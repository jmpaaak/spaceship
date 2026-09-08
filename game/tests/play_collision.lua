local collision = require("game.scenes.play_collision")

local M = {}

local deps = {
    world = {
        collisionDamage = function(planet) return planet.damage end,
        sampleValue = function(planet) return planet.value end,
    },
    expedition = {
        sampleYieldMultiplier = function(run) return run.yieldMultiplier end,
    },
    i18n = {
        t = function(key)
            local formats = {
                risk_lethal = "LETHAL -%d",
                risk_normal = "RISK -%d",
                sample_value_label = "SAMPLE $%d",
            }
            return formats[key]
        end,
    },
}

function M.run()
    print("  [R1] play_collision module tests...")

    local ascending = {phase = "ascending", durability = 3, yieldMultiplier = 1.5}
    local lethal = collision.risk(ascending, {damage = 3, value = 7}, deps)
    assert(lethal.lethal and lethal.damage == 3 and lethal.label == "LETHAL -3",
        "R1: collision risk must report lethal ascending damage")
    assert(lethal.sampleValue == 11 and lethal.sampleLabel == "SAMPLE $11",
        "R1: collision risk must preserve rounded sample yield")
    assert(collision.risk({phase = "launch"}, {damage = 1, value = 1}, deps) == nil,
        "R1: collision risk must remain ascending-only")

    local approaching = {id = "p", damage = 1, value = 2}
    assert(collision.warning(ascending, {}, approaching, 80, 100, deps),
        "R1: an unvisited approaching planet must show its risk")
    assert(collision.warning(ascending, {p = true}, approaching, 80, 100, deps) == nil,
        "R1: collided planets must not show another approach warning")
    assert(collision.warning(ascending, {}, approaching, 20, 100, deps) == nil,
        "R1: planets above the warning band must not show a warning")

    local api = {}
    collision.install(api, deps)
    local scene = setmetatable({expedition = ascending, collided = {}}, {__index = api})
    assert(scene:collisionRisk({damage = 1, value = 2}).damage == 1
            and scene:approachWarning({damage = 1, value = 2}, 80, 100),
        "R1: installed scene API must preserve collision methods")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_collision"%)'),
        "R1: play.lua must delegate collision presentation rules")
    assert(not playSource:find("function M:collisionRisk"),
        "R1: collision risk method must leave play.lua")
    assert(not playSource:find("function M:approachWarning"),
        "R1: approach warning method must leave play.lua")

    print("  R1 play_collision module OK")
end

return M
