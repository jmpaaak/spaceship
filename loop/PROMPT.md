# LANE SCOPE — econ

This worktree is one lane of a parallel multi-lane autonomous setup.
Work ONLY within this scope. Do not touch pending feedback items owned
by other lanes, and do not edit `docs/feedback/INBOX.md` items outside
your scope (append-only status notes to your own item are fine).

## Scope for this lane

이 레인은 오직 다음 INBOX 항목만, 이 순서로 처리한다: 항목7(장비 획득 경로 3원화 -- 상점행성/체크포인트확정드롭/지구상점) -> 항목8(행성탐사=표본만, 정산은 체크포인트/지구에서만) -> 항목11(연료 소진 관련 UI/문구 잔재 전면 제거) -> 항목15(귀환/비행중 슬롯머신 폐지, 지구상점 전용 슬롯머신 은하계별 오즈). 이 레인은 주로 game/world.lua, game/expedition.lua를 수정한다. game/scenes/play.lua의 텍스트/HUD 세부 표현은 메인 레인 담당이므로 최소한의 구조적 변경(신규 화면/버튼 추가 등 불가피한 경우)만 하고 기존 텍스트 정리는 건드리지 않는다. docs/feedback/INBOX.md 처리대기 섹션의 항목7/8/11/15 하위에만 진행상황을 append한다.

## Branch and push discipline

- This lane commits and pushes ONLY to branch `spaceship-econ`. Never push to
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

- Every final visual asset—ship, Earth, planets, samples, effects, slot symbols, shop icons, backgrounds—must come from the official AetherForgeAI/AetherAI UI or official API.
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
