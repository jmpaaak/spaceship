local input = require("game.scenes.play_input")
local playJoystick = require("game.scenes.play_joystick")
local playBoost = require("game.scenes.play_boost")

local M = {}

local function fixture(phase)
    local launches = 0
    local target = {
        launchSpawnX = 360,
        launchSpawnY = 1100,
        hitHudGearSlot = function() return nil end,
        hitShopModalGearSlot = function() return nil end,
        shopModalButtonRects = function()
            return { x = 200, y = 700, w = 140, h = 60 },
                { x = 380, y = 700, w = 140, h = 60 }
        end,
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
    playBoost.install(target)
    input.install(target, {
        playBoost = playBoost,
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
        layout = {
            shopModalButtons = function()
                return { x = 200, y = 700, w = 140, h = 60 },
                    { x = 380, y = 700, w = 140, h = 60 }
            end,
        },
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
    return scene, function() return launches end, target
end

function M.run()
    require("game.tests.play_boost_input").run()
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
    assert(shop.uiCapturedPointers.finger,
        "R1-A1: relaunch pointer must stay UI-captured until release")
    assert(shop:touchmoved("finger", 100, 900) == true and shop.touches.finger == nil,
        "R1-A1: dragging a consumed relaunch pointer must not activate steering")
    assert(shop:touchreleased("finger") == true and not shop.uiCapturedPointers.finger,
        "R1-A1: UI capture must clear on release")

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

    local help = fixture("ascending")
    help.helpOverlayOpen = true
    assert(help:touchpressed("help", 100, 900) == true
            and not help.helpOverlayOpen and help.touches.help == nil
            and help.uiCapturedPointers.help,
        "R1-A1: help overlay must consume and capture its dismiss pointer")

    local modal = fixture("ascending")
    modal.shopModal = { gear = {}, category = "hull", isReplacement = false }
    assert(modal:touchpressed("modal", 100, 900) == true
            and modal.touches.modal == nil and modal.uiCapturedPointers.modal,
        "R1-A1: shop modal must consume presses outside its buttons")

    local paused = fixture("ascending")
    paused.paused = true
    paused.hitHelpButton = function() return true end
    paused.hitHudGearSlot = function() return { part = {}, rect = {} } end
    assert(paused:touchpressed("pause-overlay", 100, 900) == true
            and not paused.paused and not paused.helpOverlayOpen
            and paused.gearPopup == nil and paused.touches["pause-overlay"] == nil,
        "R1-A1: pause overlay must block help/gear/world controls underneath")

    local destroyed = fixture("destroyed")
    assert(destroyed:touchpressed("destroyed", 100, 900) == true
            and destroyed.touches.destroyed == nil
            and destroyed.uiCapturedPointers.destroyed,
        "R1-A1: destroyed overlay action must capture its pointer")

    local launchGate, gateLaunches = fixture("launch")
    assert(launchGate:touchpressed("launch", 100, 900) == true and gateLaunches() == 1
            and launchGate.touches.launch == nil and launchGate.uiCapturedPointers.launch,
        "R1-A1: launch-screen tap must not become steering after phase transition")

    -- Exact desktop regression: mouse remains physically held for a frame
    -- after Relaunch changes phase to ascending. pollDesktopMouse must not
    -- recreate a virtual joystick touch at the button coordinate.
    local held = true
    local oldMouse = love.mouse
    local oldGraphics = love.graphics
    love.mouse = {
        isDown = function() return held end,
        getPosition = function() return 360, 1100 end,
    }
    love.graphics = love.graphics or {}
    local oldGetDimensions = love.graphics.getDimensions
    love.graphics.getDimensions = function() return 720, 1280 end
    local desktop, desktopLaunches, desktopTarget = fixture("settlement")
    desktop.allowDesktopMousePollingInTests = true
    playJoystick.install(desktopTarget)
    assert(desktop:touchpressed("mouse", 360, 1100) == true and desktopLaunches() == 1)
    desktop:pollDesktopMouse()
    assert(desktop.touches.mouse == nil and desktop.uiCapturedPointers.mouse,
        "R1-A1: held UI mouse after launch must not be recreated as joystick input")
    held = false
    desktop:pollDesktopMouse()
    assert(desktop.touches.mouse == nil and not desktop.uiCapturedPointers.mouse,
        "R1-A1: missed mouse release must clear UI capture during polling")
    love.graphics.getDimensions = oldGetDimensions
    love.mouse = oldMouse
    if not oldGraphics then love.graphics = nil end

    local disabledBoost = fixture("ascending")
    disabledBoost.boostBtnRect = { x = 580, y = 1100, w = 120, h = 72 }
    disabledBoost.hitBoostButton = function(self, x, y)
        return x >= self.boostBtnRect.x and x <= self.boostBtnRect.x + self.boostBtnRect.w
            and y >= self.boostBtnRect.y and y <= self.boostBtnRect.y + self.boostBtnRect.h
    end
    assert(disabledBoost:touchpressed("finger", 620, 1120) == true
            and disabledBoost.touches.finger == nil
            and disabledBoost.uiCapturedPointers.finger,
        "R1-A1: disabled BOOST button must consume and capture its pointer")
    assert(disabledBoost:touchmoved("finger", 300, 800) == true
            and disabledBoost.touches.finger == nil,
        "INBOX 74: dragging a BOOST-started pointer must not activate movement")
    assert(disabledBoost:touchreleased("finger") == true
            and not disabledBoost.uiCapturedPointers.finger
            and disabledBoost.touches.finger == nil,
        "INBOX 74: releasing a BOOST-started pointer must clear capture without movement")

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
