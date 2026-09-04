# STATUS
- preflight this cycle: PASS.
- Slice: 항목15(c) follow-up — per-profile reward TABLE variation
  (earthSlotSpin triple-STAR jackpot now scales by galaxy profile).

## 구현 내용

Gap: `earthSlotSpin.reward`가 global 고정 `slotReward` 함수를 profile과 무관하게
사용하고 있었다. void profile "고배당/위험부담형" 약속이 STAR 가중치 상향으로만
절반 이행됐고, 잭팟 금액 자체는 solar와 동일한 75였다 — 항목15 원문 "보상
테이블이 달라지도록"을 충족하지 못한 gap.

`M.earthSlotRewardMultipliers` 신규 테이블(solar=×1.0 / fringe=×1.5 / void=×2.0)과
local `earthSlotReward(symbols, profile)` 함수(triple-STAR에만 배율 적용, 나머지는
global slotReward 그대로)를 추가했다. `M.earthSlotSpin`이 upfront에서 profile을
결정하고 `earthSlotReward`를 호출하도록 변경했다.

실제 잭팟 금액:
- solar:  STAR×3 = 75 (기존과 동일)
- fringe: STAR×3 = 112
- void:   STAR×3 = 150

리스크 트레이드오프: 비-STAR 조합(PLANET triple, pair, miss)은 모든 profile에서
동일 — 진정한 "high-risk-high-reward" 설계.

결과 테이블에 `rewardProfile` 필드("solar"/"fringe"/"void")를 추가해
UI가 활성 profile 뱃지를 표시할 수 있도록 했다.

## 테스트 (TDD, RED → GREEN)
`testEarthSlotProfileRewardVariation()` 신규 추가:
(a) solar triple-STAR == 75 (기존 파리티)
(b) void triple-STAR > solar
(c) fringe triple-STAR > solar, <= void
(d) rewardProfile 필드 검증
(e) void no-match <= solar no-match (리스크 트레이드오프)

RED 확인: "void triple-STAR jackpot (75) must exceed solar (75)" → 구현 후 GREEN.

## 검증
`make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN (SPACESHIP_UNIT_OK,
SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:61, ASSET_MANIFEST_OK).
변경 파일: `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/
`docs/STATUS.md`/`docs/feedback/INBOX.md`
(`play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua` 미변경).

- Note: The primary Codex request exhausted its rate limit before committing. This Gemini fallback cycle audited the uncommitted state, verified tests pass, and pushed the commit.
- Next slice: 항목13→9→10→12→14→15 잔여 gap 재감사 (특히 UI 연동 전 순수 데이터 계층에서 누락된 부분), 또는 이 레인의 완료 선언(실제 소비 UI는 타 레인 스코프).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다.
