local world = require("game.world")

local M = {}

-- INBOX-36: Flat-$1 planet sample value characterization coverage.
function M.run()
    print("  [INBOX-36] flat $1 sample value tests...")

    -- Every planet returns $1 regardless of distance.
    assert(world.sampleValue({ y = 0 }) == 1, "sampleValue at origin must be $1")
    assert(world.sampleValue({ y = -500 }) == 1, "sampleValue at y=-500 must be $1")
    assert(world.sampleValue({ y = -2000 }) == 1, "sampleValue at y=-2000 must be $1")
    assert(world.sampleValue({ x = 1000, y = -1000 }) == 1, "sampleValue at diagonal must be $1")

    -- Sample tiers remain distance-based.
    assert(world.sampleTier({ y = -50 }) == "common")
    assert(world.sampleTier({ y = -500 }) == "rare")
    assert(world.sampleTier({ y = -1000 }) == "epic")

    -- Collision damage remains distance-based (gentle: +1 per 2000px).
    assert(world.collisionDamage({ y = -499 }) == 1)
    assert(world.collisionDamage({ y = -2000 }) == 2)

    -- A comet sample remains worth 50 times a planet sample.
    assert(world.cometSampleValue({ y = -500 }) == 50, "comet must be 50x flat $1 = $50")

    print("  INBOX-36 flat $1 sample value OK")
end

return M