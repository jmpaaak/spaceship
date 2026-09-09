local M = {}

-- INBOX-61(30): Jimmy's author line on title screen
function M.run()
    local i18n = require("game.i18n")
    i18n.setLocale("en")
    assert(i18n.t("title_author") == "Jimmy's",
        "INBOX-61(30): EN title_author must be 'Jimmy's'")
    i18n.setLocale("ko")
    assert(i18n.t("title_author") == "Jimmy's",
        "INBOX-61(30): KO title_author must be 'Jimmy's'")
    i18n.setLocale("en")
    print("  INBOX-61(30) Jimmy title author OK")
end

return M