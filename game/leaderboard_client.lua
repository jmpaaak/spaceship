-- INBOX 61(23) remaining: leaderboard score submission client.
-- Posts bestAltitude to the leaderboard server (tools/leaderboard_server.py)
-- on settle and destroy, if bestAltitude was updated.
-- Fires and forgets via love.thread; silently skips when server is
-- unreachable or when running in headless/test mode.

local gameConfig = require("game.game_config")

local M = {}

-- Thread code template for async POST.
-- Receives (url, body) as varargs.
local POST_THREAD_CODE = [[
    local url, body = ...
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local response = {}
    http.request{
        url = url .. "/score",
        method = "POST",
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(response),
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#body),
        },
    }
    -- Fire-and-forget: result is intentionally discarded.
]]

--- Submit a score to the leaderboard server (async, fire-and-forget).
--- @param name string   player name (default "Player")
--- @param bestAltitude number
function M.submitScore(name, bestAltitude)
    local url = gameConfig.leaderboardUrl
    if not url or url == "" then return end

    -- In headless/test mode love.thread may not exist.
    if not love or not love.thread then return end

    local body = string.format(
        '{"name":"%s","bestAltitude":%s}',
        tostring(name or "Player"):gsub('"', '\\"'),
        tostring(bestAltitude or 0)
    )

    local ok, thread = pcall(function()
        return love.thread.newThread(POST_THREAD_CODE)
    end)
    if ok and thread then
        thread:start(url, body)
        -- Thread reference kept alive until GC; no need to poll result.
    end
end

--- Pure-logic helper: returns true when bestAltitude exceeds the
--- previous best recorded at launch time (launchBestAltitude).
--- Used by play.lua to decide whether to submit.
function M.isNewBest(run)
    return run.bestAltitude > (run.launchBestAltitude or 0)
end

return M
