# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- INBOX 「UI/HUD 대대적 정리」 항목 2 잔여: 정산/파괴 요약 카드의 `PEAK ALT` / `최고고도`를 HUD와 같은 DIST/거리 표현으로 맞춤.
  - `game/i18n.lua`: `peak_alt_line` → `peak_dist_line` (`PEAK DIST %d` / `최고거리 %d`).
  - `game/scenes/play.lua` EARTH SHOP·SHIP DESTROYED 두 렌더 호출부를 새 키로 교체.
  - `game/self_test.lua` `testPeakDistLine()`: en/ko 문구, ALT/고도 부재, 구 키 삭제를 회귀(RED 확인 후 GREEN).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:81`, `ASSET_MANIFEST_OK`).
- 항목 1·2·3·4·5는 기존 완료(+이번 슬라이스로 항목 2 잔여 문구까지). 항목 6은 gear 레인 소유라 main은 건드리지 않음.

## Next Slice
- 항목 6(장비 카드 HUD)은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
- 새 INBOX 피드백이 없으면 main 레인 다음 후보는 사용자 노출 문자열에 남은 연료 프레이밍(`NEXT LAUNCH FUEL`, `win_fuel_line` 등) 정리 — econ 항목 11 잔재와 겹치면 조율하고 건드리지 않는다.
