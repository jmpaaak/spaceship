## Current Status

- INBOX 80: Hermes fallback order is now Codex before Grok.
  - `~/.hermes/config.yaml` `fallback_providers`: `gpt-5.6-sol` (openai-codex) → `grok-4.6` (xai-oauth) → Vertex/Gemini.
  - mok `loop/env.sh` no longer pins Grok as primary; Claude + the global chain apply. Lane worktrees updated too.

## Next slice

- 처리 대기 is empty after this cycle — IDLE unless new Discord rows land.
