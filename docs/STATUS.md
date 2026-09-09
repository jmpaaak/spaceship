## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(22) danger-warning i18n and `starDangerTextMultiplier` characterization block from `game/self_test.lua` into `game/tests/legacy_danger_warning.lua`, preserving both locales, the exact English copy, world multiplier, derived outer-radius, and locale-restoration contracts.
- Added `game/tests/self_test_danger_warning_extraction.lua` to enforce delegation, removal of the legacy runner body, the extracted `run()` boundary, and retention of all behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 966 to 942 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(23) leaderboard button, scene, and configuration characterization block into one `game/tests/legacy_*.lua` suite, preserving both locales, title layout/touch callback, scene construction, back action, and config contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
