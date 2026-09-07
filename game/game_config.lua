-- Game configuration constants shared across modules.
local M = {}

-- Leaderboard HTTP server (tools/leaderboard_server.py).
-- Set to nil or "" to disable network features.
M.leaderboardUrl = "http://127.0.0.1:8770"

return M
