local gear = require("game.gear")

local M = {}

-- docs/feedback/INBOX.md item 10(b): "엔진 부품은... 추진/기동 계열에
-- 특화된 효과(상승 가속, 연료 효율, 조종 반응성, 긴급 부스트/1회성 소모
-- 아이템 등)에 집중해 선체 부품(내구도/채집/시너지 등 범용)과 역할이
-- 겹치지 않도록 차별화한다." Verifies the new (G) propulsion-specialization
-- effect category exists, its conversion functions behave correctly, the
-- bundled engine_parts.json pool actually uses these types (making the
-- engine pool mechanically distinct from the hull pool), and the bundled
-- hull_parts.json pool does NOT use them (keeping hull's role generic per
-- the "역할이 겹치지 않도록" requirement).
function M.run()
    -- (G) effect types must be known and categorized.
    for _, t in ipairs({ "boostCharge" }) do
        assert(gear.knownEffectTypes[t], "effect type '" .. t .. "' must be known (item 10b)")
        assert(gear.effectCategories[t] == "G",
            "effect type '" .. t .. "' must be categorized as (G) propulsion")
    end

    -- (G) fuelEfficiency: removed in item 53b (no fuel system).

    -- (G) steeringResponsiveness: removed in item 53a (merged into speed).

    -- (G) boostCharge: discrete non-negative charge count.
    local boostPart = { id = "bc", tags = {}, effects = { { type = "boostCharge", value = 2.7 } } }
    assert(gear.boostChargeCount({ boostPart }) == 2, "boostCharge total must floor to a whole charge count")
    assert(gear.boostChargeCount({}) == 0, "no boostCharge effects must yield zero charges")

    -- The bundled engine_parts.json pool must actually use at least one of
    -- the (G) types on at least one card each, so the propulsion
    -- specialization is real content, not just dead schema.
    local enginePool = gear.loadEngineParts()
    local sawBoost = false
    for _, part in ipairs(enginePool) do
        for _, effect in ipairs(part.effects) do
            if effect.type == "boostCharge" then sawBoost = true end
        end
    end
    assert(sawBoost, "engine_parts.json must include at least one boostCharge card")

    -- The bundled hull_parts.json pool must stay free of the (G) types —
    -- item 10(b)'s "역할이 겹치지 않도록 차별화" requirement, kept as a
    -- concrete regression rather than just a doc claim.
    local hullPool = gear.loadHullParts()
    for _, part in ipairs(hullPool) do
        for _, effect in ipairs(part.effects) do
            assert(gear.effectCategories[effect.type] ~= "G",
                "hull_parts.json card '" .. part.id .. "' must not use a (G) propulsion-specialization effect type")
        end
    end
end

return M
