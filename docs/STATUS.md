# STATUS
preflight PASS 진입. INBOX 최우선 항목 「UI 대개편 6건」의 서브항목 4("C50 P40 S10" 슬롯 오즈 텍스트 제거 + 우주선 좌표 미니맵 근처 표시)를 완료했다.

- `game/scenes/play.lua`에서 `M:slotOddsLine()`(및 그 문자열을 반환하던 `loadoutLines().odds`/`shopLoadoutLines().odds` 필드, `drawMinimap()`의 returning-phase 전용 오즈 렌더, LAUNCH LOADOUT/EARTH SHOP NEXT LAUNCH 화면의 `loadout.odds`/`nextLaunch.odds` printf 소비부)를 전량 제거했다. `game/i18n.lua`의 이제 참조되지 않는 `slot_odds_line` en/ko 키도 제거했다.
- 대신 신규 순수 함수 `M.shipCoordsLine(x, y)`(`"(%d, %d)"` 포맷, 사칙 반올림)를 추가했다. `drawMinimap()`이 이제 미니맵을 그리는 모든 활성 페이즈(launch/ascending/returning — settlement/destroyed는 기존처럼 조기 반환)에서 미니맵 옆에 작은 8px 우측정렬 텍스트로 `self.ship.x, self.ship.y`를 상시 표시한다(기존 오즈 줄과 같은 위치/폰트/예약 공간 `hudOddsLineHeight` 재사용, 겹침 없음).
- `game/self_test.lua`에 `PlayScene.slotOddsLine == nil`(API 완전 제거 확인), `loadoutLines()/shopLoadoutLines()`의 `odds` 필드 부재, `shipCoordsLine`의 포맷/반올림(음수 좌표, 0 근처 부호 없는 반올림 포함) 회귀 테스트를 추가했다(RED으로 구필드/구함수 존재를 먼저 확인 후 구현 → GREEN).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` → `SPACESHIP_UNIT_OK`/`SPACESHIP_SMOKE_OK`. `make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:79`, `ASSET_MANIFEST_OK`).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=returning-odds`, `~/Library/Application Support/LOVE/spaceship/spaceship-runtime-preview.png`)로 미니맵 우측 상단 영역에 렌더 내용(픽셀 다양성 5182색)이 실재함을 결정적으로 확인했다(정책상 비전 모델 검토는 생략, 픽셀 다양성으로 대체 검증).
- `docs/feedback/INBOX.md`의 「UI 대개편 6건」 서브항목 4에 완료 표시(✅)와 근거를 기록했다. 나머지 서브항목(3, 5, 6)이 아직 미완이므로 상위 항목 자체는 처리 대기에 남아있다(토큰 최적화 규칙 — 완전 완료가 아니므로 이동하지 않음).

다음 사이클 다음 슬라이스: 같은 「UI 대개편 6건」의 서브항목 5("탭하여 발사" 유도 이펙트 정리 — 노란 화살표 제거 + 절제된 sine 기반 미세 이펙트) 또는 6("개발 임시본" 문구 완전 제거 — 조건부 렌더 자체 삭제) 중 하나를 진행 — 둘 다 순수 텍스트/렌더 변경으로 gear 레인 조율이 필요 없다. 서브항목 3(슬롯 카드 그리드)은 `spaceship-gear` 레인의 항목 9/10/13 데이터 구조 완성을 기다려야 하므로 gear 레인 진행 상황을 먼저 확인해야 한다. econ/gear 레인 소유 항목(7/8/11/15, 13/9/10/12/14)과 `game/gear.lua`는 건드리지 않는다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
