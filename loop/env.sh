#!/usr/bin/env bash

HERMES_BIN="${HERMES_BIN:-/Users/jm/.hermes/hermes-agent/venv/bin/hermes}"
PROVIDER="${PROVIDER:-anthropic}"
MODEL="${MODEL:-claude-sonnet-4-6}"
REASONING="${REASONING:-high}"
FALLBACK_AGY_BIN="${FALLBACK_AGY_BIN:-/Users/jm/.local/bin/agy}"
FALLBACK_MODEL="${FALLBACK_MODEL:-gemini-3.1-pro-high}"
FALLBACK_PRINT_TIMEOUT="${FALLBACK_PRINT_TIMEOUT:-20m}"
MAX_TURNS="${MAX_TURNS:-90}"
# Idle is no-stdout (remote ComfyUI waits are silent). 600s covers a typical
# XL render; RUN_BUDGET 1800s is the wall-clock ceiling and is independent.
RUN_BUDGET_SECONDS="${RUN_BUDGET_SECONDS:-1800}"
MAX_IDLE_SECONDS="${MAX_IDLE_SECONDS:-600}"
WAIT_SECONDS="${WAIT_SECONDS:-10}"
MAX_LOOPS="${MAX_LOOPS:-0}"
