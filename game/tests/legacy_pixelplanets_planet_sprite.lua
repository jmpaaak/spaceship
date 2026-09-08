local PlayScene = require("game.scenes.play")
local world = require("game.world")
local M = {}

function M.run()
    -- INBOX (12): PixelPlanets planet sprites — first 3 starType PNGs exist,
    -- are RGBA color type 6, and each galaxyStarType in world module maps
    -- to one of the 6 expected types.
    local ppTypes = { "ice", "lava", "dry", "gas", "earth", "bare" }
    for _, ptype in ipairs(ppTypes) do
        local path = "assets/planet/pp_" .. ptype .. ".png"
        local colorType = PlayScene.pngColorType(path)
        assert(colorType == 6,
            "pp_" .. ptype .. ".png must be RGBA color type 6, got " .. tostring(colorType))
    end

    -- Verify world.galaxy starType is always one of the 6 expected types
    local validTypes = { ice = true, lava = true, dry = true, gas = true, earth = true, bare = true }
    for gx = -5, 5 do
        for gy = -5, 5 do
            local g = world.galaxy(gx, gy)
            if g then
                assert(validTypes[g.starType],
                    "galaxy starType must be one of 6 known types, got " .. tostring(g.starType))
            end
        end
    end

    -- Verify planets carry galaxyStarType from their galaxy
    local g = world.galaxy(0, 0)
    assert(g and g.starType == "earth",
        "home galaxy must have starType 'earth'")
    local hub = world.hubPlanet(nil)
    assert(hub == nil, "milkyway has no hub planet")
    -- Find a foreign galaxy and check its hub/shop carry starType
    for gx = -20, 20 do
        for gy = -20, 20 do
            local fg = world.galaxy(gx, gy)
            if fg and fg.id ~= "milkyway" then
                local fHub = world.hubPlanet(fg)
                assert(fHub.galaxyStarType == fg.starType,
                    "hub planet must carry parent galaxy starType")
                local fShop = world.shopPlanet(fg)
                assert(fShop.galaxyStarType == fg.starType,
                    "shop planet must carry parent galaxy starType")
                -- Check a regular planet in this galaxy
                local sx, sy = world.sectorAt(fg.x, fg.y)
                local planets = world.planets(sx, sy)
                for _, p in ipairs(planets) do
                    assert(p.galaxyStarType == fg.starType,
                        "regular planet must carry parent galaxy starType")
                end
                break
            end
        end
    end

    -- Verify planetImagePathForPlanet wiring (INBOX 12 draw wiring)
    local resolve = PlayScene.planetImagePathForPlanet

    -- Regular planet with starType → pp_<type>
    assert(resolve({ galaxyStarType = "ice" }) == "assets/planet/studio/pp_ice_nasa_pia00353.png",
        "regular ice planet must resolve to the wired Asset Studio derivative")
    assert(resolve({ galaxyStarType = "lava" }) == "assets/planet/studio/pp_lava_nasa_pia00703.png",
        "regular lava planet must resolve to the wired Asset Studio derivative")
    assert(resolve({ galaxyStarType = "bare" }) == "assets/planet/studio/pp_bare.png",
        "regular bare planet must resolve to the wired Asset Studio derivative")

    -- Approved hub candidates take priority only for their mapped star type.
    assert(resolve({ hub = true, galaxyStarType = "gas" }) == "assets/planet/studio/hub_saturn.png",
        "gas hub planet must resolve to the approved Saturn derivative")

    -- Hub planet without starType → planet_hub.png fallback
    assert(resolve({ hub = true }) == "assets/planet/planet_hub.png",
        "hub planet without starType must fallback to planet_hub.png")

    -- Shop planet with starType → pp_<starType> (starType takes priority over dedicated shop sprite)
    assert(resolve({ isShop = true, galaxyStarType = "dry" }) == "assets/planet/pp_dry.png",
        "shop planet with starType must resolve to pp_<starType>.png")

    -- Shop planet without starType → planet_shop.png fallback
    assert(resolve({ isShop = true }) == "assets/planet/planet_shop.png",
        "shop planet without starType must fallback to planet_shop.png")

    -- Planet without starType → planet_generic.png fallback
    assert(resolve({}) == "assets/planet/planet_generic.png",
        "planet without starType must fallback to planet_generic.png")

    -- ppPlanetImagePaths table is stored in scene
    -- (cannot instantiate scene without love.graphics, verify paths table exists in module)
    assert(type(PlayScene.planetImagePathForPlanet) == "function",
        "PlayScene.planetImagePathForPlanet must be exposed")
end

return M
