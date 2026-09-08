local gear = require("game.gear")

local M = {}

-- [2026-09-05] Stellar Origin suit system — M.activeSynergies() unit tests.
-- Verifies all six synergy flags fire at their correct thresholds and that
-- an empty loadout produces no synergies. Pure: only uses gear.lua tables,
-- no love.* calls.
local function testStellarSynergies()
    local i18n = require("game.i18n")
    -- Helper: build a minimal stub card with a given suit.
    local function card(suit)
        return { id = "stub_" .. suit, suit = suit, tags = {}, effects = {} }
    end

    -- solar 3 → solarSystem=true.
    local s3 = gear.activeSynergies({ card("solar"), card("solar"), card("solar") }, {})
    assert(s3.solarSystem == true,
        "solar 3 must activate solarSystem, got: " .. tostring(s3.solarSystem))
    assert(s3.nebulaField == nil,
        "solar 3 must NOT activate nebulaField")

    -- nebula 3 → nebulaField=true.
    local n3 = gear.activeSynergies({ card("nebula"), card("nebula"), card("nebula") }, {})
    assert(n3.nebulaField == true,
        "nebula 3 must activate nebulaField, got: " .. tostring(n3.nebulaField))

    -- void 3 → eventHorizon=true.
    local v3 = gear.activeSynergies({ card("void"), card("void"), card("void") }, {})
    assert(v3.eventHorizon == true,
        "void 3 must activate eventHorizon, got: " .. tostring(v3.eventHorizon))

    -- pulsar 2 → pulsarBurst=true.
    local p2 = gear.activeSynergies({ card("pulsar"), card("pulsar") }, {})
    assert(p2.pulsarBurst == true,
        "pulsar 2 must activate pulsarBurst, got: " .. tostring(p2.pulsarBurst))

    -- 4 suits each 1 card → supernova=true.
    local four = gear.activeSynergies(
        { card("solar"), card("nebula") },
        { card("void"),  card("pulsar") })
    assert(four.supernova == true,
        "4 suits each 1+ must activate supernova, got: " .. tostring(four.supernova))

    -- Empty loadout → no synergies.
    local empty = gear.activeSynergies({}, {})
    local emptySynergyCount = 0
    for _ in pairs(empty) do emptySynergyCount = emptySynergyCount + 1 end
    assert(emptySynergyCount == 0,
        "empty loadout must produce no synergies, got count: " .. emptySynergyCount)

    assert(i18n.t("synergy_desc_solarSystem") ~= "synergy_desc_solarSystem",
        "synergy_desc_solarSystem i18n key must exist")
    assert(i18n.t("synergy_desc_nebulaField") ~= "synergy_desc_nebulaField",
        "synergy_desc_nebulaField i18n key must exist")
    local nebulaHint = i18n.synergyHint("nebula")
    assert(type(nebulaHint) == "table",
        "synergyHint must return a table, got: " .. type(nebulaHint))
    assert(nebulaHint.name and nebulaHint.name:find(i18n.t("synergy_nebulaField"), 1, true),
        "synergyHint(nebula).name must contain the synergy name, got: " .. tostring(nebulaHint.name))
    assert(nebulaHint.desc and nebulaHint.desc:find(i18n.t("synergy_desc_nebulaField"), 1, true),
        "synergyHint(nebula).desc must contain the condition text, got: " .. tostring(nebulaHint.desc))
    local nilHint = i18n.synergyHint(nil)
    local unknownHint = i18n.synergyHint("unknown")
    assert(type(nilHint) == "table" and nilHint.name == "" and nilHint.desc == "",
        "synergyHint(nil) must return {name='', desc=''}")
    assert(type(unknownHint) == "table" and unknownHint.name == "" and unknownHint.desc == "",
        "synergyHint('unknown') must return {name='', desc=''}")

    -- INBOX item 6: synergy names must not start with prefix symbols
    local prefixPats = { "^☀ ", "^%* ", "^# ", "^~ ", "^x ", "^%+ ", "^@ " }
    for _, lang in ipairs({"en", "ko"}) do
        i18n.setLocale(lang)
        for _, synKey in ipairs({"solarSystem","nebulaField","eventHorizon","pulsarBurst","binaryStar","supernova","darkMatter"}) do
            local name = i18n.t("synergy_" .. synKey)
            for _, pat in ipairs(prefixPats) do
                assert(not name:find(pat),
                    lang .. " synergy_" .. synKey .. " must not start with prefix symbol, got: " .. name)
            end
        end
    end
    i18n.setLocale("en")  -- restore default

    -- Bundled JSON cards all have suit field (no [WARN] paths expected from loader in prod).
    local hullPool, hullErr = gear.loadHullParts()
    assert(hullPool, "hull pool must load for suit check: " .. tostring(hullErr))
    for _, part in ipairs(hullPool) do
        assert(part.suit ~= nil and gear.knownSuits[part.suit],
            "hull card '" .. part.id .. "' must have a valid suit field, got: " .. tostring(part.suit))
    end
    local enginePool, engineErr = gear.loadEngineParts()
    assert(enginePool, "engine pool must load for suit check: " .. tostring(engineErr))
    for _, part in ipairs(enginePool) do
        assert(part.suit ~= nil and gear.knownSuits[part.suit],
            "engine card '" .. part.id .. "' must have a valid suit field, got: " .. tostring(part.suit))
    end
end

local function testExpeditionStellarSynergies()
    local expedition = require("game.expedition")

    local function makeCard(id, suit, rarity, effects)
        return {
            id = id,
            suit = suit,
            rarity = rarity or "common",
            tags = {},
            effects = effects or {}
        }
    end

    local runNebula = {
        sampleYieldUpgradeLevel = 2,
        sampleYieldUpgradeAmount = 0.5,
        equippedGear = { makeCard("n1", "nebula"), makeCard("n2", "nebula"), makeCard("n3", "nebula") },
        equippedEngineParts = {}
    }
    assert(math.abs(expedition.sampleYieldMultiplier(runNebula) - 3.0) < 0.001, "nebulaField must apply 1.5x")

    local runPulsar = {
        equippedGear = { makeCard("p1", "pulsar"), makeCard("p2", "pulsar") },
        equippedEngineParts = {}
    }
    local baseBonus = expedition.streakBonusPerStep(runPulsar)
    local expectedMult = (1 + 2 * baseBonus) * 2
    assert(math.abs(expedition.streakMultiplier(3, runPulsar) - expectedMult) < 0.001, "pulsarBurst must apply 2x")

    local runDarkMatter = {
        equippedGear = { makeCard("v1", "void"), makeCard("v2", "void"), makeCard("p1", "pulsar"), makeCard("p2", "pulsar") },
        equippedEngineParts = {}
    }
    local expectedDM = (1 + 2 * baseBonus) * 2 * 1.5
    assert(math.abs(expedition.streakMultiplier(3, runDarkMatter) - expectedDM) < 0.001, "darkMatter must apply 1.5x on top of 2x")

    local runVoid = {
        equippedGear = { makeCard("v1", "void"), makeCard("v2", "void"), makeCard("v3", "void") },
        equippedEngineParts = {}
    }
    -- eventHorizon no longer modifies collisionRadius; gear-only CR still works
    assert(math.abs(expedition.collisionRadius(runVoid, 100) - 100) < 0.001,
        "eventHorizon must NOT reduce collision radius (moved to collectOrbitRadius)")
    -- eventHorizon (void 3+) now grants +30% collectOrbitRadius
    assert(math.abs(expedition.collectOrbitRadius(runVoid, 100) - 130) < 0.001,
        "eventHorizon must increase collect orbit radius by 30%")
    -- Without void 3+, collectOrbitRadius is unchanged
    local runNoVoid = { equippedGear = {}, equippedEngineParts = {} }
    assert(math.abs(expedition.collectOrbitRadius(runNoVoid, 100) - 100) < 0.001,
        "collectOrbitRadius without eventHorizon must equal base")

    local runSupernova = {
        equippedGear = {
            makeCard("s1", "solar"), makeCard("n1", "nebula"), makeCard("v1", "void"), makeCard("p1", "pulsar"),
            makeCard("leg1", "solar", "legendary", {{type = "speed", value = 10}}),
            makeCard("com1", "solar", "common", {{type = "speed", value = 10}})
        },
        equippedEngineParts = {}
    }
    local totals = expedition.equippedTotals(runSupernova)
    assert(totals.speed == 25, "supernova must boost legendary effect values by 1.5x, got: " .. tostring(totals.speed))

    local runSettle = {
        phase = "ascending",
        altitude = 1,
        baseSpeed = 100,
        returnSpeed = 10,
        bestAltitude = 100, pendingSampleValue = 0, sampleCount = 0, maxAltitude = 100,
        money = 100,
        durability = 1,
        maxDurability = 5,
        equippedGear = {
            makeCard("s1", "solar", "common", {{type = "sampleSellValue", value = 10}}), makeCard("s2", "solar"), makeCard("s3", "solar"),
            makeCard("n1", "nebula"), makeCard("n2", "nebula")
        },
        equippedEngineParts = {}
    }
    expedition.settle(runSettle)
    assert(runSettle.phase == "settlement", "Must reach settlement")
    -- INBOX 61(5): solarSystem now grants +1 maxDurability (not just heal)
    assert(runSettle.maxDurability == 6, "solarSystem must increase maxDurability from 5 to 6, got: " .. tostring(runSettle.maxDurability))
    assert(runSettle.durability == 2, "solarSystem must also heal +1 durability (1→2)")
    assert(runSettle.money == 100, "binaryStar must not grant flat money")
end

-- [2026-09-05] Stellar Origin sub-item 4: loadoutLines() synergy HUD test.
-- Verifies that a nebula-3 loadout populates loadout.synergies with the
-- NEBULA FIELD label and that an empty loadout returns an empty list.
-- Pure: uses PlayScene.new() in headless mode (no love.graphics calls).
local function testStellarSynergyHUD()
    local PlayScene = require("game.scenes.play")
    local i18n = require("game.i18n")
    -- Stub store
    local store = { load = function() return 0 end, save = function() return false end }
    local scene = PlayScene.new({ bestAltitudeStore = store })

    -- Case 1: empty loadout → synergies list is empty.
    scene.expedition.equippedGear = {}
    scene.expedition.equippedEngineParts = {}
    local lEmpty = scene:loadoutLines()
    assert(type(lEmpty.synergies) == "table",
        "loadoutLines must return synergies table, got: " .. type(lEmpty.synergies))
    assert(#lEmpty.synergies == 0,
        "empty loadout must produce 0 synergy labels, got: " .. #lEmpty.synergies)

    -- Case 2: nebula 3 → nebulaField synergy label present.
    local function nc(id)
        return { id = id, suit = "nebula", rarity = "common", tags = {}, effects = {} }
    end
    scene.expedition.equippedGear = { nc("n1"), nc("n2"), nc("n3") }
    scene.expedition.equippedEngineParts = {}
    local lNebula = scene:loadoutLines()
    assert(#lNebula.synergies == 1,
        "nebula 3 loadout must produce 1 synergy label, got: " .. #lNebula.synergies)
    local expectedLabel = i18n.t("synergy_nebulaField")
    assert(lNebula.synergies[1] == expectedLabel,
        "nebula 3 synergy label must be '" .. expectedLabel
        .. "', got: '" .. tostring(lNebula.synergies[1]) .. "'")
end

function M.run()
    testStellarSynergies()
    testExpeditionStellarSynergies()
    testStellarSynergyHUD()
end

return M
