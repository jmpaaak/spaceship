# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- INBOX 「UI/HUD 대대적 정리 6개 항목」 4번의 잔여 데드 텍스트: 발사 단계에서만 숨기던 HUD `S%02d` 슬롯 예보를, 슬롯 기회가 실제가 아닌 모든 페이즈에서 숨김.
  - 기존: launch만 `hud_status_no_slots` (`HULL 3/3 LAUNCH`). settlement는 `HULL 3/3 SETTLE S00`, ascending은 동일하게 S00(또는 이전 원정에서 남은 카운트)가 붙어 같은 혼란을 유발.
  - `game/scenes/play.lua` `M:hudLines()`: `run.phase == "returning"`일 때만 `hud_status`(S%02d). 그 외는 `hud_status_no_slots`.
  - 귀환 중 남은 횟수는 실제 정보이므로 유지 (`HULL 3/3 RETURN S03`).
  - `game/self_test.lua`에 launch/ascending/settlement 무슬롯 세그먼트 + returning 유지 회귀를 추가(RED 확인 후 GREEN).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:81`, `ASSET_MANIFEST_OK`).
- 항목 4는 이 슬라이스로 S00 잔재까지 포함해 완료 표기. 항목 1·2·3·5는 기존 완료. 항목 6은 gear 레인 소유(항목 9/13/14에 흡수)라 main은 건드리지 않음.

## Next Slice
- 항목 6(장비 카드 HUD)은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
- 새 INBOX 피드백이 없으면 main 레인 다음 후보는 정산 카드의 `PEAK ALT`처럼 아직 "고도" 잔재인 사용자 노출 문구를 DIST/거리로 맞추는 소형 UI 슬라이스.
