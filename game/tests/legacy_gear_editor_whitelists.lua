local gear = require("game.gear")

local M = {}

-- docs/feedback/INBOX.md item 12/13: the web editor's client-side
-- validation is documented (tools/gear-editor/README.md, editor.js's own
-- header comment: "Validation rules here intentionally mirror
-- game/gear.lua's loader exactly") as staying byte-for-byte in sync with
-- gear.lua's `M.knownEditions`/`M.knownRarities` whitelists -- exactly the
-- same sync guarantee the effect-schema coverage enforces for
-- `M.knownEffectTypes`/`EFFECT_TYPE_GROUPS`.
function M.run()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")

    local editionsStart = editorSrc:find("KNOWN_EDITIONS%s*=%s*%[")
    assert(editionsStart, "editor.js must define a KNOWN_EDITIONS array")
    local editionsEnd = editorSrc:find("%]", editionsStart)
    local editionsBlock = editorSrc:sub(editionsStart, editionsEnd)
    for edition, _ in pairs(gear.knownEditions) do
        assert(editionsBlock:find('"' .. edition .. '"', 1, true),
            "editor.js KNOWN_EDITIONS must include '" .. edition .. "' to stay in sync with gear.lua")
    end

    local raritiesStart = editorSrc:find("KNOWN_RARITIES%s*=%s*%[")
    assert(raritiesStart, "editor.js must define a KNOWN_RARITIES array")
    local raritiesEnd = editorSrc:find("%]", raritiesStart)
    local raritiesBlock = editorSrc:sub(raritiesStart, raritiesEnd)
    for rarity, _ in pairs(gear.knownRarities) do
        assert(raritiesBlock:find('"' .. rarity .. '"', 1, true),
            "editor.js KNOWN_RARITIES must include '" .. rarity .. "' to stay in sync with gear.lua")
    end
end

return M
