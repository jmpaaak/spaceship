# STATUS
- preflight this cycle: PASS.
- Slice: 항목15(c) Earth 상점 슬롯머신 은하별 오즈 순수 데이터 계층 구현.

## 구현 내용
항목15(c)("은하계마다 슬롯머신 오즈 변화")의 순수 데이터 계층을 `game/expedition.lua`에 신규 추가했다.

`M.earthSlotOddsProfiles` — 3종 오즈 프로파일(solar 표준형, fringe 중위험, void 고배당/고위험).
`M.homeGalaxies` — 홈 은하 whitelist(milkyway → solar 프로파일).
`M.galaxySlotOddsProfile(galaxyId)` — galaxyId 해시 mod 3으로 결정론적 프로파일 배정
  (nil/milkyway → "solar", 외부 은하 → fringe 2:1 / void 1:1 비율).
`M.earthSlotWeights(galaxyId)` — 해당 프로파일의 가중치 테이블 복사본 반환.
`M.earthSlotSpin(run, galaxyId, rolls)` — 3-릴 스핀 순수 함수.
  - 누적 가중치로 심볼(COMET/PLANET/STAR) 결정.
  - 항목14(C) luck 효과를 STAR 가중치에 (1+luckBonus) 배율로 적용.
  - {symbols, reward, totalWeight, effectiveStarWeight} 반환.
`M.exploreHub` 확장 — run.lastVisitedGalaxyId 기록 추가.

## 테스트 (TDD, RED → GREEN)
`game/self_test.lua`에 `testEarthSlotMachineGalaxyOdds()`를 추가했다:
1. galaxySlotOddsProfile: nil/milkyway → "solar", 외부 은하 → fringe/void 결정론성.
2. earthSlotWeights: fringe/void 프로파일의 STAR > solar STAR, COMET < solar COMET.
3. earthSlotSpin: 고정 롤로 COMET×3 심볼, 양수 reward, totalWeight 노출 확인.
4. luck 카드 장착 시 effectiveStarWeight > 기본 solar STAR.
5. exploreHub → lastVisitedGalaxyId 설정/갱신/같은 은하 반복 탐험 시 불변.

RED 확인 (`attempt to call field 'galaxySlotOddsProfile' (a nil value)`) → 구현 후 GREEN.

## 검증
`make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN (`SPACESHIP_UNIT_OK`,
`SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK`, `ASSET_MANIFEST_OK`).
변경 파일: `game/expedition.lua`/`game/self_test.lua`/`docs/STATUS.md`/`docs/feedback/INBOX.md`
(`play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua` 미변경).

항목15(a)(b) — 비행 중 슬롯머신 폐지 및 실제 settlement UI 재배치 — 는 play.lua 담당
(이 레인 스코프 밖). 이 레인의 순수 데이터 계층(슬롯 오즈 테이블 + 스핀 함수)은
play.lua 소비자가 `earthSlotSpin(run, run.lastVisitedGalaxyId, {reels=rolls})`를
호출하는 것만으로 완전히 동작하도록 설계되었다.

- Next slice: 항목13→9→10→12→14 잔여 gap 재감사 (이 레인의 반복 패턴), 또는 gear.lua/expedition.lua 추가 API 감사.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
