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
    -- Interactive/demo/capture runs show Korean. Unit tests pin "en".
    require("game.i18n").setLocale("ko")
    if os.getenv("GAME_FONTPROBE") == "1" then
        local smallSlotFont = love.graphics.newFont(8)
        for _, s in ipairs({ "PLANET  PLANET  PLANET", "COMET  COMET  COMET", "STAR  STAR  STAR",
            "WIN +$40  FUEL +15", "WIN +$75  REPAIR +1", "WIN +$40  PENDING $40" }) do
            print(string.format("SMALLSLOTFONTPROBE|%s|%d", s, smallSlotFont:getWidth(s)))
        end
        local font = love.graphics.newFont(8)
        local samples = {
            "T/H HULL LV.0>1 $75", "T/H HULL LV.9>10 $75",
            "T/G STEER LV.0>1 $65", "T/G STEER LV.9>10 $65",
            "T/Y YIELD LV.0>1 $60", "T/Y YIELD LV.9>10 $60",
            "T/V BUY SCOUT $125", "T/V SELECT STARTER", "T/V SELECT SCOUT",
            "LEFT $999", "SHORT $999", "OWNED",
            "LEFT $9999", "SHORT $125", "LEFT $105", "SHORT $105",
            "FUEL LV.0 HULL LV.0 YIELD LV.0 STEER LV.0",
            "FUEL LV.9 HULL LV.9 YIELD LV.9 STEER LV.9",
            "H:LV.9>10", "G:LV.9>10", "Y:LV.9>10", "H:LV.0>1", "G:LV.0>1", "Y:LV.0>1",
            "$999", "OK $999",
            "T/H HULL", "T/G STEER", "T/Y YIELD", "T/V SCOUT",
            "LV.9>10 $75", "LV.9>10 $65", "LV.9>10 $60", "$125",
            "LV.0>1 $75", "LV.0>1 $65", "LV.0>1 $60",
            "LEFT $999", "SHORT $999", "SELECT",
            "STARTER", "SCOUT", "BUY $125",
            "H:LV.0>1 $75", "H:LV.9>10 $75", "G:LV.0>1 $65", "G:LV.9>10 $65",
            "Y:LV.0>1 $60", "Y:LV.9>10 $60", "V:BUY $125", "V:STARTER", "V:SCOUT",
            "HULL 4", "HULL 10", "SPD 70", "SPD 190", "YIELD x1.25", "YIELD x3.25",
            "LEFT $999", "SHORT $999",
            "SELECT STARTER", "SELECT SCOUT", "BUY SCOUT $125",
            "H:LV.0>1 $75 LEFT $105", "H:LV.9>10 $75 SHORT $75",
            "G:LV.0>1 $65 LEFT $105", "G:LV.9>10 $65 SHORT $65",
            "Y:LV.0>1 $60 LEFT $105", "Y:LV.9>10 $60 SHORT $60",
            "V:BUY $125 LEFT $105", "V:STARTER OWNED", "V:SCOUT OWNED",
        }
        for _, s in ipairs(samples) do
            print(string.format("FONTPROBE|%s|%d", s, font:getWidth(s)))
        end
        love.event.quit(0)
        return
    end
    love.graphics.setDefaultFilter("nearest", "nearest")
    canvas = love.graphics.newCanvas(viewport.width, viewport.height)
    canvas:setFilter("nearest", "nearest")
    scenes = sceneStack.new(PlayScene.new())
    local capturePhase = os.getenv("GAME_CAPTURE_PHASE")
    if capturePhase == "destroyed" then
        local run = scenes.current.expedition
        run.phase = "settlement"
        run.money = run.fuelUpgradeCost + run.durabilityUpgradeCost + 25
        require("game.expedition").buyFuelUpgrade(run)
        require("game.expedition").buyDurabilityUpgrade(run)
        require("game.expedition").launch(run)
        run.maxAltitude = 400
        run.altitude = 400
        run.bestAltitude = 400
        run.sampleCount = 2
        run.pendingSampleValue = 80
        run.slotSpins = 1
        run.pendingSlotReward = 75
        require("game.expedition").damage(run, run.durability)
    elseif capturePhase == "settlement-newbest" then
        local run = scenes.current.expedition
        run.bestAltitude = 300
        require("game.expedition").launch(run)
        run.phase = "settlement"
        run.maxAltitude = 400
        run.altitude = 400
        run.bestAltitude = 400
        run.lastAltitude = 400
        run.lastNewBest = true
        run.sampleCount = 0
        run.slotSpins = 0
        run.pendingSampleValue = 0
        run.pendingSlotReward = 0
        run.lastSampleCount = 2
        run.lastSampleSettlement = 80
        run.lastSlotSpinsCount = 1
        run.lastSlotSettlement = 75
        run.lastSettlement = 155
        run.money = 155
        run.bankedFuelBonus = 15
    elseif capturePhase == "ascending-wide-warning" then
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 1000
        scene.ship.y = -1000
        scene.ship.x = 0
        local world = require("game.world")
        world.nearbyPlanets = function()
            return { { id = "wide-warning", x = 85, y = -1020, radius = 10, hue = 0.1 } }
        end
        world.collisionDamage = function() return 3 end
        world.sampleValue = function() return 999 end
    elseif capturePhase == "ascending-sample-tiers" then
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 900
        scene.ship.y = -900
        scene.ship.x = 0
        local world = require("game.world")
        world.nearbyPlanets = function()
            return {
                { id = "tier-common", x = -50, y = -950, radius = 9, hue = 0.1 },
                { id = "tier-rare", x = 0, y = -1000, radius = 9, hue = 0.5 },
                { id = "tier-epic", x = 55, y = -1050, radius = 9, hue = 0.8 },
            }
        end
        world.collisionDamage = function() return 1 end
        world.sampleValue = function() return 10 end
        world.sampleTier = function(planet)
            if planet.id == "tier-common" then return "common" end
            if planet.id == "tier-rare" then return "rare" end
            return "epic"
        end
    elseif capturePhase == "ascending-epic-pickup-effects" then
        -- Dev-only capture for verifying the Balatro-style particle burst
        -- and ship scale-punch on an epic-tier sample pickup, requested in
        -- the 2026-09-02 pending feedback.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 900
        scene.ship.y = -900
        scene.ship.x = 0
        local world = require("game.world")
        world.nearbyPlanets = function()
            return { { id = "epic-pickup", x = 0, y = -900, radius = 9, hue = 0.8 } }
        end
        world.collisionDamage = function() return 0 end
        world.sampleValue = function() return 999 end
        world.sampleTier = function() return "epic" end
        scene:update(0)
    elseif capturePhase == "returning-odds" then
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.phase = "returning"
        scene.expedition.altitude = 500
        scene.expedition.returnDistance = 500
        scene.expedition.slotOpportunities = 3
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "returning-repair" then
        -- Real-runtime capture for the new repair-voucher slot reward
        -- (docs/GAME_DESIGN.md 귀환 슬롯: 수리권). Forces a completed
        -- STAR-STAR-STAR spin result so the WIN +$N REPAIR +N message
        -- renders in the slot result box.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.phase = "returning"
        scene.expedition.altitude = 500
        scene.expedition.returnDistance = 500
        scene.expedition.durability = 1
        scene.expedition.slotOpportunities = 2
        scene.expedition.lastSlotSymbols = { "STAR", "STAR", "STAR" }
        scene.expedition.lastSlotReward = 75
        scene.expedition.lastSlotRepair = 1
        scene.expedition.durability = 2
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "settlement-shortfunds" then
        -- Real-runtime capture for the "남은 다음 슬라이스 후보 (1)" item in
        -- docs/STATUS.md: verify the SHORT $N status branch (as opposed to
        -- the already-captured LEFT $N affordable branch) renders inside
        -- the measured shopStatusColumnW without overlap. money=0 forces
        -- every purchase row (fuel/hull/steering/yield/scout) into SHORT $N.
        local run = scenes.current.expedition
        require("game.expedition").launch(run)
        run.phase = "settlement"
        run.money = 0
        run.lastSettlement = 0
        run.lastSampleCount = 0
        run.lastSampleSettlement = 0
        run.lastSlotSpinsCount = 0
        run.lastSlotSettlement = 0
        run.lastAltitude = 0
        run.lastNewBest = false
    elseif capturePhase == "ascending-streak" then
        -- Real-runtime capture for the new hue-family STREAK sample bonus
        -- (docs/feedback/INBOX.md Balatro core-mechanics porting plan item
        -- 1). Pre-seeds a same-hue-family streak of 2 so the very next
        -- collected sample lands at streak 3 (x1.4) and the message shows
        -- the STREAK multiplier.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 500
        scene.expedition.sampleStreakCount = 2
        scene.expedition.sampleStreakFamily = "azure"
        scene.ship.y = -500
        scene.ship.x = 0
        local world = require("game.world")
        world.nearbyPlanets = function()
            return { { id = "streak-test", x = 0, y = -500, radius = 7, hue = 0.1 } }
        end
        world.collisionDamage = function() return 0 end
        world.sampleValue = function() return 100 end
    elseif capturePhase == "ascending-sample-rollup" then
        -- Real-runtime capture for the new "+$N" numeric roll-up feedback
        -- (docs/feedback/INBOX.md 2026-09-02 후속 확정 사항 #2). Manually
        -- constructs a sample floating text mid-way through its 0.3s
        -- roll-up animation (instead of relying on real frame timing,
        -- which would land the very first update() at ~1/60s and only
        -- show a near-zero value) so the capture reliably shows a
        -- partial, still-counting-up value like a slot-machine reel
        -- settling on its result.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 500
        scene.ship.y = -500
        scene.ship.x = 0
        local playScene = require("game.scenes.play")
        table.insert(scene.floatingTexts, {
            text = string.format("+$%d", playScene.rollupAmount(140, 0.15, playScene.sampleRollupDuration)),
            x = scene.ship.x,
            y = scene.ship.y,
            timer = 1.0,
            kind = "sample",
            awarded = 140,
            rollupElapsed = 0.15,
        })
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "ascending-damage-text" then
        -- Real-runtime capture for the new red "-N" damage floating text
        -- (mirrors the existing green "+$N" sample floating text). Places
        -- the ship directly on top of a planet so the very first update
        -- triggers a real collision and spawns the floating damage text.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 500
        scene.ship.y = -500
        scene.ship.x = 0
        local world = require("game.world")
        world.nearbyPlanets = function()
            return { { id = "damage-text-test", x = 0, y = -500, radius = 7, hue = 0.1 } }
        end
        world.collisionDamage = function() return 2 end
    elseif capturePhase == "returning-fuelbonus" then
        -- Real-runtime capture for the new next-expedition fuel-bonus slot
        -- reward (docs/GAME_DESIGN.md 귀환 슬롯: 다음 원정 연료 보너스).
        -- Forces a completed PLANET-PLANET-PLANET spin result so the
        -- WIN +$N FUEL +N message renders in the slot result box.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.phase = "returning"
        scene.expedition.altitude = 500
        scene.expedition.returnDistance = 500
        scene.expedition.slotOpportunities = 2
        scene.expedition.lastSlotSymbols = { "PLANET", "PLANET", "PLANET" }
        scene.expedition.lastSlotReward = 40
        scene.expedition.lastSlotFuelBonus = 15
        scene.expedition.pendingFuelBonus = 15
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "returning-samplebonus" then
        -- Real-runtime capture for the new sample-value slot reward
        -- (docs/GAME_DESIGN.md 귀환 슬롯: 표본 보너스). Forces a completed
        -- COMET-COMET-COMET spin result so the WIN +$N SAMPLE +$N message
        -- renders in the slot result box.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.phase = "returning"
        scene.expedition.altitude = 500
        scene.expedition.returnDistance = 500
        scene.expedition.slotOpportunities = 2
        scene.expedition.lastSlotSymbols = { "COMET", "COMET", "COMET" }
        scene.expedition.lastSlotReward = 40
        scene.expedition.lastSlotSampleBonus = 25
        scene.expedition.pendingSampleValue = 25
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "ascending-joystick-diagonal" then
        -- Real-runtime capture for the new omnidirectional joystick
        -- movement (docs/GAME_DESIGN.md 이동 방식 개선 항목 1). Simulates a
        -- diagonal drag touch held for a full second so the resulting
        -- frame visibly shows the ship having moved both horizontally
        -- (self.ship.x) and vertically off the automatic altitude line
        -- (self.verticalOffset), which the old binary LEFT/RIGHT-only
        -- input could never produce.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 500
        scene.ship.y = -500
        scene.ship.x = 0
        local joystick = require("game.joystick")
        scene.touches["dev-joystick"] = {
            originX = 90, originY = 200,
            x = 90 + joystick.maxRadius, y = 200 + joystick.maxRadius,
        }
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
        scene:update(1)
    elseif capturePhase == "ascending-minimap-beyond" then
        -- Real-runtime capture for the galaxy minimap's beyond-chart
        -- readout (docs/GAME_DESIGN.md 이동 방식 개선 항목 3): the ship is
        -- placed past chartRadius so the top-right chart must show the
        -- rim-clamped Earth marker, a return chevron, and an OUT N label.
        -- There is still no world wall -- only the chart changes.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 400
        local minimap = require("game.minimap")
        scene.ship.x = minimap.chartRadius + 5000
        scene.ship.y = -400
        local world = require("game.world")
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "ascending-checkpoint-tint" then
        -- Real-runtime capture for docs/feedback/INBOX.md item 1: a
        -- checkpoint galaxy marker/arrow + galaxy background tint. Places
        -- the ship inside a non-home galaxy (found by scanning cells) so
        -- the HUD galaxy name changes, the background tint shifts away
        -- from the solar-system navy, and (since the ship is now far from
        -- Earth/home) the minimap should show at least the checkpoint
        -- galaxy's own special hub marker on the chart.
        local scene = scenes.current
        require("game.expedition").launch(scene.expedition)
        scene.expedition.altitude = 400
        local world = require("game.world")
        local found
        for gy = -3, 3 do
            for gx = -3, 3 do
                if not (gx == 0 and gy == 0) then
                    local galaxy = world.galaxy(gx, gy)
                    if galaxy then found = galaxy break end
                end
            end
            if found then break end
        end
        if found then
            scene.ship.x = found.x
            scene.ship.y = found.y
        end
        world.nearbyPlanets = function() return {} end
    elseif capturePhase == "full-loop-relaunch" then
        -- Real-runtime capture for the top pending feedback item (세로
        -- 상승형 로그라이트 핵심 루프): drives the actual scene through a
        -- full launch -> ascend -> collect -> fuel-empty return -> slot
        -- spin -> safe settlement -> shop upgrade -> relaunch round trip
        -- via the same PlayScene:keypressed/update entry points a real
        -- player uses (not just field assignment), then captures the
        -- resulting fresh ascending screen so the loop is verified
        -- end-to-end in one real LOVE runtime frame instead of only via
        -- static per-phase field seeding.
        local scene = scenes.current
        local world = require("game.world")
        local expeditionModule = require("game.expedition")
        scene:keypressed("space") -- launch
        world.nearbyPlanets = function()
            return { { id = "full-loop-sample", x = 0, y = -5, radius = 7, hue = 0.1 } }
        end
        scene.ship.x = 0
        scene.expedition.altitude = 5
        scene:update(0.001) -- collect the sample near-instantly
        world.nearbyPlanets = function() return {} end
        expeditionModule.beginReturn(scene.expedition)
        while scene.expedition.phase == "returning" and scene.expedition.slotOpportunities > 0 do
            scene:keypressed("space") -- spin every offered slot
            scene:update(1) -- let the slot-spin animation resolve before the
            -- next keypress, otherwise self.slotSpin never clears and
            -- keypressed's "not self.slotSpin" guard blocks all further
            -- spins forever (infinite loop / hang).
        end
        scene:update(1000) -- finish the return -> settlement
        expeditionModule.buyFuelUpgrade(scene.expedition) -- shop upgrade with settled money
        scene:keypressed("space") -- relaunch
    elseif capturePhase == "launch-with-specimens" then
        -- Real-runtime capture for the launch-screen specimen log strip
        -- (docs/feedback 2026-09-02 request: show off exploration finds
        -- under the launch loadout card). Pre-seeds a handful of
        -- discovered specimens across tiers/families so the strip shows a
        -- mix of filled and empty squares instead of an all-empty grid.
        local scene = scenes.current
        scene.collectedSpecimens = {
            azure_common = true,
            ember_rare = true,
            void_epic = true,
            azure_rare = true,
        }
    end
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

local function clampToCanvas(gameX, gameY)
    if gameX < 0 then gameX = 0 end
    if gameX > viewport.width then gameX = viewport.width end
    if gameY < 0 then gameY = 0 end
    if gameY > viewport.height then gameY = viewport.height end
    return gameX, gameY
end

local function touchToGame(x, y)
    local width, height = love.graphics.getDimensions()
    local gameX, gameY = viewport.toGame(x, y, width, height, false)
    return clampToCanvas(gameX, gameY)
end

function love.touchpressed(id, x, y)
    if not scenes then return end
    local gameX, gameY = touchToGame(x, y)
    sceneStack.touchpressed(scenes, id, gameX, gameY)
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

-- Desktop `love .` never fires love.touch* (those are mobile/tablet).
-- Route the mouse through the same PlayScene touch/joystick path so a
-- click-drag is a virtual stick. Ignore istouch so a real touch isn't
-- handled twice (LÖVE also synthesizes mouse events for touches).
-- Coordinates are clamped onto the 180x320 canvas so high-dpi letterbox
-- rounding cannot drop the press as "outside" and silently eat the drag.
local mouseTouchId = "mouse"

function love.mousepressed(x, y, button, istouch)
    if istouch or button ~= 1 or not scenes then return end
    local gameX, gameY = touchToGame(x, y)
    sceneStack.touchpressed(scenes, mouseTouchId, gameX, gameY)
end

function love.mousemoved(x, y, dx, dy, istouch)
    if istouch or not scenes then return end
    if not love.mouse.isDown(1) then return end
    local gameX, gameY = touchToGame(x, y)
    sceneStack.touchmoved(scenes, mouseTouchId, gameX, gameY)
end

function love.mousereleased(x, y, button, istouch)
    if istouch or button ~= 1 or not scenes then return end
    local gameX, gameY = touchToGame(x, y)
    sceneStack.touchreleased(scenes, mouseTouchId, gameX, gameY)
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
