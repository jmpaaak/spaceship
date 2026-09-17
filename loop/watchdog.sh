#!/usr/bin/env bash
# Autonomous-loop watchdog: detects any dead lane (main loop or a parallel
# lane worktree) for THIS project and restarts it.
#
# Why this exists (2026-09-03 incident): main loops are normally kept alive
# by a launchd KeepAlive plist, but parallel lanes scaffolded by
# scaffold_lane.sh are NOT auto-registered with launchd -- the plist is only
# written to disk, a human has to bootstrap it. When a lane's loop.sh exits
# (idle timeout, crash, or a human manually killing it to avoid a merge
# race) nothing notices and it silently stays dead for hours. This script
# is the fix: run it on a schedule (cron/launchd calendar interval, e.g.
# every 5-10 minutes) and it will bring every configured lane back up.
#
# Usage:
#   loop/watchdog.sh                    # check/restart the primary loop only
#   loop/watchdog.sh <lanes-parent-dir> # also check/restart every lane
#                                        # worktree found under that dir
#
# Safety: this script does NOT touch git state, does NOT resolve merge
# conflicts, and refuses to start a loop while a `git status --short` in
# that worktree shows an in-progress merge/rebase (MERGE_HEAD or
# REBASE_HEAD present) -- it logs a warning and skips that lane instead, so
# it never races a human or another agent who is mid-merge.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_NAME="$(basename "${ROOT_DIR}")"
LANES_PARENT_DIR="${1:-}"
WATCHDOG_LOG="${ROOT_DIR}/logs/watchdog.log"
mkdir -p "${ROOT_DIR}/logs"
WATCHDOG_LOCK="${TMPDIR:-/tmp}/${PROJECT_NAME}.autodev-watchdog.lock"
if ! mkdir "${WATCHDOG_LOCK}" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "${WATCHDOG_LOCK}" 2>/dev/null || true' EXIT

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" | tee -a "${WATCHDOG_LOG}"
}

# Returns 0 (true) if a loop.sh process is currently running with this
# worktree as its root (matches both `--in <dir>` invocation and a plain
# `cd <dir> && ./loop/loop.sh` invocation).
is_loop_running() {
  local worktree_dir="$1"
  pgrep -f "loop\.sh\$" 2>/dev/null | while read -r pid; do
    if lsof -a -p "${pid}" -d cwd 2>/dev/null | grep -qF "${worktree_dir}"; then
      echo "${pid}"
      return 0
    fi
  done | grep -q .
}

# Refuses to (re)start a loop while a merge/rebase is in progress in that
# worktree -- avoids racing a human or subagent resolving conflicts.
has_in_progress_merge() {
  local worktree_dir="$1"
  local merge_head rebase_merge rebase_apply
  merge_head="$(git -C "${worktree_dir}" rev-parse --git-path MERGE_HEAD 2>/dev/null || true)"
  rebase_merge="$(git -C "${worktree_dir}" rev-parse --git-path rebase-merge 2>/dev/null || true)"
  rebase_apply="$(git -C "${worktree_dir}" rev-parse --git-path rebase-apply 2>/dev/null || true)"
  [[ "${merge_head}" = /* ]] || merge_head="${worktree_dir}/${merge_head}"
  [[ "${rebase_merge}" = /* ]] || rebase_merge="${worktree_dir}/${rebase_merge}"
  [[ "${rebase_apply}" = /* ]] || rebase_apply="${worktree_dir}/${rebase_apply}"
  [[ -n "${merge_head}" && -f "${merge_head}" ]] ||
    [[ -n "${rebase_merge}" && -d "${rebase_merge}" ]] ||
    [[ -n "${rebase_apply}" && -d "${rebase_apply}" ]]
}

# If STOP exists but INBOX has pending work, treat STOP as stale idle-stop
# and resume. Manual halt still works: leave 처리 대기 empty, or write
# loop/STOP with first line containing MANUAL.
inbox_has_pending() {
  local worktree_dir="$1"
  python3 - "${worktree_dir}" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
candidates = [root / "docs" / "feedback" / "INBOX.md", root / "loop" / "INBOX"]
item_re = re.compile(r"^(?:-\s*)?(?:\[|\()[A-Za-z]+\d+[a-z]?(?:\]|\))\s+\S", re.I)
for inbox in candidates:
    if not inbox.is_file():
        continue
    text = inbox.read_text(encoding="utf-8")
    if "## 처리 대기" in text:
        section = text.split("## 처리 대기", 1)[1].split("## 처리 완료", 1)[0]
        for line in section.splitlines():
            s = line.strip()
            if not s or s.startswith("<!--"):
                continue
            if s.startswith("-") or (s[:1].isdigit() and "." in s[:4]) or item_re.match(s):
                raise SystemExit(0)
    else:
        for line in text.splitlines():
            s = line.strip()
            if item_re.match(s):
                raise SystemExit(0)
            # Guard: "## P#" markdown heading is NOT a valid item; warn and skip
            if re.match(r"^#+\s+P\d+", s):
                import sys
                print(f"INBOX FORMAT ERROR: '{s}' is a markdown heading, not a [P#] item. Use: [P45] description...", file=sys.stderr)
raise SystemExit(1)
PY
}

maybe_clear_stale_stop() {
  local worktree_dir="$1"
  local label="$2"
  local stop="${worktree_dir}/loop/STOP"
  [[ -f "${stop}" ]] || return 0
  if head -n 1 "${stop}" 2>/dev/null | grep -qi "MANUAL"; then
    log "SKIP ${label}: loop/STOP is MANUAL, not auto-clearing."
    return 0
  fi
  if inbox_has_pending "${worktree_dir}"; then
    log "RESUME ${label}: INBOX has pending items; removing stale loop/STOP."
    rm -f "${stop}"
  fi
}


start_loop() {
  local worktree_dir="$1"
  local label="$2"
  if has_in_progress_merge "${worktree_dir}"; then
    log "SKIP ${label}: merge/rebase in progress in ${worktree_dir}, not touching it."
    return
  fi
  maybe_clear_stale_stop "${worktree_dir}" "${label}"
  if [[ -f "${worktree_dir}/loop/STOP" ]]; then
    log "SKIP ${label}: loop/STOP present (intentionally stopped), not restarting."
    return
  fi
  if [[ ! -x "${worktree_dir}/loop/loop.sh" ]]; then
    log "SKIP ${label}: no loop/loop.sh in ${worktree_dir}."
    return
  fi
  log "RESTART ${label}: no running loop.sh found for ${worktree_dir}, starting one."
  (
    cd "${worktree_dir}" || exit 1
    nohup ./loop/loop.sh >>"${worktree_dir}/logs/watchdog-restart.out" 2>&1 &
    disown
  )
}

check_and_restart() {
  local worktree_dir="$1"
  local label="$2"
  if is_loop_running "${worktree_dir}"; then
    log "OK ${label}: loop.sh running for ${worktree_dir}."
    return
  fi
  if ! inbox_has_pending "${worktree_dir}"; then
    log "SKIP ${label}: no pending INBOX, not restarting."
    return
  fi
  start_loop "${worktree_dir}" "${label}"
}

# 1. Primary loop for this project checkout.
check_and_restart "${ROOT_DIR}" "${PROJECT_NAME}-main"

# 2. Every parallel lane worktree, if a lanes parent dir was given (or
#    discoverable via `git worktree list`).
if [[ -n "${LANES_PARENT_DIR}" && -d "${LANES_PARENT_DIR}" ]]; then
  for lane_dir in "${LANES_PARENT_DIR}"/*/; do
    lane_dir="${lane_dir%/}"
    [[ -d "${lane_dir}/loop" ]] || continue
    lane_name="$(basename "${lane_dir}")"
    check_and_restart "${lane_dir}" "${PROJECT_NAME}-${lane_name}"
  done
else
  # Auto-discover lane worktrees registered with git for this repo.
  while read -r wt_path; do
    [[ "${wt_path}" == "${ROOT_DIR}" ]] && continue
    [[ -d "${wt_path}/loop" ]] || continue
    lane_name="$(basename "${wt_path}")"
    check_and_restart "${wt_path}" "${PROJECT_NAME}-${lane_name}"
  done < <(cd "${ROOT_DIR}" && git worktree list 2>/dev/null | awk '{print $1}')
fi
