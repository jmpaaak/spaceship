local M = {}

-- INBOX (71): title Credits / 만든이 menu.
function M.run()
    print("  [INBOX 71] credits menu tests...")

    local i18n = require("game.i18n")
    local TitleScene = require("game.scenes.title")

    -- (a) i18n: KO 만든이 / EN CREDITS, body lines, back.
    i18n.setLocale("en")
    assert(i18n.t("title_credits") == "CREDITS",
        "INBOX 71: EN title_credits must be CREDITS, got " .. tostring(i18n.t("title_credits")))
    assert(i18n.t("credits_title") == "CREDITS",
        "INBOX 71: EN credits_title must be CREDITS")
    i18n.setLocale("ko")
    assert(i18n.t("title_credits") == "만든이",
        "INBOX 71: KO title_credits must be 만든이, got " .. tostring(i18n.t("title_credits")))
    assert(i18n.t("credits_title") == "만든이",
        "INBOX 71: KO credits_title must be 만든이")
    assert(i18n.t("credits_role") == "기획 · 개발",
        "INBOX 71: KO credits_role must be 기획 · 개발")
    assert(i18n.t("credits_contact") == "jmpaxk@gmail.com (jimmy)",
        "INBOX 71: contact must be jmpaxk@gmail.com (jimmy)")
    assert(i18n.t("credits_engine"):find("LÖVE 11.5", 1, true),
        "INBOX 71: engine line must mention LÖVE 11.5")
    assert(i18n.t("credits_engine"):find("Galmuri", 1, true),
        "INBOX 71: engine line must mention Galmuri")
    i18n.setLocale("en")
    assert(i18n.t("credits_contact") == "jmpaxk@gmail.com (jimmy)",
        "INBOX 71: EN contact must keep jmpaxk@gmail.com (jimmy)")
    assert(i18n.t("credits_engine"):find("LÖVE 11.5", 1, true),
        "INBOX 71: EN engine line must mention LÖVE 11.5")
    assert(i18n.t("credits_engine"):find("Galmuri", 1, true),
        "INBOX 71: EN engine line must mention Galmuri")
    for _, loc in ipairs({ "en", "ko" }) do
        i18n.setLocale(loc)
        for _, key in ipairs({
            "title_credits", "credits_title", "credits_role",
            "credits_contact", "credits_engine", "credits_back",
        }) do
            assert(i18n.t(key) ~= key,
                "INBOX 71: i18n key '" .. key .. "' missing for locale " .. loc)
        end
    end
    i18n.setLocale("en")

    -- (b) Title 5th button under SETTINGS.
    local title = TitleScene.new({
        hasSave = false,
        onCredits = function() end,
    })
    local rects = title:buttonRects()
    assert(rects.credits, "INBOX 71: TitleScene:buttonRects must include credits")
    assert(rects.settings, "INBOX 71: settings rect must remain")
    assert(rects.credits.y > rects.settings.y,
        "INBOX 71: CREDITS must sit below SETTINGS")

    -- (c) tapping credits fires onCredits
    local creditsCalled = false
    local title2 = TitleScene.new({
        hasSave = false,
        onCredits = function() creditsCalled = true end,
    })
    local cRect = title2:buttonRects().credits
    title2:touchpressed("test", cRect.x + 1, cRect.y + 1)
    assert(creditsCalled, "INBOX 71: tapping CREDITS must call onCredits")

    -- (d) CreditsScene lives in game/scenes/credits.lua, not play.lua
    local CreditsScene = require("game.scenes.credits")
    assert(type(CreditsScene.new) == "function",
        "INBOX 71: game.scenes.credits must expose new()")
    assert(type(CreditsScene.bodyLines) == "function"
            or type(CreditsScene.new({}).bodyLines) == "function",
        "INBOX 71: CreditsScene must expose bodyLines")

    local playSrc = love.filesystem.read("game/scenes/play.lua") or ""
    assert(not playSrc:find("credits", 1, true),
        "INBOX 71: play.lua must not own the credits menu")

    local creditsSrc = love.filesystem.read("game/scenes/credits.lua") or ""
    assert(creditsSrc:find("title_bgm_credit", 1, true),
        "INBOX 71: credits scene must reuse title_bgm_credit")
    assert(creditsSrc:find("jmpaxk@gmail.com (jimmy)", 1, true)
            or creditsSrc:find("credits_contact", 1, true),
        "INBOX 71: credits scene must show contact")

    -- (e) body lines: role, mail (jimmy), engine, BGM credit
    i18n.setLocale("ko")
    local backCalled = false
    local scene = CreditsScene.new({
        onBack = function() backCalled = true end,
    })
    local lines = scene.bodyLines and scene:bodyLines() or CreditsScene.bodyLines()
    local joined = table.concat(lines, "\n")
    assert(joined:find("기획 · 개발", 1, true),
        "INBOX 71: body must include 기획 · 개발")
    assert(joined:find("jmpaxk@gmail.com (jimmy)", 1, true),
        "INBOX 71: body must include jmpaxk@gmail.com (jimmy)")
    assert(joined:find("LÖVE 11.5", 1, true),
        "INBOX 71: body must include LÖVE 11.5")
    assert(joined:find("Galmuri", 1, true),
        "INBOX 71: body must include Galmuri")
    assert(joined:find(i18n.t("title_bgm_credit"), 1, true),
        "INBOX 71: body must reuse title_bgm_credit")

    -- (f) back touch + escape return to title
    assert(scene.backButtonRect, "INBOX 71: CreditsScene must have backButtonRect")
    local backRect = scene:backButtonRect()
    scene:touchpressed("test", backRect.x + 1, backRect.y + 1)
    assert(backCalled, "INBOX 71: tapping back must call onBack")

    local backCalled2 = false
    local scene2 = CreditsScene.new({
        onBack = function() backCalled2 = true end,
    })
    scene2:keypressed("escape")
    assert(backCalled2, "INBOX 71: escape must call onBack")

    -- (g) main.lua wires CreditsScene + onCredits, not play.lua
    local mainSrc = love.filesystem.read("main.lua") or ""
    assert(mainSrc:find('require("game.scenes.credits")', 1, true),
        "INBOX 71: main.lua must require game.scenes.credits")
    assert(mainSrc:find("onCredits", 1, true),
        "INBOX 71: main.lua must wire onCredits")
    assert(mainSrc:find("CreditsScene", 1, true),
        "INBOX 71: main.lua must switch to CreditsScene")

    i18n.setLocale("en")
    print("  INBOX-71 credits menu OK")
end

return M
