# LANE SCOPE — main

This worktree is the only Spaceship autonomous loop
(`/Users/jm/orca/workspaces/interactive-story-game-factory/spaceship`). `spaceship-gear` was merged
into `main` on 2026-09-04 (items 7/8/9/10/11/12/13/14/15). Process
`docs/feedback/INBOX.md` pending items from the top. Commit and push to
`main` after tests pass. Do not resurrect parallel lanes unless new
INBOX work is explicitly split.

---

# Spaceship autonomous development brief

## First priority

Build the playable portrait-mobile roguelite specified in `docs/feedback/INBOX.md` and `docs/GAME_DESIGN.md`:

`launch → ascending → fuel-empty return/slots → Earth settlement/shop → relaunch`.

Durability destruction must wipe unbanked samples, money, purchased ship, and upgrades while preserving only all-time maximum height.


**중요 — 재감사 방지 규칙:** 이번 사이클에서 처리할 INBOX 항목이 이미 이전 사이클에서 완료됐다고 판단되면, STATUS.md 업데이트 없이 즉시 다음 미완료 항목으로 넘어가라. "이미 완료됐음을 재확인"하는 문서 커밋을 반복하지 않는다. 할 일이 없으면 IDLE로 종료한다.
**중요 — FAIL + 미커밋 변경 규칙:** preflight가 FAIL이고 git status에 수정된 파일이 있으면, 이번 사이클의 유일한 작업은 (1) 실패한 테스트를 수정하고 (2) 모든 수정 파일을 커밋하는 것이다. 새 INBOX 항목 작업을 시작하지 않는다. 미커밋 변경을 버리지 않는다 — 이전 사이클이 절반만 완료한 것을 마저 끝낸다.

**중요 — 한 사이클 한 조각:** 큰 INBOX 항목(ComfyUI 에셋 생성, 전면 UI 개편 등)을 한 사이클에 다 끝내려 하지 마라. 사이클당 검증 가능한 최소 단위 하나만 완료하고 커밋한다.
- ComfyUI: 장면 1개 또는 에셋 1~3장만 생성·catalog/로그 반영·커밋. 다음 장면은 다음 사이클.
- 큰 기능: (a)/(b)/(c) 중 한 소항목, 또는 한 파일의 한 동작만. GREEN+커밋 전에 다음 소항목을 시작하지 마라.
- 이 사이클 턴 한도 안에 커밋할 수 없으면 범위를 더 줄여라. 미커밋으로 턴을 다 쓰는 것은 금지 — 중간이라도 동작하는 조각을 커밋하라.


## Required workflow

1. Read only the pending feedback, game design, and current status needed for this cycle. Do not read `docs/STATUS.md` in full — latest `##` section plus next slice only. Do not read `docs/STATUS_HISTORY.md` unless tracking a specific past bug.
   **TOKEN RULE: Do NOT read `docs/feedback/INBOX.md` in full. The cycle prompt already contains pending item titles. Read only the specific item you are implementing this cycle** (use offset/limit or search to extract only that item's section — do not load the entire file).
   **TOKEN RULE (large files):** Never `read_file` a source file ≥80KB without `offset`+`limit`. Especially `game/self_test.lua` and `game/scenes/play.lua`. Use `search_files` for the symbol, then read ≤80 lines around the match. A full-file read stays in context for every remaining turn of this oneshot cycle — that is the real token waste, not `--oneshot` itself.
2. Run `git status --short` before editing. Preserve and finish prior-cycle work; do not overwrite it.
3. If preflight reports FAIL, reproduce and fix that exact failure first.
4. Otherwise choose one small user-visible or state-machine slice from the top pending requirement.
5. Use test-driven development: add a failing engine-hosted test, observe RED, implement, then run focused GREEN tests.
6. Run `make verify LOVE=/Users/jm/.local/bin/love` before a checkpoint commit.
7. Update `docs/STATUS.md` with verified facts for this cycle only (do not rewrite old history) and the exact next slice. Commit owned changes with a specific message. Push only after tests pass and the worktree is clean.
8. Token-optimization rule (2026-09-03): whenever this cycle judges a pending item in `docs/feedback/INBOX.md` fully done (or fully human-gated — nothing left that code/assets/tests can do until the user approves/logs in/etc.), move it out of `## 처리 대기` into `## 처리 완료` immediately, in the same commit, with the completion evidence (or a "human-gated: still waiting on <specific user action>" note). Do not leave a finished/blocked item sitting in the pending section only to re-confirm "still human-gated, no change" again next cycle — every cycle after this one, and the human's periodic progress report, has to re-read whatever stays in `## 처리 대기`, so leaving stale entries there wastes tokens on every future cycle.

## Non-negotiable game rules

- Portrait internal canvas `720×1280` (9:16, Balatro-level pixel density — the old `180×320` is too low and is superseded); phone portrait is the product orientation.
- Earth is below and progression is upward. Free-roaming landscape exploration is superseded.
- Increasing height increases planet/sample value and risk.
- Fuel 0 starts automatic return; return distance controls slot opportunities.
- Planet collision damages durability.
- Durability 0 performs the full meta wipe, preserving only personal best height.
- Safe Earth return converts samples/slot rewards to money and permits ship purchase/upgrades.

## Asset generation rule (2026-09-05 updated)

- **ComfyUI는 더 이상 사용하지 않는다.** 모든 도트 그래픽 에셋은 다음 두 방식으로 생성한다:
  - (1) 배경·큰 에셋: Python PIL/Pillow 스크립트 (`tools/` 아래 저장, 50줄 이내, 도형·패턴·노이즈 함수 조합, 수천 줄 하드코딩 픽셀 좌표 금지)
  - (2) 작은 스프라이트·아이콘: LÖVE `love.graphics`로 그려서 PNG 저장
- 사용자가 직접 제공하겠다고 한 에셋(함선/지구/행성, 사람 스프라이트)은 자동 생성 금지. 해당 에셋이 올 때까지 기존 다각형 폴백 유지.
- 라이선스 팩(PixelPlanets stars 등)은 계속 사용.
- 생성된 에셋을 최종 적용하는 순간, 같은 커밋에서 `docs/GENERATED_ASSET_LOG.md`에 한 줄 append (`YYYY-MM-DDTHH:MM:SS+0900 | <path.png> | <description>`).
- PIL 스크립트는 `tools/` 아래에 저장해서 재현 가능하게 한다. 같은 seed → 같은 결과.
- Report applied asset files/manifest paths back to the user (STATUS.md) instead of asking for approval.

## Safety and scope

- Work only in `/Users/jm/orca/workspaces/interactive-story-game-factory/spaceship`.
- Do not access credentials or paid actions.
- Do not edit or stop the `man-of-korea` loop.
- Do not claim device QA without an actual device result.
- One fresh cycle owns the checkout at a time; respect `loop/STOP`.
