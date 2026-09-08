local M = {}

function M.risk(run, planet, deps)
    -- The abolished returning phase has no collision risk.
    if run.phase ~= "ascending" then return nil end

    local damage = deps.world.collisionDamage(planet)
    local lethal = damage >= run.durability
    local risk = {
        damage = damage,
        lethal = lethal,
        label = string.format(
            lethal and deps.i18n.t("risk_lethal") or deps.i18n.t("risk_normal"),
            damage),
    }
    local baseValue = deps.world.sampleValue(planet)
    risk.sampleValue = math.floor(
        baseValue * deps.expedition.sampleYieldMultiplier(run) + 0.5)
    risk.sampleLabel = string.format(deps.i18n.t("sample_value_label"), risk.sampleValue)
    return risk
end

function M.warning(run, collided, planet, planetScreenY, shipScreenY, deps)
    if planet.id and collided[planet.id] then return nil end
    local approaching = run.phase == "ascending"
        and planetScreenY >= 40
        and planetScreenY < shipScreenY
    if not approaching then return nil end
    return M.risk(run, planet, deps)
end

function M.install(target, deps)
    function target:collisionRisk(planet)
        return M.risk(self.expedition, planet, deps)
    end

    function target:approachWarning(planet, planetScreenY, shipScreenY)
        return M.warning(self.expedition, self.collided, planet,
            planetScreenY, shipScreenY, deps)
    end
    return target
end

return M
