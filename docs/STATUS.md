# STATUS
- preflight this cycle: PASS.
- Slice: 항목9/10/14 `launchForecast` climbSpeed gap 배선.

## Gap 발견
`M.launchForecast(run, maxFuel)`이 항목10(b)/14(G)의 `fuelEfficiency` 배선
(이미 `M.effectiveFuelBurnRate(run)` 사용)과 달리 고도 계산 공식의 climbSpeed
항에서는 여전히 날 `run.climbSpeed`를 사용하고 있었다 — `M.effectiveClimbSpeed(run)`
(hull gear 태그-시너지-배율 climbSpeed 총합 + engine gear 가산 climbSpeed 포함)가
아니었다. 결과: 플레이어가 발사 전 loadout 화면에서 `hull_ember_core`(climbSpeed +5)
같은 hull 클라이밍 카드나 `engine_afterburner`(climbSpeed +6) 같은 엔진 카드를
장착해도 REACH N 예측 수치가 전혀 변하지 않았다 — 실제 비행에서는 `M.update()`가
이미 `M.effectiveClimbSpeed(run)`로 상승하는데 예측치만 날 기본값을 쓰는 불일치였다.

## 수정
`game/expedition.lua`의 `M.launchForecast`에서 `run.climbSpeed` 를
`M.effectiveClimbSpeed(run)`로 교체했다(1줄). `M.effectiveClimbSpeed`는 이미
이 파일에서 정의돼 있고 `M.launchForecast` 아래 있기 때문에 forward-reference가
생기지 않도록 함수 순서는 그대로 유지했다(Lua 로더 시점에 M.launchForecast는
호출 시점에 M.effectiveClimbSpeed를 참조하므로 선언 순서는 무관).

## 테스트 (TDD, RED → GREEN)
`game/self_test.lua`에 신규 `testGearLaunchForecastClimbSpeedGap()`을 추가했다:
- 미장착 baseline `launchForecast` 양수 확인
- `hull_ember_core`(climbSpeed +5) 장착 후 forecast 상승 확인
- forecast 비율이 정확히 `effectiveClimbSpeed/baseClimbSpeed`와 일치하는지 검증
- `engine_afterburner`(climbSpeed +6) 엔진 슬롯 장착 후 forecast 상승 확인 (engine-slot 도 반영)

RED 확인: `launchForecast must use effectiveClimbSpeed ... (baseline=1200, with gear=1200)`.
구현 후 GREEN.

## 검증
`make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN (`SPACESHIP_UNIT_OK`,
`SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
변경 파일: `game/expedition.lua`/`game/self_test.lua`/`docs/STATUS.md`/
`docs/feedback/INBOX.md` (`play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/
`game/engine_parts.lua` 미변경).

- Next slice: 항목13→9→10→12→14 잔여 gap 재감사, 또는 항목7/8/15 중 이 레인
  스코프 안의 순수 데이터/expedition 계층 슬라이스 선택.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
