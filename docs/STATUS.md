# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- INBOX 「UI/HUD 대대적 정리」 항목 3 잔여 연료 프레이밍: 런치가 no-op으로 소비하는 PLANET-트리플 `bankedFuelBonus`를 더 이상 HUD가 보상처럼 광고하지 않음.
  - `game/scenes/play.lua`: `M.showFuelBonusText = false`. `summaryFuelBonusLine()`은 보너스가 있어도 nil. 슬롯 완료 메시지는 fuel 분기를 건너뛰고 `slot_result_plain`으로 떨어짐. 귀환 슬롯 WIN 줄은 신규 순수 함수 `M.slotWinLine(run)`이 pending-money 포맷을 씀.
  - 엔진 `lastSlotFuelBonus`/`pendingFuelBonus`/`bankedFuelBonus`는 미변경 (econ 항목 15가 보상 의미 재정의).
  - `game/self_test.lua` `testFuelBonusTextHidden()`: 플래그, 정산 요약줄 부재, PLANET 트리플 메시지/`slotWinLine`의 FUEL 부재를 회귀(RED 확인 후 GREEN).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:81`, `ASSET_MANIFEST_OK`).
- 항목 1·2·3·4·5는 기존 완료(+이번 슬라이스로 항목 3 잔여 연료 문구까지). 항목 6은 gear 레인 소유라 main은 건드리지 않음.

## Next Slice
- 항목 6(장비 카드 HUD)은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
- 새 INBOX 피드백이 없으면 main 레인 다음 후보는 EARTH SHOP의 `SCOUT GAINS +40 FUEL` 트레이드오프 문구(연료가 비행 제약이 아닌데 SCOUT 이득으로 남아 있음) — `expedition.shipTradeoff` 엔진 필드는 econ/항목 10과 겹치면 조율하고 건드리지 않는다.
