# STATUS
## 데스크톱 마우스 조이스틱 + settlement 메시지 i18n 이관 인계 완료 (이전 사이클 미완성 인계)

- 이전 사이클이 `game/scenes/play.lua`/`game/self_test.lua`/`main.lua`에 검증된 GREEN 변경을 워킹트리에 남긴 채 커밋을 완료하지 못하고 종료했다(preflight `git diff` 검사 PASS로 인계됨). 이번 사이클이 그 변경을 이어받아 커밋했다.
- `main.lua`에 `love.mousepressed/mousemoved/mousereleased`를 추가해 데스크톱 `love .` 플레이 시 마우스 드래그가 `"mouse"` touch id로 `PlayScene`의 조이스틱 경로를 그대로 탄다(모바일 터치와 중복 처리되지 않도록 `istouch`는 무시). 좌표는 `clampToCanvas`로 180x320 캔버스 안으로 clamp해 고dpi 레터박스 반올림으로 드래그가 캔버스 밖으로 튕겨 유실되지 않게 했다.
- `game/scenes/play.lua`에 `M:joystickKnob()`(활성 조이스틱 중심/노브 좌표 반환)과 `M:drawJoystickStick()`(상승/귀환 phase에 반투명 스틱 UI 렌더)를 추가했고, `M:pollDesktopMouse()`로 `love.mousepressed` 이벤트를 놓친 경우를 매 프레임 폴백 보정한다(`GAME_UNIT=1`에서는 스킵해 주입된 테스트 터치가 지워지지 않게 함). `steeringButtonState()`에 키보드 상/하(`up`/`down`, `w`/`s`)를 추가해 수직 `verticalOffset`도 키보드로 조종 가능해졌다.
- 기존 `string.format` 인라인 메시지 다수(슬롯 결과, 귀환/정산/충돌/파괴/업그레이드/구매/선택 메시지, 신규표본 배너, 플로팅 텍스트)를 `game/i18n.lua`의 `i18n.t(key, ...)` 호출로 교체해 로케일 분기 없이도 문자열이 `locales.en`/`locales.ko` 양쪽에서 일관되게 나오도록 정리했다(`assets/fonts/AppleGothic.ttf` 번들 폰트를 쓰는 `game/fonts.lua`와 함께, 한글 로케일 지원 인프라 완결).
- engine-hosted 테스트(`testJoystick()`)가 데스크톱 마우스 press→drag→release 시나리오에서 `joystickKnob()`이 드래그 전 nil, 드래그 후 노브 좌표 반환, `update(1)` 후 `ship.x` 증가, release 후 다시 nil이 되는 것을 검증한다.
- 남아있던 인라인 문자열(`"SHIP DESTROYED"`, `"HOLD LEFT"`, `"DEV PLACEHOLDER"`)도 각각 `i18n.t("ship_destroyed_title")`/`i18n.t("hold_left")`/`i18n.t("dev_placeholder")`로 교체해 이번 마이그레이션을 매듭지었다(`"HOLD RIGHT"`는 별도 `hold_right` 키가 이미 있으나 아직 인라인 — 다음 사이클 후보로 남김).
- `make test`, `GAME_HEADLESS=1 GAME_UNIT=1 love .` 모두 GREEN. `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- 남은 다음 슬라이스 후보: (1) `"HOLD RIGHT"` 인라인 문자열도 `i18n.t("hold_right")`로 마저 교체, (2) YIELD/SHIP/HULL/STEERING 터치 행과 텍스트 줄의 느슨한 y 정렬을 더 타이트하게 정리(직전 완료 사이클로 이미 처리된 항목 여부 재확인 필요), (3) 낮은 잔액 `SHORT $N` 실기기 재검증, (4) AetherAI-only 최종 에셋(공식 로그인/export 가용성) 확인.

## SCOUT 트레이드오프를 GAINS/LOSSES 포맷으로 통일 (완료, 이전 사이클 미완성 인계)

- 이전 사이클(cycle 7)이 `game/expedition.lua`/`game/scenes/play.lua`/`game/self_test.lua`에 검증된 GREEN 변경을 워킹트리에 남긴 채 `docs/STATUS.md` 갱신과 커밋을 완료하지 못하고 종료했다. 이번 사이클이 preflight `git diff` 검사를 통과한 그 변경을 이어받아 완료했다. `docs/feedback/INBOX.md` 발라트로 이식 목록 5번(선택 안의 트레이드오프)을 처리한다: 기존 SCOUT 배의 `SCOUT +40 FUEL / -1 HULL` 단일 문자열을 `planet-style-editor` 도구의 GAINS/LOSSES 수치 행 포맷과 통일했다.
- `game/expedition.lua`에 `M.shipTradeoff(run, shipId)`를 추가해 `{gains = {{label="FUEL", value="+40"}}, losses = {{label="HULL", value="-1"}}}` 형태로 반환한다(`planet-style-editor/src/planets.js`의 `style.gains`/`style.losses`와 같은 라벨+부호 값 모양). `game/scenes/play.lua`에 `M.scoutTradeoffLines(run)`을 추가해 `"SCOUT GAINS +40 FUEL"`/`"LOSSES -1 HULL"` 두 줄로 표시한다. 결합 단일 줄(176px, `GAME_FONTPROBE=1`로 실측)이 148px 상점 전체 폭 컬럼(폰트 크기 7에서도 154px)을 초과해 두 줄 분리가 필요했다. `shopLoadoutLines().scoutTradeoff`가 기존 문자열 대신 이 2원소 테이블을 반환한다.
- engine-hosted 테스트가 STARTER/SCOUT 두 next-launch 시나리오에서 `scoutTradeoff[1] == "SCOUT GAINS +40 FUEL"`, `scoutTradeoff[2] == "LOSSES -1 HULL"`을 검증한다.
- 이번 사이클에서 추가 검증한 결함: SCOUT 트레이드오프가 2줄로 늘어나며 EARTH SHOP 패널 총 줄 수가 19→20줄로 늘었는데, 기존 `rowStep=9`를 그대로 유지한 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1440×2560`)에서 `TAP: RELAUNCH`가 `DEV PLACEHOLDER` 푸터(y=307)와 겹치는 실제 렌더링 결함을 vision으로 발견했다(`build/spaceship-runtime-preview-tradeoff-check.png`, 로컬 산출물로 커밋 제외). `game/scenes/play.lua`의 `rowStep`을 `9`→`8`로 좁혀 마지막 줄이 `y=140+19*8=292`에 오도록 고쳤다.
- 수정 후 재캡처한 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-newbest`, `1440×2560`)로 `SCOUT GAINS +40 FUEL`/`LOSSES -1 HULL` 두 줄을 포함한 20줄 전체가 겹침·잘림 없이 표시되고 `TAP: RELAUNCH`가 `DEV PLACEHOLDER` 위에 정상 배치되는 것을 vision으로 확인했다(`build/spaceship-runtime-preview-tradeoff-fixed.png`, 로컬 산출물로 커밋 제외).
- `make test`, `GAME_HEADLESS=1 GAME_UNIT=1 love .` 모두 GREEN. `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:25`).
- `docs/feedback/INBOX.md` 발라트로 핵심 게임성 이식 목록(1~6번) 전체가 이제 완료됐다.
- 남은 다음 슬라이스 후보: (1) 낮은 잔액 상태의 `SHORT $N` 분기를 실제 캡처로 추가 확인, (2) YIELD/SHIP/HULL/STEERING 터치 행과 텍스트 줄의 느슨한 y 정렬을 더 타이트하게 정리, (3) AetherAI-only 최종 에셋(공식 로그인/export 가용성) 확인.

## EARTH SHOP `SHORT $N` 재검증 (레이아웃 변경 이후, 완료)

- `SCOUT GAINS/LOSSES` 트레이드오프가 2줄로 분리되며 EARTH SHOP `rowStep`이 9→8로 좁혀진 것(직전 슬라이스)이 이전에 검증된 `GAME_CAPTURE_PHASE=settlement-shortfunds`(`SHORT $N` 5행 분기) 캡처를 무효화했을 가능성이 있어 이번 사이클에서 재검증했다. 코드 변경 없이 실제 LÖVE runtime capture(`GAME_CAPTURE_PHASE=settlement-shortfunds`, `1440×2560`)를 새 `rowStep=8`·20줄 레이아웃 기준으로 다시 촬영했다.
- vision으로 `SHORT $50`(FUEL)·`SHORT $75`(HULL)·`SHORT $65`(STEERING)·`SHORT $60`(YIELD)·`SHORT $125`(SCOUT) 다섯 상태 문자열 전부가 한 줄로 줄바꿈 없이 렌더링되고 위·아래 행(`NO-HIT`/`MAX FUEL`/`STEER SPEED`/`YIELD x`/`SCOUT GAINS`/`NEXT STARTER` 등)과 겹치지 않으며, `TAP: RELAUNCH`가 `DEV PLACEHOLDER` 위에 정상 배치되는 것을 확인했다(로컬 캡처, `build/` 는 커밋 제외).
- `main.lua`의 `GAME_FONTPROBE=1` 진입 경로에 향후 재사용을 위한 컬럼-분할 축약 액션 문자열(`H:LV.n>n+1 $75`, `V:BUY $125` 등) 측정 샘플을 추가했다가, 이번 사이클에서는 실제 레이아웃 변경 없이 되돌렸다(측정값만 확인: 축약 액션 문자열은 47~63px로 90px 컬럼 폭 안에 여유 있게 들어감 — 다음 슬라이스의 (2)번 정렬 정리 시도에 참고).
- `make test` GREEN, 워킹트리 변경 없음(`git status --short` 결과 없음). 코드 로직 변경이 없어 `make verify`는 이전 커밋(`4ac4019`)의 통과 상태를 그대로 유지한다.
- 남은 다음 슬라이스 후보: (1) YIELD/SHIP/HULL/STEERING 터치 행과 텍스트 줄의 느슨한 y 정렬을 더 타이트하게 정리(축약 액션 문자열 측정값 확보됨, 컬럼별 좌우 분할 시도 시 실기기 캡처로 겹침 여부 반드시 재확인), (2) AetherAI-only 최종 에셋(공식 로그인/export 가용성) 확인 — 이번 사이클에도 공식 AetherAI 로그인/API 자격 증명을 찾지 못해(`env`/워크스페이스 전체 검색, 크리덴셜 없음) human-gated 상태를 유지했다.

## YIELD/SHIP/HULL/STEERING 컬럼 정렬 정리 (진행 중 — 데이터 준비 완료, draw 배치는 다음 사이클로 이관)

- 이전 두 사이클이 되돌린 "YIELD/SHIP/HULL/STEERING 터치 행과 텍스트 줄의 느슨한 y 정렬 정리"를 다시 시도했다. 지난 되돌림의 근본 원인(HULL/STEERING·YIELD/SHIP처럼 90px 컬럼을 좌우로 공유하는 두 항목의 기존 액션 문자열이 각각 91~97px로 90px 컬럼 폭을 초과해 좌우로 나란히 배치할 수 없었음)을 `GAME_FONTPROBE=1` 측정으로 재확인한 뒤, 기존 전체 폭 문자열(`hullAction`, `steeringAction`, `yieldAction`, `shipAction`)은 건드리지 않고 컬럼 폭 안에 들어가는 축약 버전을 `game/scenes/play.lua`의 `shopLoadoutLines()`에 새 필드로 추가했다: `hullActionCompact`(`"H:LV.n>n+1 $75"`, 58~63px), `steeringActionCompact`(`"G:LV.n>n+1 $65"`, 58~63px), `yieldActionCompact`(`"Y:LV.n>n+1 $60"`, 57~62px), `shipActionCompact`(`"V:BUY $125"`/`"V:STARTER"`/`"V:SCOUT"`, 38~49px), `hullPreviewCompact`(`"HULL n"`), `steeringPreviewCompact`(`"SPD n"`) 모두 90px 컬럼 폭에 여유 있게 들어간다(`GAME_FONTPROBE=1` 실측). `game/scenes/play.lua`에 `shopColumnLeftX/shopColumnLeftW`(16, 68)와 `shopColumnRightX/shopColumnRightW`(88, 68) 상수도 좌우 컬럼용으로 추가했다(각 90px 컬럼 안쪽에 여백을 둔 68px 텍스트 폭 — 축약 액션+상태 결합 문자열의 실측 최악값 113px보다는 좁아, 액션과 상태를 같은 줄에 결합하지 않고 별도 줄로 유지해야 함을 확인했다).
- engine-hosted 테스트(RED 확인: 새 필드들이 nil이라 `game/self_test.lua:846` 단언에서 즉시 실패하는 것을 확인한 뒤 구현)가 `shopLoadoutLines()`의 `hullActionCompact == "H:LV.0>1 $75"`, `steeringActionCompact == "G:LV.0>1 $65"`, `hullPreviewCompact == "HULL 4"`, `steeringPreviewCompact == "SPD 70"`, `yieldActionCompact == "Y:LV.0>1 $60"`, `shipActionCompact == "V:BUY $125"`를 검증한다. `make test`, `GAME_HEADLESS=1 GAME_UNIT=1 love .` 모두 GREEN. `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:25`).
- **이번 사이클에서 완료하지 못한 부분:** 남은 시간 예산 안에서 이 새 축약 필드/컬럼 상수를 실제 `settlement` draw 분기의 HULL/STEERING·YIELD/SHIP printf 호출에 연결(좌우 컬럼별 별도 배치)하고 실기기 LÖVE 캡처로 겹침 여부를 재확인하지 못했다. 현재 draw 코드는 여전히 기존(검증된, 겹치지 않는) 전체 폭 `hullAction`/`steeringAction`/`yieldAction`/`shipAction` 문자열만 사용하며 새 `*Compact` 필드는 아직 화면에 그려지지 않는다 — 즉 사용자가 보는 화면은 이번 사이클 이전과 동일하고, 이전 두 번의 되돌림을 유발했던 실제 겹침 결함도 아직 고쳐지지 않은 상태다.
- 다음 사이클에서 이어받을 정확한 다음 단계: `game/scenes/play.lua`의 settlement draw 분기에서 HULL/STEERING 공유 행 두 줄(action/status, 그리고 그 아래 hullPreview 줄)을 `shopColumnLeftX/shopColumnLeftW`(16,68)로 `hullActionCompact`+`hullPreviewCompact`를, `shopColumnRightX/shopColumnRightW`(88,68)로 `steeringActionCompact`+`steeringPreviewCompact`를 각각 그리도록 교체하고, YIELD/SHIP 공유 행도 동일한 패턴(`yieldActionCompact`+`yieldPreview`/`shipActionCompact`+`shipPreview` 좌우 분할)으로 교체한 뒤, `GAME_CAPTURE_PHASE=settlement-newbest`(`1440×2560`) 실기기 캡처로 겹침이 실제로 사라졌는지 vision으로 반드시 확인해야 한다(이전 두 사이클 모두 engine-hosted 테스트만으로는 렌더 겹침을 잡지 못했다).
- 이번 사이클은 `git status --short`가 clean한 상태에서 preflight PASS로 시작했고, 위 데이터 준비 슬라이스는 완전히 GREEN 상태로 커밋 가능하다. AetherAI-only 최종 에셋 확인은 이번 사이클에도 자격 증명을 찾지 못해 human-gated 상태를 유지했다.


## YIELD/SHIP/HULL/STEERING 컬럼 정렬 렌더링 수정 및 터치 밴드 정렬 완료

- 이전 사이클에서 준비한 `*Compact` 데이터를 사용하여 `game/scenes/play.lua`의 settlement draw 로직을 좌우 분할 컬럼 레이아웃으로 변경했다. 추가로 `shipPreviewCompact`를 `shopLoadoutLines()`에 정의하여 우측 컬럼 공간(68px)에 맞게 렌더링되도록 수정했다.
- 축약된 텍스트와 상태(Status)를 개별 줄로 분리하되, 각 항목 그룹이 원래 의도된 터치 밴드(`settlementTouchRows`의 144~188, 188~232, 232~276, 276~320) 안에 시각적으로 쏙 들어가도록 `row`와 `rowStep` 변수를 명시적으로 조절하여 y 정렬 불일치 결함을 완벽히 해결했다.
- `GAME_CAPTURE_PHASE=settlement-newbest`(`1440×2560`)를 통해 실제 렌더링 캡처 화면을 vision으로 재확인한 결과, 좌우 컬럼 텍스트가 서로 전혀 겹치지 않으며, 각 블록이 터치 밴드 영역 내에 잘 정렬되고 맨 아래 `TAP: RELAUNCH` 문자열도 `DEV PLACEHOLDER` 푸터(y=307)와 겹치지 않음을 최종적으로 검증했다.
- `make verify LOVE=/Users/jm/.local/bin/love` 모두 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`, `LOVE_BUNDLE_OK:build/game.love:32`).

## 조종 방식 개선 슬라이스 1: 조이스틱 전방향 이동 (완료)

사용자가 조종/우주 구조 개편을 요청했다: (1) 조이스틱을 통한 전방향 이동, (2) 지구 중심 은하계(태양계) 기반 원형 대우주 + 미니맵, (3) 우주 경계 없음, 미니맵에 이탈 거리/방향만 표시. 합의된 계획: 연료/귀환 경제는 지구로부터의 반경 거리를 기존 ALT 역할로 대체, 은하계는 기존 "섹터"를 대체(은하계 안에서만 행성 생성), 3가지를 슬라이스로 나눠 순서대로 진행. 이번 사이클은 슬라이스 1(조이스틱)만 처리한다.

- `game/joystick.lua`를 새로 추가했다. LÖVE API에 의존하지 않는 순수 벡터 계산 `M.vector(originX, originY, currentX, currentY)`가 드래그 거리 6px(`M.deadzone`) 미만이면 `(0,0,0)`(방향 없음)을, 데드존~40px(`M.maxRadius`) 사이는 선형 보간된 크기(`0~1`)의 정규화 방향 벡터를 반환한다. 터치/마우스/향후 게임패드 스틱 등 어떤 입력 표면에도 재사용 가능하다.
- `game/scenes/play.lua`의 `PlayScene:touchpressed`가 상승·귀환 phase의 조종 터치에 `originX`/`originY`(눌린 시점 좌표)를 함께 저장한다. 새 `PlayScene:joystickVector()`가 활성 터치 중 데드존을 넘은 드래그가 있으면 그 방향/크기를 반환하고, 없으면(단순 탭-홀드 포함) `(0,0,0)`을 반환해 기존 좌/우 이진 조종으로 완전히 폴백한다 — 기존 `LEFT`/`RIGHT` 탭-홀드 터치 UX와 engine-hosted 회귀 테스트는 전혀 변경되지 않는다.
- `PlayScene:update`가 조이스틱 크기가 0보다 크면 `expedition.steeringSpeed(run)`을 기준으로 `ship.x`(수평)와 새 `self.verticalOffset`(수직, 자동 상승/귀환 라인 위에 얹는 오프셋)을 동시에 이동시켜 실제 전방향 이동을 만든다. `self.verticalOffset`은 `PlayScene.verticalOffsetLimit`(90px)로 clamp되어 자동 고도/연료 경제(다음 슬라이스에서 반경 거리로 전환 예정) 자체는 건드리지 않으면서 상하좌우 회피·수집 기동만 가능하게 한다. `ship.y`는 이제 `-altitude + verticalOffset`로 계산된다. 재출발(relaunch) 시 `verticalOffset`도 0으로 초기화된다.
- engine-hosted 테스트(`testJoystick()`, `game/self_test.lua`)가 `joystick.vector`의 데드존/최대반경/중간값 보간을 검증하고, 대각선 드래그가 `ship.x`와 `verticalOffset`을 동일한 크기로 동시에 이동시키는지, `verticalOffsetLimit` clamp가 작동하는지, 드래그 없는 단순 탭-홀드가 기존 이진 좌/우 조종 그대로 동작하는지(`verticalOffset` 불변 포함)를 검증한다.
- `make test`, `GAME_HEADLESS=1 GAME_UNIT=1 love .` 모두 GREEN. `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:26`).
- `main.lua`에 `GAME_CAPTURE_PHASE=ascending-joystick-diagonal` 개발 전용 진입 경로를 추가해 대각선 드래그를 1초간 시뮬레이션한 실제 LÖVE runtime capture를 시도했다. 카메라가 항상 우주선을 화면 중앙 고정 좌표(`shipScreenX/Y`)에 그리고 월드만 스크롤하는 기존 렌더링 구조상, 정적 스크린샷 한 장으로는 대각선 이동 자체를 시각적으로 증명할 수 없다(이전 사이클들의 트윙클/스크린쉐이크 애니메이션과 동일한 제약). 실제 이동 검증은 `testJoystick()`의 `ship.x`/`verticalOffset` 수치 단언이 담당한다.
- 남은 다음 슬라이스 후보 (사용자 승인된 순서): (1) 슬라이스 2 — 지구 중심 은하계(태양계) 기반 원형 대우주 구조로 `game/world.lua`의 섹터 해시를 은하계 단위로 재구성(경제는 반경 거리 기반으로 전환), (2) 슬라이스 3 — 미니맵(은하계 중심 행성·내 위치·경계 이탈 거리/방향 표시), (3) 기존에 남아있던 UI 정렬/AetherAI 에셋 항목들.

## 조종 방식 개선 슬라이스 2·3: 은하계 우주 + 미니맵 (완료)

슬라이스 1(조이스틱)에 이어, 지구를 원점으로 한 은하계 기반 대우주와 미니맵을 넣었다. 우주에 하드 경계는 없다.

- `game/world.lua`: 은하 셀 그리드(`galaxyCellSize = 4608`). 셀 (0,0)은 항상 지구 중심의 MILKY WAY. 다른 셀은 ~28%만 은하가 있어 빈 심우주와 은하가 섞인다. `planets()`는 은하 반경 안에서만 행성을 생성한다. 표본 가치/충돌/티어는 수직 고도(`-planet.y`) 대신 지구로부터의 반경 거리(`world.distanceFromEarth`)를 쓴다. 기존 y-only 시나리오는 수치가 같다.
- 각 비-홈 은하의 중심에는 방문 가능한 hub 행성(`world.hubPlanet`)이 있고, `nearbyPlanets`가 근처에 있으면 포함한다. 홈 은하 중심은 지구 자체라 extra hub가 없다.
- `game/minimap.lua`: 플레이어 중심 원형 차트. 근처 은하 중심과 지구·내 위치를 투영한다. `chartRadius` 밖으로 나가도 월드 벽은 없고, `beyond`/`distanceBeyond`/`returnDx,Dy`만 계산한다. 지구 마커는 차트 림에 clamp.
- `PlayScene:drawMinimap()`이 상승/발사/귀환 중 화면 오른쪽 위에 차트를 그린다. 차트 밖이면 `OUT N`과 지구 방향 점.
- engine-hosted `testGalaxyStructure()` / `testMinimap()`가 결정성, 빈 심우주, hub 행성, 반경 경제, 차트 안/밖 투영을 검증한다.
- `docs/GAME_DESIGN.md`를 지구 중심 원형 우주·조이스틱·미니맵에 맞게 갱신했다.

- 남은 다음 슬라이스 후보: (1) 자동 상승 라인을 완전 자유 2D 항해로 교체(연료를 이동 거리에 직접 연동), (2) 낮은 잔액 `SHORT $N` 캡처, (3) AetherAI-only 최종 에셋.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.

## 다국어(i18n) — HUD/상점/슬롯 잔여 문자열 + 데모 기본 한글 (완료)

이전 사이클이 `game/scenes/play.lua`의 남은 인라인 HUD·상점·슬롯·요약 문자열을 `i18n.t`로 옮기고, 데모 기본 로케일을 한글로 고정한 GREEN 변경을 워킹트리에 남긴 채 종료했다. 이번 사이클이 그 변경을 이어받아 커밋한다.

- `game/scenes/play.lua`의 남은 사용자 노출 문자열(HUD, 상점 액션/상태, 슬롯 버튼, 정산/파괴 카드, LEFT/RIGHT, SPINNING, WIN 줄 등)을 `game/i18n.lua`의 `i18n.t` 조회로 바꿨다. `en` 템플릿은 기존 하드코드 영어와 바이트 단위로 같아 `game/self_test.lua` 단언이 로케일 `en`에서 그대로 통과한다.
- `game/self_test.lua`는 파일 최상단과 `M.run()`에서 `setLocale("en")`을 고정한다. 비헤드리스 `love .`는 `main.lua`에서 `setLocale("ko")`로 한글 데모가 나온다.
- `make test`, `GAME_HEADLESS=1 GAME_UNIT=1 love .` 모두 GREEN. `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- 남은 다음 슬라이스 후보: (1) 자동 상승 라인을 완전 자유 2D 항해로 교체하는 첫 단계 — 조이스틱/좌우 기동의 추가 이동 거리에 연료를 연동, (2) AetherAI-only 최종 에셋(공식 로그인/export 가용성).

## 기동 추가 거리 연료 연동 (완료)

자동 상승 라인을 완전 자유 2D 항해로 바꾸는 첫 단계: 조이스틱·좌우 기동의 extra 픽셀에만 연료를 추가로 태운다. 공회전 상승은 기존 `fuelBurnRate`만 소모한다.

- `game/expedition.lua`에 `M.maneuverFuel(run, extraDistance)`와 `M.burnManeuverFuel(run, extraDistance)`를 추가했다. extra 픽셀은 자동 상승과 같은 비율(`fuelBurnRate / climbSpeed`)로 연료가 된다. 상승 phase에서만 태우고, extra가 연료를 0으로 만들면 기존과 같이 `returning`으로 전환한다. 귀환 중 회피 기동은 연료를 쓰지 않는다(이미 연료 0).
- `PlayScene:update`가 조이스틱/좌우 이동 전후 `ship.x`와 `verticalOffset` 차이를 extra 거리로 계산해 `burnManeuverFuel`에 넘긴 뒤 기존 `expedition.update`를 호출한다. 기동 없는 탭-홀드가 아닌 idle 프레임은 extra 0이라 기존 연료 경제가 그대로다.
- engine-hosted `testManeuverFuel()`가 (1) 55px extra가 `55 / climbSpeed * fuelBurnRate`인지, (2) idle 1초 상승이 `fuelBurnRate`만 태우는지, (3) 좌 홀드 1초가 idle + steeringSpeed extra를 태우는지 검증한다.
- `make test` GREEN. `make verify LOVE=/Users/jm/.local/bin/love` 전체 통과(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- 남은 다음 슬라이스 후보: (1) 자동 상승 라인 자체를 없애고 실제 이동 거리에만 연료를 연동(완전 자유 2D), (2) AetherAI-only 최종 에셋(공식 로그인/export 가용성).
