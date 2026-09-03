# STATUS

## 세션 시작 시 남아있던 미커밋 항목 11(a) 최종 슬라이스 검증 및 커밋 — 레인 스코프(7→8→11→15) 4개 항목 전부 완료 확인 (2026-09-03)

preflight READY(`engine tests and package` PASS, `git diff` clean이라고 보고되었으나, 실제 `git status --short`에는 `docs/STATUS.md`/`docs/STATUS_HISTORY.md`/`game/expedition.lua`/`game/scenes/play.lua`/`game/self_test.lua` 5개 파일에 이전 사이클의 미커밋 diff가 존재했다). 검토 결과 이는 항목 11(a) — `M.launchForecast(run, maxFuel)`을 `M.rangeForecast(run, capacity)`로 리네이밍(옛 이름/파라미터가 "이 연료가 다하면 위험" 프레이밍을 내포해 alias 없이 완전 삭제)하고 `game/scenes/play.lua`의 `launchForecastLine` 호출부를 갱신한 여섯 번째(최종) 슬라이스로, 이미 `game/self_test.lua`에 `expedition.launchForecast == nil` / `expedition.rangeForecast`가 동일 계산값(altitude 600, slots 6)을 반환함을 검증하는 회귀 테스트까지 포함된 완결 상태였다. `docs/feedback/INBOX.md`에도 이미 이 슬라이스가 "✅ 2026-09-03(여섯 번째 슬라이스, 최종 완결)"로 기록되어 있어 중복 작업이 아님을 확인했다.

- `GAME_HEADLESS=1 GAME_UNIT=1 love .`, `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`) 재확인 후 그대로 커밋했다 — 코드 변경 없이 이전 사이클 결과를 이어받아 검증·커밋만 수행.
- `docs/feedback/INBOX.md`를 재확인한 결과 이 레인(econ) 스코프 순서(항목7→8→11→15) 4개 항목이 모두 `✅ 완료(econ 레인, 2026-09-03)` 마커로 표시되어 있음을 재확인했다: 항목7(a/b/c 장비 획득 경로 3원화), 항목8(체크포인트 정산), 항목11(a/b/c 연료 잔재 전면 제거, 이번 커밋으로 (a) 최종 슬라이스까지 반영), 항목15(a/b/c 귀환/비행중 슬롯머신 폐지 + 지구상점 전용 슬롯머신).
- **레인 스코프 소진 확인(재확인):** `loop/PROMPT.md`가 이 레인에 지정한 4개 항목이 전부 완료되어 이 레인이 자체적으로 착수할 다음 슬라이스가 없다. 다음 사이클은 `loop/PROMPT.md` 갱신(다른 pending 항목으로 스코프 재배정) 또는 사용자 확인을 대기해야 하며, 레인 스코프 밖 항목(9/10/12/13/14 등, gear 레인 등 다른 레인 소유)을 임의로 착수하지 않는다.
- `docs/feedback/INBOX.md`는 이미 항목 7/8/11/15가 완료 표시되어 있어 이번 사이클에서 추가로 append할 새 항목 상태 변경이 없었다(진행상황 로그는 이전 사이클이 이미 기록 완료).

## 항목 11 (c) 세 번째 슬라이스 (완료, 2026-09-03)
`docs/feedback/INBOX.md` 처리대기 항목 11(연료 소진 관련 UI/문구 잔재 전면 제거)의 (c) 부분의 세 번째 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작. 이 사이클은 이 레인(econ)의 스코프 순서(항목7→8→11→15) 중 항목 11을 이어서 진행했다.

- `game/expedition.lua`의 `M.maneuverFuel(run, extraDistance)`/`M.burnManeuverFuel(run, extraDistance)`는 "Fuel is no longer a flight constraint"가 된 이후로 항상 `return 0`만 반환하며 어떤 상태도 건드리지 않는 영구 no-op 셸이었다. 유일한 실사용 호출부는 `game/scenes/play.lua`의 조이스틱 추가-거리 계산이 `thrusting`일 때 `expedition.burnManeuverFuel(...)`을 호출(반환값 버려짐)하는 죽은 코드였다.
- 두 함수를 `game/expedition.lua`에서 완전히 제거하고, `game/scenes/play.lua`에서 그 죽은 호출과 그 계산에만 쓰이던 `extraDx`/`extraDistance`/`startX` 로컬 변수를 함께 제거했다(실제 이동 계산에 쓰이는 `extraDy`/`startOffset`/`thrusting`은 그대로 유지). `game/scenes/play.lua`의 텍스트/HUD 세부 표현은 이 레인 스코프 규칙에 따라 건드리지 않았고, 불가피한 최소 구조적 죽은코드 제거만 수행했다.
- `game/self_test.lua`의 `testManeuverFuel`을 `expedition.maneuverFuel == nil`/`expedition.burnManeuverFuel == nil`(죽은 API가 셸로도 남아있지 않음을 검증)로 갱신했다(수정 전 옛 단언이 여전히 두 함수 호출을 가정해 RED 확인 후 구현, GREEN 전환 확인).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md` 처리대기 항목 11 하위에 이번 슬라이스 진행 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목 11의 남은 부분 — (a) `launchForecastLine`/`forecast_line`의 연료 기반 프레이밍 텍스트 재정의(메인 레인 텍스트 영역과 조율 필요), (b) `game/expedition.lua`의 `run.maxFuel`/`fuelUpgradeLevel`/`fuelUpgradeCost`/`fuelUpgradeAmount`/`fuelBurnRate`/`run.fuel` 등 연료 업그레이드 엔진 로직/필드 제거 또는 재정의. 이후 이 레인 스코프 순서대로 항목 15(귀환/비행중 슬롯머신 폐지, 지구상점 전용 슬롯머신 은하계별 오즈)로 진행.

## preflight FAIL 수정: item 11(b) fuelUpgradeLevel 필드 제거 후 갱신되지 않은 self_test.lua REACH/SLOTS 단언 3건 수정 (완료, 2026-09-03)

이번 사이클 preflight가 `engine tests and package: FAIL`(`game/self_test.lua:1637: assertion failed!`)을 보고했다. 이것이 최우선 과제이므로 다른 작업보다 먼저 이 정확한 실패를 재현하고 수정했다.

- `git status --short`로 세션 시작 시 `game/expedition.lua`/`game/self_test.lua`/`main.lua`/`docs/*.md`에 이전(이 econ 레인) 사이클의 커밋되지 않은 항목 11(b) 작업(연료탱크 상점 업그레이드 `buyFuelUpgrade`/`fuelUpgradeLevel`/`fuelUpgradeCost`/`fuelUpgradeAmount`를 `game/expedition.lua`에서 완전 제거)이 이미 존재함을 확인했다. 이 작업은 완결 직전 상태로 보여 그대로 보존했다.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .`로 정확한 실패를 재현: `game/self_test.lua:1637`의 `assert(shopScene.message == "SCOUT PURCHASED AND SELECTED  HULL 3  REACH 960  SLOTS 10  BALANCE $20")`가 실패했다. 원인은 이전 사이클이 `fuelUpgradeLevel` 필드를 제거하면서 SCOUT 구매 전에 연료탱크를 미리 사두던(`shopScene.expedition.money`를 올려 `expedition.buyFuelUpgrade`를 호출) 준비 코드를 함께 삭제했으나, 그 결과로 바뀐 `maxFuel`(연료탱크 미구매 → SCOUT 보너스만 적용된 `100+40=140`)에 맞춰 REACH/SLOTS 예상 문자열은 갱신하지 않은 채로 옛 값(`REACH 960 SLOTS 10`, 연료탱크 구매분 포함)이 그대로 남아있었기 때문이다.
- 계산 검증(`forecastAltitude = maxFuel / fuelBurnRate * climbSpeed = 140/5*30 = 840`, `slots = ceil(840/100) = 9`)을 거쳐 `game/self_test.lua:1637-1638`의 단언을 `"SCOUT PURCHASED AND SELECTED  HULL 3  REACH 840  SLOTS 9  BALANCE $20"`로 갱신했다.
- 동일 근본 원인의 두 번째 잔재를 `game/self_test.lua:1945-1950`(NEXT LAUNCH 프리뷰의 STARTER/SCOUT 재선택 메시지)에서도 발견 — `"STARTER SELECTED HULL 4 REACH 720 SLOTS 8"`/`"SCOUT SELECTED HULL 3 REACH 960 SLOTS 10"`도 같은 옛 연료탱크-포함 계산이었다. STARTER(연료탱크 없이 base 100) `REACH 600 SLOTS 6`, SCOUT(140) `REACH 840 SLOTS 9`로 갱신했다.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` 재실행으로 `SPACESHIP_UNIT_OK`/`SPACESHIP_SMOKE_OK` 확인, `make test`(엔진 유닛 + `tools.test_verify_asset_manifest` 9건) 전체 GREEN, `make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`) 확인했다. 이 슬라이스는 이전 사이클 diff의 단언 문자열만 계산값에 맞춰 갱신한 것으로 신규 게임 로직/화면 변경이 없어 런타임 캡처는 필요하지 않았다.
- 이 econ 레인의 스코프 순서(항목7→8→11→15) 상 항목 11(b)는 이제 완결(연료탱크 상점 업그레이드가 엔진 API/필드 수준에서 완전히 제거되고 관련 테스트도 모두 GREEN)로 보인다.
- 다음 사이클 다음 슬라이스: 이 레인 스코프 순서상 항목 11의 나머지(있다면 `run.fuel`/`fuelBurnRate`/`run.maxFuel` 등 여전히 활성 게임플레이에 쓰이는 필드는 유지하고 죽은 잔재만 마저 정리) 확인 후, 항목 15(귀환/비행중 슬롯머신 폐지, 지구상점 전용 슬롯머신 은하계별 오즈)로 진행.

## 항목 15(a) 정찰 슬라이스 — 코드 변경 없음, 다음 사이클 실행 계획만 확정 (2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 마지막으로 남은 항목 15(a) — 옛 `beginReturn`/`"returning"` 페이즈/in-flight `slotSpin`·`useSlot`의 완전 폐지 — 를 이번 사이클에 실제로 착수하려 했다. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- `game/expedition.lua`(`M.beginReturn`/`M.useSlot`/`spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`와 그 상수, `M.update`의 `"returning"` 분기, `settle()`/`destroy()`/`M.new()`/`M.launch()`의 관련 필드 초기화·리셋), `game/scenes/play.lua`(`returnControls`, `slotButtonState`/`beginSlotSpin`/`currentSlotReels`, `collisionRisk`/`approachWarning`/`hudLines`/`pollDesktopMouse`/`M:update`의 이동·충돌 블록/`keypressed`의 space-bar 슬롯 분기/`touchpressed`의 return-band 처리/`drawMinimap`의 odds 줄/`draw()`의 returning 전용 슬롯 UI 블록, `M.hudOddsLineHeight`/`M.hudHeight`의 returning 분기), `main.lua`(`returning-odds`/`returning-repair`/`returning-fuelbonus`/`returning-samplebonus`/`full-loop-relaunch` 5개 `GAME_CAPTURE_PHASE` 하네스), `game/self_test.lua`(`expedition.beginReturn`/`expedition.useSlot` 호출부 다수, `testReturnToEarthUiWiring`의 "beginReturn 경로 보존" 검증)를 전부 재확인해 이전 사이클(`logs/loop-2026-09-03.log`)의 추적 결과가 여전히 정확함을 검증했다.
- 이 재확인 과정에서 `expedition.slotReward`/`weightedSlotSymbol`/`slotExpectedValue`/`slotSymbolProbability`는 LAUNCH LOADOUT/EARTH SHOP의 `slotOddsLine` 미리보기와 `spinEarthShopSlot`(항목 15b/c, EARTH SHOP 전용 슬롯머신, 이미 완료)이 계속 사용하므로 15(a) 제거 대상이 **아니며**, `spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`(그리고 이들의 in-flight 전용 소비자인 `M.useSlot`)만 returning 전용이라 제거 대상임을 새로 명확히 확정했다. 이 구분을 정확히 하지 않고 편집을 시작했다면 이미 완료된 EARTH SHOP 슬롯머신(15b/c)까지 회귀시킬 위험이 컸다.
- **이번 사이클은 코드 변경을 내지 못했다.** 위 재확인 작업 자체가 안전한 편집을 위한 필수 선행 단계였고, 시간 예산이 여기서 소진되어 실제로 커밋 가능한 diff를 만들기 전에 중단했다. `game/expedition.lua`/`game/scenes/play.lua`/`main.lua`/`game/self_test.lua`에 대한 실제 코드 diff는 이번 사이클에 전혀 없다.
- `make test`를 재실행해 코드가 변경되지 않았음을 확인했다 — `SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `tools.test_verify_asset_manifest` 9건 모두 GREEN(직전 사이클과 동일 상태 유지).
- `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 정찰 슬라이스 기록과, 다음 사이클이 그대로 실행할 수 있는 4단계 슬라이스 계획(엔진→UI→하네스→테스트, 매 슬라이스마다 `make test` GREEN 확인)을 append했다.
- 다음 사이클 다음 슬라이스: 위 INBOX.md에 기록한 4단계 계획의 (1)부터 순서대로 — 먼저 `game/expedition.lua`에서 `M.beginReturn`/`M.useSlot`/`spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`와 관련 상수/필드만 제거(EARTH SHOP 슬롯 관련 API인 `M.slotReward`/`M.weightedSlotSymbol`/`M.slotExpectedValue`/`M.slotSymbolProbability`는 절대 건드리지 말 것)하고 `make test`로 GREEN 확인 후 커밋, 그 다음 슬라이스에서 `game/scenes/play.lua`의 UI/터치/키 입력을, 그 다음 `main.lua`의 캡처 하네스를, 마지막으로 `game/self_test.lua`의 테스트 단언을 정리한다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
