# STATUS
## [gear 레인] 항목13 웹 에디터 galaxyExclusive 라운드트립 + Card-shape 스키마 표 명문화 (완료, 2026-09-03)

preflight READY(엔진 테스트/패키지 PASS, git diff check PASS). `git status --short`가 이전 사이클이 남긴 uncommitted 항목13 후속(웹 에디터 `galaxyExclusive` 폼 + Card-shape 스키마 표)을 보고해 그대로 마무리했다.

- 감사 질문 1: 항목7이 JSON에 넣은 `galaxyExclusive`를 항목13 웹 에디터가 Save 시 보존하는가? `gear.validatePart`는 플래그를 복사하지만 `tools/gear-editor/` 폼에는 컨트롤이 없었고 `collectFormPart()`가 필드를 생략해, `hull_combo_matrix`/`engine_singularity_drive`를 열고 다른 필드만 고친 뒤 Save하면 Earth-shop 필터/허브 확정 드롭이 조용히 풀렸다.
- TDD: `game/self_test.lua`의 `testGearEditorGalaxyExclusiveFieldSync()`가 `index.html`의 `fieldGalaxyExclusive` 체크박스, `collectFormPart` 출력, `openForm` 복원을 소스 텍스트로 잠근다.
- `tools/gear-editor/index.html`에 Galaxy exclusive 체크박스, `editor.js`의 `openForm`/`collectFormPart`/그리드 라벨, `editor.css` 체크박스 레이아웃을 연결했다.
- 감사 질문 2 (직전 슬라이스가 명시한 다음 작업): `docs/GEAR_SCHEMA.md` Card-shape 예시 JSON·필드 표가 `galaxyExclusive`를 빠뜨려 스키마만 읽는 작성자가 플래그 존재를 알 수 없었다. 예시 JSON과 표 행에 optional boolean(기본 false, Earth-shop 제외 / hub-drop 전용)을 명문화했다.
- TDD: `testGearSchemaDocumentsGalaxyExclusive()`가 Card-shape 섹션(Effect shape 이전)에 예시 JSON 키, 표의 `` `galaxyExclusive` ``, Earth-shop/hub 노트가 남아 있는지를 잠근다.
- `make test` GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, asset-manifest unittest OK).
- 변경 파일은 `tools/gear-editor/editor.js`/`index.html`/`editor.css`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/STATUS_HISTORY.md`/`docs/feedback/INBOX.md`뿐 — `play.lua`/`i18n.lua`/`world.lua`/`expedition.lua` 미변경.
- 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사(문서-코드 정합성). 항목15·UI 소비 지점(`play.lua`)은 이 레인 스코프 밖.

## [gear 레인] 항목10/14 콘텐츠 커버리지 심화 감사 — engine_parts.json 9종이 엔진 슬롯에서 완전히 죽은 콘텐츠였음을 발견·수정 (완료, 2026-09-03)

- 감사 질문: "엔진 부품 하나가 실제로 엔진 슬롯에 장착됐을 때 유효한 효과를 최소 1개는 갖는가?" `game/self_test.lua`의 `testGearHullSpeedRunWiring`/`testGearMoneyRunWiring`/`testGearHullDurabilityRunWiring`가 명시적으로 "엔진 슬롯 카드의 speed/money/hullDurability는 절대 반영되지 않는다"고 문서화·검증해왔고, `M.effectiveSampleBonus`/`M.effectiveClimbSpeed`도 hull-only 스코프임을 재확인했다. 이 5개 타입(speed/money/climbSpeed/hullDurability/sampleSellValue)만으로 구성된 엔진 카드는 그 유일한 합법 슬롯(엔진)에 장착해도 게임플레이에 아무 영향이 없는 완전히 죽은 콘텐츠다.
- Python으로 실제 `game/data/engine_parts.json`(14종)을 감사한 결과, item 10(b) 이전부터 존재하던 원본 엔진 카드 9종(`engine_basic_thruster`, `engine_afterburner`, `engine_fusion_core`, `engine_azure_coolant_jet`, `engine_ember_burst_valve`, `engine_void_phase_thruster`, `engine_solar_sail_flap`, `engine_burst_capacitor`, `engine_singularity_drive`)이 전부 이 상태였다 — item 10(b)가 (G) 추진 특화 효과 카테고리를 도입했을 때 신규 카드 2종에만 반영하고 기존 9종을 감사하지 않았던 것이 원인.
- TDD: `game/self_test.lua`에 신규 `testEngineCardsHaveNonHullOnlyEffect()`를 먼저 추가했다(RED 확인: assert 실패, 9개 카드 id를 정확히 나열하는 에러 메시지로 실패 재현).
- `game/data/engine_parts.json`의 9종 카드 각각에 기존 hull-only 효과는 그대로 둔 채(밸런스 변경 없음, 순수 추가) `fuelEfficiency`/`steeringResponsiveness`/`boostCharge`((G) 카테고리) 중 하나를 추가해 각 카드가 엔진 슬롯에서도 최소 1개의 유효 효과를 갖도록 했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/GEAR_SCHEMA.md`에 "Engine card content-coverage gap (item 10/14 follow-up slice)" 섹션을 신규 추가했다.
- `git status --short`가 `game/data/engine_parts.json`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- 다음 사이클 다음 슬라이스: `game/data/hull_parts.json`(34종)에 대해서도 동일한 "슬롯 스코프 내 완전 무효 카드" 감사를 수행(hull은 (C)/(E)/(D) 카테고리 무관 타입이 많아 훨씬 적은 카드가 걸릴 것으로 예상되나 확인되지 않음), 또는 항목7(획득 경로 3원화) 순수 데이터 계층 준비.

## [gear 레인] 항목13/12 웹 에디터 에디션 미리보기 기능 구현 + 선체 부품 슬롯 스코프 감사 (완료, 2026-09-03)

preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작. 직전 슬라이스에서 다음 슬라이스 후보로 명시했던 두 가지 잔여 작업을 모두 처리했다.

1. **웹 에디터 에디션 미리보기 (항목 13/12 잔여):**
   - `tools/gear-editor/editor.js`와 `index.html`에 에디션 효과 미리보기(`updateEditionPreview`) 기능을 구현했다. 
   - `M.editionEffects`와 동일한 변환 로직(`EDITION_EFFECTS`)을 에디터에 이식하여, 사용자가 카드 폼에서 `editions`를 입력하거나 `effects` 목록을 수정할 때마다 하단에 각 에디션(irradiated, crystallized, quantum_flawed, refined)이 적용되었을 때의 최종 수치(multiplier 적용, drawback 추가, synergyBonusAdd 표시 등)를 실시간으로 미리보기할 수 있게 했다.
   - 이를 통해 화이트리스트 동기화만 검증되던 상태에서 벗어나, 항목 13의 "수치 미리보기" 요건을 완전히 만족시켰다.

2. **hull_parts.json 슬롯 스코프 콘텐츠 커버리지 (항목 10/14 후속):**
   - 직전 사이클들에서 `engine_parts.json`에 수행했던 "슬롯 스코프 내 완전 무효 카드" 감사를 `game/data/hull_parts.json`(34종)에도 동일하게 적용했다.
   - `game/self_test.lua`에 신규 `testHullCardsHaveNonEngineOnlyEffect()`를 추가해, 선체 카드가 오직 (G) 엔진 전용 타입(`fuelEfficiency`, `steeringResponsiveness`, `boostCharge`)만으로 구성되어 선체 슬롯에서 완전히 무효가 되는 경우가 있는지 검증했다.
   - 예상대로 0건(클린)임이 확인되어 추가 카드 수정 없이 GREEN 통과. 이로써 두 슬롯 풀의 스코프 커버리지 감사가 모두 완료되었다.

- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `tools/gear-editor/editor.js`, `tools/gear-editor/index.html`, `tools/gear-editor/editor.css`, `game/self_test.lua` 파일만 수정으로 보고함 — 레인 스코프가 금지한 게임 코어 시스템(`play.lua`, `world.lua`, `expedition.lua`)은 전혀 건드리지 않았다.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화) 순수 데이터 계층/획득 확률 구조 준비.

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

## [gear 레인] 항목3 스피드미터 아이콘 간소화 추가 완료 (2026-09-03)

- 이전 사이클들이 로켓/방패/동전 아이콘을 완료한 데 이어, 마지막 남은 속도(조종속도/엔진속도) 정보를 스피드미터 아이콘으로 간소화했다.
- `game/scenes/play.lua`에 `M.speedIconPoints(cx, cy, size)` 헬퍼를 추가해 하단은 평면이고 우측 상단으로 바늘 모양이 파인(negative space) 게이지 형태의 폴리곤을 구현했다.
- `M.drawCenteredIconText` 헬퍼를 도입하여 LAUNCH LOADOUT의 `loadout.steering`과 EARTH SHOP의 `nextLaunch.steeringPreviewCompact` 문자열을 그릴 때 스피드미터 아이콘과 문자열이 함께 중앙 정렬되도록 했다.
- `game/i18n.lua`의 관련 문자열("STEER SPEED %d", "조종속도 %d", "SPD %d", "속도 %d")을 모두 "%d"로 대폭 축소해 아이콘만으로 직관적으로 이해할 수 있게 했다.
- `game/self_test.lua`에 `testSpeedometerIcon()`을 추가해 폴리곤의 기하학적 형태를 회귀 검증하고, 기존 "STEER SPEED" 텍스트에 의존하던 테스트 단언문들도 새 숫자로 갱신했다.
- `make test`와 `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN 확인. `git diff` clean. 항목 3의 HUD 간소화 작업이 모두 완료되었다.

## [gear 레인] 항목6 장착 장비 카드 UI 완료 및 도감 UI 제거 (2026-09-03)

- 이전 `gear` 레인에서 백엔드 로직이 완성된 함선 부품 장비 시스템(슬롯 이원화 포함)을 실제 발사 화면(LAUNCH LOADOUT UI)에 시각적으로 배선했다. 이는 사용자의 "UI/HUD 대대적 정리 6개 항목" 중 마지막 남은 항목 6 ("표본 9종 도감 정리 + 슬롯 6개를 개성 있는 함선 장비 카드 UI로 전환")을 완전히 충족한다.
- `game/scenes/play.lua`에서 기존 장식용 요소였던 "SPECIMENS 9/9" 표본 도감 스트립 렌더링 함수(`drawSpecimenStrip`, `specimenProgress`)를 완전히 제거해 화면 공간을 확보했다. (표본 획득 배너 등 실제 기능 관련 상태인 `collectedSpecimens` 로직은 유지).
- 그 자리에 `M.drawGearSlots`를 신규 추가해 발라트로 조커 카드 형태의 장비 슬롯 렌더링을 구현했다. 선체 장비 슬롯 6개와 엔진 장비 슬롯 3개를 한 줄에 모두 그려 넣고, 각 카드의 등급(rarity)에 따라 색상(회색/녹색/파란색/주황색)을 달리 표시하며, 에디션(edition)이 있는 경우 추가 노란색 테두리로 강조한다. 각 카드 아이콘에는 이전에 구현된 `shieldIconPoints`(선체)와 `rocketIconPoints`(엔진)를 조합해 시각적 개성을 부여했다.
- `game/i18n.lua`에 `equipped_gear_label` ("EQUIPPED GEAR", "장착 장비")을 추가해 명확한 캡션을 달았다.
- `game/self_test.lua`에서 더 이상 존재하지 않는 `specimenProgress` 단언문을 제거해 회귀 테스트 정합성을 맞췄다.
- `make test`와 `make verify` 모두 GREEN 확인 완료. 이로써 사용자 요청 "UI/HUD 대대적 정리 6개 항목" 작업이 100% 완료되었다.

## [gear 레인] 항목7 장비 획득 경로 3원화 데이터 계층 준비 완료 (2026-09-03)

- `docs/feedback/INBOX.md`의 "항목 7 (함선 장비 획득 경로 3원화)" 중 백엔드 데이터 계층과 결정론적 생성 로직을 `spaceship-gear` 레인 내에서 우선 구현했다.
- `game/world.lua`에 결정론적 `M.shopPlanet(galaxy)` 생성 함수를 추가하여 은하마다 고유한 좌표에 상점 행성이 단 하나씩 생성되도록 보장했다.
- `game/gear.lua`의 스키마에 `galaxyExclusive` (은하 고유 장비) 부울 필드를 추가하고, `M.earthShopPool` 함수를 통해 이 속성이 켜진 장비는 지구 상점 풀에서 제외되도록 필터링 로직을 구축했다.
- `game/expedition.lua`에 `M.exploreHub(run, galaxyId, pool)`을 신설하여, 각 은하계의 중심 체크포인트 행성을 최초 탐사 시 `run.hubExplored`를 마킹하고 해당 은하계 특유의 고유 장비를 확률 굴림 없이 확정 지급(1개)하도록 구현했다.
- `game/data/hull_parts.json`의 특정 부품에 `galaxyExclusive = true` 속성을 시범 적용한 뒤, `game/self_test.lua`에 지구 상점 필터링과 은하 중심 확정 드롭을 검증하는 회귀 테스트(`testGearGalaxyExclusiveWiring`, `testGalaxyStructure` 보완)를 작성하여 TDD RED/GREEN 사이클을 완료했다.
- 실제 UI 배선(행성 접근 시 팝업 및 인벤토리 지급 처리 등)은 이후 다른 레인이나 슬라이스에서 담당할 수 있도록 순수 함수 기반 인프라를 마련해 둔 상태다.
