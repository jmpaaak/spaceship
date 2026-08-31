#!/usr/bin/env python3
"""Run one headless agent session with hard step and idle limits."""

from __future__ import annotations

import argparse
import ctypes
import ctypes.util
import errno
import json
import os
import queue
import signal
import subprocess
import sys
import threading
import time
from typing import NamedTuple, Optional


COUNTED_ITEM_TYPES = {
    "command_execution",
    "file_change",
    "mcp_tool_call",
    "web_search",
}
AGY_COUNTED_TOOLS = {
    "browser_click_element",
    "call_mcp_tool",
    "execute_browser_javascript",
    "multi_replace_file_content",
    "replace_file_content",
    "run_command",
    "search_web",
    "sed_file",
    "write_to_file",
}


class ProcessIdentity(NamedTuple):
    pid: int
    ppid: int
    start_tvsec: int
    start_tvusec: int


class DarwinProcessInfo(NamedTuple):
    identity: ProcessIdentity
    pgid: int
    status: int


class _ProcBSDInfo(ctypes.Structure):
    _fields_ = [
        ("pbi_flags", ctypes.c_uint32),
        ("pbi_status", ctypes.c_uint32),
        ("pbi_xstatus", ctypes.c_uint32),
        ("pbi_pid", ctypes.c_uint32),
        ("pbi_ppid", ctypes.c_uint32),
        ("pbi_uid", ctypes.c_uint32),
        ("pbi_gid", ctypes.c_uint32),
        ("pbi_ruid", ctypes.c_uint32),
        ("pbi_rgid", ctypes.c_uint32),
        ("pbi_svuid", ctypes.c_uint32),
        ("pbi_svgid", ctypes.c_uint32),
        ("rfu_1", ctypes.c_uint32),
        ("pbi_comm", ctypes.c_char * 16),
        ("pbi_name", ctypes.c_char * 32),
        ("pbi_nfiles", ctypes.c_uint32),
        ("pbi_pgid", ctypes.c_uint32),
        ("pbi_pjobc", ctypes.c_uint32),
        ("e_tdev", ctypes.c_uint32),
        ("e_tpgid", ctypes.c_uint32),
        ("pbi_nice", ctypes.c_int32),
        ("pbi_start_tvsec", ctypes.c_uint64),
        ("pbi_start_tvusec", ctypes.c_uint64),
    ]


_LIBPROC = None
_PROC_PIDTBSDINFO = 3
_PROC_STATUS_STOPPED = 4
_PROC_STATUS_ZOMBIE = 5
_DESCENDANT_CLOSURE_ROUNDS = 8


def _libproc():
    global _LIBPROC
    if _LIBPROC is None:
        path = ctypes.util.find_library("proc") or "/usr/lib/libproc.dylib"
        library = ctypes.CDLL(path, use_errno=True)
        library.proc_pidinfo.argtypes = [
            ctypes.c_int, ctypes.c_int, ctypes.c_uint64, ctypes.c_void_p, ctypes.c_int
        ]
        library.proc_pidinfo.restype = ctypes.c_int
        library.proc_listchildpids.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
        library.proc_listchildpids.restype = ctypes.c_int
        _LIBPROC = library
    return _LIBPROC


def darwin_process_info(pid: int) -> Optional[DarwinProcessInfo]:
    """Read one identity-bearing libproc record; None means that identity is gone."""
    record = _ProcBSDInfo()
    ctypes.set_errno(0)
    result = _libproc().proc_pidinfo(
        pid, _PROC_PIDTBSDINFO, 0, ctypes.byref(record), ctypes.sizeof(record)
    )
    if result == 0 and ctypes.get_errno() in {0, errno.ESRCH}:
        return None
    if result != ctypes.sizeof(record):
        error = ctypes.get_errno() or errno.EIO
        raise OSError(error, f"proc_pidinfo({pid}) failed")
    identity = ProcessIdentity(
        int(record.pbi_pid),
        int(record.pbi_ppid),
        int(record.pbi_start_tvsec),
        int(record.pbi_start_tvusec),
    )
    return DarwinProcessInfo(identity, int(record.pbi_pgid), int(record.pbi_status))


def darwin_child_pids(pid: int) -> list[int]:
    """Take one bounded snapshot of a process's direct children."""
    ctypes.set_errno(0)
    estimate = _libproc().proc_listchildpids(pid, None, 0)
    if estimate < 0:
        raise OSError(ctypes.get_errno() or errno.EIO, "proc_listchildpids sizing failed")
    capacity = max(estimate + 16, 32)
    children = (ctypes.c_int * capacity)()
    ctypes.set_errno(0)
    count = _libproc().proc_listchildpids(pid, children, ctypes.sizeof(children))
    if count < 0 or count > capacity:
        raise OSError(ctypes.get_errno() or errno.EIO, "proc_listchildpids failed")
    return [int(children[index]) for index in range(count)]


def _signal_identity(identity: ProcessIdentity, sig: signal.Signals) -> bool:
    """Revalidate identity immediately before a per-PID signal.

    libproc identity checking materially narrows PID-reuse risk, but macOS has
    no pidfd: exit/reuse can still occur between this check and os.kill().
    """
    current = darwin_process_info(identity.pid)
    if current is None:
        return sig == signal.SIGKILL
    if current.identity != identity:
        return False
    try:
        os.kill(identity.pid, sig)
    except ProcessLookupError:
        return sig == signal.SIGKILL and darwin_process_info(identity.pid) is None
    except PermissionError:
        return False
    return True


def _wait_identity_stopped(identity: ProcessIdentity) -> bool:
    for _ in range(20):
        current = darwin_process_info(identity.pid)
        if current is None or current.identity != identity:
            return False
        if current.status in {_PROC_STATUS_STOPPED, _PROC_STATUS_ZOMBIE}:
            return True
        time.sleep(0.01)
    return False


def freeze_darwin_descendants(root_pid: int) -> tuple[list[DarwinProcessInfo], bool]:
    """Best-effort bounded closure of current direct descendants.

    SIGSTOP and repeated direct-child snapshots close the reproducible setsid
    leak. They cannot recover a child that double-forks and is reparented
    before the first snapshot, nor eliminate the final identity-check/signal
    race; callers therefore fail closed on every observable uncertainty.
    """
    root = darwin_process_info(root_pid)
    if root is None or root.status == _PROC_STATUS_ZOMBIE:
        return [], True

    closure: dict[ProcessIdentity, DarwinProcessInfo] = {root.identity: root}
    stable_rounds = 0
    complete = True
    for _ in range(_DESCENDANT_CLOSURE_ROUNDS):
        found_new = False
        for parent_identity in list(closure):
            parent = darwin_process_info(parent_identity.pid)
            if parent is None or parent.identity != parent_identity:
                complete = False
                continue
            for child_pid in darwin_child_pids(parent_identity.pid):
                child = darwin_process_info(child_pid)
                if child is None:
                    complete = False
                    continue
                if child.identity.ppid != parent_identity.pid:
                    complete = False
                    continue
                parent_birth = (parent_identity.start_tvsec, parent_identity.start_tvusec)
                child_birth = (child.identity.start_tvsec, child.identity.start_tvusec)
                if child_birth < parent_birth:
                    complete = False
                    continue
                if child.identity in closure:
                    continue
                if not _signal_identity(child.identity, signal.SIGSTOP):
                    complete = False
                    continue
                if not _wait_identity_stopped(child.identity):
                    complete = False
                    continue
                closure[child.identity] = child
                found_new = True
        if found_new:
            stable_rounds = 0
        else:
            stable_rounds += 1
            if stable_rounds == 2:
                return list(closure.values())[1:], complete
    return list(closure.values())[1:], False


def verify_darwin_identities_absent(identities: list[ProcessIdentity]) -> bool:
    for _ in range(20):
        remaining = []
        for identity in identities:
            current = darwin_process_info(identity.pid)
            if current is not None and current.identity == identity:
                remaining.append(identity)
        if not remaining:
            return True
        time.sleep(0.05)
    return False


def allow_darwin_leader_immediate_exit(
    identity: ProcessIdentity, grace_seconds: float
) -> bool:
    """Let an already-completing leader publish its exit status without reaping it."""
    if grace_seconds <= 0:
        return True
    if not _signal_identity(identity, signal.SIGCONT):
        return darwin_process_info(identity.pid) is None
    deadline = time.monotonic() + min(grace_seconds, 0.1)
    while time.monotonic() < deadline:
        current = darwin_process_info(identity.pid)
        # The caller still owns this direct, unreaped Popen child, so a missing
        # libproc record here means it exited; its PID cannot be reused yet.
        if current is None:
            return True
        if current.identity != identity:
            return False
        if current.status == _PROC_STATUS_ZOMBIE:
            return True
        time.sleep(0.005)
    if not _signal_identity(identity, signal.SIGSTOP):
        return False
    return _wait_identity_stopped(identity)


def signal_process_group(group_id: int, sig: int | signal.Signals) -> bool:
    """Signal the private group created by Popen; false means it is already empty."""
    try:
        os.killpg(group_id, sig)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        # macOS returns EPERM when the unreaped session leader is the only
        # remaining group member; its PID still reserves the PGID, so no
        # unrelated group can be targeted before the later wait().
        return False


def finish_process_group(process: subprocess.Popen[str], grace_seconds: float = 1.0) -> bool:
    """Signal the private group completely before reaping its session leader."""
    group_id = process.pid
    descendant_infos: list[DarwinProcessInfo] = []
    descendants_complete = True
    if sys.platform == "darwin":
        # Freeze the owned group while its unreaped leader still reserves the
        # PGID, then close over direct descendants before the original
        # TERM/probe/KILL teardown. Per-PID signals are limited to escaped
        # groups; ordinary descendants remain under the original group policy.
        # The short leader-only resume below preserves an already-published
        # positive exit status, but reopens a bounded fork/reparent window; the
        # libproc strategy is defense-in-depth, not race-free containment.
        try:
            root_info = darwin_process_info(group_id)
            group_stopped = signal_process_group(group_id, signal.SIGSTOP)
            if root_info is not None and not group_stopped:
                descendants_complete = False
            descendant_infos, closure_complete = freeze_darwin_descendants(group_id)
            descendants_complete = descendants_complete and closure_complete
            for info in descendant_infos:
                if info.pgid != group_id and not _signal_identity(info.identity, signal.SIGKILL):
                    descendants_complete = False
            if root_info is not None and not allow_darwin_leader_immediate_exit(
                root_info.identity, grace_seconds
            ):
                descendants_complete = False
        except (OSError, ValueError):
            descendants_complete = False
    elif grace_seconds > 0:
        time.sleep(grace_seconds)

    signal_process_group(group_id, signal.SIGTERM)
    group_alive = True
    for _ in range(20):
        group_alive = signal_process_group(group_id, 0)
        if not group_alive:
            break
        time.sleep(0.05)
    if group_alive:
        signal_process_group(group_id, signal.SIGKILL)

    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        return False
    if sys.platform == "darwin":
        try:
            identities = [info.identity for info in descendant_infos]
            descendants_complete = (
                descendants_complete and verify_darwin_identities_absent(identities)
            )
        except (OSError, ValueError):
            descendants_complete = False
    return process.returncode is not None and descendants_complete


def drain_lines(lines: "queue.Queue[Optional[str]]") -> None:
    while True:
        try:
            line = lines.get_nowait()
        except queue.Empty:
            return
        if line is not None:
            print(line, end="", flush=True)


def finish_terminal_event(
    process: subprocess.Popen[str],
    lines: "queue.Queue[Optional[str]]",
    reader: threading.Thread,
    status: int,
) -> int:
    """Clean the owned process group; cleanup failure is always an internal failure."""
    reaped = finish_process_group(process)
    reader.join(timeout=1)
    drain_lines(lines)
    if not reaped or process.returncode is None:
        return 1
    # A terminal stream event permits cleanup to stop an agent that remains
    # alive; signal-based return codes from that forced cleanup do not replace
    # the event. A positive exit observed while reaping is the agent's actual
    # failure and must never be hidden by a SUCCESS event.
    if process.returncode > 0:
        return process.returncode
    return status


def monitor_lines(
    process: subprocess.Popen[str],
    lines: "queue.Queue[Optional[str]]",
    reader: threading.Thread,
    max_turns: int,
    idle_timeout: float,
    protocol: str = "stream-json",
) -> int:
    completed_steps = 0
    while True:
        try:
            line = lines.get(timeout=idle_timeout)
        except queue.Empty:
            print(
                f"[loop] Agent idle timeout after {idle_timeout:g}s without output; "
                "terminating the cycle.",
                flush=True,
            )
            finish_process_group(process, grace_seconds=0)
            reader.join(timeout=1)
            drain_lines(lines)
            return 124

        if line is None:
            reaped = finish_process_group(process, grace_seconds=0)
            if not reaped or process.returncode is None:
                return 1
            return process.returncode

        print(line, end="", flush=True)
        if protocol == "plain":
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        event_type = event.get("type")
        agy_event = event.get("event")

        if agy_event == "result":
            result_status = str(event.get("result", {}).get("status", "ERROR")).upper()
            status = 0 if result_status in {"SUCCESS", "COMPLETED", "OK"} else 1
            return finish_terminal_event(process, lines, reader, status)

        if event_type == "turn.failed":
            return finish_terminal_event(process, lines, reader, 1)

        if event_type == "turn.completed":
            return finish_terminal_event(process, lines, reader, 0)

        is_counted_step = False
        if event_type == "item.completed":
            item_type = event.get("item", {}).get("type")
            is_counted_step = item_type in COUNTED_ITEM_TYPES
        elif agy_event == "step_update":
            step = event.get("step_update", {})
            is_counted_step = (
                step.get("step_type") == "tool"
                and step.get("state") in {"DONE", "ERROR"}
                and step.get("tool_name", "") in AGY_COUNTED_TOOLS
            )

        if not is_counted_step:
            continue

        completed_steps += 1
        if completed_steps >= max_turns:
            print(
                f"[loop] MAX_TURNS={max_turns} reached after "
                f"{completed_steps} completed agentic steps; interrupting Agent.",
                flush=True,
            )
            finish_process_group(process, grace_seconds=0)
            reader.join(timeout=1)
            drain_lines(lines)
            return 124


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-turns", type=int, required=True)
    parser.add_argument("--idle-timeout", type=float, default=300)
    parser.add_argument("--protocol", choices=("stream-json", "plain"), default="stream-json")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    if args.max_turns < 1:
        parser.error("--max-turns must be at least 1")
    if args.idle_timeout <= 0:
        parser.error("--idle-timeout must be greater than 0")
    if not command:
        parser.error("a command is required after --")

    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        start_new_session=True,
    )
    lines: Optional["queue.Queue[Optional[str]]"] = None
    reader: Optional[threading.Thread] = None
    reader_started = False

    try:
        assert process.stdout is not None
        stdout = process.stdout
        line_queue: "queue.Queue[Optional[str]]" = queue.Queue()
        lines = line_queue

        def pump_output() -> None:
            try:
                for output_line in stdout:
                    line_queue.put(output_line)
            finally:
                line_queue.put(None)

        reader = threading.Thread(target=pump_output, name="agent-output", daemon=True)
        reader.start()
        reader_started = True
        return monitor_lines(
            process, lines, reader, args.max_turns, args.idle_timeout, args.protocol
        )
    except BaseException:
        finish_process_group(process, grace_seconds=0)
        if reader_started and reader is not None:
            reader.join(timeout=1)
        if lines is not None:
            drain_lines(lines)
        raise


if __name__ == "__main__":
    raise SystemExit(main())
