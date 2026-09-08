local sprites = require("game.scenes.play_sprites")

local M = {}

local function writePngHeader(path, colorType)
    local header = "\137PNG\r\n\26\n" .. string.rep("\0", 17) .. string.char(colorType)
    assert(love.filesystem.write(path, header), "R1: PNG header fixture must be writable")
end

function M.run()
    print("  [R1] play_sprites module tests...")

    local api = {}
    sprites.install(api)
    assert(api.pngColorType == sprites.pngColorType,
        "R1: sprite decoder must remain available on the scene API")
    assert(api.shouldLoadRuntimeSprite == sprites.shouldLoadRuntimeSprite,
        "R1: sprite validation must remain available on the scene API")
    assert(api.loadSprite == sprites.loadSprite,
        "R1: sprite loading must remain available on the scene API")
    assert(api.getPartIcon == sprites.getPartIcon,
        "R1: part-icon loading must remain available on the scene API")
    assert(api.loadSpriteMap == sprites.loadSpriteMap,
        "R1: sprite-map loading must be exposed by the extracted module")

    local rgbPath = "r1_sprite_rgb_header.png"
    local rgbaPath = "r1_sprite_rgba_header.png"
    writePngHeader(rgbPath, 2)
    writePngHeader(rgbaPath, 6)
    assert(sprites.pngColorType(rgbPath) == 2,
        "R1: PNG decoder must identify RGB sprites")
    assert(sprites.pngColorType(rgbaPath) == 6,
        "R1: PNG decoder must identify RGBA sprites")
    assert(not sprites.shouldLoadRuntimeSprite(rgbPath),
        "R1: RGB sprites must retain the polygon fallback")
    assert(sprites.shouldLoadRuntimeSprite(rgbaPath),
        "R1: RGBA sprites must remain loadable")
    assert(sprites.shouldLoadRuntimeSprite("missing-r1-sprite.png"),
        "R1: unreadable headers must remain eligible for runtime loading")
    love.filesystem.remove(rgbPath)
    love.filesystem.remove(rgbaPath)

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_sprites"%)'),
        "R1: play.lua must delegate runtime sprite loading")
    assert(not playSource:find("local function pngColorType"),
        "R1: PNG decoding must leave play.lua")
    assert(not playSource:find("local function loadSprite"),
        "R1: sprite loading must leave play.lua")
    assert(not playSource:find("local function getPartIcon"),
        "R1: part-icon caching must leave play.lua")
    assert(not playSource:find("local function loadSpriteMap"),
        "R1: sprite-map loading must leave play.lua")

    print("  R1 play_sprites module OK")
end

return M
