local M = {}

function M.run()
    -- INBOX 61(9): second galaxy rim marker must be cyan (same hue as first), alpha ~0.45, smaller dot
    local PlayScene = require("game.scenes.play")
    local c1 = PlayScene.rimMarker1Color
    local c2 = PlayScene.rimMarker2Color
    assert(c1 and c2, "INBOX 61(9): rimMarker1Color and rimMarker2Color must exist")
    -- Both markers share the same cyan hue (R=0.3, G=0.9, B=0.95)
    assert(c1[1] == c2[1] and c1[2] == c2[2] and c1[3] == c2[3],
        "INBOX 61(9): both rim markers must share the same cyan RGB")
    -- Second marker alpha lower
    assert(c2[4] < c1[4], "INBOX 61(9): rimMarker2 alpha must be lower than rimMarker1")
    assert(c2[4] >= 0.4 and c2[4] <= 0.5,
        "INBOX 61(9): rimMarker2 alpha must be ~0.45, got " .. tostring(c2[4]))
    -- Second marker smaller
    assert(PlayScene.rimMarker2Radius < PlayScene.rimMarker1Radius,
        "INBOX 61(9): rimMarker2 must be smaller than rimMarker1")
    print("  INBOX-61(9) minimap rim marker colours OK")
end

return M
