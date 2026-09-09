## Current Status

- INBOX 72 is complete and moved to 처리 완료. Pure `game/speed_display.lua` normalizes user-facing speed as `effectiveSpeed - baseSpeed`; fresh runs display 0, a +1 upgrade previews 1, and gear bonuses remain visible as their actual increase.
- Launch/shop presentation and the in-flight ship summary consume the normalized value in both EN and KO. Movement still uses physical `effectiveSpeed` 60 and RCS still uses the actual `effectiveSpeed/999` gradient.
- Added engine-hosted `game/tests/speed_display.lua` and updated HUD/shop regressions. RED was observed for the missing module; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN, including packaged-game verification.

## Next slice

- INBOX 73: remove Asset Studio's fixed circle/ellipse fallback from uploaded-image processing, return contained NEAREST-resized uploads unchanged, and expose the selected engine with focused server/UI tests.
