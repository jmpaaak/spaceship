## Current Status

- INBOX (19) complete: Planet text replacement — all 5 sub-items done.
  - (a) Removed sample price (`risk.sampleLabel`) and damage (`risk.label`) drawing block from planet rendering. `collisionRisk()` function kept intact for game logic.
  - (b) Undiscovered normal planets show "신규 행성 발견" / "New Planet" label with sin(time*2)*3 bobbing, color (0.7, 0.9, 1, 0.8).
  - (c) HUB planets show "HUB" + "엔진부품 획득 가능" / "Engine part available" in magenta (0.85, 0.35, 0.95), sin bobbing.
  - (d) Central star shows "중심별" / "Central Star" label in yellow (1, 0.85, 0.25) above star radius.
  - (e) SHOP planets show "SHOP" + "선체부품 획득 가능" / "Hull part available" in cyan (0.3, 0.9, 0.95), sin bobbing.
  - New i18n keys: planet_new_discovery, central_star_label, engine_part_available, hull_part_available (en + ko).
  - Tests: i18n key existence validated for both locales. make verify GREEN.

## Next Slice

- INBOX (20): Minimap — galaxy clipping + distance + checkpoint color + Earth/Star labels.
