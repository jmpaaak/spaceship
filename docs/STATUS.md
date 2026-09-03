# STATUS
preflight PASS 진입. INBOX 최우선 항목 「UI 대개편 6건」의 서브항목 1(표본 도감 스트립 제거)을 완료했다.

- `game/scenes/play.lua`에 신규 `M.showSpecimenStrip = false`(named flag, 기존 `M.showLaunchLoadoutTitle` 패턴 재사용 — 데이터 레이어인 `game/collection_store.lua`/`world.specimenCatalog`/`world.specimenKind`의 영구 저장·판정 로직은 전혀 건드리지 않고, 런치 화면의 `self:drawSpecimenStrip(736)` 렌더 호출만 게이팅)를 추가했다. 표본 최초 발견 시 뜨는 "NEW SPECIMEN" 배너(`self.newSpecimenBanner`)는 이 스트립과 무관한 별개 코드 경로이므로 영향받지 않고 그대로 유지된다.
- `game/self_test.lua`에 `PlayScene.showSpecimenStrip == false` 회귀 테스트를 `showLaunchLoadoutTitle` 검증 바로 아래에 추가했다(RED로 플래그 부재를 확인 후 구현 → GREEN).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` → `SPACESHIP_UNIT_OK`/`SPACESHIP_SMOKE_OK`. `make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:79`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 「UI 대개편 6건」 서브항목 1에 완료 표시(✅)와 근거를 기록했다. 나머지 서브항목(2~6)이 아직 미완이므로 상위 항목 자체는 처리 대기에 남아있다(토큰 최적화 규칙 — 완전 완료가 아니므로 이동하지 않음).

다음 사이클 다음 슬라이스: 같은 「UI 대개편 6건」의 서브항목 2("선체 LV.0" 표기 제거, `game/scenes/play.lua`의 `upgrades_line` 두 호출부 제거 — 독립적으로 처리 가능, gear 레인 조율 불필요) 또는 서브항목 4/5/6(오즈텍스트→좌표표시, 탭발사 이펙트 정리, 개발임시본 제거 — 모두 순수 텍스트/렌더 변경, gear 레인 무관) 중 하나를 진행. 서브항목 3(슬롯 카드 그리드)은 `spaceship-gear` 레인의 항목 9/10/13 데이터 구조 완성을 기다려야 하므로 gear 레인 진행 상황을 먼저 확인. econ/gear 레인 소유 항목(7/8/11/15, 13/9/10/12/14)과 `game/gear.lua`는 건드리지 않는다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
