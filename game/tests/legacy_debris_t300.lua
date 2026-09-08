local world = require("game.world")
local M = {}

function M.run()
    -- INBOX 61(13): debris at t=300 must still appear near origin, radius >= 5
    local pieces = world.nearbyDebris(0, 0, 4, 300)
    assert(#pieces > 0, "INBOX 61(13): debris must still exist near origin at t=300")
    for _, d in ipairs(pieces) do
        assert(d.radius >= 3,
            "INBOX 61(13): debris radius must be >= 3 (x1.3 of orig min), got " .. tostring(d.radius))
    end
    print("  INBOX-61(13) debris at t=300 OK")
end

return M
