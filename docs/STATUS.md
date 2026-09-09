## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(23) leaderboard button, scene, score parsing, and configuration characterization block from `game/self_test.lua` into `game/tests/legacy_leaderboard_scene.lua`, preserving both locales, title button ordering/touch callback, scene construction, touch/escape back actions, sorting/rank, and port configuration contracts.
- Added `game/tests/self_test_leaderboard_scene_extraction.lua` to enforce delegation, removal of the legacy runner body, the extracted `run()` boundary, and retention of all behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 942 to 857 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(23b) leaderboard client score-submission characterization block into one `game/tests/legacy_*.lua` suite, preserving exported API, new-best comparisons, headless submission, and `PlayScene` load contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
