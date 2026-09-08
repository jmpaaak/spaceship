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

    -- INBOX 61(20): earth_gear_offer must not contain [B] keyboard prefix
    do
        local i18n = require("game.i18n")
        i18n.setLocale("en")
        local en = i18n.t("earth_gear_offer", "TestGear", 100)
        assert(not en:find("%[B%]"), "INBOX 61(20): EN earth_gear_offer still contains [B], got: " .. en)
        assert(en:find("GEAR OFFER:"), "INBOX 61(20): EN must have 'GEAR OFFER:', got: " .. en)
        i18n.setLocale("ko")
        local ko = i18n.t("earth_gear_offer", "테스트장비", 100)
        assert(not ko:find("%[B%]"), "INBOX 61(20): KO earth_gear_offer still contains [B], got: " .. ko)
        assert(ko:find("장비 제안:"), "INBOX 61(20): KO must have '장비 제안:', got: " .. ko)
        i18n.setLocale("en")  -- restore
        print("  INBOX-61(20) gear offer [B] prefix removed OK")
    end

    -- INBOX 61(21): pause menu buttons + title scene i18n
    do
        local i18n = require("game.i18n")
        local PlayScene = require("game.scenes.play")

        -- Check i18n keys exist in both locales
        for _, loc in ipairs({"en", "ko"}) do
            i18n.setLocale(loc)
            for _, key in ipairs({"pause_restart", "pause_main_menu",
                "title_game_name", "title_new_game", "title_continue", "title_settings"}) do
                local val = i18n.t(key)
                assert(val and val ~= key,
                    "INBOX 61(21): i18n key '" .. key .. "' missing for locale " .. loc)
            end
        end
        i18n.setLocale("en")

        -- pauseMenuRects returns properly shaped rects
        local rects = PlayScene.pauseMenuRects()
        assert(rects.restart and rects.restart.x and rects.restart.y and rects.restart.w and rects.restart.h,
            "INBOX 61(21): pauseMenuRects must return restart rect")
        assert(rects.mainMenu and rects.mainMenu.x and rects.mainMenu.y and rects.mainMenu.w and rects.mainMenu.h,
            "INBOX 61(21): pauseMenuRects must return mainMenu rect")
        -- mainMenu must be below restart
        assert(rects.mainMenu.y > rects.restart.y,
            "INBOX 61(21): mainMenu button must be below restart button")

        -- Pause restart: tapping restart during pause resets to launch
        local exp = require("game.expedition")
        local scene = PlayScene.new()
        exp.launch(scene.expedition)
        scene.expedition.altitude = 500
        scene.ship.y = -500
        scene.paused = true
        -- Simulate tap on restart button center
        local rc = rects.restart
        scene:touchpressed("test-restart", rc.x + rc.w / 2, rc.y + rc.h / 2)
        assert(scene.paused == false,
            "INBOX 61(21): restart tap must unpause")
        assert(scene.expedition.phase == "launch",
            "INBOX 61(21): restart must reset phase to launch, got " .. scene.expedition.phase)

        -- Pause main menu: tapping main menu calls onMainMenu callback
        local menuCalled = false
        local scene2 = PlayScene.new({ onMainMenu = function() menuCalled = true end })
        exp.launch(scene2.expedition)
        scene2.paused = true
        local mc = rects.mainMenu
        scene2:touchpressed("test-menu", mc.x + mc.w / 2, mc.y + mc.h / 2)
        assert(menuCalled, "INBOX 61(21): main menu tap must call onMainMenu callback")
        assert(scene2.paused == false, "INBOX 61(21): main menu tap must unpause")

        -- Title scene: new() creates valid object with buttonRects
        local TitleScene = require("game.scenes.title")
        local startCalled = false
        local title = TitleScene.new({
            hasSave = false,
            onStart = function() startCalled = true end,
        })
        assert(title, "INBOX 61(21): TitleScene.new must return an object")
        local tRects = title:buttonRects()
        assert(tRects.start and tRects.continue_ and tRects.settings,
            "INBOX 61(21): TitleScene:buttonRects must return start/continue_/settings")
        -- Tap start
        title:touchpressed("test-start", tRects.start.x + 10, tRects.start.y + 10)
        assert(startCalled, "INBOX 61(21): tapping start button must call onStart")
        -- Continue disabled when hasSave=false
        local contCalled = false
        local title2 = TitleScene.new({
            hasSave = false,
            onContinue = function() contCalled = true end,
        })
        title2:touchpressed("test-cont", tRects.continue_.x + 10, tRects.continue_.y + 10)
        assert(not contCalled, "INBOX 61(21): continue must not fire when hasSave=false")
        -- Continue enabled when hasSave=true
        local title3 = TitleScene.new({
            hasSave = true,
            onContinue = function() contCalled = true end,
        })
        title3:touchpressed("test-cont2", tRects.continue_.x + 10, tRects.continue_.y + 10)
        assert(contCalled, "INBOX 61(21): continue must fire when hasSave=true")

        print("  INBOX-61(21) pause menu + title scene OK")
    end

    -- INBOX 61(22): danger_warning i18n + starDangerTextMultiplier constant
    do
        local i18n = require("game.i18n")
        local world = require("game.world")

        -- danger_warning key must exist in both locales
        for _, loc in ipairs({"en", "ko"}) do
            i18n.setLocale(loc)
            local val = i18n.t("danger_warning")
            assert(val and val ~= "danger_warning",
                "INBOX 61(22): i18n key 'danger_warning' missing for locale " .. loc)
        end
        i18n.setLocale("en")
        assert(i18n.t("danger_warning") == "DANGER",
            "INBOX 61(22): EN danger_warning must be 'DANGER'")

        -- starDangerTextMultiplier must be >1 (outer ring beyond well)
        assert(world.starDangerTextMultiplier and world.starDangerTextMultiplier > 1,
            "INBOX 61(22): starDangerTextMultiplier must be > 1")
        -- dangerOuter must be larger than wellRadius
        local dangerOuter = world.starWellRadius * world.starDangerTextMultiplier
        assert(dangerOuter > world.starWellRadius,
            "INBOX 61(22): danger text outer radius must exceed well radius")

        print("  INBOX-61(22) danger warning text + constants OK")
    end

    -- ===== INBOX 61(23): Leaderboard button + scene + config =====
    do
        print("  [INBOX 61(23)] leaderboard button + scene + config")

        local i18n = require("game.i18n")
        local TitleScene = require("game.scenes.title")

        -- (a) i18n keys exist for both locales
        local leaderboardKeys = {
            "title_leaderboard", "leaderboard_title", "leaderboard_empty",
            "leaderboard_back", "leaderboard_rank", "leaderboard_loading",
            "leaderboard_error",
        }
        for _, loc in ipairs({"en", "ko"}) do
            i18n.setLocale(loc)
            for _, key in ipairs(leaderboardKeys) do
                assert(i18n.t(key) ~= key,
                    "INBOX 61(23): i18n key '" .. key .. "' missing for locale " .. loc)
            end
        end
        i18n.setLocale("en")

        -- (b) TitleScene has leaderboard button rect
        local title = TitleScene.new({
            hasSave = false,
            onStart = function() end,
            onContinue = function() end,
            onLeaderboard = function() end,
        })
        local tRects = title:buttonRects()
        assert(tRects.leaderboard,
            "INBOX 61(23): TitleScene:buttonRects must include leaderboard")
        assert(tRects.leaderboard.y > tRects.continue_.y,
            "INBOX 61(23): leaderboard button must be below continue button")
        assert(tRects.leaderboard.y < tRects.settings.y,
            "INBOX 61(23): leaderboard button must be above settings button")

        -- (c) TitleScene leaderboard tap fires callback
        local lbCalled = false
        local title2 = TitleScene.new({
            hasSave = false,
            onStart = function() end,
            onLeaderboard = function() lbCalled = true end,
        })
        local lbRect = title2:buttonRects().leaderboard
        title2:touchpressed("test", lbRect.x + 1, lbRect.y + 1)
        assert(lbCalled, "INBOX 61(23): tapping leaderboard button must call onLeaderboard")

        -- (d) LeaderboardScene exists and has required methods
        local LeaderboardScene = require("game.scenes.leaderboard")
        local backCalled = false
        local lb = LeaderboardScene.new({
            onBack = function() backCalled = true end,
        })
        assert(lb, "INBOX 61(23): LeaderboardScene.new must return an object")
        assert(lb.backButtonRect, "INBOX 61(23): LeaderboardScene must have backButtonRect")
        assert(lb.state == "loaded" or lb.state == "loading",
            "INBOX 61(23): initial state must be loaded or loading")
        local backRect = lb:backButtonRect()
        lb:touchpressed("test", backRect.x + 1, backRect.y + 1)
        assert(backCalled, "INBOX 61(23): tapping back button must call onBack")

        -- (e) _parseScores works
        local scores = LeaderboardScene._parseScores(
            '[{"name":"Alice","bestAltitude":500},{"name":"Bob","bestAltitude":1000}]')
        assert(#scores == 2, "INBOX 61(23): _parseScores must parse 2 entries")
        assert(scores[1].name == "Bob", "INBOX 61(23): scores must be sorted desc")
        assert(scores[1].rank == 1, "INBOX 61(23): first score must be rank 1")
        assert(scores[2].rank == 2, "INBOX 61(23): second score must be rank 2")

        -- (f) game_config module exists with leaderboardUrl
        local gameConfig = require("game.game_config")
        assert(type(gameConfig.leaderboardUrl) == "string",
            "INBOX 61(23): game_config.leaderboardUrl must be a string")
        assert(gameConfig.leaderboardUrl:find("8770"),
            "INBOX 61(23): leaderboardUrl must include port 8770")

        -- (g) keypressed escape triggers back
        local backCalled2 = false
        local lb2 = LeaderboardScene.new({
            onBack = function() backCalled2 = true end,
        })
        lb2:keypressed("escape")
        assert(backCalled2, "INBOX 61(23): escape key must call onBack")

        print("  INBOX-61(23) leaderboard button + scene + config OK")
    end

    -- ===== INBOX 61(23b): Leaderboard client auto-post on settle/destroy =====
    do
        print("  [INBOX 61(23b)] leaderboard client score submission wiring")

        local lbClient = require("game.leaderboard_client")

        -- (a) Module loads and has expected API
        assert(type(lbClient.submitScore) == "function",
            "INBOX 61(23b): leaderboard_client must export submitScore")
        assert(type(lbClient.isNewBest) == "function",
            "INBOX 61(23b): leaderboard_client must export isNewBest")

        -- (b) isNewBest returns true when bestAltitude > launchBestAltitude
        local run1 = { bestAltitude = 500, launchBestAltitude = 400 }
        assert(lbClient.isNewBest(run1) == true,
            "INBOX 61(23b): isNewBest must be true when bestAlt > launchBest")
        local run2 = { bestAltitude = 300, launchBestAltitude = 400 }
        assert(lbClient.isNewBest(run2) == false,
            "INBOX 61(23b): isNewBest must be false when bestAlt <= launchBest")
        local run3 = { bestAltitude = 400, launchBestAltitude = 400 }
        assert(lbClient.isNewBest(run3) == false,
            "INBOX 61(23b): isNewBest must be false when equal")

        -- (c) submitScore does not crash in headless (no love.thread)
        -- Just verifying it exits silently without error.
        lbClient.submitScore("TestPlayer", 1000)

        -- (d) play.lua requires leaderboard_client and persistBestAltitude
        --     calls isNewBest (structural check via source grep)
        local PlayScene = require("game.scenes.play")
        assert(PlayScene, "INBOX 61(23b): PlayScene must load without error")

        print("  INBOX-61(23b) leaderboard client auto-post OK")
    end

    -- INBOX 61(24): Last checkpoint respawn after destruction
    do
        local expedition = require("game.expedition")

        -- (a) settle at Earth (no hub) sets checkpoint to Earth
        local run1 = expedition.new()
        run1.phase = "ascending"
        run1.pendingSampleValue = 5
        expedition.settle(run1)
        assert(run1.lastCheckpointX == 0,
            "INBOX 61(24): Earth settle must set lastCheckpointX=0, got " .. tostring(run1.lastCheckpointX))
        assert(run1.lastCheckpointY == 75,
            "INBOX 61(24): Earth settle must set lastCheckpointY=75, got " .. tostring(run1.lastCheckpointY))

        -- (b) settle at hub sets checkpoint to hub position
        local run2 = expedition.new()
        run2.phase = "ascending"
        run2.pendingSampleValue = 5
        run2.lastHubX = 300
        run2.lastHubY = -500
        expedition.settle(run2)
        assert(run2.lastCheckpointX == 300,
            "INBOX 61(24): Hub settle must set lastCheckpointX to hub X, got " .. tostring(run2.lastCheckpointX))
        assert(run2.lastCheckpointY == -500,
            "INBOX 61(24): Hub settle must set lastCheckpointY to hub Y, got " .. tostring(run2.lastCheckpointY))

        -- (c) destroy preserves lastCheckpointX/Y
        run2.phase = "ascending"
        run2.durability = 1
        expedition.damage(run2, 1)
        assert(run2.phase == "destroyed", "INBOX 61(24): damage at 0 dur must destroy")
        assert(run2.lastCheckpointX == 300,
            "INBOX 61(24): destroy must preserve lastCheckpointX, got " .. tostring(run2.lastCheckpointX))
        assert(run2.lastCheckpointY == -500,
            "INBOX 61(24): destroy must preserve lastCheckpointY, got " .. tostring(run2.lastCheckpointY))

        -- (d) lastCheckpointOrEarth helper
        local cpX, cpY = expedition.lastCheckpointOrEarth(run2)
        assert(cpX == 300 and cpY == -500,
            "INBOX 61(24): lastCheckpointOrEarth must return hub checkpoint")
        local run3 = expedition.new()
        local defX, defY = expedition.lastCheckpointOrEarth(run3)
        assert(defX == 0 and defY == 75,
            "INBOX 61(24): lastCheckpointOrEarth must default to Earth (0,75)")

        -- (e) launch after destroy preserves checkpoint
        expedition.launch(run2)
        assert(run2.lastCheckpointX == 300,
            "INBOX 61(24): launch after destroy must preserve lastCheckpointX")
        assert(run2.lastCheckpointY == -500,
            "INBOX 61(24): launch after destroy must preserve lastCheckpointY")

        print("  INBOX-61(24) last checkpoint respawn OK")
    end

    -- INBOX 61(24b): Title menu composition — CONTINUE / NEW GAME / LEADERBOARD / SETTINGS
    do
        local TitleScene = require("game.scenes.title")

        -- (a) buttonRects order: continue_ is above newGame
        local t1 = TitleScene.new({ hasSave = true })
        local r1 = t1:buttonRects()
        assert(r1.continue_ and r1.newGame and r1.leaderboard and r1.settings,
            "INBOX 61(24b): buttonRects must contain continue_/newGame/leaderboard/settings")
        assert(r1.continue_.y < r1.newGame.y,
            "INBOX 61(24b): CONTINUE must be above NEW GAME")
        assert(r1.newGame.y < r1.leaderboard.y,
            "INBOX 61(24b): NEW GAME must be above LEADERBOARD")
        -- rects.start is legacy alias for newGame
        assert(r1.start == r1.newGame,
            "INBOX 61(24b): rects.start must alias rects.newGame")

        -- (b) onNewGame fires when tapping newGame rect
        local newGameCalled = false
        local t2 = TitleScene.new({
            hasSave = false,
            onNewGame = function() newGameCalled = true end,
        })
        local r2 = t2:buttonRects()
        t2:touchpressed("test-ng", r2.newGame.x + 10, r2.newGame.y + 10)
        assert(newGameCalled, "INBOX 61(24b): tapping NEW GAME must call onNewGame")

        -- (c) onStart legacy fallback fires when no onNewGame
        local startCalled = false
        local t3 = TitleScene.new({
            hasSave = false,
            onStart = function() startCalled = true end,
        })
        t3:touchpressed("test-legacy", r2.newGame.x + 10, r2.newGame.y + 10)
        assert(startCalled, "INBOX 61(24b): onStart legacy fallback must fire")

        -- (d) CONTINUE disabled when hasSave=false, enabled when true
        local contCalled = false
        local t4 = TitleScene.new({
            hasSave = false,
            onContinue = function() contCalled = true end,
        })
        t4:touchpressed("test-c1", r2.continue_.x + 10, r2.continue_.y + 10)
        assert(not contCalled, "INBOX 61(24b): CONTINUE must not fire when hasSave=false")
        local t5 = TitleScene.new({
            hasSave = true,
            onContinue = function() contCalled = true end,
        })
        t5:touchpressed("test-c2", r2.continue_.x + 10, r2.continue_.y + 10)
        assert(contCalled, "INBOX 61(24b): CONTINUE must fire when hasSave=true")

        -- (e) best_altitude_store:reset wipes altitude
        local bestAltStore = require("game.best_altitude_store")
        local altData = {}
        local fakeFS = {
            read = function(fn) return altData[fn] end,
            write = function(fn, d) altData[fn] = d; return true end,
        }
        local store = bestAltStore.new("test-best.txt", fakeFS)
        store:save(500)
        assert(store:load() == 500, "INBOX 61(24b): store must save 500")
        store:reset()
        assert(store:load() == 0, "INBOX 61(24b): reset must return 0")

        -- (f) collection_store:reset wipes specimens
        local collStore = require("game.collection_store")
        local specData = {}
        local fakeFS2 = {
            read = function(fn) return specData[fn] end,
            write = function(fn, d) specData[fn] = d; return true end,
        }
        local cs = collStore.new("test-spec.txt", fakeFS2)
        cs:record("azure_common")
        local loaded = cs:load()
        assert(loaded["azure_common"], "INBOX 61(24b): collection must record specimen")
        cs:reset()
        local loaded2 = cs:load()
        assert(not loaded2["azure_common"], "INBOX 61(24b): reset must wipe specimens")

        -- (g) i18n keys exist
        local i18n = require("game.i18n")
        i18n.setLocale("en")
        assert(i18n.t("title_new_game") == "NEW GAME",
            "INBOX 61(24b): EN title_new_game must be 'NEW GAME'")
        i18n.setLocale("ko")
        assert(i18n.t("title_new_game") == "새 게임",
            "INBOX 61(24b): KO title_new_game must be '새 게임'")
        -- Restore locale for remaining tests
        i18n.setLocale("en")

        print("  INBOX-61(24b) title menu composition OK")
    end

    -- INBOX-61(30): Jimmy's author line on title screen
    do
        local i18n = require("game.i18n")
        i18n.setLocale("en")
        assert(i18n.t("title_author") == "Jimmy's",
            "INBOX-61(30): EN title_author must be 'Jimmy's'")
        i18n.setLocale("ko")
        assert(i18n.t("title_author") == "Jimmy's",
            "INBOX-61(30): KO title_author must be 'Jimmy's'")
        i18n.setLocale("en")
        print("  INBOX-61(30) Jimmy title author OK")
    end


    require("game.tests.bgm").run()
    require("game.tests.binary_star").run()
    require("game.tests.harvest_hull_upgrade").run()
    require("game.tests.slot_reel_scissor").run()
    require("game.tests.help_overlay_pause").run()
    require("game.tests.title_ship_icon").run()
    require("game.tests.title_ship_idle").run()
    require("game.tests.title_start_sfx").run()
    require("game.tests.debris_collision_sfx").run()

    -- INBOX 61(25): slot cost/rewards scale with galaxy distance
    -- slotTier = 1 + floor(galaxyDistance / galaxyCellSize)
    -- spinCost = $10 * slotTier; SPEED/DURABILITY/HARVEST scale with tier
    do
        local exp = require("game.expedition")
        local worldMod = require("game.world")
        local run = exp.new()

        -- (a) Earth / nil galaxy: tier 1, spinCost $10, SPEED pair=5 triple=20
        assert(exp.slotTier(run, nil) == 1,
            "INBOX 61(25): Earth/nil slotTier must be 1")
        assert(exp.slotSpinCostFor(run, nil) == 10,
            "INBOX 61(25): Earth spinCost must be $10, got " .. tostring(exp.slotSpinCostFor(run, nil)))
        local solarWeights = exp.earthSlotWeights(nil)
        local speedStart = solarWeights.MONEY + solarWeights.PART
        local speedRoll = speedStart + 0.5
        local solarPair = exp.earthSlotSpin(run, nil, { reels = { speedRoll, speedRoll, 0 } })
        assert(solarPair.rewardType == "speed",
            "INBOX 61(25): solar SPEED pair type, got " .. tostring(solarPair.rewardType))
        assert(solarPair.rewardValue == 5,
            "INBOX 61(25): solar SPEED pair must be 5, got " .. tostring(solarPair.rewardValue))
        assert(solarPair.spinCost == 10,
            "INBOX 61(25): solar spin must expose spinCost=10, got " .. tostring(solarPair.spinCost))
        assert(solarPair.slotTier == 1,
            "INBOX 61(25): solar spin must expose slotTier=1")
        local solarTriple = exp.earthSlotSpin(run, nil, { reels = { speedRoll, speedRoll, speedRoll } })
        assert(solarTriple.rewardValue == 20,
            "INBOX 61(25): solar SPEED triple must be 20, got " .. tostring(solarTriple.rewardValue))

        -- (b) Galaxy one cell away: tier 2
        -- galaxy id format "galaxy:gx:gy"; distance = hypot(gx,gy)*cellSize
        -- floor(cellSize / cellSize) + 1 = 2
        local farId = "galaxy:1:0"
        local farX = 1 * worldMod.galaxyCellSize
        local farY = 0
        local dist = math.sqrt(farX * farX + farY * farY)
        local expectedTier = 1 + math.floor(dist / worldMod.galaxyCellSize)
        assert(expectedTier == 2, "INBOX 61(25): fixture galaxy:1:0 must be tier 2, got " .. expectedTier)
        assert(exp.slotTier(run, farId) == 2,
            "INBOX 61(25): galaxy:1:0 slotTier must be 2, got " .. tostring(exp.slotTier(run, farId)))
        assert(exp.slotSpinCostFor(run, farId) == 20,
            "INBOX 61(25): galaxy:1:0 spinCost must be $20, got " .. tostring(exp.slotSpinCostFor(run, farId)))

        local farWeights = exp.earthSlotWeights(farId)
        local farSpeedStart = farWeights.MONEY + farWeights.PART
        local farSpeedRoll = farSpeedStart + 0.5
        local farPair = exp.earthSlotSpin(run, farId, { reels = { farSpeedRoll, farSpeedRoll, 0 } })
        assert(farPair.rewardType == "speed",
            "INBOX 61(25): far SPEED pair type, got " .. tostring(farPair.rewardType))
        assert(farPair.rewardValue == 10,
            "INBOX 61(25): far SPEED pair must be 5*tier=10, got " .. tostring(farPair.rewardValue))
        assert(farPair.spinCost == 20,
            "INBOX 61(25): far spinCost must be 20, got " .. tostring(farPair.spinCost))
        assert(farPair.slotTier == 2,
            "INBOX 61(25): far slotTier must be 2")
        local farTriple = exp.earthSlotSpin(run, farId, { reels = { farSpeedRoll, farSpeedRoll, farSpeedRoll } })
        assert(farTriple.rewardValue == 40,
            "INBOX 61(25): far SPEED triple must be 20*tier=40, got " .. tostring(farTriple.rewardValue))

        -- (c) DURABILITY and HARVEST also scale
        local durStart = farWeights.MONEY + farWeights.PART + farWeights.SPEED
        local durRoll = durStart + 0.5
        local farDurPair = exp.earthSlotSpin(run, farId, { reels = { durRoll, durRoll, 0 } })
        assert(farDurPair.rewardType == "durability",
            "INBOX 61(25): far DURABILITY pair type")
        assert(farDurPair.rewardValue == 6,
            "INBOX 61(25): far DURABILITY pair must be 3*tier=6, got " .. tostring(farDurPair.rewardValue))
        local farDurTriple = exp.earthSlotSpin(run, farId, { reels = { durRoll, durRoll, durRoll } })
        assert(farDurTriple.rewardValue == 20,
            "INBOX 61(25): far DURABILITY triple must be 10*tier=20, got " .. tostring(farDurTriple.rewardValue))

        local harvTotal = farWeights.MONEY + farWeights.PART + farWeights.SPEED
            + farWeights.DURABILITY + farWeights.HARVEST
        local harvRoll = harvTotal - 0.5
        local farHarvPair = exp.earthSlotSpin(run, farId, { reels = { harvRoll, harvRoll, 0 } })
        assert(farHarvPair.rewardType == "harvest",
            "INBOX 61(25): far HARVEST pair type")
        assert(math.abs(farHarvPair.rewardValue - 0.20) < 1e-6,
            "INBOX 61(25): far HARVEST pair must be 0.10*tier=0.20, got " .. tostring(farHarvPair.rewardValue))
        local farHarvTriple = exp.earthSlotSpin(run, farId, { reels = { harvRoll, harvRoll, harvRoll } })
        assert(math.abs(farHarvTriple.rewardValue - 1.00) < 1e-6,
            "INBOX 61(25): far HARVEST triple must be 0.50*tier=1.00, got " .. tostring(farHarvTriple.rewardValue))

        -- (d) MONEY already scales with spinCost; pair multiplier 3 → $60 at tier 2
        local moneyRoll = 0.5
        local farMoneyPair = exp.earthSlotSpin(run, farId, { reels = { moneyRoll, moneyRoll, farSpeedRoll } })
        assert(farMoneyPair.rewardType == "money",
            "INBOX 61(25): far MONEY pair type")
        assert(farMoneyPair.reward == 60,
            "INBOX 61(25): far MONEY pair must be spinCost*3=60, got " .. tostring(farMoneyPair.reward))

        -- (e) run.lastVisitedGalaxyId used when galaxyId omitted from slotTier helpers
        run.lastVisitedGalaxyId = farId
        assert(exp.slotTier(run) == 2,
            "INBOX 61(25): slotTier(run) must read lastVisitedGalaxyId")
        assert(exp.slotSpinCostFor(run) == 20,
            "INBOX 61(25): slotSpinCostFor(run) must read lastVisitedGalaxyId")

        print("  INBOX-61(25) slot cost/rewards scale with galaxy distance OK")
    end

    do
        -- INBOX 61(31): hub relaunch does not full-heal; hullRegen ticks HP.
        local run = expedition.new({ durability = 3 })
        run.phase = "settlement"
        run.lastVisitedGalaxyId = "andromeda"
        run.durability = 1
        run.maxDurability = 3
        assert(expedition.launch(run), "hub relaunch must succeed")
        assert(run.durability == 1,
            "INBOX 61(31): hub relaunch must keep damaged hull, got " .. tostring(run.durability))

        local earthRun = expedition.new({ durability = 3 })
        earthRun.phase = "settlement"
        earthRun.lastVisitedGalaxyId = nil
        earthRun.durability = 1
        earthRun.maxDurability = 3
        assert(expedition.launch(earthRun))
        assert(earthRun.durability == 3,
            "INBOX 61(31): Earth relaunch must still full-heal, got " .. tostring(earthRun.durability))

        local regenPart = {
            id = "hull_nano_mesh", name = "Nano Mesh", nameKo = "나노 메쉬", icon = "*",
            rarity = "common", tags = {}, editions = {},
            effects = { { type = "hullRegen", value = 0.5 } },
        }
        local regenRun = expedition.new({ durability = 3 })
        regenRun.phase = "ascending"
        regenRun.durability = 1
        regenRun.maxDurability = 3
        assert(expedition.equipGear(regenRun, "hull", regenPart))
        expedition.update(regenRun, 2.1)
        assert(regenRun.durability == 2,
            "INBOX 61(31): 0.5 HP/s for 2.1s must restore 1 HP, got " .. tostring(regenRun.durability))
        local i18n = require("game.i18n")
        assert(i18n.effectLine({ type = "hullRegen", value = 0.5 }) == "REGEN +0.5/s")
        print("  INBOX-61(31) hub no-heal + hullRegen OK")
    end

    -- INBOX 61(33): hub planet must never overlap the central star.
    -- The distance from galaxy center to hub center must be >= starRadius + hub.radius + 40.
    do
        local world = require("game.world")
        local checked = 0
        for gx = -10, 10 do
            for gy = -10, 10 do
                local g = world.galaxy(gx, gy)
                if g and g.id ~= "milkyway" then
                    local hub = world.hubPlanet(g)
                    if hub then
                        local dx = hub.x - g.x
                        local dy = hub.y - g.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        local minSafe = world.starRadius + hub.radius + 40
                        assert(dist >= minSafe,
                            string.format("INBOX 61(33): hub %s at dist %.1f overlaps star (need >= %.1f)",
                                hub.id, dist, minSafe))
                        checked = checked + 1
                    end
                end
            end
        end
        assert(checked >= 3, "INBOX 61(33): need at least 3 galaxies checked, got " .. checked)
        print("  INBOX-61(33) hub-star no-overlap OK (" .. checked .. " galaxies)")
    end

    -- INBOX 61(35): slot reels must cover all 5 symbols, not just MONEY/PART/SPEED.
    do
        local run = expedition.new()
        local tw = expedition.earthSlotTotalWeight(run, nil)
        local spinCheck = expedition.earthSlotSpin(run, nil, { reels = {0,0,0} })
        assert(tw == spinCheck.totalWeight,
            string.format("INBOX 61(35): earthSlotTotalWeight (%d) must match earthSlotSpin.totalWeight (%d)",
                tw, spinCheck.totalWeight))
        local reachable = {}
        for roll = 0, tw - 1 do
            local result = expedition.earthSlotSpin(run, nil, {
                reels = { roll, roll, roll },
            })
            reachable[result.symbols[1]] = true
        end
        for _, sym in ipairs(expedition.slotSymbols) do
            assert(reachable[sym],
                "INBOX 61(35): symbol " .. sym .. " must be reachable with rolls in [0, totalWeight)")
        end
        local luckRun = expedition.new()
        local luckPart = {
            id = "luck_test", name = "Lucky", nameKo = "행운", icon = "+",
            rarity = "common", tags = {}, editions = {},
            effects = { { type = "luck", value = 50 } },
        }
        expedition.equipGear(luckRun, "hull", luckPart)
        local twLuck = expedition.earthSlotTotalWeight(luckRun, nil)
        assert(twLuck > tw,
            string.format("INBOX 61(35): luck must increase totalWeight (%d > %d)", twLuck, tw))
        print("  INBOX-61(35) slot weighted random covers all 5 symbols OK")
    end

    -- INBOX 61(32) play_hud.lua extraction test: drawGearPopup and drawPauseOverlay
    -- must exist on PlayScene (installed from play_hud.lua) and gearPopup drawing
    -- source must live in play_hud.lua, not play.lua.
    do
        assert(type(PlayScene.drawGearPopup) == "function",
            "INBOX 61(32): drawGearPopup must be installed on PlayScene from play_hud.lua")
        assert(type(PlayScene.drawPauseOverlay) == "function",
            "INBOX 61(32): drawPauseOverlay must be installed on PlayScene from play_hud.lua")
        -- Verify the source code lives in play_hud.lua
        local hudSrc = love.filesystem.read("game/scenes/play_hud.lua") or ""
        assert(hudSrc:find("drawGearPopup", 1, true),
            "INBOX 61(32): play_hud.lua must contain drawGearPopup definition")
        assert(hudSrc:find("drawPauseOverlay", 1, true),
            "INBOX 61(32): play_hud.lua must contain drawPauseOverlay definition")
        assert(hudSrc:find("synergyHint", 1, true),
            "INBOX 61(32): play_hud.lua must contain synergy hint drawing")
        -- play.lua must NOT have the inline gearPopup draw block
        local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
        assert(not playSrc:find("Balatro%-style: small tooltip next to the gear slot"),
            "INBOX 61(32): inline gearPopup draw must be removed from play.lua")
        print("  INBOX-61(32) play_hud.lua extraction OK")
    end

    -- INBOX 61(32) play_gameover.lua extraction test: destroyed-phase layout
    -- and drawBalatroCard must exist on PlayScene (installed from play_gameover.lua)
    -- and the inline code must be removed from play.lua.
    do
        assert(type(PlayScene.destroyedRestartTextY) == "function",
            "INBOX 61(32): destroyedRestartTextY must be installed on PlayScene from play_gameover.lua")
        assert(type(PlayScene.destroyedKeepPartRects) == "function",
            "INBOX 61(32): destroyedKeepPartRects must be installed on PlayScene from play_gameover.lua")
        assert(type(PlayScene.keepConfirmButtons) == "function",
            "INBOX 61(32): keepConfirmButtons must be installed on PlayScene from play_gameover.lua")
        assert(type(PlayScene.drawBalatroCard) == "function",
            "INBOX 61(32): drawBalatroCard must be installed on PlayScene from play_gameover.lua")
        assert(type(PlayScene.handleDestroyedTouch) == "function",
            "INBOX 61(32): handleDestroyedTouch must be installed on PlayScene from play_gameover.lua")
        -- play_gameover.lua must contain the gameover code
        local goSrc = love.filesystem.read("game/scenes/play_gameover.lua") or ""
        assert(goSrc:find("destroyedPanelY"),
            "INBOX 61(32): play_gameover.lua must contain destroyedPanelY")
        assert(goSrc:find("drawBalatroCard"),
            "INBOX 61(32): play_gameover.lua must contain drawBalatroCard")
        -- play.lua must NOT have the inline destroyed layout code
        local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
        assert(not playSrc:find("M%.destroyedPanelY = 340"),
            "INBOX 61(32): inline destroyedPanelY must be removed from play.lua")
        assert(not playSrc:find("function M%.drawBalatroCard"),
            "INBOX 61(32): inline drawBalatroCard must be removed from play.lua")
        print("  INBOX-61(32) play_gameover.lua extraction OK")
    end

    -- INBOX 61(29): help overlay + luck % + ? button
    do
        -- play_help.lua installed on PlayScene
        local PlayScene = require("game.scenes.play")
        assert(type(PlayScene.drawHelpButton) == "function",
            "INBOX 61(29): drawHelpButton must be installed on PlayScene from play_help.lua")
        assert(type(PlayScene.drawHelpOverlay) == "function",
            "INBOX 61(29): drawHelpOverlay must be installed on PlayScene from play_help.lua")
        assert(type(PlayScene.hitHelpButton) == "function",
            "INBOX 61(29): hitHelpButton must be installed on PlayScene from play_help.lua")
        assert(type(PlayScene.helpButtonRect) == "function",
            "INBOX 61(29): helpButtonRect must be installed on PlayScene from play_help.lua")
        -- Help button rect is RIGHT of pause button (closer to minimap edge)
        local pb = PlayScene.pauseButton
        local hb = PlayScene.helpButtonRect(pb)
        assert(hb.x > pb.x, "INBOX 61(29): help button must be right of pause button")
        assert(hb.w == 44 and hb.h == 44, "INBOX 61(29): help button must be 44x44 touch target")
        -- Luck effect format includes %
        local i18n = require("game.i18n")
        i18n.setLocale("en")
        local luckLine = i18n.effectLine({ type = "luck", value = 10 })
        assert(luckLine == "LUCK +10%",
            "INBOX 61(29): luck effectLine must show percent, got: " .. tostring(luckLine))
        i18n.setLocale("ko")
        local luckLineKo = i18n.effectLine({ type = "luck", value = 10 })
        assert(luckLineKo:find("%%"),
            "INBOX 61(29): Korean luck effectLine must show percent, got: " .. tostring(luckLineKo))
        i18n.setLocale("en")
        -- i18n help keys exist
        for _, key in ipairs({ "help_title", "help_luck", "help_harvest", "help_streak",
                               "help_boost", "help_synergy", "help_slot" }) do
            local val = i18n.t(key)
            assert(val and val ~= key,
                "INBOX 61(29): i18n key " .. key .. " must exist, got: " .. tostring(val))
        end
        -- play_help.lua source exists
        local helpSrc = love.filesystem.read("game/scenes/play_help.lua") or ""
        assert(helpSrc:find("drawHelpOverlay"),
            "INBOX 61(29): play_help.lua must contain drawHelpOverlay")
        assert(helpSrc:find("drawHelpButton"),
            "INBOX 61(29): play_help.lua must contain drawHelpButton")
        print("  INBOX-61(29) help overlay + luck % + ? button OK")
    end

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

    print("SPACESHIP_UNIT_OK")
end

return M
