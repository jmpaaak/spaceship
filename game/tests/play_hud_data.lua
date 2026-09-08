local hudData = require("game.scenes.play_hud_data")

local M = {}

function M.run()
    print("  [R1] play_hud_data module tests...")

    assert(hudData.distance({x = 3, y = 79}, 0, 75) == 5,
        "R1: HUD distance must remain Euclidean from Earth's center")

    local translations = {}
    local i18n = {
        t = function(key, ...)
            translations[#translations + 1] = {key = key, args = {...}}
            return key
        end,
        phaseAbbrev = function(phase)
            return "phase:" .. phase
        end,
    }
    local world = {
        galaxyContaining = function(x, y)
            if x == 3 and y == 79 then return {id = "near"} end
        end,
        galaxyName = function(galaxy)
            return "galaxy:" .. galaxy.id
        end,
    }
    local scene = {
        earthCenterX = 0,
        earthCenterY = 75,
        ship = {x = 3, y = 79},
        expedition = {
            bestAltitude = 123.9,
            money = 45,
            durability = 6,
            maxDurability = 8,
            phase = "ascending",
        },
    }

    hudData.install(scene, {i18n = i18n, world = world})
    assert(scene:hudDistanceRaw() == 5,
        "R1: installed HUD distance API must preserve behavior")
    local lines = scene:hudLines()
    assert(lines.distance == "hud_distance"
            and lines.cash == "hud_cash"
            and lines.best == "hud_personal_best"
            and lines.status == "hud_status_no_slots"
            and lines.galaxy == "galaxy:near"
            and lines.maxDurability == 8,
        "R1: HUD line assembly must preserve all fields")
    assert(translations[1].key == "hud_personal_best"
            and translations[1].args[1] == 123
            and translations[2].key == "hud_distance"
            and translations[2].args[1] == 5
            and translations[3].key == "hud_cash"
            and translations[3].args[1] == 45
            and translations[4].key == "hud_status_no_slots"
            and translations[4].args[1] == 6
            and translations[4].args[2] == 8
            and translations[4].args[3] == "phase:ascending",
        "R1: HUD translations must preserve values and ordering")

    scene.expedition.phase = "returning"
    assert(scene:hudLines().galaxy == nil,
        "R1: galaxy line must remain hidden outside launch and ascent")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_hud_data"%)'),
        "R1: play.lua must delegate HUD data rules")
    assert(not playSource:find("function M:hudDistanceRaw"),
        "R1: HUD distance rule must leave play.lua")
    assert(not playSource:find("function M:hudLines"),
        "R1: HUD line assembly must leave play.lua")

    print("  R1 play_hud_data module OK")
end

return M
