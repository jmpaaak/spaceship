local gear = require("game.gear")
local engineParts = require("game.engine_parts")

local M = {}

-- docs/feedback/INBOX.md item 10: "부품 슬롯 이원화 — 선체(허브/조커형) 부품 +
-- 엔진(타로/소모형) 부품 분리". Hull and engine slots must be tracked in two
-- fully independent lists that neither fill nor empty each other, and the
-- bundled engine_parts.json card pool must load and grow to a reasonable
-- initial size just like hull_parts.json did for item 9.
function M.run()
    local enginePool, engineErr = gear.loadEngineParts()
    assert(enginePool, "engine parts must load: " .. tostring(engineErr))
    assert(#enginePool >= 10, "engine part pool should have at least 10 cards, got " .. #enginePool)
    for _, part in ipairs(enginePool) do
        assert(#part.tags >= 1, "engine part '" .. part.id .. "' must have at least one tag")
    end

    local loadout = engineParts.newLoadout()
    assert(#loadout.hull == 0 and #loadout.engine == 0)

    local hullPart = { id = "hull_x", tags = { "defense" }, effects = { { type = "hullDurability", value = 1 } } }
    local enginePart = { id = "engine_x", tags = { "speed" }, effects = { { type = "speed", value = 1 } } }

    local ok1 = engineParts.equip(loadout, "hull", hullPart)
    assert(ok1)
    -- Equipping a hull part must not touch the engine slot list at all.
    assert(#loadout.hull == 1 and #loadout.engine == 0,
        "equipping a hull part must not affect the engine slot list")

    local ok2 = engineParts.equip(loadout, "engine", enginePart)
    assert(ok2)
    assert(#loadout.hull == 1 and #loadout.engine == 1,
        "hull and engine slot lists must be independently tracked")

    -- Unequipping from one category must not touch the other.
    assert(engineParts.unequip(loadout, "engine", "engine_x"))
    assert(#loadout.hull == 1 and #loadout.engine == 0,
        "unequipping an engine part must not affect the hull slot list")

    -- Filling the (smaller) engine slot capacity independently of hull
    -- capacity: engine capacity must be reached without hull slots
    -- affecting it, and vice versa.
    for i = 1, engineParts.engineSlotCount do
        local ok = engineParts.equip(loadout, "engine", { id = "engine_fill_" .. i, tags = {}, effects = {} })
        assert(ok, "expected to be able to equip engine part #" .. i)
    end
    assert(engineParts.isFull(loadout, "engine"), "engine slots must report full at capacity")
    assert(not engineParts.isFull(loadout, "hull"),
        "hull slots must NOT report full just because engine slots are full")

    local okOverflow, overflowErr = engineParts.equip(loadout, "engine", { id = "engine_overflow", tags = {}, effects = {} })
    assert(not okOverflow and overflowErr, "equipping beyond engine capacity must fail")

    -- Duplicate ids within the same category must be rejected.
    local okDup, dupErr = engineParts.equip(loadout, "hull", hullPart)
    assert(not okDup and dupErr, "equipping the same part id twice in one category must fail")
end

return M
