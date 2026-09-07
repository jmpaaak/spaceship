-- INBOX 61(23): Leaderboard scene — shows top 20 scores from local server.
-- Fetches GET /scores?limit=20 from game_config.leaderboardUrl.
-- Falls back gracefully when server is unreachable.

local viewport = require("game.viewport")
local i18n = require("game.i18n")
local fonts = require("game.fonts")
local gameConfig = require("game.game_config")

local M = {}
M.__index = M

-- Layout constants (720×1280 canvas)
M.backButtonW = 200
M.backButtonH = 56
M.backButtonY = 1180
M.entryHeight = 42
M.listTopY = 180
M.maxEntries = 20

function M.new(options)
    options = options or {}
    local self = setmetatable({
        onBack = options.onBack,           -- callback: return to title
        scores = {},                       -- { {name=, bestAltitude=, rank=}, ... }
        state = "loading",                 -- "loading" | "loaded" | "error"
        httpThread = nil,
        httpChannel = nil,
    }, M)
    self:_fetchScores()
    return self
end

function M:_fetchScores()
    local url = gameConfig.leaderboardUrl
    if not url or url == "" then
        self.state = "loaded"
        self.scores = {}
        return
    end
    -- In headless/test mode, love.thread may not exist
    if not love or not love.thread then
        self.state = "loaded"
        self.scores = {}
        return
    end
    local threadCode = [[
        local url = ...
        local http = require("socket.http")
        local ltn12 = require("ltn12")
        local channel = love.thread.getChannel("leaderboard_result")
        local body = {}
        local ok, status = http.request{
            url = url .. "/scores?limit=20",
            sink = ltn12.sink.table(body),
            headers = { ["Accept"] = "application/json" },
        }
        if ok and status == 200 then
            channel:push("OK:" .. table.concat(body))
        else
            channel:push("ERR:" .. tostring(status))
        end
    ]]
    local ok, thread = pcall(function()
        return love.thread.newThread(threadCode)
    end)
    if ok and thread then
        self.httpChannel = love.thread.getChannel("leaderboard_result")
        self.httpThread = thread
        thread:start(url)
    else
        self.state = "loaded"
        self.scores = {}
    end
end

function M:update(dt)
    if self.state == "loading" and self.httpChannel then
        local msg = self.httpChannel:pop()
        if msg then
            if msg:sub(1, 3) == "OK:" then
                local jsonStr = msg:sub(4)
                self.scores = M._parseScores(jsonStr)
                self.state = "loaded"
            else
                self.state = "error"
            end
            self.httpThread = nil
            self.httpChannel = nil
        end
    end
end

-- Minimal JSON array parser for [{name, bestAltitude}, ...]
function M._parseScores(jsonStr)
    local scores = {}
    if not jsonStr or jsonStr == "" then return scores end
    -- Match each object in the array
    for obj in jsonStr:gmatch("{(.-)}") do
        local name = obj:match('"name"%s*:%s*"([^"]*)"')
        local alt = obj:match('"bestAltitude"%s*:%s*([%d%.]+)')
        if name and alt then
            scores[#scores + 1] = {
                name = name,
                bestAltitude = tonumber(alt),
            }
        end
    end
    -- Sort descending by altitude (server should already sort, but be safe)
    table.sort(scores, function(a, b) return a.bestAltitude > b.bestAltitude end)
    -- Limit
    while #scores > M.maxEntries do
        scores[#scores] = nil
    end
    -- Assign ranks
    for i, s in ipairs(scores) do
        s.rank = i
    end
    return scores
end

function M:backButtonRect()
    local cx = viewport.width / 2
    return {
        x = cx - M.backButtonW / 2,
        y = M.backButtonY,
        w = M.backButtonW,
        h = M.backButtonH,
    }
end

function M:draw()
    -- Background
    love.graphics.clear(0.02, 0.02, 0.06, 1)

    -- Title
    local titleFont = fonts.get(48)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(i18n.t("leaderboard_title"), 0, 60, viewport.width, "center")

    local bodyFont = fonts.get(24)
    love.graphics.setFont(bodyFont)

    if self.state == "loading" then
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.printf(i18n.t("leaderboard_loading"), 0, 400, viewport.width, "center")
    elseif self.state == "error" then
        love.graphics.setColor(0.9, 0.3, 0.3, 1)
        love.graphics.printf(i18n.t("leaderboard_error"), 0, 400, viewport.width, "center")
    elseif #self.scores == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.printf(i18n.t("leaderboard_empty"), 0, 400, viewport.width, "center")
    else
        local y = M.listTopY
        for _, entry in ipairs(self.scores) do
            -- Rank
            love.graphics.setColor(0.4, 0.7, 1, 1)
            love.graphics.printf(
                string.format(i18n.t("leaderboard_rank"), entry.rank),
                40, y, 80, "left"
            )
            -- Name
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(entry.name, 130, y, 340, "left")
            -- Altitude
            love.graphics.setColor(1, 0.85, 0.3, 1)
            love.graphics.printf(
                string.format("%.0f m", entry.bestAltitude),
                480, y, 200, "right"
            )
            y = y + M.entryHeight
        end
    end

    -- Back button
    local rect = self:backButtonRect()
    love.graphics.setColor(0.08, 0.14, 0.22, 0.9)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 10, 10)
    love.graphics.setColor(0.3, 0.6, 1, 0.8)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 10, 10)
    local btnFont = fonts.get(28)
    love.graphics.setFont(btnFont)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(i18n.t("leaderboard_back"), rect.x, rect.y + rect.h / 2 - 12, rect.w, "center")
end

function M:touchpressed(id, x, y)
    local rect = self:backButtonRect()
    if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
        if self.onBack then self.onBack() end
    end
end

function M:keypressed(key)
    if key == "escape" or key == "backspace" then
        if self.onBack then self.onBack() end
    end
end

return M
