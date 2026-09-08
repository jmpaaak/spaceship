local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test specimen-catalog extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_specimen_catalog.lua")

    assert(runner:find('require("game.tests.legacy_specimen_catalog").run()', 1, true),
        "R1-C: self_test must delegate specimen-catalog checks to the legacy suite")
    assert(not runner:find("duplicate specimen id", 1, true),
        "R1-C: specimen-catalog test body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted specimen-catalog suite must expose run()")
    print("  R1-C self_test specimen-catalog extraction OK")
end

return M