# STATUS

## 현재 상태

- 내부 canvas와 기본 창, 카메라, HUD를 세로 `180×320` 기준으로 전환했다.
- `game/self_test.lua`가 세로 viewport 크기와 `720×1280` 정수 배율 좌표 변환을 검증한다.
- `launch`에서 Space/Enter/위 입력으로 출발하고, `ascending` 중 자동 상승·연료 소모 후 연료 0에서 `returning`으로 전이한다.
- 귀환 거리를 최고 상승 높이로 확정하고 매 100 거리마다 슬롯 기회 1회를 올림 계산한다.
- `returning` 중 초당 45 거리로 자동 하강하고 지구 고도 0에 도착하면 `settlement`로 전이한다.
- 귀환 중 Space/Enter/위 입력으로 슬롯 기회를 1회씩 사용하며, 기회가 0이면 추가 실행되지 않는다.
- 상승 중 발견한 행성 표본은 고도에 따라 가치가 증가하며 미정산 표본 가치로 누적된다.
- 슬롯 1회마다 `$10` 잠정 보상이 누적되고, 안전하게 지구에 도착하면 표본 가치와 슬롯 보상을 한 번만 돈으로 확정한다.
- 정산 뒤 미정산 표본·슬롯 보상과 남은 슬롯 기회는 비워지고 HUD와 메시지에 정산액·보유 돈이 표시된다.
- 실제 LÖVE runtime capture `build/spaceship-runtime-preview.png`는 `540×960`이며 지구·우주선, LAUNCH HUD, 출발 안내와 `DEV PLACEHOLDER` 표기가 세로 화면 안에 보인다.
- 안전 귀환 뒤 상점과 재출발은 아직 미구현이다.
- 현재 그래픽은 전부 개발용 Lua placeholder이며 최종 AetherAI 에셋이 아니다.
- 공식 AetherAI 로그인/export가 없으므로 최종 미술은 human-gated pending이다. 코드·상태머신·저장·충돌·슬롯·상점 개발은 계속한다.

## 다음 한 가지

- engine-hosted 구매 테스트를 먼저 추가하고 정산 화면에서 돈으로 연료 강화를 구매한 뒤 강화된 연료로 재출발하게 한다.

## 완료 조건

- `make verify LOVE=/Users/jm/.local/bin/love` 통과 (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:23`)
- 세로 실제 런타임 캡처 `540×960` 확인
- 상점·재출발과 파괴 실패 자동 테스트는 후속 slice
