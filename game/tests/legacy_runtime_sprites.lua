local M = {}

-- INBOX 2026-09-05 item (1): RGB ComfyUI PNGs must not load; draw falls
-- back to Lua polygons/circles. RGBA keepers (ship/earth/planets/HUD) stay.
local function testRgbBrokenAssetsUnwired()
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.pngColorType) == "function",
        "pngColorType must be exported")
    assert(type(PlayScene.shouldLoadRuntimeSprite) == "function",
        "shouldLoadRuntimeSprite must be exported")
    assert(type(PlayScene.loadSprite) == "function",
        "loadSprite must be exported")

    local rgbPaths = {
        "assets/effects/shop_panel.png",
        "assets/effects/loadout_panel.png",
        "assets/effects/destroyed_panel.png",
        "assets/effects/hud_panel.png",
        "assets/effects/joystick_pad.png",
        "assets/effects/star_point.png",
        "assets/effects/planet_glow.png",
        "assets/effects/minimap_disc.png",
        "assets/effects/sample_sparkle.png",
        "assets/shop_icons/hull.png",
        "assets/shop_icons/steering.png",
        "assets/shop_icons/yield.png",
        "assets/shop_icons/ship.png",
        "assets/slot_symbols/comet.png",
        "assets/slot_symbols/planet.png",
        "assets/slot_symbols/star.png",
        "assets/backgrounds/deep_space_tile.png",
    }
    for _, path in ipairs(rgbPaths) do
        assert(PlayScene.pngColorType(path) == 2,
            path .. " must be PNG color type 2 (RGB), got "
                .. tostring(PlayScene.pngColorType(path)))
        assert(PlayScene.shouldLoadRuntimeSprite(path) == false,
            path .. " RGB sprite must not load at runtime")
    end

    local rgbaKeepers = {
        "assets/ship/ship_default.png",
        "assets/ship/ship_scout.png",
        "assets/earth/earth_generic.png",
        "assets/planet/planet_generic.png",
        "assets/planet/planet_hub.png",
        "assets/planet/planet_shop.png",
        "assets/planet/pp_ice.png",
        "assets/planet/pp_lava.png",
        "assets/planet/pp_dry.png",
        "assets/planet/pp_gas.png",
        "assets/planet/pp_earth.png",
        "assets/planet/pp_bare.png",
        "assets/planet/pp_ice_sheet.png",
        "assets/planet/pp_lava_sheet.png",
        "assets/planet/pp_dry_sheet.png",
        "assets/planet/pp_gas_sheet.png",
        "assets/planet/pp_earth_sheet.png",
        "assets/planet/pp_bare_sheet.png",
        "assets/planet/hub_sheet.png",
        "assets/hud/icon_cash.png",
        "assets/hud/icon_durability.png",
        "assets/effects/hud_speed.png",
        "assets/hud/icon_distance.png",
        "assets/effects/hud_best.png",
        "assets/effects/hud_samples.png",
        "assets/effects/hud_galaxy.png",
        "assets/effects/hud_return.png",
        "assets/effects/hud_earth.png",
        "assets/debris/asteroid.png",
        "assets/debris/can.png",
        "assets/debris/scrap.png",
        "assets/moon/moon_generic.png",
        "assets/comet/comet_generic.png",
        "assets/suit_icons/solar.png",
        "assets/suit_icons/nebula.png",
        "assets/suit_icons/void.png",
        "assets/suit_icons/pulsar.png",
    }
    for _, path in ipairs(rgbaKeepers) do
        assert(PlayScene.pngColorType(path) == 6,
            path .. " must be PNG color type 6 (RGBA), got "
                .. tostring(PlayScene.pngColorType(path)))
        assert(PlayScene.shouldLoadRuntimeSprite(path) == true,
            path .. " RGBA keeper must remain loadable")
    end

    local previousGraphics = love.graphics
    local newImageCalls = 0
    love.graphics = {
        newImage = function(path)
            newImageCalls = newImageCalls + 1
            return {
                setFilter = function() end,
                _path = path,
            }
        end,
    }
    local rgbImg = PlayScene.loadSprite("assets/effects/shop_panel.png")
    local rgbCalls = newImageCalls
    local rgbaImg = PlayScene.loadSprite("assets/ship/ship_default.png")
    love.graphics = previousGraphics
    assert(rgbImg == nil, "loadSprite must return nil for RGB PNG")
    assert(rgbCalls == 0, "loadSprite must not call newImage for RGB PNG")
    assert(rgbaImg ~= nil, "loadSprite must load RGBA keepers when graphics exists")

    local okPanel, resPanel = pcall(PlayScene.drawPanelSprite, nil, 0, 0, 100, 50)
    assert(okPanel and resPanel == false,
        "drawPanelSprite(nil) must return false without throwing")
    local okShop, resShop = pcall(PlayScene.drawShopIconSprite, nil, 10, 10, 8)
    assert(okShop and resShop == false,
        "drawShopIconSprite(nil) must return false without throwing")
    local okStar, resStar = pcall(PlayScene.drawStarPointSprite, nil, 10, 10, 3)
    assert(okStar and resStar == false,
        "drawStarPointSprite(nil) must return false without throwing")
    local okFx, resFx = pcall(PlayScene.drawPlanetEffectSprite, nil, 10, 10, 20, 1, 1, 1, 1)
    assert(okFx and resFx == false,
        "drawPlanetEffectSprite(nil) must return false without throwing")
end

function M.run()
    testRgbBrokenAssetsUnwired()
end

return M
