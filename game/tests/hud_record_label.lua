local M = {}

function M.run()
    local i18n = require("game.i18n")

    i18n.setLocale("en")
    local en_zero = i18n.t("hud_personal_best", 0)
    assert(en_zero == "RECORD 0", "INBOX (56): EN zero must not be zero-padded, got " .. tostring(en_zero))
    
    local en_high = i18n.t("hud_personal_best", 3227)
    assert(en_high == "RECORD 3227", "INBOX (56): EN must be RECORD 3227, got " .. tostring(en_high))

    i18n.setLocale("ko")
    local ko_zero = i18n.t("hud_personal_best", 0)
    assert(ko_zero == "기록 0", "INBOX (56): KO zero must not be zero-padded, got " .. tostring(ko_zero))

    local ko_high = i18n.t("hud_personal_best", 3227)
    assert(ko_high == "기록 3227", "INBOX (56): KO must be 기록 3227, got " .. tostring(ko_high))

    print("  INBOX-56 hud record label no zero-padding OK")
end

return M
