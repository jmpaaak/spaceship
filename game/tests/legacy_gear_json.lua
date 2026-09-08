local json = require("game.json")
local gear = require("game.gear")

local M = {}

-- docs/feedback/INBOX.md item 13: JSON gear-data loader must validate
-- schema and defensively reject malformed data (duplicate ids,
-- out-of-range effect values, unknown effect types/rarities, missing
-- fields) instead of silently corrupting the card pool.
function M.run()
    -- Minimal decoder smoke test (game.json) covering the subset of
    -- syntax the gear data files actually use.
    local decoded = json.decode('{"a": 1, "b": [1, 2.5, "x", true, false], "c": {"d": null}}')
    assert(decoded.a == 1)
    assert(decoded.b[1] == 1 and decoded.b[2] == 2.5 and decoded.b[3] == "x" and decoded.b[4] == true and decoded.b[5] == false)
    assert(decoded.c.d == nil)
    local okBad = pcall(json.decode, "{not json")
    assert(not okBad, "malformed JSON must raise an error")

    -- The real bundled hull/engine part data files must load and validate
    -- cleanly through love.filesystem (this is the real production path,
    -- not a mocked filesystem).
    local hullPool, hullErr = gear.loadHullParts()
    assert(hullPool, "hull parts must load: " .. tostring(hullErr))
    assert(#hullPool >= 1, "hull parts pool must be non-empty")
    for _, part in ipairs(hullPool) do
        assert(gear.knownRarities[part.rarity], "hull part has unknown rarity: " .. tostring(part.rarity))
        assert(#part.effects >= 1, "hull part must have at least one effect: " .. part.id)
    end

    local enginePool, engineErr = gear.loadEngineParts()
    assert(enginePool, "engine parts must load: " .. tostring(engineErr))
    assert(#enginePool >= 1, "engine parts pool must be non-empty")

    -- gear.findById must resolve a known id and return nil for unknown ids.
    assert(gear.findById(hullPool, hullPool[1].id) == hullPool[1])
    assert(gear.findById(hullPool, "does-not-exist") == nil)

    -- Defensive parsing: a fake in-memory filesystem lets us exercise
    -- failure paths without touching the real bundled JSON files.
    local function fakeFs(contents)
        return { read = function(path) return contents end }
    end

    local missingOk, missingErr = gear.loadPool("does/not/exist.json", { read = function() return nil end })
    assert(not missingOk and missingErr, "missing file must fail with an error message")

    local malformedOk, malformedErr = gear.loadPool("x.json", fakeFs("{not valid json"))
    assert(not malformedOk and malformedErr:find("invalid JSON"), "malformed JSON must be reported")

    local dupOk, dupErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [' ..
        '{"id":"a","name":"A","icon":"x","rarity":"common","effects":[{"type":"speed","value":1}]},' ..
        '{"id":"a","name":"A2","icon":"x","rarity":"common","effects":[{"type":"speed","value":1}]}' ..
        ']}'))
    assert(not dupOk and dupErr:find("duplicate part id"), "duplicate ids must be rejected")

    local rangeOk, rangeErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"common","effects":[{"type":"speed","value":9999}]}]}'))
    assert(not rangeOk and rangeErr:find("out of range"), "out-of-range effect value must be rejected")

    local badTypeOk, badTypeErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"common","effects":[{"type":"bogusEffect","value":1}]}]}'))
    assert(not badTypeOk and badTypeErr:find("unknown type"), "unknown effect type must be rejected")

    local badRarityOk, badRarityErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"mythic","effects":[{"type":"speed","value":1}]}]}'))
    assert(not badRarityOk and badRarityErr:find("unknown rarity"), "unknown rarity must be rejected")

    local noEffectsOk, noEffectsErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"common","effects":[]}]}'))
    assert(not noEffectsOk and noEffectsErr:find("at least one effect"), "empty effects array must be rejected")

    local missingIdOk, missingIdErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"name":"A","icon":"x","rarity":"common","effects":[{"type":"speed","value":1}]}]}'))
    assert(not missingIdOk and missingIdErr:find("missing a non%-empty string id"), "missing id must be rejected")
end

return M
