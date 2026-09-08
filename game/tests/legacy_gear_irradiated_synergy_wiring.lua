local gear = require("game.gear")

local M = {}

-- Item 12's "irradiated" edition ("⚠️ 방사능처리(Irradiated) — 시너지 태그
-- 매칭 시 보너스 추가 증폭") has carried a pure conversion function,
-- gear.editionSynergyBonusAdd(editionId), since the item 12 slice -- but
-- item 9's actual synergy engine (gear.tagSynergyMultiplier/equippedTotals)
-- never once consulted it. A part's `edition` field was completely ignored
-- by the per-shared-tag-pair bonus math, so "irradiated"'s headline
-- gameplay promise (amplified synergy) was dead: equipping an irradiated
-- card produced the exact same multiplier as an un-edition'd one. This
-- closes that gap -- gear.tagSynergyMultiplier now adds
-- gear.editionSynergyBonusAdd(a.edition) + gear.editionSynergyBonusAdd(b.edition)
-- on top of the flat M.synergyBonusPerSharedPair for every shared-tag pair,
-- so an irradiated part contributes extra amplification to every synergy
-- pair it participates in (and two irradiated parts sharing a tag stack
-- both bonuses), while editions never create synergy out of thin air for
-- non-overlapping tags.
function M.run()
    local baseA = { id = "synA", tags = { "altitude" }, edition = nil, effects = { { type = "speed", value = 4 } } }
    local baseB = { id = "synB", tags = { "altitude" }, edition = nil, effects = { { type = "speed", value = 8 } } }
    local baseline = gear.tagSynergyMultiplier({ baseA, baseB })

    local irradA = { id = "synA2", tags = { "altitude" }, edition = "irradiated", effects = { { type = "speed", value = 4 } } }
    local irradB = { id = "synB2", tags = { "altitude" }, edition = nil, effects = { { type = "speed", value = 8 } } }
    local boosted = gear.tagSynergyMultiplier({ irradA, irradB })
    assert(boosted > baseline,
        "an irradiated-edition part in a shared-tag pair must add extra synergy bonus beyond the plain per-pair amount, baseline="
            .. tostring(baseline) .. " boosted=" .. tostring(boosted))
    assert(math.abs(boosted - baseline - gear.editionSynergyBonusAdd("irradiated")) < 1e-9,
        "the extra bonus over baseline must equal exactly gear.editionSynergyBonusAdd('irradiated')")

    -- Editions only AMPLIFY existing synergy -- they must never create
    -- synergy out of thin air for parts with no shared tag at all.
    local loneIrrad = { id = "lone-irrad", tags = { "void" }, edition = "irradiated", effects = {} }
    local otherTag = { id = "other-tag", tags = { "economy" }, edition = nil, effects = {} }
    assert(gear.tagSynergyMultiplier({ loneIrrad, otherTag }) == 1,
        "an irradiated part must not create synergy when tags don't overlap")

    -- Two irradiated parts sharing a tag must stack BOTH of their synergy
    -- bonus contributions on top of the flat per-pair amount.
    local doubleIrradA = { id = "di-a", tags = { "ember" }, edition = "irradiated", effects = {} }
    local doubleIrradB = { id = "di-b", tags = { "ember" }, edition = "irradiated", effects = {} }
    local doubleBoosted = gear.tagSynergyMultiplier({ doubleIrradA, doubleIrradB })
    local expectedDouble = 1 + gear.synergyBonusPerSharedPair + 2 * gear.editionSynergyBonusAdd("irradiated")
    assert(math.abs(doubleBoosted - expectedDouble) < 1e-9,
        "two irradiated parts sharing a tag must stack both parts' synergy bonus additions, expected "
            .. tostring(expectedDouble) .. " got " .. tostring(doubleBoosted))
end

return M
