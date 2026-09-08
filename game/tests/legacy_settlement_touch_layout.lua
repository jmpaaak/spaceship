local viewport = require("game.viewport")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        assert(row.bottom - row.top >= 34,
            "settlement touch row " .. (row.key or "columns") .. " is under the 34px minimum")
    end

    -- Item 1 fix: settlement row step must exceed font size to prevent overlap
    assert(PlayScene.settlementRowStep >= PlayScene.settlementFontSize + 4,
        "settlementRowStep (" .. PlayScene.settlementRowStep .. ") too small vs font ("
            .. PlayScene.settlementFontSize .. ") — text will overlap")
    -- Summary lines must not overlap each other
    assert(PlayScene.settlementSamplesY - PlayScene.settlementTotalY >= PlayScene.settlementFontSize,
        "settlement summary total/samples lines overlap")
    assert(PlayScene.settlementPeakAltY - PlayScene.settlementSamplesY >= PlayScene.settlementFontSize,
        "settlement summary samples/peakAlt lines overlap")
    assert(PlayScene.settlementNewBestY - PlayScene.settlementPeakAltY >= PlayScene.settlementFontSize,
        "settlement summary peakAlt/newBest lines overlap")
    -- Panel must contain all 4 touch rows
    local lastRow = PlayScene.settlementTouchRows[#PlayScene.settlementTouchRows]
    assert(lastRow.bottom <= PlayScene.settlementPanelTop + PlayScene.settlementPanelHeight,
        "settlement touch rows extend below panel bottom")

    -- EARTH SHOP hull/steering/yield/ship rows print an action string
    -- (left column) and a status string (right column, "LEFT $N"/"SHORT $N"/
    -- "OWNED") side by side. A real LÖVE font probe (GAME_FONTPROBE=1 love .)
    -- against the small scene-cached font (love.graphics.newFont(8)) measured
    -- the widest action string ("T/G STEER LV.9>10 $65") at 100px and the
    -- widest status string ("SHORT $125") at 52px. Verify the drawn columns
    -- clear both measured worst cases so long status text cannot wrap onto a
    -- second line and overlap the row spaced only 9px below.
    assert(PlayScene.shopActionColumnW >= 100,
        "EARTH SHOP action column is under the measured worst-case action text width")
    assert(PlayScene.shopStatusColumnW >= 52,
        "EARTH SHOP status column is under the measured worst-case status text width")
    assert(PlayScene.shopStatusColumnX >= PlayScene.shopActionColumnX + PlayScene.shopActionColumnW,
        "EARTH SHOP status column overlaps the action column")

    -- EARTH SHOP touch rows are shaded with a faint alternating background
    -- (drawn behind, never on top of, the already-verified text) purely as a
    -- visual affordance for which rows respond to touch. Verify every row
    -- resolves a valid RGBA color and adjacent rows alternate.
    for index = 1, #PlayScene.settlementTouchRows do
        local color = PlayScene.settlementRowBackgroundColor(index)
        assert(type(color) == "table" and #color == 4,
            "settlement row background color must be an RGBA table")
        for _, channel in ipairs(color) do
            assert(channel >= 0 and channel <= 1, "settlement row background channel out of range")
        end
    end
    assert(PlayScene.settlementRowBackgroundColor(1) ~= PlayScene.settlementRowBackgroundColor(2),
        "adjacent settlement rows must use different background colors")
    assert(PlayScene.settlementRowBackgroundColor(1) == PlayScene.settlementRowBackgroundColor(3),
        "background colors should alternate in a fixed two-color cycle")

    -- The smallest supported window (integer scale 1, e.g. 180x320) at a 1x
    -- device pixel ratio is the worst case for touch-target accessibility.
    -- iOS/Android guidelines require ~44pt minimum; verify every settlement
    -- row actually clears that bar via the real canvas-to-points conversion,
    -- not just the previously-checked 34px minimum.
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        local heightPoints = viewport.canvasPixelsToPoints(row.bottom - row.top, 720, 1280, 1, false)
        assert(heightPoints >= 44,
            "settlement touch row " .. (row.key or "columns")
                .. " is under the 44pt accessibility minimum at scale 1 (" .. heightPoints .. "pt)")
        if row.columns then
            for _, column in ipairs(row.columns) do
                local widthPoints = viewport.canvasPixelsToPoints(column.right - column.left, 720, 1280, 1, false)
                assert(widthPoints >= 44,
                    "settlement touch column " .. column.key
                        .. " is under the 44pt accessibility minimum width at scale 1 (" .. widthPoints .. "pt)")
            end
        end
    end
    local rowTouchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    rowTouchScene.expedition.phase = "settlement"
    rowTouchScene.expedition.money = rowTouchScene.expedition.durabilityUpgradeCost
        + rowTouchScene.expedition.scoutShipCost
        + rowTouchScene.expedition.sampleYieldUpgradeCost + rowTouchScene.expedition.steeringUpgradeCost
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        if row.columns then
            for _, column in ipairs(row.columns) do
                rowTouchScene:touchpressed(column.key,
                    column.left + math.floor((column.right - column.left) / 2),
                    row.top + math.floor((row.bottom - row.top) / 2))
            end
        else
            rowTouchScene:touchpressed(row.key, 90, row.top + math.floor((row.bottom - row.top) / 2))
        end
    end
    assert(rowTouchScene.expedition.durabilityUpgradeLevel == 1)
    assert(rowTouchScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(rowTouchScene.expedition.steeringUpgradeLevel == 1)
    assert(rowTouchScene.expedition.ownedShips.scout and rowTouchScene.expedition.selectedShipId == "scout")
    assert(rowTouchScene.expedition.phase == "ascending")
end

return M