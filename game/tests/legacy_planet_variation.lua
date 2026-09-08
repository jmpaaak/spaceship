local M = {}

function M.run()
    -- INBOX (12): per-planet rotation/scale variation deterministic from planet id.
    -- Same id → same result, different ids → different values.
    -- Same galaxy → same starType/palette (already tested above).
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.planetVariation) == "function",
        "PlayScene.planetVariation must be exported")

    -- nil/empty planet returns identity (0, 1.0)
    local r0, s0 = PlayScene.planetVariation(nil)
    assert(r0 == 0 and s0 == 1.0,
        "nil planet must return rotation=0, scale=1.0")
    local r1, s1 = PlayScene.planetVariation({})
    assert(r1 == 0 and s1 == 1.0,
        "planet without id must return rotation=0, scale=1.0")

    -- Determinism: same id → same values
    local rA, sA = PlayScene.planetVariation({ id = "3:4:1" })
    local rA2, sA2 = PlayScene.planetVariation({ id = "3:4:1" })
    assert(rA == rA2 and sA == sA2,
        "same planet id must produce identical rotation and scaleFactor")

    -- Different ids → at least one value differs
    local rB, sB = PlayScene.planetVariation({ id = "5:6:2" })
    assert(rA ~= rB or sA ~= sB,
        "different planet ids should produce different variation values")

    -- Rotation in [0, 2π), scaleFactor in [0.85, 1.15]
    assert(rA >= 0 and rA < 2 * math.pi,
        "rotation must be in [0, 2π), got " .. tostring(rA))
    assert(sA >= 0.85 and sA <= 1.15,
        "scaleFactor must be in [0.85, 1.15], got " .. tostring(sA))

    -- Hub/shop variation also works (they have ids like "hub:galaxy:1:2")
    local rHub, sHub = PlayScene.planetVariation({ id = "hub:galaxy:1:2" })
    assert(rHub >= 0 and rHub < 2 * math.pi, "hub rotation in range")
    assert(sHub >= 0.85 and sHub <= 1.15, "hub scaleFactor in range")
end

return M