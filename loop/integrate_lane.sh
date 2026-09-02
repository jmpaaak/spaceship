#!/usr/bin/env bash
# Merge a parallel lane branch into the base branch after verifying it's
# green, then fast-forward the lane worktree back onto the new base so the
# lane's next cycle continues from an up-to-date checkout.
#
# Usage: loop/integrate_lane.sh <lane-branch> [base-branch] [love-binary]
#
# Run from the primary (base) checkout. See docs/PARALLEL_LANES.md.
set -euo pipefail

if [[ $# -lt 1 ]]; then
  printf 'Usage: %s <lane-branch> [base-branch] [love-binary]\n' "$0" >&2
  exit 2
fi

LANE_BRANCH="$1"
BASE_BRANCH="${2:-main}"
LOVE_BIN="${3:-/Users/jm/.local/bin/love}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

git fetch . "${LANE_BRANCH}:${LANE_BRANCH}" 2>/dev/null || true

current_branch="$(git branch --show-current)"
if [[ "${current_branch}" != "${BASE_BRANCH}" ]]; then
  printf 'Refusing to run: current branch is %s, expected %s.\n' \
    "${current_branch}" "${BASE_BRANCH}" >&2
  exit 2
fi

if [[ -n "$(git status --short)" ]]; then
  printf 'Refusing to run: %s worktree is not clean.\n' "${BASE_BRANCH}" >&2
  exit 2
fi

printf 'Merging %s into %s...\n' "${LANE_BRANCH}" "${BASE_BRANCH}"
if ! git merge --no-ff "${LANE_BRANCH}" -m "Integrate lane ${LANE_BRANCH}"; then
  printf 'Merge conflict. Resolve manually (consider the merge-reconciler skill), then:\n' >&2
  printf '  git merge --continue\n' >&2
  exit 1
fi

printf 'Running make verify...\n'
if ! make verify LOVE="${LOVE_BIN}"; then
  printf 'make verify FAILED after merge. Rolling back the merge commit.\n' >&2
  git reset --hard HEAD@{1}
  exit 1
fi

printf 'Integration verified GREEN. Pushing %s.\n' "${BASE_BRANCH}"
git push origin "${BASE_BRANCH}"

# Reset the lane worktree (if present) onto the freshly merged base so its
# next cycle starts clean instead of drifting further from base.
lane_worktree="$(git worktree list --porcelain | awk -v b="refs/heads/${LANE_BRANCH}" \
  '/^worktree /{wt=$2} /^branch /{if ($2==b) print wt}')"
if [[ -n "${lane_worktree}" ]]; then
  printf 'Resetting lane worktree %s onto %s...\n' "${lane_worktree}" "${BASE_BRANCH}"
  (cd "${lane_worktree}" && git fetch "${ROOT_DIR}" "${BASE_BRANCH}:refs/tmp-integrated" \
    && git reset --hard refs/tmp-integrated && git update-ref -d refs/tmp-integrated \
    && git clean -fd)
  printf 'Lane worktree reset done.\n'
else
  printf 'No local worktree found for %s; skipping reset (branch still merged).\n' "${LANE_BRANCH}"
fi

printf 'Integration of %s complete.\n' "${LANE_BRANCH}"
