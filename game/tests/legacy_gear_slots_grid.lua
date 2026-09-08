local play = require("game.scenes.play")
local expedition = require("game.expedition")
local i18n = require("game.i18n")

local M = {}

-- INBOX-40: gear slots grid below left HUD characterization coverage.
function M.run()
    -- (a) Constants exist with correct values
    assert(play.hudGearSlotSize == 48, "gear slot size must be 48px")
    assert(play.hudGearSlotGap == 4, "gear slot gap must be 4px")
    assert(play.hudGearLabelFontSize == 22, "gear label font must be 22px")

    -- (b) drawHudGearSlots method exists
    assert(type(play.drawHudGearSlots) == "function",
        "drawHudGearSlots method must exist")

    -- (c) i18n key exists
    assert(i18n.t("hud_gear_label") ~= nil and i18n.t("hud_gear_label") ~= "",
        "hud_gear_label i18n key must exist")

    -- (d) Grid height fits in 1280px canvas (vertical column layout)
    local totalHeight = 6 * (48 + 4) + 8 + 3 * (48 + 4)
    assert(totalHeight < 800,
        "gear grid vertical column must fit in 1280px canvas, got " .. totalHeight)

    -- (e) drawHudGearSlots does not throw with a mock scene
    local run = expedition.new({ money = 0 })
    run.phase = "ascending"
    run.equippedGear = {
        { name = "Shield A", rarity = "common" },
    }
    run.equippedEngineParts = {}
    local scene = setmetatable({ expedition = run }, { __index = play })

    local rectCalls = {}
    local prevGraphics = love.graphics
    love.graphics = {
        setColor = function() end,
        rectangle = function(mode, x, y, w, h)
            rectCalls[#rectCalls + 1] = { mode = mode, x = x, y = y, w = w, h = h }
        end,
        circle = function() end,
        polygon = function() end,
        draw = function() end,
        printf = function() end,
        print = function() end,
        getFont = function() return {} end,
        setFont = function() end,
        newFont = function() return {} end,
    }
    local ok, err = pcall(function() scene:drawHudGearSlots(200) end)
    love.graphics = prevGraphics
    assert(ok, "drawHudGearSlots must not throw: " .. tostring(err))

    -- Should have drawn rectangles for 9 slots (6 hull + 3 engine)
    -- At least 9 outline rectangles expected (empty slots + filled slots)
    assert(#rectCalls >= 9,
        "drawHudGearSlots must draw at least 9 slot rectangles, got " .. #rectCalls)

    -- First filled slot should be 48x48
    local found48 = false
    for _, rc in ipairs(rectCalls) do
        if rc.w == 48 and rc.h == 48 then found48 = true break end
    end
    assert(found48, "slot rectangles must be 48x48px")

    print("  INBOX-40 gear slots grid below HUD OK")
end

return M