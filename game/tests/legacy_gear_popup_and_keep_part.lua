local expedition = require("game.expedition")
local gear = require("game.gear")
local i18n = require("game.i18n")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    i18n.setLocale("en")
    assert(i18n.t("ship_destroyed_title") == "GAME OVER")
    assert(i18n.t("meta_reset_line", 12) == "MY BEST 12")
    assert(i18n.t("checkpoint_hint_repair") == "hull repair")
    assert(i18n.t("checkpoint_hint_upgrade") == "upgrades")
    assert(i18n.effectLine({ type = "speed", value = 5 }) == "SPEED +5")
    assert(i18n.rarityLabel("legendary") == "LEGENDARY")
    assert(i18n.suitLabel("solar") == "SOLAR")

    local hullPool = gear.loadHullParts()
    local part = hullPool[1]
    assert(part, "need a hull part fixture")

    local scene = PlayScene.new()
    scene.expedition.phase = "ascending"
    assert(expedition.equipGear(scene.expedition, "hull", part))
    local hud = scene:hudLines()
    local hudHeight = PlayScene.hudHeight(scene.expedition.phase, hud, 0)
    local layout = PlayScene.hudGearSlotLayout(hudHeight)
    local slot = layout.hull[1]
    scene:touchpressed("tap", slot.x + 4, slot.y + 4)
    assert(scene.gearPopup and scene.gearPopup.part and scene.gearPopup.part.id == part.id,
        "tapping an equipped hull slot must open the part popup")
    scene:touchpressed("tap2", 400, 600)
    assert(scene.gearPopup == nil, "tapping outside must close the popup")

    local wipeRun = expedition.new()
    assert(expedition.equipGear(wipeRun, "hull", part))
    expedition.launch(wipeRun)
    wipeRun.durability = 1
    assert(expedition.damage(wipeRun, 5))
    assert(wipeRun.phase == "destroyed")
    assert(#wipeRun.equippedGear == 0)
    assert(wipeRun.keepPartChoices and #wipeRun.keepPartChoices >= 1,
        "destroy must snapshot equipped parts for keep-one")
    wipeRun.keptPart = wipeRun.keepPartChoices[1]
    assert(expedition.launch(wipeRun))
    assert(#wipeRun.equippedGear == 1 and wipeRun.equippedGear[1].id == part.id,
        "relaunch after game over must keep the chosen part")
end

return M