-- INBOX 61(21): Title scene — game start screen.
-- Shows game title + START / CONTINUE / SETTINGS buttons.
-- "CONTINUE" is enabled only when a saved expedition exists (hasSave).

local viewport = require("game.viewport")
local i18n = require("game.i18n")
local fonts = require("game.fonts")

local M = {}
M.__index = M

-- Button layout constants (720×1280 canvas)
M.buttonW = 360
M.buttonH = 64
M.buttonGap = 24
M.buttonStartY = 700  -- first button top

function M.new(options)
    options = options or {}
    return setmetatable({
        hasSave = options.hasSave or false,
        onStart = options.onStart,      -- callback: new game
        onContinue = options.onContinue, -- callback: continue
        onSettings = options.onSettings, -- callback: settings (stub)
        onLeaderboard = options.onLeaderboard, -- callback: leaderboard
        -- Background star field (simple)
        stars = M._generateStars(120),
        starTimer = 0,
    }, M)
end

function M._generateStars(count)
    local stars = {}
    for i = 1, count do
        stars[i] = {
            x = math.random() * 720,
            y = math.random() * 1280,
            brightness = 0.3 + math.random() * 0.7,
            size = math.random() < 0.2 and 2 or 1,
            twinkleSpeed = 0.5 + math.random() * 2,
        }
    end
    return stars
end

function M:buttonRects()
    local cx = viewport.width / 2
    local bx = cx - M.buttonW / 2
    local y = M.buttonStartY
    local rects = {}
    -- START
    rects.start = { x = bx, y = y, w = M.buttonW, h = M.buttonH }
    y = y + M.buttonH + M.buttonGap
    -- CONTINUE
    rects.continue_ = { x = bx, y = y, w = M.buttonW, h = M.buttonH }
    y = y + M.buttonH + M.buttonGap
    -- LEADERBOARD
    rects.leaderboard = { x = bx, y = y, w = M.buttonW, h = M.buttonH }
    y = y + M.buttonH + M.buttonGap
    -- SETTINGS
    rects.settings = { x = bx, y = y, w = M.buttonW, h = M.buttonH }
    return rects
end

function M:update(dt)
    self.starTimer = (self.starTimer or 0) + dt
end

function M:draw()
    -- Background
    love.graphics.clear(0.02, 0.02, 0.06, 1)

    -- Stars
    for _, star in ipairs(self.stars or {}) do
        local alpha = star.brightness * (0.5 + 0.5 * math.sin(self.starTimer * star.twinkleSpeed))
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end

    -- Title
    local titleFont = fonts.get(72)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(i18n.t("title_game_name"), 0, 300, viewport.width, "center")

    -- Subtitle
    local subFont = fonts.get(22)
    love.graphics.setFont(subFont)
    love.graphics.setColor(0.6, 0.7, 0.9, 0.7)
    love.graphics.printf("ROGUELITE", 0, 390, viewport.width, "center")

    -- Buttons
    local rects = self:buttonRects()
    local btnFont = fonts.get(32)
    love.graphics.setFont(btnFont)

    -- START button
    self:_drawButton(rects.start, i18n.t("title_start"), true)
    -- CONTINUE button (greyed out if no save)
    self:_drawButton(rects.continue_, i18n.t("title_continue"), self.hasSave)
    -- LEADERBOARD button
    self:_drawButton(rects.leaderboard, i18n.t("title_leaderboard"), true)
    -- SETTINGS button (stub, always enabled visually)
    self:_drawButton(rects.settings, i18n.t("title_settings"), true)
end

function M:_drawButton(rect, label, enabled)
    local alpha = enabled and 1 or 0.35
    -- Background
    love.graphics.setColor(0.08, 0.14, 0.22, 0.9 * alpha)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 10, 10)
    -- Border
    love.graphics.setColor(0.3, 0.6, 1, 0.8 * alpha)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 10, 10)
    -- Label
    love.graphics.setColor(1, 1, 1, 0.95 * alpha)
    love.graphics.printf(label, rect.x, rect.y + rect.h / 2 - 14, rect.w, "center")
end

function M:touchpressed(id, x, y)
    local rects = self:buttonRects()
    if self:_hitRect(rects.start, x, y) then
        if self.onStart then self.onStart() end
        return
    end
    if self.hasSave and self:_hitRect(rects.continue_, x, y) then
        if self.onContinue then self.onContinue() end
        return
    end
    -- Leaderboard
    if self:_hitRect(rects.leaderboard, x, y) then
        if self.onLeaderboard then self.onLeaderboard() end
        return
    end
    -- Settings: stub, do nothing for now
    if self:_hitRect(rects.settings, x, y) then
        if self.onSettings then self.onSettings() end
        return
    end
end

function M:_hitRect(rect, x, y)
    return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

function M:keypressed(key)
    if key == "return" or key == "space" then
        if self.onStart then self.onStart() end
    end
end

return M
