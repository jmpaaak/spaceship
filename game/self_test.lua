require("game.i18n").setLocale("en")
local shipModule = require("game.ship")
local world = require("game.world")
local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")
local M = {}

-- Groups the gear-editor <-> gear.lua sync regression checks into one
-- wrapper so M.run() only references a single suite upvalue
-- (Lua's 60-upvalue-per-function ceiling: this suite has grown enough
-- local test functions that M.run() itself was about to exceed it).
local function testGearEditorSyncSuite()
    require("game.tests.legacy_gear_editor_whitelists").runAll()
end

-- Module-level gear test suite (kept outside M.run() so M.run() only
-- consumes 1 upvalue for this reference instead of 47+, staying within
-- Lua 5.1's 60-upvalue-per-function limit).
local function runGearTests()
    require("game.tests.legacy_gear_json").run()
    require("game.tests.legacy_gear_synergy").run()
    require("game.tests.legacy_engine_parts_slots").run()
    require("game.tests.legacy_gear_rarity_editions").run()
    testGearEditorSyncSuite()
    require("game.tests.legacy_gear_schema_docs").run()
    require("game.tests.legacy_gear_effect_schema").run()
    require("game.tests.legacy_engine_propulsion").run()
    require("game.tests.legacy_gear_effect_content").run()
    require("game.tests.legacy_engine_effect_viability").run()
    require("game.tests.legacy_gear_category_coverage").run()
    require("game.tests.legacy_gear_run_wiring").run()
    require("game.tests.legacy_gear_propulsion_run_wiring").run()
    require("game.tests.legacy_gear_survival_economy_wiring").run()
    require("game.tests.legacy_gear_insurance_category_wiring").run()
    require("game.tests.legacy_gear_offer_rolling").run()
    require("game.tests.legacy_gear_run_effect_wiring").run()
    require("game.tests.legacy_gear_sell_multiplier_wiring").run()
    require("game.tests.legacy_gear_collision_radius_wiring").run()
    require("game.tests.legacy_gear_hull_durability_wiring").run()
    require("game.tests.legacy_gear_hull_speed_wiring").run()
    require("game.tests.legacy_gear_engine_speed_wiring").run()
    require("game.tests.legacy_gear_money_run_wiring").run()
    require("game.tests.legacy_gear_streak_multiplier_wiring").run()
    require("game.tests.legacy_gear_chain_trigger_consumption_wiring").run()
    require("game.tests.legacy_gear_reroll_offer_spend_wiring").run()
    require("game.tests.legacy_gear_slot_swap_economy_wiring").run()
    require("game.tests.legacy_gear_crystallized_sell_premium_wiring").run()
    require("game.tests.legacy_gear_buy_economy_wiring").run()
    require("game.tests.legacy_gear_shop_planet_purchase_wiring").run()
    require("game.tests.legacy_gear_no_slot_cost_edition_wiring").run()
    require("game.tests.legacy_gear_no_slot_cost_engine_slot_wiring").run()
    require("game.tests.legacy_gear_irradiated_synergy_wiring").run()
    require("game.tests.legacy_gear_galaxy_exclusive_wiring").run()
    require("game.tests.legacy_gear_galaxy_exclusive_engine_pool_wiring").run()
    require("game.tests.legacy_gear_slot_exclusive_parts_wiring").run()
    require("game.tests.legacy_gear_explore_hub_edition_rolling").run()
    require("game.tests.legacy_gear_equipped_edition_effects_run_wiring").run()
    require("game.tests.legacy_gear_quantum_flawed_engine_drawback_wiring").run()
    require("game.tests.legacy_gear_engine_synergy_multiplier_wiring").run()
    require("game.tests.legacy_gear_boosts_used_destroy_reset").run()
    require("game.tests.legacy_hub_explored_resets_on_launch").run()
    require("game.tests.legacy_hub_partial_settlement").run()
    require("game.tests.legacy_hub_partial_settlement_gear_interaction").run()
    require("game.tests.legacy_hub_settle_streak_persistence").run()
    require("game.tests.legacy_earth_slot_machine_galaxy_odds").run()
    require("game.tests.legacy_earth_slot_part_replacement").run()
    require("game.tests.legacy_earth_slot_part_rarity_gate").run()
    require("game.tests.legacy_gear_earth_slot_engine_luck_wiring").run()
    require("game.tests.legacy_earth_slot_profile_reward_variation").run()
    require("game.tests.legacy_slot_spin_cost_and_miss").run()
    require("game.tests.legacy_slot_editor_web_ui").run()
    require("game.tests.legacy_dead_slot_constants").run()
    require("game.tests.legacy_slot_5_symbol_weighted_rng").run()
    require("game.tests.legacy_stellar_synergies").run()
end

function M.run()
    require("game.tests.legacy_initial_smoke").run()

    require("game.tests.legacy_specimen_catalog").run()

    require("game.tests.legacy_sample_tier_visuals").run()

    require("game.tests.legacy_collision_shake").run()

    local riskScene = require("game.tests.legacy_collision_risk").run()

    require("game.tests.legacy_hud").run(riskScene)
    require("game.tests.legacy_collision_feedback").run(riskScene)

    require("game.tests.legacy_basic_expedition").run()

    require("game.tests.legacy_expedition_upgrades").run()

    require("game.tests.legacy_sample_streak").run()

    require("game.tests.legacy_steering_upgrade").run()

    require("game.tests.speed_display").run()

    require("game.tests.legacy_ship_shop").run()

    require("game.tests.legacy_settlement_shop_input").run()

    require("game.tests.legacy_touch_flight_settlement").run()

    require("game.tests.legacy_loadout_lines").run()

    require("game.tests.legacy_shop_loadout_lines").run()

    require("game.tests.legacy_destruction_persistence").run()

    require("game.tests.legacy_collection_store").run()

    require("game.tests.legacy_best_altitude_persistence").run()

    require("game.tests.legacy_sample_collection_floating_text").run()

    require("game.tests.legacy_settlement_touch_layout").run()


    require("game.tests.legacy_destroyed_launch_touch").run()

    require("game.tests.legacy_launch_loadout_layout").run()

    require("game.tests.legacy_ascending_touch_steering").run()

    -- Omnidirectional joystick movement (docs/GAME_DESIGN.md 이동 방식 개선
    -- 항목 1, "조이스틱을 통해 전방향으로 이동 가능함").
    require("game.tests.legacy_inflight_slot_i18n").run()

    require("game.tests.legacy_expedition_removed_slots").run()

    require("game.tests.legacy_shop_loadout_removed_fuel").run()

    require("game.tests.legacy_shop_planet_modal_keyboard").run()

    require("game.tests.legacy_earth_shop_slot_keyboard").run()

    require("game.tests.legacy_earth_slot_reward_profile").run()

    require("game.tests.legacy_dead_settlement_slot_fields").run()

    require("game.tests.legacy_earth_shop_gear_offer_keyboard").run()

    require("game.tests.legacy_joystick").run()
    require("game.tests.legacy_galaxy_structure").run()
    require("game.tests.legacy_world_generation").run()
    require("game.tests.legacy_debris").run()
    require("game.tests.legacy_hud_icons").run()
    require("game.tests.legacy_runtime_sprites").run()
    require("game.tests.legacy_hub_proximity_settle").run()
    require("game.tests.legacy_reentry_shake").run()
    runGearTests()

    require("game.tests.legacy_hud_sprite_fallback").run()

    require("game.tests.legacy_planet_effect_sprite").run()

    require("game.tests.legacy_floating_icon_sprite").run()

    require("game.tests.legacy_panel_sprite").run()

    require("game.tests.legacy_shop_control_sprite").run()

    require("game.tests.legacy_pixel_star_sprite").run()

    require("game.tests.legacy_nearby_search_radius").run()

    require("game.tests.legacy_earth_proximity_auto_settlement").run()

    require("game.tests.legacy_central_star_gravity_well").run()

    require("game.tests.legacy_pixelplanets_planet_sprite").run()

    require("game.tests.legacy_planet_variation").run()

    require("game.tests.legacy_galaxy_structure").testMinimapStencilClip()
    require("game.tests.legacy_galaxy_structure").testMinimapEarthStarLabels()
    require("game.tests.legacy_earth_shop_start_trap").run()
    require("game.tests.legacy_faint_collect_orbit_ring").run()
    require("game.tests.legacy_hud_background").run()
    require("game.tests.legacy_settlement_slot_row").run()
    require("game.tests.legacy_pause_button").run()
    require("game.tests.legacy_gear_popup_and_keep_part").run()

    require("game.tests.legacy_planet_label_i18n").run()
    require("game.tests.legacy_earth_settle_radius").run()
    require("game.tests.legacy_collect_zoom_and_timeslip").run()

    require("game.tests.legacy_rcs_gradient").run()

    require("game.tests.legacy_comet_system").run()
    require("game.tests.station_dock").run()

    require("game.tests.legacy_flat_sample_value").run()

    require("game.tests.legacy_moon_system").run()

    require("game.tests.legacy_gear_slots_grid").run()

    require("game.tests.legacy_part_icon_infrastructure").run()

    require("game.tests.legacy_ship_stats_summary").run()

    require("game.tests.legacy_galaxy_ring_opacity").run()

    require("game.tests.legacy_hub_full_settlement_shop").run()

    require("game.tests.legacy_hub_shop_relaunch_touch").run()


    require("game.tests.legacy_slot_ui_copy").run()

    require("game.tests.legacy_shop_card_copy_layout").run()

    require("game.tests.legacy_solar_system_settlement").run()

    require("game.tests.legacy_gear_popup_chip_layout").run()

    require("game.tests.legacy_rim_marker_styling").run()

    require("game.tests.legacy_pause_time_freeze").run()

    require("game.tests.legacy_star_scan_range").run()

    require("game.tests.legacy_debris_t300").run()

    require("game.tests.legacy_keep_one_confirm").run()

    require("game.tests.legacy_planet_sheet_sprites").run()

    require("game.tests.legacy_hub_restock").run()

    require("game.tests.legacy_destroyed_restart_text").run()

    require("game.tests.legacy_hub_shop_row3_gap").run()

    require("game.tests.legacy_slot_speed_reward_separation").run()

    require("game.tests.legacy_earth_gear_offer_i18n").run()

    require("game.tests.legacy_pause_menu_title").run()

    require("game.tests.legacy_danger_warning").run()

    require("game.tests.legacy_leaderboard_scene").run()

    require("game.tests.legacy_leaderboard_client").run()

    require("game.tests.legacy_last_checkpoint").run()

    require("game.tests.legacy_title_menu_composition").run()

    require("game.tests.legacy_title_author").run()


    require("game.tests.bgm").run()
    require("game.tests.binary_star").run()
    require("game.tests.harvest_hull_upgrade").run()
    require("game.tests.slot_payout_audit").run()
    require("game.tests.slot_reel_scissor").run()
    require("game.tests.help_overlay_pause").run()
    require("game.tests.title_ship_icon").run()
    require("game.tests.title_ship_idle").run()
    require("game.tests.title_start_sfx").run()
    require("game.tests.debris_collision_sfx").run()
    require("game.tests.hub_sample_sfx").run()
    require("game.tests.recovery_effects").run()
    require("game.tests.legacy_slot_distance_scaling").run()

    require("game.tests.legacy_hub_relaunch_regen").run()

    require("game.tests.legacy_hub_star_no_overlap").run()

    require("game.tests.legacy_slot_symbol_coverage").run()

    require("game.tests.legacy_play_hud_extraction").run()

    require("game.tests.legacy_play_gameover_extraction").run()

    require("game.tests.legacy_help_overlay_luck").run()

    -- INBOX 61(34) synergy display in gear popup
    do
        local i18n = require("game.i18n")
        i18n.setLocale("en")
        -- synergyHint must return name+desc for known suits
        for _, suit in ipairs({"solar", "nebula", "void", "pulsar"}) do
            local h = i18n.synergyHint(suit)
            assert(type(h) == "table", "INBOX 61(34): synergyHint(" .. suit .. ") must be table")
            assert(h.name and #h.name > 0, "INBOX 61(34): synergyHint(" .. suit .. ").name empty")
            assert(h.desc and #h.desc > 0, "INBOX 61(34): synergyHint(" .. suit .. ").desc empty")
            -- No symbol prefixes (☀ * # ~ etc.)
            assert(not h.name:find("^[☀*#~x+@]"),
                "INBOX 61(34): synergy name must not start with symbol: " .. h.name)
        end
        -- play_hud.lua must draw synergy hint in popup (name + desc two lines)
        local hudSrc = love.filesystem.read("game/scenes/play_hud.lua") or ""
        assert(hudSrc:find("synergyHint"), "INBOX 61(34): play_hud.lua must use synergyHint")
        assert(hudSrc:find("hint%.name"), "INBOX 61(34): play_hud.lua must draw hint.name")
        assert(hudSrc:find("hint%.desc"), "INBOX 61(34): play_hud.lua must draw hint.desc")
        i18n.setLocale("en")
        print("  INBOX-61(34) synergy display in gear popup OK")
    end

    require("game.tests.shop_gear_rules").run()
    require("game.tests.gear_sell").run()
    require("game.tests.scout_status_hidden").run()
    require("game.tests.sfx").run()
    require("game.tests.title_to_launch_gate").run()
    require("game.tests.hud_record_label").run()
    require("game.tests.star_sprite").run()
    require("game.tests.play_draw").run()
    require("game.tests.play_scene_draw").run()
    require("game.tests.play_input").run()
    require("game.tests.play_icons").run()
    require("game.tests.play_hud_layout").run()
    require("game.tests.play_hud_gear").run()
    require("game.tests.play_sample_visuals").run()
    require("game.tests.play_sample_feedback").run()
    require("game.tests.play_planets").run()
    require("game.tests.play_sprites").run()
    require("game.tests.play_layout").run()
    require("game.tests.play_reentry").run()
    require("game.tests.play_steering").run()
    require("game.tests.play_collision").run()
    require("game.tests.play_collect_orbit").run()
    require("game.tests.play_hud_data").run()

    require("game.tests.self_test_stellar_extraction").run()
    require("game.tests.self_test_shop_card_extraction").run()
    require("game.tests.self_test_sample_visuals_extraction").run()
    require("game.tests.self_test_collision_shake_extraction").run()
    require("game.tests.self_test_specimen_catalog_extraction").run()
    require("game.tests.self_test_initial_smoke_extraction").run()
    require("game.tests.self_test_collision_risk_extraction").run()
    require("game.tests.self_test_hud_extraction").run()
    require("game.tests.self_test_collision_feedback_extraction").run()
    require("game.tests.self_test_basic_expedition_extraction").run()
    require("game.tests.self_test_upgrade_extraction").run()
    require("game.tests.self_test_sample_streak_extraction").run()
    require("game.tests.self_test_steering_upgrade_extraction").run()
    require("game.tests.self_test_ship_shop_extraction").run()
    require("game.tests.self_test_settlement_shop_input_extraction").run()
    require("game.tests.self_test_touch_flight_settlement_extraction").run()
    require("game.tests.self_test_loadout_lines_extraction").run()
    require("game.tests.self_test_shop_loadout_lines_extraction").run()
    require("game.tests.self_test_destruction_persistence_extraction").run()
    require("game.tests.self_test_collection_store_extraction").run()
    require("game.tests.self_test_best_altitude_persistence_extraction").run()
    require("game.tests.self_test_sample_collection_floating_text_extraction").run()
    require("game.tests.self_test_settlement_touch_layout_extraction").run()
    require("game.tests.self_test_destroyed_launch_touch_extraction").run()
    require("game.tests.self_test_launch_loadout_layout_extraction").run()
    require("game.tests.self_test_ascending_touch_steering_extraction").run()
    require("game.tests.self_test_inflight_slot_i18n_extraction").run()
    require("game.tests.self_test_expedition_removed_slots_extraction").run()
    require("game.tests.self_test_shop_loadout_removed_fuel_extraction").run()
    require("game.tests.self_test_shop_planet_modal_keyboard_extraction").run()
    require("game.tests.self_test_earth_shop_slot_keyboard_extraction").run()
    require("game.tests.self_test_earth_slot_reward_profile_extraction").run()
    require("game.tests.self_test_dead_settlement_slot_fields_extraction").run()
    require("game.tests.self_test_earth_shop_gear_offer_keyboard_extraction").run()
    require("game.tests.self_test_hud_sprite_fallback_extraction").run()
    require("game.tests.self_test_planet_effect_sprite_extraction").run()
    require("game.tests.self_test_floating_icon_sprite_extraction").run()
    require("game.tests.self_test_panel_sprite_extraction").run()
    require("game.tests.self_test_shop_control_sprite_extraction").run()
    require("game.tests.self_test_pixel_star_sprite_extraction").run()
    require("game.tests.self_test_nearby_search_radius_extraction").run()
    require("game.tests.self_test_earth_proximity_auto_settlement_extraction").run()
    require("game.tests.self_test_central_star_gravity_well_extraction").run()
    require("game.tests.self_test_pixelplanets_planet_sprite_extraction").run()
    require("game.tests.self_test_planet_variation_extraction").run()
    require("game.tests.self_test_solar_system_settlement_extraction").run()
    require("game.tests.self_test_gear_popup_chip_layout_extraction").run()
    require("game.tests.self_test_rim_marker_styling_extraction").run()
    require("game.tests.self_test_pause_time_freeze_extraction").run()
    require("game.tests.self_test_star_scan_range_extraction").run()
    require("game.tests.self_test_debris_t300_extraction").run()
    require("game.tests.self_test_keep_one_confirm_extraction").run()
    require("game.tests.self_test_planet_sheet_sprites_extraction").run()
    require("game.tests.self_test_hub_restock_extraction").run()
    require("game.tests.self_test_destroyed_restart_text_extraction").run()
    require("game.tests.self_test_hub_shop_row3_gap_extraction").run()
    require("game.tests.self_test_slot_speed_reward_separation_extraction").run()
    require("game.tests.self_test_earth_gear_offer_i18n_extraction").run()
    require("game.tests.self_test_pause_menu_title_extraction").run()
    require("game.tests.self_test_danger_warning_extraction").run()
    require("game.tests.self_test_leaderboard_scene_extraction").run()
    require("game.tests.self_test_leaderboard_client_extraction").run()
    require("game.tests.self_test_last_checkpoint_extraction").run()
    require("game.tests.self_test_title_menu_composition_extraction").run()
    require("game.tests.self_test_title_author_extraction").run()
    require("game.tests.self_test_slot_distance_scaling_extraction").run()
    require("game.tests.self_test_hub_relaunch_regen_extraction").run()
    require("game.tests.self_test_hub_star_no_overlap_extraction").run()
    require("game.tests.self_test_slot_symbol_coverage_extraction").run()
    require("game.tests.self_test_play_hud_extraction").run()
    require("game.tests.self_test_play_gameover_extraction").run()
    require("game.tests.self_test_help_overlay_luck_extraction").run()
    require("game.tests.world_planets_extraction").run()
    require("game.tests.planet_scatter").run()

    print("SPACESHIP_UNIT_OK")
end

return M
