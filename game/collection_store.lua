-- Persists the player's discovered specimen ids ("azure_common", ...)
-- across runs/destructions, the same way best_altitude_store.lua persists
-- the best altitude: a plain-text file read/written through love.filesystem
-- (or an injected fake in tests). Unlike money/samples, this collection is
-- never reset by ship destruction -- it is the permanent trophy shelf shown
-- under the launch screen.
local M = {}
M.__index = M

function M.new(filename, filesystem)
    return setmetatable({
        filename = filename or "specimen-collection.txt",
        filesystem = filesystem or love.filesystem,
    }, M)
end

function M:load()
    local contents = self.filesystem.read(self.filename)
    local ids = {}
    if type(contents) ~= "string" then return ids end
    for id in contents:gmatch("[^,\n]+") do
        ids[id] = true
    end
    return ids
end

local function serialize(ids)
    local sorted = {}
    for id in pairs(ids) do sorted[#sorted + 1] = id end
    table.sort(sorted)
    return table.concat(sorted, ",")
end
M.serialize = serialize

-- Merges newId into the persisted set and writes the file only if it
-- actually changed anything, returning true when a new specimen was
-- recorded (so callers can trigger a "NEW SPECIMEN" popup) and false when
-- the id was already known or invalid.
function M:record(newId)
    if type(newId) ~= "string" or newId == "" then return false end
    local ids = self:load()
    if ids[newId] then return false end
    ids[newId] = true
    self.filesystem.write(self.filename, serialize(ids))
    return true
end

return M
