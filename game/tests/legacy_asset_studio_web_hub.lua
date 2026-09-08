local M = {}

-- INBOX (61)(1): local static asset-studio hub (gear-editor pattern).
-- Characterizes file presence, pipeline labels, blocked user-supplied kinds,
-- and the no-ComfyUI rule without touching play.lua.
function M.run()
    local html = love.filesystem.read("tools/asset-studio/index.html")
    local css = love.filesystem.read("tools/asset-studio/editor.css")
    local js = love.filesystem.read("tools/asset-studio/editor.js")
    assert(html, "INBOX 61(1): tools/asset-studio/index.html must exist")
    assert(css, "INBOX 61(1): tools/asset-studio/editor.css must exist")
    assert(js, "INBOX 61(1): tools/asset-studio/editor.js must exist")
    assert(html:find("Asset Studio", 1, true),
        "asset-studio HTML must title the Asset Studio")
    assert(js:find("sprite-gen", 1, true),
        "asset-studio JS must name the sprite-gen stage")
    assert(js:find("PerfectPixel", 1, true) or js:find("perfectPixel", 1, true),
        "asset-studio JS must name the PerfectPixel stage")
    assert(js:find("NEAREST", 1, true) and js:find("4px", 1, true),
        "asset-studio JS must apply chunky 4px NEAREST")
    assert(js:find("GENERATED_ASSET_LOG", 1, true),
        "asset-studio JS must write GENERATED_ASSET_LOG lines")
    assert(js:find("MANIFEST.json", 1, true),
        "asset-studio JS must emit MANIFEST.json entries")
    assert(js:find("upload", 1, true) and js:find("prompt", 1, true),
        "asset-studio JS must accept upload/URL/prompt sources")
    assert(js:find("assets/ship/", 1, true) and js:find("assets/earth/", 1, true),
        "asset-studio JS must block user-supplied ship/earth paths")
    assert(not js:find("ComfyUI", 1, true) and not html:find("ComfyUI", 1, true),
        "asset-studio must not use ComfyUI")
    print("  INBOX-61(1) asset-studio web hub OK")
end

return M