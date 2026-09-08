local collectOrbit = require("game.scenes.play_collect_orbit")

local M = {}

function M.run()
    print("  [R1] play_collect_orbit module tests...")

    local expedition = {
        collectOrbitRadius = function(run, base)
            return base * run.multiplier
        end,
    }
    assert(collectOrbit.radius(14, nil, 30, expedition) == 44,
        "R1: collect orbit must preserve radius plus padding")
    assert(collectOrbit.radius(nil, {multiplier = 1.5}, 30, expedition) == 45,
        "R1: collect orbit must preserve expedition radius modifiers")

    local api = {}
    collectOrbit.install(api, expedition)
    assert(api.collectRadiusPadding == 30
            and api.collectOrbitRingAlpha == 0.3
            and api.collectOrbitRingLineWidth == 1
            and api.useCollectOrbitRimSprite == false,
        "R1: installed scene API must preserve collect-orbit constants")
    assert(api.collectOrbitRadius(14) == 44
            and api.collectOrbitRadius(10, {multiplier = 2}) == 80,
        "R1: installed scene API must preserve radius behavior")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_collect_orbit"%)'),
        "R1: play.lua must delegate collect-orbit rules")
    assert(not playSource:find("function M%.collectOrbitRadius"),
        "R1: collect-orbit radius rule must leave play.lua")

    print("  R1 play_collect_orbit module OK")
end

return M