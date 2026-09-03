# LANE SCOPE — gear

This worktree is one lane of a parallel multi-lane autonomous setup.
Work ONLY within this scope. Do not touch pending feedback items owned
by other lanes, and do not edit `docs/feedback/INBOX.md` items outside
your scope (append-only status notes to your own item are fine).

## Scope for this lane

이 레인은 오직 다음 INBOX 항목만, 이 순서로 처리한다: 항목13(부품 데이터 JSON 외부화 + tools/gear-editor/ 웹 에디터) -> 항목9(선체 부품 20~30종 + 시너지 엔진, game/gear.lua 신규) -> 항목10(엔진 부품 슬롯 분리, game/engine_parts.lua 신규) -> 항목12(등급/에디션 파밍 시스템) -> 항목14(효과 스키마 A~F 확장, 웹 에디터 폼 동기화). 이 레인은 game/scenes/play.lua, game/i18n.lua, game/world.lua, game/expedition.lua를 원칙적으로 건드리지 않는다(다른 레인 담당) -- 단, gear.lua/engine_parts.lua를 게임에 배선하기 위한 최소한의 로더 호출 추가는 예외로 허용한다. docs/feedback/INBOX.md 처리대기 섹션의 항목13/9/10/12/14 하위에만 진행상황을 append한다.

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
