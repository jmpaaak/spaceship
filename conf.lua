function love.conf(t)
    local headless = os.getenv("GAME_HEADLESS") == "1"
    local scale = math.max(1, math.min(4, math.floor(tonumber(os.getenv("GAME_SCALE")) or 1)))

    t.identity = "spaceship"
    t.version = "11.5"
    if headless then
        -- Disable the window table entirely so macOS Love.app does not
        -- flash a Dock icon / steal focus during unit/smoke/verify.
        t.window = false
        t.modules.audio = false
        t.modules.window = false
        t.modules.graphics = false
        return
    end
    t.window.title = "Spaceship"
    t.window.icon = "assets/icon.png"
    t.window.width = 720 * scale
    t.window.height = 1280 * scale
    t.window.resizable = true
    t.window.highdpi = true
    t.window.vsync = 1
    t.window.msaa = 0
end
