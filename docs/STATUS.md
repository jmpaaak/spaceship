## Current Status

2026-09-05 — INBOX (10) 미니맵: always-on hub arrow (변경 A)

- `game/minimap.lua`: `nearestCheckpointDirection` now also returns the galaxy object (5th return). `view()` changed `checkpointBeyond` logic: arrow shows whenever a non-milkyway hub exists AND ship distance >= hubRadius*3 (arrival threshold). Previously only showed when hub was outside `viewRadius`.
- `game/self_test.lua`: 2 new assertions — (a) hub inside chart but not arrived → arrow shows; (b) ship at hub (dist < hubRadius*3) → arrow hides.
- `make verify` GREEN.

## Next Slice

- INBOX (10) 변경 B — HUB vs 중심별(태양) 미니맵 구분: hub offset from sun, distinct glyphs

---

## 2026-09-05 — INBOX (9) 은하 중심별 중력우물 + 도트 데미지 + 10초 생존 시 표본

- `game/scenes/play.lua`: 지구 근접 시(거리 < `settleRadius + 15`) `self.timeSlip`을 설정하여 0.6초간 게임 속도를 0.5배로 낮추는 슬로우모션 구현.
- `game/scenes/play.lua`: `M.reentryHeatVignetteAlpha` 함수를 추가하여 진입 구간에서 붉은 발열 비네트의 투명도를 0에서 0.3까지 증가시키고 화면 전체에 테두리로 그림.
- `game/self_test.lua`: 슬로우모션 발동, 발열 비네트 알파값의 거리에 따른 증가 및 Settle 후 초기화 테스트 추가.
- `docs/feedback/INBOX.md`: 항목 (5)를 `## 처리 대기`에서 `## 처리 완료`로 이동.
- `make verify` GREEN.

## Next Slice

- INBOX (7) 미니맵 줌인 — HUB/중심행성이 보이게

---

## 2026-09-05 — INBOX (4) 행성 표본 채집 궤도 진입 시 타격감 이펙트

- `game/scenes/play.lua`: 표본 수집 반경 진입 시 `self.timeSlip = { timer = 0.4, scale = 0.3 }`를 적용하여 0.4초간 게임 배속 0.3의 타임슬립 효과 추가.
- `game/scenes/play.lua`: 기존 충돌에만 쓰이던 `self.shipShake`를 수집 시에도 0.25초간 발동시키고, 강도(`shipShakeMagnitude`)를 표본 등급(common=0.6, rare=1.0, epic=1.4)에 따라 설정.
- `game/scenes/play.lua`: 수집 시 화면 전체에 0.15초 동안 흰색 반투명 오버레이를 그리는 `self.collectFlash` 추가.
- `game/self_test.lua`: 롤업 애니메이션 테스트가 타임슬립에 의해 영향받지 않도록 `floatingTextScene.timeSlip = nil` 추가.
- `docs/feedback/INBOX.md`: 항목 (4) 타격감 이펙트를 `## 처리 대기`에서 `## 처리 완료`로 이동.
- `make verify` GREEN.

---

## 2026-09-05 — INBOX (6) HUB 충돌 게임오버 금지 (지구와 동일 취급)

- `game/scenes/play.lua`: 충돌 판정(`planet.radius + 5`) 내에서 `planet.hub`와 `planet.isShop`일 경우 데미지 로직을 우회하도록 예외 추가 (`not planet.hub and not planet.isShop`).
- `game/self_test.lua`: 허브 및 상점 행성과의 충돌 시뮬레이션에서 내구도가 감소하지 않고 `collided` 플래그가 설정되지 않음을 단언하는 테스트 추가.
- `docs/feedback/INBOX.md`: 기완료 항목 (2), (3) 및 방금 완료한 항목 (6)을 `## 처리 대기`에서 `## 처리 완료`로 이동.
- `make verify` GREEN.

## 2026-09-05 — INBOX (1) 상점 UI 텍스트 겹침 수정

- play.lua: settlementRowStep 28→44, summaryRowStep 32→40
- play.lua: settlementPanelTop 400→200, panelHeight 420→880
- play.lua: summaryBgHeight 70→170, touchRowHeight 70→165
- play.lua: summary Y좌표 40px 간격 재배치 (totalY=248, samplesY=288, peakAltY=328, newBestY=368)
- self_test.lua: overlap 방지 assertion 추가 (rowStep >= fontSize+4, summary line gaps >= fontSize, panel contains all rows)
- self_test.lua: hardcoded touch coordinates 업데이트 (hull y:545→500, ship y:615→670, relaunch y:755→1000)
- `make verify` GREEN.

---

## 2026-09-05 모바일 UI 전체 점검 (3)

2026-09-05 — 모바일 UI 전체 점검 (3): 조이스틱 크기 + 위치 모바일 최적화.

- `game/joystick.lua`:
  - `deadzone` 24→28px (터치 정밀도 보정).
  - `visualRadius` 56→72px, `visualKnobRadius` 12→18px (엄지 친화 크기).
  - 고정 앵커 추가: `anchorX=130`, `anchorY=1120` (화면 하단 좌측), `touchZoneRadius=120`.
- `game/scenes/play.lua`:
  - `joystickOrigin()` 헬퍼: 앵커 zone 내 터치 시작 시 origin을 앵커로 스냅.
  - ascending/returning `touchpressed`에서 `joystickOrigin` 적용.
  - `drawJoystickStick()`: 터치 없을 때 앵커 위치에 반투명 고스트 패드 표시.
- `game/self_test.lua`: 조이스틱 모바일 상수 어설션 6개 추가.
- `make verify` GREEN.

---

## 2026-09-05 Stellar Origin suit system (cycle result)

- Implemented `drawPixelStar(image, x, y, frameW, frameH, frameCount, frameIdx, size, r, g, b, a)` helper in `game/scenes/play.lua` (exported as `M.drawPixelStar`).
- `M.new()` loads `assets/space/pixelplanets_stars.png` (17 frames, 9x9) and `assets/space/pixelplanets_stars_special.png` (6 frames, 25x25); both returned on scene instance as `pixelStarsImage` / `pixelStarsSpecialImage`.
- Background stars (`world.backgroundStars`) loop: `bright < 0.4` draws a white pixel-art star (size 2-3px, opacity 0.15+bright*0.4), `bright >= 0.4` draws a golden special star (size 4-5px, opacity 0.5+bright*0.5). Rectangle fallback if image nil.
- Foreground stars (`world.stars`) loop: same logic, sizes 3-4 / 5-6 px. Old `drawStarPointSprite` calls removed from both loops.
- Self-test: new block asserts `drawPixelStar` exported, nil-safe, and scene slots typed correctly.
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + ASSET_MANIFEST_OK).

## 2026-09-05 모바일 해상도 최적화 sub-item (1): GAME_SCALE 기본값 + 밀도 점검

- `conf.lua`: `GAME_SCALE` 기본값 3 → 1 변경. 환경변수 미설정 시 창 크기가 720×1280 (1:1 canvas scale)로 열림. 모바일/emulator는 `viewport.fit()` 이 컨테이너 맞게 자동 스케일 (기존 동작 그대로).
- `GAME_CAPTURE_PHASE=play` 캡처 단계 추가 (`main.lua`): ship을 altitude 300에 배치하여 배경별/전경별/행성이 동시에 보이는 프레임 생성.
- 밀도 분석 (720×1280, sectorSize=192):
  - 캔버스 = 3.75 × 6.67 섹터 → 3×3 = 9개 섹터 렌더
  - 배경별: 120 stars/sector × 9 = 최대 1080 → 캔버스 필터 후 적절한 밀도
  - 전경별: 18 stars/sector × 9 = 162 → 스트리밍 메테오 레이어로 적절
- 캡처 경로: `docs/captures/play-density-check-2026-09-05.png`
- `make verify` GREEN.

## 2026-09-05 미니맵 나선 팔 수 — 은하 반지름 기반 결정

- `game/minimap.lua` `M.spiralArmCount(galaxy)`: 순수 랜덤(hash) 방식 → galaxy.radius 구간 기반으로 변경.
  - r < 1000 → 2, r < 1400 → 3, r < 1800 → 4, else → 5.
  - world.lua 기준 은하 반지름 범위 828~2120px와 정렬됨.
  - `M.spiralRotation()` (hash 기반) 및 팔 간격 계산 unchanged.
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK x3 + LOVE_BUNDLE_OK + ASSET_MANIFEST_OK).

## 2026-09-05 중력장(표본 수집 반경) 확대 — sub-item (3)

- `game/scenes/play.lua`:
  - 수집 반경: `planet.radius + 14` → `planet.radius + 30` (line 1590).
  - 시각 rim 반경: `planet.radius + 3` → `planet.radius + 30` (lines 2305/2308) — 플레이어가 실제 수집 범위를 직관적으로 확인 가능.
  - sparkleAnticipation 기준 반경도 `+ 14` → `+ 30` 동기화 (line 2318).
  - 충돌 데미지 반경(`planet.radius + 5`)은 그대로 유지.
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + LOVE_BUNDLE_OK + ASSET_MANIFEST_OK).

## Next Slice

- INBOX 2026-09-05 sub-item (5): 은하 공유 특성 — galaxy starType + 행성 hue 범위 클램프 + 특수별 프레임 고정.

## 2026-09-05 행성 레이블 — sub-item (4)

- `game/i18n.lua`: `hub_label = "HUB"` / `shop_label = "SHOP"` 키를 `en` 및 `ko` locales에 추가.
- `game/scenes/play.lua`: planet 루프 내, approachWarning 블록 뒤에 레이블 렌더 삽입.
  - 조건: `not self.discovered[planet.id]` (미발견 행성만).
  - Hub 행성(`planet.hub`): `y - planet.radius - 14` 위치에 황금색(0.95/0.85/0.4) "HUB" 텍스트.
  - Shop 행성(`planet.isShop`): 동일 위치에 "SHOP" 텍스트.
  - `clampLabelX`로 화면 경계 보정 (기존 approachWarning 레이블과 동일한 방식).
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + LOVE_BUNDLE_OK + ASSET_MANIFEST_OK).

## 2026-09-05 별 위치 2D 랜덤 분산 (sub-item 2)

- `game/world.lua` `M.stars()`: x/y salt를 `hash(sectorX*31+i, sectorY*17, 10001)` / `hash(sectorX*17+i, sectorY*31, 20001)` 교차 시드로 변경. 이전 `hash(sectorX, sectorY, 100+i)` / `hash(..., 200+i)` 방식은 같은 입력 배열에 다른 salt만 추가해 두 축이 암묵적으로 상관관계를 가질 수 있었음. 교차 시드는 x축 해시 입력에 sectorY*17이, y축 해시 입력에 sectorX*17이 역할을 바꿔 들어가므로 두 출력이 독립적으로 분포됨.
- `game/world.lua` `M.backgroundStars()`: 동일한 교차 시드 패턴 적용, salt 50001/60001로 `M.stars()`의 10001/20001과 완전히 다른 salt 공간 사용 → 두 레이어가 동일 위치에 겹치지 않음.
- `M.backgroundStarCount` 120 → **200** (별 밀도 향상).
- `make verify` GREEN (SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + ASSET_MANIFEST_OK).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.

## 2026-09-05 모바일 UI 점검 - sub-item (4) 상점 패널

- `game/scenes/play.lua`: 상점(settlement) 패널의 수직 위치를 1280 캔버스 기준 중앙(`y=400`)으로 내리고, 터치 행 4개의 높이를 각각 70px(iOS HIG 최소인 44pt를 크게 상회)로 확대 적용.
- 텍스트 크기를 8px에서 12px(`M.settlementFontSize = 12`)로 확대하고, 각 행의 행간을 넓힘. 메인 패널 백그라운드 및 "EARTH SHOP" / "CHECKPOINT" 제목 문자열이 누락되었던 것을 복구함.
- `game/self_test.lua`: 상점 터치 테스트에서, 변경된 터치 버튼들의(ship, hull, relaunch) 좌표에 맞게 테스트 `touchpressed` 파라미터 갱신 (예: `ship` 타겟을 `135, 210`에서 `540, 615`로 이동).
- `make verify` GREEN. 다음 처리 대상 슬라이스: "(2) 미니맵 크기 + 위치" 또는 "(5) 로드아웃(launch) 패널"
