# LANE SCOPE — main

This worktree is the main Spaceship autonomous loop
(`/Users/jm/orca/workspaces/spaceship/main`). Process `docs/feedback/INBOX.md`
pending items from the top. Do not take over items owned by other lanes:

- econ lane owns items 7 / 8 / 11 / 15
- gear lane owns items 13 / 9 / 10 / 12 / 14

Everything else — including 「생성 에셋 LLM 비전 검토 제외」 and AetherAI/ComfyUI
asset work — is this lane. Commit and push to `main` after tests pass.

---

# Spaceship autonomous development brief

## First priority

Build the playable portrait-mobile roguelite specified in `docs/feedback/INBOX.md` and `docs/GAME_DESIGN.md`:

`launch → ascending → fuel-empty return/slots → Earth settlement/shop → relaunch`.

Durability destruction must wipe unbanked samples, money, purchased ship, and upgrades while preserving only all-time maximum height.

## Required workflow

1. Read only the pending feedback, game design, and current status needed for this cycle. Do not read `docs/STATUS.md` in full — latest `##` section plus next slice only. Do not read `docs/STATUS_HISTORY.md` unless tracking a specific past bug.
2. Run `git status --short` before editing. Preserve and finish prior-cycle work; do not overwrite it.
3. If preflight reports FAIL, reproduce and fix that exact failure first.
4. Otherwise choose one small user-visible or state-machine slice from the top pending requirement.
5. Use test-driven development: add a failing engine-hosted test, observe RED, implement, then run focused GREEN tests.
6. Run `make verify LOVE=/Users/jm/.local/bin/love` before a checkpoint commit.
7. Update `docs/STATUS.md` with verified facts for this cycle only (do not rewrite old history) and the exact next slice. Commit owned changes with a specific message. Push only after tests pass and the worktree is clean.
8. Token-optimization rule (2026-09-03): whenever this cycle judges a pending item in `docs/feedback/INBOX.md` fully done (or fully human-gated — nothing left that code/assets/tests can do until the user approves/logs in/etc.), move it out of `## 처리 대기` into `## 처리 완료` immediately, in the same commit, with the completion evidence (or a "human-gated: still waiting on <specific user action>" note). Do not leave a finished/blocked item sitting in the pending section only to re-confirm "still human-gated, no change" again next cycle — every cycle after this one, and the human's periodic progress report, has to re-read whatever stays in `## 처리 대기`, so leaving stale entries there wastes tokens on every future cycle.

## Non-negotiable game rules

- Portrait internal canvas `180×320`; phone portrait is the product orientation.
- Earth is below and progression is upward. Free-roaming landscape exploration is superseded.
- Increasing height increases planet/sample value and risk.
- Fuel 0 starts automatic return; return distance controls slot opportunities.
- Planet collision damages durability.
- Durability 0 performs the full meta wipe, preserving only personal best height.
- Safe Earth return converts samples/slot rewards to money and permits ship purchase/upgrades.

## AetherAI-only asset rule

- Every final visual asset—ship, Earth, planets, samples, effects, slot symbols, shop icons, backgrounds—must come from the official AetherForgeAI/AetherAI UI/API or the remote GPU ComfyUI pipeline (`http://222.238.86.132:8188`, workflow IDs `7a3eb820-f17d-47ce-a337-da2358c2a0d5` / `5c257929-dff5-4ef4-bd1e-2c99dbbf3dee`).
- Never crawl, scrape, macro, or automate the AetherAI website.
- Never generate final art with Python/Pillow, Lua, another image model, or hand-authored raster scripts.
- 2026-09-03 update: the user human-gate on final art (waiting for manual AetherAI login/export) is removed. The loop may drive the ComfyUI HTTP API (`/prompt`, `/history`, `/view`) directly and self-judge quality (matches the object's intended silhouette/readability, no artifacts, runtime-legible at actual `1864×860` scale) instead of waiting on a manual approval. AetherAI import remains available whenever credentials appear; ComfyUI is an equally official path, not a fallback that needs later re-approval.
- 2026-09-03 update (generated asset reporting): the moment an AetherAI/ComfyUI asset is applied as final/runtime art (not a candidate), append one line to `docs/GENERATED_ASSET_LOG.md` in the same commit: `YYYY-MM-DDTHH:MM:SS+0900 | <repo-relative/path.png> | <one-line description>`. The 10-minute progress-report cron watches this file for new lines and forwards the actual image to the user. The path must be a real tracked file at that commit (no `.tmp/` or gitignored paths). Do not log candidates/superseded/QA-only art — only what the loop treats as final.
- Do not invent provenance. Official imports/generations require source/terms URL (AetherAI) or workflow path/prompt/seed/sampler settings (ComfyUI), generation/asset ID or output SHA-256, timestamp, dimensions, and runtime QA in the asset manifest — this is a quality record, not an approval gate.
- Report applied asset files/manifest paths back to the user (STATUS.md) instead of asking for approval.

## Safety and scope

- Work only in `/Users/jm/orca/workspaces/spaceship/main`.
- Do not access credentials or paid actions.
- Do not edit or stop the `man-of-korea` loop.
- Do not claim device QA without an actual device result.
- One fresh cycle owns the checkout at a time; respect `loop/STOP`.
