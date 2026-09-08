local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- INBOX 61(15): slotExclusive parts — pool filtering, slot-machine
-- acquisition, and gear-editor round-trip.
function M.run()
    -- (a) Bundled JSON pools must each carry at least 2 slotExclusive cards.
    local hullPool = gear.loadHullParts()
    local enginePool = gear.loadEngineParts()
    local function countSlotExcl(pool)
        local n = 0
        for _, p in ipairs(pool) do
            if p.slotExclusive then n = n + 1 end
        end
        return n
    end
    assert(countSlotExcl(hullPool) >= 2,
        "hull_parts.json must carry at least 2 slotExclusive cards")
    assert(countSlotExcl(enginePool) >= 2,
        "engine_parts.json must carry at least 2 slotExclusive cards")

    -- (b) gear.earthShopPool must exclude slotExclusive parts.
    local earthHull = gear.earthShopPool(hullPool)
    local earthEngine = gear.earthShopPool(enginePool)
    for _, p in ipairs(earthHull) do
        assert(not p.slotExclusive, "Earth shop hull pool must not contain slot-exclusive parts")
    end
    for _, p in ipairs(earthEngine) do
        assert(not p.slotExclusive, "Earth shop engine pool must not contain slot-exclusive parts")
    end
    assert(#earthHull < #hullPool, "Earth shop hull pool must be smaller (slot-exclusive removed)")
    assert(#earthEngine < #enginePool, "Earth shop engine pool must be smaller (slot-exclusive removed)")

    -- (c) gear.slotPool must return only slotExclusive parts.
    local slotHull = gear.slotPool(hullPool)
    local slotEngine = gear.slotPool(enginePool)
    assert(#slotHull >= 2, "slotPool hull must have at least 2 cards")
    assert(#slotEngine >= 2, "slotPool engine must have at least 2 cards")
    for _, p in ipairs(slotHull) do
        assert(p.slotExclusive, "slotPool must contain only slot-exclusive hull parts")
    end
    for _, p in ipairs(slotEngine) do
        assert(p.slotExclusive, "slotPool must contain only slot-exclusive engine parts")
    end

    -- (d) earthSlotSpin PART 2-match must prefer slotExclusive pool.
    -- Force a 2-match PART spin and verify the reward comes from slotExclusive.
    -- Note: rollGearOffer returns a simplified copy without slotExclusive field,
    -- so we check the returned id is in the slotExclusive set.
    local run = expedition.new()
    local weights = expedition.earthSlotWeights(nil)
    local partStart = weights.MONEY  -- PART is the 2nd symbol
    local partRoll = partStart + 0.5
    -- Build a lookup of all slotExclusive ids (hull + engine combined).
    local slotExclIds = {}
    for _, p in ipairs(gear.slotPool(hullPool)) do slotExclIds[p.id] = true end
    for _, p in ipairs(gear.slotPool(enginePool)) do slotExclIds[p.id] = true end
    local spin2 = expedition.earthSlotSpin(run, nil, {
        reels = { partRoll, partRoll, 0.5 },  -- PART, PART, MONEY
        partRarity = 0,
        partPick = 0,
        partEditionChance = 1,
        partEditionPick = 0,
    })
    assert(spin2.matchCount == 2 and spin2.matchSymbol == "PART",
        "expected 2-match PART")
    if spin2.rewardPart then
        assert(slotExclIds[spin2.rewardPart.id],
            "INBOX 61(15): 2-match PART spin should prefer slotExclusive card, got " ..
            tostring(spin2.rewardPart.id))
    end

    -- (e) earthSlotSpin PART 3-match: slot-exclusive rare/legendary preferred.
    local spin3 = expedition.earthSlotSpin(run, nil, {
        reels = { partRoll, partRoll, partRoll },
        partRarity = 0,
        partPick = 0,
        partEditionChance = 1,
        partEditionPick = 0,
    })
    assert(spin3.matchCount == 3 and spin3.matchSymbol == "PART",
        "expected 3-match PART")
    if spin3.rewardPart then
        assert(slotExclIds[spin3.rewardPart.id],
            "INBOX 61(15): 3-match PART spin should prefer slotExclusive card, got " ..
            tostring(spin3.rewardPart.id))
    end

    -- (f) Gear-editor round-trips slotExclusive.
    local editorJs = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorJs, "tools/gear-editor/editor.js must be readable")
    local htmlSrc = love.filesystem.read("tools/gear-editor/index.html")
    assert(htmlSrc, "tools/gear-editor/index.html must be readable")

    assert(htmlSrc:find('id="fieldSlotExclusive"', 1, true),
        "index.html must expose a fieldSlotExclusive control")
    assert(htmlSrc:find("Slot exclusive", 1, true) or htmlSrc:find("slot exclusive", 1, true),
        "index.html must label the slotExclusive control")

    local collectStart = editorJs:find("function collectFormPart")
    assert(collectStart, "editor.js must define collectFormPart")
    local collectEnd = editorJs:find("\n}", collectStart)
    local collectBlock = editorJs:sub(collectStart, collectEnd)
    assert(collectBlock:find("slotExclusive"),
        "collectFormPart must include slotExclusive so saves do not strip it")

    local openStart = editorJs:find("function openForm")
    assert(openStart, "editor.js must define openForm")
    local openEnd = editorJs:find("\nfunction closeForm", openStart) or editorJs:find("\n}", openStart)
    local openBlock = editorJs:sub(openStart, openEnd)
    assert(openBlock:find("slotExclusive"),
        "openForm must restore slotExclusive from the loaded part")

    -- (g) GEAR_SCHEMA.md must document slotExclusive.
    local schema = love.filesystem.read("docs/GEAR_SCHEMA.md")
    assert(schema, "docs/GEAR_SCHEMA.md must be readable")
    assert(schema:find('"slotExclusive"', 1, true),
        "GEAR_SCHEMA.md Card-shape example JSON must include slotExclusive")
    assert(schema:find("`slotExclusive`", 1, true),
        "GEAR_SCHEMA.md field table must document slotExclusive")
    assert(schema:find("slot machine", 1, true) or schema:find("slotPool", 1, true),
        "GEAR_SCHEMA.md slotExclusive notes must mention slot machine acquisition")
end

return M
