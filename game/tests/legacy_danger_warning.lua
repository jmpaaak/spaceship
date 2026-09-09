local i18n = require("game.i18n")
local world = require("game.world")

local M = {}

-- INBOX 61(22): danger_warning i18n + starDangerTextMultiplier constant
function M.run()
    -- danger_warning key must exist in both locales
    for _, loc in ipairs({"en", "ko"}) do
        i18n.setLocale(loc)
        local val = i18n.t("danger_warning")
        assert(val and val ~= "danger_warning",
            "INBOX 61(22): i18n key 'danger_warning' missing for locale " .. loc)
    end
    i18n.setLocale("en")
    assert(i18n.t("danger_warning") == "DANGER",
        "INBOX 61(22): EN danger_warning must be 'DANGER'")

    -- starDangerTextMultiplier must be >1 (outer ring beyond well)
    assert(world.starDangerTextMultiplier and world.starDangerTextMultiplier > 1,
        "INBOX 61(22): starDangerTextMultiplier must be > 1")
    -- dangerOuter must be larger than wellRadius
    local dangerOuter = world.starWellRadius * world.starDangerTextMultiplier
    assert(dangerOuter > world.starWellRadius,
        "INBOX 61(22): danger text outer radius must exceed well radius")

    print("  INBOX-61(22) danger warning text + constants OK")
end

return M
