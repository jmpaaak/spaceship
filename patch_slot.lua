local function read_file(path)
    local f = io.open(path, "r")
    local c = f:read("*a")
    f:close()
    return c
end
local function write_file(path, c)
    local f = io.open(path, "w")
    f:write(c)
    f:close()
end
local slot_code = read_file("game/expedition_slot.lua")

local cgl = [[
local function combinedGearList(run)
    local parts = {}
    for _, part in ipairs(run.equippedGear or {}) do parts[#parts + 1] = part end
    for _, part in ipairs(run.equippedEngineParts or {}) do parts[#parts + 1] = part end
    return parts
end
]]
slot_code = slot_code:gsub("local M = {}", "local M = {}\n" .. cgl)

-- Replace M.homeGalaxies with require("game.expedition").homeGalaxies
slot_code = slot_code:gsub("M%.homeGalaxies", 'require("game.expedition").homeGalaxies')

-- Replace M.rollGearOffer with require("game.expedition").rollGearOffer
slot_code = slot_code:gsub("M%.rollGearOffer", 'require("game.expedition").rollGearOffer')

write_file("game/expedition_slot.lua", slot_code)
