local expedition = require("game.expedition")
local i18n = require("game.i18n")
local speedDisplay = require("game.speed_display")

local M = {}

function M.run()
    assert(speedDisplay.value(60, 60) == 0,
        "base 60 / effective 60 must display speed 0")
    assert(speedDisplay.value(61, 60) == 1,
        "base 60 / effective 61 must display speed 1")
    assert(speedDisplay.value(80, 60) == 20,
        "base 60 / effective 80 must display the full increase 20")

    local current = speedDisplay.value(60, 60)
    local upgraded = speedDisplay.value(61, 60)
    i18n.setLocale("en")
    assert(i18n.t("steering_action_compact", current, upgraded, 5) == "SPEED 0 -> 1 $5")
    i18n.setLocale("ko")
    assert(i18n.t("steering_action_compact", current, upgraded, 5) == "속도 0 -> 1 $5")
    i18n.setLocale("en")

    local run = expedition.new({ baseSpeed = 60 })
    assert(expedition.effectiveSpeed(run) == 60,
        "display normalization must not change fresh-run movement speed")

    local _, _, _, radius = expedition.rcsVisual(run, 0, 0)
    local expectedRadius = 1.5 + (60 / 999) * 2.5
    assert(math.abs(radius - expectedRadius) < 1e-9,
        "RCS visuals must remain based on actual effective speed 60/999")
end

return M
