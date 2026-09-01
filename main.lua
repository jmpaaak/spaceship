local viewport = require("game.viewport")
local sceneStack = require("game.scene_stack")
local PlayScene = require("game.scenes.play")

local canvas
local scenes
local headless = os.getenv("GAME_HEADLESS") == "1"
local captureRequested = os.getenv("GAME_CAPTURE") == "1"
local captureQueued = false

function love.load()
    if headless then
        if os.getenv("GAME_UNIT") == "1" then
            require("game.self_test").run()
        end
        print("SPACESHIP_SMOKE_OK")
        love.event.quit(0)
        return
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
    canvas = love.graphics.newCanvas(viewport.width, viewport.height)
    canvas:setFilter("nearest", "nearest")
    scenes = sceneStack.new(PlayScene.new())
end

function love.update(dt)
    if scenes then sceneStack.update(scenes, math.min(dt, 1 / 20)) end
end

function love.draw()
    if not scenes then return end
    love.graphics.setCanvas(canvas)
    sceneStack.draw(scenes)
    love.graphics.setCanvas()
    local width, height = love.graphics.getDimensions()
    local scale, x, y = viewport.fit(width, height, false)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, x, y, 0, scale, scale)
    if captureRequested and not captureQueued then
        captureQueued = true
        love.graphics.captureScreenshot(function(imageData)
            imageData:encode("png", "spaceship-runtime-preview.png")
            print("SPACESHIP_CAPTURE_OK:" .. love.filesystem.getSaveDirectory() .. "/spaceship-runtime-preview.png")
            love.event.quit(0)
        end)
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if scenes then sceneStack.keypressed(scenes, key) end
end

local function touchToGame(x, y)
    local width, height = love.graphics.getDimensions()
    return viewport.toGame(x, y, width, height, false)
end

function love.touchpressed(id, x, y)
    if not scenes then return end
    local gameX, gameY, inside = touchToGame(x, y)
    if inside then sceneStack.touchpressed(scenes, id, gameX, gameY) end
end

function love.touchmoved(id, x, y)
    if not scenes then return end
    local gameX, gameY = touchToGame(x, y)
    sceneStack.touchmoved(scenes, id, gameX, gameY)
end

function love.touchreleased(id, x, y)
    if not scenes then return end
    local gameX, gameY = touchToGame(x, y)
    sceneStack.touchreleased(scenes, id, gameX, gameY)
end

local function persistBestAltitude()
    if scenes and scenes.current and scenes.current.persistBestAltitude then
        scenes.current:persistBestAltitude()
    end
end

function love.focus(focused)
    if not focused then persistBestAltitude() end
end

function love.quit()
    persistBestAltitude()
end
