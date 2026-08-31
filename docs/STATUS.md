# STATUS

## 현재 상태

- 내부 canvas와 기본 창, 카메라, HUD를 세로 `180×320` 기준으로 전환했다.
- `game/self_test.lua`가 세로 viewport 크기와 `720×1280` 정수 배율 좌표 변환을 검증한다.
- 실제 LÖVE runtime capture `build/spaceship-runtime-preview.png`는 `360×640`이며 HUD와 `DEV PLACEHOLDER` 표기가 화면 안에 보이는 것을 확인했다.
- 기존 자유 회전 탐색은 아직 남아 있으며 원정 phase와 지구 출발·귀환 루프는 미구현이다.
- 현재 그래픽은 전부 개발용 Lua placeholder이며 최종 AetherAI 에셋이 아니다.
- 공식 AetherAI 로그인/export가 없으므로 최종 미술은 human-gated pending이다. 코드·상태머신·저장·충돌·슬롯·상점 개발은 계속한다.

## 다음 한 가지

- engine-hosted 전이 테스트를 먼저 추가하고 `launch → ascending → fuel 0 자동 returning` 원정 상태와 상승 거리 기반 슬롯 기회 계산을 구현한다.

## 완료 조건

- `make verify LOVE=/Users/jm/.local/bin/love` 통과 (`SPACESHIP_UNIT_OK`, bundle 22 entries)
- 세로 실제 런타임 캡처 `360×640` 확인
- 전체 핵심 루프, 안전 귀환, 파괴 실패 자동 테스트는 후속 slice
