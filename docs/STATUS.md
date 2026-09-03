# STATUS
- 감사 질문: 항목12 quantum_flawed(양자 결함 — "효과가 이중화되지만 부작용 존재")가 엔진 슬롯 카드에서도 그 부작용(hullDurability -1)을 실제로 부과하는가? `applyEditionEffects`는 카테고리 무관하게 hullDurability -1을 계속 append해왔지만, `equippedHullDurabilityBonus`는 `run.equippedGear`(hull 전용 리스트)만 읽어 엔진 슬롯 카드는 절대 이 총합에 들어갈 수 없었다. 번들 `engine_singularity_drive`가 실제로 quantum_flawed를 롤 가능한 유일한 엔진 카드였는데, 이 카드를 장착하면 (G) fuelEfficiency 등 효과는 정상적으로 2배가 되면서도 문서화된 유일한 대가(hullDurability -1)는 전혀 적용되지 않는 "공짜 이중화" 죽은 콘텐츠였다.
- TDD: `game/self_test.lua`에 신규 `testGearQuantumFlawedEngineDrawbackWiring()`을 추가했다(RED: engine-slot quantum_flawed card left maxDurability at 3 instead of dropping to 2).
- `game/gear.lua`의 신규 순수 함수 `M.engineSlotHullDurabilityDrawback(parts)`가 엔진 슬롯 리스트에서 **음수** hullDurability 효과만 합산한다(양수 hullDurability는 항목9의 "선체 전용 방어판" 설계를 지키기 위해 계속 0으로 무시). `game/expedition.lua`의 `equippedHullDurabilityBonus(run)`가 이제 hull 총합에 이 엔진 전용 감산 총합을 더한다.
- `M.equipGear`/`M.unequipGear`가 hull 뿐 아니라 engine 카테고리 변경 시에도 `refreshShipStats(run)`를 호출하도록 갱신되어, 엔진 슬롯 quantum_flawed 장착/해제 즉시(발사 전이라도) `run.maxDurability`에 반영되고 해제 시 원복된다.
- 테스트가 빈 리스트 0 / 엔진 카드 양수 hullDurability 무시 / 음수 -1 단독 / 음수 2장 스택 -2 / 양수 엔진 카드가 maxDurability를 올리지 않음 / 합성 quantum_flawed 엔진 픽스처 3→2 + fuelEfficiency 10→20 동시 검증 / 해제 시 3으로 복원 / 실제 번들 `engine_singularity_drive` + quantum_flawed 3→2를 모두 검증한다(RED 후 GREEN).
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- 변경 파일은 `game/gear.lua`/`game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md` — `play.lua`/`i18n.lua`/`world.lua` 미변경.
- 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사(예: `refined`(noSlotCost) 에디션이 엔진 슬롯에서도 동일하게 적용되는지, 또는 다른 카테고리 무관 효과의 엔진 슬롯 커버리지), 또는 crystallized/quantum_flawed 판매가·부작용을 실제로 노출하는 상점 UI(`play.lua`, 다른 레인).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
