local i18n = require("game.i18n")

local M = {}

-- INBOX 61(20): earth_gear_offer must not contain [B] keyboard prefix.
function M.run()
    i18n.setLocale("en")
    local en = i18n.t("earth_gear_offer", "TestGear", 100)
    assert(not en:find("%[B%]"), "INBOX 61(20): EN earth_gear_offer still contains [B], got: " .. en)
    assert(en:find("GEAR OFFER:"), "INBOX 61(20): EN must have 'GEAR OFFER:', got: " .. en)
    i18n.setLocale("ko")
    local ko = i18n.t("earth_gear_offer", "테스트장비", 100)
    assert(not ko:find("%[B%]"), "INBOX 61(20): KO earth_gear_offer still contains [B], got: " .. ko)
    assert(ko:find("장비 제안:"), "INBOX 61(20): KO must have '장비 제안:', got: " .. ko)
    i18n.setLocale("en")  -- restore
    print("  INBOX-61(20) gear offer [B] prefix removed OK")
end

return M