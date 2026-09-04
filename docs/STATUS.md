# STATUS
- preflight this cycle: PASS.
- Slice: 항목7(b)/8 — hubExplored/lastVisitedGalaxyId safe-relaunch reset gap

## 구현 내용

Gap: `M.launch()`(settlement→ascending 안전 재발사)가 `run.hubExplored`와
`run.lastVisitedGalaxyId`를 초기화하지 않아, 이전 원정에서 방문한 은하 허브가
다음 원정에서도 "이미 탐사됨"으로 잠겼다. `destroy()`는 두 필드를 전체 메타
리셋의 일부로 초기화하지만, 안전 귀환 후 재발사 경로(`launch()`)에는 누락.

결과: 플레이어가 andromeda 허브를 한 번 안전하게 방문하고 지구로 돌아오면,
이후 어떤 원정에서도 `exploreHub("andromeda", pool)`이 즉시 `nil`을 반환해
허브 장비 드롭을 영구적으로 받을 수 없게 됐다(사망하기 전까지).

Fix: `launch()`의 재발사 블록(`if run.phase ~= "launch"`)에
`run.hubExplored = {}`, `run.lastVisitedGalaxyId = nil`을 추가.
`lastVisitedGalaxyId`는 Earth 상점 슬롯머신(settlement 중 실행)이 이미 읽은
후이므로, 새 원정 시작 시 nil이 맞다.

## 테스트 (TDD, RED → GREEN)
`testHubExploredResetsOnLaunch()` 신규 추가:
- 1차 원정에서 andromeda 허브 탐사 → drop 확인
- 같은 원정 내 중복 탐사 → nil 거부
- 안전 귀환(update altitude→0) → settlement
- launch from settlement → hubExplored["andromeda"] must be nil ← RED 확인
- lastVisitedGalaxyId must be nil after launch ← RED 확인
- 2차 원정에서 andromeda 탐사 → drop3 != nil (진짜 회귀 대상)
- destroy() 경로 hubExplored/lastVisitedGalaxyId 리셋 회귀 보호

RED 확인: "hubExplored must be nil for every galaxy after a safe relaunch
(was true)" (game/self_test.lua:3907)
GREEN: 구현 후 즉시 통과.

## 검증
`make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN (SPACESHIP_UNIT_OK,
SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:58, ASSET_MANIFEST_OK).
변경 파일: `game/expedition.lua`/`game/self_test.lua`
(`play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua` 미변경).

- Next slice: 항목13→9→10→12→14→15 잔여 gap 재감사, 또는
  earthSlotSpin engine-slot luck 카테고리 무관성 회귀 가드 추가.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다.
