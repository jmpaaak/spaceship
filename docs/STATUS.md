# STATUS
preflight PASS 진입. INBOX 최우선 항목 「UI 대개편 6건」의 서브항목 2("선체 LV.0" 표기 제거)를 완료했다.

- `game/scenes/play.lua`의 `M:loadoutLines()`/`M:shopLoadoutLines()`에서 `upgrades = i18n.t("upgrades_line", run.durabilityUpgradeLevel)` 필드를 완전히 제거했다. 이를 소비하던 LAUNCH LOADOUT 카드(`loadout.upgrades`), EARTH SHOP NEXT LAUNCH 프리뷰(`nextLaunch.upgrades`), destroyed 화면(`loadout.upgrades`) 3곳의 렌더 호출부(printf + rowStep 소비)도 함께 삭제했다.
- `game/i18n.lua`에서 이제 어디서도 참조되지 않는 `upgrades_line` 키(en `"HULL LV.%d"`/ko `"선체 LV.%d"`)도 제거했다. HULL n(수치) 자체는 `stats_line`("HULL 3"/"선체 3")으로 이미 표시 중이므로 정보 손실은 없다. 좌상단 선체 내구도 상시 표시(사용자가 원하는 최종 위치)는 서브항목 3(슬롯 카드 그리드)과 함께 배치될 예정이며 이번 슬라이스 범위는 아니다.
- `game/self_test.lua`의 8개 회귀 단언(`starterLoadout.upgrades`, `upgradedLoadout.upgrades`, `resetLoadout.upgrades`, `starterNextLaunch.upgrades`, `fueledNextLaunch.upgrades`, `reinforcedNextLaunch.upgrades`, `scoutNextLaunch.upgrades`, `reselectedNextLaunch.upgrades`)를 `== nil`로 갱신했다(RED로 필드 존재를 먼저 확인 후 구현 → GREEN).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` → `SPACESHIP_UNIT_OK`/`SPACESHIP_SMOKE_OK`. `make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:79`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 「UI 대개편 6건」 서브항목 2에 완료 표시(✅)와 근거를 기록했다. 나머지 서브항목(3~6)이 아직 미완이므로 상위 항목 자체는 처리 대기에 남아있다(토큰 최적화 규칙 — 완전 완료가 아니므로 이동하지 않음).

다음 사이클 다음 슬라이스: 같은 「UI 대개편 6건」의 서브항목 4("C50 P40 S10" 오즈 텍스트 제거 + 우주선 좌표 미니맵 근처 표시), 5(탭발사 이펙트 정리 — 노란 화살표 제거 + 절제된 유도 이펙트), 6("개발 임시본" 문구 완전 제거) 중 하나를 진행 — 모두 순수 텍스트/렌더 변경으로 gear 레인 조율이 필요 없다. 서브항목 3(슬롯 카드 그리드)은 `spaceship-gear` 레인의 항목 9/10/13 데이터 구조 완성을 기다려야 하므로 gear 레인 진행 상황을 먼저 확인해야 한다. econ/gear 레인 소유 항목(7/8/11/15, 13/9/10/12/14)과 `game/gear.lua`는 건드리지 않는다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
