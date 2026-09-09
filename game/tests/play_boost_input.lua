local playBoost = require("game.scenes.play_boost")

local M = {}

local function boostPart()
    return {
        id = "boost-input-fixture",
        effects = { { type = "boostCharge", value = 1 } },
    }
end

local function sceneWithCharges(count)
    local parts = {}
    for _ = 1, count do parts[#parts + 1] = boostPart() end
    return {
        expedition = {
            phase = "ascending",
            equippedEngineParts = parts,
            boostsUsed = 0,
            boostsMinted = count,
            boostRegenAcc = 0,
        },
        boostBtnRect = { x = 580, y = 1100, w = 120, h = 72 },
        touches = {},
        hitBoostButton = playBoost.hitBoostButton,
    }
end

function M.run()
    print("  [INBOX 74] BOOST input consumption tests...")

    assert(type(playBoost.touchpressed) == "function",
        "INBOX 74: play_boost must own touchpressed consumption")

    local charged = sceneWithCharges(1)
    assert(playBoost.touchpressed(charged, "finger", 620, 1120) == true,
        "INBOX 74: a BOOST button press must be consumed")
    assert(charged.expedition.boostsUsed == 1 and charged.boostActive,
        "INBOX 74: a charged button press must spend and activate BOOST exactly once")
    assert(charged.touches.finger == nil,
        "INBOX 74: a BOOST press must not become movement input")

    local empty = sceneWithCharges(0)
    assert(playBoost.touchpressed(empty, "finger", 620, 1120) == true,
        "INBOX 74: an empty BOOST button must still consume its press")
    assert(empty.expedition.boostsUsed == 0 and not empty.boostActive,
        "INBOX 74: an empty BOOST button must not activate or spend")
    assert(playBoost.touchpressed(empty, "outside", 100, 900) == false,
        "INBOX 74: a press outside BOOST must remain available to movement")

    local calls = 0
    local delegated = sceneWithCharges(0)
    delegated.hitBoostButton = function(self, x, y)
        calls = calls + 1
        return x == 620 and y == 1120
    end
    assert(playBoost.touchpressed(delegated, "mouse", 620, 1120) == true and calls == 1,
        "INBOX 74: mouse-emulated presses must use the same BOOST path")

    print("  INBOX 74 BOOST input consumption OK")
end

return M
