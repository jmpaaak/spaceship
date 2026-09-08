local hudGear = require("game.scenes.play_hud_gear")

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
    assert(not playSource:find("function M%.hudGearSlotLayout"),
        "R1: hudGearSlotLayout implementation must leave play.lua")
    assert(not playSource:find("function M%.hitHudGearSlot"),
        "R1: hitHudGearSlot implementation must leave play.lua")

    print("  R1 play_hud_gear module OK")
end

return M
