local M = {}

function M.run()
    local i18n = require("game.i18n")
    for _, loc in ipairs({"en", "ko"}) do
        i18n.setLocale(loc)
        assert(type(i18n.t("planet_new_discovery")) == "string" and #i18n.t("planet_new_discovery") > 0,
            "planet_new_discovery i18n key missing for " .. loc)
        assert(type(i18n.t("central_star_label")) == "string" and #i18n.t("central_star_label") > 0,
            "central_star_label i18n key missing for " .. loc)
        assert(type(i18n.t("engine_part_available")) == "string" and #i18n.t("engine_part_available") > 0,
            "engine_part_available i18n key missing for " .. loc)
        assert(type(i18n.t("hull_part_available")) == "string" and #i18n.t("hull_part_available") > 0,
            "hull_part_available i18n key missing for " .. loc)
        assert(type(i18n.t("hub_label")) == "string" and #i18n.t("hub_label") > 0,
            "hub_label i18n key missing for " .. loc)
        assert(type(i18n.t("shop_label")) == "string" and #i18n.t("shop_label") > 0,
            "shop_label i18n key missing for " .. loc)
    end
    i18n.setLocale("en")
end

return M
