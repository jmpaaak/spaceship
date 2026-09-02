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
  [[ -f "${worktree_dir}/.git/MERGE_HEAD" ]] || [[ -d "${worktree_dir}/.git/rebase-merge" ]] || [[ -d "${worktree_dir}/.git/rebase-apply" ]]
}

start_loop() {
  local worktree_dir="$1"
  local label="$2"
  if has_in_progress_merge "${worktree_dir}"; then
    log "SKIP ${label}: merge/rebase in progress in ${worktree_dir}, not touching it."
    return
  fi
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
  else
    start_loop "${worktree_dir}" "${label}"
  fi
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
