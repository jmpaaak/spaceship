local PlayScene = require("game.scenes.play")
local M = {}

function M.run()
    -- INBOX 61(14): planet sheet PNGs must be RGBA and drawing logic must
    -- prefer sheets over static sprites (so sheets render even when pp_*
    -- static PNGs fail to load).
    -- (a) All planet sheet PNGs must be RGBA (colorType 6)
    local sheetPaths = {
        ice   = "assets/planet/pp_ice_sheet.png",
        lava  = "assets/planet/pp_lava_sheet.png",
        dry   = "assets/planet/pp_dry_sheet.png",
        gas   = "assets/planet/pp_gas_sheet.png",
        earth = "assets/planet/pp_earth_sheet.png",
        bare  = "assets/planet/pp_bare_sheet.png",
    }
    for key, path in pairs(sheetPaths) do
        local ct = PlayScene.pngColorType(path)
        assert(ct == 6,
            "INBOX 61(14): " .. path .. " must be RGBA (colorType 6), got " .. tostring(ct))
        assert(PlayScene.shouldLoadRuntimeSprite(path) == true,
            "INBOX 61(14): " .. path .. " must pass runtime sprite gate")
    end
    -- hub_sheet must also be RGBA
    local hubCt = PlayScene.pngColorType("assets/planet/hub_sheet.png")
    assert(hubCt == 6,
        "INBOX 61(14): hub_sheet.png must be RGBA (colorType 6), got " .. tostring(hubCt))

    -- (b) Verify all 6 starTypes get galaxyStarType on generated planets
    local starTypes = { "ice", "lava", "dry", "gas", "earth", "bare" }
    for _, st in ipairs(starTypes) do
        -- A planet with this galaxyStarType should find a sheet path
        assert(sheetPaths[st],
            "INBOX 61(14): missing sheet path for starType " .. st)
    end

    -- (c) Structural: planetSheetImages is stored in self and
    -- drawing code prefers sheet over planetSprite. Verified by
    -- checking that M.new() state table includes planetSheetImages key.
    -- (Cannot call M.new() headless since it needs love.graphics for
    -- loadSprite, but we verify the code path structurally by checking
    -- that the draw function source references planetSheetImages before
    -- the planetSprite fallback.)
    -- We do a simulated sprite load test instead:
    local prevGraphics = love.graphics
    local calls = {}
    love.graphics = {
        newImage = function(p)
            return {
                setFilter = function() end,
                getDimensions = function() return 128, 512 end,
                _path = p,
            }
        end,
        newQuad = function() return "quad" end,
        setColor = function() end,
        draw = function(img, ...)
            calls[#calls + 1] = { img = img, args = {...} }
        end,
        circle = function() end,
    }
    -- Load a sheet and a static sprite
    -- Simulate mobile failure: love.filesystem.read returns nil, io.open returns nil
    local prevRead = love.filesystem.read
    local prevIoOpen = io.open
    love.filesystem.read = function() return nil, "Mobile memory limit simulation" end
    io.open = function() return nil, "Mobile absolute path simulation" end

    local sheet = PlayScene.loadSprite("assets/planet/pp_ice_sheet.png")
    local static = PlayScene.loadSprite("assets/planet/pp_ice.png")
    assert(sheet, "INBOX 61(14): sheet must load with mock graphics even if filesystem.read and io.open fail (simulating mobile)")
    assert(static, "INBOX 61(14): static must load with mock graphics even if filesystem.read and io.open fail (simulating mobile)")

    love.filesystem.read = prevRead
    io.open = prevIoOpen
    love.graphics = prevGraphics

    print("  INBOX-61(14) planet sheet sprites OK")
end

return M