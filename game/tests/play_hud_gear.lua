local hudGear = require("game.scenes.play_hud_gear")
local hudGearDraw = require("game.scenes.play_hud_gear_draw")
local loadoutDraw = require("game.scenes.play_loadout_draw")
local loadoutData = require("game.scenes.play_loadout_data")

local M = {}

function M.run()
    print("  [R1] play_hud_gear module tests...")

    local api = {
        hudHeight = function() return 100 end,
    }
    hudGear.install(api)

    assert(api.hudGearSlotSize == 48, "R1: HUD gear slot size must remain stable")
    assert(api.hudGearSlotGap == 4, "R1: HUD gear slot gap must remain stable")
    assert(api.hudGearLabelFontSize == 22, "R1: HUD gear label font must remain stable")
    assert(type(api.hudGearSlotLayout) == "function",
        "R1: play_hud_gear must install hudGearSlotLayout")
    assert(type(api.hitHudGearSlot) == "function",
        "R1: play_hud_gear must install hitHudGearSlot")

    local layout = api.hudGearSlotLayout(100)
    assert(#layout.hull == 6 and #layout.engine == 3,
        "R1: layout must expose six hull and three engine slots")
    assert(layout.hull[1].x == 5 and layout.hull[1].y == 128,
        "R1: hull slots must retain their HUD-relative origin")
    assert(layout.hull[6].y == 388, "R1: hull slots must retain vertical spacing")
    assert(layout.engineLabelY == 448 and layout.engine[1].y == 474,
        "R1: engine label and slots must remain below hull slots")

    local calls = { labels = {}, rectangles = 0 }
    local graphics = {
        getFont = function() return "previous-font" end,
        setFont = function(font) calls.lastFont = font end,
        setColor = function() end,
        printf = function(text) calls.labels[#calls.labels + 1] = text end,
        rectangle = function() calls.rectangles = calls.rectangles + 1 end,
        draw = function() end,
    }
    hudGearDraw.install(api, {
        graphics = graphics,
        fonts = { get = function(size) return "font-" .. size end },
        i18n = { t = function(key) return key end },
        getPartIcon = function() return nil end,
    })
    local drawScene = {
        expedition = {
            equippedGear = { { id = "hull-test", rarity = "legendary" } },
            equippedEngineParts = {},
        },
    }
    api.drawHudGearSlots(drawScene, 100)
    assert(calls.labels[1] == "hud_hull_label" and calls.labels[2] == "hud_engine_label",
        "R1: extracted renderer must preserve both localized labels")
    assert(calls.rectangles == 10,
        "R1: renderer must preserve one fill plus nine slot outlines")
    assert(calls.lastFont == "previous-font",
        "R1: renderer must restore the previous font")

    local loadoutCalls = { labels = {}, rectangles = 0 }
    local loadoutGraphics = {
        getFont = function() return "loadout-previous-font" end,
        setFont = function(font) loadoutCalls.lastFont = font end,
        setColor = function() end,
        printf = function(text) loadoutCalls.labels[#loadoutCalls.labels + 1] = text end,
        rectangle = function() loadoutCalls.rectangles = loadoutCalls.rectangles + 1 end,
        draw = function() end,
    }
    loadoutDraw.install(api, {
        graphics = loadoutGraphics,
        fonts = { get = function(size) return "font-" .. size end },
        i18n = { t = function(key) return key end },
        viewport = { width = 720 },
        getPartIcon = function() return nil end,
    })
    api.launchGearBoxW = 40
    api.launchGearBoxH = 50
    api.drawGearSlots({
        expedition = {
            equippedGear = { { id = "hull-test", rarity = "legendary" } },
            equippedEngineParts = {},
        },
    }, 200)
    assert(loadoutCalls.labels[1] == "equipped_gear_label",
        "R1: extracted launch loadout renderer must preserve its localized label")
    assert(loadoutCalls.rectangles == 10,
        "R1: launch loadout renderer must preserve one fill plus nine slot outlines")
    assert(loadoutCalls.lastFont == "loadout-previous-font",
        "R1: launch loadout renderer must restore the previous font")

    local function translate(key, ...)
        local values = { ... }
        for index, value in ipairs(values) do values[index] = tostring(value) end
        return key .. (next(values) and ":" .. table.concat(values, ",") or "")
    end
    local dataApi = {}
    loadoutData.install(dataApi, {
        i18n = { t = translate },
        gear = { activeSynergies = function() return { solarSystem = true } end },
        expedition = {
            effectiveSpeed = function() return 65 end,
            shipTradeoff = function()
                return {
                    gains = { { value = 20, label = "SPEED" } },
                    losses = { { value = 5, label = "HULL" } },
                }
            end,
            equippedHullDurabilityBonus = function() return 2 end,
            getScoutDurabilityBonus = function() return -6 end,
            upgradeCost = function(_, cost, level) return cost + level end,
            sampleYieldMultiplier = function() return 1.1 end,
        },
    })
    local dataRun = {
        ownedShips = { scout = false }, selectedShipId = "starter", maxDurability = 12,
        durabilityUpgradeLevel = 1, equippedGear = {}, equippedEngineParts = {}, money = 50,
        scoutShipCost = 100, baseDurability = 10, durabilityUpgradeAmount = 2,
        durabilityUpgradeCost = 20, sampleYieldUpgradeCost = 30, steeringUpgradeCost = 40,
        sampleYieldUpgradeLevel = 1, sampleYieldUpgradeAmount = 0.1,
        steeringUpgradeLevel = 2, steeringUpgradeAmount = 1, scoutClimbSpeedBonus = 20,
    }
    local dataScene = setmetatable({ expedition = dataRun }, { __index = dataApi })
    local launchLines = dataApi.loadoutLines(dataScene)
    assert(launchLines.ship == nil and launchLines.shipLabel == "STARTER"
        and launchLines.steering == "steer_speed_line:65",
        "R1: extracted launch presentation data must preserve labels and effective speed")
    assert(#launchLines.synergies == 1 and launchLines.synergies[1] == "synergy_solarSystem",
        "R1: extracted launch presentation data must preserve ordered active synergies")
    local tradeoff = dataApi.scoutTradeoffLines(dataRun)
    assert(tradeoff[1] == "scout_gains_line:20,SPEED"
        and tradeoff[2] == "scout_losses_line:5,HULL",
        "R1: extracted scout tradeoff must preserve gains/losses formatting")
    local shopLines = dataApi.shopLoadoutLines(dataScene)
    assert(shopLines.shipAction == "buy_scout:100" and shopLines.shipAffordable == false
        and shopLines.hullPreview == "stats_line:16",
        "R1: extracted shop presentation data must preserve purchase and preview values")

    local hullPart = { id = "hull-test" }
    local enginePart = { id = "engine-test" }
    local scene = {
        expedition = {
            phase = "ascending",
            equippedGear = { hullPart },
            equippedEngineParts = { enginePart },
        },
        hudLines = function() return {} end,
    }
    local hullHit = api.hitHudGearSlot(scene, 5, 128)
    assert(hullHit and hullHit.part == hullPart and hullHit.category == "hull" and hullHit.index == 1,
        "R1: occupied hull slot must be hittable")
    local engineHit = api.hitHudGearSlot(scene, 5, 474)
    assert(engineHit and engineHit.part == enginePart and engineHit.category == "engine" and engineHit.index == 1,
        "R1: occupied engine slot must be hittable")
    assert(api.hitHudGearSlot(scene, 53, 128) == nil,
        "R1: right edge must remain outside a slot")
    assert(api.hitHudGearSlot(scene, 5, 180) == nil,
        "R1: empty slots must not produce a hit")
    assert(api.hitHudGearSlot(nil, 5, 128) == nil,
        "R1: missing scene state must be safe")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_hud_gear"%)'),
        "R1: play.lua must delegate HUD gear layout to play_hud_gear")
    assert(playSource:find('require%("game%.scenes%.play_hud_gear_draw"%)'),
        "R1: play.lua must delegate HUD gear rendering to play_hud_gear_draw")
    assert(not playSource:find("function M:drawHudGearSlots"),
        "R1: drawHudGearSlots implementation must leave play.lua")
    assert(playSource:find('require%("game%.scenes%.play_loadout_draw"%)'),
        "R1: play.lua must delegate launch loadout rendering to play_loadout_draw")
    assert(not playSource:find("function M:drawGearSlots"),
        "R1: drawGearSlots implementation must leave play.lua")
    assert(playSource:find('require%("game%.scenes%.play_loadout_data"%)'),
        "R1: play.lua must delegate loadout presentation assembly to play_loadout_data")
    assert(not playSource:find("function M:loadoutLines"),
        "R1: loadoutLines implementation must leave play.lua")
    assert(not playSource:find("function M%.scoutTradeoffLines"),
        "R1: scoutTradeoffLines implementation must leave play.lua")
    assert(not playSource:find("function M:shopLoadoutLines"),
        "R1: shopLoadoutLines implementation must leave play.lua")
    assert(not playSource:find("function M%.hudGearSlotLayout"),
        "R1: hudGearSlotLayout implementation must leave play.lua")
    assert(not playSource:find("function M%.hitHudGearSlot"),
        "R1: hitHudGearSlot implementation must leave play.lua")

    print("  R1 play_hud_gear module OK")
end

return M
