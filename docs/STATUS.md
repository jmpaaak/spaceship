## Current Status

- INBOX R1 lane C slice: moved the INBOX 61(29) help-overlay/luck-format characterization body from `game/self_test.lua` into `game/tests/legacy_help_overlay_luck.lua`, preserving PlayScene-method, button-layout, locale-reset, i18n-key, source-location assertions, output, and execution order.
- Added `game/tests/self_test_help_overlay_luck_extraction.lua` to enforce delegation, removal of the inline body, the extracted `run()` boundary, and the preserved assertions; `game/self_test.lua` decreased from 441 to 400 lines.
- RED was observed when the extraction test could not read the not-yet-created legacy suite; `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` are GREEN after extraction.
- R1 remains pending because the adjacent INBOX 61(34) synergy-display legacy body still needs extraction before `self_test.lua` is runner/common-fixture centered.

## Next slice

- INBOX R1 lane C: extract the adjacent INBOX 61(34) synergy-display characterization body from `game/self_test.lua` into `game/tests/legacy_synergy_display.lua`, preserving locale reset, known-suit name/description and symbol-prefix assertions, HUD source-location assertions, output, and execution order, with an engine-hosted extraction characterization test.
