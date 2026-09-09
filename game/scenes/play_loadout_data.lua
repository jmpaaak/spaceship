-- Launch and settlement loadout presentation assembly, isolated from play.lua.
local speedDisplay = require("game.speed_display")

local M = {}

function M.install(scene, deps)
    local expedition = assert(deps.expedition, "play_loadout_data requires expedition")
    local gear = assert(deps.gear, "play_loadout_data requires gear")
    local i18n = assert(deps.i18n, "play_loadout_data requires i18n")

    local function purchaseStatus(money, cost)
        if money >= cost then return i18n.t("purchase_left", money - cost), true end
        return i18n.t("purchase_short", cost - money), false
    end

    function scene.loadoutLines(subject)
        local run = subject.expedition
        local displayedSpeed = speedDisplay.value(expedition.effectiveSpeed(run), run.baseSpeed)
        local synergies = gear.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
        local synergyOrder = {
            "solarSystem", "nebulaField", "eventHorizon",
            "pulsarBurst", "binaryStar", "supernova", "darkMatter",
        }
        local synergyLabels = {}
        for _, key in ipairs(synergyOrder) do
            if synergies[key] then
                synergyLabels[#synergyLabels + 1] = i18n.t("synergy_" .. key)
            end
        end
        return {
            ship = run.ownedShips.scout
                and i18n.t("loadout_ship", string.upper(run.selectedShipId))
                or nil,
            shipLabel = string.upper(run.selectedShipId),
            stats = i18n.t("stats_line", run.maxDurability),
            upgrades = i18n.t("upgrades_line", run.durabilityUpgradeLevel),
            steering = i18n.t("steer_speed_line", displayedSpeed),
            synergies = synergyLabels,
        }
    end

    function scene.scoutTradeoffLines(run)
        local tradeoff = expedition.shipTradeoff(run, "scout")
        local gain = tradeoff.gains[1]
        local loss = tradeoff.losses[1]
        return {
            i18n.t("scout_gains_line", gain.value, gain.label),
            i18n.t("scout_losses_line", loss.value, loss.label),
        }
    end

    function scene.shopLoadoutLines(subject)
        local run = subject.expedition
        local shipAction
        local shipActionCompact
        local shipAffordable
        local shipStatus
        local previewShipId
        local shipHidden = false
        if not run.ownedShips.scout then
            shipAction = i18n.t("buy_scout", run.scoutShipCost)
            shipActionCompact = i18n.t("buy_scout_compact", run.scoutShipCost)
            shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
            previewShipId = "scout"
        elseif run.selectedShipId == "scout" then
            shipHidden = true
            previewShipId = "scout"
        else
            shipAction = i18n.t("select_scout")
            shipActionCompact = i18n.t("select_scout_compact")
            shipAffordable = true
            previewShipId = "scout"
        end
        local previewDurability = run.baseDurability
            + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
            + expedition.equippedHullDurabilityBonus(run)
        if previewShipId == "scout" then
            previewDurability = previewDurability + expedition.getScoutDurabilityBonus(run)
        end
        local hullStatus, hullAffordable = purchaseStatus(run.money, run.durabilityUpgradeCost)
        local yieldStatus, yieldAffordable = purchaseStatus(run.money, run.sampleYieldUpgradeCost)
        local steeringStatus, steeringAffordable = purchaseStatus(run.money, run.steeringUpgradeCost)
        local displayedSpeed = speedDisplay.value(expedition.effectiveSpeed(run), run.baseSpeed)

        local nextBaseAndGear = run.baseDurability
            + (run.durabilityUpgradeLevel + 1) * run.durabilityUpgradeAmount
            + expedition.equippedHullDurabilityBonus(run)
        local nextMaxDurability = nextBaseAndGear
        if run.selectedShipId == "scout" then
            local bonus = -math.floor(nextBaseAndGear * 0.5)
            if nextBaseAndGear + bonus < 1 then bonus = 1 - nextBaseAndGear end
            nextMaxDurability = nextBaseAndGear + bonus
        end

        local hullCost = expedition.upgradeCost(run, run.durabilityUpgradeCost,
            run.durabilityUpgradeLevel)
        local yieldCost = expedition.upgradeCost(run, run.sampleYieldUpgradeCost,
            run.sampleYieldUpgradeLevel)
        local steeringCost = expedition.upgradeCost(run, run.steeringUpgradeCost,
            run.steeringUpgradeLevel)
        return {
            ship = i18n.t("next_ship_label", string.upper(run.selectedShipId)),
            stats = i18n.t("stats_line", run.maxDurability),
            upgrades = i18n.t("upgrades_line", run.durabilityUpgradeLevel),
            scoutTradeoff = shipHidden and {} or subject.scoutTradeoffLines(run),
            shipHidden = shipHidden,
            shipAction = shipAction,
            shipActionCompact = shipActionCompact,
            shipStatus = shipStatus,
            shipAffordable = shipAffordable,
            shipTradeoffLine = (not shipHidden) and i18n.t("scout_tradeoff_compact",
                run.scoutClimbSpeedBonus, expedition.getScoutDurabilityBonus(run)) or "",
            shipPreview = i18n.t("ship_preview_line", string.upper(previewShipId), previewDurability),
            shipPreviewCompact = i18n.t("ship_preview_compact",
                string.upper(previewShipId), previewDurability),
            hullAction = i18n.t("hull_action_line", run.durabilityUpgradeLevel,
                run.durabilityUpgradeLevel + 1, hullCost),
            hullActionCompact = i18n.t("hull_action_compact", run.maxDurability,
                nextMaxDurability, hullCost),
            hullPreview = i18n.t("stats_line", nextMaxDurability),
            hullPreviewCompact = i18n.t("hull_preview_compact", nextMaxDurability),
            hullStatus = hullStatus,
            hullAffordable = hullAffordable,
            yieldAction = i18n.t("yield_action_line", run.sampleYieldUpgradeLevel,
                run.sampleYieldUpgradeLevel + 1, yieldCost),
            yieldActionCompact = i18n.t("yield_action_compact",
                expedition.sampleYieldMultiplier(run),
                1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount,
                yieldCost),
            yieldPreview = i18n.t("yield_preview_line",
                1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount),
            yieldStatus = yieldStatus,
            yieldAffordable = yieldAffordable,
            steeringAction = i18n.t("steering_action_line", run.steeringUpgradeLevel,
                run.steeringUpgradeLevel + 1, steeringCost),
            steeringActionCompact = i18n.t("steering_action_compact",
                displayedSpeed,
                displayedSpeed + run.steeringUpgradeAmount, steeringCost),
            steeringPreview = i18n.t("steer_speed_line",
                displayedSpeed + run.steeringUpgradeAmount),
            steeringPreviewCompact = i18n.t("steering_preview_compact",
                displayedSpeed + run.steeringUpgradeAmount),
            steeringStatus = steeringStatus,
            steeringAffordable = steeringAffordable,
        }
    end
end

return M
