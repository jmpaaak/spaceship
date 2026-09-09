local M = {}

M.returnControls = { top = 244, bottom = 288, leftMaxX = 55, rightMinX = 125 }
M.ascendControls = { top = 244, bottom = 288, leftMaxX = 81, rightMinX = 99 }
M.pauseButton = { x = 616, y = 8, w = 44, h = 44 }
M.ascendReturnButton = { top = 1186, bottom = 1234, left = 210, right = 510 }

M.settlementFontSize = 22
M.settlementRowStep = 44
M.settlementSummaryRowStep = 40
M.settlementPanelTop = 200
M.settlementPanelHeight = 1080
M.settlementTitleY = 210
M.settlementSummaryBgTop = 240
M.settlementSummaryBgHeight = 170
M.settlementTotalY = 248
M.settlementSamplesY = 288
M.settlementPeakAltY = 328
M.settlementNewBestY = 368

local settlementTouchRowTop = 400
local settlementTouchRowHeight = 170
local settlementGearRowHeight = 70
local settlementSlotRowHeight = 200
M.settlementTouchRowHeight = settlementTouchRowHeight
M.settlementTouchRows = {
    {
        top = settlementTouchRowTop,
        bottom = settlementTouchRowTop + settlementTouchRowHeight,
        columns = {
            { key = "hull", left = 0, right = 360 },
            { key = "steering", left = 360, right = 720 },
        },
    },
    {
        top = settlementTouchRowTop + settlementTouchRowHeight,
        bottom = settlementTouchRowTop + settlementTouchRowHeight * 2,
        columns = {
            { key = "yield", left = 0, right = 360 },
            { key = "ship", left = 360, right = 720 },
        },
    },
    {
        key = "gear",
        top = settlementTouchRowTop + settlementTouchRowHeight * 2,
        bottom = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight,
    },
    {
        key = "slot",
        top = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight,
        bottom = settlementTouchRowTop + settlementTouchRowHeight * 2
            + settlementGearRowHeight + settlementSlotRowHeight,
    },
    {
        key = "relaunch",
        top = settlementTouchRowTop + settlementTouchRowHeight * 2
            + settlementGearRowHeight + settlementSlotRowHeight,
        bottom = settlementTouchRowTop + settlementTouchRowHeight * 3
            + settlementGearRowHeight + settlementSlotRowHeight,
    },
}

M.shopActionColumnX, M.shopActionColumnW = 24, 400
M.shopStatusColumnX, M.shopStatusColumnW = 430, 260
M.shopColumnLeftX, M.shopColumnLeftW = 24, 330
M.shopColumnRightX, M.shopColumnRightW = 370, 320
M.settlementRowBackgroundColors = {
    { 0.08, 0.14, 0.22, 0.35 },
    { 0.05, 0.09, 0.15, 0.2 },
}

function M.settlementShopLayout(rows)
    rows = rows or M.settlementTouchRows
    return {
        slot = { top = rows[4].top, bottom = rows[4].bottom },
        slotResult = { top = rows[4].top, bottom = rows[4].bottom },
        gear = { top = rows[3].top, bottom = rows[3].bottom },
        scout = { top = rows[2].top, bottom = rows[2].bottom },
        relaunch = { top = rows[5].top, bottom = rows[5].bottom },
    }
end

function M.pauseMenuRects(viewportWidth, viewportHeight)
    local cx = (viewportWidth or 720) / 2
    local btnW, btnH, gap = 300, 56, 20
    local baseY = (viewportHeight or 1280) / 2 + 10
    return {
        restart = { x = cx - btnW / 2, y = baseY, w = btnW, h = btnH },
        mainMenu = { x = cx - btnW / 2, y = baseY + btnH + gap, w = btnW, h = btnH },
    }
end

function M.settlementRowBackgroundColor(index, colors)
    colors = colors or M.settlementRowBackgroundColors
    return colors[(index - 1) % #colors + 1]
end

function M.install(target, viewport)
    for key, value in pairs(M) do
        if key ~= "install" and type(value) ~= "function" then
            target[key] = value
        end
    end
    target.settlementShopLayout = function()
        return M.settlementShopLayout(target.settlementTouchRows)
    end
    target.pauseMenuRects = function()
        return M.pauseMenuRects(viewport.width, viewport.height)
    end
    target.settlementRowBackgroundColor = function(index)
        return M.settlementRowBackgroundColor(index, target.settlementRowBackgroundColors)
    end
    return target
end

return M