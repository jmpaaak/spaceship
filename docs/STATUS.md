## Current Status

- INBOX 79: stop Love windows flashing during tests/QA.
  - Headless `conf.lua` now disables the window table entirely (`t.window = false`) plus window/graphics/audio modules.
  - Makefile headless env includes `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`.
  - Gostro visual QA captures still run, but windows are 1x1 borderless off-screen and minimized.

## Next slice

- 처리 대기 is empty after this cycle — IDLE unless new Discord rows land.
