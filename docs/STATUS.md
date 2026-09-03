# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- STATUS next slice: 죽은 `showFuelBonusText` 플래그/`summaryFuelBonusLine` 헬퍼 자체 삭제.
  - `game/scenes/play.lua`: `M.showFuelBonusText` 제거, 항상 nil이던 `M:summaryFuelBonusLine()` 제거. EARTH SHOP 요약 extra line은 `lastNewBest`만 사용.
  - 엔진 `bankedFuelBonus`/`lastSlotFuelBonus`/`scoutFuelBonus`는 미변경 (econ 항목 15).
  - `game/self_test.lua` `testFuelBonusTextHidden()`: 플래그/헬퍼가 nil (RED 확인 후 GREEN).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:81`, `ASSET_MANIFEST_OK`).
- UI/HUD 항목 1–5를 처리 완료로 이동. 항목 6은 gear 레인. 7/8/11/15는 econ, 9/10/12/13/14는 gear.

## Next Slice
- 항목 6(장비 카드 HUD)은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
- 새 INBOX 피드백이 없으면 main 레인에 남은 UI/HUD 1–5 작업 없음. 엔진 보너스 필드 재정의는 여전히 econ 항목 15.
