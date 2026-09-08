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
        table.insert(calls, {type = "draw", img = img, args = {...}})
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

    local studioPaths = play_star.studioStarImagePaths()
    assert(studioPaths.earth == "assets/star/studio/star_sun.png",
        "INBOX 78: the home central star must load the approved Asset Studio derivative")

    calls = {}
    local studioSun = { getDimensions = function() return 128, 128 end }
    local studioState = {
        studioStarImages = { earth = studioSun },
        starTypeImages = dummyPlayState.starTypeImages,
        starSheetImages = dummyPlayState.starSheetImages,
    }
    play_star.drawCentralStar(studioState, 25, 40, 80, {starType = "earth"}, 0)
    assert(#calls == 1 and calls[1].img == studioSun,
        "INBOX 78: a decoded studio Sun must take priority over the legacy earth sheet")
    assert(calls[1].args[1] == 25 and calls[1].args[2] == 40
            and calls[1].args[4] == 1.25 and calls[1].args[5] == 1.25
            and calls[1].args[6] == 64 and calls[1].args[7] == 64,
        "INBOX 78: studio Sun drawing must preserve the central-star center and diameter")

    calls = {}
    local unrelatedStudioState = {
        studioStarImages = { earth = studioSun },
        starTypeImages = dummyPlayState.starTypeImages,
        starSheetImages = dummyPlayState.starSheetImages,
    }
    play_star.drawCentralStar(unrelatedStudioState, 0, 0, 80, {starType = "sun"}, 0)
    assert(#calls == 1 and calls[1].img == dummyPlayState.starSheetImages.sun,
        "INBOX 78: the home-star candidate must not replace other central-star types")
    
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
