# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- STATUS next slice: 게이트만 되어 있던 잔여 연료 i18n 키 자체 삭제.
  - `game/i18n.lua` en/ko에서 `fuel_bonus_line` / `win_fuel_line` / `slot_result_fuel` / `newbest_fuel_combined` 제거.
  - `game/scenes/play.lua`: `summaryFuelBonusLine()`는 항상 nil. 슬롯 결과/WIN 줄/정산 NEW BEST 분기에서 연료 카피 호출 제거. `showFuelBonusText=false` 유지.
  - 엔진 `bankedFuelBonus`/`lastSlotFuelBonus`/`scoutFuelBonus`는 미변경 (econ 항목 15).
  - `game/self_test.lua` `testFuelBonusTextHidden()`: 위 4키가 en/ko 모두 nil + 기존 숨김 회귀(RED 확인 후 GREEN).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:81`, `ASSET_MANIFEST_OK`).
- UI/HUD 항목 1–5 완료 유지. 항목 6은 gear 레인. 7/8/11/15는 econ, 9/10/12/13/14는 gear.

## Next Slice
- 항목 6(장비 카드 HUD)은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
- 새 INBOX 피드백이 없으면 main 레인 후보는 런타임 HUD에서 남은 죽은 `showFuelBonusText` 플래그/`summaryFuelBonusLine` 헬퍼 자체 삭제(호출은 이미 항상 nil). 엔진 보너스 필드 재정의는 여전히 econ 항목 15.
