local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")

    local dx = PlayScene.launchSpawnX - PlayScene.earthCenterX
    local dy = PlayScene.launchSpawnY - PlayScene.earthCenterY
    local spawnDist = math.sqrt(dx * dx + dy * dy)
    assert(spawnDist > PlayScene.earthSettleRadius,
        "launch spawn must sit outside Earth settle radius, dist=" .. spawnDist)

    local scene = PlayScene.new({})
    assert(scene.expedition.phase == "launch")
    assert(scene.ship.x == PlayScene.launchSpawnX)
    assert(scene.ship.y == PlayScene.launchSpawnY)
    scene.expedition.phase = "ascending"
    scene:update(0.05)
    assert(scene.expedition.phase == "ascending",
        "first ascending frames must not auto-settle into Earth shop")

    scene.hasLeftEarth = true
    scene.ship.x = PlayScene.earthCenterX
    scene.ship.y = PlayScene.earthCenterY
    scene:update(0.05)
    assert(scene.expedition.phase == "settlement",
        "returning into the Earth disk after leaving must settle")
end

return M