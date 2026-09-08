local play_star = require("game.scenes.play_star")

local M = {}

function M.run()
    print("  [INBOX-58] star_sprite tests...")
    
    local calls = {}
    local dummyPlayState = {
        starTypeImages = {
            sun = { getDimensions = function() return 256, 256 end },
            earth = { getDimensions = function() return 256, 256 end }
        },
        starSheetImages = {
            sun = { getDimensions = function() return 256, 1024 end },
            earth = { getDimensions = function() return 256, 1024 end }
        }
    }
    
    local oldGraphics = love.graphics
    love.graphics = love.graphics or {}
    local origDraw = love.graphics.draw
    local origCircle = love.graphics.circle
    local origNewQuad = love.graphics.newQuad
    local origSetColor = love.graphics.setColor
    
    love.graphics.draw = function(img, ...)
        table.insert(calls, {type = "draw", img = img})
    end
    love.graphics.circle = function(mode, x, y, r)
        table.insert(calls, {type = "circle", mode = mode})
    end
    love.graphics.newQuad = function(...)
        return "quad"
    end
    love.graphics.setColor = function(...)
    end
    
    calls = {}
    play_star.drawCentralStar(dummyPlayState, 0, 0, 80, {starType = "earth"}, 0)
    assert(#calls == 1, "Should draw something")
    assert(calls[1].type == "draw", "Should use draw (sheet/image)")
    assert(calls[1].img == dummyPlayState.starSheetImages.earth, "Should use earth sheet")
    
    calls = {}
    local missingEarthSheetState = {
        starTypeImages = { sun = { getDimensions = function() return 256, 256 end } },
        starSheetImages = { sun = { getDimensions = function() return 256, 1024 end } }
    }
    play_star.drawCentralStar(missingEarthSheetState, 0, 0, 80, {starType = "earth"}, 0)
    assert(#calls == 1)
    assert(calls[1].type == "draw")
    assert(calls[1].img == missingEarthSheetState.starSheetImages.sun, "Should fallback to sun sheet")

    calls = {}
    local missingAllSheetsState = {
        starTypeImages = { sun = { getDimensions = function() return 256, 256 end } },
        starSheetImages = {}
    }
    play_star.drawCentralStar(missingAllSheetsState, 0, 0, 80, {starType = "earth"}, 0)
    assert(#calls == 1)
    assert(calls[1].type == "draw")
    assert(calls[1].img == missingAllSheetsState.starTypeImages.sun, "Should fallback to sun static image")

    calls = {}
    local emptyState = {}
    play_star.drawCentralStar(emptyState, 0, 0, 80, {starType = "earth"}, 0)
    assert(#calls == 1)
    assert(calls[1].type == "circle", "Should fallback to circle")
    
    love.graphics.draw = origDraw
    love.graphics.circle = origCircle
    love.graphics.newQuad = origNewQuad
    love.graphics.setColor = origSetColor
    if oldGraphics == nil then
        love.graphics = nil
    end
    
    print("  INBOX-58 star_sprite OK")
end

return M
