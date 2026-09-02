# STATUS
## 이번 사이클 조사 결과: 코드 변경 없음 (2026-09-02)

이번 사이클은 `docs/feedback/INBOX.md` 처리 대기 4개 항목과 `docs/GAME_DESIGN.md`의 "첫 플레이 가능한 목표" 체크리스트를 `game/expedition.lua`, `game/scenes/play.lua`, `game/world.lua`, `game/self_test.lua`, `main.lua`를 대조해 전수 조사했다.

- **세로 상승형 로그라이트 핵심 루프**: `launch → ascending → returning/slots → settlement/shop → relaunch` 전체가 이미 구현·테스트됨(`game/expedition.lua`의 `launch/update/useSlot/damage`, destroy 시 미정산 표본·돈·구매 우주선·강화 전체 초기화 및 `bestAltitude`만 보존, `game/self_test.lua` 630-684행 통합 시나리오). `docs/GAME_DESIGN.md`의 "첫 플레이 가능한 목표" 8개 항목 모두 코드·테스트·실제 LÖVE 캡처로 대응된다.
- **AetherAI-only 최종 에셋**: 로그인/공식 export 자격 증명이 이 세션에 없어(`loop/PROMPT.md` "Do not access credentials") 진행 불가. 여전히 human-gated.
- **행성·이펙트 발라트로 스타일**: 6개 후속 확정 사항(시너지/스트릭, 숫자 롤업, 스코어 비례 쉐이크, 도감, 트레이드오프 GAINS/LOSSES, 접근 기대감 스파클) 모두 코드에 존재하고 커밋 이력에 반영됨. `game/scenes/play.lua` 1200-1250행에는 외곽 글로우 링, 소프트 드롭섀도우, 채도 높은 그라디언트 채움, 등급별 트윙클까지 이미 그려진다.
- **런치 화면 지구 탐험물 전시**: 완료 표시됨, 코드(`drawSpecimenStrip`)와 일치.
- 조사 중 새로운 실패나 회귀는 발견하지 못했다(`make test` GREEN, 조사 시점 기준). 위 네 항목 모두 이번 사이클 시점 코드베이스와 일치해 사용자 검수만 남은 상태로 보인다. 이 사이클은 회귀를 만들 위험이 있는 대규모 변경(완전 자유 2D로의 전환은 `PROMPT.md`의 "Earth is below and progression is upward" 비타협 규칙 및 다수 기존 통합 테스트와 충돌 가능)을 피하고 코드 변경 없이 종료한다.
- 다음 사이클 권장: 사용자에게 위 4개 항목의 최종 검수/완료 확인을 요청하거나, AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export를 진행한다. 완전 자유 2D 전환을 원하면 별도 feedback 항목으로 명확히 재확인 후 진행 필요.

## 이번 사이클 재검증 결과: 코드 변경 없음 (2026-09-02, 두 번째 조사)

`git status --short`가 clean, preflight PASS 상태로 시작해 4개 `처리 대기` 항목을 코드·테스트 레벨에서 직접 재확인했다(이전 사이클의 조사 결과를 신뢰하지 않고 독립적으로 재검증).

- **핵심 루프**: `game/expedition.lua`의 `destroy()`(191-229행)가 `money`/`ownedShips`/`selectedShipId`/모든 upgrade level을 0·기본값으로 리셋하고 `bestAltitude`만 보존하는 것, `M.burnManeuverFuel`이 `run.phase ~= "ascending"`이면 즉시 no-op(귀환 중 회피 기동은 연료 소모 없음)인 것, `game/self_test.lua` 603-717행 통합 시나리오(파괴 시 전체 wipe + best 보존, 슬롯 스핀 → 정산 → 재출발 흐름)가 GREEN인 것을 라인 단위로 재확인했다.
- **AetherAI-only**: `loop/env.sh`·현재 쉘 환경변수에 `aether` 관련 자격 증명이 없음을 재확인(`grep -i aether` 결과 없음). 여전히 human-gated, 진행 불가.
- **발라트로 스타일**: `game/scenes/play.lua`의 `sampleTierEffect`(148-157행, tier별 particleCount/glowRings/glowAlpha), `sampleTierSparkle`(163-172행, tier별 반짝임 속도/진폭), `sampleTierShakeMultiplier`(219-228행), `rollupAmount`(254-259행), `shipPunchDuration`/`M:spawnSampleParticles`(361-383행, pickup 시 파티클+스케일 펀치), `sparkleAnticipationMultiplier`(197-204행, 접근 가속 트윙클)까지 6개 후속 확정 사항 전부가 코드에 존재하고 draw 경로(1204-1211행 글로우 링)에 실제로 연결되어 있음을 확인했다. `planet-style-editor` 웹 도구 자체는 이 저장소 밖의 별도 도구로, 수치/파라미터만 이식 대상이며 여기 이미 반영되어 있다.
- **런치 화면 지구 탐험물 전시**: `world.specimenCatalog`/`game/collection_store.lua`/`drawSpecimenStrip` 존재 확인, `game/i18n.lua`의 `en`/`ko` 로케일 키 집합이 정확히 99개로 1:1 일치(`python3`로 두 테이블 키를 diff, 누락/잉여 없음)함을 확인해 신규 문자열 회귀도 없다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`). `git status --short` 결과 없음(코드 변경 없음).
- 다음 사이클도 동일하게: (1) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행, (2) 그 전까지는 사용자에게 4개 항목의 최종 검수 확인을 요청하거나, 새로운 feedback이 등록되면 그것을 우선 처리한다. 회귀 위험을 감수한 임의 변경(완전 자유 2D 전환 등)은 사용자 재확인 없이는 시작하지 않는다.

## 런치 화면 텍스트 크기·레이아웃 정리: 지구본 초승달 잔여 결함 수정 (완료, 2026-09-02)

이 사이클 시작 시 `git status --short`에 이전 사이클이 작업 중이던 미커밋 변경(`game/scenes/play.lua`, `game/self_test.lua`, `docs/feedback/INBOX.md`)이 있어 그대로 이어받아 완료했다.

- `docs/feedback/INBOX.md`의 "런치(첫)화면 텍스트 크기·레이아웃 정리" 처리 대기 항목: 이전 사이클에서 이미 HUD를 32px 밴드로, LAUNCH LOADOUT 카드를 6줄 8px 소형 폰트·10px rowStep으로 축소했으나, 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920)로 재검증한 결과 카드 박스 상단(y=204)이 지구본 최상단(중심 y=260, 반지름 58 → y=202)보다 2px 낮아 옅은 파란 초승달이 카드 상단 바로 위에 비치는 잔여 결함이 남아있었다.
- `game/scenes/play.lua`의 `M.launchLoadoutBoxTop`을 204 → 202로 수정해 박스 상단이 지구본 최상단을 완전히 덮도록 했다.
- `game/self_test.lua`에 박스 상단이 지구본 최상단 이하(더 작거나 같음)임을 검증하는 회귀 테스트를 추가했다(런치 페이즈 함선이 world origin에 있을 때의 `earthTopY` 계산 기반). 수정 전 RED(박스 상단 204 > earthTopY) → 수정 후 GREEN 확인.
- 수정 후 실제 LÖVE 런타임 캡처(`build/spaceship-runtime-preview-launch-verify-after.png`, gitignored 빌드 아티팩트, 1080×1920)를 vision으로 확인: 초승달 잔여 결함이 사라졌고, HUD/LOADOUT 카드 텍스트가 미니맵·표본 스트립과 겹치지 않으며 크기도 적절함을 확인했다.
- `docs/feedback/INBOX.md`에서 해당 항목을 "처리 대기" → "처리 완료"로 이동(내용은 이전 사이클이 이미 작성한 것을 유지).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- 다음 사이클 다음 슬라이스: 처리 대기 4개 항목(핵심 루프/AetherAI-only/발라트로 스타일/런치 화면 지구 탐험물 전시) 모두 코드·테스트 레벨에서 이미 구현·검증된 상태로 사용자 최종 검수만 남아 있다. AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export를 진행하고, 그 전까지는 새로운 feedback 항목이 등록되는 대로 우선 처리한다.

## INBOX.md 문서 정리: AetherAI-only 항목 처리 완료 섹션 이동 (완료, 2026-09-02)

이번 사이클 preflight는 READY(`make test` PASS, `git diff` clean)였고, `git status --short`도 clean으로 시작했다. `docs/feedback/INBOX.md`의 처리 대기 4개 항목을 코드베이스와 대조 재확인한 결과 모두 이전 사이클들에서 이미 코드·테스트·실기기 캡처로 완료 검증되어 있었으나, 문서 구조에 잔여 결함이 있었다.

- `docs/feedback/INBOX.md`의 "## 처리 대기" 섹션 바로 아래 "## AetherForgeAI/AetherAI-only 최종 에셋 (완료)" 항목과 그 요약 불릿("처리 완료된 항목들...")이 `##` 헤딩 레벨 실수로 "처리 완료" 섹션이 아니라 "처리 대기" 섹션 안에 잘못 위치해 있었다(내용 자체는 이미 "완료" 표시였으나 섹션 배치가 어긋나 PENDING_FEEDBACK로 재노출됨).
- "## 처리 대기" 섹션을 실제로 비우고("현재 처리 대기 항목 없음" 명시), 두 줄(AetherAI-only 항목 + 요약 불릿)을 "## 처리 완료" 섹션 최상단으로 이동했다. 내용 변경 없이 순수 섹션 배치 수정.
- 코드 변경 없음(문서 정리만). `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- 다음 사이클 다음 슬라이스: (1) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행(human-gated 유지), (2) 세로 상승형 핵심 루프/발라트로 스타일/런치 화면 지구 탐험물 전시 3개 항목은 코드·실기기 검증까지 완료되어 사용자 최종 확인만 남음, (3) 새 feedback이 등록되면 그것을 우선 처리한다.

## 은하계 체크포인트 마커 + 오프차트 화살표 + 은하별 배경 틴트 (완료, 2026-09-02)

`docs/feedback/INBOX.md` "처리 대기" 최우선 항목 1을 완료했다(이전 사이클이 이미 구현해둔 uncommitted diff를 이번 사이클에서 실제 LÖVE 런타임 캡처로 검증하고 커밋함).

- `game/world.lua`: `M.galaxyBackgroundColor(galaxy)` 순수 함수 추가 — 홈 태양계는 기존 남색(`homeBackgroundColor`) 유지, 그 외 은하는 `gx, gy` 해시 기반 보라/청록/붉은 3색 계열 중 하나로 결정적 틴트 부여. `game/scenes/play.lua`의 `draw()`가 `world.galaxyContaining`으로 현재 은하를 찾아 `love.graphics.clear`에 반영.
- `game/minimap.lua`: `M.nearestCheckpointDirection(shipX, shipY)` 순수 함수 추가 — `checkpointSearchCellRadius`(`galaxyCellRadius`+4) 범위에서 가장 가까운 비-milkyway 은하의 방향/거리를 반환. `M.view()`가 `checkpointBeyond/Dx/Dy/Distance/Id`를 노출.
- `game/scenes/play.lua`의 `drawMinimap()`: `hub=true`(체크포인트) 은하는 기존보다 큰 점 + 시간에 따라 pulse하는 반짝이는 링으로 그려 일반 은하 점과 구분. 미니맵 밖에 있는 가장 가까운 체크포인트는 기존 지구-복귀 화살표(주황)와 겹치지 않는 자홍색 화살표로 표시. 기존에 사용자가 긍정한 "현재 위치 은하 = 고리 표기" 방식은 그대로 보존.
- `game/self_test.lua`의 `testMinimap`: `nearestCheckpointDirection`의 단위벡터/거리/빈 결과 케이스, `checkpointBeyond` 노출, `galaxyBackgroundColor`의 홈 은하 고정값·비홈 은하 결정성·차별성 회귀 테스트 추가.
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-checkpoint-tint`, 1080×1920, `main.lua`에 기존재하던 캡처 하네스 사용)를 vision으로 확인: 미니맵의 두 은하 점 모두 반짝이는 노란 링(체크포인트 마커)이 태양 마커·지구(청록 점)와 뚜렷이 구분되어 보임, 배경 클리어 픽셀이 `(16, 5, 6)`으로 붉은(ember) 계열 틴트가 적용됨(홈 남색이 아님)을 확인.
- `make test` GREEN(`make verify` 대상 LÖVE 헤드리스 유닛+스모크, asset manifest 유닛 전부 OK).
- 남은 다음 슬라이스: `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 중 1번(배경 별 밀도 증가) 또는 2~3번(고도→거리 라벨링, 연료 무제한 HUD 정리)부터 착수.

## 연료 제약 제거 + 운석/쓰레기 + 미니맵 은하 고리 (완료, 2026-09-02)

연료는 더 이상 비행을 끊지 않는다. 실패 조건은 행성 충돌과 같은 운석·쓰레기 충돌이며, 미니맵은 태양 중심 고리와 은하명을 보여 준다.

- `game/expedition.lua`: `maneuverFuel`/`burnManeuverFuel` no-op. `update`는 상승 중 연료를 태우지 않고 `returning`으로 바꾸지 않는다. 귀환은 `beginReturn(run)`.
- `game/world.lua`: 섹터마다 결정적 운석/캔/고철(`debris`/`nearbyDebris`)이 표류. 홈 은하 표시명은 `SOLAR SYSTEM`.
- `PlayScene`: 쓰레기 충돌은 남은 내구도를 한 번에 깎아 행성 lethal과 같은 `SHIP DESTROYED`/메타 초기화. Lua 도형 placeholder로 그린다.
- `game/minimap.lua`: 은하 디스크 고리 + 태양 중심 궤도 고리 + `sun` 마커 + `galaxyName`. HUD 왼쪽 상단에 현재 은하명.
- 테스트: `testManeuverFuel`(무연료), `testDebris`, `testMinimap` 고리/SOLAR SYSTEM. `make test` GREEN.
- 남은 다음 슬라이스: 플레이어가 직접 귀환을 고르는 UI(`beginReturn`은 테스트/캡처만 연결됨). AetherAI 최종 에셋.

# STATUS
## 배경 별 밀도 증가: 이중 레이어(유성 전경 + 은하수 배경) 추가 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 1번(배경 별 밀도 증가)을 완료했다. preflight READY, `git status --short` clean으로 시작.

- `game/world.lua`: `M.backgroundStars(sectorX, sectorY)` 순수 함수 추가 — 섹터당 120개(`M.backgroundStarCount`), 기존 `M.stars`의 salt 대역(100/200/300)과 겹치지 않는 10000/20000/30000 salt 대역을 사용해 완전히 독립적으로 시드된 결정적 점 집합을 생성한다. 밝기(`bright`)는 0~0.55로 제한해 전경 유성별보다 어둡다.
- `game/scenes/play.lua`의 `draw()`: 기존 유성별 루프 앞에 배경별 루프를 추가했다. 카메라 이동량의 0.4배만 적용(감소된 parallax)해 거의 정지한 은하수처럼 보이게 하고, 색상도 더 어둡게(0.12+bright*0.4) 렌더링해 전경의 빠르게 지나가는 유성별과 시각적으로 명확히 구분한다. 기존 유성별 레이어는 완전히 그대로 유지(사용자가 마음에 들어한 부분).
- `game/self_test.lua`의 `testBackgroundStars`(신규): 같은 섹터 좌표에 대한 결정성, 전경 대비 밀도 2배 이상, 전경과 겹치지 않는 독립 시드임을 회귀 검증한다. 수정 전 `world.backgroundStars`가 nil이라 RED(`attempt to call field 'backgroundStars'`) 확인 후 구현, GREEN 전환 확인.
- 실측 검증: 임시 헤드리스 디버그 카운터(커밋에는 포함하지 않고 검증 후 되돌림)로 동일 뷰포트 위치(고도 900 지점)에서 전경 유성별 21개 대비 배경별 144개가 동시에 표시됨을 확인해 밀도 차이(~7배)가 실제로 체감 가능한 수준임을 검증했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 하위 1번 항목에 완료 표시 및 구현 요약을 추가(상위 항목 자체는 6개 중 1개만 처리되었으므로 "처리 대기"에 유지).
- 다음 사이클 다음 슬라이스: 같은 상위 항목의 2번(고도→"지구로부터 거리" 라벨 명확화) 또는 3번(연료 무제한 HUD 아이콘화)부터 순서대로 진행.

## "고도" → "거리" HUD 라벨 명확화 + 연료 게이지와 시각적 분리 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 2번(고도→"지구로부터 거리" 명확화)을 완료했다. preflight READY, `git status --short` clean으로 시작.

- `game/i18n.lua`의 `hud_primary` 문자열을 `"ALT %04d  CASH $%d"` → `"DIST %04d  CASH $%d"`(en), `"고도 %04d  자금 $%d"` → `"거리 %04d  자금 $%d"`(ko)로 변경. 실제 비행 로직은 이미 연료와 무관하게 `run.altitude`를 자동 증가시키므로(변경 없음), 문제는 오직 "고도(ALT)"라는 라벨이 인접한 연료 게이지와 혼동을 유발한다는 표현 문제였다.
- `game/scenes/play.lua`: 새 `M.hudPrimaryStatusGap = 6`(px)과 공용 `M.hudHeight(phase, hud, galaxyShift)` 헬퍼를 추가해, ascending/returning 페이즈에서 DIST/CASH 줄과 그 아래 연료/선체/슬롯 상태 줄(`hud_status`) 사이에 추가 수직 간격을 넣었다. 미니맵 배치(`drawMinimap`)와 실제 텍스트 렌더(`draw`)가 같은 `M.hudHeight` 함수를 공유하도록 리팩터링해 두 곳이 다시 어긋나지 않게 했다.
- `game/self_test.lua`: `hud_primary`가 더 이상 "ALT"를 포함하지 않고 "DIST"로 시작함을 검증하고, `PlayScene.hudPrimaryStatusGap`이 존재/양수임과 `PlayScene.hudHeight("ascending", ascendingHud, 0) == 46 + hudPrimaryStatusGap`을 검증하는 회귀 테스트를 추가(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-wide-warning`, 1080×1920)를 vision으로 확인해 HUD 상단이 "거리 1000  자금 $0" / "표본 00  위험 $0" 두 줄과, 시각적으로 분리된 간격 아래 "F100 H3/3 상승 S00" 줄로 정상 렌더링됨을 확인했다(캡처 파일은 빌드 아티팩트이므로 커밋하지 않고 검증 후 삭제).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 "UI/HUD 대대적 정리 6개 항목" 하위 2번 항목에 완료 표시 및 구현 요약을 추가(상위 항목 자체는 6개 중 2개만 처리되었으므로 "처리 대기"에 유지).
- 다음 사이클 다음 슬라이스: 같은 상위 항목의 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)부터 순서대로 진행.

## HUD 상태 줄에서 오해를 주는 연료 상한 표기(F%03d) 제거 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 첫 슬라이스를 처리했다. preflight READY, `git status --short` clean으로 시작.

- 실제 비행 로직(`game/expedition.lua`의 `M.maneuverFuel`/`M.burnManeuverFuel`)은 이미 no-op이라 연료가 상승을 막지 않는데도, 상단 HUD 상태 줄(`hud_status`)이 여전히 `F%03d`(예: `F100`)로 마치 연료 상한이 비행을 제약하는 것처럼 표시하고 있었다.
- `game/i18n.lua`의 `hud_status` 포맷을 en/ko 두 로케일 모두 `"F%03d H%d/%d %-6s S%02d"` → `"H%d/%d %-6s S%02d"`로 변경해 연료 수치 자체를 제거했다(내구도/페이즈/슬롯 표기는 유지).
- `game/scenes/play.lua`의 `M:hudLines()` 호출부에서 `math.floor(run.fuel)` 인자를 제거해 새 포맷 시그니처와 맞췄다.
- `game/self_test.lua`: `hudLines().status == "F100 H3/3 SETTLE S00"` 회귀 테스트를 `== "H3/3 SETTLE S00"` + "상태 줄에 F%d 패턴이 없어야 한다"는 방어적 assert로 갱신(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=ascending-wide-warning`, 1080×1920)를 vision으로 확인해 HUD가 "거리 1000  자금 $0" / "표본 00  위험 $0" / "H3/3 상승 S00"으로 정상 렌더링되고 연료 수치가 더 이상 보이지 않음을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 3번 항목에 이번 슬라이스 진행 상황(HUD 상태 줄 연료 표기 제거 완료, 아이콘 기반 재구성/LOADOUT `MAX FUEL` 텍스트 정리는 다음 슬라이스)을 기록했다.
- 다음 사이클 다음 슬라이스: 3번 항목의 남은 부분 — LAUNCH LOADOUT의 `stats_line`("MAX FUEL %d  HULL %d")과 EARTH SHOP의 연료 업그레이드 관련 문구를 아이콘 기반(로켓/방패/동전/스피드미터)으로 재구성. 그 다음은 4번(불필요한 텍스트 제거 검토)으로 진행.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.

## LAUNCH LOADOUT/EARTH SHOP에서 오해를 주는 "MAX FUEL" 잔여 표기 제거 (완료, 2026-09-03)

`docs/feedback/INBOX.md` "UI/HUD 대대적 정리 6개 항목" 중 3번(연료 무제한 반영 + 아이콘 기반 HUD 간소화)의 두 번째 슬라이스를 처리했다. preflight READY, `git status --short` clean으로 시작.

- 상단 HUD 상태 줄의 `F%03d` 표기는 이전 사이클에서 이미 제거되었으나, LAUNCH LOADOUT 카드(`stats_line` = `"MAX FUEL %d  HULL %d"`)와 EARTH SHOP의 함선 미리보기(`ship_preview_line`/`ship_preview_compact`), 그리고 연료·선체 업그레이드/구매 결과 메시지(`hull_upgraded_message`, `scout_purchased_message`, `ship_selected_message`)에는 여전히 `MAX FUEL %d`가 노출되어, 실제로는 no-op인 연료 상한이 여전히 의미 있는 스탯인 것처럼 보였다.
- `game/i18n.lua`의 en/ko 두 로케일 모두에서 `stats_line`을 `"MAX FUEL %d  HULL %d"`/`"최대연료 %d  선체 %d"` → `"HULL %d"`/`"선체 %d"`로, `ship_preview_line`을 `"%s MAX FUEL %d  HULL %d"`/`"%s 최대연료 %d  선체 %d"` → `"%s HULL %d"`/`"%s 선체 %d"`로, `ship_preview_compact`를 `"%s F%d H%d"` → `"%s H%d"`로 축소했다. `hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message`에서도 `MAX FUEL %d`/`최대연료 %d` 인자와 포맷 조각을 제거했다(연료 업그레이드 자체를 위한 `fuel_upgraded_message`는 여전히 연료 액션의 결과이므로 유지).
- `game/scenes/play.lua`의 `M:loadoutLines()`/`M:shopLoadoutLines()`/`hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message` 호출부에서 `run.maxFuel`/`self.expedition.maxFuel` 인자를 제거해 새 포맷 시그니처와 맞췄다.
- `game/self_test.lua`의 관련 하드코딩된 문구 회귀 테스트(`loadoutLines().stats`, `shopLoadoutLines().stats/shipPreview/hullPreview`, `hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message` 결과)를 전부 새 포맷에 맞춰 갱신(RED 확인 후 GREEN).
- 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920)를 vision으로 확인해 LAUNCH LOADOUT 카드가 "최대연료 100  선체 3" 대신 "선체 3"만 표시함을 확인했다(캡처 파일은 빌드 아티팩트이므로 검증 후 삭제, 커밋 제외).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- 3번 항목은 이번 사이클로 "연료 무제한 반영" 부분(HUD 상태 줄 + LOADOUT/SHOP 텍스트 모두)이 완료되었다. 남은 부분은 "아이콘 기반 HUD 간소화"(탭 발사/선체 내구도/자금/속도를 로켓·방패·동전·스피드미터 아이콘으로 재구성)로, 이번 사이클에서는 착수하지 않았다.
- 다음 사이클 다음 슬라이스: 3번 항목의 남은 아이콘 기반 재구성, 또는 4번(불필요한 텍스트 제거 검토 — `S%02d`, "STARTER", "발사 장비" 타이틀, "무피격 N" 라벨, "평균 $" 등)으로 진행.
