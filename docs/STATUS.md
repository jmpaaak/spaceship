## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(23b) leaderboard-client score-submission characterization block from `game/self_test.lua` into `game/tests/legacy_leaderboard_client.lua`, preserving exported API checks, strict new-best comparisons, headless submission, and `PlayScene` load behavior.
- Added `game/tests/self_test_leaderboard_client_extraction.lua` to enforce delegation, removal of the legacy runner body, the extracted `run()` boundary, and retention of all behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 857 to 825 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(24) last-checkpoint respawn characterization block into one `game/tests/legacy_*.lua` suite, preserving Earth/hub settlement checkpoints, destruction/launch persistence, and Earth fallback contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
