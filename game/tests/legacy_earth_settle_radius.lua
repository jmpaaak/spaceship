local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")

    -- INBOX (23): Earth settle radius shrink
    assert(PlayScene.earthVisualRadius == 68, "earthVisualRadius must be 68 (75% of 90)")
    assert(PlayScene.earthSettleRadius == 68,
        "earthSettleRadius must be 68, got " .. PlayScene.earthSettleRadius)
    assert(PlayScene.earthReentryRadius == 145,
        "earthReentryRadius must be 145, got " .. PlayScene.earthReentryRadius)
    assert(PlayScene.launchSpawnY == -13,
        "launchSpawnY must be 75-68-20=-13, got " .. PlayScene.launchSpawnY)

    -- Spawn must still be outside settle radius.
    local dx = PlayScene.launchSpawnX - PlayScene.earthCenterX
    local dy = PlayScene.launchSpawnY - PlayScene.earthCenterY
    local spawnDist = math.sqrt(dx * dx + dy * dy)
    assert(spawnDist > PlayScene.earthSettleRadius,
        "spawn must be outside settle radius, dist=" .. spawnDist .. " settle=" .. PlayScene.earthSettleRadius)
end

return M