# STATUS
- 감사 질문: 항목12 crystallized(✨ 결정화 — 판매가 대폭 상승)가 카드 *판매가*를 실제로 올리는가? `applyEditionEffects`는 sampleSellValue만 x2 했고, `gear.sellValue`는 모든 에디션에 동일하게 +6만 더해 irradiated/refined와 환급이 완전히 같았다(rare 24). 다른 에디션은 이미 고유 메커니즘(시너지/더블+부작용/noSlotCost)이 있어 crystallized의 고유 약속만 죽은 콘텐츠였다.
- TDD: `game/self_test.lua`에 신규 `testGearCrystallizedSellPremiumWiring()`을 추가했다(RED: crystallized must sell for more than the shared edition premium, got 24). `testGearEditorEditionEffectPreviewSync`에 `sellMultiplier` 필드 동기화·미리보기 소비 가드도 추가.
- `game/gear.lua`의 `M.editionEffects.crystallized.sellMultiplier = 2`. `M.sellValue`는 이 필드가 있으면 rarity base에 곱한 뒤 공유 `editionSellBonus`를 더한다(rare crystallized 18*2+6=42, legendary 86). `M.crystallizedSellMultiplier`는 그 필드의 별칭. `buyPrice`는 계속 sellValue*3이라 sell-to-rebuy는 손실 유지. `tools/gear-editor/editor.js`의 `EDITION_EFFECTS.crystallized`와 `updateEditionPreview`가 `(sell x2)`를 표시.
- 테스트가 타 에디션 +6 유지 / crystallized 엄격 우위 / legendary 스케일 / 미지 rarity common 폴백 / buyPrice 3x / settlement sellGear 42 credit / 엔진 슬롯 판매가 선체 비침범을 검증한다(RED 후 GREEN).
- `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`).
- 변경 파일은 `game/gear.lua`/`game/self_test.lua`/`tools/gear-editor/editor.js`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md`/`docs/STATUS_HISTORY.md` — `play.lua`/`i18n.lua`/`world.lua`/`expedition.lua` 미변경.
- 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사, 또는 상점 UI가 crystallized 판매가를 표시하는 지점(`play.lua`, 다른 레인).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
