# STATUS

## 항목7→8→11→15 INBOX 정리(pending→done 표시) + 이전 사이클 미커밋 작업 커밋 (완료, 2026-09-03)

이번 사이클 시작 시 `git status --short`에 이전 사이클이 남긴 미커밋 diff(`docs/STATUS.md`/`docs/feedback/INBOX.md`/`game/expedition.lua`/`game/i18n.lua`/`game/scenes/play.lua`/`game/self_test.lua`/`main.lua`)가 있었다 — 검토 결과 이는 직전 사이클이 항목 15(a)를 완결하며 남긴 GREEN 상태의 완결된 작업(아래 15(a) 완료 로그 참고)이었다. `make test` 재확인(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `tools.test_verify_asset_manifest` 9건 모두 GREEN)으로 코드 상태가 여전히 정상임을 검증했다.

이 레인 스코프(econ, 항목7→8→11→15)의 4개 항목이 모두 완료되었음을 `docs/feedback/INBOX.md`에서도 명확히 표시했다 — 토큰 절약 규칙(loop/PROMPT.md 8항)에 따라 각 항목 번호(7/8/15, 11은 이미 이전 사이클에서 표시됨) 앞에 `✅ 완료(econ 레인, 2026-09-03)` 마커를 추가해, 다음 사이클이 이 대형 pending 블록 전체를 매번 재확인하지 않고도 econ 레인 담당 4개 항목이 끝났음을 한눈에 알 수 있게 했다(하위 진행 로그는 감사(audit) 기록으로 그대로 보존, 이동하지 않음 — 이 INBOX 구조는 항목별 독립 최상위 bullet이 아니라 여러 항목이 한 최우선 그룹 bullet 아래 번호 목록으로 묶여 있어 항목 단위로만 완료 표시를 삽입할 수 있었다).

**레인 스코프 소진 확인:** `loop/PROMPT.md`가 이 레인에 지정한 순서(항목7→8→11→15)가 전부 완료되어, 이 레인이 자체적으로 착수할 수 있는 다음 슬라이스가 없다. 다음 사이클은 `loop/PROMPT.md` 갱신(다른 미해결 pending 항목으로 스코프 재배정, 예: 항목 9/10/12/13/14의 gear 레인과의 조율이 필요한 부품 시스템 확장, 또는 world.lua/expedition.lua를 건드리는 다른 pending 항목이 새로 배정된 경우)이나 사용자 확인을 대기해야 하며, 이 레인 스코프 밖의 새 항목을 임의로 착수하지 않는다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN 상태로 커밋/푸시했다.

## 항목 15(a) 완료 — beginReturn/returning 페이즈/in-flight useSlot·slotSpin 완전 폐지 커밋 + 잔여 죽은코드 정리 (완료, 2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 마지막 항목인 15의 최종 남은 부분 (a) — 옛 `beginReturn`/`"returning"` 페이즈/in-flight `useSlot`·`slotSpin` 완전 폐지, 체크포인트/지구 도달 시 즉시 정산으로의 구조 전환 — 를 마무리했다. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short`에서 이전 사이클이 이미 이 제거 작업 전체(`game/expedition.lua`/`game/scenes/play.lua`/`main.lua`/`game/self_test.lua`, +138/-1050줄)를 마쳐뒀으나 커밋되지 않은 채로 남아 있는 것을 발견 — 검토 결과 실제로 완결된 상태(테스트 GREEN)였으므로 그대로 이어받아 잔여 죽은코드를 마저 정리하고 커밋했다.

- 이전(미커밋) 슬라이스가 이미 해낸 것: `game/expedition.lua`에서 `M.beginReturn`/`M.useSlot`/로컬 `spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`(및 관련 상수·export)를 전부 삭제하고, `M.update`의 `"returning"` 분기(고도 감소 로직)를 삭제, `settle()`이 이제 `returnToEarth`에서 직접 호출되며 `run.altitude = 0`을 명시적으로 설정하도록 갱신, `settle()`/`destroy()`/`M.new()`/`M.launch()`에서 `returnDistance`/`slotOpportunities`/`slotSpins`/`lastSlotSymbols`/`lastSlotReward`/`lastSlotRepair`/`lastSlotFuelBonus`/`lastSlotSampleBonus`/`pendingFuelBonus`/`bankedFuelBonus`/`pendingSlotReward`/`lastSlotSpinsCount`/`lastSlotSettlement`/`lastLostSlotSpinsCount`/`lastLostSlotValue` 필드 참조를 모두 제거했다(단 `M.slotSymbols`/`M.slotWeights`/`M.slotReward`/`M.weightedSlotSymbol`/`M.slotExpectedValue`/`M.slotSymbolProbability`는 EARTH SHOP 슬롯머신(항목 15b/c)이 계속 쓰므로 보존). `M.damage`가 이제 `"ascending"` 페이즈에서만 유효(예전엔 `"returning"`도 허용). `game/scenes/play.lua`에서 `returnControls`/`slotButtonState`/`beginSlotSpin`/`currentSlotReels`와 그 호출부(space-bar 슬롯 분기, touchpressed의 return-band, draw()의 returning 전용 슬롯 UI 블록, `hudOddsLineHeight`/`hudHeight`의 returning 분기)를 제거하고 `collisionRisk`/`approachWarning`/`hudLines`/`pollDesktopMouse`/`M:update`/`M:keypressed`의 `"returning"` 분기를 모두 정리했다(`slotOddsLine`/`slotSymbolProbability`/`slotExpectedValue` 자체는 LAUNCH LOADOUT/EARTH SHOP 미리보기용으로 유지). `main.lua`의 옛 `returning-odds`/`returning-repair`/`returning-fuelbonus`/`returning-samplebonus` 캡처 하네스 4개를 제거하고 `full-loop-relaunch` 하네스를 새 즉시-정산(`"r"` 키) 흐름으로 재작성했다. `game/self_test.lua`의 `expedition.beginReturn`/`expedition.useSlot` 호출부를 모두 "존재하지 않아야 함" 검증(`assert(expedition.beginReturn == nil, ...)`, `assert(expedition.useSlot == nil, ...)`)으로 갱신했다.
- 이번 사이클이 추가로 정리한 잔여 죽은코드(위 제거 작업이 놓친 부분): `game/i18n.lua`에서 어디서도 참조되지 않게 된 `spin_compact_label`/`spinning_compact`/`slot_result_repair`/`slot_result_fuel`/`slot_result_sample`/`slot_result_plain`/`returning_message`/`slot_spinning_label`/`no_slot_chances_label`/`no_slots_compact`/`slot_spin_prompt`(en/ko 총 22개 문자열 키)를 `grep`으로 실제 호출부가 전무함을 확인한 뒤 삭제했다. `phase_abbrev.returning`(en `"RETURN"`/ko `"귀환"`)도 `run.phase`가 더 이상 `"returning"` 값을 가질 수 없으므로(엔진에서 이 값을 설정하는 코드가 완전히 삭제됨) 함께 삭제했다 — `i18n.phaseAbbrev()`의 fallback(`map[phase] or ... or phase`)이 존재하므로 안전하다. `game/self_test.lua:2177` 근처의 `persistBestAltitude` 회귀 테스트가 (이제 존재할 수 없는) `"returning"`을 임의 예시 페이즈 문자열로 쓰고 있던 것을 `"ascending"`으로 교체하고 왜 바뀌었는지 설명하는 주석을 추가했다(동작은 동일 — persistBestAltitude가 phase와 무관함을 검증하는 테스트라 값 자체는 원래도 임의적이었다).
- `GAME_HEADLESS=1 GAME_CAPTURE=1 GAME_CAPTURE_PHASE=return-to-earth GAME_LOCALE=ko` 실제 LÖVE 런타임 캡처(1080×1920)를 vision으로 확인했다 — "정산 +$75  잔액 $75", "지구 상점" 화면이 크래시나 에러 텍스트 없이 정상 렌더링되고, returning 전용 UI(슬롯 릴, 조이스틱 하강 등) 잔재가 전혀 보이지 않음을 확인했다. (화면에 여전히 보이는 "도달예상 600 슬롯 6" 등 텍스트는 항목 11(a)/6의 몫이며 play.lua 텍스트 세부는 메인 레인 담당이라 이 슬라이스에서 손대지 않았다.)
- `GAME_HEADLESS=1 GAME_UNIT=1 love .`, `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`).
- 이로써 이 레인의 스코프 순서(항목7→8→11→15) 4개 항목이 모두 완료되었다: 항목7(a/b/c), 항목8, 항목11(b/c 완료, a는 메인 레인 조율 필요 텍스트 영역), 항목15(a/b/c). `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 슬라이스 진행 상황을 append하고, 항목 15 전체를 처리완료로 이동했다.
- 다음 사이클 다음 슬라이스: 이 레인의 지정된 4개 항목(7/8/11/15)이 모두 완료되어, `loop/PROMPT.md`의 레인 스코프에 명시된 작업이 소진되었다. 다음 사이클은 `loop/PROMPT.md` 갱신(다른 미해결 pending 항목으로 스코프 재배정) 또는 사용자 확인을 대기해야 한다 — 이 레인 스코프 밖의 새 항목을 임의로 착수하지 않는다.

## 항목 7(c) UI 연결 — EARTH SHOP 범용 장비 구매 경로를 "n" 키로 실제 플레이에 연결 (완료, 2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 항목 7의 마지막 남은 부분 (c) — 지구 EARTH SHOP에서 범용(은하 비특정) 장비 부품 구매 — 를 처리했다. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short`에서 이전 사이클이 남긴 미커밋 diff(`game/expedition.lua`/`game/i18n.lua`/`game/scenes/play.lua`/`game/self_test.lua`)를 발견 — 검토 결과 그대로 완결된 7(c) 슬라이스였으므로 덮어쓰지 않고 이어서 완결/커밋했다.

- 이전 슬라이스가 `game/expedition.lua`에 `M.genericGearCatalog`/`M.buyEarthGear(run, gearId)`를 순수 엔진 API로 이미 추가해두었으나(항목 7 첫 슬라이스), `game/scenes/play.lua`가 이를 전혀 호출하지 않아 EARTH SHOP에서 범용 부품을 구매할 방법이 실제 플레이에는 없었다 — 상점 행성 구매(7-a, "b" 키)와 체크포인트 확정 드롭(7-b)만 접근 가능했다.
- `game/expedition.lua`에 신규 `M.nextBuyableEarthGear(run)`을 추가했다 — `run.ownedGear`에 없는 `genericGearCatalog`의 첫 항목을 카탈로그 순서대로 반환하고, 모두 보유 시 `nil`을 반환한다. 카드별 개별 UI(항목 9/13의 몫)가 아직 없는 상태에서 "다음 미보유 범용 부품 구매"라는 단일 액션으로 카탈로그 전체를 순회 구매할 수 있게 하는 최소 설계다.
- `game/scenes/play.lua`의 `M:keypressed`에 settlement 페이즈 전용 신규 `"n"` 키 분기를 추가했다 — 후보가 있으면 `expedition.buyEarthGear`를 호출해 `earth_gear_bought_message`로 결과를 안내하고, 자금 부족 시 기존 HULL/YIELD/STEERING/SCOUT/SLOT 구매 키들과 동일한 `purchaseShortfallMessage` 패턴(신규 `item_earth_gear` 문구)을 재사용하며, 모두 보유 시 `all_earth_gear_owned_message`로 안내한다. `game/i18n.lua`에 `earth_gear_bought_message`/`item_earth_gear`/`all_earth_gear_owned_message`(en/ko)를 추가했다. 레인 스코프 규칙(play.lua 텍스트/HUD 세부는 메인 레인 담당)에 따라 새 시각 레이아웃(카드 그리드 등)은 추가하지 않고 키 입력 분기와 필수 메시지 문구만 최소 추가했다.
- `game/self_test.lua`에 신규 `testEarthGearShopUiWiring()`을 추가했다 — settlement에서 "n"이 첫 미보유 범용 부품을 구매함(자금 차감+ownedGear 반영+구매 메시지), 재입력 시 다음 미보유 부품으로 넘어감(중복 구매 없음), 전량 보유 시 "ALL EARTH GEAR OWNED" 메시지, 자금 부족 시 차감 없이 shortfall 메시지, settlement 이외 페이즈(ascending)에서는 완전 no-op임을 회귀 검증한다. `game/self_test.lua:2926`의 `M.run()` 목록에 이 함수 호출을 추가로 등록했다.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .`, `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`).
- 이로써 항목 7(a/b/c) 전체가 엔진+UI 연결까지 완료되었다. 항목 8도 이전 슬라이스에서 엔진+UI 연결까지 완료된 상태다.
- `docs/feedback/INBOX.md` 처리대기 항목 7 하위에 이번 슬라이스 진행 상황을 append했다.
- 다음 사이클 다음 슬라이스: econ 레인 순서상 항목 11의 남은 (a) — `launchForecastLine`/`forecast_line`의 연료 기반 프레이밍 텍스트 재정의는 메인 레인 조율이 필요한 play.lua 텍스트 영역이라 이 레인에서 직접 처리하기보다 스코프 재확인이 필요하다. 항목 11의 (b)/(c) 엔진 레벨 정리는 이미 완료 상태이므로, 실질적으로 econ 레인의 다음 작업은 항목 15(a)의 마지막 남은 부분 — 옛 `beginReturn`/`"returning"` 페이즈/`useSlot`/`slotSpin` 및 관련 UI(조이스틱 하강 렌더, 슬롯 릴 애니메이션, `returnControls` 터치 밴드, `GAME_CAPTURE_PHASE=returning-*` 하네스)를 실제로 제거하는 것 — 로 넘어가는 것이 유력하다. `game/scenes/play.lua`의 returning 페이즈 UI/터치/키 입력 전반을 광범위하게 재작성해야 하는 큰 작업이라 메인 레인과의 조율이 여전히 필요하다.

## 항목 15(a) 두 번째 단계 — ascending 페이즈에 "r" 키로 즉시-귀환(`returnToEarth`) UI 연결 (완료, 2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 항목 15의 남은 부분 (a) — `beginReturn`/returning 페이즈/in-flight `slotSpin`·`useSlot` 폐지, 체크포인트/지구 도달 시 즉시 정산으로의 구조 전환 — 의 두 번째 슬라이스를 처리했다. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- 직전 슬라이스가 순수 추가로 `game/expedition.lua`에 `M.returnToEarth(run)`(ascending 페이즈에서만 동작, 기존 `settle()` 재사용해 즉시 settlement로 전환)을 엔진 API로만 만들어두었으나, 어디서도 호출되지 않아 실제 플레이로 접근 불가능한 상태였다. 이번 슬라이스에서 `game/scenes/play.lua`의 `M:keypressed`에 ascending 페이즈 전용 신규 `"r"` 키 분기를 추가해 이 엔진 API를 실제로 연결했다 — 성공 시 `self:persistBestAltitude()`(기존 returning-phase 진입 시 호출하던 것과 동일한 베스트 고도 영속화 부수효과)를 호출한 뒤 기존 `settled_message` i18n 문구(신규 문구 추가 없음, 기존 `returning`→`settlement` 전환 경로가 쓰던 것과 동일 포맷)로 정산 결과를 안내한다.
- **순수 추가(additive)다.** 기존 `M.beginReturn`/`"returning"` 페이즈/`M.useSlot`/`space`·`up`·`w` 키의 기존 동작(`returning` 페이즈에서의 슬롯 스핀 트리거 포함)은 전혀 건드리지 않았다 — `"r"` 키는 ascending 페이즈에서만 반응하는 완전히 새로운 분기이며, `beginReturn`으로 이미 `returning` 페이즈에 들어간 run에는 아무 영향이 없다(회귀 테스트로 확인).
- `game/self_test.lua`에 신규 `testReturnToEarthUiWiring()`을 추가했다 — ascending에서 `keypressed("r")`이 실제로 `expedition.returnToEarth`를 호출해 phase가 곧장 `settlement`로 전환되고 pending sample+slot 보상이 money로 정산됨, `settled_message`가 표시됨을 검증하고, launch 페이즈에서는 완전 no-op, 이미 `beginReturn`으로 `returning` 페이즈에 들어간 run에는 `"r"`이 아무 영향도 주지 않음(기존 경로 보존)을 회귀 검증한다. RED 확인: 구현 전 `scene.expedition.phase == "settlement"` 단언이 실패(`"r"` 키가 처리되지 않아 phase가 `"ascending"`으로 그대로 남음)함을 실제로 재현한 뒤 구현 → GREEN 전환 확인.
- `main.lua`에 신규 `GAME_CAPTURE_PHASE=return-to-earth` 개발 하네스를 추가하고 실제 LÖVE 런타임 캡처(1080×1920, ko 로케일)를 vision으로 확인했다 — "거리 0000 자금 $75", "정산 +$75  잔액 $75"(pendingSampleValue 60 + pendingSlotReward 15 = 75가 정확히 반영됨), "지구 상점" 화면이 크래시나 에러 텍스트 없이 정상 렌더링됨을 확인했다.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .`, `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 슬라이스 진행 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목 15(a)의 마지막 남은 부분 — 이제 `"r"` 키로 즉시 귀환이 실제 플레이에서 가능해졌으므로, 옛 `beginReturn`/`"returning"` 페이즈/`useSlot`/`slotSpin` 및 관련 UI(조이스틱 하강 렌더, 슬롯 릴 애니메이션, `returnControls` 터치 밴드, `main.lua`의 `GAME_CAPTURE_PHASE=returning-*` 하네스들)를 실제로 제거하는 것 — `game/scenes/play.lua`의 returning 페이즈 UI/터치/키 입력 전반을 광범위하게 재작성해야 하는 큰 작업이라 메인 레인과의 조율이 여전히 필요하다.

## 항목 15(a) 첫 단계 — ascending 페이즈에서 즉시 정산하는 신규 엔진 진입점 `M.returnToEarth(run)` 추가 (완료, 2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 항목 15의 남은 부분 (a) — `beginReturn`/returning 페이즈/in-flight `slotSpin`·`useSlot` 폐지, 체크포인트/지구 도달 시 즉시 정산으로의 구조 전환 — 의 첫 슬라이스를 처리했다. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- 이전 슬라이스들이 항목 15(b)/(c)(EARTH SHOP 전용 슬롯머신 엔진+UI 연결)까지 완료해두었고, 항목 15(a)는 여전히 미착수 상태였다. (a)는 `game/scenes/play.lua`의 returning 페이즈 UI/터치/키 입력 전반(조이스틱 하강 조작, 슬롯 릴 애니메이션, `returnControls` 터치 밴드)을 광범위하게 재작성해야 하는 큰 작업이라 이 레인 스코프 규칙(play.lua는 최소 구조적 변경만) 아래 한 사이클에 전량 착수하기 어렵다고 판단해, 먼저 안전하게 추가만 할 수 있는 엔진 레벨 진입점부터 슬라이스했다.
- `game/expedition.lua`에 `M.returnToEarth(run)`을 신규 추가했다 — `run.phase == "ascending"`일 때만 동작하고, 기존 `M.update()`의 `returning` 분기가 `altitude == 0`에서 호출하던 로컬 `settle(run)`(표본+슬롯 보류값 모두 정산, `run.phase = "settlement"`로 전환)을 그대로 재사용한다. 즉 `beginReturn` → returning 페이즈 하강 → altitude 0 도달의 3단계를 거치지 않고, ascending에서 곧장 settlement로 건너뛴다 — 항목 8의 체크포인트 정산과 동일한 "즉시 정산" 철학을 지구 복귀에도 적용한 것이다. 다른 페이즈(launch/returning/settlement/destroyed)에서 호출하면 어떤 상태도 바꾸지 않고 `false`만 반환한다.
- **이번 슬라이스는 순수 추가(additive)다.** 기존 `M.beginReturn`/`"returning"` 페이즈/`M.useSlot`/`game/scenes/play.lua`의 returning UI(조이스틱 하강, 슬롯 스핀 버튼, `returnControls` 터치 밴드, `main.lua`의 `GAME_CAPTURE_PHASE=returning-*` 캡처 하네스들, `game/self_test.lua`의 기존 `testManeuverFuel`/`main.lua`의 `beginReturn`/`useSlot` 호출부)는 전혀 건드리지 않아 회귀 위험이 없다 — 새 API가 아직 어디서도 호출되지 않는 순수 엔진 슬라이스다.
- `game/self_test.lua`에 신규 `testReturnToEarth()`를 추가했다 — ascending에서 pending sample/slot 값이 있는 run에 대해 `returnToEarth`를 호출하면 두 값이 합산되어 `run.money`로 정산되고 phase가 곧장 `settlement`로 전환됨(`lastSettlement`/`lastAltitude` 등 기존 settle() 부수효과 필드도 함께 기록됨)을 검증하고, launch 페이즈 및 이미 settlement인 run에서는 호출이 거부되어 상태가 전혀 바뀌지 않음을 검증한다. RED를 실제로 확인했다: `M.returnToEarth`를 임시로 주석 처리해 `game/self_test.lua:468: attempt to call field 'returnToEarth' (a nil value)`가 재현됨을 확인한 뒤 구현을 복원해 GREEN 전환을 재확인했다.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .`, `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 슬라이스 진행 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목 15(a)의 남은 부분 — `game/scenes/play.lua`가 실제로 `M.returnToEarth`를 호출하도록 UI를 연결(예: ascending 중 명시적 "귀환" 액션 키/버튼, 또는 항목 8의 체크포인트 정산처럼 자동 트리거 조건 설계)하고, 그 후 안전하게 `beginReturn`/`"returning"` 페이즈/`useSlot`/`slotSpin` 및 관련 UI(조이스틱 하강 렌더, 슬롯 릴 애니메이션, `returnControls`, `main.lua`의 `GAME_CAPTURE_PHASE=returning-*` 하네스들)를 제거하는 것 — `game/scenes/play.lua`의 returning 페이즈 UI/터치/키 입력 전반을 광범위하게 재작성해야 하는 큰 작업이라 메인 레인과의 조율이 필요하다.

## 항목 15(b) UI 연결 — settlement 페이즈 "m" 키로 EARTH SHOP 슬롯머신 실행 (완료, 2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 항목 15의 두 번째 슬라이스. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- 이전 슬라이스가 `game/expedition.lua`에 순수 엔진 API로만 추가했던 `M.spinEarthShopSlot(run)`(항목 15b — settlement 페이즈 전용, 고정 요금 `earthShopSlotCost=20`, `run.lastCheckpointGalaxyId`의 은하별 변동 오즈로 즉시 정산)가 여전히 어디서도 호출되지 않아 실제 플레이로 접근 불가능한 상태였다. 이번 슬라이스에서 `game/scenes/play.lua`의 `M:keypressed`에 settlement 페이즈 전용 신규 `"m"` 키 분기를 추가해 이 엔진 API를 실제로 연결했다 — 스핀 성공 시 `earth_shop_slot_result`(심볼/보상/잔액) 메시지, 요금 부족 시 기존 HULL/YIELD/STEERING/SCOUT 구매 키들과 동일한 `purchaseShortfallMessage` 패턴으로 안내한다.
- 이 레인 스코프 규칙(`game/scenes/play.lua`의 텍스트/HUD 세부 표현은 메인 레인 담당, 이 레인은 불가피한 최소 구조적 변경만)에 따라 새 버튼/터치 로우 등 시각 레이아웃은 추가하지 않고 키보드 입력 분기만 최소 추가했다 — settlement 화면의 기존 4개 `settlementTouchRows`도 건드리지 않았다. `game/i18n.lua`에 en/ko `earth_shop_slot_result`/`item_earth_shop_slot` 두 문구 쌍만 신규 추가했다(기존 문구는 전혀 수정하지 않음).
- `game/self_test.lua`에 신규 `testEarthShopSlotUiWiring()`을 추가했다 — settlement 페이즈에서 `keypressed("m")`이 실제로 `expedition.spinEarthShopSlot`을 호출해 잔액/메시지에 반영됨, 요금 부족 시 차감 없이 shortfall 메시지가 뜸, settlement가 아닌 페이즈(ascending)에서는 완전히 no-op임을 회귀 검증한다(RED 확인: 구현 전 `scene.message`가 `nil`/`keypressed`가 "m"을 처리하지 않아 단언 실패 → 구현 후 GREEN).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .`, `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 슬라이스 진행 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목 15의 남은 (a) — `beginReturn`/returning 페이즈/in-flight `slotSpin`·`useSlot`의 완전 폐지와 체크포인트/지구 도달 시 즉시 정산으로의 구조 전환(`game/scenes/play.lua`의 returning 페이즈 UI/터치/키 입력 전반을 광범위하게 재작성해야 하는 큰 작업, 메인 레인과의 조율 필요). UI 연출(슬롯 결과를 EARTH SHOP 화면에 시각적으로 그리는 것)은 메인 레인의 텍스트/HUD 영역이므로 이 레인은 엔진 연결까지만 완료로 본다.

- `tail -c` / `xxd`로 파일 끝을 직접 확인해 `docs/STATUS.md`가 `...진행.\n\n`(개행 두 개, 즉 EOF 직전 빈 줄)로 끝나고 있음을 재현했다(이전 사이클이 이 파일을 커밋 없이 수정한 상태로 남긴 잔재였다). 파일 끝을 단일 개행(`...진행.\n`)으로 정규화해 `git diff --check`가 더 이상 EOF 공백 경고를 내지 않도록 고쳤다. 이 파일의 본문 내용(이전 사이클이 작성한 항목 11(c) 네 번째 슬라이스 기록 포함)은 전혀 건드리지 않았다.
- `git status --short`로 세션 시작 시 `docs/feedback/INBOX.md`/`game/i18n.lua`/`game/self_test.lua`에 이전 사이클의 커밋되지 않은 작업(항목 11(c) i18n 잔재 문구 삭제 슬라이스)이 이미 존재함을 확인했다. 이 작업은 완결된 상태(관련 테스트 포함, GREEN)로 보여 그대로 보존하고 이번 커밋에 함께 포함시켰다.
- `git diff --check` 재실행으로 EOF 경고가 사라졌음을 확인(출력 없음 = clean).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`). 이 슬라이스는 공백/EOF 정규화와 기존 작업의 커밋일 뿐 신규 게임 로직 변경이 없어 런타임 캡처는 필요하지 않았다.
- 다음 사이클 다음 슬라이스: 위 297번째 줄(이전 사이클 기록)에서 이미 식별된 항목 11의 남은 부분(a: `launchForecastLine` 재정의, c: 활성 연료 필드 재설계) 중 하나, 또는 3번 항목(속도/스피드미터 아이콘화 재검토), 또는 6번(표본 도감 정리 + 슬롯 6개를 함선 장비 카드 UI로 전환)으로 진행.

## 항목 15(b)/(c) — EARTH SHOP 전용 슬롯머신 엔진(은하계별 변동 오즈) 신규 추가 (완료, 2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 항목 15의 첫 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- 항목 11이 이 레인 스코프 순서상 이미 완결로 보여(이전 사이클 기록 확인), 다음 순번인 항목 15로 넘어갔다.
- `game/expedition.lua`에 EARTH SHOP 전용 슬롯머신 엔진을 신규 추가했다:
  - `M.exploreCheckpoint(run, galaxyId)`가 이제 재방문 시에도 항상 `run.lastCheckpointGalaxyId`를 갱신한다(기존의 1회성 기어 지급/체크포인트 정산 가드와는 별개 필드).
  - `M.galaxySlotProfile(galaxyId)` — `nil`/`"milkyway"`는 기존 in-flight 표준 오즈와 동일한 `M.homeSlotProfile`(`COMET=5,PLANET=4,STAR=1`)을 반환하고, 그 외 은하는 신규 `M.stringHash`(문자열 id용 결정적 LCG 해시, `game/world.lua`의 숫자 해시와 동일한 방식을 이식)로 `M.safeSlotProfile`(`COMET=6,PLANET=3,STAR=1`, 표준보다 약간 안전)과 `M.riskySlotProfile`(`COMET=2,PLANET=3,STAR=5`, STAR 비중 확대 — 브리핑의 "화성/외곽 은하 슬롯은 고배당/위험부담형" 예시에 대응) 중 하나에 결정적으로 배정된다.
  - `M.weightedSlotSymbol(roll, weights)`를 선택적 `weights` 인자를 받도록 확장(기본값은 기존 in-flight `slotWeights`)해 EARTH SHOP 오즈도 동일한 가중 추첨 로직을 재사용하도록 했다(회귀 위험 최소화 — 기존 in-flight 호출부는 인자 없이 그대로 동작).
  - `M.earthShopSlotExpectedValue(galaxyId)`가 기존 `M.slotExpectedValue`와 동일한 완전 열거(brute-force) 방식으로 특정 은하 오즈 테이블의 기대값을 계산한다(테스트/향후 UI 표시용).
  - `M.spinEarthShopSlot(run)`(신규 공개 진입점) — settlement 페이즈에서만 동작(비행 중 페이즈는 거부), 고정 요금(`M.earthShopSlotCost = 20`)을 `run.money`에서 선차감한 뒤 `run.lastCheckpointGalaxyId`의 오즈 테이블로 3릴을 돌려 보상을 즉시 `run.money`에 반영한다(귀환 슬롯의 "파괴되면 미확정" 잠정 보상 모델과 달리, 지구에 이미 안전 도착한 이후의 순수 오락 요소이므로 즉시 확정). 결과는 `run.lastEarthShopSlotSymbols`/`lastEarthShopSlotReward`/`lastEarthShopSlotGalaxyId`에 기록된다.
- `game/self_test.lua`의 신규 `testEarthShopSlotMachine()`이 다음을 회귀 검증한다: 홈/미탐사 상태는 표준 오즈, 임의의 여러 은하 id가 결정적으로 두 변동 테이블 모두에 분산됨, 위험 테이블의 기대값이 안전 테이블보다 항상 높음, 체크포인트 재탐사 시에도 최근 은하 id가 갱신됨, `M.spinEarthShopSlot`이 settlement 페이즈만 허용하고 요금 부족 시 거부하며 정확한 요금 차감 후 보상을 반영함(RED 확인: `expedition.galaxySlotProfile`/`spinEarthShopSlot` 등이 없어 `attempt to call a nil value` → GREEN 전환).
- `game/scenes/play.lua`는 이 레인 스코프 규칙(구조적 죽은코드/불가피한 최소 변경만, 텍스트/HUD는 메인 레인)에 따라 건드리지 않았다 — 새 엔진 API는 아직 UI에 연결되지 않은 순수 엔진 슬라이스다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:43`, `ASSET_MANIFEST_OK`). 신규 게임 로직이나 화면 변화는 없는 순수 엔진 추가이므로 실제 LÖVE 런타임 캡처는 이번 슬라이스에서 필요하지 않았다.
- `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 슬라이스 진행 상황을 append했다.
- 다음 사이클 다음 슬라이스: 이 레인 스코프 순서상 항목 15의 남은 부분 — (a) `beginReturn`/returning 페이즈/in-flight `slotSpin`·`useSlot`의 완전 폐지와 체크포인트/지구 도달 시 즉시 정산으로의 구조 전환(`game/scenes/play.lua`의 returning 페이즈 UI/터치/키 입력 전반을 광범위하게 재작성해야 하는 큰 작업, 메인 레인과의 조율 필요), (b)의 UI 노출(EARTH SHOP 화면에 `M.spinEarthShopSlot`을 실제로 그리고 누를 수 있게 하는 `game/scenes/play.lua` 연결).

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

## 항목 15(a) 정찰 슬라이스 — 코드 변경 없음, 다음 사이클 실행 계획만 확정 (2026-09-03)

`docs/feedback/INBOX.md`의 econ 레인 스코프 순서(항목7→8→11→15) 중 마지막으로 남은 항목 15(a) — 옛 `beginReturn`/`"returning"` 페이즈/in-flight `slotSpin`·`useSlot`의 완전 폐지 — 를 이번 사이클에 실제로 착수하려 했다. preflight READY(`engine tests and package` PASS, `git diff` clean), 세션 시작 `git status --short` clean, 이전 사이클이 남긴 미커밋 작업 없음.

- `game/expedition.lua`(`M.beginReturn`/`M.useSlot`/`spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`와 그 상수, `M.update`의 `"returning"` 분기, `settle()`/`destroy()`/`M.new()`/`M.launch()`의 관련 필드 초기화·리셋), `game/scenes/play.lua`(`returnControls`, `slotButtonState`/`beginSlotSpin`/`currentSlotReels`, `collisionRisk`/`approachWarning`/`hudLines`/`pollDesktopMouse`/`M:update`의 이동·충돌 블록/`keypressed`의 space-bar 슬롯 분기/`touchpressed`의 return-band 처리/`drawMinimap`의 odds 줄/`draw()`의 returning 전용 슬롯 UI 블록, `M.hudOddsLineHeight`/`M.hudHeight`의 returning 분기), `main.lua`(`returning-odds`/`returning-repair`/`returning-fuelbonus`/`returning-samplebonus`/`full-loop-relaunch` 5개 `GAME_CAPTURE_PHASE` 하네스), `game/self_test.lua`(`expedition.beginReturn`/`expedition.useSlot` 호출부 다수, `testReturnToEarthUiWiring`의 "beginReturn 경로 보존" 검증)를 전부 재확인해 이전 사이클(`logs/loop-2026-09-03.log`)의 추적 결과가 여전히 정확함을 검증했다.
- 이 재확인 과정에서 `expedition.slotReward`/`weightedSlotSymbol`/`slotExpectedValue`/`slotSymbolProbability`는 LAUNCH LOADOUT/EARTH SHOP의 `slotOddsLine` 미리보기와 `spinEarthShopSlot`(항목 15b/c, EARTH SHOP 전용 슬롯머신, 이미 완료)이 계속 사용하므로 15(a) 제거 대상이 **아니며**, `spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`(그리고 이들의 in-flight 전용 소비자인 `M.useSlot`)만 returning 전용이라 제거 대상임을 새로 명확히 확정했다. 이 구분을 정확히 하지 않고 편집을 시작했다면 이미 완료된 EARTH SHOP 슬롯머신(15b/c)까지 회귀시킬 위험이 컸다.
- **이번 사이클은 코드 변경을 내지 못했다.** 위 재확인 작업 자체가 안전한 편집을 위한 필수 선행 단계였고, 시간 예산이 여기서 소진되어 실제로 커밋 가능한 diff를 만들기 전에 중단했다. `game/expedition.lua`/`game/scenes/play.lua`/`main.lua`/`game/self_test.lua`에 대한 실제 코드 diff는 이번 사이클에 전혀 없다.
- `make test`를 재실행해 코드가 변경되지 않았음을 확인했다 — `SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `tools.test_verify_asset_manifest` 9건 모두 GREEN(직전 사이클과 동일 상태 유지).
- `docs/feedback/INBOX.md` 처리대기 항목 15 하위에 이번 정찰 슬라이스 기록과, 다음 사이클이 그대로 실행할 수 있는 4단계 슬라이스 계획(엔진→UI→하네스→테스트, 매 슬라이스마다 `make test` GREEN 확인)을 append했다.
- 다음 사이클 다음 슬라이스: 위 INBOX.md에 기록한 4단계 계획의 (1)부터 순서대로 — 먼저 `game/expedition.lua`에서 `M.beginReturn`/`M.useSlot`/`spinSlot`/`slotRepairVoucher`/`slotFuelBonus`/`slotSampleBonus`와 관련 상수/필드만 제거(EARTH SHOP 슬롯 관련 API인 `M.slotReward`/`M.weightedSlotSymbol`/`M.slotExpectedValue`/`M.slotSymbolProbability`는 절대 건드리지 말 것)하고 `make test`로 GREEN 확인 후 커밋, 그 다음 슬라이스에서 `game/scenes/play.lua`의 UI/터치/키 입력을, 그 다음 `main.lua`의 캡처 하네스를, 마지막으로 `game/self_test.lua`의 테스트 단언을 정리한다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
