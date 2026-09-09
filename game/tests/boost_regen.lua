local expedition = require("game.expedition")
local gear = require("game.gear")
local playBoost = require("game.scenes.play_boost")
local i18n = require("game.i18n")

local M = {}

local function boostPart(value)
    return {
        id = "boost-regen-fixture",
        effects = { { type = "boostCharge", value = value or 1 } },
    }
end

function M.run()
    print("  [INBOX 66] boost regen / cap / 1.0s duration tests...")

    -- (a) boostCharge sum is the cap. A fresh run with Booster+ starts empty
    -- (0 remaining), not prefilled. Without Booster+, remaining stays 0.
    local bare = expedition.new()
    bare.phase = "ascending"
    assert(expedition.boostChargeCount(bare) == 0,
        "INBOX 66: unequipped run must have boostCharge cap 0")
    assert(expedition.boostsRemaining(bare) == 0,
        "INBOX 66: unequipped run must start with 0 remaining boosts")
    expedition.update(bare, 5)
    assert(expedition.boostsRemaining(bare) == 0,
        "INBOX 66: no Booster+ means regen stays 0 even after 5s")

    local run = expedition.new()
    run.phase = "ascending"
    local enginePool = gear.loadEngineParts()
    local boostCard = gear.findById(enginePool, "engine_emergency_boost_pod")
    assert(boostCard, "fixture engine card 'engine_emergency_boost_pod' must exist")
    assert(expedition.equipGear(run, "engine", boostCard))
    local cap = expedition.boostChargeCount(run)
    assert(cap == 2, "INBOX 66: emergency boost pod still grants cap 2")
    assert(expedition.boostsRemaining(run) == 0,
        "INBOX 66: boostCharge is a cap, not a starting fill — remaining starts at 0")

    -- (b) ascending: 1 charge every 5s, never above cap.
    expedition.update(run, 4.9)
    assert(expedition.boostsRemaining(run) == 0,
        "INBOX 66: 4.9s of ascent must not yet mint a charge")
    expedition.update(run, 0.1)
    assert(expedition.boostsRemaining(run) == 1,
        "INBOX 66: 5s of ascent must mint exactly 1 boost")
    expedition.update(run, 5)
    assert(expedition.boostsRemaining(run) == 2,
        "INBOX 66: 10s of ascent must mint a second charge up to the cap")
    expedition.update(run, 10)
    assert(expedition.boostsRemaining(run) == 2,
        "INBOX 66: regen must not exceed the boostCharge cap")

    -- Spend one, then regen back to cap (used counter goes down).
    assert(expedition.spendBoost(run) == true)
    assert(expedition.boostsRemaining(run) == 1)
    expedition.update(run, 5)
    assert(expedition.boostsRemaining(run) == 2,
        "INBOX 66: after spending, 5s of ascent must refill 1 charge up to the cap")
    assert(expedition.spendBoost(run) == true)
    assert(expedition.spendBoost(run) == true)
    assert(expedition.boostsRemaining(run) == 0)
    local refused, err = expedition.spendBoost(run)
    assert(refused == false and type(err) == "string",
        "INBOX 66: spendBoost still refuses at 0 remaining")

    -- Regen only during ascending.
    run.phase = "settlement"
    expedition.update(run, 5)
    assert(expedition.boostsRemaining(run) == 0,
        "INBOX 66: settlement must not mint boost charges")
    run.phase = "ascending"
    expedition.update(run, 5)
    assert(expedition.boostsRemaining(run) == 1,
        "INBOX 66: returning to ascending resumes regen")

    -- Launch resets remaining to 0 (empty tank, cap unchanged).
    run.phase = "settlement"
    assert(expedition.launch(run))
    assert(run.phase == "ascending")
    assert(expedition.boostChargeCount(run) == 2)
    assert(expedition.boostsRemaining(run) == 0,
        "INBOX 66: launch must start remaining at 0 (cap is not a starting fill)")

    -- (c) active duration is 1.0s; help copy matches.
    local realRun = expedition.new()
    realRun.phase = "ascending"
    realRun.equippedEngineParts = { boostPart(1) }
    local scene = {
        expedition = realRun,
        boostBtnRect = { x = 580, y = 1100, w = 120, h = 72 },
    }
    -- Remaining starts at 0 with the new contract; seed one charge via regen.
    expedition.update(scene.expedition, 5)
    assert(expedition.boostsRemaining(scene.expedition) == 1)
    assert(playBoost.hitBoostButton(scene, 620, 1120) == true)
    assert(scene.boostActive and scene.boostActive.timer == 1.0,
        "INBOX 66: boostActive.timer must be 1.0 (was 0.8)")

    local boostSrc = love.filesystem.read("game/scenes/play_boost.lua") or ""
    assert(not boostSrc:find("timer = 0.8", 1, true),
        "INBOX 66: play_boost.lua must not still hardcode 0.8s duration")
    assert(boostSrc:find("timer = 1.0", 1, true) or boostSrc:find("timer = 1", 1, true),
        "INBOX 66: play_boost.lua must set boostActive.timer to 1.0")

    i18n.setLocale("en")
    assert(i18n.t("help_boost"):find("1.0s", 1, true) or i18n.t("help_boost"):find("1s", 1, true),
        "INBOX 66: EN help_boost must say 1s duration")
    i18n.setLocale("ko")
    assert(i18n.t("help_boost"):find("1.0초", 1, true) or i18n.t("help_boost"):find("1초", 1, true),
        "INBOX 66: KO help_boost must say 1초 duration")
    i18n.setLocale("en")

    print("  INBOX 66 boost regen / cap / 1.0s duration OK")
end

return M
