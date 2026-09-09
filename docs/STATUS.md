## Current Status

- INBOX 60 is complete: hub first-explore plays a dedicated `hub_sample` oneshot. `game/sfx.lua` registers `assets/sfx/hub_sample.mp3`; `play_update.lua` calls `sfx.play("hub_sample")` only inside the `planet.hub` first-explore/`exploreHub` branch.
- Ordinary planet/moon/comet collect still uses `sfx.play("collect")`. The star well keeps the `star_sample` loop and does not play `hub_sample` on the 10s survival reward.
- Pixabay Loud Space Launch (id 351055) returned HTTP 403, so `tools/gen_hub_sample_sfx.py` wrote a 6s procedural launch fallback (seed 351055). `game/tests/hub_sample_sfx.lua` is GREEN.

## Next slice

- INBOX 61: slot HARVEST payout must apply shop-upgrade units (`rewardValue / 0.10` levels) so 2-match is +0.10 and 3-match is +0.50, with `game/tests/slot_payout_audit.lua`.
