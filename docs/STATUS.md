# STATUS
preflight FAIL(engine tests) fixed this cycle. INBOX 항목 「국제화 누락 + 발라트로식 점수 연출 + HUD 약자 정리 3건」을 완료해 처리 대기에서 처리 완료로 이동했다.

- 이 사이클 진입 시 preflight가 `game/self_test.lua:1390`(distancePunch 회귀 테스트)에서 FAIL이었다. 원인: `game/scenes/play.lua`의 `M:update()`가 `previousBestAltitude`를 매 프레임 `self.expedition.bestAltitude`(현재 값, 즉 이미 갱신된 값)로 지역변수 재계산했기 때문에, 테스트가 `expedition.bestAltitude`를 씬 바깥에서 직접 증가시켜도(실제 상승 중 `expedition.update`가 만드는 것과 동일한 효과) `previousBestAltitude`가 항상 최신값과 같아져 `bestAltitude > previousBestAltitude` 비교가 절대 참이 되지 않았다(신기록 펀치가 발동 안 됨).
- 수정: 신규 필드 `self.lastKnownBestAltitude`(초기값 = `altitudeStore:load()`)를 추가해 프레임 간 상태로 유지하고, `previousBestAltitude`는 이 필드에서 읽으며, `M:update()` 끝에서 `self.lastKnownBestAltitude = self.expedition.bestAltitude`로 갱신한다. 이제 씬 외부(테스트 또는 실제 상승 로직)에서 `bestAltitude`가 오른 다음 프레임에 정확히 감지된다.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` → `SPACESHIP_UNIT_OK`/`SPACESHIP_SMOKE_OK`. `make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:79`, `ASSET_MANIFEST_OK`).
- 이 수정으로 이전 사이클이 uncommitted로 남겨둔 나머지 작업(발라트로식 DIST 펀치 연출 전체 + HUD `HULL` 약자 라벨 교체)도 함께 GREEN이 되어, 해당 INBOX 3건 항목(1/2/3)이 모두 완료됨을 확인했다. `docs/feedback/INBOX.md`에서 이 항목을 처리 대기에서 처리 완료로 이동하고 완료 근거(버그 원인/수정/테스트)를 기록했다(토큰 최적화 규칙).

다음 사이클 다음 슬라이스: `docs/feedback/INBOX.md` 처리대기 상단의 다음 최우선 항목 "UI 대개편 6건"(표본도감 제거/선체LV 표기 제거/슬롯 카드 그리드 UI/슬롯오즈텍스트 제거+좌표표시/탭발사 이펙트 정리/개발임시본 제거) 중 순수 장식 성격이라 독립적으로 처리 가능한 서브항목(1, 2, 4, 5, 6 중 표본도감 제거)부터 슬라이스. 항목 3(슬롯 카드 그리드)은 `spaceship-gear` 레인과 데이터 구조 조율이 필요하므로 gear 레인 진행 상황을 먼저 확인. econ/gear 레인 소유 항목(7/8/11/15, 13/9/10/12/14)과 `game/gear.lua`는 건드리지 않는다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
