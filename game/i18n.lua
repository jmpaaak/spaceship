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
    risk_lethal = "LETHAL -%d",
    risk_normal = "RISK -%d",
    sample_value_label = "SAMPLE $%d",
    hud_samples = "SAMPLES %02d  AT RISK $%d",
    hud_earth = "EARTH IN %d",
    hud_return_progress = "RETURN %d%%  %ds LEFT",
    hud_personal_best = "PERSONAL BEST %04d",
    hud_distance = "DIST %04d",
    hud_cash = "CASH $%d",
    hud_status = "H%d/%d %-6s S%02d",
    hud_status_no_slots = "H%d/%d %-6s",
    forecast_line = "REACH %d  SLOTS %d",
    -- docs/feedback/INBOX.md 국제화 누락 항목: game/world.lua's M.galaxy()
    -- used to hardcode "SOLAR SYSTEM"/"GALAXY %d-%d" directly, bypassing
    -- i18n entirely. Galaxy display names are now resolved at render time
    -- via world.galaxyName(galaxy) -> i18n.t(...) using these keys.
    galaxy_home = "SOLAR SYSTEM",
    galaxy_named = "GALAXY %d-%d",
    loadout_ship = "SHIP %s",
    stats_line = "HULL %d",
    -- docs/feedback/INBOX.md item 11(c): the fuel-upgrade UI purchase row
    -- was removed from EARTH SHOP (item 11b) because fuel no longer
    -- constrains flight, but this line still displayed a "FUEL LV.%d"
    -- segment that could never advance past 0 through any reachable
    -- player action (engine-level expedition.buyFuelUpgrade stays only
    -- for older regression fixtures), permanently misleading. Now shows
    -- only the still-purchasable hull upgrade level.
    upgrades_line = "HULL LV.%d",
    steer_speed_line = "STEER SPEED %d",
    fuel_bonus_line = "NEXT LAUNCH FUEL +%d",
    purchase_left = "LEFT $%d",
    purchase_short = "SHORT $%d",
    purchase_shortfall_message = "NEED $%d MORE FOR %s",
    buy_scout = "BUY SCOUT $%d",
    buy_scout_compact = "V:BUY $%d",
    select_starter = "SELECT STARTER",
    select_starter_compact = "V:STARTER",
    owned_label = "OWNED",
    select_scout = "SELECT SCOUT",
    select_scout_compact = "V:SCOUT",
    next_ship_label = "NEXT %s",
    scout_gains_line = "SCOUT GAINS %s %s",
    scout_losses_line = "LOSSES %s %s",
    ship_preview_line = "%s HULL %d",
    ship_preview_compact = "%s H%d",
    hull_action_line = "T/H HULL LV.%d>%d $%d",
    hull_action_compact = "H:LV.%d>%d $%d",
    hull_preview_compact = "HULL %d",
    yield_action_line = "T/Y YIELD LV.%d>%d $%d",
    yield_action_compact = "Y:LV.%d>%d $%d",
    yield_preview_line = "YIELD x%.2f",
    steering_action_line = "T/G STEER LV.%d>%d $%d",
    steering_action_compact = "G:LV.%d>%d $%d",
    steering_preview_compact = "SPD %d",
    -- docs/feedback/INBOX.md UI/HUD item 4: "AVG $" (formerly Korean "평균
    -- $") read as an ambiguous label for the slot machine's expected-value
    -- payout. "EV $" (Expected Value) is the precise statistical term this
    -- number represents and matches common gambling/game UI convention.
    slot_odds_line = "C%d P%d S%d  EV $%.2f",
    slot_spinning_label = "SLOT SPINNING...",
    no_slot_chances_label = "NO SLOT CHANCES",
    no_slots_compact = "NO SLOTS",
    slot_spin_prompt = "TAP: SLOT SPIN  %d LEFT",
    spin_compact_label = "SPIN %d",
    spinning_compact = "SPINNING",
    slot_result_repair = "%s +$%d REPAIR +%d  %d LEFT",
    slot_result_fuel = "%s +$%d FUEL +%d  %d LEFT",
    slot_result_sample = "%s +$%d SAMPLE +$%d  %d LEFT",
    slot_result_plain = "%s +$%d  %d LEFT",
    returning_message = "RETURNING  %d SLOT CHANCES",
    settled_message = "SETTLED +$%d  BALANCE $%d",
    floating_sample_gain = "+$%d",
    sample_streak_message = "SAMPLE +$%d  STREAK x%.1f  %s",
    sample_message = "SAMPLE +$%d  %s",
    new_specimen_label = "NEW SPECIMEN: %s",
    floating_damage_text = "-%d",
    ship_destroyed_message = "SHIP DESTROYED  BEST %d  META RESET",
    collision_message = "COLLISION -%d  HULL %d/%d",
    checkpoint_settled_message = "CHECKPOINT +$%d  BALANCE $%d",
    checkpoint_gear_message = "CHECKPOINT GEAR: %s",
    gear_bought_message = "GEAR BOUGHT: %s  BALANCE $%d",
    item_shop_gear = "SHOP GEAR",
    hull_upgraded_message = "HULL UPGRADED  LV.%d  HULL %d  %s  BALANCE $%d",
    item_hull_upgrade = "HULL UPGRADE",
    yield_upgraded_message = "SAMPLE YIELD UPGRADED  LV.%d  x%.2f  BALANCE $%d",
    item_yield_upgrade = "SAMPLE YIELD UPGRADE",
    steering_upgraded_message = "STEERING UPGRADED  LV.%d  SPEED %d  BALANCE $%d",
    item_steering_upgrade = "STEERING UPGRADE",
    scout_purchased_message = "SCOUT PURCHASED AND SELECTED  HULL %d  %s  BALANCE $%d",
    item_scout = "SCOUT",
    ship_selected_message = "%s SELECTED  HULL %d  %s",
    ascending_message = "ASCENDING  DRAG TO STEER",
    specimens_count_label = "SPECIMENS %d/%d",
    launch_loadout_title = "LAUNCH LOADOUT",
    earth_shop_title = "EARTH SHOP",
    newbest_fuel_combined = "NEW BEST!  FUEL +%d",
    newbest_label = "NEW BEST!",
    total_label = "TOTAL $%d",
    samples_settlement_line = "SAMPLES (%d) $%d",
    spins_settlement_line = "SPINS (%d) $%d",
    peak_alt_line = "PEAK ALT %d",
    tap_relaunch = "TAP: RELAUNCH",
    ship_destroyed_title = "SHIP DESTROYED",
    lost_total_line = "LOST TOTAL $%d",
    meta_reset_line = "META RESET  BEST %d",
    next_ship_line = "NEXT %s",
    tap_start_over = "TAP: START OVER",
    hold_left = "HOLD LEFT",
    hold_right = "HOLD RIGHT",
    spinning_label = "SPINNING...",
    win_repair_line = "WIN +$%d  REPAIR +%d",
    win_fuel_line = "WIN +$%d  FUEL +%d",
    win_sample_line = "WIN +$%d  SAMPLE +$%d",
    win_pending_line = "WIN +$%d  PENDING $%d",
    button_left = "LEFT",
    button_right = "RIGHT",
    minimap_out = "OUT %d",
    dev_placeholder = "DEV PLACEHOLDER",
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
    risk_lethal = "치명 -%d",
    risk_normal = "위험 -%d",
    sample_value_label = "표본 $%d",
    hud_samples = "표본 %02d  위험 $%d",
    hud_earth = "지구까지 %d",
    hud_return_progress = "귀환 %d%%  %d초",
    hud_personal_best = "최고기록 %04d",
    hud_distance = "거리 %04d",
    hud_cash = "자금 $%d",
    hud_status = "H%d/%d %-6s S%02d",
    hud_status_no_slots = "H%d/%d %-6s",
    forecast_line = "도달예상 %d  슬롯 %d",
    galaxy_home = "태양계",
    galaxy_named = "은하 %d-%d",
    loadout_ship = "함선 %s",
    stats_line = "선체 %d",
    upgrades_line = "선체 LV.%d",
    steer_speed_line = "조종속도 %d",
    fuel_bonus_line = "다음발사 연료 +%d",
    purchase_left = "잔액 $%d",
    purchase_short = "부족 $%d",
    purchase_shortfall_message = "$%d 부족: %s",
    buy_scout = "정찰선구매 $%d",
    buy_scout_compact = "V:구매 $%d",
    select_starter = "기본선 선택",
    select_starter_compact = "V:기본선",
    owned_label = "보유중",
    select_scout = "정찰선 선택",
    select_scout_compact = "V:정찰선",
    next_ship_label = "다음 %s",
    scout_gains_line = "정찰선 이득 %s %s",
    scout_losses_line = "손실 %s %s",
    ship_preview_line = "%s 선체 %d",
    ship_preview_compact = "%s H%d",
    hull_action_line = "T/H 선체 LV.%d>%d $%d",
    hull_action_compact = "H:LV.%d>%d $%d",
    hull_preview_compact = "선체 %d",
    yield_action_line = "T/Y 산출 LV.%d>%d $%d",
    yield_action_compact = "Y:LV.%d>%d $%d",
    yield_preview_line = "산출 x%.2f",
    steering_action_line = "T/G 조종 LV.%d>%d $%d",
    steering_action_compact = "G:LV.%d>%d $%d",
    steering_preview_compact = "속도 %d",
    slot_odds_line = "C%d P%d S%d  기대값 $%.2f",
    slot_spinning_label = "슬롯 회전중...",
    no_slot_chances_label = "슬롯 기회 없음",
    no_slots_compact = "슬롯없음",
    slot_spin_prompt = "탭: 슬롯회전  %d회 남음",
    spin_compact_label = "회전 %d",
    spinning_compact = "회전중",
    slot_result_repair = "%s +$%d 수리+%d  %d회",
    slot_result_fuel = "%s +$%d 연료+%d  %d회",
    slot_result_sample = "%s +$%d 표본+$%d  %d회",
    slot_result_plain = "%s +$%d  %d회",
    returning_message = "귀환중  슬롯 %d회",
    settled_message = "정산 +$%d  잔액 $%d",
    floating_sample_gain = "+$%d",
    sample_streak_message = "표본 +$%d  연속 x%.1f  %s",
    sample_message = "표본 +$%d  %s",
    new_specimen_label = "신규표본: %s",
    floating_damage_text = "-%d",
    ship_destroyed_message = "함선파괴  최고 %d  초기화",
    collision_message = "충돌 -%d  선체 %d/%d",
    checkpoint_settled_message = "체크포인트 정산 +$%d  잔액 $%d",
    checkpoint_gear_message = "체크포인트 장비: %s",
    gear_bought_message = "장비 구매: %s  잔액 $%d",
    item_shop_gear = "상점 장비",
    hull_upgraded_message = "선체 업그레이드  LV.%d  선체 %d  %s  잔액 $%d",
    item_hull_upgrade = "선체 업그레이드",
    yield_upgraded_message = "표본산출 업그레이드  LV.%d  x%.2f  잔액 $%d",
    item_yield_upgrade = "표본산출 업그레이드",
    steering_upgraded_message = "조종 업그레이드  LV.%d  속도 %d  잔액 $%d",
    item_steering_upgrade = "조종 업그레이드",
    scout_purchased_message = "정찰선 구매완료  선체 %d  %s  잔액 $%d",
    item_scout = "정찰선",
    ship_selected_message = "%s 선택  선체 %d  %s",
    ascending_message = "상승중  드래그 조종",
    specimens_count_label = "표본 %d/%d",
    launch_loadout_title = "발사 장비",
    earth_shop_title = "지구 상점",
    newbest_fuel_combined = "신기록!  연료+%d",
    newbest_label = "신기록!",
    total_label = "합계 $%d",
    samples_settlement_line = "표본 (%d) $%d",
    spins_settlement_line = "회전 (%d) $%d",
    peak_alt_line = "최고고도 %d",
    tap_relaunch = "탭: 재발사",
    ship_destroyed_title = "함선 파괴",
    lost_total_line = "손실합계 $%d",
    meta_reset_line = "초기화  최고 %d",
    next_ship_line = "다음 %s",
    tap_start_over = "탭: 다시시작",
    hold_left = "좌 유지",
    hold_right = "우 유지",
    spinning_label = "회전중...",
    win_repair_line = "승리 +$%d  수리+%d",
    win_fuel_line = "승리 +$%d  연료+%d",
    win_sample_line = "승리 +$%d  표본+$%d",
    win_pending_line = "승리 +$%d  대기 $%d",
    button_left = "좌",
    button_right = "우",
    minimap_out = "외부 %d",
    dev_placeholder = "개발 임시본",
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

function M.phaseAbbrev(phase)
    local table_ = locales[locale] or locales[DEFAULT_LOCALE]
    local map = table_.phase_abbrev or locales[DEFAULT_LOCALE].phase_abbrev
    return map[phase] or locales[DEFAULT_LOCALE].phase_abbrev[phase] or phase
end

M.locales = locales

return M
