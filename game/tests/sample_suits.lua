local world = require("game.world")
local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")
local i18n = require("game.i18n")

local M = {}

function M.run()
    print("  [INBOX 69] sample suits / hue family remap tests...")

    assert(#world.hueFamilies == 4,
        "INBOX 69: hueFamilies must have 4 suit keys, got " .. tostring(#world.hueFamilies))
    assert(world.hueFamilies[1].key == "solar"
            and world.hueFamilies[2].key == "nebula"
            and world.hueFamilies[3].key == "void"
            and world.hueFamilies[4].key == "pulsar",
        "INBOX 69: hueFamilies order must be solar/nebula/void/pulsar")

    assert(world.hueFamily(0.00).key == "solar")
    assert(world.hueFamily(0.24).key == "solar")
    assert(world.hueFamily(0.25).key == "nebula")
    assert(world.hueFamily(0.49).key == "nebula")
    assert(world.hueFamily(0.50).key == "void")
    assert(world.hueFamily(0.74).key == "void")
    assert(world.hueFamily(0.75).key == "pulsar")
    assert(world.hueFamily(0.99).key == "pulsar")

    local worldSrc = love.filesystem.read("game/world.lua") or ""
    assert(not worldSrc:find('key = "azure"', 1, true)
            and not worldSrc:find('key = "ember"', 1, true),
        "INBOX 69: world.lua hueFamilies must drop azure/ember keys")

    local catalog = world.specimenCatalog()
    assert(#catalog == 12,
        "INBOX 69: 4 suits x 3 tiers = 12 catalog entries, got " .. tostring(#catalog))
    local solarId, solarLabel = world.specimenKind({ hue = 0.1, y = -50 })
    assert(solarId == "solar_common",
        "INBOX 69: hue 0.1 common must be solar_common, got " .. tostring(solarId))
    assert(solarLabel == "SOLAR DUST",
        "INBOX 69: solar common label must be SOLAR DUST, got " .. tostring(solarLabel))
    local nebulaId, nebulaLabel = world.specimenKind({ hue = 0.4, y = -500 })
    assert(nebulaId == "nebula_rare",
        "INBOX 69: hue 0.4 rare must be nebula_rare, got " .. tostring(nebulaId))
    assert(nebulaLabel == "NEBULA SHARD")
    local voidId = world.specimenKind({ hue = 0.6, y = -500 })
    assert(voidId == "void_rare")
    local pulsarId, pulsarLabel = world.specimenKind({ hue = 0.9, y = -900 })
    assert(pulsarId == "pulsar_epic",
        "INBOX 69: hue 0.9 epic must be pulsar_epic, got " .. tostring(pulsarId))
    assert(pulsarLabel == "PULSAR CORE")

    local run = expedition.new({})
    run.phase = "ascending"
    local ok1, awarded1, mult1 = expedition.collectSample(run, 100, "solar")
    local ok2, awarded2, mult2 = expedition.collectSample(run, 100, "solar")
    local ok3, awarded3, mult3 = expedition.collectSample(run, 100, "solar")
    assert(ok1 and ok2 and ok3)
    assert(awarded1 == 100 and mult1 == 1)
    assert(awarded2 == 120 and mult2 == 1.2,
        "INBOX 69: second consecutive solar must be x1.2, got " .. tostring(awarded2))
    assert(awarded3 == 140 and mult3 == 1.4,
        "INBOX 69: third consecutive solar must be x1.4, got " .. tostring(awarded3))
    local ok4, awarded4, mult4 = expedition.collectSample(run, 100, "nebula")
    assert(ok4 and awarded4 == 100 and mult4 == 1,
        "INBOX 69: switching to nebula must reset streak to x1.0, got " .. tostring(awarded4))
    assert(run.sampleStreakFamily == "nebula")

    i18n.setLocale("en")
    run.sampleStreakCount = 3
    run.sampleStreakFamily = "solar"
    assert(PlayScene.streakHudLabel(run) == "SOLAR x1.4",
        "INBOX 69: EN HUD must show SOLAR x1.4, got " .. tostring(PlayScene.streakHudLabel(run)))
    run.sampleStreakFamily = "nebula"
    run.sampleStreakCount = 1
    assert(PlayScene.streakHudLabel(run) == "NEBULA x1.0")
    run.sampleStreakFamily = "void"
    assert(PlayScene.streakHudLabel(run) == "VOID x1.0")
    run.sampleStreakFamily = "pulsar"
    assert(PlayScene.streakHudLabel(run) == "PULSAR x1.0")

    i18n.setLocale("ko")
    run.sampleStreakFamily = "solar"
    run.sampleStreakCount = 3
    assert(PlayScene.streakHudLabel(run) == "솔라 x1.4",
        "INBOX 69: KO HUD must show 솔라 x1.4, got " .. tostring(PlayScene.streakHudLabel(run)))
    run.sampleStreakFamily = "nebula"
    run.sampleStreakCount = 1
    assert(PlayScene.streakHudLabel(run) == "네뷸라 x1.0")
    run.sampleStreakFamily = "void"
    assert(PlayScene.streakHudLabel(run) == "보이드 x1.0")
    run.sampleStreakFamily = "pulsar"
    assert(PlayScene.streakHudLabel(run) == "펄서 x1.0")
    i18n.setLocale("en")

    print("  INBOX 69 sample suits OK")
end

return M
