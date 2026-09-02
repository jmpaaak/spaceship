#!/usr/bin/env bash
# Scaffold a parallel autonomous-dev lane as an independent git worktree.
#
# Usage:
#   loop/scaffold_lane.sh <lane-name> <worktrees-parent-dir> "<scope-description>" [base-branch]
#
# Run this from inside the primary project checkout (the one with loop/loop.sh
# already configured and working). See docs/PARALLEL_LANES.md for the full
# design rationale and the problems this addresses (duplicate work, merge
# conflicts, shared-doc write races, push races, rate limits).
set -euo pipefail

if [[ $# -lt 3 ]]; then
  printf 'Usage: %s <lane-name> <worktrees-parent-dir> "<scope-description>" [base-branch]\n' "$0" >&2
  exit 2
fi

LANE_NAME="$1"
PARENT_DIR="$2"
SCOPE_DESC="$3"
BASE_BRANCH="${4:-main}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_NAME="$(basename "${ROOT_DIR}")"
LANE_BRANCH="${PROJECT_NAME}-${LANE_NAME}"
LANE_DIR="${PARENT_DIR}/${LANE_NAME}"

if [[ ! -f "${SCRIPT_DIR}/loop.sh" ]]; then
  printf 'This script must be run from a project with loop/loop.sh already set up (%s missing).\n' \
    "${SCRIPT_DIR}/loop.sh" >&2
  exit 2
fi

mkdir -p "${PARENT_DIR}"

cd "${ROOT_DIR}"
if git show-ref --verify --quiet "refs/heads/${LANE_BRANCH}"; then
  printf 'Branch %s already exists; reusing it.\n' "${LANE_BRANCH}"
else
  git branch "${LANE_BRANCH}" "${BASE_BRANCH}"
fi

if [[ -d "${LANE_DIR}" ]]; then
  printf 'Worktree dir already exists: %s (skipping git worktree add)\n' "${LANE_DIR}"
else
  git worktree add "${LANE_DIR}" "${LANE_BRANCH}"
fi

LANE_LOOP_DIR="${LANE_DIR}/loop"
mkdir -p "${LANE_LOOP_DIR}"

# Copy the loop machinery verbatim (paths inside loop.sh/run_agent.py are
# resolved relative to SCRIPT_DIR/ROOT_DIR at runtime, so no rewriting needed).
for f in loop.sh env.sh run_agent.py preflight.py classify_provider_failure.py control.sh; do
  if [[ -f "${SCRIPT_DIR}/${f}" ]]; then
    cp "${SCRIPT_DIR}/${f}" "${LANE_LOOP_DIR}/${f}"
    chmod --reference="${SCRIPT_DIR}/${f}" "${LANE_LOOP_DIR}/${f}" 2>/dev/null || true
  fi
done
chmod +x "${LANE_LOOP_DIR}/loop.sh" 2>/dev/null || true
[[ -f "${LANE_LOOP_DIR}/control.sh" ]] && chmod +x "${LANE_LOOP_DIR}/control.sh"

# Lane-scoped PROMPT.md: base PROMPT.md plus an explicit scope lock at the top
# so this lane cannot silently pick up work owned by another lane.
LANE_LABEL="com.jm.${PROJECT_NAME}.${LANE_NAME}-lane"
{
  printf '# LANE SCOPE — %s\n\n' "${LANE_NAME}"
  printf 'This worktree is one lane of a parallel multi-lane autonomous setup.\n'
  printf 'Work ONLY within this scope. Do not touch pending feedback items owned\n'
  printf 'by other lanes, and do not edit `docs/feedback/INBOX.md` items outside\n'
  printf 'your scope (append-only status notes to your own item are fine).\n\n'
  printf '## Scope for this lane\n\n%s\n\n' "${SCOPE_DESC}"
  printf '## Branch and push discipline\n\n'
  printf -- '- This lane commits and pushes ONLY to branch `%s`. Never push to\n' "${LANE_BRANCH}"
  printf '  `main`/`master` directly, never force-push.\n'
  printf -- '- A separate integration step periodically merges this branch into\n'
  printf '  the base branch after `make verify` passes.\n\n'
  printf -- '---\n\n'
  cat "${SCRIPT_DIR}/PROMPT.md"
} > "${LANE_LOOP_DIR}/PROMPT.md"

# Lane-scoped plist (distinct Label so launchd tracks it independently).
SRC_PLIST="$(find "${SCRIPT_DIR}" -maxdepth 1 -iname '*.plist' | head -1)"
if [[ -n "${SRC_PLIST}" ]]; then
  sed \
    -e "s#${ROOT_DIR}#${LANE_DIR}#g" \
    -e "s#com\.jm\.${PROJECT_NAME}\.autodev-loop#${LANE_LABEL}#g" \
    "${SRC_PLIST}" > "${LANE_LOOP_DIR}/${LANE_LABEL}.plist"
  printf '<key>LOOP_ROOT</key>\n' >> /dev/null # no-op, placeholder for readability
fi

printf 'Lane scaffolded: %s\n' "${LANE_DIR}"
printf '  branch:  %s\n' "${LANE_BRANCH}"
printf '  prompt:  %s\n' "${LANE_LOOP_DIR}/PROMPT.md"
if [[ -n "${SRC_PLIST}" ]]; then
  printf '  plist:   %s (copy to ~/Library/LaunchAgents/ and launchctl bootstrap to start)\n' \
    "${LANE_LOOP_DIR}/${LANE_LABEL}.plist"
fi
printf '\nNext steps:\n'
printf '  1. Review/edit %s\n' "${LANE_LOOP_DIR}/PROMPT.md"
printf '  2. cp %s ~/Library/LaunchAgents/\n' "${LANE_LOOP_DIR}/${LANE_LABEL}.plist"
printf '  3. launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/%s.plist\n' "${LANE_LABEL}"
