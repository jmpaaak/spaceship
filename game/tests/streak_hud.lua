local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    print("  [INBOX 67] streak HUD tests...")

    assert(type(PlayScene.streakHudLabel) == "function",
        "INBOX 67: streakHudLabel must be installed on PlayScene from play_hud.lua")
    assert(type(PlayScene.drawStreakHud) == "function",
        "INBOX 67: drawStreakHud must be installed on PlayScene from play_hud.lua")

    local hudSrc = love.filesystem.read("game/scenes/play_hud.lua") or ""
    assert(hudSrc:find("function PH.streakHudLabel", 1, true),
        "INBOX 67: streakHudLabel must live in play_hud.lua")
    assert(hudSrc:find("function PH.drawStreakHud", 1, true),
        "INBOX 67: drawStreakHud must live in play_hud.lua")
    assert(hudSrc:find("fonts.get(11)", 1, true),
        "INBOX 67: streak HUD must use Galmuri 11px")

    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(not playSrc:find("function PH.streakHudLabel", 1, true)
            and not playSrc:find("function M.streakHudLabel", 1, true),
        "INBOX 67: play.lua must not own streakHudLabel")
    assert(playSrc:find("drawStreakHud", 1, true),
        "INBOX 67: play.lua must one-line-delegate drawStreakHud")

    local drawSrc = love.filesystem.read("game/scenes/play_scene_draw.lua") or ""
    assert(drawSrc:find("self:drawStreakHud()", 1, true),
        "INBOX 67: play_scene_draw must call drawStreakHud under pause/help")

    -- Fresh run / streak 0 or 1 always shows x1.0 (never blank).
    local run = expedition.new({})
    run.phase = "ascending"
    assert(PlayScene.streakHudLabel(run) == "x1.0",
        "INBOX 67: streak 0 must show x1.0, got " .. tostring(PlayScene.streakHudLabel(run)))

    expedition.collectSample(run, 100, "solar")
    assert(run.sampleStreakCount == 1)
    assert(PlayScene.streakHudLabel(run) == "SOLAR x1.0",
        "INBOX 67: first solar sample must show SOLAR x1.0, got "
            .. tostring(PlayScene.streakHudLabel(run)))

    expedition.collectSample(run, 100, "solar")
    assert(run.sampleStreakCount == 2)
    assert(PlayScene.streakHudLabel(run) == "SOLAR x1.2",
        "INBOX 67: second solar sample must show SOLAR x1.2, got "
            .. tostring(PlayScene.streakHudLabel(run)))

    expedition.collectSample(run, 100, "solar")
    assert(PlayScene.streakHudLabel(run) == "SOLAR x1.4",
        "INBOX 67: third solar sample must show SOLAR x1.4, got "
            .. tostring(PlayScene.streakHudLabel(run)))

    expedition.collectSample(run, 100, "nebula")
    assert(PlayScene.streakHudLabel(run) == "NEBULA x1.0",
        "INBOX 67: hue switch must reset to NEBULA x1.0, got "
            .. tostring(PlayScene.streakHudLabel(run)))

    expedition.collectSample(run, 100, "void")
    assert(PlayScene.streakHudLabel(run) == "VOID x1.0",
        "INBOX 67: void family must use VOID, got "
            .. tostring(PlayScene.streakHudLabel(run)))

    expedition.collectSample(run, 100, "pulsar")
    assert(PlayScene.streakHudLabel(run) == "PULSAR x1.0",
        "INBOX 67: pulsar family must use PULSAR, got "
            .. tostring(PlayScene.streakHudLabel(run)))

    -- Label must use expedition.streakMultiplier(sampleStreakCount, run).
    local expected = expedition.streakMultiplier(run.sampleStreakCount, run)
    local formatted = string.format("x%.1f", expected)
    assert(PlayScene.streakHudLabel(run):find(formatted, 1, true),
        "INBOX 67: label must include expedition.streakMultiplier value " .. formatted)

    print("  INBOX 67 streak HUD OK")
end

return M
