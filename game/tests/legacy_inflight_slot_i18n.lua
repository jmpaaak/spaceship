local i18n = require("game.i18n")

local M = {}

function M.run()
    -- Item 11: the abolished in-flight slot machine must leave neither locale
    -- keys nor slot-opportunity wording in the automatic-return message.
    local deadKeys = {
        "slot_spin_prompt", "slot_result_repair", "slot_result_sample",
        "slot_result_plain", "slot_spinning_label", "no_slot_chances_label",
        "no_slots_compact", "spin_compact_label", "spinning_compact",
        "hold_left", "hold_right", "spinning_label",
        "win_repair_line", "win_sample_line", "win_pending_line",
        "button_left", "button_right", "slot_odds_line",
    }
    local originalLocale = i18n.getLocale()

    for _, locale in ipairs({ "en", "ko" }) do
        i18n.setLocale(locale)
        for _, key in ipairs(deadKeys) do
            -- i18n.t asserts on missing keys; use pcall to detect them.
            local ok = pcall(i18n.t, key)
            assert(not ok,
                "item 11: dead in-flight slot key '" .. key ..
                "' must be removed from " .. locale .. " i18n (still resolves to a value)")
        end

        local returningMessage = i18n.t("returning_message")
        if locale == "en" then
            assert(not returningMessage:upper():find("SLOT", 1, true),
                "item 11: English returning_message must not mention slots")
        else
            assert(not returningMessage:find("슬롯", 1, true),
                "item 11: Korean returning_message must not mention slots")
        end
    end

    i18n.setLocale(originalLocale)
end

return M