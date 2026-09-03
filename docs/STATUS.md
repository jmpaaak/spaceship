# STATUS
## 내부 해상도 720×1280 상향 — HUD/터치/미니맵/조이스틱/폰트/상점/지구/로드아웃 ×4 (완료, 2026-09-03)

preflight READY. INBOX 최우선 해상도 항목의 두 번째 슬라이스: 720×1280 캔버스에 남아 있던 180×320 절대 픽셀 레이아웃을 ×4 했다.

- TDD: `game/self_test.lua`에 `testCanvasLayoutScale()`을 먼저 추가해 RED(`assertion failed` at settlementTouchRows 752/928)를 확인한 뒤 구현.
- 터치: `settlementTouchRows` 752–1280(반폭 360), `returnControls` 976–1152 / slot 240–480, `ascendControls` 동일 밴드. 회귀 탭 `90,244`/`90,266` 등을 새 히트박스 안으로 옮김.
- 비주얼: `minimap.size` 48→192, 조이스틱 24/160/56, HUD 높이 280/184/136, 폰트 32/56/28, 아이콘 ×4, 상점 컬럼 ×4, 지구 `earthCenterY=300`/`earthRadius=232`, 로드아웃 박스 top 808, 상점/파괴/슬롯 패널 좌표 ×4.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:64`, `ASSET_MANIFEST_OK`).
- 항목은 행성 스프라이트 재생성/논리 크기와 일부 장식 px가 남아 `docs/feedback/INBOX.md` 처리대기에 유지.

다음 사이클 다음 슬라이스: 행성(및 깨진 우주선) 스프라이트 ComfyUI 재생성 또는 논리 크기 상향. 미니맵 마커 점 반경·플로팅 텍스트 박스는 남은 장식 px. econ/gear 레인 소유 항목과 `game/gear.lua`는 건드리지 않는다.

## 내부 해상도 720×1280 상향 — viewport+conf+회귀 단언 (완료, 2026-09-03)

preflight READY(engine tests/package PASS, git diff check PASS). 세션 시작 시 `docs/GAME_DESIGN.md`/`loop/PROMPT.md`/`docs/feedback/INBOX.md`/`loop/env.sh`에 이전 사이클의 미커밋 문서 작업이 이미 있었다(해상도 비협상 규칙 문구를 `720×1280`으로 바꿔 둔 상태, env idle timeout 600s). 이 작업을 보존하고, INBOX 최우선 항목 「내부 해상도를 발라트로 수준으로 상향」의 첫 슬라이스(viewport+conf+회귀 테스트 단언)를 구현했다.

- TDD: `game/self_test.lua`의 `assert(viewport.width == 180 and viewport.height == 320)`를 `720`/`1280`으로 먼저 바꿔 RED(`assertion failed` at the new size assert)를 확인. `M.run()`에 로컬을 추가하면 Lua 200-local 한도에 걸리므로 1x fit 검증은 기존 `scale,x,y` 로컬을 재사용.
- `game/viewport.lua` `M.width`/`M.height` = 720/1280, `conf.lua` 창 크기 `720 * scale` / `1280 * scale`.
- 풀캔버스 터치 상수 `PlayScene.destroyedTouchArea`/`launchTouchArea`가 새 캔버스를 덮도록 `viewport.width`/`viewport.height`를 참조.
- 좌/우 반 분할(`touch.x < viewport.width / 2`)을 쓰던 회귀 테스트의 우측 탭 `x=160`(옛 180폭의 오른쪽)을 `x=640`으로 갱신. 상점/귀환 슬롯 밴드처럼 아직 ×4 하지 않은 히트박스를 두드리는 좌표(`90,244` 등)는 그대로 둠.
- 우주선 스프라이트 논리 footprint 16px → 64px (`game/scenes/play.lua` draw): 기존 64×64 ComfyUI 원본을 새 캔버스에서 1:1로 그림.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:64`, `ASSET_MANIFEST_OK`).
- 항목은 HUD/터치 좌표 전량이 남아 있으므로 `docs/feedback/INBOX.md` 처리대기에 유지하고 첫 슬라이스 로그만 append.

다음 사이클 다음 슬라이스: 같은 항목의 HUD/터치 히트박스·미니맵(`game/minimap.lua` size 48)·조이스틱 비주얼 반경·상점 `settlementTouchRows`/`returnControls`/`ascendControls`·폰트·로드아웃 박스·지구 원반을 ×4 또는 캔버스 비율로 재배치. 행성 스프라이트는 ComfyUI로 더 큰 원본을 재생성하거나 논리 크기를 키운다. econ/gear 레인 소유 항목(7/8/11/15, 13/9/10/12/14)과 `game/gear.lua`는 건드리지 않는다.

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
