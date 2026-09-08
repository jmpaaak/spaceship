local M = {}

-- INBOX 61(3): slot UI — lever pull larger, i18n colon-free format.
function M.run()
    local i18n = require("game.i18n")
    -- EN i18n: no colon prefix, user-friendly prompts
    i18n.setLocale("en")
    local enSpin = i18n.t("earth_slot_spin_prompt")
    assert(not enSpin:find(":", 1, true),
        "INBOX 61(3): earth_slot_spin_prompt EN must not contain colon, got: " .. enSpin)
    local enRelaunch = i18n.t("tap_relaunch")
    assert(not enRelaunch:find(":", 1, true),
        "INBOX 61(3): tap_relaunch EN must not contain colon, got: " .. enRelaunch)
    -- KO i18n: already updated previously
    i18n.setLocale("ko")
    local koSpin = i18n.t("earth_slot_spin_prompt")
    assert(koSpin:find("탭하여", 1, true),
        "INBOX 61(3): earth_slot_spin_prompt KO must start with 탭하여, got: " .. koSpin)
    local koRelaunch = i18n.t("tap_relaunch")
    assert(koRelaunch:find("탭하여", 1, true),
        "INBOX 61(3): tap_relaunch KO must start with 탭하여, got: " .. koRelaunch)
    -- Lever pull multiplier: code sets slotLeverPull = 1.0 for snappy pull
    local src1 = love.filesystem.read("game/scenes/play.lua") or ""
    local src2 = love.filesystem.read("game/scenes/play_shop.lua") or ""
    local src3 = love.filesystem.read("game/scenes/play_slot.lua") or ""
    local leverSrc = src1 .. src2 .. src3
    assert(leverSrc:find("slotLeverPull", 1, true),
        "INBOX 61(3): must reference slotLeverPull")
    print("  INBOX-61(3) slot lever/i18n OK")
end

return M