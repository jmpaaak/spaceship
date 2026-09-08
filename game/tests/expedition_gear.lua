local expedition = require("game.expedition")
local expeditionGear = require("game.expedition_gear")
local expeditionUpgrade = require("game.expedition_upgrade")

local M = {}

function M.run()
    print("  expedition gear/upgrade extraction tests...")

    local originalEffectiveSpeed = expeditionGear.effectiveSpeed
    local delegatedRun
    expeditionGear.effectiveSpeed = function(api, run)
        assert(api == expedition, "gear wrapper must pass the public expedition API")
        delegatedRun = run
        return 4321
    end
    local speedRun = expedition.new()
    assert(expedition.effectiveSpeed(speedRun) == 4321 and delegatedRun == speedRun,
        "expedition.effectiveSpeed must delegate to expedition_gear")
    expeditionGear.effectiveSpeed = originalEffectiveSpeed

    local originalUpgradeCost = expeditionUpgrade.upgradeCost
    expeditionUpgrade.upgradeCost = function(api, run, baseCost, level)
        assert(api == expedition and baseCost == 17 and level == 4)
        return 987
    end
    assert(expedition.upgradeCost(speedRun, 17, 4) == 987,
        "expedition.upgradeCost must delegate to expedition_upgrade")
    expeditionUpgrade.upgradeCost = originalUpgradeCost

    local run = expedition.new({ durability = 3, baseSpeed = 60 })
    local hull = {
        id = "extraction_hull",
        rarity = "common",
        tags = {},
        effects = {
            { type = "hullDurability", value = 2 },
            { type = "climbSpeed", value = 5 },
        },
    }
    assert(expedition.equipGear(run, "hull", hull))
    assert(run.maxDurability == 5, "extracted gear domain must refresh hull stats")

    run.phase = "settlement"
    run.money = 100
    local expectedCost = expedition.upgradeCost(run, run.durabilityUpgradeCost, 0)
    assert(expedition.buyDurabilityUpgrade(run))
    assert(run.money == 100 - expectedCost and run.maxDurability == 6,
        "extracted upgrade domain must preserve purchase and stat refresh")

    local source = love.filesystem.read("game/expedition.lua") or ""
    assert(source:find('require%("game%.expedition_gear"%)'),
        "expedition must consume expedition_gear")
    assert(source:find('require%("game%.expedition_upgrade"%)'),
        "expedition must consume expedition_upgrade")
    assert(source:find('require%("game%.expedition_run"%)'),
        "expedition must consume expedition_run")

    print("  expedition gear/upgrade extraction OK")
end

return M
