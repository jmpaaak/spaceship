local sceneDraw = require("game.scenes.play_scene_draw")

local M = {}

function M.run()
    print("  [R1] play_scene_draw module tests...")

    local scene = {}
    sceneDraw.install(scene, {})
    assert(type(scene.draw) == "function",
        "R1: play_scene_draw must install scene draw orchestration")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_scene_draw"%)'),
        "R1: play.lua must delegate scene drawing to play_scene_draw")
    assert(not playSource:find("function M:draw%(%s*%)"),
        "R1: draw implementation must leave play.lua")

    print("  R1 play_scene_draw module OK")
end

return M
