-- Minimal i18n module: locale-keyed string.format templates.
--
-- Usage:
--   local i18n = require("game.i18n")
--   i18n.setLocale("ko")
--   i18n.t("hud_primary", 4, 100)
--
-- Every key has identical %-format specifiers in every locale so call
-- sites pass the same positional arguments regardless of language.
-- The "en" table is byte-for-byte the previous hardcoded English so
-- game/self_test.lua assertions keep passing when locale is "en".
local M = {}

local DEFAULT_LOCALE = "en"
local locale = DEFAULT_LOCALE

local locales = {}

locales.en = {
    launch_tap_to_launch = "TAP TO LAUNCH",
    paused_label = "PAUSED",
    risk_lethal = "LETHAL -%d",
    risk_normal = "RISK -%d",
    sample_value_label = "SAMPLE $%d",
    hud_samples = "SAMPLES %02d  AT RISK $%d",
    hud_earth = "EARTH IN %d",
    hud_return_progress = "RETURN %d%%  %ds LEFT",
    hud_personal_best = "PERSONAL BEST %04d",
    hud_distance = "DIST %d",
    hud_cash = "CASH $%d",
    -- Item 11: S%02d (slotOpportunities) removed — item-15 abolished in-flight
    -- slots so this segment was always "S00" (dead/misleading). hud_status and
    -- hud_status_no_slots now share the same format; hud_status_no_slots is
    -- kept as an alias for backward-compatibility with any call sites.
    hud_status = "H%d/%d %-6s",
    hud_status_no_slots = "H%d/%d %s",
    galaxy_home = "SOLAR SYSTEM",
    galaxy_names = {
        "Andromeda", "Whirlpool", "Triangulum", "Sombrero", "Pinwheel",
        "Cartwheel", "Magellanic", "Centaurus", "Cigar", "Bode's",
        "Hoag's", "Tadpole", "Black Eye", "Sculptor", "Supernova",
        "Orion", "Helix", "Cat's Eye", "Cygnus", "Pegasus"
    },
    galaxy_suffixes = {},
    galaxy_named = "%s",
    star_names = {
        "Sirius", "Vega", "Arcturus", "Rigel", "Betelgeuse",
        "Aldebaran", "Antares", "Pollux", "Deneb", "Regulus",
        "Canopus", "Achernar", "Altair", "Spica", "Fomalhaut",
        "Bellatrix", "Capella", "Procyon", "Castor", "Mizar"
    },
    hub_star_names = {
        "Proxima", "Barnard", "Luyten", "Kapteyn", "Lacaille",
        "Kruger", "Lalande", "Groombridge", "Teegarden", "Gliese",
        "Trappist", "Kepler", "Ross", "Wolf", "Epsilon Indi",
        "Tau Ceti", "61 Cygni", "40 Eridani", "Eta Cassiopeiae", "Delta Pavonis"
    },
    loadout_ship = "SHIP %s",
    stats_line = "HULL %d",
    upgrades_line = "HULL LV.%d",
    steer_speed_line = "%d",
    item_speed_upgrade = "ENGINE UPGRADE",
    purchase_left = "LEFT $%d",
    purchase_short = "SHORT $%d",
    purchase_shortfall_message = "NEED $%d MORE FOR %s",
    buy_scout = "BUY SCOUT $%d",
    buy_scout_compact = "BUY $%d",
    scout_tradeoff_compact = "+%d SPEED, %d HULL",
    select_starter = "SELECT STARTER",
    select_starter_compact = "STARTER",
    owned_label = "OWNED",
    select_scout = "SELECT SCOUT",
    select_scout_compact = "SCOUT",
    next_ship_label = "NEXT %s",
    scout_gains_line = "SCOUT GAINS %s %s",
    scout_losses_line = "LOSSES %s %s",
    ship_preview_line = "%s HULL %d",
    ship_preview_compact = "%s H%d",
    hull_action_line = "T/H HULL LV.%d>%d $%d",
    hull_action_compact = "HULL %d -> %d $%d",
    hull_preview_compact = "HULL %d",
    yield_action_line = "T/Y HARVEST LV.%d>%d $%d",
    yield_action_compact = "HARVEST x%.2f -> x%.2f $%d",
    yield_preview_line = "HARVEST x%.2f",
    steering_action_line = "T/G SPEED LV.%d>%d $%d",
    steering_action_compact = "SPEED %d -> %d $%d",
    steering_preview_compact = "%d",
    -- docs/feedback/INBOX.md UI/HUD item 4: "AVG $" (formerly Korean "평균
    -- $") read as an ambiguous label for the slot machine's expected-value
    -- payout. "EV $" (Expected Value) is the precise statistical term this
    -- number represents and matches common gambling/game UI convention.
    -- Item 15(b): Earth shop slot machine keys
    -- Item 11/15(a): returning_message no longer references in-flight slot
    -- opportunities (abolished).
    returning_message = "RETURNING  DRAG TO STEER",
    earth_slot_spin_prompt = "TAP TO SPIN!",
    earth_slot_result = "%s  +$%d",
    earth_slot_miss = "%s  NO WIN",
    earth_slot_broke = "NOT ENOUGH MONEY  NEED $%d MORE FOR SPIN",
    settled_message = "SETTLED +$%d  BALANCE $%d",
    floating_sample_gain = "+$%d",
    floating_hub_settle = "SETTLED: +$%d",
    floating_hub_gear = "NEW: %s",
    shop_modal_title = "LOCAL GALAXY SHOP",
    shop_modal_buy = "[Y] BUY: $%d",
    shop_modal_skip = "[N] LEAVE",
    sample_streak_message = "SAMPLE +$%d  STREAK x%.1f  %s",
    sample_message = "SAMPLE +$%d  %s",
    new_specimen_label = "NEW SPECIMEN: %s",
    floating_damage_text = "-%d",
    ship_destroyed_message = "SHIP DESTROYED  BEST %d  META RESET",
    collision_message = "COLLISION -%d  HULL %d/%d",
    star_well_timer = "SAMPLING %s  %.1fs LEFT",
    star_well_sample = "STAR SAMPLE",
    hull_upgraded_message = "HULL UPGRADED  LV.%d  HULL %d  BALANCE $%d",
    item_hull_upgrade = "HULL UPGRADE",
    yield_upgraded_message = "SAMPLE YIELD UPGRADED  LV.%d  x%.2f  BALANCE $%d",
    item_yield_upgrade = "SAMPLE YIELD UPGRADE",
    steering_upgraded_message = "STEERING UPGRADED  LV.%d  SPEED %d  BALANCE $%d",
    item_steering_upgrade = "STEERING UPGRADE",
    scout_purchased_message = "SCOUT PURCHASED AND SELECTED  HULL %d  BALANCE $%d",
    item_scout = "SCOUT",
    ship_selected_message = "%s SELECTED  HULL %d",
    ascending_message = "ASCENDING  DRAG TO STEER",
    return_to_earth = "↓ RETURN TO EARTH",
    equipped_gear_label = "EQUIPPED GEAR",
    launch_loadout_title = "LAUNCH LOADOUT",
    earth_shop_title = "EARTH SHOP",
    earth_shop_label = "EARTH SHOP",
    hub_shop_label = "HUB SHOP",
    -- Item 7(c): Earth shop gear purchase UI
    earth_gear_offer = "GEAR OFFER: %s  $%d",
    earth_gear_bought = "GEAR ACQUIRED: %s  BALANCE $%d",
    earth_gear_full = "GEAR SLOTS FULL  SELL EQUIPPED FIRST",
    earth_gear_broke = "NOT ENOUGH MONEY  NEED $%d MORE",
    hub_restock_btn = "RESTOCK GEAR  $%d",
    shop_err_broke = "NOT ENOUGH MONEY",
    shop_err_full_hull = "HULL SLOTS FULL",
    shop_err_full_engine = "ENGINE SLOTS FULL",
    shop_err_already = "ALREADY EQUIPPED",
    shop_err_generic = "CANNOT BUY",
    newbest_label = "NEW BEST!",
    total_label = "TOTAL $%d",
    samples_settlement_line = "SAMPLES (%d) $%d",
    spins_settlement_line = "SPINS (%d) $%d",
    peak_alt_line = "PEAK ALT %d",
    tap_relaunch = "TAP TO RELAUNCH",
    ship_destroyed_title = "GAME OVER",
    lost_total_line = "LOST TOTAL $%d",
    meta_reset_line = "MY BEST %d",
    next_ship_line = "NEXT %s",
    tap_start_over = "TAP TO START OVER",
    minimap_out = "OUT %d",
    minimap_earth_label = "Earth",
    minimap_star_label = "Sun",
    ship_stats_ship = "SHIP: %s",
    ship_stats_speed = "SPEED %d",
    ship_stats_hull = "HULL %d/%d",
    ship_stats_harvest = "HARVEST x%.2f",
    ship_stats_samples_label = "ON SAMPLE SALE",
    ship_stats_samples = "$%d",
    hub_label = "HUB",
    shop_label = "SHOP",
    planet_new_discovery = "New Planet",
    central_star_label = "Central Star",
    engine_part_available = "Engine part available",
    hull_part_available = "Hull part available",
    checkpoint_hint = "sell samples & upgrades",
    checkpoint_hint_repair = "hull repair",
    checkpoint_hint_upgrade = "upgrades",
    checkpoint_hint_sell = "sell samples",
    game_over_title = "GAME OVER",
    my_best_record = "MY BEST %d",
    keep_part_hint = "KEEP ONE PART",
    keep_confirm_title = "KEEP THIS PART?",
    keep_yes = "YES",
    keep_no = "NO",
    rarity_common = "COMMON",
    rarity_uncommon = "UNCOMMON",
    rarity_rare = "RARE",
    rarity_legendary = "LEGENDARY",
    suit_solar = "SOLAR",
    suit_nebula = "NEBULA",
    suit_void = "VOID",
    suit_pulsar = "PULSAR",
    effect_speed = "SPEED +%d",
    effect_hullDurability = "HULL %+d",
    effect_sampleSellValue = "HARVEST +%d",
    effect_money = "MONEY +%d",
    ship_name_starter = "STARTER",
    ship_name_scout = "SCOUT",
    effect_sellMultiplier = "HARVEST +%d%%",
    effect_shopDiscount = "SHOP -%d%%",
    effect_collisionRadius = "HITBOX %+d",
    effect_detectionRadius = "DETECT %+d",
    effect_luck = "LUCK +%d",
    effect_rerollBonus = "REROLL +%d",
    effect_boostCharge = "BOOST +%d",
    effect_autoCollect = "AUTO COLLECT",
    effect_chainTrigger = "CHAIN",
    effect_insurance = "INSURANCE",
    effect_streakMultiplier = "STREAK +%d%%",
    effect_hullRegen = "REGEN +%.1f/s",
    comet_label = "Comet",
    moon_label = "Moon",
    -- Stellar Origin suit synergy labels (item 16 sub-item 4)
    synergy_solarSystem  = "SOLAR SYSTEM",
    synergy_nebulaField  = "NEBULA FIELD",
    synergy_eventHorizon = "EVENT HORIZON",
    synergy_pulsarBurst  = "PULSAR BURST",
    synergy_binaryStar   = "BINARY STAR",
    synergy_supernova    = "SUPERNOVA",
    synergy_darkMatter   = "DARK MATTER",
    synergy_desc_solarSystem  = "3+ SOLAR: +1 max HP on land",
    synergy_desc_nebulaField  = "3+ NEBULA: harvest x1.5",
    synergy_desc_eventHorizon = "3+ VOID: collect +30%",
    synergy_desc_pulsarBurst  = "2+ PULSAR: streak x2",
    synergy_desc_binaryStar   = "2S+2N: +30$ on land",
    synergy_desc_supernova    = "ALL 4: legendary x1.5",
    synergy_desc_darkMatter   = "2V+2P: streak +50%",
    -- INBOX-40: gear slots HUD label
    hud_gear_label = "GEAR",
    hud_hull_label = "HULL",
    hud_engine_label = "ENGINE",
    admin_speed = "SPD+",
    admin_hull = "HULL+",
    admin_yield = "YLD+",
    effect_label = "Effect",
    -- INBOX 61(21): pause menu + title scene
    pause_restart = "RESTART",
    pause_main_menu = "MAIN MENU",
    danger_warning = "DANGER",
    title_game_name = "SPACESHIP",
    title_author = "Jimmy's",
    title_new_game = "NEW GAME",
    title_continue = "CONTINUE",
    title_settings = "SETTINGS",
    title_leaderboard = "LEADERBOARD",
    title_bgm_credit = "BGM: Space — lasercheese (CC-BY 3.0)",
    leaderboard_title = "LEADERBOARD",
    leaderboard_empty = "No scores yet",
    leaderboard_back = "BACK",
    leaderboard_rank = "#%d",
    leaderboard_loading = "Loading...",
    leaderboard_error = "Could not connect",
}

locales.en.phase_abbrev = {
    launch = "LAUNCH",
    ascending = "ASCEND",
    returning = "RETURN",
    settlement = "SETTLE",
    destroyed = "DESTRO",
}

locales.ko = {
    launch_tap_to_launch = "탭하여 발사",
    paused_label = "일시정지",
    risk_lethal = "치명 -%d",
    risk_normal = "위험 -%d",
    sample_value_label = "표본 $%d",
    hud_samples = "표본 %02d  위험 $%d",
    hud_earth = "지구까지 %d",
    hud_return_progress = "귀환 %d%%  %d초",
    hud_personal_best = "최고기록 %04d",
    hud_distance = "거리 %d",
    hud_cash = "자금 $%d",
    -- Item 11: S%02d (slotOpportunities) removed — item-15 abolished in-flight
    -- slots so this segment was always "S00" (dead/misleading). hud_status and
    -- hud_status_no_slots now share the same format; hud_status_no_slots is
    -- kept as an alias for backward-compatibility with any call sites.
    hud_status = "H%d/%d %-6s",
    hud_status_no_slots = "H%d/%d %s",
    galaxy_home = "태양계",
    galaxy_names = {
        "안드로메다", "소용돌이", "삼각형자리", "솜브레로", "바람개비",
        "수레바퀴", "마젤란", "센타우루스", "시가", "보데",
        "호그", "올챙이", "검은눈", "조각가", "초신성",
        "오리온", "나선", "고양이눈", "백조", "페가수스"
    },
    galaxy_suffixes = {},
    galaxy_named = "%s",
    star_names = {
        "시리우스", "베가", "아르크투루스", "리겔", "베텔게우스",
        "알데바란", "안타레스", "폴룩스", "데네브", "레굴루스",
        "카노푸스", "아케르나르", "알타이르", "스피카", "포말하우트",
        "벨라트릭스", "카펠라", "프로키온", "카스토르", "미자르"
    },
    hub_star_names = {
        "프록시마", "바나드", "루이텐", "카프타인", "라카유",
        "크루거", "랄란드", "그룸브리지", "티가든", "글리제",
        "트라피스트", "케플러", "로스", "볼프", "엡실론 인디",
        "타우 세티", "백조자리 61", "에리다누스 40", "에타 카시오페이아", "델타 파보니스"
    },
    loadout_ship = "함선 %s",
    stats_line = "선체 %d",
    upgrades_line = "선체 LV.%d",
    steer_speed_line = "%d",
    purchase_left = "잔액 $%d",
    purchase_short = "부족 $%d",
    purchase_shortfall_message = "$%d 부족: %s",
    buy_scout = "정찰선구매 $%d",
    buy_scout_compact = "구매 $%d",
    scout_tradeoff_compact = "+%d 속도, %d 내구도",
    select_starter = "기본선 선택",
    select_starter_compact = "기본선",
    owned_label = "보유중",
    select_scout = "정찰선 선택",
    select_scout_compact = "정찰선",
    next_ship_label = "다음 %s",
    scout_gains_line = "정찰선 이득 %s %s",
    scout_losses_line = "손실 %s %s",
    ship_preview_line = "%s 선체 %d",
    ship_preview_compact = "%s H%d",
    hull_action_line = "T/H 내구 LV.%d>%d $%d",
    hull_action_compact = "내구도 %d -> %d $%d",
    hull_preview_compact = "내구도 %d",
    yield_action_line = "T/Y 수확 LV.%d>%d $%d",
    yield_action_compact = "수확 x%.2f -> x%.2f $%d",
    yield_preview_line = "수확 x%.2f",
    steering_action_line = "T/G 속도 LV.%d>%d $%d",
    steering_action_compact = "속도 %d -> %d $%d",
    steering_preview_compact = "%d",
    -- Item 15(b): Earth shop slot machine keys
    -- Item 11/15(a): returning_message no longer references in-flight slot
    -- opportunities (abolished).
    returning_message = "귀환중  드래그 조종",
    earth_slot_spin_prompt = "탭하여 룰렛 도전!",
    earth_slot_result = "%s  +$%d",
    earth_slot_miss = "%s  꽝",
    earth_slot_broke = "잔액 부족  스핀에 $%d 더 필요",
    settled_message = "정산 +$%d  잔액 $%d",
    floating_sample_gain = "+$%d",
    floating_hub_settle = "정산완료: +$%d",
    floating_hub_gear = "획득: %s",
    shop_modal_title = "지역 은하 상점",
    shop_modal_buy = "[Y] 구매: $%d",
    shop_modal_skip = "[N] 떠나기",
    sample_streak_message = "표본 +$%d  연속 x%.1f  %s",
    sample_message = "표본 +$%d  %s",
    new_specimen_label = "신규표본: %s",
    floating_damage_text = "-%d",
    ship_destroyed_message = "함선파괴  최고 %d  초기화",
    collision_message = "충돌 -%d  선체 %d/%d",
    star_well_timer = "중심행성 (%s) 표본 채집 중 %.1f초",
    star_well_sample = "태양 표본",
    hull_upgraded_message = "선체 업그레이드  LV.%d  선체 %d  잔액 $%d",
    item_hull_upgrade = "선체 업그레이드",
    yield_upgraded_message = "수확 업그레이드  LV.%d  x%.2f  잔액 $%d",
    item_yield_upgrade = "수확 업그레이드",
    steering_upgraded_message = "조종 업그레이드  LV.%d  속도 %d  잔액 $%d",
    item_steering_upgrade = "조종 업그레이드",
    scout_purchased_message = "정찰선 구매완료  선체 %d  잔액 $%d",
    item_scout = "정찰선",
    ship_selected_message = "%s 선택  선체 %d",
    ascending_message = "상승중  드래그 조종",
    return_to_earth = "↓ 지구로 귀환",
    equipped_gear_label = "장착 장비",
    launch_loadout_title = "발사 장비",
    earth_shop_title = "지구 상점",
    earth_shop_label = "지구 상점",
    hub_shop_label = "HUB 상점",
    -- Item 7(c): Earth shop gear purchase UI
    earth_gear_offer = "장비 제안: %s  $%d",
    earth_gear_bought = "장비 획득: %s  잔액 $%d",
    earth_gear_full = "장비 슬롯 가득  장착 장비 먼저 판매",
    earth_gear_broke = "돈이 부족합니다  $%d 더 필요",
    hub_restock_btn = "장비 재입고  $%d",
    shop_err_broke = "잔액이 부족합니다",
    shop_err_full_hull = "선체부품 슬롯이 가득 찼습니다",
    shop_err_full_engine = "엔진부품 슬롯이 가득 찼습니다",
    shop_err_already = "이미 장착한 부품입니다",
    shop_err_generic = "구매할 수 없습니다",
    newbest_label = "신기록!",
    total_label = "합계 $%d",
    samples_settlement_line = "표본 (%d) $%d",
    spins_settlement_line = "회전 (%d) $%d",
    peak_alt_line = "최고고도 %d",
    tap_relaunch = "탭하여 재발사",
    ship_destroyed_title = "게임 오버",
    lost_total_line = "손실합계 $%d",
    meta_reset_line = "내 최고기록 %d",
    next_ship_line = "다음 %s",
    tap_start_over = "탭하여 다시시작",
    minimap_out = "외부 %d",
    minimap_earth_label = "지구",
    minimap_star_label = "태양",
    ship_stats_ship = "함선: %s",
    ship_stats_speed = "속도 %d",
    ship_stats_hull = "내구 %d/%d",
    ship_stats_harvest = "수확 x%.2f",
    ship_stats_samples_label = "수확 표본 판매 시",
    ship_stats_samples = "$%d",
    hub_label = "HUB",
    shop_label = "SHOP",
    planet_new_discovery = "신규 행성 발견",
    central_star_label = "중심별",
    engine_part_available = "엔진부품 획득 가능",
    hull_part_available = "선체부품 획득 가능",
    checkpoint_hint = "표본 판매와 업그레이드",
    checkpoint_hint_repair = "내구도 회복",
    checkpoint_hint_upgrade = "업그레이드",
    checkpoint_hint_sell = "표본 판매",
    game_over_title = "게임 오버",
    my_best_record = "내 최고기록 %d",
    keep_part_hint = "부품 하나 유지",
    keep_confirm_title = "이 부품을 유지할까요?",
    keep_yes = "예",
    keep_no = "아니오",
    rarity_common = "커먼",
    rarity_uncommon = "언커먼",
    rarity_rare = "레어",
    rarity_legendary = "전설",
    suit_solar = "솔라",
    suit_nebula = "네뷸라",
    suit_void = "보이드",
    suit_pulsar = "펄서",
    effect_speed = "속도 +%d",
    effect_hullDurability = "내구 %+d",
    effect_sampleSellValue = "수확 +%d",
    effect_money = "수확 +%d",
    ship_name_starter = "기본선",
    ship_name_scout = "정찰선",
    effect_sellMultiplier = "수확 +%d%%",
    effect_shopDiscount = "상점 -%d%%",
    effect_collisionRadius = "충돌 %+d",
    effect_detectionRadius = "탐지 %+d",
    effect_luck = "행운 +%d",
    effect_rerollBonus = "리롤 +%d",
    effect_boostCharge = "부스트 +%d",
    effect_autoCollect = "자동 채집",
    effect_chainTrigger = "연쇄",
    effect_insurance = "보험",
    effect_streakMultiplier = "연속 +%d%%",
    effect_hullRegen = "회복 +%.1f/초",
    comet_label = "혜성",
    moon_label = "위성",
    -- Stellar Origin suit synergy labels (item 16 sub-item 4)
    synergy_solarSystem  = "태양계 시너지",
    synergy_nebulaField  = "성운 지대",
    synergy_eventHorizon = "사건의 지평선",
    synergy_pulsarBurst  = "펄서 폭발",
    synergy_binaryStar   = "쌍성",
    synergy_supernova    = "초신성",
    synergy_darkMatter   = "암흑물질",
    synergy_desc_solarSystem  = "솔라 3+: 착지 시 최대내구 +1",
    synergy_desc_nebulaField  = "네뷸라 3+: 수확 x1.5",
    synergy_desc_eventHorizon = "보이드 3+: 채집 +30%",
    synergy_desc_pulsarBurst  = "펄서 2+: 연속 x2",
    synergy_desc_binaryStar   = "솔라2+네뷸라2: 착지 +$30",
    synergy_desc_supernova    = "4수트: 전설 x1.5",
    synergy_desc_darkMatter   = "보이드2+펄서2: 연속 +50%",
    -- INBOX-40: gear slots HUD label
    hud_gear_label = "장착",
    hud_hull_label = "선체부품",
    hud_engine_label = "엔진부품",
    admin_speed = "속도+",
    admin_hull = "내구+",
    admin_yield = "수확+",
    effect_label = "효과",
    -- INBOX 61(21): pause menu + title scene
    pause_restart = "다시 시작",
    pause_main_menu = "메인 메뉴",
    danger_warning = "위험",
    title_game_name = "우주선",
    title_author = "Jimmy's",
    title_new_game = "새 게임",
    title_continue = "이어서 하기",
    title_settings = "설정",
    title_leaderboard = "리더보드",
    title_bgm_credit = "BGM: Space — lasercheese (CC-BY 3.0)",
    leaderboard_title = "리더보드",
    leaderboard_empty = "기록이 없습니다",
    leaderboard_back = "돌아가기",
    leaderboard_rank = "#%d",
    leaderboard_loading = "불러오는 중...",
    leaderboard_error = "연결할 수 없습니다",
}

locales.ko.phase_abbrev = {
    launch = "발사",
    ascending = "상승",
    returning = "귀환",
    settlement = "상점",
    destroyed = "파괴",
}

function M.setLocale(code)
    if locales[code] then
        locale = code
    end
end

function M.getLocale()
    return locale
end

function M.t(key, ...)
    local table_ = locales[locale] or locales[DEFAULT_LOCALE]
    local template = table_[key] or locales[DEFAULT_LOCALE][key]
    assert(template, "i18n: missing key '" .. tostring(key) .. "'")
    if select("#", ...) > 0 then
        return string.format(template, ...)
    end
    return template
end

function M.partName(part)
    if type(part) ~= "table" then return tostring(part or "") end
    if locale == "ko" and type(part.nameKo) == "string" and #part.nameKo > 0 then
        return part.nameKo
    end
    return part.name or part.id or "?"
end

function M.effectLine(effect)
    if type(effect) ~= "table" then return "" end
    local key = "effect_" .. tostring(effect.type or "")
    local table_ = locales[locale] or locales[DEFAULT_LOCALE]
    local template = table_[key] or locales[DEFAULT_LOCALE][key]
    if not template then
        return tostring(effect.type or "?") .. " " .. tostring(effect.value or "")
    end
    if effect.mode == "multiply" then
        local name = (template:match("^([^%%]+)") or tostring(effect.type)):gsub("%s*%+?$", "")
        return string.format("%s ×%.1f", name, effect.value or 0)
    end
    if template:find("%%") then
        return string.format(template, effect.value or 0)
    end
    return template
end

function M.partEffects(part)
    if type(part) ~= "table" or type(part.effects) ~= "table" then return "" end
    local lines = {}
    for _, effect in ipairs(part.effects) do
        lines[#lines + 1] = M.effectLine(effect)
    end
    return table.concat(lines, "\n")
end

function M.rarityLabel(rarity)
    local key = "rarity_" .. tostring(rarity or "common")
    local table_ = locales[locale] or locales[DEFAULT_LOCALE]
    return table_[key] or locales[DEFAULT_LOCALE][key] or tostring(rarity or "")
end

function M.suitLabel(suit)
    if not suit or suit == "" then return "" end
    local key = "suit_" .. tostring(suit)
    local table_ = locales[locale] or locales[DEFAULT_LOCALE]
    return table_[key] or locales[DEFAULT_LOCALE][key] or tostring(suit)
end

-- Suit → primary synergy name + condition, shown on item inspect/acquire.
-- User 2026-09-07: prefix HUD synergy names (e.g. "* 성운 지대") onto the
-- popup condition line so the right-side HUD label is recognizable.
local suitSynergyKeys = {
    solar  = "solarSystem",
    nebula = "nebulaField",
    void   = "eventHorizon",
    pulsar = "pulsarBurst",
}

function M.synergyHint(suit)
    local key = suitSynergyKeys[suit]
    if not key then return { name = "", desc = "" } end
    return {
        name = M.t("synergy_" .. key) .. " " .. M.t("effect_label"),
        desc = M.t("synergy_desc_" .. key),
    }
end

function M.shopError(err)
    err = tostring(err or "")
    if err:find("not enough money", 1, true) then return M.t("shop_err_broke") end
    if err:find("hull slots are full", 1, true) then return M.t("shop_err_full_hull") end
    if err:find("engine slots are full", 1, true) then return M.t("shop_err_full_engine") end
    if err:find("already equipped", 1, true) then return M.t("shop_err_already") end
    return M.t("shop_err_generic")
end

function M.phaseAbbrev(phase)
    local table_ = locales[locale] or locales[DEFAULT_LOCALE]
    local map = table_.phase_abbrev or locales[DEFAULT_LOCALE].phase_abbrev
    return map[phase] or locales[DEFAULT_LOCALE].phase_abbrev[phase] or phase
end

M.locales = locales

return M
