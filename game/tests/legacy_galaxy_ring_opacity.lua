local play = require("game.scenes.play")

local M = {}

-- INBOX-45: galaxy density <= 0.85 threshold, concentric ring alpha 0.15,
-- galaxy boundary ring alpha 0.12.
function M.run()
    -- galaxyChartLineColor alpha must be <= 0.12 (with rounding tolerance).
    local _, _, _, lineAlpha = play.galaxyChartLineColor("test")
    assert(lineAlpha ~= nil and lineAlpha <= 0.13,
        string.format(
            "INBOX-45(b): galaxyChartLineColor alpha should be ~0.12, got %s",
            tostring(lineAlpha)
        ))
    -- galaxyExistenceThreshold is covered by testMinimapGalaxyRimMarker.
    print("  INBOX-45 galaxy ring opacity OK")
end

return M