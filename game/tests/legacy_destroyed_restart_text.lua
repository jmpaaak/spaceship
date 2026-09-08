local PlayScene = require("game.scenes.play")

local M = {}

-- INBOX 61(17): destroyed-screen restart-text positioning characterization.
function M.run()
    -- When no keep choices: text should be vertically centered in panel.
    local emptyY = PlayScene.destroyedRestartTextY(false)
    local panelCenter = PlayScene.destroyedPanelY + math.floor(PlayScene.destroyedPanelH / 2)
    assert(math.abs(emptyY - (panelCenter - 11)) <= 1,
        "INBOX 61(17): empty keepPartChoices restart text must be near panel vertical center"
        .. " (got " .. emptyY .. ", expected ~" .. (panelCenter - 11) .. ")")

    -- When items exist: text should be near panel bottom.
    local itemsY = PlayScene.destroyedRestartTextY(true)
    local bottomExpect = PlayScene.destroyedPanelY + PlayScene.destroyedPanelH - 72
    assert(itemsY == bottomExpect,
        "INBOX 61(17): with keepPartChoices restart text must be near panel bottom"
        .. " (got " .. itemsY .. ", expected " .. bottomExpect .. ")")

    -- Centered Y must be higher (smaller) than bottom Y.
    assert(emptyY < itemsY,
        "INBOX 61(17): empty restart Y (" .. emptyY .. ") must be above items Y (" .. itemsY .. ")")
    print("  INBOX-61(17) destroyed restart text Y OK")
end

return M
