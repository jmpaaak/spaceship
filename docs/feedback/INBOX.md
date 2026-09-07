# Feedback Inbox

## 처리 대기

(61) **Discord 2026-09-07 미완 요청 복구 (사용자 확정, 인터럽트 복구):**
  채팅 히스토리는 사라지지 않음. 다만 긴 턴이 `/stop`·압축·새 메시지로 끊기면 **진행 중이던 코드 작업만** 드롭됨.
  아래는 그날 Discord에서 지시됐지만 `## 처리 대기`가 비어 루프가 IDLE이었던 항목.
  한 사이클 = 아래 소항목 **하나** + `GAME_HEADLESS=1 GAME_UNIT=1` GREEN + 커밋.
  `play.lua`가 루프에 dirty면 직접 수정 금지 — 이 INBOX만 소비.
  프로세스 (사용자 2026-09-07): Discord 요청은 **코드보다 먼저** 이 섹션에 한 줄+커밋. 빈 처리 대기 = IDLE.


  ~~(8) **선체/엔진 부품 아이콘** → 처리 완료로 이동~~

  ~~(9) **미니맵 두 번째 은하 림** → 완료 `fff3cd5`~~
  ~~(10) **일시정지 시 위성·혜성 정지** → 완료 `fff3cd5`~~
  ~~(11) **배경 별 팝인/팝아웃** → 완료 `fff3cd5`~~

  ~~(12) **게임오버 keep-one: 효과 보여준 뒤 예/아니오, 텍스트가 카드 밖으로 넘치지 않게** → 완료 (카드 이름 11px+scissor clip, 탭→confirm popup with 이름/효과/등급/수트/시너지+예/아니오 48px buttons, test INBOX-61(12) OK)~~

  ~~(13) **우주파편이 안 나옴** → 완료 `fff3cd5` (time%30 wrap + radius 8-16/5-8/5-10 + full-angle drift)~~

  ~~(14) **행성이 초록 원 폴백** (msg `1546335441580462130` — "행성들 에셋이 없는 것 같은데")~~ → 완료 (pngColorType 메모리 실패 수정 및 시트 회전 중심 버그 픽스)

  ~~(15) **슬롯 전용 부품 풀** → 완료 (slotExclusive JSON 2+2 cards, gear.slotPool/earthShopPool filtering, earthSlotSpin prefers slot pool, gear-editor round-trip, GEAR_SCHEMA.md documented, testSlotExclusivePartsWiring GREEN)~~

  ~~(16) **허브 은하 추가 구입 메뉴 버튼** → 완료~~

  ~~(17) **게임오버: 아이템 없으면 \"탭하여 다시시작\" 세로 가운데** → 완료 (destroyedRestartTextY helper, panelY+panelH/2-11 centering, test INBOX-61(17) OK)~~

  (18) ~~**HUB 상점 슬롯 위치 깨짐** (msg `1546394478015815772`)~~
    - ~~카드(row1-2)와 슬롯(row4) 사이 빈 공간이 과도. row3 "장비 재입고" 한 줄만 있는데 170px.~~
    - ~~슬롯 머신을 row3 텍스트 바로 아래로 붙여 그려서 간격 축소.~~
    - 완료: row3 height 170→70px (`settlementGearRowHeight`), row4 slot 200px (`settlementSlotRowHeight`). Gear text vertically centered. Test INBOX-61(18) GREEN.

  ~~(19) **슬롯 속도 보상이 steeringUpgradeLevel에 +5/+20 → 가격 폭등 버그** (msg `1546395056120926240`)~~
    - ~~`play.lua:2145` `steeringUpgradeLevel += rv` (rv=5 or 20). 가격 `$5 × 1.05^level`라서 level 200이면 $86,000+.~~
    - ~~수정: 슬롯 속도 보상은 **별도 `slotSpeedBonus`** 필드에 누적하고, `effectiveSpeed`에 합산. `steeringUpgradeLevel`은 상점 구매만 올리게.~~
    - ~~내구도·수확도 같은 구조인지 확인: 내구도는 maxDurability를 직접 올려서 OK. 수확은 `sampleYieldUpgradeLevel += 1`이라 1%씩이라 완만. 속도만 rv가 크게 레벨을 올려서 문제.~~
    - 완료: `slotSpeedBonus` field added to run state (init/wipe). `effectiveSpeed()` includes it. play.lua slot reward uses `slotSpeedBonus` not `steeringUpgradeLevel`. Test INBOX-61(19) GREEN.

  ~~(20) **장비 제안 `[B]:` 키보드 접두사 제거** (msg `1546395217618542712`)~~
    - ~~i18n `earth_gear_offer` = `"GEAR OFFER [B]: %s  $%d"` — `[B]` 제거.~~
    - 완료: EN `"GEAR OFFER: %s  $%d"`, KO `"장비 제안: %s  $%d"`. Test INBOX-61(20) GREEN.

  (21) ~~**일시정지 메뉴: 다시 시작 + 메인메뉴** (msg `1546395541850554480`)~~
    - ~~일시정지 상태에서 **다시 시작** 버튼 → `expedition.destroy` + `expedition.launch` (현재 런 초기화).~~
    - ~~**메인 메뉴로** 버튼 → `scene_stack.switch(titleScene)`.~~
    - ~~`game/scenes/title.lua` 신규: 배경 별 + 게임 타이틀 + "시작하기" / "이어서 하기" / "설정" (mok 패턴).~~
    - ~~"이어서 하기"는 저장된 `expedition` state가 있으면 활성, 없으면 비활성.~~
    - ~~`main.lua`가 PlayScene 대신 TitleScene으로 시작.~~
    - ~~설정은 빈 껍데기(언어/사운드 토글 자리).~~
    - 완료: pause overlay에 RESTART/MAIN MENU 버튼 추가, `game/scenes/title.lua` 신규 (별 배경 + 타이틀 + 시작/이어서/설정 버튼), `main.lua` TitleScene으로 시작, 캡처 모드는 직접 PlayScene. `onMainMenu` 콜백으로 양방향 전환. Test INBOX-61(21) GREEN.

  (22) **중심별 근처 "DANGER" 텍스트 + 태양 에셋 교체** (msg `1546396077832273940`)
    - ~~중심별(태양) 중력 우물 근처에 진입하면 **"DANGER"** 경고 텍스트 표시. 빨강 깜빡임, 우물 바깥 경계 부근에서 나타남.~~
    - ~~현재 태양은 노란 원 폴백. NASA 태양 사진 → 청키 4px PIL 파이프라인으로 화려한 에셋 교체.~~
    - ~~`tools/gen_sun.py` ≤50줄, 128×128 RGBA. 기존 `gen_stars_from_nasa.py` 패턴 활용.~~
    - ~~`assets/star/star_generic.png` 교체. `play.lua` draw에서 `starImage` 사용.~~
    - 완료: DANGER 경고 텍스트 — `world.starDangerTextMultiplier=1.5` 범위 내 접근 시 빨간 깜빡임 텍스트 4개가 well ring 주위를 천천히 회전하며 표시. i18n EN="DANGER"/KO="위험". 태양 에셋은 이미 `tools/gen_stars.py`로 6종 star sprite + rotation sheet 생성 완료 (노란 원 폴백 아님). Test INBOX-61(22) GREEN.

  (23) ~~**메인메뉴 리더보드 + 로컬 서버** (msg `1546396453734326293`)~~
    - ~~타이틀 씬 (21)에 **리더보드** 버튼 추가.~~
    - ~~Mac mini 로컬에 가벼운 HTTP 서버 (`tools/leaderboard_server.py`, Flask 또는 http.server + JSON 파일).~~
    - ~~API: `POST /score` `{name, bestAltitude, timestamp}` → append. `GET /scores?limit=20` → top 20.~~
    - ~~게임: 게임오버 또는 착지 시 `bestAltitude` 갱신되면 서버에 POST. 타이틀 리더보드 화면에서 GET 후 표시.~~
    - ~~LÖVE HTTP: `love.thread` + `luasocket` 또는 `os.execute curl` 비동기. 연결 실패 시 조용히 스킵.~~
    - ~~서버 포트 고정 (예: 8770). `conf.lua`에 `leaderboardUrl` 설정.~~
    - 완료(a): LEADERBOARD 버튼 title scene에 추가, `game/scenes/leaderboard.lua` scene (GET /scores 표시), `game/game_config.lua` (leaderboardUrl=8770), `tools/leaderboard_server.py` (POST /score + GET /scores), i18n EN+KO, main.lua 연결. Test INBOX-61(23) GREEN.
    - 완료(b): `game/leaderboard_client.lua` 신규 — `submitScore(name, bestAltitude)` fire-and-forget POST via `love.thread`. `isNewBest(run)` helper. `play.lua:persistBestAltitude()`에서 bestAltitude 갱신 시 자동 POST. settle/destroy 모두 `persistBestAltitude()` 경유하므로 양쪽 커버. headless/서버 미접속 시 silent skip. Test INBOX-61(23b) GREEN.

  (24) ~~**게임오버 → 마지막 체크포인트 부활 + 메인홈 구성** (msg `1546397935804223528`, 정정 `1546398416471457792`)~~
    - ~~현재: 게임오버 → 아이템 1개만 keep → 지구(0,75)에서 리스타트, 모든 돈/업그레이드/장비 리셋.~~
    - ~~변경: **마지막 방문 체크포인트(허브/지구)에서 부활**. 단 돈·업그레이드·장비는 **기존대로 전부 리셋** + **keep-one(아이템 1개 선택) 유지**. 달라지는 건 **부활 위치만** (지구 고정 → 마지막 체크포인트).~~
    - ~~`run.lastCheckpointPosition = {x, y, galaxyId}` settle/settleAtHub 시 저장. `destroy` → ship 위치를 `lastCheckpointPosition`으로, 나머지(돈/업그레이드/장비) 리셋은 현행 유지.~~
    - 완료(a): `lastCheckpointX/Y` added to run state. `settle()` saves Earth or hub position. `destroy()` preserves checkpoint. `lastCheckpointOrEarth(run)` helper. `play.lua` uses checkpoint for destroy respawn. Test INBOX-61(24) GREEN.
    - ~~**새 게임**: 메인홈에서 `새 게임` = 전체 리셋 + 지구 시작. `이어서 하기` = 마지막 체크포인트.~~
    - ~~타이틀 메뉴 최종 구성: `이어서 하기` / `새 게임` / `리더보드` / `설정`.~~
    - 완료(b): Title menu CONTINUE / NEW GAME / LEADERBOARD / SETTINGS. NEW GAME resets bestAltitude+specimens then Earth start. CONTINUE gated on `bestAltitude > 0`. i18n EN/KO. Test INBOX-61(24b) GREEN.

  (25) ~~**슬롯 비용·보상 은하 거리에 비례** (msg `1546403099059429456`)~~
    - ~~현재: spinCost=$10 고정, 보상도 고정(SPEED+5/+20, DURABILITY+3/+10 등). 먼 은하에서 돈이 많아져도 슬롯 의미 없어짐.~~
    - ~~변경: `slotTier = 1 + floor(galaxyDistance / galaxyCellSize)`. spinCost = `$10 * slotTier`. MONEY 보상도 `spinCost * multiplier`로 이미 스케일됨. 비머니 보상도 tier에 비례: SPEED `(5*tier)/(20*tier)`, DURABILITY `(3*tier)/(10*tier)`, HARVEST `(0.04*tier)/(0.20*tier)`.~~
    - ~~`earthSlotSpin`에 `tier` 파라미터 추가하거나, `run`에서 `lastVisitedGalaxyId` → `world.galaxyAt` → 거리 계산.~~
    - ~~HUD에 스핀 비용 표시는 이미 `spinCost` 읽으므로 자동 반영.~~
    - ~~`tripleMultiplier` (solar 1.0 / fringe 1.5 / void 2.0)는 tier 위에 추가로 곱해짐.~~
    - 완료: `slotTier`/`slotSpinCostFor`/`galaxyDistance` in expedition. Named `galaxy:gx:gy` → hypot(gx,gy)*cellSize. SPEED/DURABILITY/HARVEST * tier. HUD/spin/refund use `slotSpinCostFor`. Test INBOX-61(25) GREEN.

  ~~(27) **에셋 스튜디오 sprite-gen 서버 연동** (msg `1546408506700337213`)~~
    - 완료: `tools/serve_editors.py` POST `/api/sprite-gen` `{prompt,width,height,image?}` → PNG base64. Tries `sprite-gen` package, else deterministic PIL shapes. `editor.js` `generateFromPromptAsync` fetch + local fallback. Test `tools.test_serve_editors` GREEN.

  (28) **부스트 버튼 UI + 부스트 중 RCS 강화** (msg `1546408800070934598`)
    - 우측 하단에 **BOOST 버튼** 시각적으로 표시 (44×44 이상, 충전 수 표시, 0이면 비활성 회색).
    - 부스트 활성 중 RCS 파티클: radius ×2.5, 속도 ×2, 스폰 쿨다운 0.045→0.02, 색상 금빛 `(1, 0.85, 0.3)` 오버라이드.
    - 부스트 활성 중 화면 가장자리에 짧은 속도선(speed lines) 이펙트 추가.

  (29) **행운 % 표시 + 헬프(?) 아이콘 + 게임 설명** (msg `1546409329245036554`)
    - 행운 수치를 **퍼센트**로 표시 (`luck +10` → `행운 +10%`). `i18n effect_luck` 포맷 `"행운 +%d%%"` / `"LUCK +%d%%"`.
    - HUD 우측 상단, 일시정지 버튼 옆에 **? 헬프 아이콘** (44×44 터치).
    - 탭하면 오버레이 패널:
      - **행운**: 드롭 희귀도 상향 / 에디션 확률 8%+luck% / 슬롯 HARVEST 가중 ×(1+luck/100)
      - **수확**: 표본 판매 배율
      - **연속**: 같은 계열 연쇄 시 보너스
      - **부스트**: 우측 하단 탭, 0.8초 3배속
      - **시너지**: 같은 수트 부품 조합 효과
      - **슬롯**: 심볼 매칭 규칙
    - Balatro 스타일 다크 패널, 닫기=아무 곳 탭.

  ~~(30) **타이틀: Sid Meier's 스타일 "Jimmy's 우주선"** (msg `1546411241927614506`)~~
    - ~~제목 위에 작고 회색 `"Jimmy's"` (22px, `(0.55, 0.55, 0.58)`).~~
    - ~~본 제목 `우주선` / `SPACESHIP` (기존 큰 폰트).~~
    - ~~i18n `title_author = "Jimmy's"` (EN/KO 동일). `title_game_name` 유지.~~
    - 완료: title.lua에 22px "Jimmy's" + 44px 타이틀 이미 구현됨 (이전 사이클). i18n `title_author` EN/KO 존재.

  (32) **거대 파일 금지 + INBOX 최대 병렬** (사용자 2026-09-07)
    - 원본: `docs/MODULE_STRUCTURE.md`. 800줄/80KB Lua에 기능 붙이지 말 것. 슬라이스=모듈 1개.
    - `play.lua`(≈5059줄)를 `game/scenes/play_hud.lua` / `play_slot.lua` / `play_shop.lua` / `play_boost.lua` / `play_help.lua` / `play_gameover.lua` / `play_joystick.lua` 로 분리한 뒤에야 (22)(28)(29) 병렬 가능.
    - 처리 대기를 **파일이 안 겹치는 단위로 최대로** 워크트리 병렬. 담당 모듈 경로를 각 항목에 적을 것.
    - **즉시 WT 가능 (모듈화 대기 없음):** (26) JSON+`game/gear.lua`, (27) `tools/asset-studio`+`serve_editors.py`, (36) `assets/sfx`+`game/sfx.lua`.

  ~~(33) **허브와 중심별 절대 겹침 금지 + 중심별 스프라이트 이상** (msg `1546414575241396264`)~~
    - ~~담당: `game/world.lua` `hubPlanet` (play.lua 드로우 금지).~~
    - ~~허브 디스크와 중심별(`starRadius=80`)이 절대 겹치지 않게: `dist >= starRadius + hub.radius + padding`(≥40). 현재 `max(80, radius*0.18)`는 태양 r=80과 허브 r=40~56이 겹침.~~
    - ~~중심별 스프라이트가 초록 X 쿼드/시트 버그(원형 마스크·회전 중심). 시트면 프레임 쿼드가 몸통을 덮게. NASA/청키 원형만.~~
    - 완료: `hubPlanet()` minDist = starRadius + hubRadius + 41 으로 겹침 방지. 중심별 스프라이트 초록 X는 (14)에서 이미 수정(pngColorType 메모리 실패 + 시트 회전 중심). Test INBOX-61(33) GREEN.

  (34) **시너지 표기가 팝업에 없음** (msg `1546413969718378588`)
    - 담당: `game/scenes/play.lua` gearPopup 하단 (모듈화 후 `play_hud.lua`). 이름+설명 두 줄, 기호 금지.

  (35) **슬롯 실제 결과가 3심볼만** (아이들 5종 아이콘은 있음)
    - 담당: `game/expedition.lua` `earthSlotSpin` + play 스핀 호출.
    - `math.random(1,10)` vs 가중치 합 20 → DURABILITY/HARVEST 미추첨. `random()*totalWeight`로.

  (36) **SFX 3종** (msg `1546415750342770748` + Pixabay 충돌)
    - 담당: **새** `game/sfx.lua` (play.lua에 붙이지 말 것). 에셋 이미 `assets/sfx/`.
    - `galaxy_discover.mp3` — 새 은하 발견 또는 은하까지 거리 ≤5셀일 때 1회.
    - `star_sample.mp3` — 중심별 표본 추출 진행 중 루프, 우물 벗어나면 stop.
    - `collision.mp3` — Pixabay "Deep Impact Sound Effect" (BryanSantosBreton, Content License, id 176434). 행성/파편 충돌 시 원샷.

  (31b) **허브 내구 회복 제거 + hullRegen 부품** (msg `1546411887430991913`)
    - 담당: `game/expedition.lua` launch 힐 스킵 + `game/gear.lua` hullRegen + `game/data/hull_parts.json`. 허브 UI 힌트는 play.lua라 모듈 분리 후 또는 루프 dirty가 아니면.

  (37) ~~**gear-editor에 시너지 표기/수트 편집 없음** (msg `1546415792424488970`)~~
    - 완료: 상단 시너지 7종 패널 + 카드 Suit 셀렉트/칩. `KNOWN_SUITS` ↔ `gear.knownSuits`. 기호 없음. Test INBOX-61(37) GREEN.

  ~~(40) **gear-editor 부품 이름·설명 한글 + KO/EN 토글** (msg `1546415792424488970` 후속)~~
    - 완료: 툴바 KO|EN 토글 + localStorage `gear-editor-locale`. KO=nameKo + effect/rarity/suit/synergy KO, EN=name + i18n EN. 기호 없음. Test `tools.test_gear_editor_locale` GREEN.



  ~~(38) **타이틀/게임 BGM 플레이리스트**~~ (msg `1546416154589925406`, 추가 `another-space-background-track`)
    - 담당: **새** `game/bgm.lua` + `game/scenes/title.lua` (play.lua 금지). `main.lua` update에서 `bgm.update()` 한 줄.
    - 트랙 1: FoxSynergy "Blue Space" v0.95 MP3, CC-BY 3.0 — `assets/sfx/title_bgm.mp3`
    - 트랙 2: yd "ObservingTheStar" OGG, CC0 — `assets/sfx/observing_the_star.ogg`
    - 한 곡이 끝나면 다음 곡. 개별 루프 금지. 타이틀 enter에서 start, 플레이 중에도 유지(leave에서 stop 하지 않음).
    - 헤드리스 `love.audio` nil 가드.
    - 크레딧 11px: `BGM: Blue Space — FoxSynergy (CC-BY 3.0) / Observing the Star — yd (CC0)`
    - 완료: `game/bgm.lua` 생성, 플레이리스트 루프, title scene enter에서 start, main update 연동. i18n 크레딧 적용. Test INBOX-61(38) GREEN.

  ~~(42) **게임 배경음: OpenGameArt Space (orchestral)** (msg `1546416973133389855`)~~
    - 완료: `game/bgm.lua` 한 곡 루프 `assets/sfx/space_orchestral.mp3` (이미 커밋된 mp3). i18n EN/KO `title_bgm_credit` = `BGM: Space — lasercheese (CC-BY 3.0)`. 헤드리스 audio nil 가드 유지. Test INBOX-61(42) GREEN.

  ~~(43) **gear-editor 엔진 파츠도 초기 클릭 시 현재 JSON 자동 로드** (msg `154641...` 후속)~~
    - 완료: Hull|Engine 탭. `hullPool`/`enginePool` 분리. `autoLoadDefaults`는 hull만. Engine 첫 클릭에 `/gear-editor/data/engine_parts.json` fetch. 파일 피커 덮어쓰기 유지. Test `tools.test_gear_editor_engine_tab` GREEN.

  ~~(44) **발라트로 조커식 부품 효과 다양화** (namu.wiki Balatro/조커 카드#s-6, 사용자 2026-09-07)~~
    - 완료: JSON 전수 재배치 — 한 장=한 정체성. 엔진에서 헐-온리 효과 제거. `validatePart`가 `mode` persist. Test GREEN.

  검증: 해당 소항목 self_test + `SPACESHIP_UNIT_OK` / `SPACESHIP_SMOKE_OK`. 커밋 메시지에 소항목 번호.
  이미 커밋된 것(재큐 금지): 수확 +1% `7d34de2`, 표본라벨 `be27a9a`, 시너지 이름 prefix `074f5f7`(포맷은 (6)이  supersede), 상점 LV 배너 제거 `15de44e`, 위성 속도 데미지 `074f5f7`.

## 처리 완료
(61.33) **허브와 중심별 절대 겹침 금지 + 중심별 스프라이트 이상:**
  - 완료: `world.lua` `hubPlanet()` minDist = starRadius + hubRadius + 41 으로 허브 디스크가 중심별과 겹치지 않게 보장. 중심별 스프라이트 초록 X 버그는 (14)에서 이미 수정(pngColorType + 시트 회전 중심). Test INBOX-61(33) GREEN.

(61.30) **타이틀: Sid Meier's 스타일 "Jimmy's 우주선":**
  - 완료: title.lua에 22px "Jimmy's" (0.55,0.55,0.58) + 44px 타이틀 구현 완료 (이전 사이클). i18n `title_author` EN/KO 존재.

(61.41) **쌍성 시너지 착지 +$30 농장 금지** (OOB 2026-09-07)
  - 완료: `game/expedition.lua`의 `settle` 및 `settleAtHub`에서 착지 시 고정금액 +30 대신 `pendingSampleValue` * 1.3 (+30%)을 적용하도록 변경. `i18n.lua` 텍스트 수정 완료. `INBOX-61(41)` 테스트 GREEN.
(61.42) **게임 배경음 Space orchestral:**
  - 완료: `game/bgm.lua` 플레이리스트를 lasercheese "Space (orchestral)" 한 곡 루프로 교체. 트랙 `assets/sfx/space_orchestral.mp3`. `title_bgm_credit` EN/KO = `BGM: Space — lasercheese (CC-BY 3.0)`. `game/tests/bgm.lua` + `GAME_HEADLESS=1 GAME_UNIT=1` GREEN. play.lua 미수정.

(61.43) **gear-editor 엔진 탭 자동 로드:**
  - 완료: Hull|Engine 탭 클릭이 `selectPool`로 전환. `hullPool`/`enginePool` 메모리 분리. `autoLoadDefaults()`는 hull만 fetch. Engine 탭 첫 클릭 `ensureEngineLoaded()` → `/gear-editor/data/engine_parts.json`. 파일 피커는 덮어쓰기용 유지. `python3 -m unittest tools.test_gear_editor_engine_tab -v` GREEN. play.lua / self_test.lua untouched.

(61.44) **발라트로 조커식 부품 효과 다양화:**
  - 완료: 선체/엔진 JSON 전수 재배치 — 한 장=한 정체성 (커먼 단일, 언커먼 복합2, 레어 ×, 전설 +와 ×). 엔진에서 헐-온리(shopDiscount/sellMultiplier/insurance/money/sampleSellValue/hullDurability) 제거. `validatePart`가 `effects[].mode` persist (rare ×가 로딩 후 flat으로 사라지던 버그). i18n multiply 줄 `×N`. `tools/rebalance_joker_parts.py`. UNIT/SMOKE GREEN.

(61.40) **gear-editor KO/EN 토글:**
  - 완료: toolbar KO|EN (`localeKoBtn`/`localeEnBtn`), `localStorage` key `gear-editor-locale`. Grid uses `nameKo` in KO and `name` in EN. Effects/rarity/suit/synergy 7종 follow i18n (no symbols). `python3 -m unittest tools.test_gear_editor_locale -v` GREEN.

(61.27) **에셋 스튜디오 sprite-gen 서버 연동:**
  - 완료: `tools/serve_editors.py` serves the repo and `POST /api/sprite-gen`. Prompt → PNG base64 (`sprite-gen` if installed, else PIL procedural). Optional `image` base64 conditions the fallback. `tools/asset-studio/editor.js` fetches the endpoint; file:// falls back to the local xorshift still. `python3 -m unittest tools.test_serve_editors -v` GREEN.

  ~~(26) **부품 밸런스: common 스탯 상향 + uncommon 이상 발라트로 +/× 배수 체계**~~ (msg `1546406578733842492`)
    - common: 단일 효과, 값 최소 5 이상, 평균 ~10. 지금 1~3짜리 효과는 전부 5~12로.
    - uncommon: **+배수** (`addMultiplier`). 기존 효과에 **고정값 추가** (예: `speed +8` + `luck +5`). 복합 효과 2개.
    - rare: **×배수** (`scaleMultiplier`). 효과값이 **비율 곱**으로 동작 (예: `speed ×1.5`, `harvest ×1.3`). 새 effect type `"multiply"` 추가하거나, value를 `{"flat": N, "mult": M}` 구조로.
    - legendary: **+배수 AND ×배수** 복합 (예: `speed +10, harvest ×2.0`).
    - 완료(a): `gear.lua` `totalEffect` / `equippedTotals`가 flat sum + mult product를 분리 계산하도록: `final = (base + sum_of_flat) * product_of_mult`. JSON 스키마: `effects[].mode = "flat"|"multiply"` (기본 "flat", 기존 호환). `expedition.effectiveSpeed` 등에서 곱 적용.
    - 완료(b): `tools/gear-editor`에서 mode 필드 편집 가능하게. GEAR_SCHEMA 문서 반영.
    - hull_parts.json / engine_parts.json 전수 재조정.

    - 완료: Python 스크립트로 JSON 전수 재조정 완료. common(단일), uncommon(복합2), rare(multiply), legendary(flat+multiply) 적용. test fixtures(engine_emergency_boost_pod 등) 예외 처리 후 테스트 GREEN.


(61.37) **gear-editor 시너지 표 + Suit 편집:**
  - 완료: 상단 시너지 7종 패널(이름+조건, 기호 없음) + 카드 Suit 셀렉트/칩. `KNOWN_SUITS` ↔ `gear.knownSuits`. collectFormPart가 suit persist. Test `testGearEditorSuitAndSynergySync` in sync suite. UNIT/SMOKE GREEN.

(61.25) **슬롯 비용·보상 은하 거리에 비례:**
  - 완료: `slotTier`/`slotSpinCostFor`/`galaxyDistance`. spinCost=$10*tier. SPEED/DURABILITY/HARVEST * tier. HUD/spin/refund wired. Test INBOX-61(25) GREEN.

(61.8) **선체/엔진 부품 아이콘 + HUD 48px:**
  - 완료: `tools/gen_part_icons.py` 36줄, 32×32 RGBA chunky-4px icons for all 65 parts. Hull=shield silhouette, Engine=nozzle silhouette, suit colors (solar gold/nebula purple/void blue/pulsar cyan). HUD slot 32→48px. Icons in drawHudGearSlots/drawGearSlots/gearPopup/drawBalatroCard (keep-one). Shield/circle fallbacks removed. Manifest updated. GREEN.

(61.7) **등급·수트 칩 각 한 줄:**
  - 완료: Gear popup chips changed from horizontal side-by-side to vertical stack (rarity one line, suit below). Each chip centered independently. Tooltip height 220→256 to accommodate. `gearPopupChipVertical` flag + test. GREEN.

(61.6) **시너지 팝업 두 줄 + 기호 제거 + 보이드 채집 +30%:**
  - 완료: Removed ☀ * # ~ x + @ prefix symbols from all synergy names (EN+KO). Updated KO names (사건의 지평선 etc.). `i18n.synergyHint` returns `{name, desc}` table. Popup: 22px name line + 11px desc line, gold pulse if active, grey if not. eventHorizon changed from collisionRadius −30% to collectOrbitRadius +30%. `expedition.collectOrbitRadius(run, base)` added. Tests all GREEN.

(61.5) **솔라 3+ 착지 HP+1 이득 없음 → maxDurability+1:**
  - 완료: `expedition.settle()` solarSystem synergy changed from +1 HP heal (useless because launch() restores to maxDurability) to +1 maxDurability. i18n EN/KO updated. testINBOX61_5 verifies maxDurability increase survives through launch.

(61.4) **상점 카드 4줄, 세로 가운데, 내구도/정찰선 카피:**
  - 완료: 내구→내구도, >→->, scout tradeoff in-card, 4-line vertical center layout, external grey lines removed. testINBOX61_4 passing.

(61.3) **슬롯 UI: 레버 중복 제거, 크게 당김, 릴 정지마다 이펙트, 카피:**
  - 완료: PNG lever removed from gen_slot_machine.py, code-only lever with *150 pull. Sparkle particles on reel stop. haptic 0.03. i18n 탭하여 format. testINBOX61_3 passing.

(61.2) **슬롯 2/3매치 차등 + 전설 금지 + 중복 $10 환불 + 슬롯 풀이면 교체:**
  - 완료: earthSlotSpin PART branch pool에 hull+engine 양쪽 포함. 2매치=common/uncommon, 3매치=rare/legendary 래리티 게이트 동작 확인. 중복 환불·교체 UI 기존 코드 정상. testEarthSlotSpinPartRarityGate 테스트 추가 (engine pool 포함 검증).

(61.1) **에셋 스튜디오 웹에디터 (사용자 확정, 2026-09-07):**
  - 완료: `tools/asset-studio/` 정적 HTML+JS 웹에디터 구현.
  - File System Access API를 통해 `assets/`, `docs/GENERATED_ASSET_LOG.md`, `docs/assets/MANIFEST.json`에 원클릭 자동 반영되도록 개선 (gear-editor 패턴 완벽 준수).

(60) **지구 이미지 확대 + PIL 교체 (사용자 확정, 2026-09-06):**
  - 현재 `M.earthVisualRadius = 58`이지만 실제 이미지가 작아서 반응 영역과 불일치.
  - 변경: `M.earthVisualRadius = 90` (이미지가 settle 영역에 맞게 큼직하게).
  - PIL 지구 이미지 생성 (`tools/gen_earth.py`, ≤50줄): 128×128 RGBA, 파란 구체 + 녹색 대륙 + 흰 구름 도트. `assets/earth/earth_generic.png` 교체.
  - `make verify` GREEN + 커밋: `feat(earth): larger visual radius + PIL pixel-art Earth sprite`
  - ✅ 완료: earthVisualRadius 58→90, draw scale 116→180, fallback circle 58→90, PIL 128x128 earth sprite generated, tests updated.

(59) **잔해(debris) 랜덤 회전 (사용자 확정, 2026-09-06):**
  - 현재 잔해 스프라이트가 회전 0으로 그려짐. 자연스럽지 않음.
  - 변경: `world.debris()` 또는 play.lua draw에서 잔해별 고정 회전값 `rotation = hash(id, 970) * 2π` 추가. 추가로 시간에 따라 천천히 회전: `rotation + time * (hash(id, 971) - 0.5) * 2` (초당 ±1rad 자전).
  - draw: `love.graphics.draw(debrisSprite, x, y, rotation, scale, scale, iw/2, ih/2)`.
  - 폴백 원(`circle("fill")`)에는 회전 불필요.
  - `make verify` GREEN + 커밋: `feat(play): random rotation for debris sprites`
  - ✅ 완료: world.lua adds rotation/rotSpeed fields; play.lua uses junk.rotation for sprite draw.

(58) **허브 상점 재발사 버그 수정 (사용자 확정, 2026-09-06):**
  - 다른 은하계 체크포인트(hub) 행성에서 상점이 열리지만 재발사 탭이 작동 안 함.
  - 원인 조사: `touchpressed`에서 `key == "relaunch"` → `keypressed("space")` → `expedition.launch(run)`. `launch()`는 `run.phase == "settlement"` 허용. settle()은 `run.phase = "settlement"` 설정. 코드 경로는 맞음.
  - 가능 원인: (a) `settlementTouchRows[5]` 또는 relaunch 행이 터치 y 좌표 밖에 있음 (루프가 행을 추가/제거하면서 인덱스 어긋남) (b) hub settle 시 상점 패널이 relaunch 행을 가리거나 touch hit test에서 누락.
  - 수정: hub settlement에서도 relaunch touch가 확실히 작동하도록 디버깅 + 수정. `make verify`에 hub relaunch 테스트 추가.
  - `make verify` GREEN + 커밋: `fix(play): hub shop relaunch touch must work`


(55) **상점 하단 — 슬롯/기어오퍼/NEXT SCOUT 제거, 재발사+함선선택만 남기기 (사용자 확정, 2026-09-06):**
  - 상점 draw에서 `settlementTouchRows[3]`(슬롯) 영역: 기어 오퍼 텍스트 + 슬롯머신 + SOLAR ODDS 등 전부 제거.
  - `settlementTouchRows[5]`(재발사) 영역: NEXT SCOUT/STARTER 텍스트 (`nextLaunch.ship`, `nextLaunch.stats`, `nextLaunch.upgrades`) 제거. `tap_relaunch` 텍스트만 남기기.
  - Scout tradeoff 텍스트(L3584-3597)도 제거.
  - 남는 것: 상단 업그레이드 4행(hull/steering/yield/ship) + 재발사 버튼 + 함선 좌우 선택.
  - 슬롯은 별도 UI로 분리 예정 (52에서 이미 리디자인됨).
  - ✅ 완료: commit `c4ec930` (inbox: shop bottom cleanup, RCS continuous gradient 1-999, background star grid fix (55-57))

(56) **RCS 색상·크기 — 속도 1~999 연속 그라데이션 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `c4ec930`

(57) **배경 별 격자 패턴 개선 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `c4ec930`

(53) **부품 스탯 통합 + 불필요 효과 제거 (사용자 확정, 2026-09-06):**
  - (a) climbSpeed + speed + steeringResponsiveness → `speed` 통합: ✅ commit `6fde761`
  - (b) fuelEfficiency 제거: ✅ commit `1e643ae`
  - (c) 부품 효과 종류 최종 목록: ✅ 코드가 목록과 일치 (rerollBonus 추가 포함)

(54) **부품 웹에디터 + PIL 아이콘 생성 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `99b0ce5` (parts editor + PIL icons)

(48) **중심별 타이머 텍스트 개선 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `26a2e64` (hub shop, star timer text, moon radius 1.3x, gear popup, shop boxes (47-51))

(49) **위성 수집 반경 1.3배 확대 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `26a2e64`

(50) **장착 슬롯 터치 → 장비 상세 팝업 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `26a2e64`

(51) **상점 메뉴 박스 형태 추가 (사용자 확정, 2026-09-06):**
  - ✅ 완료: commit `26a2e64`

(52) **슬롯머신 리디자인 — PIL 심볼 생성 + 터치 릴 스톱 + 새 배당 (사용자 확정, 2026-09-06):**
  - **심볼 5종 PIL 생성** (`tools/gen_slot_symbols.py`, ≤50줄):
    - `assets/slot_symbols/money.png` 32×32 — 금색 코인/달러 모티프
    - `assets/slot_symbols/part.png` 32×32 — 기어/렌치 모티프 (부품)
    - `assets/slot_symbols/speed.png` 32×32 — 번개/화살 모티프
    - `assets/slot_symbols/durability.png` 32×32 — 방패 모티프
    - `assets/slot_symbols/harvest.png` 32×32 — 결정/보석 모티프 (수확)
  - 색조: 어두운 배경에 밝은 도트, PixelPlanets 톤. RGBA, 투명 배경.
  - **슬롯 본체**: `tools/gen_slot_machine.py` PIL — 3칸 가로 프레임 (96×48 정도), 기계 테두리 + 레버.
  - **릴 동작**: 3개 릴이 동시에 스핀 시작. 사용자가 **터치할 때마다 릴 1개씩 순서대로 멈춤** (왼→중→오). 멈출 때 감속 애니메이션 (빠르게 → 천천히 → 정지). 3개 다 멈추면 결과 판정.
  - **배당 (기존 시스템 교체)**:
    - miss (0 일치): **스핀 비용만 차감** ($10 기본), 보상 없음
    - 2개 일치: **스핀 비용 × 3** 획득
    - 3개 일치: **스핀 비용 × 10** 획득
    - 심볼별 추가 효과:
      - 💰 돈: 위 배당 그대로 현금
      - ⚙️ 부품: 2매치 → common 부품 드롭, 3매치 → rare/epic 부품 드롭 (레어도 상승)
      - ⚡ 속도: 2매치 → 다음 1회 속도 1.5배 버프, 3매치 → 영구 속도 +1
      - 🛡️ 내구도: 2매치 → HP 1 회복, 3매치 → HP 전체 회복
      - 💎 수확: 2매치 → 다음 3회 수확량 2배, 3매치 → 다음 10회 수확량 3배
  - **가중치**: 돈 30%, 부품 15%, 속도 20%, 내구도 15%, 수확 20%. 에디터(slot-editor)에서 조절 가능.
  - 기존 `slotSymbols = {"COMET","PLANET","STAR"}` + `slotReward` 전부 교체.
  - `expedition.earthSlotSpin` 리턴에 `stoppedReels`, `matchCount`, `matchSymbol` 추가.
  - play.lua draw: 슬롯 영역에 3칸 릴 애니메이션. 각 칸에 심볼 PNG 스크롤. 터치 시 `self.slotState.stopNext()`.
  - `make verify` GREEN + 커밋 순서: (a) PIL 심볼+본체 생성 (b) 릴 스톱 로직 (c) 배당 교체 + draw

(46) **"신규 행성 발견" 텍스트 제거 — 완료 2026-09-06:** draw에서 `planet_new_discovery` elseif 블록 제거. i18n 키는 유지. `make verify` GREEN.
(45) **미니맵 은하 밀도 + 링 오퍼시티 — 완료 2026-09-06:** (a) `galaxyExistenceThreshold` 0.82→0.85 (밀도 ~18%→~15%). (b) 동심원 링 알파 0.4→0.15, galaxy boundary ring 알파 0.55→0.12. 비-containing 은하 마커 숨김은 이전 사이클에서 완료. 테스트 갱신 (밀도 <20%, 알파 검증). `make verify` GREEN.
(44) **선체 정보 → 미니맵 아래 우측 — 완료 2026-09-06:** `drawShipStatsSummary()` 메서드 추가. ascending 때 미니맵 아래 우측에 22px 폰트로 함선명/속도LV/내구LV/수확LV 4줄 우측정렬 표시. settlement/destroyed/launch에서는 비표시. i18n 4키 EN+KO 추가. 테스트 INBOX-44 블록 추가. `make verify` GREEN.
(43) **HUD 아이콘 교체 — PIL 생성 — 완료 2026-09-06:** `tools/gen_hud_icons.py` PIL 스크립트로 16×16 RGBA 아이콘 3개 생성 (icon_distance/icon_cash/icon_durability). `play.lua` hudIconImages 경로 업데이트. 테스트 16×16 호환. `make verify` GREEN.
(42) **장착 네모칸 가로→세로 배치 — 완료 2026-09-06:** `drawHudGearSlots` 가로 배열을 세로 1열로 변경. x=5 고정, y를 HUD 아래부터 32px+4px 간격으로 내려감. hull 6칸 → 8px gap → engine 3칸. 총 높이 ~332px. 테스트 갱신 (horizontal width→vertical height assert). `make verify` GREEN.
(41) **HUD 폰트 크기 — launch 때만 큼, ascending과 동일하게 고정 — 완료 2026-09-06:** `M.hudFontSize` 44→22, `M.hudLineStep` 52→30, icons 32→16px, `hudBackgroundMaxWidth` 500→280. launch-only font override 제거 (`previousHudFont`/`isLaunchHud` 분기). `M.launchHudHeight` 제거. 모든 페이즈에서 init 시 설정된 22px 폰트 사용. `make verify` GREEN.
(40) **장착장비 패널 → 좌상단 HUD 아래 고정 노출 + 아이템 칸 확대 — 완료 2026-09-06:** `drawHudGearSlots(hudHeight)` 메서드 추가. 32×32px 슬롯 그리드 (hull 6 + engine 3), rarity별 배경색 + 아이콘 오버레이, 빈 슬롯 어두운 테두리. "GEAR"/"장착" 라벨 22px. ascending/returning/launch 때 좌상단 HUD 아래 고정. `make verify` GREEN.
(39) **시작 화면 "탭하여 발사" 위치 이동 — 완료 2026-09-06:** messageY를 `launchLoadoutBoxTop - 50 + sin(time*2)*4` 플로트로 이동, 텍스트 색 `(0.6,0.6,0.6,0.7)`, 로켓 아이콘 함께 이동. `make verify` GREEN.
(38) **HUD 텍스트 2배 + 한줄씩 + 내구도 네모칸 + 최고기록 (사용자 확정, 2026-09-06):**
  - **(a) HUD 폰트 2배.** `M.hudFontSize = 22` → **44**. Galmuri11 44px (11×4). `M.hudLineStep`도 비례 확대 (36→52 이상).
  - **(b) 한 줄에 하나씩.** 현재 거리·자금이 같은 줄에 나란히. 변경:
    - 1줄: 은하 이름 (있으면)
    - 2줄: `거리 0088`
    - 3줄: `자금 $0`
    - 4줄: 내구도 (네모칸)
    - 5줄: `최고기록 3227`
  - **(c) 내구도 = 네모칸 시각화.** `H3/3 발사` 텍스트 대신, `maxDurability`개 네모(12×12px)를 나란히 그림. 현재 HP만큼 채워진 색(초록→노랑→빨강 그라디언트), 빈 칸은 어두운 회색 테두리. `love.graphics.rectangle("fill"/"line")`.
  - **(d) 최고기록.** `hud.best`를 ascending 때도 표시 (현재 launch/settlement에서만). 은하 이름 바로 다음 줄.
  - **(e) `hudHeight()` 재계산.** 5줄 × lineStep. `hudBackgroundWidth`도 한 줄 최대 폭 기준.
  - `make verify` GREEN + 커밋: `fix(hud): 2x font, one-stat-per-line, HP blocks, best record always visible`

(37) **위성 시스템 도입 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `world.planetHasMoon()` ~30% 확률, `world.moonForPlanet(planet, time)` 공전 궤도 반환. 반경 3~5px, 공전 반경 planet.radius+15~25px, 3초 주기. 표본 보상 $10 (10×행성). 충돌 데미지 행성 동일. 수집 반경 moonRadius+15. play.lua에서 수집/충돌/그리기 통합. i18n `moon_label` 추가. INBOX-37 전용 테스트 블록 추가. `make verify` GREEN.

(36) **행성 기본 표본 보상 $1로 하향 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `world.sampleValue()` → 고정 `return 1`. 거리 스케일 제거. `sampleTier`/`collisionDamage` 기존 거리 기반 유지. 혜성 50×$1=$50. 기존 테스트 값 갱신 + INBOX-36 전용 블록 추가. `make verify` GREEN.

(35) **혜성 시스템 도입 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `world.lua`에 comet 시스템 구현 (comets 테이블, spawnComet, cometPosition, tickCometSpawn, nearbyComets, cometSampleValue, cometCollisionDamage, resetComets). 첫 60초 후 보장 스폰, 이후 30초마다 30% 확률. 속도 80-120px/s, 반지름 8-12px. 보상 행성의 50배. `play.lua` 업데이트/드로우 루프에 혜성 수집/충돌 + 꼬리 파티클(노란→빨강) + "혜성"/"Comet" 라벨. i18n `comet_label` 추가. self_test INBOX-35 블록 추가. `make verify` GREEN.

(31) **미니맵 은하 2개 표시 원인 수정 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `minimap.view()` galaxy 엔트리에 `isContaining` 플래그 추가. `play.lua`에서 non-containing 은하 마커(점+다이아몬드) 비표시. containing 은하만 마커·링·허브 그림. `testMinimapGalaxyContainingFlag` 추가. `make verify` GREEN.

(30) **상점 — starter 정보 제거 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: scout 보유+선택 시 `shopLoadoutLines()`에서 `shipAction`/`shipStatus`/`shipAffordable` nil, `shipHidden=true`, `scoutTradeoff={}`. Draw에서 "SCOUT ✓" 표시. "v" 키/터치 no-op. 기존 테스트 갱신 + INBOX-30 커버리지 추가. `make verify` GREEN.

(29) **채집 줌인 축소 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `collectZoom.scale` 1.35→1.12. play.lua + self_test.lua 업데이트. `make verify` GREEN.

(34) **미니맵 — 은하 중심 겹침 방지 + 인접 은하 외곽 표기 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: (a) `galaxyExistenceThreshold` 0.72→0.82 (밀도 ~28%→~18%). 8-connected overlap filter 이미 적용. (b) `minimap.view()` → `nearestGalaxyRimMarker` 추가 (disc 밖 비-home 은하: dx/dy/distance/name/id). play.lua에서 cyan dot + 거리 레이블 disc rim에 그림. `testMinimapGalaxyRimMarker` 추가. `make verify` GREEN.

(33) **RCS 분출 색상·크기 — 속도 레벨에 따라 변화 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `expedition.rcsSpeedLevel(run)` 추가 (steeringUpgradeLevel 0→Lv0 white r1.5, 1-2→Lv1 red r2, 3-4→Lv2 blue r2.5, 5+→Lv3 rainbow r3). play.lua 파티클 생성 시 레벨별 색·반지름 적용. draw에서 `particle.radius or 1.5` 사용. self_test INBOX-33 블록 추가. `make verify` GREEN.

(32) **상하 이동 저항 수정 — verticalOffset ±90 clamp 제거 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `verticalOffset` 필드, `clampVerticalOffset()`, `verticalOffsetLimit` 삭제. 상하도 `ship.y += joyDy * speed * dt` 직접 이동 (무제한). `extraDy` 이중 적용 제거. 테스트 업데이트. `make verify` GREEN.

(28) **행성 밀도 절반 + 겹침 방지 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `hash(...,1) > 0.70` → `> 0.85` (30%→15%), `hash(...,7) > 0.96` → `> 0.98` (4%→2%). 겹침 방지: 2-planet 섹터에서 dist < (r1+r2+10)이면 두 번째 삭제. 테스트 `testPlanetDensityHalved`, `testPlanetOverlapPrevention` 추가. `make verify` GREEN.

(27) **행성 대각선 패턴 수정 — LCG hash 버그 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `world.planets()` hash 호출에서 `salt+i` 패턴을 `sectorX+i*K, sectorY+i*K2, salt` 패턴으로 변경. radius/hue/x/y 모두 수정. `testPlanetDiagonalHash` 테스트 추가. `make verify` GREEN.

(24) **표본 채집 줌인 + 타임슬립 1.25배 확대 (사용자 확정, 2026-09-06):**

(25) **잔해(debris) 가시성 — 크기 확대 + 확인 (사용자 확정, 2026-09-06):**
  - 현재 잔해 반지름: asteroid 3~7px, can 2~3px, scrap 2~4px. 모바일 720×1280에서 거의 안 보임.
  - 변경: asteroid `minR=8, maxR=16`, can `minR=5, maxR=8`, scrap `minR=5, maxR=10`. 약 2~3배 확대.
  - 잔해 드리프트 `vx/vy * time`이 시간 경과 시 섹터 바깥으로 밀어내므로, `time` 값을 `time % 30` 같이 래핑하거나, drift를 `sectorSize` 안으로 clamp하여 잔해가 항상 시야에 존재하게.
  - 색/스프라이트도 확인: `debrisImages.asteroid` 등이 nil이면 폴백 원이 그려지는데, 반지름이 작으면 1px 점.
  - 함선 고유 패시브 (22번) 확정 시 Fortress 잔해 면역과 연동.
  - `make verify` GREEN + 커밋: `fix(debris): enlarge debris radius for mobile visibility`

(26) **함선 고유 패시브 시스템 (사용자 확정, 2026-09-06):**
  - 사용자 확정: 함선마다 상점에서 올릴 수 없는 고유 패시브 1개.
  - 현재 `selectedShipId` = "starter" | "scout". `refreshShipStats`는 속도/체력만. 확장:
    - **Starter "Pioneer"**: 패시브 없음 (기본 체력 3, 속도 0)
    - **Scout "Comet"**: 수집 반경 +50% (`collectRadius = (planet.radius + 30) * 1.5`)
    - **Tank "Fortress"**: 잔해 데미지 면역 (`debrisDamage = 0`)
    - **Gambler "Joker"**: 슬롯 STAR 확률 2배 (`starWeightMultiplier = 2`)
    - **Explorer "Voyager"**: 미니맵 viewRadius 2배
  - `expedition.lua`에 `M.shipPassive(run)` 추가, `play.lua`에서 수집/잔해/슬롯/미니맵 분기.
  - 상점에 함선 구매 UI 확장 (현재 scout만). 가격: Comet 200, Fortress 300, Joker 250, Voyager 350.
  - `make verify` GREEN + 커밋: `feat(ships): unique passive per ship hull`
  - [2026-09-06] ✅ 완료: (a) `collectZoom = {timer=0.5, scale=1.35, planetX, planetY}` — 0.5초 카메라 1.35× 줌인, 함선-행성 중점 기준, lerp 복귀. (b) `timeSlip.scale` 0.3→0.24. 테스트 `INBOX-24 collectZoom + timeslip OK` GREEN.

(23) **지구 settle 반경 축소 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `earthSettleRadius` 88→68 (margin 30→10), `launchSpawnY` -63→-13 (margin 50→20), `earthReentryRadius` 174→145 (58*2.5). self_test `reentryR` updated to use `earthReentryRadius` directly. New INBOX-23 assertion block added. `make verify` GREEN.

(22) **함선 아이디어 — 사용자에게 제안 (논의 필요, 2026-09-06):**
  - [2026-09-06] human-gated: 사용자 응답 대기 중. 코드 작업 없음 — 사용자가 방향을 확정하면 스펙화.

(21) **거리 = 지구로부터의 함선 거리 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: `hudLines()` distance를 `run.altitude`(가상 누적 고도) 대신 `sqrt((ship.x - earthCenterX)^2 + (ship.y - earthCenterY)^2)` 유클리드 거리로 변경. `run.altitude`/`bestAltitude`는 내부(표본 가치·메타 리셋 등)에서 그대로 유지, HUD만 실거리 표시. 테스트 `distScene21` 추가(ship (300, -325) → Earth(0,75) 거리=500 확인). `make verify` GREEN.

(20) **미니맵 — 은하 클리핑 + 거리 확보 + 체크포인트 색 + 지구/태양 텍스트 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: (a) `love.graphics.stencil`으로 미니맵 디스크 내부만 렌더링 — 은하 링 overflow 방지. (b) `viewRadius`를 0.55*cellSize로 축소 + 인접 은하 boundary ring 생략으로 겹침 방지. (c) 체크포인트 은하=골드 펄스 별, HUB=마젠타 다이아몬드 — 별도 빨간 마커 없음(확인 완료). (d) Earth(HUB)/Star 텍스트 라벨 11px 회색, stencil 내부에서만 렌더링. 테스트 `testMinimapStencilClip` + `testMinimapEarthStarLabels` 등록·GREEN.

(19) **행성 텍스트 교체 — 표본가격·데미지 제거, 신규행성 발견 텍스트 + HUB/중심별/부품 텍스트 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: (a) sampleLabel/label 그리기 블록 삭제, collisionRisk() 유지. (b) 미발견 일반행성 위 "신규 행성 발견" sin 움직임. (c) HUB 위 "HUB"+"엔진부품 획득 가능" 마젠타. (d) 중심별 위 "중심별" 노란색. (e) SHOP 위 "SHOP"+"선체부품 획득 가능" 시안. i18n 4개 키 en/ko 추가. 테스트 GREEN.

(18) **일시정지 버튼 — 우측 상단 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: 44×44 터치영역 (668,8), ascending에서만 표시. 탭→paused 토글, paused면 update() early return(dt=0), 화면 중앙 "PAUSED"/"일시정지" 오버레이. 아무 곳 탭→해제. settlement/destroyed/launch에서 숨김. testPauseButton() 추가.

(17) **HUD 정리 — 개발 임시본 제거, 표본금액 HUD 줄 제거, 좌표 좌상단, 아이콘 확대, 겹침 수정 (사용자 확정, 2026-09-06):**
  - [2026-09-06] ✅ 완료: (a) devPlaceholder 상수/draw/i18n 전부 삭제. (b) samples HUD 줄 제거 — hudLines/hudHeight/draw에서 samples 분기 삭제, self_test 갱신. (c) hud_status_no_slots 포맷 `"H%d/%d %s"` — 좌상단에 hull+phase. (d) hullIconSize/cashIconSize 8→16, gap 4→6. (e) hudLineStep 16→22.

(16) **HUD 가로 검정띠 제거 (사용자 확정, 2026-09-05):**
  - `M:draw`가 `drawPanelSprite(shopEff.hudPanel, 0, 0, viewport.width, hudHeight)` / 폴백 `rectangle("fill", 0, 0, viewport.width, hudHeight)` 로 화면 가로 전체를 덮음. 미니맵 Y는 `hudHeight`에 묶여 있음.
  - 변경: HUD 배경은 **왼쪽 텍스트 폭만큼**만 (대략 텍스트+아이콘+패딩, 최대 ~280px). 오른쪽 별/행성이 비치게. 미니맵은 기존처럼 HUD 아래 우측. `hudHeight()` 숫자 자체는 미니맵 앵커용으로 유지해도 됨 — **full-width fill만 금지**.
  - `make verify` GREEN + 커밋: `fix(hud): stop drawing full-width black HUD band`

  - [2026-09-05] ✅ 완료: `PlayScene.hudBackgroundWidth`가 왼쪽 텍스트+아이콘+패딩 폭을 재고 `hudBackgroundMaxWidth`(280)로 캡. `M:draw` 폴백 rectangle/`drawPanelSprite` dest width가 viewport.width가 아니라 그 폭만 사용. `hudHeight()`는 미니맵 앵커용으로 유지. `testHudBackgroundNotFullWidth` GREEN.

(15) **지구상점 슬롯 — 겹침 해소 + 리스크 + 웹에디터 (사용자 확정, 2026-09-05):**
  - 상점 슬롯이 업글/기어 오퍼와 같은 밴드에 그려져 겹침. `settlementTouchRows[3]`(slot)과 `[4]`(relaunch) 레이아웃을 분리: 슬롯은 전용 행, 결과 패널이 다른 행 텍스트를 덮지 않게.
  - 슬롯 본체 스프라이트: itch **Caz PIXEL FANTASY SLOT MACHINE** (https://cazwolf.itch.io/pixel-slot-machine, NYOP, 상업 OK) 사용자 구매 후 `assets/slot/` 에 본체+레버. 구매 전엔 기존 `slot_spin_button.png` / 심볼 3종 유지하되 겹침만 먼저 고친다. ComfyUI 재생성 금지.
  - 리스크: 지금 `slotReward` miss도 **+$5**, pair +15, triple 40, STAR×3 = 75. 사용자는 "리스크가 거의 없음". 변경: **스핀 비용** (기본 10, 에디터로 조절) + miss **0**. pair/triple/jackpot은 에디터 JSON에서 읽기.
  - 웹에디터: `tools/gear-editor/` 패턴 복제 → `tools/slot-editor/index.html`+css+js. 심볼 이름/가중치/배당/스핀비용/은하 프로필(solar/fringe/void) 배율을 JSON으로 편집·저장. 런타임은 `data/slot_config.json` (없으면 현재 기본값).
  - `make verify` GREEN + 커밋 순서: (a) `fix(settlement): slot row no longer overlaps shop upgrades` (b) `feat(slot): spin cost + miss pays 0` (c) `feat(tools): slot-editor web UI`

  - [2026-09-05] ✅ 완료: (a) 상점 슬롯 레이아웃 겹침 분리 (b) 스핀 비용 도입 및 miss 0 적용 (c) slot-editor 웹 UI 구현 및 slot_config.json 런타임 적용 완료. make verify GREEN.

(14) **수집 궤도 링을 옅고 얇은 선으로 (사용자 확정, 2026-09-05):**
  - [2026-09-05] ✅ 완료: 수집 반경 `radius+30` 유지. 미발견 행성 궤도 링은 `setLineWidth(1)` + alpha 0.3 폴백 선. 불투명 `planet_rim.png`는 끄고 선만 사용. 반짝임/타격감 유지. `testFaintCollectOrbitRing` 상수/alpha 단언. `make verify` GREEN.

(13) **미니맵 은하 표현: 나선 → 동심원 (사용자 확정, 2026-09-05):**
  - [2026-09-05] ✅ 완료: `spiralArmCount`/`spiralRotation`/`spiralPointsPerArm`/`spiralWindTurns`/`spiralPoints`/`spiralHash` 전부 삭제. `M.concentricRingCount(galaxy)` 신규 (반지름 구간 2~5). `view.rings`에 `kind="concentricRing"` 엔트리 추가, `view.spiral`/`view.spiralGalaxyId` 제거. play.lua 나선 그리기→동심원 `circle("line")` (금색 0.9/0.75/0.3/0.4). self_test 검증 통과. `make verify` GREEN.

(12) **PixelPlanets(GitHub Deep-Fold / JS 포트)로 행성 모양 교체 (사용자 확정, 2026-09-05):**
  - [2026-09-05] ✅ 완료: PIL 생성 6종 pp_*.png (ice/lava/dry/gas/earth/bare, 64x64 RGBA), MANIFEST.json 등록, GENERATED_ASSET_LOG 기록, README MIT 크레딧 추가. play.lua `planetImagePathForPlanet` 배선 (starType→pp_<type>, hub/shop도 pp 우선·폴백 유지), 약한 hue tint (0.35 blend), `planetVariation` id 기반 회전/스케일 변주. self_test: 파일 존재·color type 6, resolve 배선 5케이스, planetVariation 결정론·범위 검증. `make verify` GREEN.

(11) **RCS 분출 한 줄 — 조이스틱 반대 방향만 (사용자 확정):**
  - [2026-09-05] 완료: bank/lift 분기 두 개를 단일 opposite-stick puff로 교체. 대각 입력 시 틱당 1개만 생성. self_test 3개 (vx<0, vy<0, diagPuffCount==1) GREEN.

(10) **미니맵: 가장 가까운 HUB를 화살표로 항상 가리킴 + HUB와 중심별 구분 (사용자 확정):**
  - [2026-09-05] 변경 A 완료: checkpointBeyond 조건 제거, 항상 화살표 표시 (도착 시만 숨김).
  - [2026-09-05] 변경 B 완료: hubPlanet 위치를 은하 중심(sun)에서 오프셋 (hash(gx,gy,580) 각도, galaxy.radius*0.18 거리). minimap.view()에 hubMarkers 테이블 추가. play.lua에서 마젠타 다이아몬드+펄스 링으로 hub 그리기. self_test 3개 검증 (hub≠sun 위치, hubMarkers 차트 좌표 분리, 화살표 방향).

(9) **은하 중심별(태양) 중력우물 + 도트 데미지 + 10초 생존 시 표본 (사용자 확정):**
  - [2026-09-05] 구현 완료: world.lua에 starRadius/wellRadius/dotInterval/survivalTime/gravityStrength 상수 추가. play.lua에 중력 당김, 0.5초당 1딜 DoT, 10초 연속 생존 시 표본 수집, HUD 타이머, 주황/빨강 우물 링 시각 효과 구현. self_test.lua에 5개 테스트 (우물 밖 무중력, 0.5초당 1딜, 10초 표본, 이탈 시 리셋, 은하당 1회).

(8) **미니맵 나선/링 색 — 전 은하 동일, 태양계 특례 제거 (사용자 확정):**
  - 현재 `play.lua` drawMinimap: milkyway 링/마커만 파랑 `(0.3, 0.55, 0.95)` / `(0.25, 0.55, 1)`, 나머지 은하는 전부 금색 `(0.9, 0.75, 0.3)`.
  - 사용자: 은하계 나선색은 모두 같아야 함. 태양계만 다른 이유 없음.
  - 변경: 링·나선·galaxy 마커를 **한 팔레트**로 통일 (금색 유지 권장: fill `0.9, 0.75, 0.3`, line alpha 0.55). milkyway `if ring.id == "milkyway"` / `if galaxy.id == "milkyway"` 색 분기를 제거.
  - Earth 마커(시안) / player(흰색) / 귀환 화살(주황) / 체크포인트 화살(마젠타) / sun(노란 별) 은 구분용이라 **유지**.
  - 나선 점(`view.spiral`)이 안 그려지고 있으면 금색으로 그려 넣을 것 (계산은 `minimap.view()`에 이미 있음).
  - `make verify` GREEN + 커밋: `fix(minimap): same spiral/ring color for every galaxy`
  - [2026-09-05] 구현 완료: milkyway 특례 제거 및 공통 금색 팔레트 적용.


(7) **미니맵 줌인 — HUB/중심행성이 보이게 (사용자 확정):**
  - 현재 `minimap.viewRadius = galaxyCellSize * 2.5` (≈11520px). 은하 디스크가 차트에서 ~10px, hub 행성은 서브픽셀.
  - 변경: `M.viewRadius = world.galaxyCellSize * 0.7` (현재 은하가 차트의 대부분을 채움).
  - 이웃 은하는 기존 `project()` 림 클램프로 가장자리에 점으로 유지. `chartRadius` / `galaxyCellRadius` / `checkpointSearchCellRadius` 는 그대로 (오프차트 화살표 유지).
  - hub 마커(`markerGalaxyHubRadius`)와 sun 마커가 현재 은하 안에서 서로 구분되게 그릴 것.  Milky Way는 Earth + Sun 둘 다 차트에 들어와야 함.
  - self_test의 viewRadius 의존 assertion (`Earth must clamp…`, `checkpointBeyond`)을 새 스케일에 맞게 수정.
  - `make verify` GREEN + 커밋: `fix(minimap): zoom in viewRadius 2.5→0.7 cells so hub/sun readable`
  - [2026-09-05] 구현 완료: minimap viewRadius를 0.7셀로 줌인, 인접 은하 림 클램프 유지, sun/hub 마커 분리 및 self_test 갱신.


(5) **지구 착륙 시 진입 이펙트 — 길게 흔들리는 대기권 진입 느낌 (사용자 확정):**
  - 지구 근접 → settle 판정 직전, 일정 거리 안에 들어오면 "착륙 진입" 연출:
  - 판정: `ship 거리 < earthRadius * 3` 이면 착륙 진입 시작 (settle 거리보다 넓은 구간).
  - **(a) 지속 흔들림:** ✅ 완료 — `self.reentryShake` 거리 반비례, draw `sin(time*60)*reentryShake` x 오프셋, settle 시 0. `shipShake`와 별도.
  - **(b) 슬로우모션:** 착륙 직전(거리 < earthRadius * 1.5) 0.6초간 dt를 0.5배로.
  - **(c) 화면 가장자리 붉은 발열:** 진입 구간에서 화면 가장자리에 반투명 빨간 비네트. 거리에 따라 alpha 0→0.3 증가. draw 마지막에 그리기.
  - settle 트리거 시점에 `reentryShake = 0` 초기화.
  - `make verify` GREEN + 커밋: `feat(play): atmospheric reentry shake + heat vignette on Earth landing`


- **행성 표본 채집 궤도 진입 시 타격감 이펙트 (사용자 확정):** ✅ 완료 — `game/scenes/play.lua`에서 수집 시 타임슬립, 카메라 흔들림, 화면 플래시를 구현함.
  - 행성 수집 반경(`planet.radius + 30`)에 진입하는 순간 다음 효과 동시 발동:

  **(a) 타임슬립 (슬로우모션):**
  - 진입 순간 `dt` 배율을 0.3으로 낮춰서 0.4초간 슬로우. 별·잔해·행성 궤도 반짝임 모두 느려짐.
  - 구현: `self.timeSlip = { timer = 0.4, scale = 0.3 }` → `update(dt)`에서 `dt = dt * timeSlip.scale` 적용 → timer 소진 시 해제.

  **(b) 카메라 흔들림 (셰이크):**
  - 이미 `self.shipShake` 메커니즘이 있음. 수집 시 `shipShake = 0.25`, `shipShakeMagnitude`를 tier에 따라 설정 (common=0.6, rare=1.0, epic=1.4).
  - 현재 충돌에서만 쓰는데, **수집 시에도** 발동하도록 수집 블록에 추가.

  **(c) 화면 플래시:**
  - 수집 순간 화면 전체에 0.15초간 흰색 반투명 오버레이(`love.graphics.setColor(1,1,1,0.3)` → `love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)`).
  - `self.collectFlash = 0.15` → draw에서 남은 시간 비례로 alpha 감소.

  **(d) 선체 펀치 스케일 (이미 있음):**
  - `spawnSampleParticles`에서 `shipScalePunch`가 발동됨 — 유지.

  - `make verify` GREEN + 커밋: `feat(play): timeslip + shake + flash on sample collection`


(2) **귀환 버튼 제거 + 지구 근접 시 자동 정착 (사용자 확정):**
  - 사용자: "귀환 버튼 불필요. 직접 지구로 돌아가서 근접하는 것."
  - 현재: `beginReturn` → `returning` phase → altitude 자동 감소 → `settle()`. 그리고 별도 귀환 터치 버튼(커밋 `9c6eba8`)이 있음.
  - 변경:
    - 귀환 버튼 UI + 터치 핸들러 제거.
    - `returning` phase 폐지. ascending에서 **직접 지구(0,0) 근처에 도달**하면 settle. 판정: `ship.x^2 + ship.y^2 <= (earthRadius + 30)^2` (중력장과 동일 범위).
    - `beginReturn()` 호출부 모두 제거. ascending에서 지구 방향으로 직접 조종해서 돌아가는 것.
    - `returning` phase 관련 HUD 표시("귀환 중" 등) 제거.
    - 관련 self_test assertion 업데이트.
  - `make verify` GREEN + 커밋.

(3) **귀환 시 순간이동 수정:**
  - (2)에서 returning phase 폐지하면 자동 해결. ascending에서 직접 이동하므로 순간이동 없음.

(6) **HUB 충돌 게임오버 금지 — 지구와 동일 취급 (사용자 확정, 최우선):**
  - 보고: HUB에 부딪히면 일반 행성처럼 데미지 → 게임오버.
  - 원인: `play.lua` 행성 루프에서 수집(`radius+30`)과 충돌(`radius+5` + `world.collisionDamage`)이 **모든** 행성에 적용됨. `planet.hub`도 예외 없음.
  - 변경:
    - `planet.hub` 및 `planet.isShop` 은 충돌 데미지 블록을 **건너뛴다** (지구처럼 근접=상호작용만).
    - hub 기존 상호작용 유지: 근접 시 `settleAtHub` + 은하당 1회 `exploreHub` 기어 드롭. shop 모달도 유지.
    - `self.collided[planet.id]` 를 hub/shop에 세팅하지 말 것 (데미지 경로 자체가 없어야 함).
    - self_test: hub에 `collisionDamage` 호출/내구도 감소가 일어나지 않음을 단언.
  - `make verify` GREEN + 커밋: `fix(play): hub/shop planets never deal collision damage`


- ✅ 완료(2026-09-05) **상점(settlement) UI 텍스트 겹침/깨짐 수정:**
  settlementRowStep 28→44, summaryRowStep 32→40, summaryBgHeight 70→170, panelTop 400→200, panelHeight 420→880, touchRowHeight 70→165.
  summary Y좌표 40px 간격 재배치 (248/288/328/368). self_test에 overlap 방지 assertion 추가. `make verify` GREEN.
- ✅ 완료(2026-09-05) **모바일 UI 전체 점검 및 재배치 — 7개 소항목 전부 완료:**
  (1) HUD 텍스트 12–14px, 행 간격 14px, hudHeight 비례 증가.
  (2) 미니맵 마커 반경 1.5배.
  (3) 조이스틱 크기/위치/deadzone 모바일 최적화.
  (4) 상점 터치 행 44px+, 중앙 배치, 폰트 확대.
  (5) 로드아웃 패널 하단 1/3, 슬롯 1.5배, 폰트 12px.
  (6) Destroyed 패널 확대, 터치 타겟 화면 하단 전체.
  (7) 귀환 버튼 300×48px, 불투명도 0.85.

- ✅ 완료(2026-09-05) **상점(settlement) 미도달 — returning→settle 전환 점검 (사용자 보고):**
  - 원인: 모바일에서 ascending→returning 전환을 트리거할 터치 UI가 없었음 (fuel 메카닉 없음, 키보드 'r'만 존재).
  - play.lua: ascending 단계에 "↓ RETURN TO EARTH" 터치 버튼 추가 (1190–1234, 260–460). 키보드 'r' 단축키도 유지.
  - i18n.lua: return_to_earth 키 en/ko 추가.
  - self_test.lua: 터치 버튼·키보드 → returning 전환 + returning → settlement 완주 테스트.
  - make verify GREEN.

- ✅ 완료(2026-09-05) **행성 팝인/팝아웃 수정 — nearbyPlanets 검색 반경 확대:**
  - play.lua update/draw: `nearbyPlanets(x,y,1)` → `nearbyPlanets(x,y,4)`, `nearbyDebris(x,y,1,t)` → `nearbyDebris(x,y,4,t)` — 4개 호출 전부 수정.
  - self_test.lua: 반경 캡처 테스트 추가 — rad==4 검증. make verify GREEN.

- ✅ 완료(2026-09-05) **Stellar Origin 수트 시스템 도입 — Balatro 스타일 그룹 시너지:**
  - (1) JSON 스키마: hull_parts.json + engine_parts.json 전체 카드에 suit 배정. gear.lua `M.knownSuits` 추가, 로더 경고.
  - (2) 시너지 엔진: `M.activeSynergies()` — 7개 시너지(solarSystem/nebulaField/eventHorizon/pulsarBurst/binaryStar/supernova/darkMatter) 모두 구현.
  - (3) expedition.lua 연동: collectSample/settle/equippedTotals 모두 synergy 참조.
  - (4) HUD 표시: loadoutLines()에 synergies 필드, 발동 시너지 금색 라벨 렌더링. i18n en+ko 7개 키 추가.
  - (5) self_test: testStellarSynergies() + testExpeditionStellarSynergies() + testStellarSynergyHUD() 전부 GREEN.
  - make verify GREEN. commit: feat(gear): Stellar Origin suit system + synergy engine (all 5 sub-items).



- ✅ 완료(2026-09-05) **RCS 분출 위치에 ship.angle 반영 (선택, 조이스틱 개선):**
  - play.lua: 가로 분출 위치/속도 → `perp = angle + pi/2` 방향 × 6px. 세로 분출 → `fwd = (cos/sin)(angle)` 방향 × 6px.
  - self_test.lua: 기존 `particles[1].x < ship.x` 단순 검사 → 각도 인식 기하학 검증(perpX/perpY 계산으로 0.5px 허용오차 비교)으로 교체.
  - make verify GREEN.

- ✅ 완료(2026-09-05) **잔해(debris) 충돌 즉사 → 고정 1 데미지로 완화:**
  - `play.lua` line 1727: `local damage = self.expedition.durability` → `local damage = 1`.
  - self_test.lua: 기존 즉사 단일 테스트 → (A) 전체 HP에서 1 데미지 생존 + (B) HP 1일 때 파괴 두 서브테스트로 교체.
  - 파티클·흔들림·floating damage text 그대로. make verify GREEN.

- ✅ 완료(2026-09-05) **모바일 해상도 최적화 + 별 분산 + 중력장 확대 + 행성 마커 + 은하 공유 특성 (5개 소항목 전부 완료):**
  - (1) conf.lua GAME_SCALE 기본값 3→1, play-density 밀도 캡처 확인.
  - (2) world.lua stars/backgroundStars x/y 교차 시드 독립, backgroundStarCount 120→200.
  - (3) play.lua 수집반경/시각 rim planet.radius+14→+30, 충돌반경 유지.
  - (4) i18n hub_label/shop_label 추가, 미발견 행성 상단 HUB/SHOP 레이블.
  - (5) world.lua M.galaxy() starType/starTypeIdx/baseHue 추가; M.planets() galaxyStarType + hue ±30° 클램프; play.lua galaxySpecialFrame으로 특수별 통일. make verify GREEN.

- ✅ 완료(2026-09-05) **미니맵 나선 팔 수를 은하 반지름 기반으로 결정 — 팔 간격은 균등 유지:**
  `game/minimap.lua` `M.spiralArmCount(galaxy)` 수정: hash 랜덤 → radius 구간(r<1000→2, r<1400→3, r<1800→4, else→5). make verify GREEN. 커밋: `fix(minimap): galaxy arm count from radius, not random`.

- ✅ 완료(2026-09-05) **PixelPlanets 픽셀별 스프라이트로 배경/전경 별 교체 (사용자 확정, 최우선):**
  PixelPlanets JS 포트(MIT)의 별 스프라이트 두 장이 이미 에셋에 반입됨:
  - `assets/space/pixelplanets_stars.png` (144×9 RGBA) — 17종 작은 픽셀별, 각 9×9 프레임
  - `assets/space/pixelplanets_stars_special.png` (150×25 RGBA) — 6종 큰 특수별, 각 25×25 프레임

  **구현:**
  1. `M.new()` 에 두 이미지 로드 추가:
     ```lua
     M.pixelStarsImage = loadSprite("assets/space/pixelplanets_stars.png")
     M.pixelStarsSpecialImage = loadSprite("assets/space/pixelplanets_stars_special.png")
     ```
  2. 별 스프라이트 드로우 헬퍼 `drawPixelStar(image, x, y, frameW, frameH, frameCount, frameIdx, size, r, g, b, a)` 추가:
     `love.graphics.newQuad(frameIdx*frameW, 0, frameW, frameH, iw, ih)` 로 프레임 잘라서 `love.graphics.draw`.
  3. `world.backgroundStars()` 루프 내에서 기존 `drawStarPointSprite` 대신:
     - `bright < 0.4` → `pixelplanets_stars.png` 17프레임 중 `starIdx = (hash % 17)` 프레임, size=2~3px, color=white, opacity=`0.15 + bright*0.4`
     - `bright >= 0.4` → `pixelplanets_stars_special.png` 6프레임 중 하나, size=4~5px, color=`#ffef9e`(황금), opacity=`0.5 + bright*0.5`
     - 이미지 없으면 기존 `love.graphics.rectangle("fill",...)` 폴백 유지
  4. `world.stars()` (전경 meteors) 루프도 동일하게: 일반 별은 size=3~4px, 특수별은 size=5~6px.
  5. `M.new()` 리턴 테이블에 `pixelStarsImage`, `pixelStarsSpecialImage` 포함.
  6. `make verify` GREEN + `GAME_CAPTURE_PHASE=launch` 캡처 경로 STATUS에 기록(PNG 미커밋).
  7. 커밋: `feat(stars): PixelPlanets pixel-art star sprites replace procedural points`

  **검증 기준:** 배경에 흰/황금 픽셀별 스프라이트가 보이고, `love.graphics.rectangle` 단색 점은 사라짐. `make verify` PASS.
  완료증거: SPACESHIP_UNIT_OK + SPACESHIP_SMOKE_OK + ASSET_MANIFEST_OK (2026-09-05).

- ✅ 완료(2026-09-05) **깨진 ComfyUI PNG는 다각형 폴백으로 빼고, 쓸 만한 것만 재생성 (2026-09-05, 사용자 확정, 최우선):** 런치가 깨져 보인 주원인은 RGB 불투명 64×64를 패널/이펙트로 그린 것. 투명 RGBA는 함선·지구·HUD 아이콘·표본만. 나머지 ~74장 RGB는 게임에 쓰면 블러/사각 덩어리. 비전 검토 없음. 한 사이클 = 아래 소항목 하나 + `make verify` GREEN + 커밋.

  (1) ✅ 완료(2026-09-05) **RGB 깨진 에셋 언와이어 + 다각형 폴백:** `loadSprite`는 PNG IHDR color type 6(RGBA)만 `newImage`. RGB(type 2) ~76장은 nil → 기존 Lua 다각형/원 폴백. 배경 타일 `deep_space_tile.png`는 계속 비활성(절차적 별만). 파일은 디스크/git에 유지.

  (2) ✅ 완료(2026-09-05) **함선/지구/행성 ComfyUI 재생성은 하지 말 것 (2026-09-05, 사용자 확정):** 너무 오래 걸려서 사용자가 이미지를 따로 가져와 연결한다. `ship_default`/`ship_scout`/`earth_generic`/`planet_generic`/`planet_hub`/`planet_shop`을 ComfyUI로 다시 뽑지 마라. 새 PNG가 INBOX/디스크로 올 때까지 현행 파일 유지하거나 (1) 폴백만. 연결 작업은 사용자가 파일을 준 뒤의 별도 항목.

  (3) ✅ 완료(2026-09-05) **은하/행성 다양성 — Deep-Fold PixelPlanets 검토 후 적용 여부:** MIT, PNG/GIF/spritesheet export. ComfyUI 행성 대체 후보. 한 사이클에 결정+프로토타입 1장(결정론적 시드=은하/행성 id) 또는 “적용 안 함”을 STATUS에 남김. Godot을 LÖVE에 임베드하지 말 것 — export PNG만. (적용 안 함: 헤드리스 Godot 자동화 제약으로 인해 기존 AetherAI/ComfyUI 파이프라인 유지 결정)

- **모든 시각 에셋 ComfyUI 전면 재생성 (2026-09-04, 사용자 확정, 최우선):** 런치 실행화면이 거대한 빨강/하늘색 블러 덩어리로 깨져 있다. 원인 두 가지를 **같은 항목에서** 고친다. (A) 현재 PNG 100장 중 89장이 64×64 RGB라 `drawPanelSprite`가 HUD/정산/상점 패널을 `viewport.width`(720)로 늘려 그린다. (B) 기존 ComfyUI 결과물이 실루엣·투명 배경·픽셀 밀도 모두 게임에 안 맞는다. 비전 검토 없이 생성→`assets/` 덮어쓰기→`docs/assets/MANIFEST.json` provenance→`docs/GENERATED_ASSET_LOG.md` 한 줄→`make verify` GREEN→커밋. 한 사이클 = 아래 그룹 하나(에셋 1~3장)만.

  (0) ✅ 완료(2026-09-05) **스케일 버그 먼저 (코드, 재생성 전 필수):** `drawPanelSprite`는 더 이상 64×64를 720×N으로 stretch하지 않는다. 이미지 없으면 기존 사각형 폴백, 있으면 원본 픽셀 크기. HUD 아이콘 `drawHudSpriteOrPoly` size 8~14px / 지구 지름 116px / 함선 논리 64px 유지. `GAME_CAPTURE_PHASE=launch` 캡처 경로만 STATUS에 기록(PNG 미커밋).

  (1) ✅ 완료(2026-09-05) **함선** — `assets/ship/ship_default.png`, `assets/ship/ship_scout.png`. 64×64, **투명 배경**, top-down 작은 은색 우주선 실루엣, 픽셀아트, 본체가 프레임의 ~60%만 차지.

  (2) ✅ 완료(2026-09-05) **지구** — `assets/earth/earth_generic.png`. 64×64 투명 배경, 작은 푸른 지구 구체(대륙 실루엣), 가장자리 여백.

  (3) ✅ 완료(2026-09-05) **행성 3종** — `assets/planet/planet_generic.png` `planet_hub.png` `planet_shop.png`. 각 64×64 투명 배경, 작은 행성 구체. 한 사이클에 3장까지.

  (4) ✅ 완료(2026-09-05) **HUD 아이콘** — 9장 전부 32×32 RGBA 투명(풀블리드 아님). slice 1 coin/shield/speed, slice 2 distance/best/samples, slice 3 galaxy/return/earth.

  (5) ✅ 완료(2026-09-05) **패널·상점 행** — 64×64를 풀스크린으로 쓰지 말 것. 필요하면 코너/타일용 작은 PNG만 생성하고 draw는 (0)의 비-stretch 경로. 기존 `shop_panel`/`loadout_panel`/`destroyed_panel` 등 64×64 패널 PNG는 재생성하되 draw가 늘리지 않게 (0)이 선행해야 한다.

  원격 ComfyUI `http://222.238.86.132:8188`, workflow `7a3eb820-f17d-47ce-a337-da2358c2a0d5`, `tools/comfyui_asset_pipeline.py`. 배경 타일 `deep_space_tile.png`는 이미 비활성(격자 시밍) — 재생성하지 말고 절차적 별만 유지.


- ✅ 완료(2026-09-04) — **ComfyUI 에셋 draw 배선 복원 (2026-09-04, 사용자 확정):** gear 머지로 `game/scenes/play.lua`가 교체되면서 69개 ComfyUI 에셋이 로드는 되지만 draw에 연결되지 않은 상태다. 전체 우선순위 그룹 배선 완료.
  (1) ✅ HUD 아이콘 (2026-09-04)
  (2) ✅ 미니맵 마커 (2026-09-04)
  (3) ✅ 행성 이펙트 (2026-09-04)
  (4) ✅ 플로팅 텍스트 아이콘 (2026-09-04)
  (5) ✅ 런치·정산·파괴 패널 (2026-09-04)
  (6) ✅ 상점 아이콘 행 (2026-09-04) — 이번 사이클에서 Shop/HUD 패널 및 버튼 백그라운드 배선 완료. `make verify` 통과.


7. ✅ 완료(2026-09-04) — **함선 장비 획득 경로 3원화:** 장비 카드는 세 가지 방식으로 얻을 수 있다. (a) 각 은하계의 고정 좌표에 존재하는 "상점 행성"(신규 개념 — 은하마다 결정론적으로 하나씩, `game/world.lua`의 갤럭시 해시 방식을 재사용해 상점 행성 좌표를 고정 생성)에서 돈으로 구매. (b) 각 은하계의 중심 체크포인트 행성(기존 `M.hubPlanet`, 태양계는 지구에 해당하는 "은하 중심 행성" 개념)을 최초 탐사(착륙/근접 상호작용)하면 **확률이 아니라 해당 은하계 특유의 고유 장비 부품을 무조건 1개 확정 지급**. (c) 범용(은하 특정적이지 않은) 일반 등급 장비 부품은 지구 EARTH SHOP에서도 구매 가능 — 특정 은하 고유의 희귀 장비는 지구에서 판매하지 않는다. `game/world.lua`에 상점 행성 결정론적 생성 함수를, `game/expedition.lua`에 은하 중심 탐사 시 고유 장비 확정 드롭 로직을 추가하고 각각 `game/self_test.lua` 회귀 테스트로 검증한다.
  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목7(c) Earth shop gear offer UI 배선 + isFull 버그 수정): `game/i18n.lua`에 earth_gear_offer/earth_gear_bought/earth_gear_full/earth_gear_broke 4개 키(en/ko)를 추가했다. `game/scenes/play.lua` settlement 진입 시 `gear.earthShopPool`+`expedition.rollGearOffer`로 오퍼를 1장 생성해 `ea …(압축됨)
  8. ✅ 완료(2026-09-04) — **행성 탐사 보상은 표본만, 정산은 체크포인트에서만:** 은하계 내 일반 행성(체크포인트/상점 행성이 아닌 보통 행성) 탐사·채집은 오직 표본(sample)만 지급하며 돈으로 직접 환산되지 않는다. 표본을 돈으로 바꾸려면 지구 또는 그 표본을 채집한 은하계의 체크포인트 행성(중심 hub 행성)으로 복귀해야만 정산(settlement)이 발생한다. 이는 기존 `expedition.lua`의 `settle(run)`(지구 복귀 시 정산)을 확장해 은하 체크포인트 복귀도 같은 정산 트리거로 인정하는 구조 변경이 필요하다 — 현재는 지구 복귀(`run.altitude == 0`)만 정산을 트리거하므로, 은하 중심 체크포인트 근접/도킹도 부분 정산(해당 원정에서 그 은하까지 오가며 모은 표본만, 또는 전체 pending 표본) 트리거로 추가하는 방식을 설계해 구현한다. `game/self_test.lua`에 "체크포인트 복귀 시 표본이 정산되고 일반 행성 근접만으로는 정산되지 않는다"는 회귀 테스트를 작성한다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목 8 부분 정산 배선): `game/expedition.lua`에 `M.settleAtHub(run)`을 신규 추가했다. 일반 행성 탐사 시 `M.collectSample`이 돈이 아닌 `pendingSampleValue`만 올려주는 기존 구조를 재확인하고, `settleAtHub`가 호출될 때 `pendingSampleValue`를 `money`로 즉시 합산하며 `pendingSampleValue`를 0으로 비우도록 구현했다. 이는 비행 상태(`asce …(압축됨)
  9. ✅ 완료(2026-09-04) — **핵심 게임성 방향 — 발라트로 규모의 부품 다양성 + 조합(시너지) 중심 고도(점수) 상승:** 사용자가 게임의 재미 핵심으로 명시적으로 규정한 방향이다. 6종 정도의 장비로는 충분하지 않으며, 발라트로의 조커 카드 풀(150종 이상)에 준하는 **수십 종 규모의 선체 부품 카드 풀**을 설계해야 한다. 단순히 개별 부품이 각자 독립적인 수치 버프를 주는 것을 넘어서, **부품들의 조합(시너지)이 고도(distance-from-Earth 점수) 상승 속도/효율에 배가 효과를 내는 것**이 핵심 재미여야 한다 (발라트로에서 조커 조합이 점수를 기하급수적으로 불리는 것과 동일한 설계 철학). 다음을 다음 사이클들에 걸쳐 단계적으로 설계·구현한다: (a) `game/expedition.lua` 또는 신규 `game/gear.lua`에 부품 카드 데이터 테이블을 만들어 최소 20~30종 이상으로 시작해 점진적으로 확장한다 (아이콘 실루엣은 Lua 도형으로 우선 프로토타입). (b) 각 카드는 단독 효과 외에 "특정 계열/태그(예: azure/ember/void 표본 계열, 상승 계열, 방어 계열, 확률 계열 등)를 공유하는 다른 카드와 함께 장착 시" 추가 보너스가 발동하는 태그 기반 시너지 규칙을 순수 함수로 설계한다. (c) 슬롯 수(현재 6개)를 장비 장착 한도로 유지하되, 사용자가 매 사이클 다른 조합을 실험하고 싶어지도록 카드 획득(상점 구매/체크포인트 확정 드롭)과 교체가 잦아지는 루프를 설계한다. (d) `game/self_test.lua`에 개별 카드 효과 테스트뿐 아니라 대표 시너지 조합(예: 카드 A+B 동시 장착 시 고도 상승 배율이 단순 합보다 커야 함)에 대한 회귀 테스트를 반드시 포함한다. 이 항목은 규모가 크므로 한 사이클에 전량 구현하려 하지 말고, 카드 데이터 구조/시너지 엔진 설계 → 초기 카드 풀(10~15종) 구현 및 검증 → 이후 사이클에서 지속 확장하는 순서로 진행한다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-03, 항목9/14 (A) hullDurability gap 슬라이스): 레인이 지정받은 5개 항목(13→9→10→12→14)은 이전 사이클들에서 모두 1차 완료 상태였으나, 이 레인이 반복 적용해온 "문서-코드 정합성 감사" 패턴을 이번 사이클에도 다시 적용해 새 gap을 찾아 처리했다. `gear.equippedTotals`가 항목14 첫 슬라이스 때부터 (A) `hullDurability` 효과를 가산 합산해왔고, `hull_parts.json`에는 항목9의  …(압축됨)
  10. ✅ 완료(2026-09-04) — **부품 슬롯 이원화 — 선체(허브/조커형) 부품 + 엔진(타로/소모형) 부품 분리 (2026-09-02, 사용자 확정):** 발라트로가 조커 슬롯(상시 장착, 지속 효과)과 타로/행성/스펙트럴 카드 슬롯(소모형, 즉시 발동 후 소모되거나 덱을 변형)을 별도 슬롯군으로 두는 것처럼, 스페이스쉽도 항목 9의 "선체 부품"(상시 장착, 지속 패시브/시너지형 — 조커 역할)과 별개로 **"엔진 부품"이라는 두 번째 슬롯 카테고리**를 신설한다. 엔진 부품의 정확한 성격(상시 장착형 vs 소모형, 슬롯 수, 획득처)은 다음 사이클에서 설계하되, 최소한 다음을 만족해야 한다: (a) 선체 부품 슬롯(항목 9)과는 별도의 슬롯 목록/카운트를 가져 서로 슬롯을 잠식하지 않는다 — `run.equippedGear`(선체)와 별개로 신규 `run.equippedEngineParts`(가칭) 같은 독립 목록을 둔다. (b) 엔진 부품은 이름에서 알 수 있듯 추진/기동 계열에 특화된 효과(상승 가속, 연료 효율, 조종 반응성, 긴급 부스트/1회성 소모 아이템 등)에 집중해 선체 부품(내구도/채집/시너지 등 범용)과 역할이 겹치지 않도록 차별화한다. (c) 획득 경로는 항목 7의 3원화(상점 행성 구매/체크포인트 확정 드롭/지구 상점 범용 구매) 구조를 그대로 재사용하되, 엔진 부품 전용 카드 풀로 별도 관리한다. `game/gear.lua`(또는 신규 `game/engine_parts.lua`)에 데이터 구조를 분리 설계하고 `game/self_test.lua`에 "선체 슬롯과 엔진 슬롯이 서로 독립적으로 가득 차고 비워짐"을 검증하는 회귀 테스트를 추가한다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-03, 카테고리 무관 효과 콘텐츠 커버리지 슬라이스): `testGearEffectTypeContentCoverage`/`testEngineCardsHaveNonHullOnlyEffect`보다 한 단계 더 깊은 감사 — 카테고리 무관(hull/engine 둘 다 소비하도록 설계된) 효과 10종(luck/chainTrigger/rerollBonus/collisionRadius/detectionRadius/autoCollect/insurance/shopDiscount/ …(압축됨)
  11. ✅ 완료(2026-09-04) — **연료 소진 관련 잔재 UI/문구 전면 제거 (2026-09-02, 사용자 확정):** 실제 비행 로직(`game/expedition.lua`, `game/self_test.lua` 주석 "Fuel is no longer a flight constraint")은 이미 연료가 상승을 막지 않도록 no-op 처리되어 있으나, **UI/텍스트에는 여전히 "연료가 떨어지면(소진되면) 추락/귀환한다"는 옛 설계를 전제로 한 표현이 남아있다.** 다음을 찾아 전부 제거하거나 연료-무관 표현으로 재작성한다: (a) `game/scenes/play.lua`의 `launchForecastLine`/`M.launchForecast` — 함수명 자체와 `NO-HIT %d SLOTS %d`(`i18n.lua`의 `forecast_line`, "무피격 N")가 "이 연료(`maxFuel`)로 충돌 없이 갈 수 있는 고도"라는, 연료가 다 떨어지면 위험해진다는 프레이밍을 내포한다 — 연료와 무관하게 재정의하거나(예: 순수 기대 진행 거리/추천 장비 조합 안내로 대체) 완전히 제거한다. (b) `run.maxFuel`/`fuelUpgradeLevel`/`fuelUpgradeCost`/`fuelUpgradeAmount` 기반 "연료 업그레이드" 상점 항목(`stats_line`, `fuel_action_line`, `fuel_upgraded_message`, `fuelStatus`/`fuelAffordable`, `shipPreviewForecast`/`fuelPreviewForecast`) — 연료가 게임플레이에 아무 제약도 주지 않는 지금, "연료를 늘려야 더 안전하다"는 인상을 주는 구매 항목/문구는 오해를 유발하므로 제거하거나 별도 의미(예: 엔진 부품 슬롯의 소모성 자원 등, 항목 10과 연계 검토)로 완전히 재정의한다. (c) 코드 전반의 `run.fuel`, `fuelBurnRate`, `burnManeuverFuel` 등 죽은 연료 소모 로직/필드도 함께 정리(제거 또는 명시적으로 deprecated 주석 강화)해 향후 혼동을 줄인다. `game/self_test.lua`의 관련 테스트(현재 `forecast == "NO-HIT 600 SLOTS 6"` 등 하드코딩된 문구 검증)도 새 문구/구조에 맞춰 갱신한다.
  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목11 두 슬라이스 완료): (1) S%02d HUD 슬롯 카운터 제거(이전 슬라이스). (2) 이번 슬라이스: 정착/파괴 패널의 `spins_settlement_line`("SPINS (0) $0") 제거 — in-flight 슬롯 폐지로 lastSlotSpinsCount/lastSlotSettlement/lastLostSlotValue/lastLostSlotSpinsCount가 expedition.lua에서 영구 nil임을 감사 확인. `lost_tot …(압축됨)
 + 부수 효과(에디션) 시스템 — 발라트로식 파밍 재미 (2026-09-02, 사용자 확정):** 항목 9(선체 부품)·항목 10(엔진 부품) 카드 풀에 발라트로의 조커 등급/에디션 시스템과 동일한 구조를 적용해 "같은 부품이라도 뽑기마다 다르게 느껴지는" 파밍 재미를 추가한다. 두 축을 분리해 설계한다: **(A) 등급(rarity)** — 커먼(Common)/언커먼(Uncommon)/레어(Rare, 필요 시 레전더리까지 확장)로 부품 자체의 희소성과 강력함 단계를 나눈다. 등급이 높을수록 효과가 강하거나 다중 효과를 가지며, 상점/체크포인트 드롭 확률(항목 7)이 등급별로 차등 적용된다(레어일수록 희귀). **(B) 에디션(부수 효과, 발라트로의 홀로그래픽/네거티브/폴리크롬 등에 해당)** — 동일한 부품이라도 획득 시 추가로 부여될 수 있는 별도 수식 레이어. 사용자가 예시로 든 "방사능처리됨" 같은 테마 접두/접미 에디션을 스페이스쉽 세계관(우주 방사선·희귀 합금·양자 결함 등)에 맞게 3~5종 창작한다 (예: ⚠️ 방사능처리(Irradiated) — 시너지 태그 매칭 시 보너스 추가 증폭, ✨ 결정화(Crystallized) — 판매가 대폭 상승, 🌀 양자결함(Quantum-Flawed) — 효과가 두 배지만 부작용 하나 동반, 💠 정제(Refined) — 슬롯 점유 없이 보조 효과만 등, 발라트로의 네거티브처럼 "슬롯을 소모하지 않음" 컨셉도 후보). 에디션은 등급과 독립적으로 낮은 확률로 부여되어 동일 부품이라도 다른 개체가 나올 수 있게 한다. 구현: `game/gear.lua`(또는 `engine_parts.lua`)의 카드 데이터 구조에 `rarity` 필드와 `edition`(nil 가능) 필드를 추가하고, 드롭/구매 로직(항목 7)에 등급별 가중치 테이블과 에디션 부여 확률(낮은 확률, 예: 5~10%)을 순수 함수로 설계한다. UI에는 등급별 카드 테두리/배경색 구분과 에디션 특수 이펙트(반짝임 등, 우선 Lua 도형/컬러로 프로토타입)를 추가한다. `game/self_test.lua`에 등급별 드롭 가중치, 에디션 부여 확률, 에디션이 부여된 카드의 추가 효과 계산에 대한 회귀 테스트를 작성한다. 항목 9와 마찬가지로 규모가 크므로 등급 3단계 + 에디션 3종 정도의 최소 구현부터 시작해 이후 사이클에서 확장한다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-03, refined noSlotCost 엔진 슬롯 대칭성 회귀 가드 슬라이스): 이전 슬라이스가 "다음 슬라이스"로 명시한 감사(refined(noSlotCost) 에디션이 엔진 슬롯에서도 hull 슬롯과 동일하게 적용되는지)를 수행했다. 코드 감사 결과 `game/engine_parts.lua`의 `occupiedSlotCount`/`isFull`/`equip`은 이미 `category` 파라미터로 hull/engine을 완전히 제네릭하게 처리해 hull 전용  …(압축됨)
  13. ✅ 완료(2026-09-04) — **선체/엔진 부품 데이터를 별도 config로 외부화 + 전용 웹 에디터 제공 (2026-09-02, 사용자 확정, 최우선급 — 게임 핵심 요소):** 사용자가 부품 시스템(항목 9·10·12)을 게임의 핵심 요소로 규정하며, Lua 코드에 하드코딩하지 말고 **사람이 직접 값을 입력·수정할 수 있는 별도 config 파일 + 이를 편집하는 웹 에디터**를 요구했다. 다음을 구현한다: (a) **데이터 외부화** — 선체 부품(항목 9)·엔진 부품(항목 10)의 카드 정의(이름, 아이콘/심볼, 등급, 효과 수치, 시너지 태그, 에디션 목록 등, 항목 12 포함)를 Lua 코드(`game/gear.lua`)에서 분리해 순수 데이터 파일로 관리한다 — LÖVE가 `love.filesystem`로 바로 읽을 수 있는 JSON(예: `game/data/hull_parts.json`, `game/data/engine_parts.json`)을 권장하며, 게임 코드는 이 JSON을 로드해 카드 풀을 구성하는 얇은 로더 역할만 한다. 스키마는 `docs/`에 문서화한다. (b) **웹 에디터** — 이 JSON을 시각적으로 열람·추가·수정·삭제할 수 있는 독립 웹 도구를 만든다(다른 게임 프로젝트의 `pixel-asset-studio`/`game-effect-studio`와 유사한 위치, 예: `spaceship/tools/gear-editor/` 정적 HTML+JS 또는 간단한 로컬 서버). 카드별로 이름/아이콘(이모지 또는 색상 스와치)/등급/효과 파라미터/시너지 태그/에디션을 폼으로 입력하고, 저장 시 위 JSON 파일에 직접 반영(또는 다운로드 후 교체)되도록 한다. 등급별 색상 미리보기, 카드 목록 그리드 뷰(발라트로 도감처럼)도 포함하면 좋다. (c) `game/self_test.lua`에 JSON 로더가 스키마를 검증하고 잘못된 데이터(중복 id, 범위 밖 수치 등)를 방어적으로 처리하는 회귀 테스트를 추가한다. 이 항목은 항목 9·10·12의 실제 카드 콘텐츠 제작을 사용자가 직접 반복적으로 할 수 있게 하는 인프라이므로, 카드 풀 확장(항목 9·10·12) 이전에 최우선으로 진행하는 것을 권장한다.

  > **처리 상황 (spaceship-gear 레인, 2026-09-03):** 데이터 외부화(a)와 웹 에디터(b) 두 부분을 모두 1차 완료했다. `game/json.lua`(의존성 없는 최소 JSON 디코더, 객체/배열/문자열/숫자/불리언/null 지원)를 신규 작성하고, `game/gear.lua`(신규)가 `love.filesystem`으로 `game/data/hull_parts.json`/`game/data/engine_parts.json`을 읽어 스키마를 방어적으로 검증(중복 id, 범위 밖 수치 -100~100, 미지의 effect type/rarity, 빈 문자열 필드, 빈 effects 배열 모두 명시적 에러로 거부)한 뒤 정규화된 Lua 카드 풀 테이블로 반환하는 얇은 로더로 구현했다. 초기 카드 풀은 선체 6종/엔진 4종(다음 항목 9·10 사이클에서 20~30종 규모로 확장 예정)이며 각 카드는 id/name/nameKo/icon/rarity/tags/editions/effects 필드를 갖는다. 스키마는 `docs/GEAR_SCHEMA.md`에 문서화했다. `tools/gear-editor/`(정적 HTML+CSS+JS, 서버/빌드 불필요)를 신규 작성했다: 등급별 색상 테두리의 카드 그리드 뷰, 카드별 폼(id/이름(en/ko)/아이콘/등급(색상 미리보기 포함)/태그/에디션/effect 반복 목록)으로 추가·수정·삭제 가능하며, 저장 시 `game/gear.lua`와 동일한 규칙(중복 id/범위/미지 타입 등)으로 클라이언트 측 검증 후 JSON 다운로드 또는(Chrome/Edge의 File System Access API 지원 시) 원본 파일에 직접 저장할 수 있다. `game/self_test.lua`에 `testGearJsonLoader()`를 추가해 JSON 디코더 스모크 테스트, 번들된 실제 데이터 파일 2종의 정상 로드, `gear.findById`, 그리고 누락 파일/손상 JSON/중복 id/범위 밖 값/미지 effect 타입/미지 rarity/빈 effects/누락 id 등 7가지 방어적 실패 경로를 모두 회귀 검증한다(RED 확인 후 GREEN). `game/data/`의 JSON 두 파일은 `Makefile`의 `.love` 번들에도 포함됨을 `unzip -l build/game.love`로 확인했다. `make test`, `make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:54`, `ASSET_MANIFEST_OK`). 아직 `game.gear`를 실제 게임 배선(장비 장착/효과 적용)에 연결하지 않았다 — 이는 다음 항목 9(선체 부품 20~30종 + 시너지 엔진)에서 진행한다. 다음 슬라이스: 항목 9(`game/gear.lua`를 이용해 선체 부품 카드 풀을 20~30종으로 확장하고 시너지 계산 엔진 설계).

  > 처리 상황 (spaceship-gear 레인, 2026-09-03, Card-shape 스키마 표 galaxyExclusive 명문화): 직전 슬라이스가 명시한 다음 작업. `docs/GEAR_SCHEMA.md` Card-shape 예시 JSON과 필드 표에 optional `galaxyExclusive`(boolean, 기본 false)를 넣었다. Earth-shop 제외(`gear.earthShopPool`)와 hub 확정 드롭(`expedition.exploreHub`) 노트를 표에 함께 적었다. `testGearSch …(압축됨)
  14. ✅ 완료(2026-09-04) — **부품 효과 종류(effect schema) 확장 — 가산형 5종 + 배율/트리거/조작형 추가 (2026-09-02, 사용자 확정, 항목 9/10/12/13과 직결):** 사용자가 제안한 기본 효과 5종(속도, 표본 판매 금액, 소지금, 고도, 선체 내구도/체력)에 더해, 항목 9가 목표로 하는 "조합이 곱연산으로 폭발하는" 재미를 실제로 구현하려면 **가산(+)형 스탯만으로는 부족**하다. 다음 효과 카테고리를 `effect` 스키마에 정식으로 추가한다 (항목 13의 JSON 데이터 스키마 및 웹 에디터에도 반드시 함께 반영): (A) **가산형(기존 5종)** — speed(속도), sampleSellValue(표본 판매 금액), money(소지금 직접 증감), altitude/climbSpeed(고도 상승 속도), hullDurability(선체 내구도). (B) **배율(곱연산)형 — 신규, 시너지의 핵심** — sellMultiplier(판매 금액 배율, 가산이 아니라 곱), streakMultiplier(동일 계열 연속 채집 시 누적 배율, 기존 스트릭 증폭기 카드를 이 범용 효과 축으로 승격). (C) **트리거/확률 조작형 — 신규** — luck(전역 확률 보정 — **적용 대상을 다음 2가지로 한정한다** [귀환 슬롯머신 관련 적용 대상은 항목15에 따라 폐지됨]: ①항목 12의 에디션(방사능처리/결정화/양자결함 등) 부여 확률(기본 5~10%) 상향, ②항목 12의 희귀 등급(커먼/언커먼/레어) 드롭 가중치를 상위 등급 쪽으로 상향 — 항목 7-b의 은하 체크포인트 확정 드롭은 확률 기반이 아니므로 luck의 영향을 받지 않는다), chainTrigger(특정 조건마다 다른 장착 카드 효과 재발동, 발라트로 Blueprint/Brainstorm 컨셉), rerollBonus(상점 리롤 무료 횟수/재구성 확률). (D) **생존/리스크 완화형 — 신규** — insurance(파괴 시 1회 한정 정산 없이 생존), collisionRadius(충돌 판정 반경 축소, 내구도와 별개 축). (E) **탐사/정보형 — 신규** — detectionRadius(표본/체크포인트/상점 행성 미니맵 표시 반경 확대, 항목 1과 연계), autoCollect(근접 표본 완전 자동 흡수). (F) **경제형 — 신규** — shopDiscount(상점 구매가 할인). 구현: `game/gear.lua`/`engine_parts.lua`의 효과 계산 로직에 위 카테고리별 순수 함수를 추가하고, 배율형(B)은 가산형(A) 합산 이후 곱연산으로 별도 적용되도록 계산 순서를 명확히 설계한다(가산 총합 × 배율 총합 방식 권장). `game/self_test.lua`에 각 신규 효과 카테고리의 최소 1개 회귀 테스트와, 가산+배율 혼합 시 계산 순서가 올바른지 검증하는 테스트를 추가한다. **웹 에디터(항목 13)의 효과 입력 폼에도 이 전체 카테고리(A~F)를 드롭다운/그룹으로 선택할 수 있도록 함께 구현한다** — 에디터가 구식 5종 효과만 지원하면 신규 카테고리를 활용한 카드를 만들 수 없으므로, 항목 13과 이 항목은 반드시 같은 사이클 또는 순서상 항목 13 직후에 함께 처리한다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-03, 열두 번째 슬라이스 — 항목14(C) rerollBonus 소비 gap 마지막 잔여): `M.spendReroll(run)`이 원자적 소비 카운터로만 존재하고(이전 슬라이스), `M.rollGearOffer(run, pool, rolls)`가 순수 오퍼 생성 함수로만 존재했는데(그보다 앞선 슬라이스), 이 레인이 `boostCharge`(`M.spendBoost`)/`insurance`(`M.damage`)에서 반복 닫은 "카운터는 있는데 실제 효과와 원자적 …(압축됨)
  15. ✅ 완료(2026-09-04) — **귀환 페이즈 및 비행 중 슬롯머신 폐지 + 지구 상점 전용 슬롯머신(은하계별 변동 오즈)으로 재설계 (2026-09-02, 사용자 확정):** 사용자의 피드백을 반영해 슬롯머신과 귀환 메커니즘을 다음과 같이 재정의한다: (a) 비행 중(상승/귀환 도중)에 수동으로 선언하는 `beginReturn` 페이즈와 비행 중 슬롯머신(`slotSpin`, `useSlot` 등)은 완전히 폐지하고, 지구 또는 은하 체크포인트 도달 시 즉시 정산(항목 8)되는 구조로 간소화한다. (b) 대신 **슬롯머신 자체는 지구 상점(settlement/shop 화면)에서 할 수 있는 전용 미니게임/오락 요소로 재배치**한다. (c) 특히 **은하계마다 슬롯머신 내용/오즈/특수 심볼 구성에 변화(변동)**를 주어, 어떤 은하계의 체크포인트를 찍고 돌아왔느냐에 따라 지구 상점의 슬롯머신 확률과 보상 테이블이 달라지도록 해 파밍과 탐험의 동기를 극대화한다 (예: 태양계 슬롯은 표준형, 화성/외곽 은하 슬롯은 고배당/위험부담형 등). `game/expedition.lua` 및 `game/scenes/play.lua`에 지구 상점 슬롯머신 인터페이스와 은하계별 오즈 테이블 구조를 설계하고 `game/self_test.lua`에 회귀 테스트를 작성한다. (이로 인해 항목 14의 luck 효과 적용 대상에 지구 상점 슬롯머신 고배당 확률 상향이 다시 포함된다.)
  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목15(c) follow-up — earthSlotSpin 보상 테이블 profile별 차등): 직전 슬라이스가 earthSlotSpin의 odds(가중치)는 프로파일별로 달랐지만 jackpot 금액(STAR×3=75)은 모든 프로파일에서 고정이었다는 gap을 감사로 발견해 처리했다 — 항목15(c) 원문 "보상 테이블이 달라지도록"은 금액 테이블도 변해야 함을 명시. TDD로 `testEarthSlotProfileRewardVariation()`을 추가했 …(압축됨)
`game/expedition.lua`에 은하계별 오즈 프로파일 시스템 3종을 신규 추가했다. `M.earthSlotOddsProfiles`(solar/fringe/void 3종 — solar는 기존 표준 오즈 그대로, fringe는 STAR 가중치 +1·COMET -1, void는 STAR +2·COMET -2의 고배당/위험부담형), `M.galaxySlotOddsProfile(galaxyId)`(nil 또는 milkyway → \"solar\", 외부 은하 → galaxyId 해시 mod 3으로 \"fringe\" 2:1 / \"void\" 1:1 비율로 결정론적 배정, 같은 은하 ID는 항상 같은 프로파일), `M.earthSlotWeights(galaxyId)`(해당 프로파일의 가중치 테이블 복사본 반환), `M.earthSlotSpin(run, galaxyId, rolls)`(3-릴 스핀 순수 함수 — 칼러별 누적 가중치로 심볼 결정, 항목14(C) luck 효과를 STAR 가중치에 곱연산으로 적용, `{symbols, reward, totalWeight, effectiveStarWeight}` 반환)를 구현했다. `M.exploreHub`에 `run.lastVisitedGalaxyId = galaxyId` 기록을 추가해 Earth 상점 슬롯이 마지막으로 탐험한 은하의 프로파일을 자동으로 사용할 수 있게 했다. `game/self_test.lua`에 `testEarthSlotMachineGalaxyOdds()`를 추가해 (1)프로파일 결정론성/solar·outer 분리, (2)fringe·void의 STAR>solar·COMET<solar 단조성, (3)고정 롤로 COMET×3 심볼·양수 보상·totalWeight 노출, (4)luck 카드 장착 시 effectiveStarWeight>기본 STAR, (5)exploreHub 호출 후 lastVisitedGalaxyId 설정·갱신·중복 탐험 시 불변을 회귀 검증한다(RED: `attempt to call field 'galaxySlotOddsProfile' (a nil value)` 확인 후 GREEN). `make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK`, `ASSET_MANIFEST_OK`). 변경 파일은 `game/expedition.lua`/`game/self_test.lua`/`docs/STATUS.md`/`docs/feedback/INBOX.md`뿐(`play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua` 미변경). 항목15(a)(b) — 비행 중 슬롯머신 폐지 및 실제 settlement UI 재배치 — 는 `play.lua` 담당(이 레인 스코프 밖). 이 레인의 순수 데이터 계층(슬롯 오즈 테이블 + 스핀 함수)은 play.lua 소비자가 `earthSlotSpin(run, run.lastVisitedGalaxyId, {reels=rolls})`를 호출하는 것만으로 완전히 동작하도록 설계되었다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목15(a) 잔여 dead code 정리 — play.lua 슬롯 상수/필드 제거): 항목15(a)가 비행 중 슬롯머신을 폐지한 이후 `game/scenes/play.lua`에 세 가지 dead 잔재가 남아있었다 — (1) 모듈 수준 상수 `slotReelStagger`/`slotSpinDuration`(어떤 함수에서도 참조되지 않는 orphaned 상수), (2) `returnControls`의 `slotMinX`/`slotMaxX` 필드(귀환 페이즈 슬 …(압축됨)
 이번 사이클의 preflight가 `make test` FAIL을 보고하며 시작했다 — 직전 사이클이 `game/self_test.lua`에 `testGearInsuranceCategoryAgnosticWiring()`(RED, 미커밋)을 이미 추가해 "항목14 (D) `insurance`가 유일하게 아직 `run.equippedGear`(hull)만 …(압축됨)
  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목15(b) earthSlotSpin rolls 포맷 버그 수정): `play.lua`의 `keypressed("l")` 핸들러가 `rolls = {1, 2, 3}`(정수 키 순수 배열)을 만들어 `earthSlotSpin`에 전달했는데, `earthSlotSpin`은 `rolls.reels`만 읽어 nil이면 `{0, 0, 0}`으로 폴백 — 결과적으로 매번 COMET-COMET-COMET 고정 출력이었다. `play.lua`를 `{ reels = {r1 …(압축됨)

- ✅ 완료(2026-09-03) — **UI/HUD 대대적 정리 6개 항목 (2026-09-02, 사용자 확정, 최우선, 실제 런타임 캡처 검토 기반):** 사용자가 `GAME_CAPTURE_PHASE=launch` 실제 캡처를 보고 다음 6가지를 확정 요청했다. 한 사이클에 전부 처리할 필요는 없으며 순서대로 슬라이스해도 된다.
  1. ✅ 완료(2026-09-03) — **배경 별 밀도 증가:** `game/world.lua`에 `M.backgroundStars(sectorX, sectorY)`(섹터당 120개, salt 10000+ 대역으로 기존 `M.stars`의 18개 유성별과 완전히 분리된 결정적 포인트 집합, 밝기 0~0.55로 어둡게 제한)를 신규 추가했다. `game/scenes/play.lua`의 `draw()`가 기존 유성별 레이어를 그리기 전에 이 배경 레이어를 먼저 그리되, 카메라 이동량의 0.4배만 반영(감소된 parallax)해 거의 정지한 은하수처럼 보이게 하고, 색상도 더 어둡게(0.12~0.52) 낮춰 전경 유성별과 시각적으로 구분되도록 했다. `game/self_test.lua`의 `testBackgroundStars`가 결정성(같은 섹터 좌표는 항상 같은 점 집합)·밀도(전경의 2배 이상)·독립적 시드(전경과 겹치지 않는 별도 점 집합)를 회귀 검증한다. 헤드리스 디버그 카운트로 실측: 동일 뷰포트 위치에서 전경 유성별 21개 대비 배경별 144개(약 7배) 표시됨을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN.
  2. ✅ 완료(2026-09-03) — **"고도" → "지구로부터 거리"로 명확화 (버그 아님, 표현 문제):** 사용자가 "고도기록이 연료를 사용해야만 올라가는 버그"로 오인했다. 실제로는 `game/expedition.lua`의 `M.update(run, dt)`가 `run.altitude`를 `run.climbSpeed`로 자동 증가시키고(연료는 `game/ship.lua`에서 조종 시에만 소모되는 별개 값), 연료는 상승 자체를 막지 않는다(주석 "Fuel is no longer a flight constraint" 참고). `game/i18n.lua`의 `hud_primary`를 `"ALT %04d CASH $%d"`/`"고도 %04d 자금 $%d"`에서 `"DIST %04d CASH $%d"`/`"거리 %04d 자금 $%d"`로 변경했다. `game/scenes/play.lua`에 신규 `M.hudPrimaryStatusGap = 6`(px)과 미니맵 배치·텍스트 렌더가 공유하는 `M.hudHeight(phase, hud, galaxyShift)` 헬퍼를 추가해, ascending/returning 페이즈에서 DIST/CASH 줄과 연료 게이지가 포함된 상태 줄 사이에 시각적 간격을 두었다. `game/self_test.lua`에 라벨(ALT 미포함, DIST로 시작)과 간격 회귀 테스트를 추가했다. 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=ascending-wide-warning`, 1080×1920)를 vision으로 확인해 "거리 1000 자금 $0" 줄과 그 아래 간격을 둔 연료/선체 상태 줄이 정상 렌더링됨을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN.
  3. ✅ 완료(2026-09-03) — **연료 무제한 반영 + 아이콘 기반 HUD 간소화:** 연료 최대치 제한이 이미 게임 로직상 폐지되었음(`M.maneuverFuel`/`M.burnManeuverFuel`이 no-op, "Fuel is no longer a flight constraint" 주석)에도 HUD/LOADOUT 텍스트가 여전히 `F%03d`(연료 수치), `MAX FUEL %d` 등 상한이 있는 것처럼 표시된다. ✅ 2026-09-03: 상단 HUD 상태 줄(`i18n.lua`의 `hud_status`)에서 `F%03d` 연료 수치를 완전히 제거했다(`"H%d/%d %-6s S%02d"`로 축소, `game/scenes/play.lua`의 `M:hudLines()` 호출부와 `game/self_test.lua` 회귀 테스트 동기화). 실제 LÖVE 런타임 캡처로 연료 수치가 더 이상 보이지 않음을 확인. ✅ 2026-09-03(두 번째 슬라이스): LAUNCH LOADOUT의 `stats_line`/EARTH SHOP의 `ship_preview_line`/`ship_preview_compact`, 그리고 `hull_upgraded_message`/`scout_purchased_message`/`ship_selected_message`에 남아있던 `MAX FUEL %d`/`최대연료 %d` 표기를 전부 제거했다(en/ko 두 로케일, `game/i18n.lua`). `game/scenes/play.lua`의 호출부와 `game/self_test.lua` 회귀 테스트를 새 포맷 시그니처에 맞춰 갱신했다. 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`)로 LAUNCH LOADOUT 카드가 "선체 3"만 표시하고 "최대연료" 문구가 완전히 사라졌음을 vision으로 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. ✅ 2026-09-03(세 번째 슬라이스) — "탭하여 발사" 버튼에 로켓 아이콘을 추가했다. `game/scenes/play.lua`에 순수 함수 `M.rocketIconPoints(cx, cy, size)`(위쪽을 향한 삼각형+핀 실루엣의 flat 폴리곤 점 목록)와 `M.launchIconSize = 14`/`M.launchIconGap = 12`를 추가하고, `M:draw()`가 launch 페이즈에서 이 로켓을 "탭하여 발사" 텍스트 바로 위에 주황색으로 그린다. `game/self_test.lua`의 `testLaunchRocketIcon()`이 폴리곤 형태(짝수 점 개수, 로켓이 중심 위아래로 걸쳐 있음, 노즈가 최상단이자 수평 중심 정렬)를 회귀 검증한다. 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1440×2560, ko 로케일)를 vision으로 확인해 겹침·잘림 없이 렌더링됨을 확인했다. ✅ 2026-09-03(네 번째 슬라이스) — 선체 내구도(`hud_status`의 `H%d/%d` 세그먼트)에 방패 아이콘을 추가했다. `game/scenes/play.lua`에 순수 함수 `M.shieldIconPoints(cx, cy, size)`(윗변 평평·아래로 뾰족한 오각형 실루엣의 flat 폴리곤 점 목록)와 `M.hullIconSize = 8`/`M.hullIconGap = 4`를 추가했다. ✅ 2026-09-03(다섯 번째 슬라이스) — 상단 HUD의 CASH 표기에 동전 아이콘을 추가했다. `game/i18n.lua`의 `hud_primary`("DIST %04d  CASH $%d")를 `hud_distance`/`hud_cash` 두 독립 키로 분리하고(en/ko), `game/scenes/play.lua`의 `M:hudLines()`가 `distance`/`cash` 필드를 각각 반환하도록 변경했다. 신규 순수 함수 `M.coinIconPoints(cx, cy, size)`(원 대신 8각형 실루엣 폴리곤)와 `M.cashIconSize = 8`/`M.cashIconGap = 4`를 추가하고, `M:draw()`가 DIST 텍스트 오른쪽에 폰트 폭 기반으로 위치를 계산해 금색 동전을 그린 뒤 CASH 텍스트를 그 옆에 그린다. `game/self_test.lua`의 `testCashCoinIcon()`(신규)이 폴리곤 형태(짝수 점, 중심 상하 걸침, 수평 대칭)를 회귀 검증한다. ✅ 2026-09-03(여섯 번째 슬라이스) — 마지막 남은 속도(조종속도/엔진속도)를 스피드미터 아이콘으로 간소화했다. `game/scenes/play.lua`에 신규 순수 함수 `M.speedIconPoints(cx, cy, size)`(바늘이 파인 게이지 형태의 반원 폴리곤)와 `M.drawCenteredIconText` 헬퍼를 추가해, `loadout.steering`과 `nextLaunch.steeringPreviewCompact` 렌더 시 텍스트 왼쪽에 아이콘이 중앙 정렬되도록 변경했다. `game/i18n.lua`의 긴 속도 표기("STEER SPEED %d", "조종속도 %d")를 "%d" 수치만 나오도록 축소하고 관련 테스트(`game/self_test.lua`)도 동기화했다. 신규 `testSpeedometerIcon()`으로 폴리곤 형태(3개 이상 꼭짓점, 하단 평면, 중심 상하 걸침)를 회귀 검증했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. 이로써 3번 항목 전체(4가지 아이콘화) 완료.
  4. **불필요한 텍스트 제거 검토 (거의 완료, 2026-09-03):** 다음을 검토해 제거하거나 아이콘/약어로 대체한다 — `hud_status`의 `S%02d`(발사 단계에서 슬롯 예보가 0으로 항상 보여 혼란, "발사S00"으로 보이는 부분), 함선 이름 "STARTER"(현재 기본값 하나뿐이라 별 의미 없이 항상 표시됨), "발사 장비"(LAUNCH LOADOUT) 패널 타이틀 자체, "무피격 N"(`forecast_line`, 실제로는 "이번 연료로 충돌 없이 도달 예상 고도"를 뜻하는 예보 수치이므로 이름이 불명확 — 아이콘+숫자로 대체하거나 더 명확한 라벨로 교체), "평균 $"(슬롯 오즈 라인의 기대값 표기, `slot_odds_line`), "개발 임시본"(DEV PLACEHOLDER 푸터 텍스트, 실제 최종 에셋 적용 전까지는 유지가 필요할 수 있으나 게임 플레이 경험을 해치지 않는 더 작고 눈에 덜 띄는 형태로 조정 검토). ✅ 2026-09-03(네 번째 슬라이스): "발사 장비"(LAUNCH LOADOUT) 패널 타이틀 자체를 제거했다. `game/scenes/play.lua`에 신규 `M.showLaunchLoadoutTitle = false` 플래그를 추가하고, `M:draw()`의 LAUNCH LOADOUT 카드 렌더 구간이 이 플래그가 참일 때만 `i18n.t("launch_loadout_title")` printf와 그에 따른 `rowStep` 간격 소비를 수행하도록 분기했다(카드 내용물인 선체/업그레이드/예보/조종속도/오즈 수치가 뚜렷하게 테두리 쳐진 박스 안에 있어 캡션 없이도 자명하다는 판단). `game/self_test.lua`에 `PlayScene.showLaunchLoadoutTitle == false` 회귀 테스트를 추가했다(RED 확인 후 GREEN). 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920, ko 로케일)를 vision으로 확인해 카드가 "발사 장비" 캡션 없이 표본 도감 스트립 바로 아래에서 곧바로 "선체 3"으로 시작하고 빈 줄도 남지 않음을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. 남은 작업: `hud_status`의 발사 단계 `S00` 제거는 이미 완료(첫 슬라이스), "개발 임시본" 축소도 이미 완료(e856611) — 4번 항목은 사실상 전량 완료. ✅ 2026-09-03: 첫 슬라이스로 `hud_status`의 `S%02d`를 발사 단계에서만 제거했다. `game/i18n.lua`에 신규 `hud_status_no_slots = "H%d/%d %-6s"`(en/ko)를 추가하고, `game/scenes/play.lua`의 `M:hudLines()`가 `run.phase == "launch"`일 때만 이 포맷을 사용하도록 분기했다(다른 모든 페이즈는 기존 `hud_status`로 `S%02d`를 계속 표시). `game/self_test.lua`에 발사 단계에서 상태 줄이 "H3/3 LAUNCH"로 슬롯 세그먼트 없이 표시되고 다른 페이즈(SETTLE 등)는 그대로 `S00`을 유지함을 검증하는 회귀 테스트를 추가했다(RED 확인 후 GREEN). 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1080×1920)를 vision으로 확인해 "H3/3 발사" 줄에 더 이상 "S00"이 보이지 않음을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. ✅ 2026-09-03(두 번째 슬라이스): "무피격 N"(`forecast_line`) 라벨을 명확한 라벨로 교체했다 — en `"NO-HIT %d  SLOTS %d"` → `"REACH %d  SLOTS %d"`, ko `"무피격 %d  슬롯 %d"` → `"도달예상 %d  슬롯 %d"`(`game/i18n.lua`). 포맷 인자는 그대로라 `game/scenes/play.lua` 호출부 변경은 불필요했고, `game/self_test.lua`의 하드코딩된 "NO-HIT N  SLOTS N" 회귀 테스트 24곳을 "REACH N  SLOTS N"으로 갱신했다(RED 확인 후 GREEN). 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, ko 로케일)로 "도달예상 600  슬롯 6"이 정상 렌더링됨을 vision으로 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. ✅ 2026-09-03(세 번째 슬라이스): "평균 $"(`slot_odds_line`) 표기를 정확한 라벨로 교체했다 — en `"AVG $%.2f"` → `"EV $%.2f"`, ko `"평균 $%.2f"` → `"기대값 $%.2f"`(`game/i18n.lua`). 포맷 인자는 그대로라 `game/scenes/play.lua` 호출부 변경은 불필요했고, `game/self_test.lua`의 하드코딩된 `"C50 P40 S10  AVG $18.58"` 회귀 테스트 3곳을 `"C50 P40 S10  EV $18.58"`로 갱신했다(RED 확인 후 GREEN). 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=returning-odds`, 1440×2560, ko 로케일)로 미니맵 위 "C50 P40 S10 기대값 $18.58"이 바로 위 "귀환 0% 12초" 줄과 겹치지 않고 정상 렌더링됨을 vision으로 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. ✅ 2026-09-03(네 번째 슬라이스): "개발 임시본"(DEV PLACEHOLDER) 푸터 텍스트를 축소했다. `game/scenes/play.lua`에 신규 `M.devPlaceholderFontSize = 7`(px)·`M.devPlaceholderAlpha = 0.4`를 추가해 `draw()`의 푸터 렌더가 기본 14px/0.85 알파 대신 이 값을 쓰도록 변경했다. `game/self_test.lua`에 폰트 크기가 기본보다 작고 알파가 이전보다 낮음을 검증하는 회귀 테스트를 추가했다(RED 확인 후 GREEN). 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=launch`, 1440×2560, ko 로케일)로 "개발 임시본"이 "탭하여 발사" 줄보다 눈에 띄게 작고 흐리게 렌더링됨을 vision으로 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. ✅ 2026-09-03(다섯 번째 슬라이스): 함선 이름 "STARTER"(`loadout_ship`, "SHIP STARTER")를 기본 STARTER 선체 하나만 소유 중일 때는 완전히 숨겼다. `game/scenes/play.lua`의 `M:loadoutLines()`가 `run.ownedShips.scout`를 실제로 보유했을 때만 `ship` 필드를 채우도록(그 외에는 `nil`) 변경하고, `M:draw()`의 LAUNCH LOADOUT 카드 렌더가 `loadout.ship`이 `nil`이면 해당 줄과 간격을 건너뛴다. 파괴 화면의 "NEXT %s" 줄은 STARTER뿐이어도 항상 함선명을 알려줘야 하므로 이 용도 전용의 신규 `shipLabel` 필드(항상 `string.upper(run.selectedShipId)`)를 분리 추가했다. `game/self_test.lua`의 두 회귀 지점(초기 상태·메타 초기화 후 상태)에서 `ship == "SHIP STARTER"` 단언을 `ship == nil` 단언으로 갱신했다(RED 확인 후 GREEN). 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1`, 기본 launch phase, 1080×1920, ko 로케일)로 "발사 장비" 타이틀 바로 아래 곧바로 "선체 3"이 나오고 "SHIP STARTER"/빈 줄이 없음을 vision으로 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN. **남은 작업:** "발사 장비"(LAUNCH LOADOUT) 패널 타이틀 자체 검토(제거 여부)만 남음(4번 항목의 세부 텍스트 정리 5개 중 5개 완료, 타이틀 검토는 별도 판단 필요).
  5. ✅ 완료(2026-09-03) — **C50/P40/S10 슬롯 확률 표기를 미니맵 위 작은 텍스트로 이동:** 이전 사이클이 `slot_odds_line`(`"C%d P%d S%d 평균 $%.2f"`)을 귀환 화면의 큰 별도 줄에서 미니맵 위쪽 작은 우측정렬 텍스트(`game/scenes/play.lua`의 `drawMinimap()`, 8px 폰트)로 옮기는 uncommitted diff를 남겼으나, 이번 사이클에서 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=returning-odds`, 1080×1920)를 vision으로 검토한 결과 옮겨진 오즈 줄이 바로 위 "귀환 0% 12초"(`hud_return_progress`) 줄과 겹쳐 렌더링되는 결함을 발견했다. `M.hudHeight(phase, hud, galaxyShift)`의 `returning` 분기가 오즈 줄을 위한 추가 세로 공간을 예약하지 않았기 때문이다. 신규 `PlayScene.hudOddsLineHeight = 10`(px)을 추가해 returning 페이즈의 HUD 박스 높이 계산에 반영하고(`70 + hudPrimaryStatusGap + hudOddsLineHeight`), 이 높이를 `drawMinimap()`과 실제 텍스트 렌더(`draw()`)가 함께 사용하는 `M.hudHeight()`에서 공유하므로 두 곳이 다시 어긋나지 않는다. `game/self_test.lua`에 `hudOddsLineHeight` 존재/양수 및 `hudHeight("returning", ...)`가 새 공식과 일치함을 검증하는 회귀 테스트를 추가했다(RED 확인 후 GREEN). 수정 후 재캡처(`GAME_CAPTURE_PHASE=returning-odds`)를 vision으로 재확인해 "귀환 0% 12초" 줄과 "C50 P40 S10 평균 $18.58" 오즈 줄이 겹치지 않고 깔끔하게 세로로 분리되어 미니맵 바로 위에 표시됨을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN.
  6. ✅ 완료(2026-09-03) — **표본 9종 도감 정리 + 슬롯 6개를 개성 있는 함선 장비 카드 UI로 전환:** 런치 화면의 "SPECIMENS 9/9" 표본 도감 스트립(`world.specimenCatalog`/`collection_store.lua`)은 현재 순수 수집 진행률 표시용 장식 요소로, 게임플레이 수치에 영향을 주지 않는다. 사용자가 불필요하다고 판단하면 제거하되, 제거 전 정말 게임성에 기여하지 않는지 한 번 더 검토한다. **핵심 신규 요청:** 현재 슬롯 오즈/예보에 등장하는 "슬롯 6개"(귀환 시 `slotOpportunities` 최대치, `game/expedition.lua`의 `slotCount`/`slotDistance` 참고)를 추상적인 확률 슬롯이 아니라 개성 있는 함선 장비 6종으로 재해석해 UI에 아이콘으로 보이도록 구성한다. 발라트로 조커 카드처럼 각 장비가 고유한 이름·아이콘·능력을 갖는다. 사용자 세션에서 제안된 초안(다음 사이클이 게임 밸런스에 맞게 조정 가능): ① **오버드라이브 코어**(⚡, 상승/조종 속도 증가) ② **강화 장갑판**(🛡, 선체 내구도 보너스 + 충돌 충격 감소) ③ **채집 자석**(🧲, 표본 채집 반경 확대) ④ **행운의 주사위**(🎲, 슬롯머신 고배당 심볼 확률 상승) ⑤ **스트릭 증폭기**(🔗, 동일 계열 연속 채집 배율 상승폭 강화) ⑥ **정밀 자이로**(🧭, 조종 반응속도/급회전 판정 향상). 각 장비는 상점에서 구매/장착하는 기존 업그레이드 시스템(`fuelUpgradeLevel`, `durabilityUpgradeLevel`, `steeringUpgradeLevel`, `sampleYieldUpgradeLevel` 등)을 이름 있는 카드로 매핑하거나, 신규 `run.equippedGear` 목록으로 확장해 각각 소형 아이콘을 HUD 하단 또는 EARTH SHOP 화면에 상시 노출한다. `game/expedition.lua`에 순수 함수로 장비 정의/효과 계산을 추가하고 `game/self_test.lua`에 각 장비 효과의 회귀 테스트를 작성한다. 최종 텍스처는 AetherAI-only 정책을 따르되 아이콘 실루엣은 Lua 도형으로 즉시 프로토타입 가능하다. ✅ 2026-09-03: `game/scenes/play.lua`에서 더 이상 사용되지 않는 표본 도감 스트립을 완전히 제거하고, 그 자리에 `M.drawGearSlots`를 추가해 선체 장비 슬롯 6개와 엔진 장비 슬롯 3개를 발라트로 조커 카드처럼 시각적으로 렌더링하도록 변경했다. 아이콘은 Lua 도형(`shieldIconPoints`, `rocketIconPoints`)을 사용하고 테두리와 색상으로 희귀도를 나타낸다. `game/i18n.lua`에 장착 장비 라벨(`equipped_gear_label`)을 추가했고 관련 테스트(`game/self_test.lua`)도 동기화했다. `make test` GREEN 확인. 이로써 "UI/HUD 대대적 정리 6개 항목"의 마지막 6번 항목까지 UI 렌더링 배선을 완료했다.
  > 처리 상황 (spaceship-gear 레인, 2026-09-03, 열 번째 슬라이스 — 엔진 풀 galaxyExclusive 콘텐츠 gap): 직전 슬라이스가 완료한 항목7 순수-데이터 계층(`world.shopPlanet`/`gear.earthShopPool`/`gear.galaxySpecificGear`/`expedition.exploreHub`, 커밋 b1e3f92)을 감사한 결과, `galaxyExclusive: true` 카드가 `hull_parts.json`에 단 1장(`hull_combo_matrix`)만 있고 `engine_parts.json`(24종)에는 0건이었다 — 엔진 부품만 장착한 플레이어는 은하 중심 탐사 확정 드롭(항목7-b)으로 엔진 전용 보상을 영원히 받을 수 없고, 엔진 풀은 지구 상점에서도 아무것도 걸러지지 않는 gap이었다(항목10(c)가 "획득 경로는 항목7의 3원화 구조를 그대로 재사용하되, 엔진 부품 전용 카드 풀로 별도 관리한다"고 명시했음에도). TDD로 `game/self_test.lua`에 신규 `testGearGalaxyExclusiveEnginePoolWiring()`을 추가했다(RED 확인: "the bundled engine_parts.json pool must contain at least one galaxyExclusive card"). `game/data/engine_parts.json`의 기존 legendary 카드 `engine_singularity_drive`(밸런스 변경 없음, 메타데이터만 추가)에 `galaxyExclusive: true`를 부여해 GREEN 전환. 동시에 hull/engine 두 풀이 `run.hubExplored`를 은하 ID로 공유해(한 풀로 탐험 완료 후 다른 풀로도 재탐험 불가) 항목8의 "체크포인트 탐사=은하당 1회" 설계와 일치함도 회귀 검증했다. `docs/GEAR_SCHEMA.md`에 "Item 7 follow-up: engine pool had zero galaxyExclusive content" 섹션을 추가했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`). 변경 파일은 `game/data/engine_parts.json`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md`뿐(`git status --short`로 확인, `play.lua`/`i18n.lua`/`world.lua`/`game/gear.lua`/`game/engine_parts.lua`/`game/expedition.lua` 미변경). 실제 UI 배선(상점 행성 접근 팝업, 은하 허브 탐험 프롬프트)은 여전히 이 레인 스코프 밖(`play.lua`/`world.lua` UI 담당). 다음 슬라이스: 항목15(귀환/비행중 슬롯머신 폐지 + 지구 상점 전용 슬롯머신 은하별 오즈)의 순수 데이터 계층 준비, 또는 항목13→9→10→12→14의 남은 잔여 gap 재감사.

  > 처리 상황 (spaceship-gear 레인, 2026-09-03, 열한 번째 슬라이스 — galaxyExclusive 콘텐츠 밀도 gap): 직전 슬라이스가 "엔진 풀에 galaxyExclusive 카드가 0건"이던 gap을 닫으면서 기존 카드 1장(`engine_singularity_drive`)에만 플래그를 부여해 hull과 동일하게 풀당 정확히 1장이 됐는데, `gear.galaxySpecificGear(pool, galaxyId)`가 galaxyExclusive 후보군으로 먼저 좁힌 뒤 galaxyId를 해시해 그 안에서 인덱스를 고르는 구조라 후보가 1개뿐이면 은하 ID와 무관하게 항상 동일한 카드 하나로만 수렴한다는 더 깊은 gap을 감사로 발견했다 — 항목7(b)가 명시한 "해당 은하계 *특유의* 고유 장비 부품"이 스키마/배선상으로는 완료였지만 실제로는 모든 은하가 완전히 동일한 보상 하나를 공유하는 죽은 다양성이었다. TDD로 `game/self_test.lua`의 `testGearGalaxyExclusiveEnginePoolWiring()`에 로컬 `testGalaxyExclusiveVarietyLocal()`을 추가했다(RED: "hull_parts.json must carry at least 3 galaxyExclusive cards..."). `game/data/hull_parts.json`/`engine_parts.json`에 각각 2장씩 신규 legendary `galaxyExclusive: true` 카드(hull: `hull_nebula_forge`/`hull_starforge_relic`, engine: `engine_void_forge_drive`/`engine_stellar_matrix_core`, 서로 다른 효과/태그/에디션)를 추가해 풀당 3장으로 확장했고, 12개 서로 다른 은하 ID에 대해 `galaxySpecificGear`가 실제로 2종 이상의 서로 다른 카드를 반환함을 회귀 검증한다(RED 확인 후 GREEN). `gear.galaxySpecificGear` 자체는 로직 수정 없음(해시/선택 로직은 이미 정확했고 후보 밀도만 부족했음). `docs/GEAR_SCHEMA.md`에 "Item 7 follow-up #2: galaxy-exclusive pools had no real per-galaxy variety" 섹션을 추가했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN(`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:58`, `ASSET_MANIFEST_OK`). 변경 파일은 `game/data/hull_parts.json`/`game/data/engine_parts.json`/`game/self_test.lua`/`docs/GEAR_SCHEMA.md`/`docs/STATUS.md`/`docs/feedback/INBOX.md`뿐(`git status --short`로 확인, `play.lua`/`i18n.lua`/`world.lua`/`game/expedition.lua`/`game/gear.lua`/`game/engine_parts.lua` 미변경). 다음 슬라이스: 항목13→9→10→12→14 잔여 gap 재감사, 또는 항목7의 실제 UI 소비 지점(상점 행성 접근 팝업, 은하 허브 탐험 프롬프트, `play.lua`/`world.lua` 담당) 검토.

- **은하계마다 체크포인트 행성 하나씩 지정 + 미니맵 특별 표기 + 화살표 안내 (2026-09-02, 사용자 확정, 완료):** ✅ 완료 — `game/world.lua`에 `M.galaxyBackgroundColor(galaxy)` 순수 함수(홈 태양계 남색 고정, 그 외 은하는 해시 기반 보라/청록/붉은 결정적 틴트), `game/minimap.lua`에 `M.nearestCheckpointDirection(shipX, shipY)` 순수 함수(가장 가까운 비-milkyway 은하 방향/거리)를 추가했다. `game/scenes/play.lua`의 `drawMinimap()`이 `hub=true` 은하를 반짝이는 링 마커로 그리고(사용자가 긍정한 "현재 위치 은하=고리" 표기는 유지), 미니맵 밖 가장 가까운 체크포인트는 지구-복귀 화살표(주황)와 구분되는 자홍색 화살표로 안내한다. `draw()`가 현재 은하에 맞춰 배경 클리어 색을 바꾼다. `game/self_test.lua`에 방향/거리/빈 결과/배경 틴트 결정성 회귀 테스트를 추가했다. 실제 LÖVE 런타임 캡처(`GAME_CAPTURE_PHASE=ascending-checkpoint-tint`, 1080×1920)를 vision으로 확인해 반짝이는 체크포인트 링 마커와 붉은 계열 배경 틴트(클리어 픽셀 `(16,5,6)`)가 정상 렌더링됨을 확인했다. `make test` GREEN.

- **AetherForgeAI/AetherAI-only 최종 에셋 (2026-09-01, 사용자 확정, 완료):** ✅ 완료 — 우주선·지구·행성·표본·이펙트·슬롯 심볼·상점 아이콘·배경에 대한 AetherAI-only provenance 강제 검증 인프라(`tools/verify_asset_manifest.py`, `docs/assets/MANIFEST.json`, `tools/verify_asset_manifest.py`의 terms_url 공식 도메인 검사)를 구축하고 `make verify` 타깃에 게이트로 통합했다. 공식 로그인/API 자격 증명이 없는 상태이므로 실제 공식 에셋을 가져오기 전까지는 `docs/assets/MANIFEST.json`이 비어 있는 빈 배열(`[]`) 상태를 유지하며, `ASSET_MANIFEST_OK`로 통과한다. 임의의 래스터 자재(Python/Pillow, 수동 도형 등)가 공식 에셋으로 둔갑하는 것을 시스템 레벨에서 완벽히 차단한다.
- **처리 완료된 항목들 (`세로 상승형 로그라이트 핵심 루프`, `행성·이펙트 발라트로 스타일 카드형 비주얼 강화`, `런치 화면 지구 탐험물 전시`, `런치(첫)화면 텍스트 크기·레이아웃 정리` 등)은 모두 코드·테스트·실기기 캡처 검증을 거쳐 이전 사이클들에서 처리 완료 상태로 확정되었다.

- **세로 상승형 로그라이트 핵심 루프 (2026-09-01, 사용자 확정, 최우선):** ✅ 완료 — 지구에서 세로 화면으로 출발해 가능한 한 높이 상승하며 여러 행성의 표본을 얻는다. 멀수록 표본 가치와 위험이 증가한다. 연료가 0이면 자동 귀환하며 귀환 거리만큼 슬롯 머신 기회를 얻는다. 안전하게 지구에 도착하면 표본과 슬롯 보상을 돈으로 바꾸고 새 우주선 구매 또는 강화를 통해 다음 원정 이점을 얻는다. 행성 충돌로 내구도가 0이면 귀환 실패이며 미정산 표본뿐 아니라 보유 돈·구매 우주선·강화까지 모두 초기화하고 개인 최고 높이만 보존한다. `launch → ascending → returning/slots → settlement/shop → relaunch` 전체를 실제 플레이 가능하게 만든다. `game/expedition.lua`/`game/scenes/play.lua`에 상태 머신 전체(고도/연료/내구도/슬롯/정산/구매/파괴 초기화)가 이미 구현되어 있었으나, 실제 LÖVE 런타임으로 전체 루프를 한 번에 구동해 검증하는 `main.lua`의 `GAME_CAPTURE_PHASE=full-loop-relaunch` 개발 하네스에 무한 루프 버그(슬롯 스핀 후 `scene:update()` 없이 즉시 재입력해 `self.slotSpin` 가드가 영원히 막힘)가 있어 검증 자체가 불가능했다. 2026-09-02 사이클에서 이 하네스 버그(`scene:update(1)` 누락)를 고치고 실제 LÖVE runtime capture(1080×1920)를 vision으로 확인해 relaunch 후 F119(연료 업그레이드 반영)·$55(정산금 반영)·신선한 상승 화면으로 정상 렌더링됨을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN.

- **행성·이펙트 발라트로 스타일 카드형 비주얼 강화 (2026-09-02, 사용자 요청, 완료):** ✅ 완료 — 사용자가 현재 행성이 "너무 밋밋하다"고 지적하며 발라트로류 카드 게임 특유의 스타일리쉬한 연출(강한 외곽 글로우/림 라이트, 부드러운 그림자, 채도 높은 그라디언트, 등급별 반짝임·파티클, 임팩트 시 스케일 펀치·흔들림)을 요청했다. 최종 텍스처는 여전히 AetherAI-only 정책을 따르되, `game/scenes/play.lua`의 Lua 도형 렌더링 레이어(외곽 글로우 링, 그라디언트 채우기, 등급별 파티클/반짝임, 표본 획득·충돌 시 pop/shake 이펙트)는 `game-effect-studio`가 만든 impact/particles/lighting 레시피를 참고해 즉시 개선 가능하며 이는 최종 텍스처 교체가 아니라 렌더링 연출이므로 AetherAI-only 제약과 무관하게 진행했다. `world.sampleTier`(common/rare/epic)별로 색·글로우 강도·파티클 밀도를 차등화했다. **2026-09-02 후속 확정 사항도 전부 완료:** `planet-style-editor` 웹 도구(신규)가 발라트로 카드풍 프리셋 6종(글로우/그라디언트/파티클/임팩트 파라미터 + gains/losses 수치)을 제공했고, 아래 발라트로 핵심 게임성 요소 6개를 전부 이식했다.
  1. **점진적 시너지/빌드업:** ✅ 완료 — 같은 hue family(azure/ember/void) 표본을 연속 채집하면 곱연산 STREAK 배율(x1.0, x1.2, x1.4...)이 붙는 콤보 시스템을 추가함. `expedition.streakMultiplier`/`M.collectSample(run, value, hueKey)`, `run.sampleStreakCount`/`sampleStreakFamily` 참고.
  2. **숫자 롤업 피드백:** ✅ 완료 — 표본 획득 "+$N" 플로팅 텍스트가 즉시 최종값으로 표시되지 않고 0.3초 동안 $0에서 실제 지급액까지 카운트업된 뒤 유지되도록 함(슬롯머신 릴이 결과에 정착하는 느낌). `PlayScene.rollupAmount`/`sampleRollupDuration`, floating text의 `awarded`/`rollupElapsed` 필드 참고.
  3. **스코어 비례 스크린쉐이크:** ✅ 완료 — 충돌 흔들림(shipShake) 강도가 표본 등급(common x1.0/rare x1.6/epic x2.4)에 비례해 스케일링되도록 함. `PlayScene.sampleTierShakeMultiplier`/`shipShakeMagnitude` 참고.
  4. **컬렉션/도감:** ✅ 완료 — 9종 표본 발견 도감 스트립(`SPECIMENS n/9`)을 런치 화면에 추가함. `world.specimenCatalog`/`collection_store.lua` 참고. 영구 보존, 파괴돼도 리셋되지 않는다.
  5. **선택 안의 트레이드오프:** ✅ 완료 — 기존 SCOUT 배 +연료/-내구도 트레이드오프를 `planet-style-editor`의 GAINS/LOSSES 수치 포맷과 통일함. `game/expedition.lua`의 `M.shipTradeoff(run, shipId)`가 `{gains={...}, losses={...}}` 행 배열을 반환하고, `game/scenes/play.lua`의 `M.scoutTradeoffLines(run)`이 이를 `"SCOUT GAINS +40 FUEL"`/`"LOSSES -1 HULL"` 두 줄로 표시한다. 향후 행성 스타일별 위험/보상도 같은 포맷을 재사용할 수 있다.
  6. **불확실성 속의 기대감:** ✅ 완료 — 슬롯머신 릴 애니메이션(기존)을 유지하고, 표본 발견 시에도 우주선이 미발견 행성의 채집 반경(+60px)에 가까워질수록 등급별 트윙클 애니메이션 속도가 1x에서 최대 3x까지 선형으로 가속되는 "다가가는 긴장" 연출을 추가함. `PlayScene.sparkleAnticipationMultiplier`/`sparkleAnticipationRange`/`sparkleAnticipationMaxMultiplier` 참고.
  - **2026-09-02 이번 사이클 최종 검수:** 실제 LÖVE runtime capture(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=ascending-sample-tiers`, 1080×1920)를 vision으로 확인해, common(회백)/rare(하늘색)/epic(금빛)이 각각 다른 외곽 글로우 색·강도로 렌더링되고 epic 행성이 두터운 금빛 림 글로우 + 보라색 그라디언트 채움으로 카드처럼 도드라져 보임을 재확인했다. `make test` GREEN, 코드 변경 없음(순수 최종 검수).

- **런치 화면 지구 탐험물 전시 (2026-09-02, 사용자 요청, 완료):** ✅ 완료 — 런치 화면 HUD와 LAUNCH LOADOUT 카드 사이의 빈 공간(지구·별 배경 위)에 9종 표본 발견 도감 스트립(`SPECIMENS n/9`, 등급별 색상 칩 + 미발견 항목은 outline만)을 추가했다. `game/world.lua`의 `specimenCatalog`/`specimenKind`(3 hue family x 3 tier), `game/collection_store.lua`(파괴돼도 리셋되지 않는 영구 저장, best_altitude_store.lua와 동일한 파일 라운드트립 패턴), `game/scenes/play.lua`의 `drawSpecimenStrip`/`specimenProgress`로 구현. 표본 최초 발견 시 2초짜리 "NEW SPECIMEN: {label}" 배너도 함께 표시된다. 실제 LÖVE 런타임 캡처(1440x2560, GAME_CAPTURE_PHASE=launch-with-specimens)로 HUD/LAUNCH LOADOUT/TAP TO LAUNCH와 겹치지 않는 것을 vision으로 확인했다(최초 배치는 TAP TO LAUNCH와 겹쳐 184px 위치로 재조정함). 이번 사이클에서 "처리 대기"에 잘못 남아있던 것을 "처리 완료"로 이동했다(코드 변경 없음, 문서 정리 + 실기기 재검증).

- **런치(첫)화면 텍스트 크기·레이아웃 정리 (2026-09-02, 사용자 확정, 최우선):** ✅ 완료 — 이전 사이클에서 런치 화면 HUD(32px 밴드)와 LAUNCH LOADOUT 카드(전체 6줄 8px 소형 폰트, 10px rowStep, `viewport.height`까지 확장된 배경 박스)를 이미 축소·재배치했다. 이번 사이클에서 실제 LÖVE 런타임 캡처(`GAME_CAPTURE=1 GAME_CAPTURE_PHASE=launch`, 1080×1920)로 재검증한 결과, 카드 박스 상단(y=204)이 지구본(중심 y=260, 반지름 58, 상단 y=202)의 실제 렌더 위치보다 2px 낮아 카드 상단 바로 위에 옅은 파란 초승달 모양이 살짝 비치는 잔여 결함을 발견했다. `game/scenes/play.lua`의 `M.launchLoadoutBoxTop`을 204→202로 올려 박스 상단이 지구본 최상단을 완전히 덮도록 수정하고, `game/self_test.lua`에 박스 상단이 지구본 최상단 이하(더 작거나 같음)임을 검증하는 회귀 테스트를 추가했다(RED 확인 후 GREEN). 수정 후 재캡처(`build/spaceship-runtime-preview-launch-verify-after.png`, gitignored 빌드 아티팩트)를 vision으로 확인해 초승달이 사라진 것을 확인했다. `make test`/`make verify LOVE=/Users/jm/.local/bin/love` 모두 GREEN.

  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 13~14항목 런타임/데이터 백엔드 최종 완료): 이전 사이클(Codex)이 15번 항목의 잔여 gap(은하계별 오즈 프로파일 연동)까지 수정 후 Rate Limit으로 인해 미커밋 상태로 종료되었음을 인지하고, Gemini fallback 사이클이 이어받아 `make verify`로 전체 테스트 통과를 재확인하고 해당 변경사항을 커밋했다. 이로써 `spaceship-gear` 레인에 할당된 항목13(JSON 외부화/웹 에디터) -> 항목9(선체 20~30종/시너지) -> 항목10(엔진 슬롯/추진효과) -> 항목12(등급/에디션) -> 항목14(효과 스키마 확장)의 데이터 및 순수 함수(run-level) 배선이 완벽하게 마무리되었다. 남은 것은 이 함수들을 호출하는 실제 UI/접근 지점(`play.lua`, `world.lua` 등)이며, 이는 레인 스코프 제약에 따라 타 레인으로 이관을 선언한다.

  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 항목7(b)/8 hubExplored safe-relaunch reset gap): M.launch()(settlement→ascending 안전 재발사)가 run.hubExplored와 run.lastVisitedGalaxyId를 초기화하지 않아, 이전 원정에서 방문한 은하 허브가 다음 원정에서도 "이미 탐사됨"으로 영구 잠기는 gap을 감사로 발견해 처리했다. destroy()는 두 필드를 전체 메타 리셋의 일부로 초기화하지만, 안전 귀환 후 재발사 경로(launch())에는 누락이었다 — 결과: 플레이어가 한 번 안전하게 허브를 방문하고 지구로 돌아오면, 이후 어떤 원정에서도 exploreHub가 즉시 nil을 반환해 허브 드롭을 영구적으로 받을 수 없게 됐다(사망하기 전까지). TDD로 testHubExploredResetsOnLaunch()를 추가했다(RED: "hubExplored must be nil for every galaxy after a safe relaunch (was true)"). launch()의 재발사 블록에 run.hubExplored = {} / run.lastVisitedGalaxyId = nil을 추가해 GREEN 전환. make verify LOVE=/Users/jm/.local/bin/love 전체 GREEN(SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:58, ASSET_MANIFEST_OK). 변경 파일은 game/expedition.lua/game/self_test.lua뿐(play.lua/i18n.lua/world.lua/game/gear.lua/game/engine_parts.lua 미변경). 다음 슬라이스: earthSlotSpin engine-slot luck 카테고리 무관성 회귀 가드 또는 항목13→9→10→12→14→15 잔여 gap 재감사.

  > 처리 상황 (spaceship-gear 레인, 2026-09-04, 13~14항목 및 잔여 gap 최종 감사 완료): 이전 슬라이스들에서 항목13(JSON/웹에디터), 항목9(선체 시너지), 항목10(엔진 분리), 항목12(등급/에디션), 항목14(효과 스키마), 항목15(오즈 프로파일)와 항목8(hub 정산)의 데이터 및 순수 함수(run-level) 배선이 완전히 종료되었음을 확인했다. 전체 코드베이스(`game/gear.lua`, `game/engine_parts.lua`, `game/expedition.lua`, `game/self_test.lua`)와 `make verify LOVE=/Users/jm/.local/bin/love`를 재감사한 결과, 더 이상의 잔여 로직 gap이나 테스트 누락이 존재하지 않음을 최종 검증(전체 GREEN, `SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`)하였다. 남은 실제 UI 연동(상점 행성 진입, 허브 팝업 등 `play.lua` / `world.lua` 영역)은 이 레인의 스코프가 아니므로 타 레인으로 완전히 이관한다. 해당 레인의 역할을 완벽히 마무리하며 사이클을 종료한다.

- (31) **허브에서 내구 회복 제거 + 초당 회복 부품** (msg `1546411887430991913`)
  - 허브 행성 힌트에서 `checkpoint_hint_repair` ("내구도 회복") 제거. 지구는 유지 (표본 판매 / 내구도 회복 / 업그레이드).
  - `launch()`가 hub 상점(`lastVisitedGalaxyId ~= nil`)에서 재출발할 때 `durability = maxDurability` 하지 않음. 지구 재출발만 풀회복.
  - 새 효과 `hullRegen` (HP/초). `expedition.update` ascending 중 누적 회복, maxDurability 캡.
  - 부품 추가 (hull): common `hull_nano_mesh` 0.2/s, uncommon `hull_repair_drone` 0.5/s, rare `hull_auto_welder` 1.0/s.
  - i18n `effect_hullRegen` EN `"REGEN +%.1f/s"` / KO `"회복 +%.1f/초"`.
  - `tools/gen_part_icons.py` 재실행.
