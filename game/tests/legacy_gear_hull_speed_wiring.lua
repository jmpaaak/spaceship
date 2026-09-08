local expedition = require("game.expedition")

local M = {}

-- Item 9/14 (A) gap audit continued: `hullDurability` (previous slice) and
-- `sampleSellValue`/`sellMultiplier` (slice before that) were both found to
-- be validated-and-loaded but never actually READ by any run-state
-- function -- this lane's recurring "문서-코드 정합성 감사" pattern. The
-- original item 14 (A) list has five additive types
-- (speed/sampleSellValue/money/climbSpeed/hullDurability); climbSpeed,
-- sampleSellValue and hullDurability are now all wired, but `speed` (a hull
-- card's contribution to the ship's steering/maneuvering rate, distinct
-- Item 53a: effectiveSpeed now reads both hull `speed` and engine `speed`.
-- Hull cards contribute additively via equippedTotals; engine cards
-- contribute additively via aggregateEffects + tagSynergyMultiplier.
function M.run()
    -- No gear equipped: effectiveSpeed must equal baseSpeed (default 60).
    local bareRun = expedition.new()
    local baseline = expedition.effectiveSpeed(bareRun)
    assert(baseline == 60,
        "an unequipped fresh run's effectiveSpeed must equal baseSpeed 60, got "
            .. tostring(baseline))

    -- Equipping a hull card with a `speed` effect must raise effectiveSpeed
    -- by exactly that additive amount.
    local speedCard = {
        id = "hull-speed-fixture", name = "Thruster Fins", nameKo = "Thruster Fins", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "speed", value = 8 } },
    }
    local run = expedition.new()
    assert(expedition.equipGear(run, "hull", speedCard))
    local boosted = expedition.effectiveSpeed(run)
    assert(boosted == 68,
        "equipping a speed +8 hull card must raise effectiveSpeed from 60 to 68, got "
            .. tostring(boosted))

    -- An ENGINE-slot card carrying `speed` must also count (item 53a unified).
    local engineRun = expedition.new()
    local engineSpeedCard = {
        id = "engine-speed-fixture", name = "EngineSpeed", nameKo = "EngineSpeed", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "speed", value = 8 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineSpeedCard))
    local engineResult = expedition.effectiveSpeed(engineRun)
    assert(engineResult == 68,
        "speed effects on an engine-slot part must now count toward effectiveSpeed "
            .. "(item 53a unified speed), got " .. tostring(engineResult))

    -- Hull and engine speed contributions must stack additively.
    local stackedRun = expedition.new()
    assert(expedition.equipGear(stackedRun, "hull", speedCard))
    assert(expedition.equipGear(stackedRun, "engine", engineSpeedCard))
    local stacked = expedition.effectiveSpeed(stackedRun)
    assert(stacked == 76,
        "hull speed (+8) and engine speed (+8) must both add to base 60 for 76, got "
            .. tostring(stacked))
end

return M
