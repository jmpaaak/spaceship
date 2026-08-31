# STATUS

## 현재 상태

- 기존 자유 회전형 가로 우주 탐색 프로토타입은 사용자 핵심 기획과 맞지 않아 교체 대상이다.
- 목표는 세로 `180×320` 상승형 모바일 로그라이트다.
- 현재 그래픽은 전부 개발용 Lua placeholder이며 최종 AetherAI 에셋이 아니다.
- 공식 AetherAI 로그인/export가 없으므로 최종 미술은 human-gated pending이다. 코드·상태머신·저장·충돌·슬롯·상점 개발은 계속한다.

## 다음 한 가지

- 테스트를 먼저 추가하고 portrait viewport와 `launch → ascending → returning/slots → settlement/shop → relaunch`, 파괴 시 메타 초기화·최고 높이 보존을 구현한다.

## 완료 조건

- `make verify LOVE=/Users/jm/.local/bin/love` 통과
- 세로 실제 런타임 캡처
- 안전 귀환과 파괴 실패 양쪽 자동 테스트
- Git clean checkpoint commit/push
