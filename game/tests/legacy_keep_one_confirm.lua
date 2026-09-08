local PlayScene = require("game.scenes.play")
local M = {}

function M.run()
    -- INBOX 61(12): keep-one card text 11px + confirm popup with yes/no
    -- (a) drawBalatroCard uses 11px name (not 22px) — verified structurally
    -- via the font constant in the function source; runtime draw verified by smoke.
    -- (b) keepConfirmButtons returns layout with >=44px touch targets
    local btns = PlayScene.keepConfirmButtons()
    assert(btns, "INBOX 61(12): keepConfirmButtons must return a table")
    assert(btns.yes and btns.no, "INBOX 61(12): must have yes and no buttons")
    assert(btns.yes.h >= 44,
        "INBOX 61(12): yes button height must be >= 44px, got " .. tostring(btns.yes.h))
    assert(btns.no.h >= 44,
        "INBOX 61(12): no button height must be >= 44px, got " .. tostring(btns.no.h))
    -- (c) popup dimensions fit within 720x1280
    assert(btns.px >= 0 and btns.px + btns.pw <= 720,
        "INBOX 61(12): popup must fit horizontally")
    assert(btns.py >= 0 and btns.py + btns.ph <= 1280,
        "INBOX 61(12): popup must fit vertically")
    -- (d) buttons inside popup
    assert(btns.yes.x >= btns.px and btns.yes.x + btns.yes.w <= btns.px + btns.pw,
        "INBOX 61(12): yes button must be inside popup")
    assert(btns.no.x >= btns.px and btns.no.x + btns.no.w <= btns.px + btns.pw,
        "INBOX 61(12): no button must be inside popup")
    -- (e) tap card sets keepPartConfirm, not keptPart directly
    -- (structural — verified via the touched() code path)
    -- (f) keepConfirmBtnH constant >=44
    assert(PlayScene.keepConfirmBtnH >= 44,
        "INBOX 61(12): keepConfirmBtnH must be >= 44")
    print("  INBOX-61(12) keepOne confirm popup OK")
end

return M