-- INBOX 61(21)+61(24b): Title scene — game start screen.
-- Menu: CONTINUE / NEW GAME / LEADERBOARD / SETTINGS.
-- "CONTINUE" is enabled only when a saved expedition exists (hasSave).
-- "NEW GAME" = full reset (bestAltitude, specimens, money, upgrades, checkpoint).

local viewport = require("game.viewport")
local i18n = require("game.i18n")
local fonts = require("game.fonts")

local M = {}
local bgm = require("game.bgm")
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
        onNewGame = options.onNewGame,        -- callback: full reset + start
        onContinue = options.onContinue,      -- callback: resume last checkpoint
        onSettings = options.onSettings,      -- callback: settings (stub)
        onLeaderboard = options.onLeaderboard, -- callback: leaderboard
        -- Legacy compat: onStart maps to onNewGame
        onStart = options.onStart,
        -- Background star field (simple)
        stars = M._generateStars(120),
        starTimer = 0,
        shipImage = nil,
        shipIdleTime = 0,
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

-- INBOX (49): starter ship sits large, nearest, centered above Jimmy's (y=488).
function M.shipLayout(iw, ih)
    iw = iw or 64
    ih = ih or 64
    local scale = 7
    local w = iw * scale
    local h = ih * scale
    return {
        path = "assets/ship/ship_default.png",
        filter = "nearest",
        scale = scale,
        x = (viewport.width - w) / 2,
        y = 488 - h - 24,
        w = w,
        h = h,
    }
end

-- INBOX (52): slight diagonal tilt + slow bob + tiny left-right sway.
-- Rotation stays within ±8°. Asset path and nearest scale are unchanged.
function M.shipIdlePose(t)
    t = t or 0
    local tiltAmp = 7 * math.pi / 180
    return {
        angle = math.sin(t * 0.55) * tiltAmp,
        ox = math.sin(t * 0.7) * 3,
        oy = math.sin(t * 1.1) * 8,
    }
end

function M:buttonRects()
    local cx = viewport.width / 2
    local bx = cx - M.buttonW / 2
    local y = M.buttonStartY
    local rects = {}
    -- CONTINUE (top — primary action when save exists)
    rects.continue_ = { x = bx, y = y, w = M.buttonW, h = M.buttonH }
    y = y + M.buttonH + M.buttonGap
    -- NEW GAME (was "start")
    rects.newGame = { x = bx, y = y, w = M.buttonW, h = M.buttonH }
    -- Keep legacy alias for existing tests
    rects.start = rects.newGame
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
    self.shipIdleTime = (self.shipIdleTime or 0) + dt
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

    -- Starter ship above Jimmy's (INBOX 49: large, nearest, centered)
    if not self.shipImage and love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, "assets/ship/ship_default.png")
        if ok and img then
            img:setFilter("nearest", "nearest")
            self.shipImage = img
        end
    end
    if self.shipImage then
        local iw, ih = self.shipImage:getWidth(), self.shipImage:getHeight()
        local layout = M.shipLayout(iw, ih)
        local pose = M.shipIdlePose(self.shipIdleTime or 0)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.shipImage,
            layout.x + layout.w / 2 + pose.ox,
            layout.y + layout.h / 2 + pose.oy,
            pose.angle,
            layout.scale, layout.scale,
            iw / 2, ih / 2)
    end

    -- Author credit (Sid Meier's Civilization style): small grey above title
    local authorFont = fonts.get(22)
    love.graphics.setFont(authorFont)
    love.graphics.setColor(0.55, 0.55, 0.58, 0.85)
    love.graphics.printf(i18n.t("title_author"), 0, 488, viewport.width, "center")

    -- Title — lower, closer to the menu (user 2026-09-07)
    local titleFont = fonts.get(44)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(i18n.t("title_game_name"), 0, 520, viewport.width, "center")

    -- Buttons
    local rects = self:buttonRects()
    local btnFont = fonts.get(32)
    love.graphics.setFont(btnFont)

    -- CONTINUE button (greyed out if no save)
    self:_drawButton(rects.continue_, i18n.t("title_continue"), self.hasSave)
    -- NEW GAME button
    self:_drawButton(rects.newGame, i18n.t("title_new_game"), true)
    -- LEADERBOARD button
    self:_drawButton(rects.leaderboard, i18n.t("title_leaderboard"), true)
    -- SETTINGS button (stub, always enabled visually)
    self:_drawButton(rects.settings, i18n.t("title_settings"), true)

    love.graphics.setFont(fonts.get(11))
    love.graphics.setColor(0.55, 0.55, 0.58, 0.7)
    love.graphics.printf(i18n.t("title_bgm_credit"), 8, viewport.height - 28, viewport.width - 16, "center")
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
    -- iOS/Love2D Studio: AudioContext is locked until a user gesture.
    -- Retry BGM here so the first tap (even a miss) unlocks playback.
    bgm.start()
    local rects = self:buttonRects()
    -- Continue (only if save exists)
    if self.hasSave and self:_hitRect(rects.continue_, x, y) then
        if self.onContinue then self.onContinue() end
        return
    end
    -- New Game
    if self:_hitRect(rects.newGame, x, y) then
        local handler = self.onNewGame or self.onStart
        if handler then handler() end
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
    bgm.start()
    if key == "return" or key == "space" then
        local handler = self.onNewGame or self.onStart
        if handler then handler() end
    end
end

function M:enter()
    bgm.start()
end

return M
