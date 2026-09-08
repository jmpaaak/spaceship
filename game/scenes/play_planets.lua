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
    if planet.hub then
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

function M.install(scene)
    scene.planetColor = M.planetColor
    scene.planetVariation = M.planetVariation
    scene.planetImagePathForPlanet = M.planetImagePathForPlanet
    return scene
end

return M
