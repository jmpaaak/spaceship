local input = require("game.scenes.play_input")

local M = {}

local function fixture(phase)
    local launches = 0
    local target = {
        launchSpawnX = 360,
        launchSpawnY = 1100,
        hitHudGearSlot = function() return nil end,
        hitHelpButton = function() return false end,
        joystickOrigin = function(x, y) return x, y end,
        handleDestroyedTouch = function() return true end,
        pauseMenuRects = function()
            return {
                restart = { x = 200, y = 600, w = 300, h = 56 },
                mainMenu = { x = 200, y = 676, w = 300, h = 56 },
            }
        end,
    }
    input.install(target, {
        viewport = { width = 720, height = 1280 },
        settlementTouchRows = {
            { top = 400, bottom = 570, columns = {
                { key = "hull", left = 0, right = 360 },
                { key = "steering", left = 360, right = 720 },
            } },
            { top = 570, bottom = 740, columns = {
                { key = "yield", left = 0, right = 360 },
                { key = "ship", left = 360, right = 720 },
            } },
            { key = "gear", top = 740, bottom = 810 },
            { key = "slot", top = 810, bottom = 1010 },
            { key = "relaunch", top = 1010, bottom = 1180 },
        },
        pauseButton = { x = 616, y = 8, w = 44, h = 44 },
        adminButtons = {},
        adminButtonRect = function() return 0, 0, 0, 0 end,
        expedition = {
            launch = function(run)
                launches = launches + 1
                run.phase = "ascending"
                return true
            end,
            lastCheckpointOrEarth = function() return 0, 75 end,
            boostsRemaining = function() return 0 end,
            buyDurabilityUpgrade = function() return false end,
            buySampleYieldUpgrade = function() return false end,
            buySteeringUpgrade = function() return false end,
            buyShip = function() return false end,
            selectShip = function() return false end,
        },
        world = { resetComets = function() end },
    })
    local scene = setmetatable({
        expedition = {
            phase = phase or "ascending",
            ownedShips = {},
            gearLoadout = {},
            money = 0,
        },
        ship = { x = 321, y = 654 },
        touches = {},
        discovered = {},
        collided = {},
        floatingTexts = {},
        particles = {},
        launchInputArmed = true,
        time = 0,
    }, { __index = target })
    return scene, function() return launches end
end

function M.run()
    print("  [R1-A1] play_input module tests...")

    local shop, launchCount = fixture("settlement")
    local oldX, oldY = shop.ship.x, shop.ship.y
    assert(shop:touchpressed("finger", 360, 1100) == true,
        "R1-A1: relaunch row must consume the press")
    assert(launchCount() == 1 and shop.expedition.phase == "ascending",
        "R1-A1: settlement relaunch tap must launch exactly once")
    assert(shop.ship.x == 360 and shop.ship.y == 1100,
        "R1-A1: relaunch must use the normal Earth launch spawn")
    assert(shop.touches.finger == nil and not (shop.ship.x == oldX and shop.ship.y == oldY),
        "R1-A1: consumed relaunch press must not become steering input")

    local flight = fixture("ascending")
    assert(flight:touchpressed("finger", 100, 900) == true,
        "R1-A1: world press must report consumption")
    assert(flight.touches.finger and flight.touches.finger.x == 100,
        "R1-A1: world press must retain joystick pointer capture")
    assert(flight:touchmoved("finger", 130, 920) == true
            and flight.touches.finger.x == 130 and flight.touches.finger.y == 920,
        "R1-A1: captured drag must update and consume the pointer")
    assert(flight:touchreleased("finger") == true and flight.touches.finger == nil,
        "R1-A1: captured release must clear and consume the pointer")

    local mouse = fixture("ascending")
    assert(mouse:touchpressed("mouse", 620, 900) == true
            and mouse:touchmoved("mouse", 600, 880) == true
            and mouse:touchreleased("mouse") == true,
        "R1-A1: mouse-emulated touch must follow the same capture contract")

    local overlay = fixture("ascending")
    overlay.gearPopup = { part = {} }
    assert(overlay:touchpressed("finger", 500, 900) == true,
        "R1-A1: gear popup must consume its dismiss press")
    assert(overlay.gearPopup == nil and overlay.touches.finger == nil,
        "R1-A1: overlay press must not leak to world steering")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_input"%)'),
        "R1: play.lua must install the extracted input module")
    assert(not playSource:find("function M:keypressed")
            and not playSource:find("function M:touchpressed")
            and not playSource:find("function M:touchmoved")
            and not playSource:find("function M:touchreleased"),
        "R1: input callback implementations must leave play.lua")

    print("  R1-A1 play_input module OK")
end

return M
