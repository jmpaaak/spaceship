# STATUS
- 감사 질문: 항목9(c) 슬롯 교체 루프는 `M.sellGear`/`exploreHub`만 있고 지구 상점 *구매*가 없었다. 문서상 sell-to-rebuy는 손실이어야 하는데 `gear.buyPrice`가 없고, 항목14(F) `shopDiscount`는 연료/선체 업그레이드에만 걸려 상점의 본상품인 부품 카드에는 적용되지 않았다.
- TDD: `game/self_test.lua`에 신규 `testGearBuyEconomyWiring()`을 추가했다(기존 `testGearSlotSwapEconomyWiring` 바로 아래, `M.run`에 등록).
- `game/gear.lua`의 `M.buyPrice(part)`는 `M.sellValue * M.buyPriceMultiplier`(3) — common 4→12, legendary 에디션 46→138. `game/expedition.lua`의 `M.buyGear`는 settlement-only, `shopPrice` 할인, `galaxyExclusive` 지구 판매 거부, `equipGear` 경유로 hullDurability 즉시 반영. `M.sellGear`는 이제 `engine_parts.unequip` 직접 호출 대신 `M.unequipGear`를 타서 판매 후 maxDurability가 다시 줄어든다.
- 테스트가 buyPrice 스케일/비행 중 거부/잔액 부족 거부/hull 구매+내구 즉시 반영/중복 id 거부/엔진 슬롯 비침범/shopDiscount 12→9.6/galaxyExclusive 거부/판매 후 내구 3 복귀를 검증한다.
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- 변경 파일은 `game/gear.lua`/`game/expedition.lua`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md`/`docs/STATUS_HISTORY.md` — `play.lua`/`i18n.lua`/`world.lua` 미변경.
- 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사, 또는 실제 EARTH SHOP UI가 `buyGear`/`sellGear`를 호출하는 지점(`play.lua`, 다른 레인).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
