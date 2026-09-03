# STATUS
## 항목 "국제화 누락 + 발라트로식 점수 연출 + HUD 약자 정리" — (1) "SOLAR SYSTEM" 하드코딩 i18n 이관 (완료, 2026-09-03)

preflight READY(engine tests/package PASS, git diff clean)로 시작. `git status --short`로 세션 시작 시 `game/i18n.lua`/`game/minimap.lua`/`game/scenes/play.lua`/`game/self_test.lua`/`game/world.lua`에 이전 사이클의 커밋되지 않은 작업이 이미 존재함을 확인했다 — `docs/feedback/INBOX.md` 처리대기 항목 "국제화 누락 + 발라트로식 점수 연출 + HUD 약자 정리 3건"의 (1)번("SOLAR SYSTEM" 미번역) 구현이 완결 직전 상태였다. 이 사이클은 이 작업을 이어받아 검증하고 마무리했다.

- `game/world.lua`의 `M.galaxy()`가 `\"SOLAR SYSTEM\"`/`\"GALAXY %d-%d\"` 문자열을 galaxy 테이블에 직접 담아 반환하던 것을 제거했다 — 홈 은하는 `id=\"milkyway\"`, 그 외는 `id=\"galaxy:%d:%d\"` + 좌표(`gx`/`gy`)만 남기고, 신규 순수 함수 `M.galaxyName(galaxy)`가 `i18n.t(\"galaxy_home\")`/`i18n.t(\"galaxy_named\", gx, gy)`로 로케일에 맞는 표시명을 조회하도록 분리했다.
- `game/i18n.lua`에 en/ko 두 로케일 모두 `galaxy_home`(`\"SOLAR SYSTEM\"`/`\"태양계\"`)과 `galaxy_named`(`\"GALAXY %d-%d\"`/`\"은하 %d-%d\"`) 키를 추가했다.
- 실제 표시 시점 세 곳 — `game/scenes/play.lua`의 `M:hudLines()`(HUD galaxy 라벨), `game/minimap.lua`의 `M.view()`(minimap galaxies 리스트/rings 배열, containing galaxy 이름) — 를 모두 `galaxy.name` 직접 참조에서 `world.galaxyName(galaxy)` 호출로 전환해, 화면에 보이는 은하 이름이 항상 i18n을 거치도록 통일했다.
- `game/self_test.lua`의 `testGalaxyStructure`에 (a) `home.name == nil`(하드코딩 문자열이 galaxy 테이블 자체에는 더 이상 남아있지 않음), (b) locale을 en/ko로 전환해가며 `world.galaxyName(home)`이 각각 `\"SOLAR SYSTEM\"`/`\"태양계\"`로 바뀜(실제로 i18n을 경유함을 증명), (c) `world.galaxyName(nil) == nil`(방어적 nil 처리) 회귀 테스트를 추가했다. `GAME_HEADLESS=1 GAME_UNIT=1 love .`로 RED(수정 전에는 `home.name`이 여전히 `\"SOLAR SYSTEM\"` 문자열이었음)를 먼저 확인한 뒤 GREEN 전환을 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:61`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 해당 처리대기 항목 아래에 이번 슬라이스 완료 로그를 append했다(항목 자체는 (2)(3)이 남아 있으므로 처리대기에 그대로 유지, 완료된 (1) 부분만 하위 로그로 기록).
- 다음 사이클 다음 슬라이스: 같은 항목의 (2) 발라트로식 점수 펀치 연출(`run.bestAltitude` 갱신 시 카운트업/스케일 펀치, `PlayScene.rollupAmount` 패턴 재사용) 또는 (3) `hud_status`(`\"H%d/%d %-6s S%02d\"`)의 `H%d/%d` 약자를 읽기 쉬운 라벨로 교체(항목 UI 대개편의 좌상단 내구도 상시 표시와 통합 검토 포함).

## preflight FAIL 수정: 레인 충돌로 제거된 game/gear.lua를 여전히 require하던 미커밋 game/scenes/play.lua diff 되돌림 (완료, 2026-09-03)

이번 사이클 preflight가 `engine tests and package: FAIL`(`game/scenes/play.lua:11: module 'game.gear' not found`)을 보고했다. 이것이 최우선 과제이므로 다른 작업보다 먼저 이 정확한 실패를 재현하고 수정했다.

- `git status --short`로 세션 시작 시 `game/scenes/play.lua`/`game/i18n.lua`에 커밋되지 않은 변경이 있음을 확인했다. 이 diff는 `M:drawGearStrip(y)`(장착된 기어 아이콘 스트립 렌더)와 `gear_label` i18n 키를 추가하며 `local gear = require("game.gear")`로 `game/gear.lua`를 require하고 있었다.
- 그러나 직전 커밋 `dfa2da2`(\"fix: resolve lane conflict on game/gear.lua (item 6 -> gear lane)\")가 이미 `game/gear.lua`와 그 회귀 테스트를 의도적으로 삭제했다 — `docs/feedback/INBOX.md` 6번 항목의 \"⚠️ 레인 충돌 통보\" 문구가 명시하듯 이 경로는 이제 `spaceship-gear` 레인이 JSON 데이터 로더(`game/data/hull_parts.json`/`engine_parts.json`)로 재작성 중이며 **main 레인은 앞으로 `game/gear.lua`를 건드리지 않는다**고 못박혀 있다. 세션 시작 시 미커밋 상태로 남아있던 `drawGearStrip` diff는 이 레인 재배정 이전(또는 이를 무시하고) 작성된 고아 상태 작업으로, `game/gear.lua`가 사라진 채로 남아 require 실패를 그대로 유발하고 있었다.
- 수정 경로로 (a) `game/gear.lua`를 main 레인에서 재생성하는 방법과 (b) 고아 diff를 되돌리는 방법을 검토했다. INBOX.md의 명시적 레인 재배정 통보를 존중해 (b)를 선택했다 — `git checkout -- game/scenes/play.lua game/i18n.lua`로 두 파일을 직전 커밋(`dfa2da2`) 상태로 되돌렸다. 이 되돌림은 어떤 완료된 작업도 덮어쓰지 않는다: `drawGearStrip`/`gear_label`은 세션 시작 시점에 이미 이번 사이클 이전 어떤 커밋에도 존재하지 않았던 순수 미커밋 diff였다.
- `git status --short`가 되돌림 후 완전히 clean함을 확인(worktree == HEAD, 커밋할 코드 변경 없음).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`) — preflight가 보고한 정확한 `module 'game.gear' not found` 실패가 재현되지 않고 해소됨을 확인했다.
- 이번 슬라이스는 preflight 실패 원인 진단·제거만 수행했다(신규 게임 로직/UI 변경 없음, 코드 diff 없음 — `docs/STATUS.md` 갱신만 커밋 대상). 다음 사이클이 6번 항목의 UI 노출(예: 장착된 기어를 HUD에 아이콘으로 보여주는 작업)을 다시 시도하려면, main 레인이 아니라 `spaceship-gear` 레인의 최신 `game/gear.lua`(JSON 데이터 로더 기반, `game.gear.equipped`/`game.gear.cardCount` API가 바뀌었을 수 있음) 구조에 맞춰 새로 설계해야 한다.
- 다음 사이클 다음 슬라이스: 11번 항목의 남은 부분(a: `launchForecastLine`/`M.launchForecast`의 연료-종속 프레이밍 재정의 — `game/expedition.lua:142`), 또는 3번 항목(속도/스피드미터 아이콘화는 이미 완료 표시가 있으나 재검토 필요할 수 있음), 또는 4번(불필요한 텍스트 제거 검토, 거의 완료). 6번/7번/8번/9번/10번/11(c)/12번/13번/14번 항목은 `spaceship-gear`/`spaceship-econ` 레인이 별도로 진행 중이므로 main 레인은 이 경로들(`game/gear.lua` 등)을 건드리지 않는다.
## 항목 11(c) — 죽은 연료 조종 함수 `maneuverFuel`/`burnManeuverFuel` 제거 (완료, 2026-09-03)

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

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
