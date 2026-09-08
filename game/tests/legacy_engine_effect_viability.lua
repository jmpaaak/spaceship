local gear = require("game.gear")

local M = {}

-- Item 10/14 content-coverage gap audit (this lane's recurring "문서-코드
-- 정합성 감사" pattern applied one level deeper than
-- legacy_gear_effect_content suite): that test only checks that
-- every effect TYPE appears somewhere across the two pools combined, but
-- several run-level wrappers are documented as explicitly HULL-ONLY -- an
-- engine-slot card carrying `money`/`hullDurability`/`sampleSellValue`
-- contributes NOTHING when equipped in the engine slot. A bundled
-- engine_parts.json card whose effects are ENTIRELY drawn from that hull-only
-- set is therefore live-looking schema but dead-in-practice content: a player
-- can equip it in its only legal slot category and see zero gameplay effect.
-- Item 53a: speed is category-agnostic, so it is not hull-only.
function M.run()
    local hullOnlyTypes = {
        money = true,
        hullDurability = true, sampleSellValue = true,
    }
    local enginePool = gear.loadEngineParts()
    local deadCards = {}
    for _, part in ipairs(enginePool) do
        local hasNonHullOnlyEffect = false
        for _, effect in ipairs(part.effects) do
            if not hullOnlyTypes[effect.type] then
                hasNonHullOnlyEffect = true
                break
            end
        end
        if not hasNonHullOnlyEffect then
            deadCards[#deadCards + 1] = part.id
        end
    end
    assert(#deadCards == 0,
        "every bundled engine_parts.json card must carry at least one effect type that is NOT " ..
        "hull-only-scoped (money/hullDurability/sampleSellValue), otherwise the " ..
        "card contributes nothing when equipped in its only legal (engine) slot; dead cards: " ..
        table.concat(deadCards, ", "))
end

return M
