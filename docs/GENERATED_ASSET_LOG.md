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
