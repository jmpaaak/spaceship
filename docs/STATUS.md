## Current Status

- INBOX R1 lane C slice: moved the INBOX 61(32) `play_gameover.lua` extraction characterization body from `game/self_test.lua` into `game/tests/legacy_play_gameover_extraction.lua`, preserving installed-method, source-location, removed-inline-block assertions, output, and execution order.
- Added `game/tests/self_test_play_gameover_extraction.lua` to enforce delegation, removal of the inline body, the extracted `run()` boundary, and the preserved assertions; `game/self_test.lua` decreased from 467 to 441 lines.
- RED was observed when the extraction test could not read the not-yet-created legacy suite; `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` are GREEN after extraction.
- R1 remains pending because additional inline legacy bodies still need extraction before `self_test.lua` is runner/common-fixture centered.

## Next slice

- INBOX R1 lane C: extract the adjacent INBOX 61(29) help-overlay/luck-format characterization body from `game/self_test.lua` into `game/tests/legacy_help_overlay_luck.lua`, preserving PlayScene method, layout, locale reset, i18n-key, source-location assertions, output, and execution order, with an engine-hosted extraction characterization test.
