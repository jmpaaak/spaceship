# Generated Asset Log

Append-only log of final (non-candidate) visual assets applied to the
running game via the AetherAI/ComfyUI pipelines, once the loop's own
QA has judged them ready to use — human-gate removed (2026-09-03), so
this is the loop's own approval record.

Each entry is ONE line, appended (never edited/reordered), in this
exact format so `spaceship_progress_report.py` cron can detect new
lines and forward the image file to the user automatically:

```
YYYY-MM-DDTHH:MM:SS+0900 | <relative/path/to.png> | <one-line what/why>
```

- `<relative/path/to.png>` must be an actual file that exists in this
  repo at the commit that adds the log line.
- Keep the description to one line; put full provenance in
  `docs/assets/MANIFEST.json`, not here.
- Do not log candidate/superseded/QA-only assets — only ones the loop
  is treating as the final, runtime-applied art for their slot.

<!-- New entries append below this line. Do not remove existing lines. -->
2026-09-03T17:10:00+0900 | assets/ship/ship_default.png | ComfyUI-generated 64x64 top-down ship sprite, wired into PlayScene as self.shipImage (drawn at ~16px footprint)
2026-09-03T17:06:36+0900 | assets/planet/planet_generic.png | ComfyUI-generated 64x64 neutral-tone planet sprite, wired into PlayScene as self.planetImage (tinted per-planet by existing hue color, replaces flat gradient circle)
2026-09-03T20:35:00+0900 | assets/ship/ship_default.png | Regenerated (seed 20260903137) after remote ComfyUI host instability corrupted the prior file; single-connected-component silhouette verified via flood-fill pixel analysis
2026-09-03T20:37:00+0900 | assets/planet/planet_generic.png | Regenerated (seed 20260903241) after remote ComfyUI host instability corrupted the prior file; single-connected disc silhouette verified via flood-fill pixel analysis
2026-09-03T21:15:00+0900 | assets/earth/earth_generic.png | ComfyUI-generated 64x64 Earth sprite (seed 20260903358), wired into PlayScene as self.earthImage, replaces the flat ocean-circle + green-blob launch-screen Earth disc; single-connected-component silhouette (2618px) verified via flood-fill pixel analysis
2026-09-03T21:40:00+0900 | assets/effects/sample_sparkle.png | ComfyUI-generated 64x64 sample-pickup sparkle effect sprite (seed 20260903501), wired into PlayScene as self.sampleEffectImage (tinted per-particle by existing tier color, replaces flat love.graphics.circle dots); single-connected-component silhouette (3300px) verified via flood-fill pixel analysis
2026-09-03T20:45:57+0900 | assets/backgrounds/deep_space_tile.png | ComfyUI-generated 128x128 deep-space nebula background tile (seed 20260903612), wired into PlayScene as self.backgroundImage, tiled/wrap-repeat behind existing star point layers at 0.4x parallax
2026-09-03T22:05:00+0900 | assets/slot_symbols/comet.png | ComfyUI-generated 64x64 comet slot-machine reel icon (seed 20260903701), wired into PlayScene as self.slotSymbolImages.COMET, replaces plain "COMET" text in the returning-phase reel
2026-09-03T22:06:00+0900 | assets/slot_symbols/planet.png | ComfyUI-generated 64x64 planet slot-machine reel icon (seed 20260903702), wired into PlayScene as self.slotSymbolImages.PLANET, replaces plain "PLANET" text in the returning-phase reel
2026-09-03T22:07:00+0900 | assets/slot_symbols/star.png | ComfyUI-generated 64x64 star slot-machine jackpot reel icon (seed 20260903703), wired into PlayScene as self.slotSymbolImages.STAR, replaces plain "STAR" text in the returning-phase reel
2026-09-03T23:10:00+0900 | assets/shop_icons/hull.png | ComfyUI-generated 64x64 EARTH SHOP hull-upgrade row icon (seed 20260903801), wired into PlayScene as self.shopIconImages.hull, drawn beside the HULL action row's compact text
2026-09-03T23:11:00+0900 | assets/shop_icons/steering.png | ComfyUI-generated 64x64 EARTH SHOP steering-upgrade row icon (seed 20260903802), wired into PlayScene as self.shopIconImages.steering, drawn beside the STEERING action row's compact text
2026-09-03T23:12:00+0900 | assets/shop_icons/yield.png | ComfyUI-generated 64x64 EARTH SHOP sample-yield-upgrade row icon (seed 20260903803), wired into PlayScene as self.shopIconImages.yield, drawn beside the YIELD action row's compact text
2026-09-03T23:13:00+0900 | assets/shop_icons/ship.png | ComfyUI-generated 64x64 EARTH SHOP ship-purchase row icon (seed 20260903804), wired into PlayScene as self.shopIconImages.ship, drawn beside the SHIP action row's compact text
2026-09-04T01:33:00+0900 | assets/debris/asteroid.png | ComfyUI-generated 64x64 drifting asteroid hazard sprite (seed 20260904101), wired into PlayScene as self.debrisImages.asteroid, replaces the Lua circle placeholder
2026-09-04T01:34:00+0900 | assets/debris/can.png | ComfyUI-generated 64x64 drifting soda-can junk sprite (seed 20260904102), wired into PlayScene as self.debrisImages.can, replaces the Lua rectangle placeholder
2026-09-04T01:35:00+0900 | assets/debris/scrap.png | ComfyUI-generated 64x64 drifting rusty scrap sprite (seed 20260904103), wired into PlayScene as self.debrisImages.scrap, replaces the Lua triangle placeholder
2026-09-04T01:39:32+0900 | assets/effects/planet_twinkle.png | ComfyUI-generated 64x64 planet-approach twinkle sprite (seed 20260904104), wired into PlayScene as self.planetTwinkleImage, replaces orbiting love.graphics.circle dots around undiscovered planets
2026-09-04T01:46:23+0900 | assets/effects/collision_spark.png | ComfyUI-generated 64x64 collision-impact spark sprite (seed 20260904105), wired into PlayScene as self.collisionEffectImage, used by spawnCollisionParticles on planet/debris hits
2026-09-04T01:46:23+0900 | assets/effects/thrust_plume.png | ComfyUI-generated 64x64 rocket exhaust plume sprite (seed 20260904106), wired into PlayScene as self.thrustEffectImage for RCS puffs and the ascending tail flame
2026-09-04T01:50:29+0900 | assets/effects/planet_glow.png | ComfyUI-generated 64x64 undiscovered-planet rim glow sprite (seed 20260904107), wired into PlayScene as self.planetGlowImage, replaces stacked love.graphics.circle glow rings
2026-09-04T01:54:49+0900 | assets/effects/planet_shadow.png | ComfyUI-generated 64x64 planet drop shadow sprite (seed 20260904108), wired into PlayScene as self.planetShadowImage, replaces the Lua circle drop shadow
2026-09-04T01:58:58+0900 | assets/effects/minimap_disc.png | ComfyUI-generated 64x64 minimap chart disc sprite (seed 20260904109), wired into PlayScene as self.minimapDiscImage, replaces the Lua circle fill+line galaxy chart background
2026-09-04T02:03:31+0900 | assets/effects/joystick_pad.png | ComfyUI-generated 64x64 virtual joystick pad sprite (seed 20260904110), wired into PlayScene as self.joystickPadImage, replaces the Lua circle fill+line analog-stick base
2026-09-04T02:07:10+0900 | assets/effects/joystick_knob.png | ComfyUI-generated 64x64 virtual joystick knob sprite (seed 20260904111), wired into PlayScene as self.joystickKnobImage, replaces the Lua circle analog-stick cap
2026-09-04T02:10:46+0900 | assets/effects/hud_coin.png | ComfyUI-generated 64x64 HUD cash coin sprite (seed 20260904112), wired into PlayScene as self.cashIconImage, replaces the Lua octagon CASH icon
2026-09-04T02:14:09+0900 | assets/effects/hud_shield.png | ComfyUI-generated 64x64 HUD hull shield sprite (seed 20260904113), wired into PlayScene as self.hullIconImage, replaces the Lua pentagon HULL icon
2026-09-04T02:17:55+0900 | assets/effects/hud_speed.png | ComfyUI-generated 64x64 HUD speedometer sprite (seed 20260904114), wired into PlayScene as self.speedIconImage, replaces the Lua semicircle+needle STEER SPEED icon
2026-09-04T02:21:21+0900 | assets/effects/minimap_checkpoint_star.png | ComfyUI-generated 64x64 minimap checkpoint star sprite (seed 20260904115), wired into PlayScene as self.checkpointStarImage, replaces the Lua 5-point star polygon for checkpoint galaxies
2026-09-04T02:25:38+0900 | assets/effects/minimap_checkpoint_arrow.png | ComfyUI-generated 64x64 minimap off-chart checkpoint arrow sprite (seed 20260904116), wired into PlayScene as self.checkpointArrowImage, replaces the Lua circle+triangle direction marker
2026-09-04T02:29:24+0900 | assets/effects/minimap_player.png | ComfyUI-generated 64x64 minimap player location marker sprite (seed 20260904117), wired into PlayScene as self.playerMarkerImage, replaces the Lua filled-circle+outline you-are-here marker
