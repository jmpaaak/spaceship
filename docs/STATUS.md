# STATUS
- 감사 질문(이전 슬라이스의 "다음 슬라이스" 지정 항목): 항목12 `refined`(noSlotCost — "슬롯을 소모하지 않음") 에디션이 엔진 슬롯(용량 3)에서도 hull 슬롯(용량 6)과 동일하게 슬롯 예외를 받는가?
- 코드 감사 결과: `game/engine_parts.lua`의 `occupiedSlotCount`/`isFull`/`equip`은 `category` 파라미터로 hull/engine을 완전히 제네릭하게 처리하고 hull 전용 분기가 전혀 없다 — 설계상으로는 이미 두 카테고리 모두에서 동일하게 동작해야 했다. 하지만 기존 `testGearNoSlotCostEditionWiring`은 hull 카테고리만 검증했고, 엔진 카테고리에 대한 회귀 가드가 코드베이스에 단 하나도 없었다("문서상 보장일 뿐 코드가 확인한 적이 없다"는, 이 레인이 반복 적용해온 감사 패턴과 동일 유형의 gap).
- TDD: `game/self_test.lua`에 신규 `testGearNoSlotCostEngineSlotWiring()`을 추가했다 — 엔진 슬롯(3)을 일반 카드로 가득 채운 뒤 (1) 일반 카드 추가 거부 (2) `refined` 에디션 카드는 가득 찬 상태에서도 장착 성공 (3) 장착 후에도 `isFull(engine)`은 여전히 true (일반 3장은 그대로 슬롯 점유) (4) 일반 카드 1장 해제 시 정확히 1슬롯만 여유 생김(refined 카드 존재와 무관) (5) 그 자리에 새 일반 카드 재장착 성공 (6) 엔진 카테고리를 `refined` 오버플로로 채워도 독립된 hull 카테고리의 `isFull`에는 전혀 영향 없음을 검증한다.
- 첫 실행부터 GREEN이었다(코드가 이미 제네릭하게 옳게 동작했음을 실측으로 확인 — RED를 강제로 관찰하려면 `occupiedSlotCount`에 임시로 hull 하드코딩을 넣어 확인할 수도 있었으나, 실제 프로덕션 코드에 결함이 없어 그 단계는 생략하고 GREEN 확인으로 회귀 가드를 확정했다). 이 슬라이스의 가치는 버그 수정이 아니라 "문서화된 대칭성 보장"을 실제 테스트로 승격시켜 향후 회귀를 방지하는 것이다.
- `make test`(GAME_HEADLESS=1 GAME_UNIT=1 love .)와 `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- 이번 사이클 커밋 2개: (1) 전 사이클이 남긴 uncommitted 항목12 quantum_flawed 엔진 슬롯 hullDurability 페널티 배선(`game/gear.lua`/`game/expedition.lua`/`docs/GEAR_SCHEMA.md`, 이미 이전 STATUS.md 기록으로 검증 완료 상태였음)을 그대로 커밋, (2) 이번 슬라이스의 `testGearNoSlotCostEngineSlotWiring` 신규 추가.
- 변경 파일은 `game/self_test.lua`(신규 테스트만) — `game/gear.lua`/`game/engine_parts.lua`/`game/expedition.lua` 프로덕션 코드는 이번 슬라이스에서 무변경(이미 옳았음). `play.lua`/`i18n.lua`/`world.lua` 미변경.
- 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사. 후보: (a) 다른 카테고리 무관 에디션 메타데이터(`sellMultiplier`, `editionSynergyBonusAdd` 등)가 hull/engine 양쪽에서 대칭적으로 테스트됐는지 유사 감사, (b) crystallized/quantum_flawed 판매가·부작용을 실제로 노출하는 상점 UI(`play.lua`, 다른 레인 소관이라 이 레인에서는 데이터/로직 계층까지만), (c) 항목14 나머지 효과 스키마 그룹의 카드x카테고리 조합 커버리지 재감사.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
