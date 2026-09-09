-- INBOX (71): Credits / 만든이 scene. Title-only; play.lua must not own this.
-- Body: role, contact, engine/font, reused title_bgm_credit. Back returns to title.

local viewport = require("game.viewport")
local i18n = require("game.i18n")
local fonts = require("game.fonts")

local M = {}
M.__index = M

M.backButtonW = 200
M.backButtonH = 56
M.backButtonY = 1180
M.bodyStartY = 280
M.bodyGap = 56

function M.new(options)
    options = options or {}
    return setmetatable({
        onBack = options.onBack,
    }, M)
end

function M.bodyLines()
    return {
        i18n.t("credits_role"),
        i18n.t("credits_contact"),
        i18n.t("credits_engine"),
        i18n.t("title_bgm_credit"),
    }
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
    love.graphics.clear(0.02, 0.02, 0.06, 1)

    local titleFont = fonts.get(48)
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(i18n.t("credits_title"), 0, 60, viewport.width, "center")

    local bodyFont = fonts.get(24)
    love.graphics.setFont(bodyFont)
    local y = M.bodyStartY
    for _, line in ipairs(self:bodyLines()) do
        love.graphics.setColor(0.85, 0.88, 0.95, 1)
        love.graphics.printf(line, 40, y, viewport.width - 80, "center")
        y = y + M.bodyGap
    end

    local rect = self:backButtonRect()
    love.graphics.setColor(0.08, 0.14, 0.22, 0.9)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 10, 10)
    love.graphics.setColor(0.3, 0.6, 1, 0.8)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 10, 10)
    local btnFont = fonts.get(28)
    love.graphics.setFont(btnFont)
    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(i18n.t("credits_back"), rect.x, rect.y + rect.h / 2 - 12, rect.w, "center")
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
