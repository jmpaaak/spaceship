# STATUS
- preflight this cycle: PASS.
- Slice: 항목8 은하 중심 체크포인트 부분 정산 (Partial Settlement) 구현 및 항목 10/14 parity gap 1건(boostsUsed) 닫기.

## 구현 내용
항목 8 ("행성 탐사 보상은 표본만, 정산은 체크포인트에서만")의 요구사항에 따라,
지구(고도 0) 복귀 시 전체 정산이 일어나는 기존 구조 외에 비행 중(은하 체크포인트 조우 시)
보유한 표본(pendingSampleValue)만 돈으로 즉시 환산해주는 부분 정산 로직을 구현했다.

`game/expedition.lua`에 `M.settleAtHub(run)`을 신규 추가하여, `run.pendingSampleValue`를
`run.money`로 합산하고 pending 값을 0으로 비운다. 이는 원정을 종료(`run.phase = "settlement"`)시키지 않고
비행 상태를 유지하며, M.equippedHullMoneyBonus (지구 정산 보너스)는 적용하지 않는다.
또한, `M.collectSample`이 이미 즉시 돈이 아닌 `pendingSampleValue`만 올려주는
정상 구조를 갖추고 있음도 확인했다.
(덧붙여, 이전 사이클의 잔재였던 `run.boostsUsed`가 destroy 시 리셋되지 않는 parity gap 도 닫았다.)

## 테스트 (TDD, RED → GREEN)
`game/self_test.lua`에 신규 `testHubPartialSettlement()`를 추가했다:
- `M.collectSample`로 획득한 표본이 `money`가 아닌 `pendingSampleValue`에만 적립됨을 확인 (회귀 방지)
- `M.settleAtHub` 호출 시 `pendingSampleValue`가 0으로 비워지고 그만큼 `money`가 상승함을 검증
- 여러 번 호출해도 남은 pending이 없으면 money가 변하지 않음을 검증

RED 확인 후 GREEN 전환.

## 검증
`make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN (`SPACESHIP_UNIT_OK`,
`SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:63`, `ASSET_MANIFEST_OK`).
변경 파일: `game/expedition.lua`/`game/self_test.lua`/`docs/STATUS.md`/`docs/feedback/INBOX.md`
(`play.lua`/`i18n.lua`/`world.lua` 미변경).

- Next slice: 항목 7, 13, 9, 10, 12, 14 의 잔여 gap 재감사 또는 항목 15 순수 데이터 계층 처리.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
