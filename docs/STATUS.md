# STATUS
## [gear 레인] 항목13/12 웹 에디터 등급/에디션 화이트리스트 동기화 회귀 가드 (완료, 2026-09-03)

레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료 상태였고, 이 레인이 반복 적용해온 "문서-코드 정합성 감사" 패턴을 이번 사이클에도 다시 적용했다. `tools/gear-editor/editor.js`(항목13)가 항목12의 등급/에디션 화이트리스트를 실제로 `game/gear.lua`와 동기화 유지하는지 감사한 결과, `editor.js` 헤더 주석/`README.md`가 오래전부터 "Validation rules here intentionally mirror game/gear.lua's loader exactly"라고 문서화해왔고, 기존 `testGearEffectSchemaExpansion()`이 `EFFECT_TYPE_GROUPS`/`M.knownEffectTypes` 동기화는 이미 회귀 검증했지만, `KNOWN_EDITIONS`/`KNOWN_RARITIES` 축에는 동일한 검증이 존재하지 않았다 — 문서상 보장일 뿐 코드가 확인한 적이 없어 향후 한쪽에만 새 등급/에디션이 추가되면 조용히 어긋날 수 있는 gap이었다. preflight READY(엔진 테스트/패키지 PASS, git diff clean)로 시작.

- TDD: `game/self_test.lua`에 신규 `testGearEditorEditionAndRaritySync()`를 먼저 추가했다 — `editor.js`를 `love.filesystem.read`로 직접 읽어 `gear.knownEditions`/`gear.knownRarities`의 모든 키가 `KNOWN_EDITIONS`/`KNOWN_RARITIES` 배열 리터럴에 문자열로 존재하는지 검증한다(기존 효과 타입 동기화 검증과 동일 기법).
- RED 확인: `game/gear.lua`의 `M.knownEditions`에 임시로 `__test_temp_edition = true`를 주입(커밋 안 함)해 `make test` 실행 시 `editor.js KNOWN_EDITIONS must include '__test_temp_edition' to stay in sync with gear.lua` 에러로 정확히 실패함을 확인, 원복 후 GREEN.
- 실제 감사 결과 현재 `editor.js`는 이미 `gear.lua`와 완전히 동기화돼 있었다(에디션 4종 `irradiated`/`crystallized`/`quantum_flawed`/`refined`, 등급 4종 `common`/`uncommon`/`rare`/`legendary` 모두 양쪽 일치) — 이번 슬라이스는 기존 드리프트를 고친 것이 아니라 향후 드리프트를 잡아낼 회귀 가드를 신규 추가한 것이다.
- `docs/GEAR_SCHEMA.md`에 "Item 13/12: web editor edition/rarity whitelist sync check" 섹션을 신규 추가했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`, 그리고 이번 슬라이스가 건드릴 필요 없었던 `game/gear.lua`/`game/engine_parts.lua`/`game/expedition.lua`/`tools/gear-editor/editor.js`도 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 13 하위(항목14 앞)에 처리 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점 행성 좌표 생성/은하 체크포인트 확정 드롭)의 순수 함수/데이터 계층 준비, 또는 웹 에디터가 에디션별 `M.editionEffects` 수치 변환(예: crystallized의 sampleSellValue x2)을 카드 폼에서 실제로 미리보기하는지 감사(현재는 화이트리스트 동기화만 검증됨, 수치 미리보기 자체는 미구현으로 보임).

## [gear 레인] 항목10(b) boostCharge 소비 배선 — 미장착 시 안전 거부, 재발사 시 리필 (완료, 2026-09-03)

- `game/expedition.lua`에 신규 `run.boostsUsed`(`M.new`에서 0 초기화, `M.launch`에서 `run.insuranceUsed`/`run.rerollsUsed`와 함께 0으로 리셋)와 두 함수를 추가했다: `M.boostsRemaining(run)`(현재 `M.boostChargeCount(run)`에서 `run.boostsUsed`를 뺀 값, 0 미만 방지 — 장비 재장착 시 즉시 상한 상승, `rerollsRemaining`과 동일 계약)와 `M.spendBoost(run)`(성공 시 `true`+카운터 증가, 잔여 없으면 예외 없이 `false, 에러메시지` 반환 — `M.spendReroll`/`M.sellGear`/`M.equipGear`와 동일한 원자적 거부 패턴).
- `game/self_test.lua`의 `testGearPropulsionRunWiring` 확장 검증: `engine_emergency_boost_pod`(boostCharge +2) 장착 run이 2에서 시작해 두 번의 `spendBoost`로 0까지 소진, 세 번째는 안전하게 거부(음수 방지), 미장착 run은 0에서 시작하고 거부도 정상 동작, 재발사(`M.launch`) 시 현재 장착 총합으로 리필됨을 확인.
- `docs/GEAR_SCHEMA.md`에 "Item 10(b)/14(G) `boostCharge` consumption wiring (follow-up slice)" 섹션을 신규 추가했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- 실제 게임플레이 소비 지점(탭-투-부스트 버튼 등, `M.spendBoost`를 실제로 호출해 추력/고도 버스트를 적용하는 것)은 여전히 이 레인 스코프 밖(`play.lua` 담당).
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화) 순수 데이터 계층 준비, 또는 이 레인이 완료한 순서 밖의 잔여 작업(실제 UI 소비 지점은 대부분 play.lua/world.lua 담당이라 다른 레인 소관) 검토.

## [gear 레인] 항목10/14 콘텐츠 커버리지 심화 감사 — engine_parts.json 9종이 엔진 슬롯에서 완전히 죽은 콘텐츠였음을 발견·수정 (완료, 2026-09-03)

이 레인이 지정받은 항목13→9→10→12→14가 모두 1차 완료되고 여러 후속 gap 슬라이스까지 닫힌 상태에서, 기존 `testGearEffectTypeContentCoverage`("모든 효과 타입이 두 풀 어딘가에는 등장하는가")보다 한 단계 더 깊은 감사를 수행했다 — preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- 감사 질문: "엔진 부품 하나가 실제로 엔진 슬롯에 장착됐을 때 유효한 효과를 최소 1개는 갖는가?" `game/self_test.lua`의 `testGearHullSpeedRunWiring`/`testGearMoneyRunWiring`/`testGearHullDurabilityRunWiring`가 명시적으로 "엔진 슬롯 카드의 speed/money/hullDurability는 절대 반영되지 않는다"고 문서화·검증해왔고, `M.effectiveSampleBonus`/`M.effectiveClimbSpeed`도 hull-only 스코프임을 재확인했다. 이 5개 타입(speed/money/climbSpeed/hullDurability/sampleSellValue)만으로 구성된 엔진 카드는 그 유일한 합법 슬롯(엔진)에 장착해도 게임플레이에 아무 영향이 없는 완전히 죽은 콘텐츠다.
- Python으로 실제 `game/data/engine_parts.json`(14종)을 감사한 결과, item 10(b) 이전부터 존재하던 원본 엔진 카드 9종(`engine_basic_thruster`, `engine_afterburner`, `engine_fusion_core`, `engine_azure_coolant_jet`, `engine_ember_burst_valve`, `engine_void_phase_thruster`, `engine_solar_sail_flap`, `engine_burst_capacitor`, `engine_singularity_drive`)이 전부 이 상태였다 — item 10(b)가 (G) 추진 특화 효과 카테고리를 도입했을 때 신규 카드 2종에만 반영하고 기존 9종을 감사하지 않았던 것이 원인.
- TDD: `game/self_test.lua`에 신규 `testEngineCardsHaveNonHullOnlyEffect()`를 먼저 추가했다(RED 확인: assert 실패, 9개 카드 id를 정확히 나열하는 에러 메시지로 실패 재현).
- `game/data/engine_parts.json`의 9종 카드 각각에 기존 hull-only 효과는 그대로 둔 채(밸런스 변경 없음, 순수 추가) `fuelEfficiency`/`steeringResponsiveness`/`boostCharge`((G) 카테고리) 중 하나를 추가해 각 카드가 엔진 슬롯에서도 최소 1개의 유효 효과를 갖도록 했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/GEAR_SCHEMA.md`에 "Engine card content-coverage gap (item 10/14 follow-up slice)" 섹션을 신규 추가했다.
- `git status --short`가 `game/data/engine_parts.json`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- 다음 사이클 다음 슬라이스: `game/data/hull_parts.json`(34종)에 대해서도 동일한 "슬롯 스코프 내 완전 무효 카드" 감사를 수행(hull은 (C)/(E)/(D) 카테고리 무관 타입이 많아 훨씬 적은 카드가 걸릴 것으로 예상되나 확인되지 않음), 또는 항목7(획득 경로 3원화) 순수 데이터 계층 준비.

## [gear 레인] 항목14(C) chainTrigger 소비 배선 — rerollBonus/boostCharge와 동일한 "카운트는 있지만 아무도 쓰지 않는" 마지막 잔여 처리 (완료, 2026-09-03)

preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작. 직전 슬라이스가 `game/data/hull_parts.json`(34종)에 대해 항목10/14의 "슬롯 스코프 내 완전 무효 카드" 감사를 다음 후보로 명시했으나, Python으로 실제 감사한 결과 hull_parts.json은 이미 (G) 엔진 전용 타입을 전혀 쓰지 않고 hull-only 5종 타입만으로 구성된 카드가 하나도 없어(0건) 이 감사는 클린 상태였다. 대신 이 레인이 반복 적용해온 "문서-코드 정합성 감사" 패턴을 항목14 (C) `chainTrigger`에 다시 적용해 새 gap을 찾아 처리했다.

- 감사 결과: `expedition.chainTriggerCount(run)`(항목14 (C)/(E) run wiring 슬라이스에서 추가)는 장착 부품의 `chainTrigger` 총합을 재계산해 노출하는 순수 파생값으로만 존재했고, 이 카운트를 실제로 "소비"해 무언가를 재발동시키는 코드 경로가 단 하나도 없었다 — 이 레인이 이미 `rerollBonus`(`M.spendReroll`/`run.rerollsUsed`)와 `boostCharge`(`M.spendBoost`/`run.boostsUsed`)에서 발견·처리한 것과 정확히 동일한 패턴의 마지막 잔여였다.
- TDD: `game/self_test.lua`에 신규 `testGearChainTriggerConsumptionWiring()`을 먼저 추가했다(RED 확인: `an unequipped run must report zero chain retriggers, got nil` — `collectSample`이 아직 4번째 반환값을 주지 않아 실패).
- `game/expedition.lua`의 `M.collectSample(run, value, hueKey)`가 기존 yield/streak/hull-sample-bonus 계산 이후 `M.chainTriggerCount(run)`(카테고리 무관, hull/engine 둘 다 합산 — rerollBonus/detectionRadius/autoCollect와 동일 설계)을 읽어 `awarded = awarded * (1 + retriggers)`로 재적용하도록 확장했다(`chainTrigger +1` 카드 = 1회 기본 적용 + 1회 재발동 = 2배). 표본 채집 이벤트 자체는 중복 생성되지 않는다 — `run.sampleCount`/스트릭 계열 상태는 여전히 호출당 정확히 1회만 증가한다. `M.collectSample`이 이제 4번째 반환값으로 실제 적용된 재발동 횟수(`retriggers`)를 노출해 향후 UI/테스트가 재계산 없이 바로 표시할 수 있다.
- `testGearChainTriggerConsumptionWiring()`이 미장착 baseline(awarded=100, retriggers=0), hull `chainTrigger +1` 카드 장착 시 awarded=200/retriggers=1/sampleCount는 여전히 1, 동일 카드를 엔진 슬롯에 장착해도 동일하게 배가(카테고리 무관 재확인)를 회귀 검증한다(RED 확인 후 GREEN).
- `docs/GEAR_SCHEMA.md`에 "Item 14(C) `chainTrigger` consumption gap" 섹션을 신규 추가했다.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`, 그리고 `game/gear.lua`/`game/engine_parts.lua`도 전혀 건드리지 않았다.
- 다음 사이클 다음 슬라이스: 이로써 레인이 지정받은 5개 항목(13→9→10→12→14)의 문서상 명시적 "카운트만 있고 소비자 없음" 유형 gap은 모두 닫힌 것으로 보인다 — 다음은 항목7(획득 경로 3원화 — 상점 행성 좌표 생성 등 순수 함수/데이터 계층에서 준비 가능한 부분) 순수 데이터 계층 준비, 또는 이 레인이 완료한 순서 밖의 잔여 작업(실제 UI 소비 지점은 대부분 play.lua/world.lua/minimap.lua 담당이라 다른 레인 소관) 검토를 권장한다.

## [gear 레인] 항목10/14 카테고리 무관 효과 콘텐츠 커버리지 — engine_parts.json에 10개 타입 최초 카드 추가 (완료, 2026-09-03)

이 레인이 지정받은 항목13→9→10→12→14가 모두 1차 완료되고 여러 후속 gap 슬라이스(직전 chainTrigger 소비 배선 포함)까지 닫힌 상태에서, 기존 콘텐츠 커버리지 테스트 두 종(`testGearEffectTypeContentCoverage`: 두 풀 합쳐 모든 타입이 최소 1회 등장, `testEngineCardsHaveNonHullOnlyEffect`: 모든 엔진 카드가 최소 1개 non-hull-only 효과 보유)보다 한 단계 더 깊은 감사를 수행했다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- 감사 질문: "카테고리 무관(hull/engine 어느 슬롯이든 효과가 실제로 반영되도록 설계된) 효과 타입 10종(luck/chainTrigger/rerollBonus/collisionRadius/detectionRadius/autoCollect/insurance/shopDiscount/sellMultiplier/streakMultiplier — 대부분 `expedition.lua`의 `combinedGearList(run)` 헬퍼가 hull+engine 두 목록을 무조건 합산해 소비)가 실제로 엔진 슬롯 카드에서도 등장하는가?" Python으로 `game/data/engine_parts.json`(14종)을 직접 감사한 결과 10종 전부 0건 — 이 타입들을 쓰는 번들 카드는 전부 `hull_parts.json`에만 존재해, 엔진 부품만 장착한 플레이어는 이 10가지 효과 중 어느 것도 실제 플레이에서 마주칠 수 없었다(런 배선 함수 자체는 이미 두 슬롯 모두를 읽도록 설계돼 있었으나 콘텐츠가 없어 죽어있던 gap).
- TDD: `game/self_test.lua`에 신규 `testEngineCardsHaveCategoryAgnosticEffectCoverage()`를 먼저 추가했다(RED 확인: `missing: luck, chainTrigger, rerollBonus, collisionRadius, detectionRadius, autoCollect, insurance, shopDiscount, sellMultiplier, streakMultiplier` 전체 나열 실패).
- `game/data/engine_parts.json`에 10종 신규 카드를 추가했다(14종 → 24종, 누락 타입당 1장): `engine_probability_core`(luck), `engine_echo_thruster`(chainTrigger), `engine_haggler_valve`(rerollBonus), `engine_slim_nacelle`(collisionRadius), `engine_deep_scan_pod`(detectionRadius), `engine_magnet_intake`(autoCollect), `engine_escape_pod_thruster`(insurance), `engine_freelancer_manifold`(shopDiscount), `engine_market_thruster`(sellMultiplier), `engine_momentum_stabilizer`(streakMultiplier). 각 카드는 새 카테고리 무관 효과 옆에 항상 (G) `steeringResponsiveness`/`fuelEfficiency` 또는 (A) `speed` 같은 이미 엔진-합법으로 확립된 보조 효과를 함께 부여해, 신규 카드도 `testEngineCardsHaveNonHullOnlyEffect`의 "non-hull-only 효과 최소 1개" 규칙을 독립적으로 만족한다. 태그 관례(economy/control/defense/speed/altitude)를 그대로 재사용해 항목9의 시너지 엔진과 완전히 호환된다.
- `docs/GEAR_SCHEMA.md`에 "Item 10/14 category-agnostic content-coverage gap" 섹션을 신규 추가했다.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/data/engine_parts.json`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`, 그리고 `game/gear.lua`/`game/engine_parts.lua`/`game/expedition.lua`도 전혀 건드리지 않았다(순수 데이터+테스트 슬라이스).
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점 행성 좌표 생성/은하 체크포인트 확정 드롭)의 순수 함수/데이터 계층 준비, 또는 이 레인이 반복 적용해온 "문서-코드 정합성 감사" 패턴을 다시 적용해 항목9/10/12/13/14의 남은 잔여 gap(예: 시너지 엔진의 다른 에디션 상호작용, 슬롯 교체 루프 실사용 UI는 다른 레인 담당) 재검증.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
