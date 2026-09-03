# STATUS
- 감사 질문: 항목12 에디션 변환(`crystallized` sampleSellValue x2, `quantum_flawed` 전체 x2 + hullDurability -1, `refined` 전체 x0.5)이 장착 후 실제 run 스탯에 반영되는가? `rollGearOffer`는 오퍼 테이블에 `applyEditionEffects`를 이미 적용했지만, `M.equipGear`는 받은 카드를 그대로 슬롯에 넣어 상점/허브 UI가 풀 원본에 `edition` id만 찍으면 변환 수치가 버려졌다.
- TDD: `game/self_test.lua`에 신규 `testGearEquippedEditionEffectsRunWiring()`을 먼저 추가했다(RED: `equipping a crystallized card (raw sampleSellValue 5) must yield sample bonus 10, got 5`).
- `game/expedition.lua`의 `materializeEdition`이 입력 카드를 얕은 복사한 뒤 `gear.applyEditionEffects`를 한 번 적용하고 `editionApplied`로 이중 적용을 막는다. `M.equipGear`는 이 사본을 슬롯에 넣는다. `rollGearOffer`도 변환된 오퍼에 `editionApplied`를 찍어 상점 UI가 오퍼를 그대로 장착해도 수치가 두 배가 되지 않는다. 입력 카드는 변형하지 않는다.
- 테스트가 crystallized 5→10 / 무에디션 baseline 5 / quantum_flawed maxDurability 3→6(더블+drawback) / refined climbSpeed 8→4 / 엔진 슬롯 sampleSellValue 스코프 0 / 이미 변환된 오퍼 멱등 10 유지를 검증한다(RED 후 GREEN).
- 같은 사이클에서 이전 미커밋이던 `testGearEditorEditionEffectPreviewSync`의 drawback/synergyBonusAdd/noSlotCost 필드 동기화·미리보기 소비 가드도 함께 GREEN.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- 변경 파일은 `game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md`/`docs/STATUS_HISTORY.md` — 레인 스코프가 금지한 `play.lua`/`i18n.lua`/`world.lua`, 그리고 `game/gear.lua`/`game/engine_parts.lua`는 건드리지 않았다.
- 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사, 또는 실제 UI 소비 지점(`play.lua`가 `rollGearOffer` 결과를 `equipGear`에 넘기는 상점/허브 화면 — 다른 레인).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
