function love.conf(t)
    local headless = os.getenv("GAME_HEADLESS") == "1"
    local scale = math.max(1, math.min(4, math.floor(tonumber(os.getenv("GAME_SCALE")) or 1)))

    t.identity = "spaceship"
    t.version = "11.5"
    t.window.title = "Spaceship"
    t.window.width = 720 * scale
    t.window.height = 1280 * scale
    t.window.resizable = true
    t.window.highdpi = false
    t.window.vsync = 1
    t.window.msaa = 0
    t.modules.audio = not headless
    t.modules.window = not headless
    t.modules.graphics = not headless
end
