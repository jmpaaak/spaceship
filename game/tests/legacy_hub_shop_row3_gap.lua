local PlayScene = require("game.scenes.play")

local M = {}

-- INBOX 61(18): hub-shop row-3 (gear text) gap characterization.
function M.run()
    local rows = PlayScene.settlementTouchRows
    local row3H = rows[3].bottom - rows[3].top
    assert(row3H < 100,
        "INBOX 61(18): row3 (gear) height must be < 100px to reduce gap, got " .. row3H)

    -- Row 4 (slot) must start right after row 3.
    assert(rows[4].top == rows[3].bottom,
        "INBOX 61(18): row4.top (" .. rows[4].top .. ") must equal row3.bottom (" .. rows[3].bottom .. ")")

    -- Rows must remain contiguous and within the panel.
    for i = 2, #rows do
        assert(rows[i].top == rows[i - 1].bottom,
            "INBOX 61(18): row " .. i .. " top must equal row " .. (i - 1) .. " bottom")
    end
    assert(rows[#rows].bottom <= PlayScene.settlementPanelTop + PlayScene.settlementPanelHeight,
        "INBOX 61(18): last row bottom must fit within panel")
    print("  INBOX-61(18) hub shop row3 gap OK")
end

return M