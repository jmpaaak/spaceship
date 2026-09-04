#!/usr/bin/env bash
set -uo pipefail
umask 077

if [[ -n "${LOOP_ROOT:-}" ]]; then
  ROOT_DIR="${LOOP_ROOT}"
  SCRIPT_DIR="${ROOT_DIR}/loop"
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi
ENV_FILE="${SCRIPT_DIR}/env.sh"
STOP_FILE="${SCRIPT_DIR}/STOP"
LOCK_DIR="${SCRIPT_DIR}/.lock"
LOG_DIR="${ROOT_DIR}/logs"
PREFLIGHT="${PREFLIGHT:-${SCRIPT_DIR}/preflight.py}"

if [[ ! -f "${ENV_FILE}" ]]; then
  printf 'Missing configuration: %s\n' "${ENV_FILE}" >&2
  exit 2
fi
# shellcheck source=env.sh
source "${ENV_FILE}"

for name in MAX_TURNS RUN_BUDGET_SECONDS MAX_IDLE_SECONDS WAIT_SECONDS MAX_LOOPS; do
  value="${!name}"
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    printf '%s must be a non-negative integer (got %q)\n' "${name}" "${value}" >&2
    exit 2
  fi
done
if (( MAX_TURNS < 1 )); then
  printf 'MAX_TURNS must be at least 1\n' >&2
  exit 2
fi
if (( MAX_IDLE_SECONDS < 1 )); then
  printf 'MAX_IDLE_SECONDS must be at least 1\n' >&2
  exit 2
fi
if (( RUN_BUDGET_SECONDS < 1 )); then
  printf 'RUN_BUDGET_SECONDS must be at least 1\n' >&2
  exit 2
fi
# RUN_BUDGET is total wall-clock for a cycle. MAX_IDLE is "no stdout
# for this many seconds" — they are independent. A silent/rate-limited
# primary should be detected quickly and retried on the fallback model.

mkdir -p "${LOG_DIR}"
if ! mkdir "${LOCK_DIR}" 2>/dev/null; then
  printf 'Loop is already running (lock: %s)\n' "${LOCK_DIR}" >&2
  exit 3
fi
cleanup() {
  rm -f "${LOCK_DIR}/prompt.txt"
  rm -f "${LOCK_DIR}/primary-output.log"
  rmdir "${LOCK_DIR}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [[ -f "${STOP_FILE}" ]]; then
  printf 'STOP exists; no cycle started. Remove it or use loop/control.sh start.\n'
  exit 0
fi

if [[ ! -x "${HERMES_BIN}" ]]; then
  printf 'PREFLIGHT_RESULT=INTERNAL_ERROR\nHermes executable is missing: %s\n' \
    "${HERMES_BIN}" >&2
  exit 2
fi
if [[ ! -x "${FALLBACK_AGY_BIN}" ]]; then
  printf 'PREFLIGHT_RESULT=INTERNAL_ERROR\nGemini fallback executable is missing: %s\n' \
    "${FALLBACK_AGY_BIN}" >&2
  exit 2
fi

cycle=0
while :; do
  cycle=$((cycle + 1))
  started_at="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  log_file="${LOG_DIR}/loop-$(date '+%Y-%m-%d').log"

  {
    printf '\n===== cycle %d start %s =====\n' "${cycle}" "${started_at}"
    printf 'root=%s\nprovider=%s\nmodel=%s\nmax_turns=%s\nrun_budget=%s\n' \
      "${ROOT_DIR}" "${PROVIDER}" "${MODEL}" "${MAX_TURNS}" "${RUN_BUDGET_SECONDS}"
  } | tee -a "${log_file}"

  # Token-opt is first: compact STATUS.md before preflight/prompt so the
  # agent never ingests an unbounded history. compact_status.py no-ops if
  # the file is already small or was written in the last 45s (live edit).
  COMPACT_STATUS="${HOME}/.hermes/scripts/compact_status.py"
  if [[ -f "${COMPACT_STATUS}" ]]; then
    /usr/bin/python3 "${COMPACT_STATUS}" "${ROOT_DIR}/docs/STATUS.md" 2>&1 | tee -a "${log_file}" || true
  fi

  preflight_report="$(LOOP_ROOT="${ROOT_DIR}" /usr/bin/python3 "${PREFLIGHT}" 2>&1)"
  preflight_status=$?
  printf '%s\n' "${preflight_report}" | tee -a "${log_file}"
  if [[ -f "${STOP_FILE}" ]]; then
    printf 'STOP detected after preflight; exiting normally.\n' | tee -a "${log_file}"
    exit 0
  fi
  if (( preflight_status == 3 )); then
    printf 'Product verified and no pending feedback; exiting normally.\n' | tee -a "${log_file}"
    exit 0
  fi
  if (( preflight_status != 0 && preflight_status != 1 )); then
    printf 'Unexpected preflight status=%d; refusing to launch agent.\n' \
      "${preflight_status}" | tee -a "${log_file}"
    exit 2
  fi

  prompt="The repository root is ${ROOT_DIR}. Your first action must be to read ${SCRIPT_DIR}/PROMPT.md by this exact absolute path. Every terminal tool call must set workdir=${ROOT_DIR}; every file tool call must use an absolute path under ${ROOT_DIR}. Do not search under /Users/jm/orca/projects; that directory only contains shared Git metadata, not this worktree. Follow PROMPT.md exactly and work only in ${ROOT_DIR}. This is a fresh standalone coding cycle: do not resume, continue, or reuse any prior conversation."
  prompt+=" Do not exceed ${MAX_TURNS} agentic steps in this cycle."
  prompt+=" The deterministic cycle preflight report follows. A FAIL is the top-priority product task and forbids any completion claim until the exact failing checks pass: ${preflight_report}"
  if [[ "${LOOP_TEST_MODE:-0}" == "1" ]]; then
    prompt+=' This invocation is a setup smoke test only: read the files and report whether the loop instructions are usable, but do not modify files, commit, or begin product development.'
  fi

  prompt_file="${LOCK_DIR}/prompt.txt"
  agent_output="${LOCK_DIR}/primary-output.log"
  printf '%s\n' "${prompt}" > "${prompt_file}"
  : > "${agent_output}"

  cd "${ROOT_DIR}" || exit 1
  /usr/bin/python3 "${SCRIPT_DIR}/run_agent.py" \
    --max-turns "${MAX_TURNS}" \
    --idle-timeout "${MAX_IDLE_SECONDS}" \
    --protocol plain \
    -- \
    "${HERMES_BIN}" chat --oneshot -Q \
    --toolsets terminal,file --ignore-rules --yolo --source tool \
    --in "${ROOT_DIR}" --max-turns "${MAX_TURNS}" \
    --run-budget "${RUN_BUDGET_SECONDS}" --query-file "${prompt_file}" \
    2>&1 | tee "${agent_output}" | tee -a "${log_file}"
  agent_status=${PIPESTATUS[0]}

  if (( agent_status != 0 )) && \
      /usr/bin/python3 "${SCRIPT_DIR}/classify_provider_failure.py" \
        "${agent_output}" "${agent_status}"; then
    printf 'Codex/Grok chain exhausted; retrying this fresh cycle with %s.\n' \
      "${FALLBACK_MODEL}" | tee -a "${log_file}"
    /usr/bin/python3 "${SCRIPT_DIR}/run_agent.py" \
      --max-turns "${MAX_TURNS}" \
      --idle-timeout "${MAX_IDLE_SECONDS}" \
      --protocol stream-json \
      -- \
      "${FALLBACK_AGY_BIN}" \
      --dangerously-skip-permissions \
      --disable-slash-commands \
      --mode accept-edits \
      --print "${prompt} The configured Hermes Codex then Grok chain was exhausted, so continue this same task as the configured Gemini fallback." \
      --output-format stream-json \
      --print-timeout "${FALLBACK_PRINT_TIMEOUT}" \
      --model "${FALLBACK_MODEL}" \
      2>&1 | tee -a "${log_file}"
    agent_status=${PIPESTATUS[0]}
  fi
  rm -f "${prompt_file}" "${agent_output}"

  finished_at="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '===== cycle %d end %s status=%d =====\n' \
    "${cycle}" "${finished_at}" "${agent_status}" | tee -a "${log_file}"

  if (( agent_status == 124 )); then
    printf 'Hermes Codex/Grok chain went silent; Gemini fallback was attempted. Continuing next cycle.\n' | tee -a "${log_file}"
  elif (( agent_status != 0 )); then
    printf 'Agent cycle failed with status=%d; propagating failure.\n' \
      "${agent_status}" | tee -a "${log_file}"
    exit "${agent_status}"
  fi
  if [[ -f "${STOP_FILE}" ]]; then
    printf 'STOP detected after cycle %d; exiting normally.\n' "${cycle}" | tee -a "${log_file}"
    exit 0
  fi
  if (( MAX_LOOPS > 0 && cycle >= MAX_LOOPS )); then
    printf 'MAX_LOOPS=%d reached; exiting normally.\n' "${MAX_LOOPS}" | tee -a "${log_file}"
    exit 0
  fi

  remaining="${WAIT_SECONDS}"
  while (( remaining > 0 )); do
    if [[ -f "${STOP_FILE}" ]]; then
      printf 'STOP detected between cycles; exiting normally.\n' | tee -a "${log_file}"
      exit 0
    fi
    sleep 1
    remaining=$((remaining - 1))
  done
done
