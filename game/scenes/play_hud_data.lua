local M = {}

function M.distance(ship, earthCenterX, earthCenterY)
    local dx = ship.x - earthCenterX
    local dy = ship.y - earthCenterY
    return math.sqrt(dx * dx + dy * dy)
end

function M.lines(scene, deps, earthCenterX, earthCenterY)
    local run = scene.expedition
    local i18n = deps.i18n
    local world = deps.world
    local best = i18n.t("hud_personal_best", math.floor(run.bestAltitude or 0))
    local dist = M.distance(scene.ship, earthCenterX, earthCenterY)

    local galaxy
    if run.phase == "ascending" or run.phase == "launch" then
        local containing = world.galaxyContaining(scene.ship.x, scene.ship.y)
        if containing then
            galaxy = world.galaxyName(containing)
        end
    end

    return {
        distance = i18n.t("hud_distance", math.floor(dist)),
        cash = i18n.t("hud_cash", run.money),
        best = best,
        status = i18n.t("hud_status_no_slots", run.durability,
            run.maxDurability, i18n.phaseAbbrev(run.phase)),
        galaxy = galaxy,
        maxDurability = run.maxDurability,
    }
end

function M.install(scene, deps)
    local earthCenterX = scene.earthCenterX
    local earthCenterY = scene.earthCenterY

    function scene:hudDistanceRaw()
        return M.distance(self.ship, earthCenterX, earthCenterY)
    end

    function scene:hudLines()
        return M.lines(self, deps, earthCenterX, earthCenterY)
    end
end

return M
