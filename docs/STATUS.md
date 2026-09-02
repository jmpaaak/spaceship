# STATUS
## 상승 화면 조이스틱 UI 축소 + 우주선 뱅킹/RCS 이펙트 완성 및 커밋 (인계 완료, 2026-09-02)

`git status --short`가 `M game/joystick.lua`/`M game/scenes/play.lua`(인계된 미커밋 GREEN 변경, preflight `git diff` 검사 PASS) 상태로 시작했다. preflight READY, 처리 대기 최우선 1개 항목(AetherAI-only)은 여전히 로그인 자격 증명이 없어 human-gated이므로, `loop/PROMPT.md` 2행 "Preserve and finish prior-cycle work; do not overwrite it"에 따라 인계된 미완성 변경을 이어받아 완료하는 것을 이번 사이클의 슬라이스로 선정했다.

- 인계된 변경은 `docs/GAME_DESIGN.md` 이동 방식 개선 요청에 대한 후속 다듬기다: 기존 조이스틱 원판(`joystick.maxRadius`=40px, 불투명도 0.35/0.9)이 180x320 캔버스에서 지나치게 크고 불투명한 오버레이로 보였던 문제를 고쳤다. `game/joystick.lua`에 `M.visualRadius`(14px)/`M.visualKnobRadius`(3px)/`M.visualFillAlpha`(0.12)/`M.visualLineAlpha`(0.28)/`M.visualKnobAlpha`(0.4)를 추가해 입력 반응 반경(`maxRadius`, 조작감 유지)과 그려지는 원판 크기(작고 반투명, 시각적 잡음 감소)를 분리했다. `M:joystickKnob()`/`M:drawJoystickStick()`이 새 `visualRadius`를 사용하도록 갱신했다.
- `game/scenes/play.lua`에 `M.bankFromSteer(dx, magnitude)`(스틱 기울기를 `-pi/2` 정지 자세 기준 최대 `±steerTiltMax`(0.5 라디안) 뱅크 각도로 변환)와 `self.ship.angle`을 목표 뱅크 각도로 매 프레임 부드럽게(`turnRate = min(1, 14*dt)`) 보간하는 로직을 `M:update`에 추가해, 조이스틱/키보드 좌우 조작 시 우주선이 실제로 기울어져 보이도록 했다(이전에는 위치만 이동하고 자세는 항상 고정 nose-up이었다). 기울임이 임계값(0.12 라디안)을 넘고 `rcsCooldown`이 0일 때 기운 방향 반대편에 짧은(0.22초) 청백색 RCS 파티클을 주기적으로(0.045초 쿨다운) 방출해 방향 전환의 물리적 근거를 시각화했다.
- 기존 상승/귀환 화면의 반투명 LEFT/RIGHT 사각 버튼 오버레이(steering band 배경색 채우기 + HOLD LEFT/HOLD RIGHT, button_left/button_right 텍스트)를 draw 경로에서 제거했다. 이 버튼들은 조이스틱이 이미 전방향 조작을 대체한 뒤에도 화면에 남아있던 레거시 이진 좌우 입력의 잔재 UI였다(입력 로직인 `steeringButtonState()`/`steeringHoriz`는 키보드 좌우 폴백으로 여전히 사용되므로 유지, 그려지는 오버레이만 제거).
- engine-hosted 테스트(`game/self_test.lua` 85-124행)가 이미 인계돼 있던 것을 그대로 실행해 확인: 마우스 드래그 스틱이 데스크톱에서 정상 동작(release 후 knob nil로 사라짐), `joystick.visualRadius < joystick.maxRadius` 및 두 알파값이 모두 낮은 투명도임을 단언, `bankFromSteer(1,1)==steerTiltMax`/`bankFromSteer(-1,1)==-steerTiltMax`/`bankFromSteer(1,0.5)==steerTiltMax*0.5`, 오른쪽 스틱이 `ship.angle`을 뱅크 방향(시계 방향, nose-up 대비 증가)으로 기울이고 그 오른쪽에서 RCS 퍼프 파티클을 방출함을 검증한다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-joystick-diagonal`, 1080x1920, 기존에 이미 있던 대각선 드래그 개발 캡처 경로 재사용)를 vision으로 확인했다: 우주선이 정지 자세(수직) 대비 확실히 기울어진 자세로 렌더링되고, 화면 하단부에 예전의 크고 불투명한 원판 대신 작고 옅은 파란 원형 스틱 UI가 배치됨을 확인했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, 8/8 Python 유닛 테스트, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`는 이번 슬라이스가 인계 완료 항목이라 별도 변경 없음(처리 대기 1개 항목 AetherAI-only는 여전히 human-gated로 남아 있음).
- 남은 다음 슬라이스 후보: (1) AetherAI 로그인 자격 증명이 제공되면 이 매니페스트 스키마에 맞춰 실제 공식 에셋 export를 진행, (2) 새 feedback이 등록되면 그것을 우선 처리한다.

## AetherAI-only 최종 에셋: provenance manifest 검증 도구 추가 (make verify 게이트, 2026-09-02)

`git status --short` clean, preflight PASS 상태로 시작. 처리 대기 최우선 항목인 "AetherAI-only 최종 에셋"을 이번 사이클의 슬라이스로 선정했다. 로그인/공식 export 자격 증명은 여전히 이 세션에 없어(`env`/`~/.hermes/.env`에 `aether` 키 없음, `/private/tmp/aether.html`은 이전 세션이 확인한 공식 도메인(`aetherforgeai.com`) 정보일 뿐 로그인 세션이 아님을 재확인) 실제 공식 에셋 import는 여전히 human-gated다. `loop/PROMPT.md`의 "If login/export is unavailable... continue non-asset gameplay, tests, persistence, balancing, touch input, packaging, and UI layout work" 지침에 따라, import 불가능한 이번 사이클에도 진행 가능한 비-에셋 작업으로 이 항목의 **강제 검증 인프라**를 추가했다.

- 새 `tools/verify_asset_manifest.py`: `assets/` 아래 이미지 파일(`.png/.jpg/.jpeg/.webp/.gif/.bmp/.tga`, 폰트 `.ttf` 등은 제외)이 하나라도 있으면 `docs/assets/MANIFEST.json`에 `loop/PROMPT.md` 37행이 요구하는 12개 필드(`source_url`, `terms_url`, `asset_id`, `prompt`, `model`, `style`, `settings`, `downloaded_at`, `sha256`, `width`, `height`, `qa`)를 전부 갖춘 매칭 항목이 있는지, `source_url`이 공식 `aetherforgeai.com`/`aetherai.com` 도메인인지, 기록된 `sha256`이 실제 파일 해시와 일치하는지(오래되었거나 다른 파일로 바꿔치기된 항목 검출) 검사한다. 위반이 있으면 `ASSET_MANIFEST_FAIL`과 구체적 사유 목록을 출력하고 0이 아닌 코드로 종료한다. 이미지가 하나도 없고 매니페스트가 빈 배열이면(현재 상태, AetherAI import 전) `ASSET_MANIFEST_OK`로 조용히 통과한다 — 즉 지금 당장 에셋을 만들어내라고 강제하지 않으며, Lua 도형/Python 생성 이미지를 "최종 에셋"으로 몰래 들여오는 것만 막는다.
- 새 `docs/assets/MANIFEST.json`(빈 배열 `[]`)을 추가해 앞으로 공식 AetherAI export를 받을 때 채워 넣을 자리를 만들었다.
- `Makefile`의 `verify` 타깃에 `python3 tools/verify_asset_manifest.py`를 추가해 `make verify LOVE=...`가 앞으로 항상 이 게이트를 통과해야 한다. `test` 타깃에도 `python3 -m unittest tools.test_verify_asset_manifest -v`를 추가했다(Lua headless 테스트와 별개로 이 Python 도구 자체의 회귀를 잡는다 — 도구 자체는 최종 미술이 아니라 provenance 검증 스크립트이므로 `docs/GAME_DESIGN.md`의 "Python/Pillow는 최종 에셋 source로 금지" 규칙과 무관하다).
- TDD로 진행: `tools/test_verify_asset_manifest.py`(8개 케이스: 빈 매니페스트+이미지 없음 통과, 폰트 파일 예외, 매니페스트 항목 없는 이미지 거부, 완전한 매칭 항목 통과, 필수 필드 누락 거부, sha256 불일치 거부, 존재하지 않는 파일을 가리키는 항목 거부, 비공식 `source_url` 거부)를 먼저 작성해 `verify_asset_manifest` 모듈이 없어 RED(ImportError)임을 확인한 뒤 `tools/verify_asset_manifest.py`를 구현해 GREEN으로 만들었다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, 8/8 Python 유닛 테스트, `LOVE_BUNDLE_OK:build/game.love:42`, `ASSET_MANIFEST_OK`).
- `docs/feedback/INBOX.md`의 "AetherAI-only 최종 에셋" 항목은 실제 공식 에셋을 아직 하나도 import하지 못했으므로(자격 증명 부재) "처리 대기"에 그대로 남겨둔다 — 이번 슬라이스는 그 요구사항을 코드로 강제하는 안전장치를 마련한 것이지, 요구사항 자체를 완료한 것이 아니다.
- 남은 다음 슬라이스 후보: (1) AetherAI 로그인 자격 증명이 제공되면 이 매니페스트 스키마에 맞춰 실제 공식 에셋 export를 진행, (2) 세로 상승형 핵심 루프/발라트로 스타일/런치 화면 표본 전시 3개 항목은 이미 코드·실기기 검증까지 완료되어 사용자 최종 확인만 남음, (3) 새 feedback이 등록되면 그것을 우선 처리한다.

## 세로 상승형 로그라이트 핵심 루프: full-loop-relaunch 캡처 무한 루프 버그 수정 + 실기기 검증 (2026-09-02)

`git status --short`가 `M main.lua`(인계된 미커밋 GREEN 변경, preflight `git diff` 검사 PASS) 상태로 시작했다. preflight READY, 처리 대기 최우선 2개 항목(핵심 루프, AetherAI-only) 중 인계된 변경이 이미 핵심 루프 항목의 실기기 검증 도구였으므로 이를 완성하는 것을 이번 사이클의 슬라이스로 선정했다.

- 인계된 `main.lua`의 `GAME_CAPTURE_PHASE=full-loop-relaunch` 개발 전용 진입 경로(실제 `PlayScene:keypressed`/`update`로 launch→ascend→collect→fuel-empty return→slot spin→settlement→shop upgrade→relaunch 전체를 구동)를 실행해 검증하려 했으나, 실제로 실행하자 LÖVE 프로세스가 종료되지 않고 무한 행(hang)함을 발견했다(180초 타임아웃, 프로세스를 강제 종료해야 했음).
- 근본 원인: `while scene.expedition.phase == "returning" and scene.expedition.slotOpportunities > 0 do scene:keypressed("space") end` 루프가 `scene:update()`를 호출하지 않은 채 매 반복마다 즉시 재입력한다. `game/scenes/play.lua:1054`의 `keypressed`는 `not self.slotSpin`일 때만 `expedition.useSlot`을 호출해 새 스핀을 시작하는데, `beginSlotSpin()`이 설정한 `self.slotSpin`은 `PlayScene:update`가 `slotSpin.elapsed >= slotSpin.duration`(0.45초 애니메이션)에 도달했을 때만 `nil`로 지워진다(`game/scenes/play.lua:848-850` 근방). `scene:update()` 없이 `keypressed`만 반복 호출하면 첫 스핀 이후 `slotOpportunities`가 절대 줄지 않아(가드가 항상 막음) 무한 루프가 된다.
- `main.lua`의 해당 while 루프 안에 `scene:update(1)`을 추가해 매 스핀 후 애니메이션이 실제로 정착(`slotSpin`이 `nil`로 클리어)하도록 고쳤다. 수정 후 재실행하자 즉시 정상 종료(`SPACESHIP_CAPTURE_OK`)했다.
- 실제 LÖVE runtime capture(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=full-loop-relaunch`, 1080×1920, `build/spaceship-runtime-preview-full-loop-relaunch.png`, 로컬 산출물로 커밋 제외)를 vision으로 확인했다: relaunch 후 화면이 고도 0000, 자금 $55(슬롯/정산 보상 반영), F119(연료 업그레이드 반영, 상점에서 구매한 fuel upgrade가 실제로 적용됨), 신선한 상승 화면(우주선이 지구 위에서 다시 상승 시작)으로 렌더링되어 `launch → ascending → returning/slots → settlement/shop → relaunch` 전체 루프가 실제 LÖVE 런타임에서 정상 작동함을 확인했다. 겹침/깨짐 없음.
- 이 수정은 `main.lua`의 개발 전용 캡처 하네스 코드에 한정되며 `game/*.lua` 게임 로직 자체는 변경하지 않았다(핵심 루프는 이미 구현되어 있었고, 이번 사이클은 그 실기기 검증 도구의 버그를 고쳐 검증을 완성한 것). `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- `docs/feedback/INBOX.md`의 "세로 상승형 로그라이트 핵심 루프" 항목을 실기기 검증 완료로 "처리 완료"로 이동했다.
- 남은 다음 슬라이스 후보: (1) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행(계속 human-gated), (2) 새 feedback이 등록되면 그것을 우선 처리한다.

## 행성·이펙트 발라트로 스타일 카드형 비주얼 강화: 최종 검수 후 처리 완료로 이동 (2026-09-02)

`git status --short` clean, preflight PASS 상태로 시작. 처리 대기 3개 항목(핵심 루프, AetherAI-only, 발라트로 스타일) 중 "발라트로 스타일" 항목을 이번 사이클의 슬라이스로 선정해 코드·실기기 캡처로 최종 검수했다.

- `game/scenes/play.lua`를 직접 대조해 6개 후속 확정 사항(스트릭 `expedition.streakMultiplier`/`collectSample`, 롤업 `rollupAmount`, 등급 비례 쉐이크 `sampleTierShakeMultiplier`, 도감 `world.specimenCatalog`/`collection_store.lua`, GAINS/LOSSES `shipTradeoff`/`scoutTradeoffLines`, 접근 기대감 `sparkleAnticipationMultiplier`)가 전부 코드에 존재하고 draw 경로(`sampleTierEffect`/`sampleTierColor`/`sampleTierSparkle`, 외곽 글로우 링·소프트 드롭섀도우·그라디언트 채움·등급별 트윙클)에 실제로 연결되어 있음을 라인 단위로 재확인했다.
- `make test` GREEN 확인 후, 실제 LÖVE runtime capture(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-sample-tiers`, 1080×1920, `main.lua`에 이미 존재하는 개발용 진입 경로)를 촬영해 vision으로 확인했다: common(회백)/rare(하늘색)/epic(금빛) 세 행성이 각각 다른 색·두께의 외곽 글로우 링으로 렌더링되고, epic 행성은 두터운 금빛 림 글로우 + 보라색 그라디언트 채움(밝은 하이라이트 + 어두운 베이스)으로 눈에 띄게 카드처럼 도드라져 보임을 확인했다(발라트로류 "강한 외곽 글로우/림 라이트, 채도 높은 그라디언트, 등급별 차등" 요구사항 충족).
- `docs/feedback/INBOX.md`의 "행성·이펙트 발라트로 스타일 카드형 비주얼 강화" 항목 전체(메인 항목 + 6개 후속 확정 사항)를 "처리 대기" → "처리 완료"로 이동했다. 코드 변경 없음, 실기기 vision 재검증 + 문서 정리만 수행했다.
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN.
- 남은 다음 슬라이스 후보: (1) 세로 상승형 로그라이트 핵심 루프 항목도 사용자 최종 검수 후 "처리 완료"로 이동, (2) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행, (3) 새 feedback이 등록되면 그것을 우선 처리한다.

## `docs/feedback/INBOX.md` 문서 동기화: 완료된 런치 화면 지구 탐험물 전시 항목을 처리 완료로 이동 (2026-09-02)

`git status --short` clean, preflight PASS 상태로 시작. 처리 대기 4개 항목을 다시 코드 레벨로 전수 재확인했다.

- 3개 항목(핵심 루프, AetherAI-only, 발라트로 스타일)은 이전 여러 사이클의 조사와 동일하게 여전히 코드에 이미 구현/검증되어 있거나(핵심 루프·발라트로 스타일) 자격 증명 부재로 human-gated(AetherAI-only, `env`/쉘 환경변수에 `aether` 관련 키 없음 재확인)임을 확인했다 — 코드 변경 없음, 사용자 최종 검수만 남음.
- `docs/feedback/INBOX.md`의 "런치 화면 지구 탐험물 전시" 항목은 제목 자체에 `(2026-09-02, 사용자 요청, 완료)`라고 적혀 있고 본문도 `✅ 완료`로 시작하는데도 여전히 "처리 대기" 섹션에 잘못 남아 있던 문서 정합성 결함을 발견했다. 코드(`game/world.lua`의 `specimenCatalog`, `game/collection_store.lua`, `game/scenes/play.lua`의 `drawSpecimenStrip`/`specimenProgress`, `game/self_test.lua` 338/1296행)를 다시 대조해 실제로 완료 상태와 일치함을 재확인한 뒤, 해당 항목 전체를 "처리 대기" → "처리 완료" 섹션으로 이동했다(문서만 수정, 게임 로직/텍스트 변경 없음).
- `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:33`).
- 남은 다음 슬라이스 후보: (1) AetherAI 로그인 자격 증명이 제공되면 공식 에셋 export 진행, (2) 세로 상승형 핵심 루프/발라트로 스타일 두 항목도 사용자 최종 검수 후 "처리 완료"로 이동할 수 있으면 이동, (3) 새 feedback이 등록되면 그것을 우선 처리한다.

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
