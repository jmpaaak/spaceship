local celestialAssets = require("game.celestial_asset_manifest")
local hubAssets = require("game.hub_planet_asset_manifest")

local M = {}

local pixelPlanetTypes = {
    ice = true,
    lava = true,
    dry = true,
    gas = true,
    earth = true,
    bare = true,
}

function M.planetColor(hue)
    if hue < 0.33 then return 0.35, 0.75, 1 end
    if hue < 0.66 then return 0.95, 0.55, 0.3 end
    return 0.65, 0.45, 0.95
end

function M.planetVariation(planet)
    if not planet or not planet.id then return 0, 1.0 end

    local id = tostring(planet.id)
    local hash = 0
    for index = 1, #id do
        hash = (hash * 31 + id:byte(index)) % 65521
    end

    local rotation = (hash % 360) * (math.pi / 180)
    local scale = 0.85 + (hash % 100) / 100 * 0.30
    return rotation, scale
end

function M.planetImagePathForPlanet(planet)
    local studioAsset = celestialAssets.planets[planet.galaxyStarType]
    if studioAsset and not planet.hub and not planet.isShop then
        return studioAsset.runtimePath
    end

    if planet.hub then
        local hubAsset = hubAssets.hubs[planet.galaxyStarType]
        if hubAsset then
            return hubAsset.runtimePath
        end
        if pixelPlanetTypes[planet.galaxyStarType] then
            return "assets/planet/pp_" .. planet.galaxyStarType .. ".png"
        end
        return "assets/planet/planet_hub.png"
    end

    if planet.isShop then
        if pixelPlanetTypes[planet.galaxyStarType] then
            return "assets/planet/pp_" .. planet.galaxyStarType .. ".png"
        end
        return "assets/planet/planet_shop.png"
    end

    if pixelPlanetTypes[planet.galaxyStarType] then
        return "assets/planet/pp_" .. planet.galaxyStarType .. ".png"
    end
    return "assets/planet/planet_generic.png"
end

function M.studioPlanetImagePaths()
    local paths = {}
    for planetType, asset in pairs(celestialAssets.planets) do
        paths[planetType] = asset.runtimePath
    end
    return paths
end

function M.studioHubPlanetImagePaths()
    local paths = {}
    for planetType, asset in pairs(hubAssets.hubs) do
        paths[planetType] = asset.runtimePath
    end
    return paths
end

function M.selectPlanetArtwork(planet, assets)
    assets = assets or {}
    local planetType = planet.galaxyStarType
    local studioSprite = (assets.studio or {})[planetType]
    if studioSprite and not planet.hub and not planet.isShop then
        return studioSprite, nil
    end

    local pixelSprite = (assets.pixel or {})[planetType]
    local sprite
    if planet.hub then
        local studioHubSprite = (assets.studioHub or {})[planetType]
        if studioHubSprite then
            return studioHubSprite, nil
        end
        sprite = pixelSprite or assets.hub or assets.default
    elseif planet.isShop then
        sprite = pixelSprite or assets.shop or assets.default
    else
        sprite = pixelSprite or assets.default
    end

    local sheet
    if planet.hub then
        sheet = assets.hubSheet
    elseif planetType then
        sheet = (assets.sheets or {})[planetType]
    end
    return sprite, sheet
end

function M.install(scene)
    scene.planetColor = M.planetColor
    scene.planetVariation = M.planetVariation
    scene.planetImagePathForPlanet = M.planetImagePathForPlanet
    scene.studioPlanetImagePaths = M.studioPlanetImagePaths
    scene.studioHubPlanetImagePaths = M.studioHubPlanetImagePaths
    scene.selectPlanetArtwork = M.selectPlanetArtwork
    return scene
end

return M
