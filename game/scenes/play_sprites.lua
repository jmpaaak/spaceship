-- Runtime sprite decoding, loading, and part-icon caching for the play scene.
local M = {}

-- PNG IHDR color type (byte 26): 2 = RGB (opaque square blobs), 6 = RGBA.
function M.pngColorType(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local data
    if love.filesystem and love.filesystem.newFile then
        local file = love.filesystem.newFile(path)
        local ok = file:open("r")
        if ok then
            data = file:read(33)
            file:close()
        end
    end
    if not data then
        local handle = io.open(path, "rb")
        if handle then
            data = handle:read(33)
            handle:close()
        end
    end
    if type(data) ~= "string" or #data < 26 then
        return nil
    end
    if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then
        return nil
    end
    return data:byte(26)
end

function M.shouldLoadRuntimeSprite(path)
    local colorType = M.pngColorType(path)
    -- Unknown headers may be inaccessible in a mobile sandbox. Only known RGB
    -- files are rejected so scene draw helpers can use their polygon fallback.
    return colorType ~= 2
end

function M.loadSprite(path)
    if not M.shouldLoadRuntimeSprite(path) then
        return nil
    end
    if not (love.graphics and love.graphics.newImage) then
        return nil
    end
    local ok, image = pcall(love.graphics.newImage, path)
    if ok and image then
        image:setFilter("nearest", "nearest")
        return image
    end
    return nil
end

local partIconCache = {}

function M.getPartIcon(partId)
    if not partId then return nil end
    if partIconCache[partId] ~= nil then
        return partIconCache[partId] or nil
    end
    local image = M.loadSprite("assets/part_icons/" .. partId .. ".png")
    partIconCache[partId] = image or false
    return image
end

function M.loadSpriteMap(paths)
    local images = {}
    for key, path in pairs(paths) do
        images[key] = M.loadSprite(path)
    end
    return images
end

function M.install(scene)
    scene.pngColorType = M.pngColorType
    scene.shouldLoadRuntimeSprite = M.shouldLoadRuntimeSprite
    scene.loadSprite = M.loadSprite
    scene.getPartIcon = M.getPartIcon
    scene.loadSpriteMap = M.loadSpriteMap
    return scene
end

return M
