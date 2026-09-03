# STATUS
## preflight FAIL 수정: 미해결 병합 충돌 마커(docs/assets/MANIFEST.json, docs/feedback/INBOX.md) 제거 (완료, 2026-09-03)

preflight가 `engine tests and package: FAIL`(`tools/verify_asset_manifest.py`가 `docs/assets/MANIFEST.json`을 JSON으로 파싱하다 `json.decoder.JSONDecodeError`)와 `git diff check: FAIL`(두 파일에 남은 `<<<<<<<`/`=======`/`>>>>>>>` 리터럴 충돌 마커)을 보고했다. 이것이 최우선 과제이므로 다른 작업보다 먼저 이 정확한 실패를 재현하고 수정했다.

- `git status --short`로 세션 시작 시 `docs/assets/MANIFEST.json`/`docs/feedback/INBOX.md`가 `UU`(양쪽 모두 수정, 미해결 병합 충돌) 상태임을 확인했다. `git stash list`에 `stash@{0}: On main: cycle-wip`가 남아 있어, 이전 사이클이 `git stash pop` 도중 충돌을 만나고 충돌 마커를 그대로 커밋하지 않은 채(즉 미해결 상태로) 세션을 종료했음을 파악했다.
- `docs/assets/MANIFEST.json`: `Updated upstream` 쪽(ComfyUI 스모크 테스트 우주선 항목 1개)과 `Stashed changes` 쪽(AetherAI 표본 스프라이트 9개 항목)이 서로 다른 배열 원소였으므로 — 즉 실제 값 충돌이 아니라 두 커밋이 서로 다른 신규 원소를 배열에 추가한 것 — 두 세트를 모두 보존해 단일 유효 JSON 배열(우주선 1개 + 표본 9개 = 총 10개 원소)로 합쳤다.
- `docs/feedback/INBOX.md`: `Updated upstream` 쪽(항목 7건, human-gate 제거/ComfyUI 파이프라인/미니맵 나선/국제화+HUD/UI 대개편/은하이름/우주선 추진 방향)과 `Stashed changes` 쪽(생성 에셋 LLM 비전 검토 제외 1건)도 서로 다른 신규 pending 항목이었으므로 둘 다 `## 처리 대기` 아래에 보존하고 마커만 제거했다. 어느 쪽 항목 내용도 삭제/수정하지 않았다.
- `git add`로 두 파일의 충돌 해결 상태를 스테이징한 뒤, 스태시 전체가 이미(위 두 파일 포함, 다른 8개 파일은 원래 순수 fast-forward로 이미 적용돼 있었음) 작업트리에 반영돼 있음을 `git stash show -p --stat`로 확인하고 `git stash drop`으로 정리했다(스태시 재적용 시도 없음 — 이미 다 반영된 상태였으므로 pop이 아니라 drop).
- `python3 tools/verify_asset_manifest.py` 단독 재실행으로 `ASSET_MANIFEST_OK`를, `git diff --check` 재실행으로 출력 없음(clean)을 확인해 preflight가 보고한 두 실패가 모두 재현되지 않음을 확인했다.
- `make verify LOVE=/Users/jm/.local/bin/love` 전체 재실행 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x2, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`, `tools.test_verify_asset_manifest` 9건 OK).
- `assets/sprites/specimens/*.png`(9개, 이전 사이클이 이미 생성해 두었던 AetherAI free-asset 표본 스프라이트, MANIFEST 항목과 매칭)는 `git status`상 `??`(untracked)였으나 `game/self_test.lua`의 `testSpecimenSprites()`가 이 파일들의 실존을 검증하고 있었고 `make verify`가 GREEN이었으므로 이번 커밋에 함께 추가했다.
- 이번 슬라이스는 preflight 실패 원인(미해결 병합 충돌) 진단·제거만 수행했다(신규 게임 로직/텍스트 변경 없음 — 다만 두 문서 파일의 병합 결과 및 이전 사이클의 표본 스프라이트 자산은 이번 커밋에 처음 포함됨). 화면 렌더가 바뀌는 코드 변경이 없으므로 실제 LÖVE 런타임 캡처는 필요하지 않았다.
- 다음 사이클 다음 슬라이스: `docs/feedback/INBOX.md` 처리 대기 최상단 항목(AetherAI human-gate 제거/ComfyUI 실작업 진행)부터 이어서 진행 — 인프라(comfyui_asset_pipeline.py, verify_asset_manifest.py의 OFFICIAL_SOURCE_PREFIXES)는 이미 있으나 우주선/행성/이펙트/아이콘 실제 프로덕션 에셋 생성·배선은 아직. 또는 INBOX 최상단의 미니맵 은하나선/국제화+HUD 약자 정리/UI 대개편 6건 중 하나로 진행. econ/gear 레인 소유 항목(7/8/9/10/11/12/13/14/15)은 건드리지 않는다.

## 항목 6 첫 슬라이스 — 슬롯 6개를 함선 장비 카드 6종으로 재해석하는 game/gear.lua 카탈로그 추가 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 6번(표본 도감 정리 검토 + 슬롯 6개를 개성 있는 함선 장비 카드 UI로 전환)의 첫 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- 귀환 시 `slotOpportunities` 최대치인 "슬롯 6개"가 추상적인 확률 슬롯으로만 표시되고 있어, 사용자가 요청한 "발라트로 조커 카드처럼 이름·아이콘·능력이 있는 6종 함선 장비" 재해석을 위한 데이터 카탈로그부터 착수했다(UI/렌더 변경은 이번 슬라이스 범위 밖).
- 신규 `game/gear.lua`에 `M.catalog`(정확히 6개 항목, `M.cardCount == 6`)를 추가했다. 사용자 세션 초안의 6종(오버드라이브 코어/강화 장갑판/채집 자석/행운의 주사위/스트릭 증폭기/정밀 자이로)을 모두 담되, 앞의 세 개(오버드라이브 코어=steeringUpgradeLevel, 강화 장갑판=durabilityUpgradeLevel, 채집 자석=sampleYieldUpgradeLevel)는 이미 존재하는 EARTH SHOP 업그레이드 레벨에 `upgradeField`로 매핑했다. 뒤의 세 개(행운의 주사위/스트릭 증폭기/정밀 자이로)는 대응하는 단일 수치 업그레이드가 아직 없어(슬롯 오즈·스트릭 배율·조종 반응성은 지금도 다른 메커니즘이 따로 존재) `upgradeField = nil`로 남겨 "아직 구매 불가"임을 정직하게 표현했다.
- `M.equipped(run)` 순수 함수가 `upgradeField`를 가진 카드 중 해당 레벨이 0보다 큰 것만 `.level` 필드를 추가한 얕은 사본으로 반환한다. `upgradeField`가 `nil`인 세 카드는 run 상태와 무관하게 항상 결과에서 제외된다.
- `game/self_test.lua`에 `testGearCatalog()`(신규)을 추가했다 — 카탈로그 크기 6, 레벨 0에서는 미장착, `durabilityUpgradeLevel`/`sampleYieldUpgradeLevel`을 각각 세팅했을 때 해당 카드만 정확한 `.level`로 장착 보고, `steeringUpgradeLevel`까지 세팅하면 3종 모두 장착, 그리고 행운의 주사위/스트릭 증폭기/정밀 자이로는 어떤 레벨 조합에서도 절대 장착되지 않음을 회귀 검증한다(RED 확인: `game.gear` 모듈이 없어 `require` 실패로 재현 → GREEN 전환).
- 이번 슬라이스는 데이터/엔진 전용이다(신규 UI 렌더/HUD/EARTH SHOP 화면 변경 없음). 화면에 보이는 변화가 없으므로 실제 LÖVE 런타임 캡처는 이번 슬라이스에서 필요하지 않았다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:44`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md` 6번 항목에 이번 슬라이스 완료 표시 및 구현 요약, 남은 작업(카드 아이콘 UI 노출, 표본 도감 스트립 제거 재검토, 나머지 3종 카드 구매 경로 설계)을 기록했다.
- 다음 사이클 다음 슬라이스: 6번 항목의 남은 부분(HUD 하단 또는 EARTH SHOP에 `gear.equipped(run)` 아이콘 상시 노출 UI 추가, 표본 도감 스트립 제거 여부 재검토, 행운의 주사위/스트릭 증폭기/정밀 자이로의 실제 구매/장착 경로 설계) 중 하나, 또는 11번 항목의 남은 부분(a: `launchForecastLine` 연료-종속 프레이밍 재정의, c: 활성 연료 필드 재설계) 중 하나로 진행.

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
