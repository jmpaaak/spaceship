local expedition = require("game.expedition")

local M = {}

-- Item 9/14 (A) `money` gap: gear.equippedTotals has additively summed a
-- part's `money` effect since item 14's very first slice, and the bundled
-- hull_parts.json pool has carried 3 `money` cards (hull_reserve_tank +2
-- more) since item 9's expansion (plus several engine_parts.json cards),
-- but until this slice NOTHING in expedition.lua ever read that total --
-- the very last of the original five (A) additive types
-- (speed/sampleSellValue/money/climbSpeed/hullDurability) named in item 14
-- to still be silently dead content, exactly matching the pattern already
-- found and closed for speed/hullDurability/sampleSellValue above. `money`
-- is a direct settlement payout bonus (not a per-sample or per-tick rate
-- like its siblings), so it is wired into `settle(run)` -- the single
-- place a run's `money` balance is credited for a completed expedition --
-- rather than into a per-frame/per-sample function like the others.
function M.run()
    -- No gear equipped: settling a run with pending sample/slot value must
    -- credit exactly that payout, unmodified (regression baseline matching
    -- every other gear run-wrapper's "unequipped == pre-wiring behavior").
    local bareRun = expedition.new({ money = 0 })
    bareRun.phase = "ascending"
    bareRun.pendingSampleValue = 40
    bareRun.altitude = 0
    expedition.settle(bareRun)
    expedition.update(bareRun, 0.001)
    assert(bareRun.money == 40, "an unequipped run's settlement payout must equal pending sample value 40, got " .. tostring(bareRun.money))

    -- Equipping a hull card with a `money` effect must add that flat bonus
    -- on top of the sample/slot settlement payout, hull-only (matching
    -- climbSpeed/sampleSellValue/hullDurability/speed's hull-scoped design,
    -- since item 9 calls these the "선체(조커형)" combo payoff stats).
    local moneyCard = {
        id = "hull-money-fixture", name = "Cargo Broker", nameKo = "Cargo Broker", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "money", value = 15 } },
    }
    local run = expedition.new({ money = 0 })
    assert(expedition.equipGear(run, "hull", moneyCard))
    run.phase = "ascending"
    run.pendingSampleValue = 40
    run.altitude = 0
    expedition.settle(run)
    expedition.update(run, 0.001)
    assert(run.money == 55, "a money +15 hull card must raise the settlement payout from 40 to 55, got " .. tostring(run.money))

    -- Sanity: an ENGINE-slot card carrying `money` must NOT count -- item 9
    -- scopes this additive stat to hull parts, matching `speed`.
    local engineRun = expedition.new({ money = 0 })
    local engineMoneyCard = {
        id = "engine-money-fixture", name = "EngineMoney", nameKo = "EngineMoney", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "money", value = 15 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineMoneyCard))
    engineRun.phase = "ascending"
    engineRun.pendingSampleValue = 40
    engineRun.altitude = 0
    expedition.settle(engineRun)
    expedition.update(engineRun, 0.001)
    assert(engineRun.money == 40, "money effects on an engine-slot part must NOT count toward the settlement bonus (item 9 scopes this stat to hull gear), got " .. tostring(engineRun.money))
end

return M
