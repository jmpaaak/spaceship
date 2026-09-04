# LANE SCOPE — gear

This worktree is one lane of a parallel multi-lane autonomous setup.
Work ONLY within this scope. Do not touch pending feedback items owned
by other lanes, and do not edit `docs/feedback/INBOX.md` items outside
your scope (append-only status notes to your own item are fine).

## Scope for this lane

이 레인은 INBOX 처리 대기의 **모든 항목**을 처리한다 (이 레인이 현재 유일한 활성 레인이므로). 우선순위 순서:
- 항목 7 (함선 장비 획득 경로 3원화)
- 항목 8 (행성 탐사 보상은 표본만, 정산은 체크포인트에서만)
- 항목 11 (연료 소진 관련 잔재 UI/문구 전면 제거)
- 항목 15 (귀환 페이즈 및 비행 중 슬롯머신 폐지 + 지구 상점 전용 슬롯머신)
- 항목 9/10/12/13/14 — 이미 완료됨, 추가 감사 불필요

항목 11/15는 `game/scenes/play.lua`, `game/i18n.lua`를 반드시 수정해야 하므로 이 레인에서 예외적으로 허용한다. 항목 7/8은 `game/world.lua`, `game/expedition.lua`를 수정해야 하므로 마찬가지로 허용한다.

**중요: 이미 완료된 항목(13/9/10/12/14)은 재감사하지 않는다. 남은 항목(7/8/11/15) 중 하나를 골라 실제 코드 작업을 진행하라.**

## Branch and push discipline

- This lane commits and pushes ONLY to branch `spaceship-gear`. Never push to
  `main`/`master` directly, never force-push.
- A separate integration step periodically merges this branch into
  the base branch after `make verify` passes.

---

# Spaceship autonomous development brief

## First priority

Build the playable portrait-mobile roguelite specified in `docs/feedback/INBOX.md` and `docs/GAME_DESIGN.md`:

`launch → ascending → fuel-empty return/slots → Earth settlement/shop → relaunch`.

Durability destruction must wipe unbanked samples, money, purchased ship, and upgrades while preserving only all-time maximum height.

## Required workflow

1. Read only the pending feedback, game design, and current status needed for this cycle. Do not read `docs/STATUS.md` in full — latest `##` section plus next slice only. Do not read `docs/STATUS_HISTORY.md` unless tracking a specific past bug.
   **TOKEN RULE: Do NOT read `docs/feedback/INBOX.md` in full. The cycle prompt already contains pending item titles. Read only the specific item you are implementing this cycle** (use offset/limit or search to extract only that item's section — do not load the entire 150KB file).

2. Run `git status --short` before editing. Preserve and finish prior-cycle work; do not overwrite it.
3. If preflight reports FAIL, reproduce and fix that exact failure first.
4. Otherwise choose one small user-visible or state-machine slice from the top pending requirement.
5. Use test-driven development: add a failing engine-hosted test, observe RED, implement, then run focused GREEN tests.
6. Run `make verify LOVE=/Users/jm/.local/bin/love` before a checkpoint commit.
7. Update `docs/STATUS.md` with verified facts for this cycle only (do not rewrite old history) and the exact next slice. Commit owned changes with a specific message. Push only after tests pass and the worktree is clean.

## Non-negotiable game rules

- Portrait internal canvas `180×320`; phone portrait is the product orientation.
- Earth is below and progression is upward. Free-roaming landscape exploration is superseded.
- Increasing height increases planet/sample value and risk.
- Fuel 0 starts automatic return; return distance controls slot opportunities.
- Planet collision damages durability.
- Durability 0 performs the full meta wipe, preserving only personal best height.
- Safe Earth return converts samples/slot rewards to money and permits ship purchase/upgrades.

## AetherAI-only asset rule

- Every final visual asset—ship, Earth, planets, samples, effects, slot symbols, shop icons, backgrounds—must come from the official AetherForgeAI/AetherAI UI or official API, or the remote GPU ComfyUI pipeline (`http://222.238.86.132:8188`, workflow IDs `7a3eb820-f17d-47ce-a337-da2358c2a0d5` / `5c257929-dff5-4ef4-bd1e-2c99dbbf3dee`).
- Never crawl, scrape, macro, or automate the AetherAI website.
- Never generate final art with Python/Pillow, Lua, another image model, or hand-authored raster scripts.
- Until an official export and receipt exist, simple Lua shapes may remain only as visibly documented `DEV PLACEHOLDER` gameplay geometry. Do not call them final assets or visual QA.
- Do not invent provenance. Official imports require source/terms URL, generation/asset ID, prompt/model/style/settings, timestamp, original SHA-256, dimensions, and runtime QA.
- If login/export is unavailable, mark art human-gated and continue non-asset gameplay, tests, persistence, balancing, touch input, packaging, and UI layout work.

## Safety and scope

- Work only in `/Users/jm/orca/workspaces/interactive-story-game-factory/spaceship`.
- Do not access credentials or paid actions.
- Do not edit or stop the `man-of-korea` loop.
- Do not claim device QA without an actual device result.
- One fresh cycle owns the checkout at a time; respect `loop/STOP`.
