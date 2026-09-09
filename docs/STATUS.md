## Current Status

- INBOX R1 lane C slice: moved the INBOX 61(35) five-symbol weighted-slot characterization body from `game/self_test.lua` into `game/tests/legacy_slot_symbol_coverage.lua`, preserving total-weight equivalence, all-symbol reachability, luck-weight growth, output, and execution order.
- Added `game/tests/self_test_slot_symbol_coverage_extraction.lua` to enforce delegation, removal of the inline body, the extracted `run()` boundary, and the preserved assertions.
- RED was observed when the extraction test could not read the not-yet-created legacy suite; `make test LOVE=/Users/jm/.local/bin/love` is GREEN after extraction.
- R1 remains pending because additional inline legacy bodies still need extraction before `self_test.lua` is runner/common-fixture centered.

## Next slice

- INBOX R1 lane C: extract the adjacent INBOX 61(32) `play_hud.lua` extraction characterization body from `game/self_test.lua` into `game/tests/legacy_play_hud_extraction.lua`, preserving installed-method, source-location, removed-inline-block assertions, output, and execution order, with an engine-hosted extraction characterization test.
