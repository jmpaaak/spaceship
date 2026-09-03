# STATUS
preflight READY(engine tests/package PASS, git diff clean). INBOX 최우선 항목 「내부 해상도를 발라트로 수준으로 상향」의 세 번째(마지막) 슬라이스 — 이전 두 슬라이스가 남긴 "일부 장식 px는 아직 구 스케일" 잔여분을 마저 처리해 이 항목을 완결했다.

- TDD: `game/self_test.lua`의 `testCanvasLayoutScale()`에 신규 단언(`PlayScene.floatingTextBoxHalfWidth`/`floatingTextBoxTopOffset`, `minimap.markerSunRadius` 등 10개 마커 반경 상수)을 먼저 추가해 RED(`game/self_test.lua:1045`) 확인 후 구현.
- `game/scenes/play.lua`에 `M.floatingTextBoxHalfWidth = 120`/`M.floatingTextBoxTopOffset = 40`(구 30/10 ×4)을 추가하고 표본 획득/피격 "+$N"/"-N" 플로팅 텍스트의 `love.graphics.printf` 박스가 이 상수를 참조하도록 교체.
- `game/minimap.lua`에 미니맵 마커 반경 상수 10개(`markerSunRadius` 10.4, `markerGalaxyHomeRadius` 8.8, `markerGalaxyHubRadius` 9.2, `markerGalaxyHubRingRadius` 16, `markerGalaxyPlainRadius` 6, `markerEarthRadius` 8, `markerPlayerFillRadius` 6.8, `markerPlayerLineRadius` 9.6, `markerBeyondRadius` 8.8, `markerCheckpointTipRadius` 7.2 — 옛 180×320 스케일 2.6/2.2/2.3/4/1.5/2/1.7/2.4/2.2/1.8의 ×4)를 추가하고, `game/scenes/play.lua`의 `M:drawMinimap()`(태양/은하 홈·허브·일반/지구/플레이어/귀환화살표/체크포인트화살표 렌더 전부)이 하드코딩 반경 대신 이 상수를 참조하도록 교체.
- `make test`(`GAME_HEADLESS=1 GAME_UNIT=1 love .` → `SPACESHIP_UNIT_OK`/`SPACESHIP_SMOKE_OK`), `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:64`, `ASSET_MANIFEST_OK`).
- 토큰 최적화 규칙에 따라 `docs/feedback/INBOX.md`에서 이 항목("내부 해상도를 발라트로 수준으로 상향")을 처리 대기 → 처리 완료로 이동했다(이전 두 슬라이스 로그 포함, 요약 한 항목으로 재작성). 좌표/UI 스케일 요구는 이제 전량 반영되었고, 스프라이트 재생성(별도 항목)도 이미 완료 상태다.

다음 사이클 다음 슬라이스: `docs/feedback/INBOX.md` 처리대기 상단의 다음 최우선 항목("AetherAI 최종 에셋 human-gate 제거"/"ComfyUI로 실제 에셋 작업 진행" — 이펙트/슬롯 심볼/상점 아이콘/배경 등 남은 부분) 또는 "미니맵 은하나선 표기 + 체크포인트 가독성"(사용자 확정, 최우선) 진행. econ/gear 레인 소유 항목(7/8/11/15, 13/9/10/12/14)과 `game/gear.lua`는 건드리지 않는다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
