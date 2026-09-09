local M = {}

local hash = require("game.world").hash
local world = require("game.world")

M.stations = {}
M.stationIdCounter = 0
M.stationNextSpawn = 60
M.stationSpawnInterval = 30
M.stationSpawnChance = 0.30
M.stationFirstSpawned = false

function M.reset(startTime)
    M.stations = {}
    M.stationIdCounter = 0
    M.stationNextSpawn = (startTime or 0) + 60
    M.stationFirstSpawned = false
end

function M.spawn(time, shipX, shipY, viewW, viewH)
    viewW = viewW or 720
    viewH = viewH or 1280
    M.stationIdCounter = M.stationIdCounter + 1
    local id = "station_" .. M.stationIdCounter

    -- Spawn ahead of the ship, since ship travels up (decreasing Y)
    local startX = shipX + (hash(M.stationIdCounter, 100, 9004) - 0.5) * viewW * 0.8
    local startY = shipY - viewH * 0.8

    local radius = 30
    local rotationSpeed = (hash(M.stationIdCounter, 101, 9005) - 0.5) * 1.0
    if math.abs(rotationSpeed) < 0.2 then
        rotationSpeed = 0.5
    end
    
    local arcSpan = 50 * math.pi / 180 -- 50 degrees
    local initialArcAngle = hash(M.stationIdCounter, 102, 9006) * math.pi * 2

    local station = {
        id = id,
        spawnTime = time,
        x = startX,
        y = startY,
        radius = radius,
        rotationSpeed = rotationSpeed,
        rotation = 0,
        arcSpan = arcSpan,
        initialArcAngle = initialArcAngle,
        docked = false,
    }
    M.stations[#M.stations + 1] = station
    return station
end

function M.tickSpawn(time, shipX, shipY, viewW, viewH)
    if time < M.stationNextSpawn then return nil end

    local shouldSpawn = false
    if not M.stationFirstSpawned then
        shouldSpawn = true
        M.stationFirstSpawned = true
    else
        local roll = hash(math.floor(time * 100), 556, 9011)
        shouldSpawn = roll < M.stationSpawnChance
    end

    M.stationNextSpawn = M.stationNextSpawn + M.stationSpawnInterval

    if shouldSpawn then
        return M.spawn(time, shipX, shipY, viewW, viewH)
    end
    return nil
end

function M.nearbyStations(shipX, shipY, time, dt, viewW, viewH)
    viewW = viewW or 720
    viewH = viewH or 1280
    local nearby = {}
    local alive = {}
    local maxDist = math.max(viewW, viewH) * 2.0
    for _, st in ipairs(M.stations) do
        if not st.docked then
            st.rotation = st.rotation + st.rotationSpeed * dt
        end
        local dx = st.x - shipX
        local dy = st.y - shipY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < maxDist then
            alive[#alive + 1] = st
            nearby[#nearby + 1] = st
        end
    end
    M.stations = alive
    return nearby
end

-- Station docking logic
-- returns "docked", "crash", or "none"
function M.checkDocking(station, shipX, shipY, shipVx, shipVy, maxSafeSpeed)
    local dx = shipX - station.x
    local dy = shipY - station.y
    local dist2 = dx * dx + dy * dy
    local hitDist = station.radius + 15 -- approximate ship radius
    
    if dist2 <= hitDist * hitDist then
        local currentArcAngle = (station.initialArcAngle + station.rotation) % (math.pi * 2)
        -- atan2(dy, dx) returns angle of ship from station center.
        -- Docking port points outward, so ship needs to be in that angle.
        local shipAngle = math.atan2(dy, dx)
        if shipAngle < 0 then shipAngle = shipAngle + math.pi * 2 end
        
        local currentMod = currentArcAngle % (math.pi * 2)
        if currentMod < 0 then currentMod = currentMod + math.pi * 2 end
        
        local diff = math.abs(shipAngle - currentMod)
        if diff > math.pi then diff = math.pi * 2 - diff end
        
        local speed2 = (shipVx or 0)^2 + (shipVy or 0)^2
        
        if diff <= station.arcSpan / 2 and speed2 <= (maxSafeSpeed^2) then
            return "docked"
        else
            return "crash"
        end
    end
    return "none"
end

return M
