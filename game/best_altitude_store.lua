local M = {}
M.__index = M

local function validAltitude(value)
    return type(value) == "number" and value >= 0 and value == value and value < math.huge
end

function M.new(filename, filesystem)
    return setmetatable({
        filename = filename or "best-altitude.txt",
        filesystem = filesystem or love.filesystem,
    }, M)
end

function M:load()
    local contents = self.filesystem.read(self.filename)
    local altitude = tonumber(contents)
    if not validAltitude(altitude) then return 0 end
    return altitude
end

function M:save(altitude)
    if not validAltitude(altitude) or altitude <= self:load() then return false end
    return self.filesystem.write(self.filename, string.format("%.17g", altitude)) == true
end

return M
