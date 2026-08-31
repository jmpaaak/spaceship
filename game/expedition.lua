local M = {}

local function slotCount(distance, slotDistance)
    if distance <= 0 then return 0 end
    return math.ceil(distance / slotDistance)
end

function M.new(options)
    options = options or {}
    return {
        phase = "launch",
        altitude = 0,
        maxAltitude = 0,
        fuel = options.fuel or 100,
        fuelBurnRate = options.fuelBurnRate or 5,
        climbSpeed = options.climbSpeed or 30,
        returnSpeed = options.returnSpeed or 45,
        slotDistance = options.slotDistance or 100,
        returnDistance = 0,
        slotOpportunities = 0,
        slotSpins = 0,
    }
end

function M.launch(run)
    if run.phase ~= "launch" then return false end
    run.phase = "ascending"
    return true
end

function M.useSlot(run)
    if run.phase ~= "returning" or run.slotOpportunities <= 0 then return false end
    run.slotOpportunities = run.slotOpportunities - 1
    run.slotSpins = run.slotSpins + 1
    return true
end

function M.update(run, dt)
    if dt <= 0 then return end

    if run.phase == "returning" then
        run.altitude = math.max(0, run.altitude - run.returnSpeed * dt)
        if run.altitude == 0 then run.phase = "settlement" end
        return
    end

    if run.phase ~= "ascending" then return end

    local ascentTime = dt
    if run.fuelBurnRate > 0 then
        ascentTime = math.min(dt, run.fuel / run.fuelBurnRate)
        run.fuel = math.max(0, run.fuel - run.fuelBurnRate * dt)
    end

    run.altitude = run.altitude + run.climbSpeed * ascentTime
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)

    if run.fuel <= 0 then
        run.phase = "returning"
        run.returnDistance = run.maxAltitude
        run.slotOpportunities = slotCount(run.returnDistance, run.slotDistance)
    end
end

return M
