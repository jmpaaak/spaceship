# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- INBOX 「UI/HUD 대대적 정리」 항목 3 잔여: EARTH SHOP이 더 이상 `SCOUT GAINS +40 FUEL`을 이득으로 광고하지 않음.
  - `game/scenes/play.lua` `M.scoutTradeoffLines()`: 엔진 `shipTradeoff`의 FUEL 라벨 gain은 UI에서 생략. 실제 선체 손실(`LOSSES -1 HULL`)만 남김.
  - 상점 draw는 `scoutTradeoff` 줄을 ipairs로만 그려 nil 두 번째 줄을 찍지 않음.
  - `expedition.shipTradeoff` / `scoutFuelBonus` 엔진 필드는 미변경 (econ / 항목 10이 보상 의미 재정의).
  - `game/self_test.lua` `testScoutFuelGainHidden()`: 엔진 FUEL gain 유지, UI 문구에 FUEL 부재, 선체 손실 1줄만 표시를 회귀(RED 확인 후 GREEN). 기존 shopLoadoutLines 단언 2곳도 동기화.
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:81`, `ASSET_MANIFEST_OK`).
- 항목 1·2·3·4·5는 기존 완료(+이번 슬라이스로 항목 3 SCOUT 연료 이득 문구까지). 항목 6은 gear 레인 소유라 main은 건드리지 않음.

## Next Slice
- 항목 6(장비 카드 HUD)은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
- 새 INBOX 피드백이 없으면 main 레인 다음 후보는 게이트된 잔여 연료 i18n 키(`fuel_bonus_line`/`win_fuel_line`/`slot_result_fuel`/`newbest_fuel_combined`) 자체 삭제 — 호출부는 이미 `showFuelBonusText=false`로 막혀 있고, 엔진 보너스 필드 재정의는 여전히 econ 항목 15.
