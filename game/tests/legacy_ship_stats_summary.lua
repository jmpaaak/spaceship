local play = require("game.scenes.play")
local expedition = require("game.expedition")

local M = {}

-- INBOX-44: ship stats summary below minimap right side during ascending.
function M.run()
    local run = expedition.new()
    run.phase = "ascending"
    run.steeringUpgradeLevel = 2
    run.durabilityUpgradeLevel = 1
    run.sampleYieldUpgradeLevel = 3
    run.selectedShipId = "scout"
    local scene = setmetatable({
        expedition = run,
        ship = { x = 0, y = -500 },
        time = 1,
    }, { __index = play })
    -- Stub love.graphics for headless
    local printfCalls = {}
    local previousGraphics = love.graphics
    love.graphics = {
        printf = function(text, x, y, w, align)
            table.insert(printfCalls, { text = text, x = x, y = y, w = w, align = align })
        end,
        print = function() end,
        setColor = function() end,
        getFont = function() return { getWidth = function() return 0 end } end,
        setFont = function() end,
        newFont = function() return { getWidth = function() return 0 end } end,
        circle = function() end,
        rectangle = function() end,
        polygon = function() end,
        draw = function() end,
        stencil = function(fn) if fn then fn() end end,
        setStencilTest = function() end,
    }
    local ok, err = pcall(function() scene:drawShipStatsSummary() end)
    love.graphics = previousGraphics
    assert(ok, "drawShipStatsSummary must not throw: " .. tostring(err))
    -- Must produce 4 right-aligned printf calls (ship, speed, hull, harvest)
    local rightAligned = 0
    local sawShip, sawSpeed, sawHull, sawHarvest = false, false, false, false
    for _, c in ipairs(printfCalls) do
        if c.align == "right" then
            rightAligned = rightAligned + 1
            if c.text:find("SCOUT") or c.text:find("기본선") or c.text:find("정찰선") then sawShip = true end
            if c.text == "SPEED 122" or c.text == "속도 122" then sawSpeed = true end
            if c.text:find("HULL %d+/%d+") then sawHull = true end
            if c.text:find("HARVEST x%d+%.%d+") then sawHarvest = true end
        end
    end
    assert(rightAligned >= 3, "ship stats must have >= 3 right-aligned lines, got " .. rightAligned)
    assert(sawShip, "ship stats must include ship name")
    assert(sawSpeed, "ship stats must include SPEED")
    assert(sawHarvest, "ship stats must include harvest multiplier")

    -- Verify it does NOT draw during settlement
    run.phase = "settlement"
    printfCalls = {}
    love.graphics = {
        printf = function(text, x, y, w, align)
            table.insert(printfCalls, { text = text, x = x, y = y, w = w, align = align })
        end,
        print = function() end,
        setColor = function() end,
        getFont = function() return { getWidth = function() return 0 end } end,
        setFont = function() end,
        newFont = function() return { getWidth = function() return 0 end } end,
    }
    pcall(function() scene:drawShipStatsSummary() end)
    love.graphics = previousGraphics
    assert(#printfCalls == 0, "ship stats must not draw during settlement")

    -- Verify positioning: text x should be near right side (viewport.width - minimap.size - 3)
    run.phase = "ascending"
    printfCalls = {}
    love.graphics = {
        printf = function(text, x, y, w, align)
            table.insert(printfCalls, { text = text, x = x, y = y, w = w, align = align })
        end,
        print = function() end,
        setColor = function() end,
        getFont = function() return { getWidth = function() return 0 end } end,
        setFont = function() end,
        newFont = function() return { getWidth = function() return 0 end } end,
    }
    pcall(function() scene:drawShipStatsSummary() end)
    love.graphics = previousGraphics
    local minimap = require("game.minimap")
    local viewport = require("game.viewport")
    local expectedX = viewport.width - 3 - minimap.size
    for _, c in ipairs(printfCalls) do
        if c.align == "right" then
            assert(c.x == expectedX,
                "ship stats x must be " .. expectedX .. ", got " .. c.x)
            break
        end
    end

    print("  INBOX-44 ship stats summary below minimap OK")
end

return M