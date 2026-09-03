# STATUS
## [gear 레인] 항목9/14 (A) `money` gap — 5개 (A) 가산형 중 마지막 잔여였던 설정금 정산 보너스를 배선 (완료, 2026-09-03)

레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료 상태였고, 이 레인이 반복 적용해온 "문서-코드 정합성 감사" 패턴을 이번 사이클에도 다시 적용했다. 항목14의 원 (A) 5종(speed/sampleSellValue/money/climbSpeed/hullDurability) 중 speed(직전 사이클)/climbSpeed/sampleSellValue/hullDurability는 이미 run에 배선됐지만, `money`(선체 부품의 소지금 직접 증감 기여)는 `hull_parts.json`에 3종, `engine_parts.json`에도 다수 카드가 실재함에도 `gearModule.equippedTotals(...).money`를 읽는 run 함수가 단 하나도 없어 조금도 실제 소지금에 반영되지 않는 죽은 콘텐츠였다 — 항목14의 5개 (A) 가산형 전체 중 유일하게 남아있던 마지막 gap이었다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- TDD: `game/self_test.lua`에 신규 `testGearMoneyRunWiring()`을 먼저 추가했다(RED 확인: "a money +15 hull card must raise the settlement payout from 50 to 65 ... got 50" 실패).
- `game/expedition.lua`에 신규 `M.equippedHullMoneyBonus(run)`(`gearModule.equippedTotals(run.equippedGear or {}).money` 읽기, hull 전용 — climbSpeed/sampleSellValue/hullDurability/speed와 동일하게 항목9가 "선체(조커형)" 콤보 페이오프로 명시한 스코프)를 추가했다.
- `money`는 다른 (A) 형제들(틱당 비율 또는 표본당 보너스)과 달리 원정 완료 시 1회 지급되는 정산 보너스로 자연스럽게 읽혀, 매 프레임/매 표본 함수가 아니라 `settle(run)`(원정이 지구로 복귀해 정산되는 유일한 지점)에 배선했다 — `payout = lastSampleSettlement + lastSlotSettlement + M.equippedHullMoneyBonus(run)`.
- `testGearMoneyRunWiring()` 회귀 검증: 미장착 run은 표본+슬롯 pending 값 그대로 정산(40+10=50), `money +15` 선체 카드 장착 시 정확히 65로 정산, 동일 카드를 엔진 슬롯에 장착하면 hull 전용 스코프대로 제외되어 50 그대로 유지.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/GEAR_SCHEMA.md`에 "Item 9/14 (A) `money` run-state gap — `settle(run)` closes the last (A) additive gap" 섹션을 신규 추가했다.
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 9 하위에 처리 상황을 append했다.
- **이로써 항목14의 (A) 가산형 5종(speed/sampleSellValue/money/climbSpeed/hullDurability) 전체가 실제 run 상태에 배선되어, 지금까지 이 레인이 발견한 "스키마 등록만 되고 죽어있던" (A) 카테고리 잔여 gap이 모두 닫혔다.**
- 다음 사이클 다음 슬라이스: 이 감사 패턴을 (B)~(G) 카테고리 각 효과 타입에도 재적용해 다른 잔여 gap이 남아있는지 재검증(예: 엔진 부품 쪽 (A) 카드들이 hull과 동일한 스코프 설계 의도를 만족하는지, 엔진 전용 `money`/`climbSpeed` 카드가 있다면 그 스코프가 문서화된 설계와 일치하는지 확인), 또는 항목7(획득 경로 3원화) 순수 함수 계층 검토.

## [gear 레인] 항목9/14 (A) `speed` gap — 선체 `speed` 카드 7종이 조종 속도에 반영되지 않던 것을 발견·배선 (완료, 2026-09-03)

레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료 상태였고, 직전 사이클이 `hullDurability` gap을 처리하며 "이 감사 패턴을 다른 (A) 가산형 잔여에도 계속 적용" 하도록 다음 슬라이스로 명시했다. 이번 사이클에서 그 잔여를 찾아 처리했다: 항목14의 원 (A) 5종(speed/sampleSellValue/money/climbSpeed/hullDurability) 중 climbSpeed/sampleSellValue/hullDurability는 이미 run에 배선됐지만, `speed`(선체 부품의 조종/기동 속도 기여, 엔진 부품의 퍼센트형 `steeringResponsiveness`(G)와는 별개)는 `hull_parts.json`에 7종 카드가 실재함에도 `M.steeringSpeed(run)`을 포함한 어떤 run 함수도 `equippedTotals(...).speed`를 읽지 않아 조종 속도에 조금도 반영되지 않는 죽은 콘텐츠였다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- TDD: `game/self_test.lua`에 신규 `testGearHullSpeedRunWiring()`을 먼저 추가했다(RED 확인: "equipping a speed +8 hull card must raise steeringSpeed from 55 to 63 ... got 55" 실패).
- `game/expedition.lua`에 신규 `M.equippedHullSpeedBonus(run)`(`gearModule.equippedTotals(run.equippedGear or {}).speed` 읽기, hull 전용 — climbSpeed/sampleSellValue/hullDurability와 동일하게 항목9가 "선체(조커형)" 콤보 페이오프로 명시한 스코프)를 추가했다.
- `M.steeringSpeed(run)`이 기존 `baseSteeringSpeed + steeringUpgradeLevel*steeringUpgradeAmount` 합에 이 보너스를 먼저 가산한 뒤, 기존처럼 엔진 부품의 `steeringResponsiveness` 퍼센트 배율(`gearModule.effectiveSteeringRate`)을 곱연산으로 적용하도록 변경했다 — 가산 후 곱연산이라 선체 `speed` 카드와 엔진 `steeringResponsiveness` 카드가 서로를 대체하지 않고 함께 누적된다.
- `testGearHullSpeedRunWiring()` 회귀 검증: 미장착 run은 기존 공식 그대로(55), `speed +8` 선체 카드 장착 시 정확히 63으로 상승, 동일 카드를 엔진 슬롯에 장착하면 hull 전용 스코프대로 제외되어 55 그대로 유지, 선체 `speed`(+8)와 엔진 `steeringResponsiveness`(+50%)가 함께 있으면 55+8=63 다음 ×1.5=94.5로 정확히 계산됨(가산-후-곱연산 순서 검증).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/GEAR_SCHEMA.md`에 "Item 9/14 (A) `speed` run-state gap — `M.steeringSpeed` closes it" 섹션을 신규 추가했다.
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 9 하위에 처리 상황을 append했다.
- 다음 사이클 다음 슬라이스: 이 감사 패턴을 항목9/10/12/13/14에 계속 적용해 다른 잔여 gap이 남아있는지 재검증(예: 엔진 부품 쪽 (A) `money`/`climbSpeed`/`speed` 카드가 hull과 동일하게 실제 소비되는지, 또는 항목7 획득 경로 3원화의 순수 함수 계층 검토).

## [gear 레인] 항목9/14 (A) hullDurability gap — 9종 카드가 실제로는 죽은 콘텐츠였던 것을 발견·배선 (완료, 2026-09-03)

레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료 상태였으나, 이 레인이 반복 적용해온 "문서-코드 정합성 감사" 패턴을 이번 사이클에도 다시 적용해 새 gap을 찾아 처리했다. `gear.equippedTotals`가 항목14 첫 슬라이스 때부터 (A) `hullDurability` 효과를 가산 합산해왔고, `hull_parts.json`에는 항목9의 24종 확장 이후 `hullDurability` 카드가 9종(`hull_scrap_plate`, `hull_titan_frame` 등) 실재했지만, `run.maxDurability`를 계산하는 유일한 지점인 `refreshShipStats(run)`가 이 총합을 전혀 읽지 않아 이 9종 카드를 장착해도 선체 최대 내구도가 조금도 달라지지 않았다 — 항목9가 명시한 "부품 조합이 실제 스탯에 배가 효과"의 (A) 가산형 카테고리 중 하나가 이 레인의 전체 작업 기간 동안 조용히 죽어있던 콘텐츠였다(이전 사이클들이 이미 sampleSellValue/sellMultiplier, irradiated 시너지, noSlotCost, boostCharge 소비에서 동일한 패턴의 gap을 발견·처리한 것과 완전히 같은 유형). preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- TDD로 `game/self_test.lua`에 신규 `testGearHullDurabilityRunWiring()`을 먼저 추가했다(RED 확인: "equipping a hullDurability +2 hull card must raise maxDurability from 3 to 5 ... got 3" 실패).
- `game/expedition.lua`에 신규 private `equippedHullDurabilityBonus(run)`(공개 `M.equippedHullDurabilityBonus`로도 노출)이 `gearModule.equippedTotals(run.equippedGear or {}).hullDurability`를 읽는다 — `M.effectiveClimbSpeed`/`M.effectiveSampleBonus`와 동일하게 hull 전용(엔진 슬롯 미포함, 항목9가 콤보 페이오프를 선체 부품으로 명시적으로 한정하기 때문).
- `refreshShipStats(run)`가 기존 `baseDurability + shipBonus + upgradeLevel*upgradeAmount` 공식에 이 보너스를 가산하도록 변경했다.
- `refreshShipStats`가 기존에는 발사/상점구매/함선선택 지점에서만 호출돼 장비 장착/해제 시점에 즉시 반영되지 않았으므로, `M.equipGear`/`M.unequipGear`가 `hull` 카테고리에 한해 즉시 `refreshShipStats`를 재호출하도록 확장했다. 아직 첫 발사 전(`run.phase == "launch"`, 발사 전 로드아웃 화면)에는 현재 `durability`도 재계산된 max에 맞춰 동기화한다(장착 시 상향, 해제 시 하향 클램프) — `M.new`가 보장하는 "아직 발사하지 않은 run은 항상 durability == maxDurability" 불변식과 일치시킴. 엔진 카테고리 장착/해제는 그대로 둔다(hullDurability는 hull 전용 스코프이므로 재계산도 durability 동기화도 하지 않음).
- `testGearHullDurabilityRunWiring()` 회귀 검증: 미장착 run은 기존 base+ship+upgrade 공식 그대로(3), `hullDurability +2` 선체 카드 장착 후 발사하면 maxDurability가 3→5로 오르고 현재 durability도 5로 채워짐, 동일 카드를 엔진 슬롯에 장착하면 hull 전용 스코프대로 제외되어 maxDurability가 3 그대로 유지됨, 장비 hullDurability(+2)와 구매한 durabilityUpgradeLevel(+1)이 base 3 위에 함께 가산됨(합계 6).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/GEAR_SCHEMA.md`에 "Item 9/14 (A) `hullDurability` run-state gap — `refreshShipStats` closes it" 섹션을 신규 추가했다.
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`와, 이번 슬라이스가 건드릴 필요 없었던 `game/gear.lua`/`game/engine_parts.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 9 하위에 처리 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화) 순수 함수 계층 검토, 또는 이 감사 패턴을 계속 적용해 항목9/10/12/13/14의 다른 잔여 gap을 재검증(예: `hullDurability`처럼 스키마-등록만 되고 run 소비자가 없던 다른 조합이 아직 남아있는지).

## [spaceship-gear 레인] 항목9/14 gap — `sampleSellValue`/`sellMultiplier` 실 게임 미소비 발견·배선 — `M.effectiveSampleBonus` (완료, 2026-09-03)

레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료된 상태였으나, 이전 슬라이스들이 반복해온 "문서-코드 정합성 감사" 패턴을 이번 사이클에도 다시 적용해 새 gap을 찾아 처리했다. `gear.equippedTotals`가 item 14 첫 슬라이스 때부터 (A) `sampleSellValue` 가산 총합에 (B) `sellMultiplier` 배율을 곱연산 1회로 적용해왔고, 번들 데이터에도 `hull_parts.json` 기준 `sampleSellValue` 카드 8종 + `sellMultiplier` 카드 1종(`hull_market_broker`)이 실재했지만, `game/expedition.lua`의 어떤 함수도 이 `equippedTotals.sampleSellValue` 값을 실제로 읽지 않아 이 9종 카드를 장착해도 표본 채집으로 버는 실제 금액이 조금도 달라지지 않았다 — item 9가 명시한 "부품 조합이 고도 상승 속도/효율에 배가 효과"의 경제 쪽 절반이(고도 쪽은 이미 `M.effectiveClimbSpeed`로 배선됨) 이 레인의 전체 작업 기간 동안 조용히 죽어있던 콘텐츠였다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- TDD로 `game/self_test.lua`의 기존 `testGearRunEffectWiring()`을 확장했다(RED 확인: `attempt to call field 'effectiveSampleBonus' (a nil value)`).
- `game/expedition.lua`에 신규 `M.effectiveSampleBonus(run)` — `gear.equippedTotals(run.equippedGear or {}).sampleSellValue`를 그대로 노출한다. `M.effectiveClimbSpeed`와 동일하게 hull 전용(엔진 슬롯은 포함하지 않음) — item 9가 콤보 시너지 대상을 선체("조커형") 부품으로 명시적으로 한정하기 때문에 (C)/(E) 카테고리 무관 래퍼들과는 의도적으로 다른 설계.
- `M.collectSample(run, value, hueKey)`가 기존 `sampleYieldMultiplier × streakMultiplier` 체인을 적용해 반올림(floor)한 값에 `M.effectiveSampleBonus(run)`을 가산(insurance/collisionRadius와 동일하게 "최종 산출값을 수정" 자세 — 배율 체인 내부로 접지 않음, 카드의 raw value가 배율이 아니라 고정 수치이므로 최종 가산이 자연스러움).
- `testGearRunEffectWiring()`이 다음을 회귀 검증한다: 미장착 run은 `effectiveSampleBonus == 0`, `sampleSellValue=10`+`sellMultiplier=50` 카드 장착 시 `effectiveSampleBonus == 15`(`10 * 1.5`, `testGearEffectSchemaExpansion`이 이미 검증한 `equippedTotals` 수학과 일치), 실제 `collectSample(run, 100)` 호출이 정확히 115(기본 100 + 가산 보너스 15)를 반환.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/GEAR_SCHEMA.md`에 "Item 9/14 economy-stat gap ... `M.effectiveSampleBonus`" 섹션을 신규 추가했다.
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`와, 이번 슬라이스가 건드릴 필요 없었던 `game/gear.lua`/`game/engine_parts.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 14 하위(항목15 앞)에 처리 상황을 일곱 번째 슬라이스로 append했다.
- 여전히 미착수: `sellMultiplier`/`sampleSellValue`를 쓰는 엔진 슬롯 카드(현재 번들 `engine_parts.json`에는 둘 다 0종 — 이번 슬라이스는 이미 콘텐츠가 있던 hull 쪽 소비자 gap만 닫음), 상점/체크포인트 UI가 장착 중인 기어의 실제 예상 표본 보너스를 시각적으로 표시하는 지점(`play.lua`, 레인 스코프 밖), 실제 상점 UI에서 "무료 리롤" 버튼이 `M.spendReroll`을 호출하는 지점(이전 슬라이스부터 계속 미착수).
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점 행성 좌표 생성 등 순수 함수/데이터 계층에서 준비 가능한 부분)의 순수 함수 계층 검토, 또는 엔진 슬롯 전용 `sampleSellValue`/`sellMultiplier` 카드 콘텐츠 추가(item 10b가 엔진을 추진/기동 특화로 차별화하라고 명시했으므로 신중히 검토 필요 — 무분별하게 늘리면 hull/engine 역할 분리 취지가 흐려짐), 또는 이 감사 패턴을 계속 적용해 항목9/10/12/13/14의 다른 잔여 gap을 재검증.

## [spaceship-gear 레인] 항목14(C) `rerollBonus` 소비 배선 — `M.rerollsRemaining`/`M.spendReroll` (완료, 2026-09-03)

이 레인(`spaceship-gear` 브랜치)이 지정받은 항목13→9→10→12→14가 모두 1차 완료된 상태에서, 항목14 (C) `rerollBonus`가 문서상 "run-level 소비자 있음"으로 기록돼 있었으나 실제로는 `M.rerollCount(run)`이라는 매 호출마다 재계산되는 순수 파생값만 존재하고, 실제로 리롤을 "쓰고" 잔여량이 줄어드는 소비 경로가 전혀 없었던 gap을 감사로 발견해 처리했다. 이는 같은 (C)/(E) 계열의 `chainTrigger`/`detectionRadius`/`autoCollect`(상태 없는 매 틱 수정자로 정상)와 달리, "무료 리롤"은 개념상 소비되어 고갈되는 자원이어야 하는데 그 소비 메커니즘 자체가 없었다는 뜻이다(같은 (D) 카테고리의 `insurance`가 `run.insuranceUsed`라는 1회성 boolean으로 실제 소비되는 것과 대비됨). preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- TDD로 `game/self_test.lua`의 기존 `testGearRunEffectWiring()`을 확장했다(RED 확인: `attempt to call field 'rerollsRemaining' (a nil value)`).
- `game/expedition.lua`에 신규 `run.rerollsUsed`(현재 원정에서 이미 소비한 리롤 수, `M.new`에서 0 초기화)를 추가하고 `M.launch`의 재발사 분기와 전체 메타 초기화 `destroy(run)` 양쪽에서 0으로 리셋하도록 배선했다(`run.insuranceUsed`와 완전히 동일한 생명주기).
- 신규 `M.rerollsRemaining(run)` — `M.rerollCount(run) - run.rerollsUsed`, 0 미만으로 내려가지 않도록 클램프. `M.rerollCount(run)`이 여전히 장착 부품 기준 실시간 총합이므로, 원정 중 리롤 부품을 추가 장착하면 잔여 한도가 즉시 올라간다(별도 재계산 로직 불필요).
- 신규 `M.spendReroll(run)` — 원자적, 예외 없음: 잔여 리롤이 있으면 `true` + `run.rerollsUsed` 1 증가, 없으면 `false, "no free rerolls remaining"` + 상태 불변(`M.equipGear`/`M.sellGear`와 동일한 "부분 적용 없음" 계약).
- `testGearRunEffectWiring()`이 다음을 회귀 검증한다: 미장착 run은 `rerollsRemaining == 0`이고 `spendReroll`이 즉시 거부됨, `rerollBonus` 카드(floored 총합 2) 장착 run은 `rerollsRemaining == 2`로 시작해 두 번의 연속 `spendReroll` 성공 후 정확히 0으로 고갈됨, 세 번째 호출은 `false` + 에러 메시지로 거부되며 상태를 더 감소시키지 않음, 같은 run을 재발사(`M.launch`)하면 잔여가 장착 총합(2)으로 다시 채워짐.
- 감사 과정에서 `docs/GEAR_SCHEMA.md`의 "(B) multiplicative" 단락이 여전히 `streakMultiplier`를 "run-state 소비자 없음"으로 서술해, 이후 슬라이스("Item 14(B) streakMultiplier run wiring")의 실제 완료 상태와 모순되던 stale 문서를 함께 정정했다(코드 변경 없음, 순수 문서 정확성 수정 — 후속 섹션을 가리키도록 교차 참조로 교체).
- `docs/GEAR_SCHEMA.md`에 "Item 14(C) rerollBonus consumption wiring — M.rerollsRemaining / M.spendReroll" 섹션을 신규 추가했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`와, 이번 슬라이스가 건드릴 필요 없었던 `game/gear.lua`/`game/engine_parts.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 14 하위(항목15 앞)에 처리 상황을 여섯 번째 슬라이스로 append했다.
- 여전히 미착수: 실제 상점 UI에서 "무료 리롤" 버튼이 `M.spendReroll`을 호출하는 지점(`play.lua` 담당, 레인 스코프 밖).
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점 행성 좌표 생성 등 순수 함수/데이터 계층에서 준비 가능한 부분)의 순수 함수 계층 검토, 또는 이 레인이 완료한 항목13→9→10→12→14 순서 밖의 잔여 작업 재검토(문서-코드 정합성 감사 패턴이 이번에도 실제 gap을 찾아냈으므로, 다음 슬라이스도 각 STATUS.md/GEAR_SCHEMA.md "완료" 주장을 코드로 재검증하는 방식이 유효할 수 있음).

## [spaceship-gear 레인] 항목14(D) `collisionRadius` 마지막 run-level gap 배선 (완료, 2026-09-03)

`docs/GEAR_SCHEMA.md`가 "항목14의 (A)~(F) 전 카테고리가 최소 1개 run-level 배선을 갖는다"고 여러 차례 명시했으나, 실제로 코드를 확인해보니 (D) 카테고리의 `collisionRadius`(`gear.effectiveCollisionRadius`)만 유일하게 `game/expedition.lua`에 run 래퍼가 없는 상태였다 — 같은 (D)의 `insurance`는 이미 `M.damage`에 배선됐고, (C)/(E)의 `chainTrigger`/`rerollBonus`/`detectionRadius`/`autoCollect`는 이전 슬라이스에서 배선됐으나 `collisionRadius`만 문서의 낙관적 서술과 달리 실제로는 빠져 있었다. 레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료된 상태였고, 이번 사이클은 문서가 반복적으로 "전 카테고리 완료"라 주장했던 것을 코드로 직접 검증해 발견한 이 실제 gap을 닫았다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- 코드 감사: `game/expedition.lua`에서 `gear.effectiveCollisionRadius`를 감싸는 함수가 전혀 존재하지 않음을 `search_files`로 확인(반면 같은 (C)/(E) 계열의 `detectionRadius`/`autoCollectEnabled`/`chainTriggerCount`/`rerollCount`는 모두 존재).
- TDD로 `game/self_test.lua`에 `testGearCollisionRadiusRunWiring()`을 먼저 추가했다(RED 확인: `attempt to call field 'collisionRadius' (a nil value)`).
- `game/expedition.lua`의 신규 `M.collisionRadius(run, baseRadius)` — 기존 `combinedGearList(run)` 헬퍼(hull+engine 합산, item 10의 슬롯 수 독립성은 유지하되 이 효과 타입의 스탯 풀은 카테고리 무관)를 재사용해 `gear.effectiveCollisionRadius(baseRadius, combinedGearList(run))`를 얇게 감싼다. `loop/PROMPT.md`가 허용한 "최소한의 로더 호출" 예외 범위에서 `game/expedition.lua`만 수정했다(`play.lua`/`i18n.lua`/`world.lua` 미변경).
- `game/self_test.lua`의 `testGearCollisionRadiusRunWiring()`이 다음을 회귀 검증한다: 미장착 run은 기저 반경 그대로 반환, hull 카드에 `collisionRadius +20` 장착 시 기저 10 → 정확히 8로 축소, ENGINE 슬롯 카드에 `collisionRadius +50` 장착 시에도 기저 10 → 정확히 5로 축소(카테고리 무관 설계 재확인).
- `docs/GEAR_SCHEMA.md`에 "Item 14(D) collisionRadius run wiring" 섹션을 신규 추가해 이 gap과 그 해소를 명시적으로 문서화했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 14 하위(항목15 앞)에 처리 상황을 다섯 번째 슬라이스로 append했다.
- **이로써 항목14의 (A)~(G) 전 효과 타입이 실제로 예외 없이 최소 1개 run-level 소비자를 갖는다** — 이전 사이클들의 "전 카테고리 완료" 서술이 실제로 정확해졌다.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점 행성 좌표 생성 등 순수 함수/데이터 계층에서 준비 가능한 부분)의 순수 함수 계층 검토, 또는 이 레인이 완료한 항목13→9→10→12→14 순서 밖의 잔여 작업 재검토. 실제 게임플레이 소비 지점(충돌 판정에 `M.collisionRadius` 실사용, 상점/체크포인트 UI가 `M.rollGearOffer` 호출 등)은 대부분 `play.lua`/`world.lua` 담당이라 다른 레인 소관.

## [spaceship-gear 레인] 항목12 `noSlotCost`(refined 에디션) 슬롯 예외 배선 (완료, 2026-09-03)

`docs/GEAR_SCHEMA.md`/`game/gear.lua`가 항목12 슬라이스 이후 계속 "reserved metadata for a future no-slot-cost mechanic ... not yet wired" 라고 명시해 온 마지막 미배선 항목을 처리했다. 레인이 지정받은 5개 항목(13→9→10→12→14)의 순수 함수/데이터/run 배선 계층이 이전 사이클들에서 이미 1차 완료된 상태였고, 이번 사이클은 `docs/GEAR_SCHEMA.md`가 문서상 명시적으로 남겨둔 "아직 안 됨" 항목 중 유일하게 남아있던 항목12의 `refined` 에디션 `noSlotCost` 플래그를 실제 슬롯 계산에 연결했다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- TDD로 `game/self_test.lua`에 `testGearNoSlotCostEditionWiring()`을 먼저 추가했다(RED 확인: `attempt to call field 'isNoSlotCost' (a nil value)` — `game/gear.lua`에 이 변환 함수가 아직 없었음, `game/gear.lua`/`game/engine_parts.lua`를 `git stash`로 되돌려 실제 실패를 재현 확인).
- `game/gear.lua`의 신규 `M.isNoSlotCost(editionId)` — 순수 함수, `M.editionEffects[editionId].noSlotCost`가 `true`인 경우(현재는 `refined`만 해당)에만 `true`를 반환한다.
- `game/engine_parts.lua`가 신규로 `game.gear`를 require(단방향 — `gear.lua`는 `engine_parts.lua`를 require하지 않아 순환 의존 없음)하고, 신규 private `occupiedSlotCount(list)` 헬퍼가 `gear.isNoSlotCost(part.edition)`인 카드를 슬롯 점유 카운트에서 제외하도록 `M.isFull`/`M.equip`을 갱신했다 — `refined` 카드는 해당 카테고리(hull 6/engine 3)가 이미 가득 차 있어도 예외적으로 장착 가능해진다(발라트로 네거티브 조커의 "슬롯을 소모하지 않음" 컨셉 실구현). 일반(비-`refined`) 카드의 기존 동작(정확히 6/3에서 거부)은 완전히 그대로 유지된다.
- `game/self_test.lua`의 `testGearNoSlotCostEditionWiring()`이 다음을 회귀 검증한다: `gear.isNoSlotCost`의 진리표(`refined`→true, 다른 에디션/nil→false), 일반 카드 6장으로 hull 슬롯을 정상적으로 가득 채움(기존 동작 불변), 가득 찬 상태에서 추가 일반 카드는 여전히 거부, `refined` 카드는 가득 찬 상태에서도 장착에 성공하고 실제로 슬롯 리스트에 추가됨, 그 후에도 `isFull`이 여전히 true(일반 카드 6장이 이미 채웠으므로 무관), 일반 카드 1장 해제 시 정확히 1자리만 비어 새 일반 카드로 다시 채울 수 있음, engine 카테고리는 hull 쪽 `noSlotCost` 처리와 완전히 무관하게 유지됨(항목10 슬롯 독립성 보존).
- `docs/GEAR_SCHEMA.md`에 "Item 12: `noSlotCost` edition wiring" 섹션을 신규 추가하고, 기존 `refined` 에디션 설명의 "reserved metadata ... not yet wired" 문구를 실제 배선 완료로 갱신했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/gear.lua`/`game/engine_parts.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 12 하위에 처리 상황을 append했다.
- 다음 사이클 다음 슬라이스: 이 레인이 지정받은 5개 항목(13/9/10/12/14)의 문서상 명시적 미배선 gap은 이제 모두 닫힌 상태다. 다음은 항목7(획득 경로 3원화 — 상점 행성 좌표 생성 등 순수 함수/데이터 계층에서 준비 가능한 부분) 또는 항목9/10/12/14 각 함수의 실제 게임플레이 소비 UI(상점 화면의 refined 카드 시각적 "슬롯 무점유" 표시 등, `play.lua` 담당이라 이 레인의 최소 로더 호출 예외 범위 밖) 중 우선순위에 따라 선택.

## [spaceship-gear 레인] 항목9(c) — 슬롯 교체/판매 경제 루프 `M.sellGear` (완료, 2026-09-03)

`docs/feedback/INBOX.md` 항목 9의 마지막 명시적 잔여였던 (c)("슬롯 수(현재 6개)를 장비 장착 한도로 유지하되... 카드 획득... 과 교체가 잦아지는 루프를 설계한다")를 구현했다. 레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료된 상태였고, `docs/GEAR_SCHEMA.md`가 반복해서 "(c) 슬롯 수/교체 루프 설계는 미착수"로 남긴 항목을 이번 사이클에서 닫았다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- TDD로 `game/self_test.lua`에 `testGearSlotSwapEconomyWiring()`을 먼저 추가했다(RED 확인: `attempt to call field 'sellValue' (a nil value)` — `game/gear.lua`에 판매가 계산 함수가 아직 없었음).
- `game/gear.lua`에 `M.raritySellValue`(common 4/uncommon 9/rare 18/legendary 40, 상점 구매가보다 충분히 낮게 설계해 판매→재구매가 손실이 있는 실질적 트레이드오프가 되도록 함)와 `M.editionSellBonus = 6`(항목12 에디션 카드에 판매가 프리미엄 부여)을 추가하고, 순수 함수 `M.sellValue(part)`가 등급+에디션 유무로 판매(환급)가를 계산한다(미지/누락 등급은 에러 대신 common 취급).
- `game/expedition.lua`의 신규 `M.sellGear(run, category, id)`가 해당 카테고리 슬롯에서 카드를 찾아 `gear.sellValue`로 금액을 계산한 뒤 `engine_parts.unequip`으로 제거하고 `run.money`에 원자적으로 credit한다(부분 적용 없음), 다른 상점 액션(`buyFuelUpgrade` 등)과 동일하게 `run.phase == "settlement"`로 제한해 비행 중 남용을 막는다.
- `loop/PROMPT.md`가 명시적으로 허용한 "gear.lua/engine_parts.lua를 게임에 배선하기 위한 최소한의 로더 호출" 예외 범위에서 `game/expedition.lua`만 수정했다(`play.lua`/`i18n.lua`/`world.lua`는 건드리지 않음).
- `game/self_test.lua`의 `testGearSlotSwapEconomyWiring()`이 다음을 회귀 검증한다: `gear.sellValue`의 등급/에디션 스케일링(누락 등급의 common 폴백 포함), 비행 중(settlement 아닌 phase) 판매 거부(금액/슬롯 리스트 불변), 정산 단계 판매 성공(정확한 금액 credit + 슬롯 제거), 엔진 슬롯 판매가 선체 슬롯 리스트에 비침범(그 역도 마찬가지, 항목10 슬롯 독립성 재확인), 미장착/존재하지 않는 id 판매 실패(금액 불변).
- `docs/GEAR_SCHEMA.md`에 "Item 9(c): slot-swap economy loop" 섹션을 신규 추가했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/gear.lua`/`game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 9 하위에 처리 상황을 append했다.
- **이로써 항목9의 (a)(b)(c)(d)가 모두 최소 구현을 갖췄다** — 레인 스코프상 실제 상점 UI의 "판매" 버튼 노출(카드별 sell 액션 시각화)은 `play.lua` 담당이라 범위 밖으로 명시.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점 행성 좌표 생성 등 순수 함수/데이터 계층에서 준비 가능한 부분) 또는 이 레인이 완료한 항목13→9→10→12→14 순서 밖의 잔여 작업 검토. 두 항목 모두 `game/world.lua`의 상점 행성 결정론적 좌표 생성이나 `play.lua`의 실제 장착/구매/판매 UI가 필요해 이 레인의 "최소 로더 호출" 예외 범위를 넘어설 가능성이 높다.

## [spaceship-gear 레인] 항목14 (C)/(E) 후속 — chainTrigger/rerollBonus/detectionRadius/autoCollect 실제 run 배선 (완료, 2026-09-03)

`docs/feedback/INBOX.md` 항목 14의 나머지 (C)/(E) 카테고리(`chainTrigger`/`rerollBonus`/`detectionRadius`/`autoCollect`)를 실제 `run` 상태에 배선했다. 레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료된 상태였고, `docs/STATUS.md`/`docs/GEAR_SCHEMA.md`가 반복해서 "여전히 미착수"로 남긴 목록 중 마지막 잔여였던 이 (C)/(E) run 배선을 이번 사이클에서 닫았다(이전에는 (D) insurance/(F) shopDiscount, (G) 추진 효과, 항목12 드롭 RNG만 배선되어 있었다). preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- TDD로 `game/self_test.lua`에 `testGearRunEffectWiring()`을 먼저 추가했다(RED 확인: `attempt to call field 'chainTriggerCount' (a nil value)` — `game/expedition.lua`에 이 네 함수의 run 래퍼가 아직 없었음).
- `game/expedition.lua`에 신규 private 헬퍼 `combinedGearList(run)`(`run.equippedGear`+`run.equippedEngineParts`를 하나의 리스트로 합침)와 이를 사용하는 4개 공개 함수를 추가했다: `M.chainTriggerCount(run)`, `M.rerollCount(run)`, `M.detectionRadius(run, baseRadius)`, `M.autoCollectEnabled(run)`. `M.effectiveClimbSpeed`(hull 전용)나 `M.boostChargeCount`(engine 전용)와 달리, (C)/(E) 효과 타입은 스키마상 카테고리 무관(hull/engine 어느 카드든 가질 수 있음)이므로 두 슬롯 모두 합산 대상으로 설계했다 — 항목10의 \"슬롯 수 독립\"은 유지하되 이 특정 효과들의 \"스탯 풀\"은 슬롯 카테고리를 가리지 않는다.
- `loop/PROMPT.md`가 명시적으로 허용한 \"gear.lua/engine_parts.lua를 게임에 배선하기 위한 최소한의 로더 호출\" 예외 범위에서 `game/expedition.lua`만 수정했다(`play.lua`/`i18n.lua`/`world.lua`는 건드리지 않음).
- `game/self_test.lua`의 `testGearRunEffectWiring()`이 다음을 회귀 검증한다: 미장착 run은 네 값 모두 문서화된 기본값(0/0/기저 반경 그대로/false)으로 해석됨, 네 효과 타입을 모두 가진 hull 카드 1장 장착 시 `chainTriggerCount`가 1.9→1로 내림, `rerollCount`가 2.4→2로 내림, `detectionRadius(run, 20)`이 정확히 30(+50%), `autoCollectEnabled`가 true, ENGINE 슬롯 카드에 `chainTrigger` 효과를 얹어도 동일하게 총합에 반영됨(카테고리 무관 설계 확인).
- `docs/GEAR_SCHEMA.md`에 \"Item 14 (C)/(E) run wiring — chainTrigger/rerollBonus/detectionRadius/autoCollect (follow-up slice)\" 섹션을 신규 추가하고, 이전 두 섹션의 \"Still deferred\" 문구를 갱신해 더 이상 미착수가 아님을 명시했다. 이로써 항목14의 (A)~(F) 전체 카테고리가 최소 1개 run 래퍼를 갖게 되었다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md`만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 14 하위에 처리 상황을 append했다.
- 여전히 미착수: 이 네 함수의 실제 게임플레이 소비 지점(`chainTriggerCount`의 재발동 이벤트, `rerollCount`의 상점 UI 무료 리롤 버튼, `detectionRadius`를 `minimap.lua`의 `viewRadius`/`checkpointSearchCellRadius`에 연결, `autoCollectEnabled`를 실제 표본 자동 흡수 로직에 연결) — 이들은 `play.lua`/`world.lua`/`minimap.lua` 영역이라 다른 레인 담당. 항목9(c)의 슬롯 교체 루프 설계, 항목10(c) 엔진 부품 획득 경로 3원화, 실제 상점/체크포인트 UI가 `M.rollGearOffer`를 호출하는 화면 자체도 여전히 미착수.
- 다음 사이클 다음 슬라이스: 레인이 지정받은 5개 항목(13/9/10/12/14)의 순수 데이터/run-배선 계층이 이제 전 카테고리에 걸쳐 1차 완료되었으므로, 사용자/통합 우선순위에 따라 (a) `play.lua` 담당 레인과 조율해 실제 장착/상점 UI를 최소 로더 호출 예외로 배선하거나, (b) 항목9(c)/10(c)의 설계 문서화 슬라이스로 전환하는 것을 권장.



`docs/feedback/INBOX.md` 항목 14의 (D)(F) 카테고리(`insurance`/`shopDiscount`)를 실제 `run` 상태에 배선했다. 항목13→9→10→12→14가 이미 1차로 모두 완료된 상태에서, 항목14 잔여 슬라이스(C~F 카테고리의 실제 run 배선) 중 (D)/(F)를 이번 사이클에서 처리했다. `loop/PROMPT.md`가 명시적으로 허용한 "gear.lua/engine_parts.lua를 게임에 배선하기 위한 최소한의 로더 호출" 예외 범위에서 `game/expedition.lua`만 수정했다(`play.lua`/`i18n.lua`/`world.lua`는 건드리지 않음). preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- TDD로 `game/self_test.lua`에 `testGearSurvivalAndEconomyWiring()`을 먼저 추가했다(RED 확인: "an equipped insurance part must prevent destruction on the first lethal hit" 단언 실패 — insurance/shopDiscount가 아직 run에 배선되지 않은 상태이므로 첫 치명타에 바로 파괴됨).
- **(D) insurance** — `game/expedition.lua`의 `M.damage(run, amount)`가 치명타로 내구도가 0이 될 때 `gear.hasInsurance(run.equippedGear)`를 확인한다. 이번 원정에서 아직 보험을 소진하지 않았다면(신규 `run.insuranceUsed`, `M.new`에서 `false`로 시작하고 `M.launch`의 재발사 분기에서도 리셋), 내구도를 1로 복구하고 전체 메타 초기화(`destroy(run)`)를 건너뛴 채 `false`(파괴 아님)를 반환한다. 같은 원정 내 두 번째 치명타는 `run.insuranceUsed == true`이므로 정상적으로 `destroy(run)`을 트리거한다 — 항목14의 "1회 한정" 요구를 정확히 구현.
- **(F) shopDiscount** — 신규 `M.shopPrice(run, basePrice)`가 `run.equippedGear`와 `run.equippedEngineParts`를 하나의 리스트로 합쳐 `gear.effectiveShopPrice(basePrice, parts)`를 호출한다. 기존 5개 상점 구매 함수(`M.buyFuelUpgrade`/`M.buyDurabilityUpgrade`/`M.buySampleYieldUpgrade`/`M.buySteeringUpgrade`/`M.buyShip`)를 모두 갱신해 원가(`*Cost`/`scoutShipCost`) 대신 `M.shopPrice`가 계산한 할인가를 기준으로 구매 가능 여부를 판단하고 그 금액만 차감하도록 했다.
- `game/data/hull_parts.json`을 24종에서 26종으로 확장했다: 신규 `hull_emergency_beacon`(uncommon, `insurance` +1, 태그 defense/control), `hull_trade_license`(uncommon, `shopDiscount` +20, 태그 economy) — 두 카드 모두 테스트/실제 게임 데이터로 함께 검증된다.
- `game/self_test.lua`의 `testGearSurvivalAndEconomyWiring()`이 다음을 회귀 검증한다: 보험 카드 장착 시 첫 치명타를 생존(돈/장착 장비/페이즈 그대로 유지, `destroy()` 미실행)하고 두 번째 치명타에는 정상 파괴(돈 0으로 초기화)됨, 보험 미장착 런은 첫 치명타에 정상 파괴(회귀 안전성 확인), 할인 카드 장착 시 `M.shopPrice`가 정확히 20% 할인가를 반환하고 실제 구매가 그 할인가로 성립함(50원 소지 중 40원 지불, 잔액 10), 할인 카드 미장착 런은 정가(50원) 전액 지불. 수정 전 RED 확인 후 구현, GREEN 전환 확인.
- `docs/GEAR_SCHEMA.md`에 "(D) insurance + (F) shopDiscount run wiring (follow-up slice)" 섹션을 추가해 계약을 문서화했다.
- `unzip -l build/game.love`로 갱신된 `game/data/hull_parts.json`과 `game/expedition.lua`가 `.love` 번들에 정상 포함됨을 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/data/hull_parts.json`/`game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md`/`docs/STATUS.md`만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 14 하위에 처리 상황을 두 번째 슬라이스로 append했다.
- 여전히 미착수: (C) `luck`/`chainTrigger`/`rerollBonus`와 (E) `detectionRadius`/`autoCollect`의 run 배선, 항목12의 실제 드롭 RNG 호출 지점(상점/체크포인트 획득 시 `gear.rollRarity`/`gear.rollEdition` 실제 연결). 다음 사이클 다음 슬라이스: 위 미착수 항목 중 하나를 선택해 진행하거나, 항목9(c)의 슬롯 교체 루프 설계/항목10(c) 엔진 부품 획득 경로 설계로 전환.

## [spaceship-gear 레인] 항목10(b) 후속 — 엔진 부품 (G) 효과 실제 run 배선(연료효율/조종반응성/부스트) (완료, 2026-09-03)

레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료되었으나, `docs/STATUS.md`/`docs/GEAR_SCHEMA.md`가 남긴 "다음 슬라이스" 후보 중 항목10(b)의 (G) 추진 특화 효과(fuelEfficiency/steeringResponsiveness/boostCharge)가 순수 함수(`game/gear.lua`)로만 존재하고 실제 `run` 상태에는 아직 배선되지 않은 상태였다. 이번 사이클은 `loop/PROMPT.md`가 명시적으로 허용한 "gear.lua/engine_parts.lua를 게임에 배선하기 위한 최소한의 로더 호출" 예외 범위 안에서 이 갭을 닫았다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean), `git status --short` clean으로 시작(이전 사이클 미완료 작업 없음).

- `game/expedition.lua`는 이미 `game.gear`/`game.engine_parts`를 최상단에서 require하고 있었다(항목9 climbSpeed 시너지 배선 때 추가됨) — 이번 사이클은 그 기존 require를 재사용해 새 함수 3개만 추가했으며 `game/scenes/play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다(변경 파일은 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md`뿐).
- 신규 `M.effectiveFuelBurnRate(run)` — `gear.effectiveFuelBurnRate(run.fuelBurnRate, run.equippedEngineParts)`를 얇게 감싼다. `M.launchForecast(run, maxFuel)`이 기존 `run.fuelBurnRate` 원값 대신 이 함수를 사용하도록 변경해, 연료 효율 엔진 부품(예: `engine_cryo_fuel_cell`, fuelEfficiency +25)을 장착하면 발사 전 예상 고도(forecast)가 실제로 상승한다.
- `M.steeringSpeed(run)`을 확장해 기존 base+업그레이드 공식 위에 `gear.effectiveSteeringRate(baseRate, run.equippedEngineParts)`를 곱연산으로 적용했다. `game/scenes/play.lua`의 조이스틱/탭 조종 코드가 이미 `expedition.steeringSpeed(run)`을 호출하고 있으므로, play.lua를 전혀 수정하지 않고도 조종 반응성 엔진 부품(예: `engine_vector_nozzle`, steeringResponsiveness +15)이 실제 조종 속도에 반영된다.
- 신규 `M.boostChargeCount(run)` — 장착된 엔진 부품의 boostCharge 효과 총합(정수, 음수 방지)을 노출한다. 실제 "부스트 사용" UI/소비 로직은 `play.lua` 영역이라 이번 사이클 범위 밖으로 명시하고, 향후 소비 로직이 참조할 단일 소스만 마련했다.
- `game/self_test.lua`에 `testGearPropulsionRunWiring()`(신규)을 추가해 3가지 모두 회귀 검증한다: `engine_cryo_fuel_cell` 장착 시 `launchForecast` 고도가 상승하고 `effectiveFuelBurnRate`가 정확히 -25%를 반영함, `engine_vector_nozzle` 장착 시 `steeringSpeed`가 정확히 +15%, 엔진 미장착 시 `boostChargeCount`가 0이고 `engine_emergency_boost_pod`(boostCharge +2) 장착 시 정확히 2, 이 모든 엔진 부품 효과가 독립된 선체(hull) 장비 목록에는 전혀 영향을 주지 않음(항목10 슬롯 독립성 재확인).
- `docs/GEAR_SCHEMA.md`의 "Propulsion specialization effect category (item 10b)" 섹션을 갱신해 이 세 함수의 실제 배선 계약과 테스트 커버리지를 문서화했다.
- `make test`(`GAME_HEADLESS=1 GAME_UNIT=1`), `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md` 처리대기 섹션의 항목10 하위에 이 진행상황을 세 번째 슬라이스로 append했다.
- 여전히 미착수: 항목10(c) 획득 경로 3원화(상점 행성 구매/체크포인트 확정 드롭/지구 상점 범용 구매), boostCharge의 실제 소비 UI(`play.lua`), 항목14 (C)~(F)/(D)/(E)/(F) 카테고리의 run 상태 소비(충돌 판정/미니맵 스캔 반경/상점 가격 등), 항목12의 실제 드롭 RNG 배선.
- 다음 사이클 다음 슬라이스: 위 미착수 항목 중 사용자/통합 우선순위에 따라 하나를 선택해 진행. 후보 우선순위: (a) 항목12의 실제 드롭 RNG 배선(체크포인트/상점 획득 시 `gear.rollRarity`/`gear.rollEdition` 실제 연결), (b) 항목10(c) 엔진 부품 획득 경로 설계, (c) 항목14 (D)/(E)/(F) 카테고리(insurance/collisionRadius/detectionRadius/autoCollect/shopDiscount)의 run 배선.

## [spaceship-gear 레인] 항목14: 효과 스키마 A~F 확장 + 웹 에디터 폼 동기화 (완료, 2026-09-03)

`loop/PROMPT.md`의 gear 레인 순서(항목13 -> 항목9 -> 항목10 -> 항목12 -> 항목14)에 따라 항목12(등급/에디션 파밍) 완료 후 항목14(효과 스키마 A~F 확장)를 착수했다 — 이 레인이 지정받은 5개 항목의 마지막이다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean)로 시작했고, `git status --short`는 clean이라 이전 사이클 미완료 작업은 없었다.

- TDD로 `game/self_test.lua`에 `testGearEffectSchemaExpansion()`을 먼저 추가했다(RED 확인: `attempt to index a nil value (field 'effectCategories')`).
- `game/gear.lua`의 `M.knownEffectTypes`를 기존 5종(A: speed/sampleSellValue/money/climbSpeed/hullDurability)에서 15종으로 확장했다: **(B)** sellMultiplier/streakMultiplier, **(C)** luck/chainTrigger/rerollBonus, **(D)** insurance/collisionRadius, **(E)** detectionRadius/autoCollect, **(F)** shopDiscount. 각 타입의 스키마 카테고리를 표시하는 `M.effectCategories` 메타데이터 테이블도 함께 추가했다.
- **(B) 배율형 — 시너지 핵심**: `M.equippedTotals`를 확장해, 항목9의 climbSpeed 태그 시너지 배율 적용 이후 sellMultiplier(퍼센트 형태, 예: `25` = "+25%")를 모든 장착 부품에서 먼저 가산 합산한 뒤, 그 결합된 퍼센트를 `sampleSellValue` 가산 총합에 곱연산 1회로만 적용하도록 했다. 두 장의 +25% 카드는 정확히 +50%가 되고(가산 스택), 복리 +56.25%로 계산되지 않는다 — 항목14가 요구한 "가산 총합 × 배율 총합" 순서를 정확히 구현했다. `streakMultiplier`는 스키마 타입으로 등록·검증만 하고, 실제 "동일 계열 연속 채집" 배율 소비 로직 자체는 `game/expedition.lua` 소관이라 이번 사이클 범위 밖으로 명시했다(레인 스코프상 최소 로더 호출 예외 외의 expedition.lua 수정은 금지).
- **(C) 트리거/확률**: `M.chainTriggerCount(parts)`/`M.rerollCount(parts)`(효과 총합을 0 이상 정수로 내림). `M.totalLuckBonus(parts)`는 luck 효과 총합을 100으로 나눠, 항목12에서 이미 구현된 `gear.rollRarity(roll, luckBonus)`/`gear.rollEdition(part, chanceRoll, pickRoll, luckBonus)`가 곧바로 받을 수 있는 소수 `luckBonus` 형태로 변환한다 — 장착 부품의 luck 효과가 실제 등급/에디션 확률 롤과 연결되는 지점을 이번 사이클에서 마련했다(호출은 여전히 상점/드롭 코드, 이 레인 스코프 밖).
- **(D) 생존/리스크**: `M.hasInsurance(parts)`(1회성 불리언 게이트 — 여러 장 장착해도 생명 중첩 없음, 항목12의 "1회 한정" 취지 반영), `M.effectiveCollisionRadius(baseRadius, parts)`(퍼센트 축소, 0 클램프).
- **(E) 탐사/정보**: `M.effectiveDetectionRadius(baseRadius, parts)`(퍼센트 확대), `M.autoCollectEnabled(parts)`(불리언 게이트, hasInsurance와 동일 형태).
- **(F) 경제**: `M.effectiveShopPrice(basePrice, parts)`(퍼센트 할인, 0 클램프 — 카드 스택으로 무료는 가능해도 음수 가격은 되지 않음).
- `tools/gear-editor/editor.js`에 `EFFECT_TYPE_GROUPS`(카테고리별 A~F 라벨 그룹 테이블)를 신규 추가하고, 기존 `KNOWN_EFFECT_TYPES`를 `Object.values(EFFECT_TYPE_GROUPS).flat()`로 파생시켜 두 목록이 구조적으로 어긋날 수 없게 했다. 카드 폼의 효과 타입 드롭다운(`addEffectRow`)이 `<optgroup>`으로 A~F를 그룹화해 렌더링하도록 갱신해, ~15종으로 늘어난 효과 타입도 폼에서 탐색 가능하게 했다(항목14 "웹 에디터의 효과 입력 폼에도 이 전체 카테고리를 드롭다운/그룹으로 선택할 수 있도록" 요구사항).
- `docs/GEAR_SCHEMA.md`에 "Effect schema categories A~F (item 14)" 섹션을 신규 추가해 각 카테고리의 계산 규칙, 배율 적용 순서(가산-후-곱연산), 클램프 동작을 문서화했고, "Known effect types" 섹션을 15종 전체를 나열하도록 갱신했다.
- `game/self_test.lua`의 `testGearEffectSchemaExpansion()`이 GREEN으로 전환됨을 확인했다: 15종 전체 등록/카테고리 배정 확인, (B) 가산-후-곱연산 순서(2장 +25%→+50%, sellMultiplier 미장착 시 순가산 유지 회귀), (C)(D)(E)(F) 각 변환 함수의 정상 값과 클램프 경계(collisionRadius/shopDiscount 500% 입력 시 0으로 클램프) 동작을 검증하고, `love.filesystem.read`로 `editor.js` 소스 텍스트를 직접 읽어 `gear.knownEffectTypes`의 모든 항목이 `EFFECT_TYPE_GROUPS` 안에 문자열 리터럴로 존재하는지도 검증한다(RED 두 번 확인: 처음엔 `editor.js`가 구식 5종만 가져 `KNOWN_EFFECT_TYPES` 매칭 실패, `EFFECT_TYPE_GROUPS`로 리팩터 후 재확인해 최종 GREEN).
- `make test`(`GAME_HEADLESS=1 GAME_UNIT=1`), `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- **아직 (C)~(F) 계산 함수들은 `run` 상태(항목7의 드롭 RNG/충돌 판정/미니맵 스캔 반경/상점 가격 등)에 배선되지 않았다** — 레인 스코프상 `game/scenes/play.lua`/`game/world.lua`/`game/expedition.lua`는 원칙적으로 다른 레인 담당이며, 이번 슬라이스는 순수 데이터/효과 계산 계층만 완성했다.
- `docs/feedback/INBOX.md` 처리대기 섹션의 항목14 하위에 이 진행상황을 append했다.
- **레인 스코프가 지정한 5개 항목(13→9→10→12→14) 순서를 이번 사이클로 전부 1차 완료했다.** 다음 슬라이스는 사용자/통합 우선순위에 따라 (a) 각 항목의 "다음 슬라이스"로 명시된 잔여 작업(항목9의 슬롯 교체 루프 설계, 항목10의 엔진 전용 효과 차별화/획득 경로 3원화, 항목12의 실제 드롭 RNG 배선) 또는 (b) 게임 배선(최소 로더 호출 예외 범위 내에서 `run.equippedGear`/`run.equippedEngineParts` 실제 장착 UI) 중 선택.





## [spaceship-gear 레인] 항목12: 등급(rarity) 드롭 가중치 + 에디션 파밍 시스템 1차 구현 (완료, 2026-09-03)

`loop/PROMPT.md`의 gear 레인 순서(항목13 -> 항목9 -> 항목10 -> 항목12 -> 항목14)에 따라 항목10(엔진 부품 슬롯 분리) 완료 후 항목12(등급/에디션 파밍 시스템)를 착수했다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean)로 시작했고, `git status --short`에는 워크트리 설정 파일(`loop/PROMPT.md` 수정, `loop/com.jm.spaceship.gear-lane.plist` 신규)만 있어 이전 사이클 미완료 작업은 없었다.

- TDD로 `game/self_test.lua`에 `testGearRarityAndEditionSystem()`을 먼저 추가했다(RED 확인: `attempt to call a nil value (field 'rollRarity')`).
- `game/gear.lua`에 `M.knownEditions = { irradiated, crystallized, quantum_flawed, refined }` 화이트리스트를 추가하고, `validatePart`가 카드의 `editions` 배열 각 항목을 이 목록과 대조해 미지의 edition id를 다른 필드 검증(중복 id/범위 밖 수치/미지 effect type/rarity)과 동일하게 즉시 거부하도록 확장했다.
- **(A) 등급 드롭 가중치**: `M.rarityDropWeights`(common 60/uncommon 25/rare 12/legendary 3, 상대 가중치 — "레어일수록 희귀")와 `M.rollRarity(roll, luckBonus)`를 추가했다. 순수 함수로 명시적 `roll`(`[0,1)`)을 받아 `love.math.random`에 직접 의존하지 않으므로 결정적으로 유닛 테스트 가능하며, 실제 RNG 소스는 상점/드롭 코드(이 레인 스코프 밖)가 결정한다. `luckBonus`(항목14 luck 효과 대상 #2: "희귀 등급 드롭 가중치를 상위 등급 쪽으로 상향")는 rare/legendary 가중치를 올리고 common/uncommon을 낮춰, 동일 `roll`에서 luck이 높을수록 등급이 낮아지는 일이 없도록 설계했다.
- **(B) 에디션 부여**: `M.baseEditionChance = 0.08`(항목12 "낮은 확률, 예: 5~10%")과 `M.rollEdition(part, chanceRoll, pickRoll, luckBonus)`를 추가했다. 카드 자신의 `editions` 목록에서만 선택하며(빈 목록이면 항상 `nil`), `luckBonus`(항목14 luck 대상 #1: "에디션 부여 확률 상향")가 확률을 가산 상향한다.
- `M.editionEffects` 테이블로 4종 에디션의 실제 수치 변환을 정의했다(스페이스쉽 세계관 — 우주 방사선·희귀 합금·양자 결함): `irradiated`(⚠️ 방사능처리, 수치 불변 + 시너지 보너스 +0.05 via `M.editionSynergyBonusAdd`), `crystallized`(✨ 결정화, sampleSellValue만 x2), `quantum_flawed`(🌀 양자결함, 전체 효과 x2 + hullDurability -1 부작용 추가), `refined`(💠 정제, 전체 효과 x0.5, 추후 "슬롯 비점유" 컨셉을 위한 `noSlotCost` 메타데이터 예약). `M.applyEditionEffects(part, editionId)`는 원본 `part.effects`를 변형하지 않고 새 배열을 반환하며, 미지 edition id는 에러를 던진다.
- `docs/GEAR_SCHEMA.md`에 "Rarity + edition farming system (item 12)" 섹션을 추가해 이 모든 계약을 문서화했다.
- `tools/gear-editor/editor.js`에 `KNOWN_EDITIONS`(Lua의 `M.knownEditions`와 동일 목록)를 추가해 클라이언트 측 검증도 미지 edition을 동일하게 거부하도록 동기화했고, `index.html`의 Editions 입력 필드에 알려진 4종을 안내 문구로 노출했다.
- `game/data/hull_parts.json`(hull_reactive_hull, hull_quantum_alloy)과 `game/data/engine_parts.json`(engine_fusion_core, engine_singularity_drive) 각 2장씩에 실제 `editions` 배열을 채워, 로더/테스트가 합성 픽스처가 아닌 번들된 실 데이터로 최소 1건씩 검증되도록 했다.
- `game/self_test.lua`의 `testGearRarityAndEditionSystem()`이 GREEN으로 전환됨을 확인했다: 등급 가중치 순서(roll=0→common, roll≈1→legendary)/luck 단조성(동일 roll에서 luck이 등급을 낮추지 않음), 카드별 후보 목록 제한(빈 editions는 항상 nil), base/luck 부여 확률 임계값, 각 에디션의 효과 변환(crystallized 배가/quantum_flawed 배가+부작용/applyEditionEffects 원본 비변형), 미지 edition 에러 경로를 모두 검증한다.
- `make test`(`GAME_HEADLESS=1 GAME_UNIT=1`), `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- **아직 실제 드롭/상점 로직(항목7의 획득 경로)이나 UI 카드 테두리/반짝임 이펙트에는 배선하지 않았다** — 레인 스코프상 `game/scenes/play.lua`/`game/world.lua`/`game/expedition.lua`는 원칙적으로 다른 레인 담당이며, 이번 슬라이스는 순수 데이터/확률 계산 계층만 완성했다.
- `docs/feedback/INBOX.md` 처리대기 섹션의 항목12 하위에 이 진행상황을 append했다.
- 다음 슬라이스: 항목14(효과 스키마 A~F 확장 — 배율/트리거/생존/탐사/경제 카테고리 — + `tools/gear-editor/editor.js`의 `KNOWN_EFFECT_TYPES` 폼 동기화, 이번 사이클의 `KNOWN_EDITIONS` 동기화 패턴을 그대로 재사용 가능).



## [spaceship-gear 레인] 항목9: 선체 부품 풀 24종으로 확장 + 태그 시너지 엔진 1차 구현 (완료, 2026-09-03)

`loop/PROMPT.md`의 gear 레인 순서(항목13 -> 항목9 -> 항목10 -> 항목12 -> 항목14)에 따라 항목13(부품 데이터 외부화 + 웹 에디터) 완료 후 항목9(선체 부품 20~30종 + 시너지 엔진)를 착수했다. preflight READY(엔진 테스트/패키지 PASS, `git diff` clean)로 시작했고, `git status --short`에는 이 워크트리 설정 파일(`loop/PROMPT.md`의 레인 스코프 헤더, `loop/com.jm.spaceship.gear-lane.plist`)만 있어 이전 사이클 미완료 작업은 없었다.

- TDD로 `game/self_test.lua`에 `testGearSynergyEngine()`을 먼저 추가했다(RED 확인: `hull part pool must have at least 20 cards ... got 6`).
- `game/data/hull_parts.json`을 6종에서 24종으로 확장했다. 신규 카드는 모두 최소 1개의 시너지 태그를 갖도록 했고, `world.hueFamilies`(azure/ember/void)에 대응하는 전용 태그를 포함해 `speed`/`altitude`/`defense`/`economy`/`control` 등 기존 태그와 겹치는 조합을 다양하게 만들었다(등급도 common~legendary까지 분포).
- `game/gear.lua`에 순수 함수 태그 시너지 엔진을 추가했다: `M.aggregateEffects(parts)`(효과 타입별 순수 가산 합), `M.tagSynergyMultiplier(parts)`(태그를 공유하는 장착 부품 쌍마다 `M.synergyBonusPerSharedPair`(0.15)씩 배율 가산, 공유 쌍이 없으면 정확히 1), `M.equippedTotals(parts)`(가산 합산 후 `climbSpeed`에만 시너지 배율을 곱해 적용 — 발라트로처럼 조합이 배가 효과를 내는 항목9의 핵심 요구를 만족시키며, `money`/`sampleSellValue`/`speed`/`hullDurability`는 이번 사이클엔 순가산으로 유지). `synergyMultiplier` 필드도 함께 반환해 향후 UI/테스트가 현재 콤보 강도를 직접 표시할 수 있게 했다.
- `docs/GEAR_SCHEMA.md`에 "Tag-based synergy engine (item 9)" 섹션을 추가해 세 함수의 계약과 확장된 24종 카드 풀 구성을 문서화했다.
- `game/self_test.lua`의 `testGearSynergyEngine()`이 GREEN으로 전환됨을 확인했다: 풀 크기(>=20), 모든 카드가 태그를 가짐, 순가산 vs 시너지곱 차이(태그 공유 시 climbSpeed 합보다 커야 함, 태그 불일치 시 배율 정확히 1), `sampleSellValue` 등 다른 타입은 순가산 유지.
- `make test`(`GAME_HEADLESS=1 GAME_UNIT=1`), `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:54`, `ASSET_MANIFEST_OK`, 자산 매니페스트/번들 검증 포함).
- **아직 게임 배선(런타임 장착 UI, `run.equippedGear`)에는 연결하지 않았다** — 레인 스코프상 `game/scenes/play.lua`/`game/world.lua`/`game/expedition.lua`는 원칙적으로 다른 레인 담당이며, 이번 슬라이스는 순수 데이터/엔진 계층만 완성했다. 실제 게임 내 장착 UI 배선은 로더 호출 최소 예외 범위에서 다음 사이클이 필요시 진행하거나, play.lua 담당 레인과 조율한다.
- `docs/feedback/INBOX.md` 처리대기 섹션의 항목9 하위에 이 진행상황을 append했다.
- 다음 슬라이스: 항목10(엔진 부품 슬롯 분리, `game/engine_parts.lua` 신규 — 선체 슬롯과 독립된 `run.equippedEngineParts` 목록 설계).



`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 "남은 작업" 부분(탭하여 발사/선체 내구도/자금/속도를 아이콘+짧은 수치로 재구성)을 첫 슬라이스로 착수했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작했다.

- `game/scenes/play.lua`에 순수 함수 `M.rocketIconPoints(cx, cy, size)`(love.graphics 호출 없음, 위쪽을 향한 삼각형+양쪽 핀 실루엣의 flat `{x1,y1,x2,y2,...}` 폴리곤 점 목록 반환)와 신규 상수 `M.launchIconSize = 14`, `M.launchIconGap = 12`를 추가했다.
- `M:draw()`의 메시지 렌더 구간이 `phase == "launch"`일 때만 `love.graphics.polygon("fill", M.rocketIconPoints(...))`으로 이 로켓 아이콘을 "탭하여 발사" 텍스트 바로 위(간격 12px)에 주황색으로 그리도록 분기했다. 다른 페이즈(정산/파괴 등)는 영향 없음.
- 이 로켓 실루엣은 도형 기반 `DEV PLACEHOLDER` 게임플레이 지오메트리이며 최종 에셋이 아니다(AetherAI-only 정책 위반 아님).
- `game/self_test.lua`에 `testLaunchRocketIcon()` 회귀 테스트를 추가했다 — 폴리곤 점 개수가 짝수/최소 3정점, 로켓이 중심 y 위아래로 걸쳐 있음(높이 0 아님), 첫 정점(노즈 끝)이 최상단이며 `cx`에 수평 중심 정렬되어 있음을 검증한다. `M.run()`에 `testLaunchRocketIcon()` 호출을 등록했다.
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1440×2560, ko 로케일, `build/spaceship-runtime-preview-launch-rocket-icon.png`)를 vision으로 확인해, 주황색 삼각형 로켓 아이콘이 "탭하여 발사" 텍스트 바로 위에 겹침·잘림 없이 깔끔하게 렌더링됨을 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 3번 항목에 이번 슬라이스(TAP TO LAUNCH 로켓 아이콘) 완료를 기록했다. 남은 작업: 선체 내구도/자금($)/속도(엔진·조종속도)의 아이콘화는 아직 착수 전.
- 다음 사이클 다음 슬라이스: 3번 항목의 나머지(선체 내구도/자금/속도 아이콘화)를 계속하거나, 6번(표본 도감 정리 + 슬롯 6개 장비 카드 UI 전환)으로 진행.

## "발사 장비"(LAUNCH LOADOUT) 패널 타이틀 제거 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 4번(불필요한 텍스트 제거 검토)의 마지막 남은 슬라이스("발사 장비" 패널 타이틀 자체 검토)를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short`는 clean이었으므로 새 슬라이스를 착수했다.

- `game/scenes/play.lua`에 신규 `M.showLaunchLoadoutTitle = false` 플래그를 추가했다. LAUNCH LOADOUT 카드의 내용물(선체/업그레이드/예보/조종속도/오즈 수치)이 뚜렷하게 테두리 쳐진 박스 안에 표본 도감 스트립 바로 아래 위치해 캡션 없이도 문맥상 자명하다고 판단해, 캡션 텍스트를 완전히 삭제하지 않고 플래그로 게이트해 향후 사이클이 실기기 피드백에 따라 손쉽게 되돌릴 수 있게 했다.
- `M:draw()`의 LAUNCH LOADOUT 카드 렌더 구간이 `M.showLaunchLoadoutTitle`이 참일 때만 `i18n.t("launch_loadout_title")` printf와 그에 따른 `rowStep` 세로 간격 소비를 수행하도록 분기했다(거짓이면 선체 줄이 카드 상단 바로 아래에서 시작).
- `game/self_test.lua`에 `PlayScene.showLaunchLoadoutTitle == false` 회귀 테스트를 추가했다(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920, ko 로케일, `build/spaceship-runtime-preview-title-removed.png`)를 vision으로 확인해, 카드가 "발사 장비" 캡션 없이 표본 도감 스트립 바로 아래에서 곧바로 "선체 3"으로 시작하고 빈 줄도 남지 않음을 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 4번 항목을 "사실상 전량 완료"로 갱신했다(하위 5개 세부 텍스트 정리 항목 모두 완료).
- 다음 사이클 다음 슬라이스: 3번 항목(연료 무제한 아이콘 기반 HUD 간소화, "탭하여 발사"/선체 내구도/자금/속도를 아이콘+짧은 수치로 재구성) 또는 6번(표본 도감 정리 + 슬롯 6개를 함선 장비 카드 UI로 전환)으로 진행.

## 무의미한 "SHIP STARTER" 함선명 라인을 STARTER만 소유 중일 때는 숨김 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 4번(불필요한 텍스트 제거 검토)의 남은 슬라이스 중 하나("STARTER" 함선명 제거)를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short`에는 전 사이클이 남긴 미커밋 diff(`game/scenes/play.lua`, `game/self_test.lua`)가 있었으므로 그 작업을 이어받아 완성하고 검증했다(새로 시작하지 않음).

- `game/scenes/play.lua`의 `M:loadoutLines()`가 반환하던 `ship = i18n.t("loadout_ship", ...)`("SHIP STARTER")는 기본 STARTER 선체 하나만 존재하는 지금 항상 표시되는 죽은 텍스트였다(선택지가 없어 "선택됨"을 알리는 정보 가치가 없음). `run.ownedShips.scout`가 참일 때만(즉 두 번째 선박을 실제로 보유해 "어떤 선박이 선택되었는지"가 진짜 정보가 될 때만) `ship` 필드를 채우고, 그 외에는 `nil`로 반환하도록 변경했다.
- `M:draw()`의 LAUNCH LOADOUT 카드 렌더 구간이 `loadout.ship`이 `nil`이면 그 줄과 `rowStep` 간격을 아예 건너뛰도록(`if loadout.ship then ... end`) 수정해, 파괴 후 화면에 빈 줄이 남지 않는다.
- 파괴 화면의 "NEXT %s" 줄(`next_ship_line`)은 STARTER뿐이어도 항상 다음 원정의 함선명을 알려줘야 하므로, 이 용도로만 쓰이는 신규 `shipLabel = string.upper(run.selectedShipId)` 필드를 항상 채워 반환하고 `draw()`가 `loadout.ship` 대신 `loadout.shipLabel`을 사용하도록 분리했다.
- `game/self_test.lua`의 두 회귀 지점(초기 STARTER-only 상태, 메타 초기화 후 STARTER-only로 되돌아간 상태)에서 `starterLoadout.ship == "SHIP STARTER"`였던 기존 단언을 `== nil`로 갱신하고 이유를 주석으로 남겼다.
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1`, 기본 launch phase, 1080x1920, ko 로케일)를 vision으로 확인해, "발사 장비" 타이틀 바로 아래에 "SHIP STARTER"/"선박 스타터" 줄 없이 곧바로 "선체 3"이 나오는 것을 확인했다(카드에 빈 줄도 남지 않음).
- 상점 화면(`M:shopLoadoutLines()`/`draw()`의 shop 렌더 구간)은 함선명 텍스트를 별도로 그리지 않으므로 영향 없음을 코드로 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 4번 항목에 이번 슬라이스(STARTER 함선명 라인 제거) 완료를 기록했다. 남은 항목: "발사 장비" 패널 타이틀 자체 검토, "개발 임시본" 축소는 이미 이전 사이클(e856611)에서 완료.
- 다음 사이클 다음 슬라이스: 4번 항목의 남은 부분("발사 장비" 패널 타이틀 자체를 제거/대체할지 검토), 또는 3번 항목의 아이콘 기반 HUD 재구성, 또는 6번(표본 도감 정리 + 슬롯 6개를 함선 장비 카드 UI로 전환)으로 진행.

## "평균 $"/"AVG $" 슬롯 기대값 라벨을 "기대값 $"/"EV $"로 교체 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 4번(불필요한 텍스트 제거 검토)의 다음 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작.

- `slot_odds_line`(en `"C%d P%d S%d  AVG $%.2f"`, ko `"C%d P%d S%d  평균 $%.2f"`)의 마지막 세그먼트 라벨이 슬롯머신 기대값(expected value)을 뜻하는데, "AVG"/"평균"은 통계적으로 부정확하지 않지만 INBOX 4번 항목이 명시적으로 정리 대상으로 지목했다. `game/i18n.lua`의 en/ko 두 로케일 모두 `"AVG $%.2f"` → `"EV $%.2f"`, `"평균 $%.2f"` → `"기대값 $%.2f"`로 교체했다(포맷 인자 개수/순서는 그대로라 `game/scenes/play.lua`의 `slotOddsLine()`/`loadoutLines()`/`shopLoadoutLines()` 호출부는 변경 불필요).
- `game/self_test.lua`의 하드코딩된 `"C50 P40 S10  AVG $18.58"` 회귀 테스트 3곳(`slotOddsLine()`, launch loadout `odds`, shop loadout `odds`)을 전부 `"C50 P40 S10  EV $18.58"`로 갱신했다(수정 전 RED `assertion failed! game/self_test.lua:1704` 확인 후 GREEN 전환 확인).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=returning-odds`, 1440×2560, ko 로케일)를 vision으로 확인해 미니맵 위 "C50 P40 S10 기대값 $18.58" 줄이 바로 위 "귀환 0% 12초" 줄과 겹치지 않고 정상 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 4번 항목에 이번 슬라이스 진행 상황("평균 $"/"AVG $" → "기대값 $"/"EV $" 교체 완료)을 기록했다. 남은 항목: "STARTER" 함선명 제거, "발사 장비" 패널 타이틀 검토, "개발 임시본" 축소.
- 다음 사이클 다음 슬라이스: 4번 항목의 남은 부분(함선 이름 "STARTER" 제거, "발사 장비" 패널 타이틀 검토, "개발 임시본" 축소) 중 하나를 이어서 처리하거나, 3번 항목의 아이콘 기반 HUD 재구성, 또는 6번(표본 도감 정리 + 슬롯 6개를 함선 장비 카드 UI로 전환)으로 진행.

## "무피격 N" 예보 라벨을 명확한 "REACH/도달예상"으로 교체 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 4번(불필요한 텍스트 제거 검토)의 다음 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작.

- LAUNCH LOADOUT/EARTH SHOP의 `forecast_line`(en `"NO-HIT %d  SLOTS %d"`, ko `"무피격 %d  슬롯 %d"`)은 실제로는 "현재 최대 연료로 충돌 없이 도달 예상되는 고도와 그 귀환 거리의 슬롯 기회"를 뜻하는데, 라벨 "무피격"/"NO-HIT"은 뜻이 불명확해 사용자가 혼동하기 쉬웠다(INBOX 4번 항목에서 명시적으로 지적).
- `game/i18n.lua`의 en/ko 두 로케일 모두 `forecast_line`을 `"NO-HIT %d  SLOTS %d"` → `"REACH %d  SLOTS %d"`, `"무피격 %d  슬롯 %d"` → `"도달예상 %d  슬롯 %d"`로 교체해 "도달 예상 고도"라는 실제 의미를 그대로 드러내는 라벨로 바꿨다(포맷 인자 개수/순서는 그대로라 `game/scenes/play.lua`의 `launchForecastLine`/`M:loadoutLines()`/`M:shopLoadoutLines()` 호출부는 변경이 필요 없었다).
- `game/self_test.lua`의 하드코딩된 `"NO-HIT N  SLOTS N"` 회귀 테스트 24곳을 전부 `"REACH N  SLOTS N"`으로 갱신했다(수정 전 RED `assertion failed! game/self_test.lua:1386` 확인 후 GREEN 전환 확인).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920, ko 로케일)를 vision으로 확인해 LAUNCH LOADOUT 카드에 "무피격 600  슬롯 6" 대신 "도달예상 600  슬롯 6"이 정상 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 4번 항목에 이번 슬라이스 진행 상황(`"무피격 N"` → `"REACH N"`/`"도달예상 N"` 교체 완료)을 기록했다. 남은 항목: "STARTER" 함선명 제거, "발사 장비" 패널 타이틀 검토, "평균 $" 표기 정리, "개발 임시본" 축소.
- 다음 사이클 다음 슬라이스: 4번 항목의 남은 부분(함선 이름 "STARTER" 제거, "발사 장비" 패널 타이틀 검토, "평균 $" 정리, "개발 임시본" 축소) 중 하나를 이어서 처리하거나, 3번 항목의 아이콘 기반 HUD 재구성, 또는 6번(표본 도감 정리 + 슬롯 6개를 함선 장비 카드 UI로 전환)으로 진행.

## 이번 사이클 조사 결과: 코드 변경 없음 (2026-09-02)

이번 사이클은 `docs/feedback/INBOX.md` 처리 대기 4개 항목과 `docs/GAME_DESIGN.md`의 "첫 플레이 가능한 목표" 체크리스트를 `game/expedition.lua`, `game/scenes/play.lua`, `game/world.lua`, `game/self_test.lua`, `main.lua`를 대조해 전수 조사했다.

- **세로 상승형 로그라이트 핵심 루프**: `launch → ascending → returning/slots → settlement/shop → relaunch` 전체가 이미 구현·테스트됨(`game/expedition.lua`의 `launch/update/useSlot/damage`, destroy 시 미정산 표본·돈·구매 우주선·강화 전체 초기화 및 `bestAltitude`만 보존, `game/self_test.lua` 630-684행 통합 시나리오). `docs/GAME_DESIGN.md`의 "첫 플레이 가능한 목표" 8개 항목 모두 코드·테스트·실제 LÖVE 캡처로 대응된다.
- **AetherAI-only 최종 에셋**: 로그인/공식 export 자격 증명이 이 세션에 없어(`loop/PROMPT.md` "Do not access credentials") 진행 불가. 여전히 human-gated.
- **행성·이펙트 발라트로 스타일**: 6개 후속 확정 사항(시너지/스트릭, 숫자 롤업, 스코어 비례 쉐이크, 도감, 트레이드오프 GAINS/LOSSES, 접근 기대감 스파클) 모두 코드에 존재하고 커밋 이력에 반영됨. `game/scenes/play.lua` 1200-1250행에는 외곽 글로우 링, 소프트 드롭섀도우, 채도 높은 그라디언트 채움, 등급별 트윙클까지 이미 그려진다.
- **런치 화면 지구 탐험물 전시**: 완료 표시됨, 코드(`drawSpecimenStrip`)와 일치.
- 조사 중 새로운 실패나 회귀는 발견하지 못했다(`make test` GREEN, 조사 시점 기준). 위 네 항목 모두 이번 사이클 시점 코드베이스와 일치해 사용자 검수만 남은 상태로 보인다. 이 사이클은 회귀를 만들 위험이 있는 대규모 변경(완전 자유 2D로의 전환은 `PROMPT.md`의 "Earth is below and progression is upward" 비타협 규칙 및 다수 기존 통합 테스트와 충돌 가능)을 피하고 코드 변경 없이 종료한다.
- 다음 사이클 권장: 사용자에게 위 4개 항목의 최종 검수/완료 확인을 요청하거나, AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export를 진행한다. 완전 자유 2D 전환을 원하면 별도 feedback 항목으로 명확히 재확인 후 진행 필요.

## 이번 사이클 재검증 결과: 코드 변경 없음 (2026-09-02, 두 번째 조사)

`git status --short`가 clean, preflight PASS 상태로 시작해 4개 `처리 대기` 항목을 코드·테스트 레벨에서 직접 재확인했다(이전 사이클의 조사 결과를 신뢰하지 않고 독립적으로 재검증).

- **핵심 루프**: `game/expedition.lua`의 `destroy()`(191-229행)가 `money`/`ownedShips`/`selectedShipId`/모든 upgrade level을 0·기본값으로 리셋하고 `bestAltitude`만 보존하는 것, `M.burnManeuverFuel`이 `run.phase ~= "ascending"`이면 즉시 no-op(귀환 중 회피 기동은 연료 소모 없음)인 것, `game/self_test.lua` 603-717행 통합 시나리오(파괴 시 전체 wipe + best 보존, 슬롯 스핀 → 정산 → 재출발 흐름)가 GREEN인 것을 라인 단위로 재확인했다.
- **AetherAI-only**: `loop/env.sh`·현재 쉘 환경변수에 `aether` 관련 자격 증명이 없음을 재확인(`grep -i aether` 결과 없음). 여전히 human-gated, 진행 불가.
- **발라트로 스타일**: `game/scenes/play.lua`의 `sampleTierEffect`(148-157행, tier별 particleCount/glowRings/glowAlpha), `sampleTierSparkle`(163-172행, tier별 반짝임 속도/진폭), `sampleTierShakeMultiplier`(219-228행), `rollupAmount`(254-259행), `shipPunchDuration`/`M:spawnSampleParticles`(361-383행, pickup 시 파티클+스케일 펀치), `sparkleAnticipationMultiplier`(197-204행, 접근 가속 트윙클)까지 6개 후속 확정 사항 전부가 코드에 존재하고 draw 경로(1204-1211행 글로우 링)에 실제로 연결되어 있음을 확인했다. `planet-style-editor` 웹 도구 자체는 이 저장소 밖의 별도 도구로, 수치/파라미터만 이식 대상이며 여기 이미 반영되어 있다.
- **런치 화면 지구 탐험물 전시**: `world.specimenCatalog`/`game/collection_store.lua`/`drawSpecimenStrip` 존재 확인, `game/i18n.lua`의 `en`/`ko` 로케일 키 집합이 정확히 99개로 1:1 일치(`python3`로 두 테이블 키를 diff, 누락/잉여 없음)함을 확인해 신규 문자열 회귀도 없다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`). `git status --short` 결과 없음(코드 변경 없음).
- 다음 사이클도 동일하게: (1) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행, (2) 그 전까지는 사용자에게 4개 항목의 최종 검수 확인을 요청하거나, 새로운 feedback이 등록되면 그것을 우선 처리한다. 회귀 위험을 감수한 임의 변경(완전 자유 2D 전환 등)은 사용자 재확인 없이는 시작하지 않는다.

## 런치 화면 텍스트 크기·레이아웃 정리: 지구본 초승달 잔여 결함 수정 (완료, 2026-09-02)

이 사이클 시작 시 `git status --short`에 이전 사이클이 작업 중이던 미커밋 변경(`game/scenes/play.lua`, `game/self_test.lua`, `docs/feedback/INBOX.md`)이 있어 그대로 이어받아 완료했다.

- `docs/feedback/INBOX.md`의 "런치(첫)화면 텍스트 크기·레이아웃 정리" 처리 대기 항목: 이전 사이클에서 이미 HUD를 32px 밴드로, LAUNCH LOADOUT 카드를 6줄 8px 소형 폰트·10px rowStep으로 축소했으나, 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920)로 재검증한 결과 카드 박스 상단(y=204)이 지구본 최상단(중심 y=260, 반지름 58 → y=202)보다 2px 낮아 옅은 파란 초승달이 카드 상단 바로 위에 비치는 잔여 결함이 남아있었다.
- `game/scenes/play.lua`의 `M.launchLoadoutBoxTop`을 204 → 202로 수정해 박스 상단이 지구본 최상단을 완전히 덮도록 했다.
- `game/self_test.lua`에 박스 상단이 지구본 최상단 이하(더 작거나 같음)임을 검증하는 회귀 테스트를 추가했다(런치 페이즈 함선이 world origin에 있을 때의 `earthTopY` 계산 기반). 수정 전 RED(박스 상단 204 > earthTopY) → 수정 후 GREEN 확인.
- 수정 후 실제 LÖVE 런타임 캡처(`build/spaceship-runtime-preview-launch-verify-after.png`, gitignored 빌드 아티팩트, 1080×1920)를 vision으로 확인: 초승달 잔여 결함이 사라졌고, HUD/LOADOUT 카드 텍스트가 미니맵·표본 스트립과 겹치지 않으며 크기도 적절함을 확인했다.
- `docs/feedback/INBOX.md`에서 해당 항목을 "처리 대기" → "처리 완료"로 이동(내용은 이전 사이클이 이미 작성한 것을 유지).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- 다음 사이클 다음 슬라이스: 처리 대기 4개 항목(핵심 루프/AetherAI-only/발라트로 스타일/런치 화면 지구 탐험물 전시) 모두 코드·테스트 레벨에서 이미 구현·검증된 상태로 사용자 최종 검수만 남아 있다. AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export를 진행하고, 그 전까지는 새로운 feedback 항목이 등록되는 대로 우선 처리한다.

## INBOX.md 문서 정리: AetherAI-only 항목 처리 완료 섹션 이동 (완료, 2026-09-02)

이번 사이클 preflight는 READY(`make test` PASS, `git diff` clean)였고, `git status --short`도 clean으로 시작했다. `docs/feedback/INBOX.md`의 처리 대기 4개 항목을 코드베이스와 대조 재확인한 결과 모두 이전 사이클들에서 이미 코드·테스트·실기기 캡처로 완료 검증되어 있었으나, 문서 구조에 잔여 결함이 있었다.

- `docs/feedback/INBOX.md`의 "## 처리 대기" 섹션 바로 아래 "## AetherForgeAI/AetherAI-only 최종 에셋 (완료)" 항목과 그 요약 불릿("처리 완료된 항목들...")이 `##` 헤딩 레벨 실수로 "처리 완료" 섹션이 아니라 "처리 대기" 섹션 안에 잘못 위치해 있었다(내용 자체는 이미 "완료" 표시였으나 섹션 배치가 어긋나 PENDING_FEEDBACK로 재노출됨).
- "## 처리 대기" 섹션을 실제로 비우고("현재 처리 대기 항목 없음" 명시), 두 줄(AetherAI-only 항목 + 요약 불릿)을 "## 처리 완료" 섹션 최상단으로 이동했다. 내용 변경 없이 순수 섹션 배치 수정.
- 코드 변경 없음(문서 정리만). `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- 다음 사이클 다음 슬라이스: (1) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행(human-gated 유지), (2) 세로 상승형 핵심 루프/발라트로 스타일/런치 화면 지구 탐험물 전시 3개 항목은 코드·실기기 검증까지 완료되어 사용자 최종 확인만 남음, (3) 새 feedback이 등록되면 그것을 우선 처리한다.

## 은하계 체크포인트 마커 + 오프차트 화살표 + 은하별 배경 틴트 (완료, 2026-09-02)

`docs/feedback/INBOX.md` "처리 대기" 최우선 항목 1을 완료했다(이전 사이클이 이미 구현해둔 uncommitted diff를 이번 사이클에서 실제 LÖVE 런타임 캡처로 검증하고 커밋함).

- `game/world.lua`: `M.galaxyBackgroundColor(galaxy)` 순수 함수 추가 — 홈 태양계는 기존 남색(`homeBackgroundColor`) 유지, 그 외 은하는 `gx, gy` 해시 기반 보라/청록/붉은 3색 계열 중 하나로 결정적 틴트 부여. `game/scenes/play.lua`의 `draw()`가 `world.galaxyContaining`으로 현재 은하를 찾아 `love.graphics.clear`에 반영.
- `game/minimap.lua`: `M.nearestCheckpointDirection(shipX, shipY)` 순수 함수 추가 — `checkpointSearchCellRadius`(`galaxyCellRadius`+4) 범위에서 가장 가까운 비-milkyway 은하의 방향/거리를 반환. `M.view()`가 `checkpointBeyond/Dx/Dy/Distance/Id`를 노출.
- `game/scenes/play.lua`의 `drawMinimap()`: `hub=true`(체크포인트) 은하는 기존보다 큰 점 + 시간에 따라 pulse하는 반짝이는 링으로 그려 일반 은하 점과 구분. 미니맵 밖에 있는 가장 가까운 체크포인트는 기존 지구-복귀 화살표(주황)와 겹치지 않는 자홍색 화살표로 표시. 기존에 사용자가 긍정한 "현재 위치 은하 = 고리 표기" 방식은 그대로 보존.
- `game/self_test.lua`의 `testMinimap`: `nearestCheckpointDirection`의 단위벡터/거리/빈 결과 케이스, `checkpointBeyond` 노출, `galaxyBackgroundColor`의 홈 은하 고정값·비홈 은하 결정성·차별성 회귀 테스트 추가.
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-checkpoint-tint`, 1080×1920, `main.lua`에 기존재하던 캡처 하네스 사용)를 vision으로 확인: 미니맵의 두 은하 점 모두 반짝이는 노란 링(체크포인트 마커)이 태양 마커·지구(청록 점)와 뚜렷이 구분되어 보임, 배경 클리어 픽셀이 `(16, 5, 6)`으로 붉은(ember) 계열 틴트가 적용됨(홈 남색이 아님)을 확인.
- `make test` GREEN(`make verify` 대상 LÖVE 헤드리스 유닛+스모크, asset manifest 유닛 전부 OK).
- 남은 다음 슬라이스: `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 중 1번(배경 별 밀도 증가) 또는 2~3번(고도→거리 라벨링, 연료 무제한 HUD 정리)부터 착수.

## 연료 제약 제거 + 운석/쓰레기 + 미니맵 은하 고리 (완료, 2026-09-02)

연료는 더 이상 비행을 끊지 않는다. 실패 조건은 행성 충돌과 같은 운석·쓰레기 충돌이며, 미니맵은 태양 중심 고리와 은하명을 보여 준다.

- `game/expedition.lua`: `maneuverFuel`/`burnManeuverFuel` no-op. `update`는 상승 중 연료를 태우지 않고 `returning`으로 바꾸지 않는다. 귀환은 `beginReturn(run)`.
- `game/world.lua`: 섹터마다 결정적 운석/캔/고철(`debris`/`nearbyDebris`)이 표류. 홈 은하 표시명은 `SOLAR SYSTEM`.
- `PlayScene`: 쓰레기 충돌은 남은 내구도를 한 번에 깎아 행성 lethal과 같은 `SHIP DESTROYED`/메타 초기화. Lua 도형 placeholder로 그린다.
- `game/minimap.lua`: 은하 디스크 고리 + 태양 중심 궤도 고리 + `sun` 마커 + `galaxyName`. HUD 왼쪽 상단에 현재 은하명.
- 테스트: `testManeuverFuel`(무연료), `testDebris`, `testMinimap` 고리/SOLAR SYSTEM. `make test` GREEN.
- 남은 다음 슬라이스: 플레이어가 직접 귀환을 고르는 UI(`beginReturn`은 테스트/캡처만 연결됨). AetherAI 최종 에셋.

# STATUS
## 배경 별 밀도 증가: 이중 레이어(유성 전경 + 은하수 배경) 추가 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 1번(배경 별 밀도 증가)을 완료했다. preflight READY, `git status --short` clean으로 시작.

- `game/world.lua`: `M.backgroundStars(sectorX, sectorY)` 순수 함수 추가 — 섹터당 120개(`M.backgroundStarCount`), 기존 `M.stars`의 salt 대역(100/200/300)과 겹치지 않는 10000/20000/30000 salt 대역을 사용해 완전히 독립적으로 시드된 결정적 점 집합을 생성한다. 밝기(`bright`)는 0~0.55로 제한해 전경 유성별보다 어둡다.
- `game/scenes/play.lua`의 `draw()`: 기존 유성별 루프 앞에 배경별 루프를 추가했다. 카메라 이동량의 0.4배만 적용(감소된 parallax)해 거의 정지한 은하수처럼 보이게 하고, 색상도 더 어둡게(0.12+bright*0.4) 렌더링해 전경의 빠르게 지나가는 유성별과 시각적으로 명확히 구분한다. 기존 유성별 레이어는 완전히 그대로 유지(사용자가 마음에 들어한 부분).
- `game/self_test.lua`의 `testBackgroundStars`(신규): 같은 섹터 좌표에 대한 결정성, 전경 대비 밀도 2배 이상, 전경과 겹치지 않는 독립 시드임을 회귀 검증한다. 수정 전 `world.backgroundStars`가 nil이라 RED(`attempt to call field 'backgroundStars'`) 확인 후 구현, GREEN 전환 확인.
- 실측 검증: 임시 헤드리스 디버그 카운터(커밋에는 포함하지 않고 검증 후 되돌림)로 동일 뷰포트 위치(고도 900 지점)에서 전경 유성별 21개 대비 배경별 144개가 동시에 표시됨을 확인해 밀도 차이(~7배)가 실제로 체감 가능한 수준임을 검증했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 하위 1번 항목에 완료 표시 및 구현 요약을 추가(상위 항목 자체는 6개 중 1개만 처리되었으므로 "처리 대기"에 유지).
- 다음 사이클 다음 슬라이스: 같은 상위 항목의 2번(고도→"지구로부터 거리" 라벨 명확화) 또는 3번(연료 무제한 HUD 아이콘화)부터 순서대로 진행.

## "고도" → "거리" HUD 라벨 명확화 + 연료 게이지와 시각적 분리 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 2번(고도→"지구로부터 거리" 명확화)을 완료했다. preflight READY, `git status --short` clean으로 시작.

- `game/i18n.lua`의 `hud_primary` 문자열을 `"ALT %04d  CASH $%d"` → `"DIST %04d  CASH $%d"`(en), `"고도 %04d  자금 $%d"` → `"거리 %04d  자금 $%d"`(ko)로 변경. 실제 비행 로직은 이미 연료와 무관하게 `run.altitude`를 자동 증가시키므로(변경 없음), 문제는 오직 "고도(ALT)"라는 라벨이 인접한 연료 게이지와 혼동을 유발한다는 표현 문제였다.
- `game/scenes/play.lua`: 새 `M.hudPrimaryStatusGap = 6`(px)과 공용 `M.hudHeight(phase, hud, galaxyShift)` 헬퍼를 추가해, ascending/returning 페이즈에서 DIST/CASH 줄과 그 아래 연료/선체/슬롯 상태 줄(`hud_status`) 사이에 추가 수직 간격을 넣었다. 미니맵 배치(`drawMinimap`)와 실제 텍스트 렌더(`draw`)가 같은 `M.hudHeight` 함수를 공유하도록 리팩터링해 두 곳이 다시 어긋나지 않게 했다.
- `game/self_test.lua`: `hud_primary`가 더 이상 "ALT"를 포함하지 않고 "DIST"로 시작함을 검증하고, `PlayScene.hudPrimaryStatusGap`이 존재/양수임과 `PlayScene.hudHeight("ascending", ascendingHud, 0) == 46 + hudPrimaryStatusGap`을 검증하는 회귀 테스트를 추가(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-wide-warning`, 1080×1920)를 vision으로 확인해 HUD 상단이 "거리 1000  자금 $0" / "표본 00  위험 $0" 두 줄과, 시각적으로 분리된 간격 아래 "F100 H3/3 상승 S00" 줄로 정상 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 커밋하지 않고 검증 후 삭제).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 하위 2번 항목에 완료 표시 및 구현 요약을 추가(상위 항목 자체는 6개 중 2개만 처리되었으므로 "처리 대기"에 유지).
- 다음 사이클 다음 슬라이스: 같은 상위 항목의 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)부터 순서대로 진행.

## HUD 상태 줄에서 오해를 주는 연료 상한 표기(F%03d) 제거 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 첫 슬라이스를 처리했다. preflight READY, `git status --short` clean으로 시작.

- 실제 비행 로직(`game/expedition.lua`의 `M.maneuverFuel`/`M.burnManeuverFuel`)은 이미 no-op이라 연료가 상승을 막지 않는데도, 상단 HUD 상태 줄(`hud_status`)이 여전히 `F%03d`(예: `F100`)로 마치 연료 상한이 비행을 제약하는 것처럼 표시하고 있었다.
- `game/i18n.lua`의 `hud_status` 포맷을 en/ko 두 로케일 모두 `"F%03d H%d/%d %-6s S%02d"` → `"H%d/%d %-6s S%02d"`로 변경해 연료 수치 자체를 제거했다(내구도/페이즈/슬롯 표기는 유지).
- `game/scenes/play.lua`의 `M:hudLines()` 호출부에서 `math.floor(run.fuel)` 인자를 제거해 새 포맷 시그니처와 맞췄다.
- `game/self_test.lua`: `hudLines().status == "F100 H3/3 SETTLE S00"` 회귀 테스트를 `== "H3/3 SETTLE S00"` + "상태 줄에 F%d 패턴이 없어야 한다"는 방어적 assert로 갱신(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=ascending-wide-warning`, 1080×1920)를 vision으로 확인해 HUD가 "거리 1000  자금 $0" / "표본 00  위험 $0" / "H3/3 상승 S00"으로 정상 렌더링되고 연료 수치가 더 이상 보이지 않음을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 3번 항목에 이번 슬라이스 진행 상황(HUD 상태 줄 연료 표기 제거 완료, 아이콘 기반 재구성/LOADOUT `MAX FUEL` 텍스트 정리는 다음 슬라이스)을 기록했다.
- 다음 사이클 다음 슬라이스: 3번 항목의 남은 부분 — LAUNCH LOADOUT의 `stats_line`("MAX FUEL %d  HULL %d")과 EARTH SHOP의 연료 업그레이드 관련 문구를 아이콘 기반(로켓/방패/동전/스피드미터)으로 재구성. 그 다음은 4번(불필요한 텍스트 제거 검토)으로 진행.

## 슬롯 오즈 라인을 미니맵 위로 이동 + 귀환 진행률 텍스트와의 겹침 수정 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 5번(C50/P40/S10 슬롯 확률 표기를 미니맵 위 작은 텍스트로 이동)을 완료했다. preflight READY(`make test` PASS, `git diff` clean), 이번 사이클 시작 시 `git status --short`에 이전 사이클이 남긴 미커밋 변경(`game/scenes/play.lua`, 슬롯 오즈 라인을 `drawMinimap()`으로 옮기는 작업)이 있어 그대로 이어받아 완료했다.

- 이전 사이클이 `slot_odds_line`(`"C%d P%d S%d 평균 $%.2f"`)을 귀환 화면의 큰 별도 줄(y=197, center)에서 `game/scenes/play.lua`의 `drawMinimap()` 안, 미니맵 차트 바로 위의 작은 8px 우측정렬 텍스트로 옮겨두었다.
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=returning-odds`, 1080×1920)로 재검증한 결과, 옮겨진 오즈 줄이 바로 위에 그려지는 "귀환 0%  12초"(`hud_return_progress`) 텍스트와 겹쳐서 렌더링되는 잔여 결함을 발견했다. `M.hudHeight(phase, hud, galaxyShift)`의 `returning` 분기(`70 + hudPrimaryStatusGap + galaxyShift`)가 오즈 줄을 위한 추가 세로 공간을 예약하지 않았기 때문이다.
- `game/scenes/play.lua`에 신규 `PlayScene.hudOddsLineHeight = 10`(px)을 추가하고, `M.hudHeight`의 `returning` 분기 공식을 `70 + hudPrimaryStatusGap + hudOddsLineHeight + galaxyShift`로 수정했다. 이 함수는 `drawMinimap()`(미니맵 배치)과 `draw()`(실제 텍스트 렌더) 양쪽이 공유하므로 두 곳이 다시 어긋나지 않는다.
- `game/self_test.lua`에 `PlayScene.hudOddsLineHeight`가 존재/양수임과, `PlayScene.hudHeight("returning", returningHud, 0)`이 새 공식과 일치함을 검증하는 회귀 테스트를 추가했다(수정 전 RED `"returning HUD band height must grow by hudOddsLineHeight..."` 확인 후 GREEN 전환 확인).
- 수정 후 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=returning-odds`)를 vision으로 재확인: "귀환 0%  12초" 줄과 "C50 P40 S10  평균 $18.58" 오즈 줄이 겹치지 않고 세로로 깔끔하게 분리되어 미니맵 원형 차트 바로 위에 작게 표시됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 하위 5번 항목에 완료 표시 및 구현 요약을 추가(상위 항목 자체는 6개 중 5개만 처리되었으므로 "처리 대기"에 유지).
- 다음 사이클 다음 슬라이스: 같은 상위 항목의 6번(표본 도감 정리 검토 + 슬롯 6개를 함선 장비 카드 UI로 전환 — 규모가 크므로 데이터 구조 설계부터 슬라이스 필요) 또는 3~4번의 남은 부분(아이콘 기반 HUD 재구성, "STARTER"/"발사 장비"/"무피격 N"/"개발 임시본" 정리)으로 진행.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.

## LAUNCH LOADOUT/EARTH SHOP에서 오해를 주는 "MAX FUEL" 잔여 표기 제거 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 두 번째 슬라이스를 처리했다. preflight READY, `git status --short` clean으로 시작.

- 상단 HUD 상태 줄의 `F%03d` 표기는 이전 사이클에서 이미 제거되었으나, LAUNCH LOADOUT 카드(`stats_line` = `"MAX FUEL %d  HULL %d"`)와 EARTH SHOP의 함선 미리보기(`ship_preview_line`/`ship_preview_compact`), 그리고 연료·선체 업그레이드/구매 결과 메시지(`hull_upgraded_message`, `scout_purchased_message`, `ship_selected_message`)에는 여전히 `MAX FUEL %d`가 노출되어, 실제로는 no-op인 연료 상한이 여전히 의미 있는 스탯인 것처럼 보였다.
- `game/i18n.lua`의 en/ko 두 로케일 모두에서 `stats_line`을 `"MAX FUEL %d  HULL %d"`/`"최대연료 %d  선체 %d"` → `"HULL %d"`/`"선체 %d"`로, `ship_preview_line`을 `"%s MAX FUEL %d  HULL %d"`/`"%s 최대연료 %d  선체 %d"` → `"%s HULL %d"`/`"%s 선체 %d"`로, `ship_preview_compact`를 `"%s F%d H%d"` → `"%s H%d"`로 축소했다. `hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message`에서도 `MAX FUEL %d`/`최대연료 %d` 인자와 포맷 조각을 제거했다(연료 업그레이드 자체를 위한 `fuel_upgraded_message`는 여전히 연료 액션의 결과이므로 유지).
- `game/scenes/play.lua`의 `M:loadoutLines()`/`M:shopLoadoutLines()`/`hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message` 호출부에서 `run.maxFuel`/`self.expedition.maxFuel` 인자를 제거해 새 포맷 시그니처와 맞췄다.
- `game/self_test.lua`의 관련 하드코딩된 문구 회귀 테스트(`loadoutLines().stats`, `shopLoadoutLines().stats/shipPreview/hullPreview`, `hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message` 결과)를 전부 새 포맷에 맞춰 갱신(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920)를 vision으로 확인해 LAUNCH LOADOUT 카드가 "최대연료 100  선체 3" 대신 "선체 3"만 표시함을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- 3번 항목은 이번 사이클로 "연료 무제한 반영" 부분(HUD 상태 줄 + LOADOUT/SHOP 텍스트 모두)이 완료되었다. 남은 부분은 "아이콘 기반 HUD 간소화"(탭 발사/선체 내구도/자금/속도를 로켓·방패·동전·스피드미터 아이콘으로 재구성)로, 이번 사이클에서는 착수하지 않았다.
- 다음 사이클 다음 슬라이스: 3번 항목의 남은 아이콘 기반 재구성, 또는 4번(불필요한 텍스트 제거 검토 — `S%02d`, "STARTER", "발사 장비" 타이틀, "무피격 N" 라벨, "평균 $" 등)으로 진행.

## HUD 상태 줄에서 발사 단계의 불필요한 슬롯 표기(S00) 제거 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 4번(불필요한 텍스트 제거 검토)의 첫 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작.

- 발사(launch) 단계에서는 아직 귀환 여정이 시작되지 않아 `run.slotOpportunities`가 항상 0이므로, HUD 상태 줄(`hud_status` = `"H%d/%d %-6s S%02d"`)이 "H3/3 발사S00"처럼 항상 의미 없는 슬롯 예보를 표시하고 있었다.
- `game/i18n.lua`에 en/ko 두 로케일 모두 신규 `hud_status_no_slots = "H%d/%d %-6s"`(슬롯 세그먼트 없는 버전)를 추가했다. 기존 `hud_status`는 그대로 유지(다른 모든 페이즈는 슬롯 표기가 유의미하므로).
- `game/scenes/play.lua`의 `M:hudLines()`가 `run.phase == "launch"`일 때만 `hud_status_no_slots`를 사용하고, 그 외 페이즈(ascending/returning/settlement/destroyed)는 기존 `hud_status`(슬롯 포함)를 그대로 사용하도록 분기했다.
- `game/self_test.lua`에 발사 단계에서 상태 줄이 `"H3/3 LAUNCH"`(슬롯 세그먼트 없음)로 표시되고, SETTLE 등 다른 페이즈는 여전히 `"H3/3 SETTLE S00"`처럼 `S%02d`를 유지함을 검증하는 회귀 테스트를 추가했다(수정 전 RED `"H3/3 LAUNCH S00" ~= "H3/3 LAUNCH"` 확인 후 GREEN 전환 확인).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920)를 vision으로 확인해 "H3/3 발사" 줄에 더 이상 "S00"이 보이지 않음을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 4번 항목에 이번 슬라이스 진행 상황(발사 단계 `S%02d` 제거 완료, 남은 항목: "STARTER" 함선명/"발사 장비" 타이틀/"무피격 N" 라벨/"평균 $" 표기/"개발 임시본" 축소)을 기록했다.
- 다음 사이클 다음 슬라이스: 4번 항목의 남은 부분(함선 이름 "STARTER" 제거, "발사 장비" 패널 타이틀 검토, "무피격 N" → 아이콘/명확한 라벨, "평균 $" 정리, "개발 임시본" 축소) 중 하나를 이어서 처리하거나, 3번 항목의 아이콘 기반 HUD 재구성으로 진행.

## "개발 임시본"(DEV PLACEHOLDER) 푸터 텍스트 축소 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 4번(불필요한 텍스트 제거 검토)의 마지막 남은 세부 항목("개발 임시본" 축소)을 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작.

- 화면 최하단의 "DEV PLACEHOLDER"/"개발 임시본" 푸터가 기본 14px 폰트·0.85 알파로 그려져 바로 위 "탭하여 발사"/게임 메시지 줄과 시각적으로 경쟁하고 있었다. 이 텍스트는 최종 에셋 적용 전까지 유지가 필요한 영구 개발자용 고지일 뿐 게임플레이 정보가 아니므로, 조용한 워터마크처럼 보이도록 작게·흐리게 조정했다.
- `game/scenes/play.lua`에 신규 `M.devPlaceholderFontSize = 7`(px)과 `M.devPlaceholderAlpha = 0.4`를 추가하고, `draw()`의 푸터 렌더가 기본 폰트/0.85 알파 대신 이 값들을 사용하도록 변경했다(`self.tinyFont`를 재사용해 폰트 캐시를 공유).
- `game/self_test.lua`에 `PlayScene.devPlaceholderFontSize`가 기본 HUD 폰트(14px)보다 작고 `PlayScene.devPlaceholderAlpha`가 이전 0.85보다 낮음을 검증하는 회귀 테스트를 추가했다.
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1440×2560, ko 로케일)를 vision으로 확인해 "개발 임시본" 텍스트가 "탭하여 발사" 줄보다 눈에 띄게 작고 흐리게 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 4번 항목("불필요한 텍스트 제거 검토")에 남아있던 세부 항목 5개(S00 제거, 무피격→도달예상, 평균→기대값, 개발 임시본 축소)가 모두 완료되었다. 남은 것은 4번 항목의 상위 슬라이스인 "STARTER" 함선명 제거와 "발사 장비" 패널 타이틀 검토, 그리고 3번 항목의 아이콘 기반 HUD 재구성.
- 다음 사이클 다음 슬라이스: 4번 항목의 남은 두 세부(함선 이름 "STARTER" 제거, "발사 장비" 패널 타이틀 검토) 중 하나를 처리하거나, 3번 항목의 아이콘 기반 HUD 재구성으로 진행.

## HUD 상태 줄 선체 내구도(H%d/%d)에 방패 아이콘 추가 — 아이콘 기반 HUD 간소화 두 번째 슬라이스 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 두 번째 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작.

- 이전 사이클이 "탭하여 발사" 버튼에 로켓 아이콘을 추가했으나(item 3 첫 슬라이스), 선체 내구도(`hud_status`의 `H%d/%d` 세그먼트)·자금($)·속도 세 정보는 여전히 아이콘 없이 텍스트만으로 표시되고 있었다. 이번 슬라이스에서 선체 내구도에 방패 아이콘을 추가했다.
- `game/scenes/play.lua`에 순수 함수 `M.shieldIconPoints(cx, cy, size)`(윗변 평평·아래로 뾰족한 오각형 실루엣의 flat 폴리곤 점 목록, `rocketIconPoints`와 같은 패턴)와 `M.hullIconSize = 8`(px)/`M.hullIconGap = 4`(px)를 추가했다.
- `M:draw()`의 상태 줄 렌더가 갈라지는 세 분기(samples 있음/best 있음/기본)가 모두 공유하는 신규 로컬 헬퍼 `drawStatusWithShield(y)`를 추가해, 상태 텍스트 왼쪽에 이 방패를 하늘색(0.6,0.85,1)으로 그린 뒤 텍스트 draw x좌표를 아이콘 폭+간격(12px)만큼 오른쪽으로 밀어 겹치지 않게 했다. launch 페이즈의 8px 소형 폰트, 다른 페이즈의 기본 14px 폰트 모두에서 동작한다.
- `game/self_test.lua`에 `testHullShieldIcon()`(신규)을 추가했다 — 폴리곤이 짝수 개 점, 3개 이상 정점, 중심 위아래로 걸쳐 있음, cx 기준 수평 대칭임을 회귀 검증한다(순수 함수라 headless 검증만으로 RED/GREEN 확인, 기존 `testLaunchRocketIcon`과 동일 패턴).
- 실제 LÖVE 런타임 캡처 두 건을 vision으로 확인: `GAME_CAPTURE_PHASE=ascending-wide-warning`(1080x1920, 기본 14px 폰트)에서 방패 아이콘이 "H3/3 상승 S00" 텍스트 왼쪽에 겹침 없이 렌더링됨을 확인했고, `GAME_CAPTURE_PHASE=launch`(1080x1920, 8px 소형 폰트)에서도 "H3/3 발사" 왼쪽에 방패가 잘림 없이 정상 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 3번 항목에 이번 슬라이스 완료 표시 및 구현 요약을 추가(3번 항목 자체는 남은 아이콘화 대상이 자금($)·속도 두 가지이므로 "처리 대기"에 유지).
- 다음 사이클 다음 슬라이스: 3번 항목의 남은 부분(자금 아이콘화, 속도/스피드미터 아이콘화) 중 하나, 또는 6번(표본 도감 정리 검토 + 슬롯 6개를 함선 장비 카드 UI로 전환 — 데이터 구조 설계부터 슬라이스 필요)으로 진행.

## HUD 상단 CASH 표기에 동전 아이콘 추가 — 아이콘 기반 HUD 간소화 세 번째 슬라이스 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 세 번째 슬라이스를 처리했다. preflight READY(`make test` PASS, `git diff` clean), `git status --short` clean으로 시작.

- 이전 사이클까지 "탭하여 발사" 버튼(로켓)과 선체 내구도(방패)에 아이콘을 추가했으나, 자금($) 표기는 여전히 텍스트만이었다. 상단 HUD의 `hud_primary`(`"DIST %04d  CASH $%d"`)는 두 값을 하나의 문자열로 결합해 그렸기 때문에 CASH 값 앞에만 아이콘을 삽입할 수 없었다.
- `game/i18n.lua`에서 en/ko 두 로케일 모두 `hud_primary`를 `hud_distance`("DIST %04d"/"거리 %04d")와 `hud_cash`("CASH $%d"/"자금 $%d") 두 개의 독립된 키로 분리했다.
- `game/scenes/play.lua`의 `M:hudLines()`가 `distance`/`cash` 두 필드를 각각 반환하도록 변경(기존 `primary` 필드는 제거).
- `game/scenes/play.lua`에 순수 함수 `M.coinIconPoints(cx, cy, size)`(원이 아닌 8각형 실루엣의 flat 폴리곤 점 목록, `shieldIconPoints`/`rocketIconPoints`와 동일 패턴 — `love.graphics.circle`은 세그먼트 수가 암묵적이라 헤드리스 회귀 테스트로 정확히 고정할 수 없어 원 대신 다각형을 사용)와 `M.cashIconSize = 8`/`M.cashIconGap = 4`를 추가했다.
- `M:draw()`가 DIST 텍스트를 그린 뒤, 현재 활성 폰트(`love.graphics.getFont()`)로 측정한 DIST 텍스트 폭만큼 오른쪽에 동전 아이콘(금색)을 그리고, CASH 텍스트를 그 아이콘 폭+간격만큼 더 오른쪽에 그리도록 변경했다(launch 페이즈의 8px 소형 폰트와 다른 페이즈의 기본 14px 폰트 양쪽 모두 폭 측정이 자동으로 맞춰진다).
- `game/self_test.lua`에 `testCashCoinIcon()`(신규, `testHullShieldIcon`과 동일 패턴 — 폴리곤 형태·중심 상하 걸침·수평 대칭 검증)을 추가하고, 기존 `ascendingHud.primary` 회귀 단언을 `ascendingHud.distance`/`ascendingHud.cash` 두 필드에 대한 검증(DIST로 시작, ALT 미포함, CASH $N 형식)으로 갱신했다(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=ascending-wide-warning`, 1080×1920, ko 로케일)를 vision으로 확인해 "거리 1000"과 "자금 $0" 사이에 작은 금색 동전 아이콘이 겹침·잘림 없이 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- 3번 항목의 아이콘 기반 HUD 간소화 대상 4가지(탭 발사=로켓, 선체 내구도=방패, 자금=동전, 속도) 중 3가지가 완료되었다. 남은 것은 속도(조종속도/엔진속도)의 스피드미터 아이콘화뿐이다.
- 다음 사이클 다음 슬라이스: 3번 항목의 마지막 남은 부분(속도/스피드미터 아이콘화 — LAUNCH LOADOUT의 `steer_speed_line`에 아이콘 추가), 또는 6번(표본 도감 정리 검토 + 슬롯 6개를 함선 장비 카드 UI로 전환)으로 진행.

## [gear 레인] 부품 데이터 JSON 외부화 + tools/gear-editor/ 웹 에디터 (완료, 2026-09-03)

`docs/feedback/INBOX.md` 항목 13(선체/엔진 부품 데이터를 별도 config로 외부화 + 전용 웹 에디터 제공)을 처리했다. 이 레인(`spaceship-gear` 브랜치)은 `loop/PROMPT.md`의 레인 스코프에 따라 항목 13→9→10→12→14 순서로 진행하며, `game/scenes/play.lua`/`i18n.lua`/`world.lua`/`expedition.lua`는 원칙적으로 건드리지 않는다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- `game/json.lua`(신규) — 외부 의존성 없는 최소 JSON 디코더(객체/배열/문자열/숫자/불리언/null 지원, 인코더 없음). LÖVE에 JSON 모듈이 기본 내장되어 있지 않아 직접 작성했다.
- `game/gear.lua`(신규) — `love.filesystem`로 `game/data/hull_parts.json`/`game/data/engine_parts.json`을 읽어 스키마를 방어적으로 검증(중복 id, 범위 밖 effect 수치 [-100,100], 미지의 effect type/rarity, 빈 문자열 필드, 빈 effects 배열을 모두 명시적 에러로 거부)한 뒤 정규화된 Lua 카드 풀 테이블을 반환하는 얇은 로더. `M.loadHullParts`/`M.loadEngineParts`/`M.loadPool`/`M.findById`/`M.parsePool` 제공. 아직 게임 로직(장비 장착/효과 적용)에는 배선하지 않음 — 다음 항목 9에서 진행.
- `game/data/hull_parts.json`(신규, 선체 부품 6종), `game/data/engine_parts.json`(신규, 엔진 부품 4종) — 초기 콘텐츠. 항목 9·10 사이클에서 20~30종 규모로 확장 예정.
- `docs/GEAR_SCHEMA.md`(신규) — 카드/문서 JSON 스키마와 검증 규칙을 문서화.
- `tools/gear-editor/`(신규, 정적 HTML+CSS+JS, 빌드/서버 불필요) — 등급별 색상 테두리 카드 그리드 뷰 + 카드별 폼(id/이름 en·ko/아이콘/등급(색상 미리보기)/태그/에디션/effect 반복 목록)으로 추가·수정·삭제. 저장 전 `game/gear.lua`와 동일한 규칙으로 클라이언트 검증하며, JSON 다운로드 또는(Chrome/Edge의 File System Access API 지원 시) 원본 파일에 직접 저장(`showOpenFilePicker`/`createWritable`) 가능. `tools/gear-editor/README.md`에 사용법 문서화.
- `game/self_test.lua`에 `testGearJsonLoader()`를 추가해 JSON 디코더 스모크 테스트, 번들된 실제 데이터 파일 2종의 정상 로드/검증, `gear.findById`, 그리고 누락 파일/손상 JSON/중복 id/범위 밖 값/미지 effect 타입/미지 rarity/빈 effects/누락 id 등 7가지 방어적 실패 경로를 모두 회귀 검증(RED 확인 후 GREEN).
- `unzip -l build/game.love`로 `game/gear.lua`/`game/json.lua`/`game/data/*.json`이 `.love` 번들에 정상 포함됨을 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:54`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 항목 13 하위에 처리 상황을 append했다(항목 자체는 완료로 표시).
- 다음 사이클 다음 슬라이스: 항목 9(핵심 게임성 방향 — 발라트로 규모의 부품 다양성 + 조합/시너지 중심 고도 상승). `game/gear.lua`를 이용해 선체 부품 카드 풀을 20~30종으로 확장하고, 부품 조합이 고도 상승 속도/효율에 배가 효과를 내는 시너지 계산 엔진을 설계한다.


## [gear 레인] 엔진 부품 슬롯 분리 — game/engine_parts.lua 신규 (완료, 2026-09-03)

`docs/feedback/INBOX.md` 항목 10(부품 슬롯 이원화 — 선체(허브/조커형) 부품 + 엔진(타로/소모형) 부품 분리)을 처리했다. 이 레인(`spaceship-gear` 브랜치)은 `loop/PROMPT.md`의 레인 스코프에 따라 항목 13→9→10→12→14 순서로 진행하며, `game/scenes/play.lua`/`i18n.lua`/`world.lua`/`expedition.lua`는 원칙적으로 건드리지 않는다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- 신규 `game/engine_parts.lua` — 순수 함수 슬롯 이원화 API. `M.newLoadout()`이 `{ hull = {}, engine = {} }`(두 독립 배열)를 반환하고, `M.hullSlotCount = 6`(기존 "슬롯 6개")/`M.engineSlotCount = 3`(신규, 독립 캡)을 별도 상수로 둔다. `M.equip(loadout, category, part)`/`M.unequip(loadout, category, id)`/`M.isFull(loadout, category)`가 `category`("hull" 또는 "engine")로 지정된 리스트만 조작하고 다른 카테고리에는 절대 영향을 주지 않는다. 같은 카테고리 내 중복 id·용량 초과 장착은 `false, 에러메시지`로 거부(예외를 던지지 않음).
- `game/data/engine_parts.json`을 4종에서 12종으로 확장했다 — 항목13의 JSON 외부화 인프라(`game/gear.lua`의 `M.loadPool`/`M.loadEngineParts`)를 그대로 재사용하며, hull_parts.json과 동일 스키마(id/name/nameKo/icon/rarity/tags/editions/effects)로 common~legendary 등급 분포와 azure/ember/void hue-family 태그를 포함시켜 모든 카드가 기존 시너지 엔진(`gear.aggregateEffects`/`gear.tagSynergyMultiplier`/`gear.equippedTotals`, 항목9에서 이미 구현됨)과 그대로 호환된다.
- `docs/GEAR_SCHEMA.md`에 "Engine part slot separation (item 10)" 섹션을 추가해 슬롯 API 계약을 문서화했다.
- `game/self_test.lua`의 `testEnginePartsSlotSeparation()`(신규)이 다음을 회귀 검증한다: 엔진 풀 크기(>=10)/전카드 태그 보유, hull 장착이 engine 리스트 길이에 전혀 영향을 주지 않음(그 역도 마찬가지), engine 슬롯 unequip이 hull 리스트에 영향 없음, engine 슬롯을 캡(3)까지 채워도 hull은 여전히 안 가득참(`isFull`이 카테고리별로 독립적으로 계산됨), 용량 초과 장착과 같은 카테고리 내 중복 id 장착이 모두 `false`+에러로 거부됨. 수정 전(`game/engine_parts.lua` require 시점) RED(`module 'game.engine_parts' not found`) 확인 후 구현, GREEN 전환 확인.
- `unzip -l build/game.love`로 `game/engine_parts.lua`와 갱신된 `game/data/engine_parts.json`이 `.love` 번들에 정상 포함됨을 확인했다(55개 항목).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 항목 10 하위에 처리 상황을 append했다((a) 완료, (b)(c)는 다음 사이클로 명시).
- 아직 게임 배선(`run.equippedGear`/`run.equippedEngineParts`, 실제 장착 UI)에는 연결하지 않았다 — 레인 스코프상 `play.lua`/`expedition.lua`는 원칙적으로 다른 레인 담당이라 순수 데이터/슬롯 엔진 계층만 완성했다(향후 로더 호출 최소 예외 범위에서 배선 검토).
- 다음 사이클 다음 슬라이스: 항목 12(선체/엔진 부품 등급/에디션 파밍 시스템 — rarity별 드롭 가중치, edition 부여 확률 등을 `game/gear.lua`/`game/engine_parts.lua`에 순수 함수로 추가).

## [gear 레인] 엔진 부품 추진 특화 효과 카테고리(G) — 항목 10(b) 완료 (2026-09-03)

`docs/feedback/INBOX.md` 항목 10(b)("엔진 부품은... 추진/기동 계열에 특화된 효과... 집중해 선체 부품과 역할이 겹치지 않도록 차별화")를 처리했다. 항목13→9→10→12→14가 이미 1차 완료된 상태에서, 항목 10의 남은 (b)(c) 중 (b)를 이번 사이클에서 완료했다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- `game/gear.lua`의 `M.knownEffectTypes`에 신규 (G) 추진 특화 카테고리 3종(`fuelEfficiency`, `steeringResponsiveness`, `boostCharge`)을 추가하고 `M.effectCategories`에도 `"G"`로 등록했다.
- 3종 각각에 대한 순수 변환 함수를 추가했다: `M.effectiveFuelBurnRate(baseRate, parts)`(연료/기동 소모율 % 감소, 0 클램프), `M.effectiveSteeringRate(baseRate, parts)`(조종/회전 반응속도 % 증가), `M.boostChargeCount(parts)`(1회성 긴급 부스트 사용 가능 횟수, 정수 내림, 음수 방지 — `chainTriggerCount`/`rerollCount`와 동일한 이산 카운트 형태).
- `game/data/engine_parts.json`을 12종에서 14종으로 확장했다: 신규 `engine_emergency_boost_pod`(boostCharge), `engine_cryo_fuel_cell`(fuelEfficiency) 추가, 기존 `engine_ion_drive`(fuelEfficiency)/`engine_vector_nozzle`(steeringResponsiveness)/`engine_gyro_stabilizer`(steeringResponsiveness)에도 (G) 효과를 추가해 엔진 풀이 실제로 3종 모두를 사용하도록 했다. `game/data/hull_parts.json`은 (G) 타입을 전혀 사용하지 않아 "역할이 겹치지 않도록" 요건을 데이터 수준에서도 만족한다.
- `tools/gear-editor/editor.js`의 `EFFECT_TYPE_GROUPS`에 `"G: propulsion (engine parts)"` 그룹을 추가했다 — `KNOWN_EFFECT_TYPES`가 이 테이블에서 파생되므로 웹 에디터 폼/검증이 자동으로 동기화된다.
- `docs/GEAR_SCHEMA.md`에 "Propulsion specialization effect category (item 10b)" 섹션과 "Known effect types" 목록에 (G) 항목을 추가해 문서화했다.
- `game/self_test.lua`의 신규 `testEnginePropulsionSpecialization()`이 다음을 회귀 검증한다: (G) 3종이 `knownEffectTypes`/`effectCategories`에 정상 등록됨, 각 변환 함수의 정상/경계(클램프) 동작, 번들된 `engine_parts.json`이 fuelEfficiency/steeringResponsiveness/boostCharge 3종 모두를 실제로 사용함, 번들된 `hull_parts.json`은 (G) 타입을 전혀 사용하지 않음(역할 분리 회귀). 수정 전 RED(엔진 풀에 신규 타입이 없어 `sawFuelEff`/`sawSteering`/`sawBoost` 단언 실패, hull 카드 검증은 처음부터 GREEN) 확인 후 데이터/함수 반영, GREEN 전환 확인.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 항목 10 하위에 처리 상황을 두 번째 슬라이스로 append했다.
- (c) 획득 경로 3원화(상점 행성 구매/체크포인트 확정 드롭/지구 상점 범용 구매)는 여전히 미착수 — `game/world.lua`/`game/expedition.lua` 실배선은 레인 스코프상 최소 로더 호출 예외 범위에서 향후 슬라이스로 검토 필요.
- 아직 게임 배선(run.equippedGear/run.equippedEngineParts, 실제 장착 UI, (G) 함수들의 run 상태 소비)에는 연결하지 않았다 — 레인 스코프상 `play.lua`/`expedition.lua`는 원칙적으로 다른 레인 담당이라 순수 데이터/함수 계층만 완성했다.

## [gear 레인] 게임 배선 — run.equippedGear/run.equippedEngineParts + climbSpeed 시너지 실적용 (완료, 2026-09-03)

`loop/PROMPT.md`가 명시적으로 허용한 "gear.lua/engine_parts.lua를 게임에 배선하기 위한 최소한의 로더 호출" 예외 범위에서, 항목 9의 핵심 payoff(부품 시너지가 실제로 고도 상승 속도에 반영됨)를 지금까지 순수 함수로만 존재하던 상태에서 실제 `run` 상태로 처음 배선했다. `game/scenes/play.lua`/`world.lua`/`i18n.lua`는 건드리지 않았다 — 변경 파일은 `game/expedition.lua`(로더 require + 배선)와 `game/self_test.lua`(회귀 테스트)뿐이다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- `game/expedition.lua`가 최상단에서 `game.gear`/`game.engine_parts`를 require한다(레인 스코프 예외로 명시된 최소 로더 호출).
- `M.new(run)`이 이제 `run.gearLoadout`(`engine_parts.newLoadout()`, `{ hull = {}, engine = {} }`)과, 그 내부 배열을 그대로 가리키는 편의 필드 `run.equippedGear`/`run.equippedEngineParts`(항목 10이 이름까지 지정했던 필드)를 갖는다.
- 신규 `M.equipGear(run, category, part)`/`M.unequipGear(run, category, id)` — `engine_parts.equip`/`unequip`을 얇게 감싸 `run.equippedGear`/`run.equippedEngineParts`가 항상 `run.gearLoadout`의 실제 리스트를 가리키도록 동기화한다(캡슐화된 slot API를 그대로 재사용하므로 hull/engine 상호 비침범 보장이 자동으로 유지됨).
- 신규 `M.effectiveClimbSpeed(run)` — `gear.equippedTotals(run.equippedGear)`(항목 9의 태그 시너지 배율이 이미 적용된 climbSpeed 총합)를 `run.climbSpeed`(업그레이드 등 기존 값)에 가산한다. `M.update(run, dt)`의 ascending 분기가 `run.climbSpeed` 대신 이 함수를 사용하도록 변경해, 장착된 선체 부품의 climbSpeed 효과(및 시너지 배율)가 실제 상승 속도에 반영된다.
- 파괴 시 전체 메타 초기화(`destroy(run)`)가 `run.gearLoadout`을 새로 초기화하고 `equippedGear`/`equippedEngineParts`를 빈 배열로 재바인딩하도록 확장했다 — `docs/GAME_DESIGN.md`의 "내구도 0 시 구매한 함선/업그레이드 모두 초기화" 요구를 장착 부품에도 동일하게 적용(개인 최고 고도만 보존).
- `game/self_test.lua`의 신규 `testGearRunWiring()`이 다음을 회귀 검증한다: 신규 run이 빈 hull/engine 리스트로 시작함, 실제 번들 카드(`hull_ember_core`, climbSpeed +5)를 장착하면 1초 상승 후 고도가 base climbSpeed(60)보다 커짐(장비 배선이 실제 게임플레이에 영향을 줌), engine 장착이 hull 리스트에 전혀 영향 없음(항목10 슬롯 독립성이 run 레벨에서도 유지), unequip이 다른 카테고리에 영향 없음, 내구도 0 파괴 시 두 리스트 모두 빈 배열로 초기화됨. 수정 전 RED(`run.equippedGear`가 nil이라 "a fresh run must start with an empty hull gear list" 단언 실패) 확인 후 구현, GREEN 전환 확인.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua` 두 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- 여전히 미착수: 실제 장착 UI(플레이어가 화면에서 카드를 고르는 화면)는 `play.lua` 영역이라 다른 레인 담당. (E)/(F)/(D) 카테고리(detectionRadius/shopDiscount/insurance/collisionRadius 등)의 run 상태 소비, 항목 12의 실제 드롭 RNG 배선, 항목 9(c)의 슬롯 교체 루프 설계는 다음 슬라이스로 남는다.
- 다음 사이클 다음 슬라이스: (a) engine parts의 (G) 효과(fuelEfficiency/steeringResponsiveness/boostCharge)도 동일한 최소 로더 호출 방식으로 run에 배선(예: `M.effectiveFuelBurnRate`/`M.effectiveSteeringRate`를 실제 조종/연비 계산에 연결), 또는 (b) 항목 12(등급/에디션)의 실제 드롭 RNG 배선(체크포인트/상점 획득 시 `gear.rollRarity`/`gear.rollEdition` 호출), 둘 중 사용자 우선순위에 따라 선택.


## [gear 레인] 항목 12 드롭 RNG 게임 배선 — M.rollGearOffer (완료, 2026-09-03)

`docs/feedback/INBOX.md` 항목 12(등급/에디션 파밍 시스템)의 실제 게임 배선을 처리했다. 이 레인(`spaceship-gear` 브랜치)은 `loop/PROMPT.md`의 레인 스코프에 따라 항목13→9→10→12→14가 이미 1차 완료된 상태였고, 이번 사이클은 항목12의 `gear.rollRarity`/`gear.rollEdition`이 여전히 순수 함수로만 존재하던(어떤 run 코드도 실제로 호출하지 않던) 상태를 해소했다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- 신규 `game/expedition.lua`의 `M.rollGearOffer(run, pool, rolls)` — 명시적 `rolls`(rarity/pick/editionChance/editionPick, 실제 RNG 소스는 여전히 호출자 책임)를 받아 (1) `gear.rollRarity`로 등급을 결정하되 `run.equippedGear`의 luck 총합(`gear.totalLuckBonus`)을 luckBonus로 자동 주입, (2) 해당 등급 카드를 `pool`에서 선택(없으면 전체 풀로 폴백해 항상 카드를 반환), (3) `gear.rollEdition`(동일 luckBonus)으로 에디션 부여를 굴리고 부여되면 `gear.applyEditionEffects`로 실제 효과 수치까지 반영한 "오퍼" 테이블(`{id,name,nameKo,icon,rarity,tags,edition,effects}`)을 반환한다. 이 오퍼는 loadout 항목이 아니라 순수 결과값이며, 실제 장착은 기존 `M.equipGear`를 호출자가 별도 수행한다. `loop/PROMPT.md`가 명시적으로 허용한 "최소한의 로더 호출" 예외 범위이며 `play.lua`/`i18n.lua`/`world.lua`는 건드리지 않았다.
- `game/self_test.lua`의 신규 `testGearOfferRolling()`이 다음을 회귀 검증한다: roll=0→common 등급/무에디션, roll≈1 + 에디션 보유 카드 강제선택→legendary 등급 + 에디션 실제 적용(원본 대비 효과 수치 변경 확인), 장착된 luck 카드가 동일 roll에서 무luck 대비 절대 더 낮은 등급으로 가지 않고 이 프로브 케이스(roll=0.8, luck +20)에서는 실제로 uncommon→rare로 더 높은 등급을 뽑음(항목14 (C) luck 대상 #2 회귀), 특정 등급 카드가 없는 풀에서도 폴백으로 항상 오퍼를 반환함. 수정 전 RED(`attempt to call field 'rollGearOffer' (a nil value)`) 확인 후 구현, GREEN 전환 확인.
- `docs/GEAR_SCHEMA.md`에 "Item 12 drop RNG run wiring — M.rollGearOffer (follow-up slice)" 섹션을 추가해 계약을 문서화했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md` 네 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 12 하위에 처리 상황을 append했다.
- 여전히 미착수: 실제 상점/체크포인트 UI에서 `M.rollGearOffer`를 호출해 플레이어에게 카드를 제시하는 화면(레인 스코프상 `play.lua` 담당), 항목14 (C) chainTrigger/rerollBonus의 run 소비, 항목14 (E) detectionRadius/autoCollect의 run 배선(예: minimap.lua 스캔 반경에 실제 연결).
- 다음 사이클 다음 슬라이스: 항목14 (E) detectionRadius를 `minimap.lua`의 `viewRadius`/`checkpointSearchCellRadius`에 연결(이 역시 순수 함수는 이미 `gear.effectiveDetectionRadius`로 존재), 또는 (C) chainTrigger/rerollBonus를 상점 리롤/체인 트리거 소비 로직에 배선.

## [gear 레인] 항목14(B) streakMultiplier 마지막 잔여 배선 — 전 카테고리(A~G) run 소비자 완성 (완료, 2026-09-03)

`docs/feedback/INBOX.md` 항목 14의 (B) `streakMultiplier`(문서상 유일하게 "스키마에 등록만 되고 실제 run 소비자가 없는" 상태로 남아있던 효과 타입)를 배선했다. 이 레인(`spaceship-gear` 브랜치)은 항목13→9→10→12→14가 이미 1차 완료된 상태에서, `docs/GEAR_SCHEMA.md`의 "Effect schema categories A~F" 섹션이 명시적으로 남겨둔 마지막 gap을 처리했다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- `game/gear.lua`의 신규 `M.effectiveStreakBonusPerStep(baseBonusPerStep, parts)` — 순수 변환 함수, 카드의 `streakMultiplier` 값을 "스텝당 퍼센트 포인트 가산"으로 해석해 기본 스텝율에 더한다(예: value=10 → 스텝당 +10%p).
- `game/expedition.lua`의 신규 `M.streakBonusPerStep(run)` — 기존 항목14(C)/(E)에서 만든 `combinedGearList(run)` 헬퍼(hull+engine 합산, 카테고리 무관)를 재사용해 `gear.effectiveStreakBonusPerStep`을 실제 run의 장착 목록에 적용한다. `M.streakMultiplier(streakCount, run)`이 선택적 `run` 인자를 받아 하드코딩된 0.2 상수 대신 `M.streakBonusPerStep(run)`을 사용하도록 변경했다(무인자 호출은 기존 0.2 기본값으로 정상 폴백해 하위 호환 유지). `M.collectSample(run, value, hueKey)`이 `run`을 전달해 실제 원정 중 장착 부품이 표본 채집 스트릭 배율에 실제로 반영되도록 배선했다.
- `game/data/hull_parts.json`에 이 효과 타입을 처음 사용하는 카드 `hull_combo_matrix`(rare, streakMultiplier +10, tags economy/control)를 신규 추가했다.
- `game/self_test.lua`의 신규 `testGearStreakMultiplierWiring()`이 다음을 회귀 검증한다: 미장착 run의 스텝율/streakMultiplier(3)가 배선 전 기저값(0.2/1.4)과 정확히 일치, `run` 인자 없이 호출해도 정상 동작(하위 호환), `hull_combo_matrix` 장착 시 스텝율이 0.3으로 상승하고 streakMultiplier(3)이 1.6으로 상승, ENGINE 슬롯 장착도 동일하게 반영(카테고리 무관 설계), `collectSample`의 3연속 동일 계열 채집 호출이 실제로 성장하는 배율(1.0→1.3→1.6)을 반환함(RED 확인 후 GREEN — 구현 전 `attempt to call field 'streakBonusPerStep' (a nil value)` 에러로 실패).
- `docs/GEAR_SCHEMA.md`에 "Item 14(B) streakMultiplier run wiring" 섹션을 신규 추가해 계약을 문서화했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/data/hull_parts.json`/`game/expedition.lua`/`game/gear.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`는 전혀 건드리지 않았다.
- `docs/feedback/INBOX.md`의 항목 14 하위에 처리 상황을 append했다.
- **이제 항목14의 (A)~(G) 전 효과 타입이 최소 1개 실제 run-level 소비자를 갖는다** — 항목13→9→10→12→14 레인 스코프의 순수 함수/데이터/기본 run 배선 레이어가 사실상 완료된 상태다.

## [gear 레인] 항목14 효과 타입 콘텐츠 커버리지 — 카드 없이 방치되던 7개 타입에 실제 카드 추가 (완료, 2026-09-03)

이 레인(`spaceship-gear` 브랜치)이 지정받은 항목13→9→10→12→14가 이미 1차 완료된 상태에서, `docs/STATUS.md`/`docs/GEAR_SCHEMA.md`가 항목14의 A~G 전 효과 타입이 "최소 1개 실제 run-level 소비자"를 갖는다고 문서화해 왔으나, 이는 소비 *함수*(예: `expedition.detectionRadius`)가 존재한다는 뜻일 뿐 실제 번들 카드 데이터(`game/data/hull_parts.json`/`engine_parts.json`)가 그 타입을 사용하는 카드를 하나라도 포함하는지는 검증한 적이 없었다는 gap을 발견하고 처리했다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- 감사 결과: `sellMultiplier`/`luck`/`chainTrigger`/`rerollBonus`/`collisionRadius`/`detectionRadius`/`autoCollect` 7개 효과 타입이 run-level 배선 함수는 모두 존재하지만 실제 번들 카드 풀(선체 27종 + 엔진 14종) 어디에도 사용되지 않아, 플레이어가 실제 플레이에서 절대 마주칠 수 없는 죽은 콘텐츠였다.
- `game/self_test.lua`의 신규 `testGearEffectTypeContentCoverage()`가 항목10(b)의 `testEnginePropulsionSpecialization()`이 (G) 3종에만 적용하던 "번들 풀이 실제로 이 타입을 사용해야 한다" 패턴을 `gear.knownEffectTypes` 전체로 일반화한다 — 두 풀을 로드해 등장하는 모든 effect type의 합집합을 구하고, 알려진 모든 타입이 최소 1회 등장하는지 검증한다(RED 확인: `effect type 'detectionRadius' must be used by at least one bundled hull/engine part` 실패 후 데이터 추가, GREEN 전환).
- `game/data/hull_parts.json`에 7종 신규 선체 카드를 추가했다(누락 타입당 1장): `hull_market_broker`(sellMultiplier +20%), `hull_lucky_charm`(luck +15), `hull_echo_relay`(chainTrigger +1), `hull_negotiator_chip`(rerollBonus +2), `hull_slipstream_hull`(collisionRadius -15%), `hull_scanner_array`(detectionRadius +25%), `hull_collector_drone`(autoCollect). 기존 태그 관례(economy/control/defense/speed/void)를 유지해 항목9의 태그 시너지 엔진과 그대로 호환된다. 선체 풀이 27종에서 34종으로 확장(엔진 풀은 14종 그대로).
- `docs/GEAR_SCHEMA.md`에 "Item 14: effect-type content coverage" 섹션을 신규 추가했다.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/data/hull_parts.json`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`/`expedition.lua`는 전혀 건드리지 않았다(순수 데이터 + 테스트 슬라이스).
- 이로써 항목14의 A~G 전 효과 타입이 (1) 스키마 등록, (2) run-level 소비 함수, (3) 실제 번들 카드에서의 사용, 세 층위 모두를 갖춘 상태가 되었다.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화 — 상점/체크포인트 UI는 다른 레인 담당이라 순수 함수/데이터 계층에서 준비 가능한 부분만) 검토, 또는 신규 카드들의 실제 게임플레이 소비 지점(collisionRadius/detectionRadius를 minimap.lua/충돌판정에 연결 등, `play.lua`/`world.lua`/`minimap.lua` 담당이라 다른 레인 소관)은 이 레인 스코프 밖으로 명시.

## [gear 레인] 항목12 irradiated 에디션 시너지 보너스 배선 — 문서화만 되고 실제로는 죽어있던 핵심 효과를 살림 (완료, 2026-09-03)

이 레인(`spaceship-gear` 브랜치)이 지정받은 항목13→9→10→12→14가 모두 1차 완료된 상태에서, 항목12 "irradiated" 에디션의 문서(`⚠️ 방사능처리(Irradiated) — 시너지 태그 매칭 시 보너스 추가 증폭`)와 실제 코드 사이의 gap을 감사로 발견했다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- 감사 결과: `gear.editionSynergyBonusAdd(editionId)`(irradiated → +0.05, 그 외 → 0)가 item 12 슬라이스 때부터 순수 함수로 존재했으나, item 9의 실제 시너지 엔진 `gear.tagSynergyMultiplier(parts)`가 파트의 `edition` 필드를 단 한 번도 읽지 않았다 — 모든 공유 태그 쌍이 에디션과 무관하게 정확히 `M.synergyBonusPerSharedPair`(0.15)만 받고 있어서, irradiated 카드를 장착해도 일반 카드와 배율이 완전히 동일했다. irradiated 에디션이 사용자에게 문서화된 유일한 고유 메커니즘(시너지 증폭)이 실질적으로 죽은 콘텐츠였다(`applyEditionEffects`의 범용 "all"-scope 배율만 작동, 시너지 증폭 자체는 미작동).
- `game/gear.lua`의 `M.tagSynergyMultiplier(parts)`를 수정해, 공유 태그를 갖는 모든 쌍에 대해 `M.synergyBonusPerSharedPair` 위에 `M.editionSynergyBonusAdd(a.edition) + M.editionSynergyBonusAdd(b.edition)`을 추가로 더하도록 했다 — 쌍의 양쪽이 각자 독립적으로 자신의 에디션 보너스를 기여하므로, 같은 태그를 공유하는 irradiated 카드 2장은 두 기여분 모두 누적된다. 에디션이 없는(또는 irradiated가 아닌) 파트는 두 호출 모두 0을 반환해 기존 동작을 완전히 보존하며(순수 상위호환), 태그가 전혀 겹치지 않는 쌍은 여전히 시너지 기여가 전혀 없다(에디션이 없던 시너지를 만들어내지 않음).
- `game/self_test.lua`의 신규 `testGearIrradiatedSynergyBonusWiring()`이 다음을 회귀 검증한다: irradiated 카드가 포함된 공유 태그 쌍의 배율이 동일 쌍(에디션 없음)보다 반드시 더 큼, 그 차이가 정확히 `gear.editionSynergyBonusAdd("irradiated")`와 일치, 태그가 전혀 겹치지 않으면 irradiated 카드가 있어도 배율이 정확히 1(시너지 없음), 같은 태그를 공유하는 irradiated 카드 2장은 두 기여분 모두 누적됨(RED 확인: 수정 전 `boosted=1.15`가 `baseline=1.15`와 동일해 실패, 수정 후 GREEN).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:55`, `ASSET_MANIFEST_OK`).
- `git status --short`가 `game/gear.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` 파일만 수정으로 보고함 — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`/`expedition.lua`는 전혀 건드리지 않았다(`tagSynergyMultiplier`는 이미 `expedition.effectiveClimbSpeed`가 소비하고 있어 별도 run 배선이 불필요했다).
- 번들된 `hull_reactive_hull`/`hull_quantum_alloy`(선체), `engine_fusion_core`/`engine_singularity_drive`(엔진) 카드가 이미 `irradiated`를 후보 에디션으로 갖고 있어, 이 보너스는 기존 item 12 드롭 RNG 경로(`gear.rollEdition`/`expedition.rollGearOffer`)를 통해 신규 콘텐츠 추가 없이도 바로 도달 가능하다.
- `docs/GEAR_SCHEMA.md`에 "Item 12: `irradiated` edition synergy-bonus wiring" 섹션을 신규 추가했다.
- `docs/feedback/INBOX.md`의 항목 12 하위에 처리 상황을 append했다.
- 다음 사이클 다음 슬라이스: 항목7(획득 경로 3원화) 순수 데이터 계층 준비, 또는 이 레인이 완료한 순서 밖의 잔여 작업(실제 UI 소비 지점은 대부분 play.lua/world.lua 담당이라 다른 레인 소관) 검토.

## [gear 레인] 항목10(b)/14(G) boostCharge 소비 배선 — rerollBonus와 동일한 마지막 잔여 gap 처리 (완료, 2026-09-03)

이 레인(`spaceship-gear` 브랜치)이 지정받은 항목13→9→10→12→14가 모두 1차 완료된 상태에서, `M.boostChargeCount(run)`(항목10(b)/14(G))가 여전히 순수 재계산 총합으로만 존재하고 실제로 "쓸" 수 있는 소비 메커니즘이 없었다는 gap을 감사로 발견했다 — 항목14(C) `rerollBonus`가 `M.spendReroll`/`run.rerollsUsed`로 이미 닫은 것과 정확히 동일한 패턴의 마지막 잔여였다. preflight READY(엔진 테스트/패키지 PASS, git diff clean), `git status --short` clean으로 시작.

- TDD: `game/self_test.lua`의 `testGearPropulsionRunWiring`에 소비 검증 블록을 먼저 추가했다(RED 확인: `attempt to call field 'boostsRemaining' (a nil value)` 에러로 실패).
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

