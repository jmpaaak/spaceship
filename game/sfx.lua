local M = {}

M.sounds = {
    galaxy_discover = "assets/sfx/galaxy_discover.mp3",
    star_sample     = "assets/sfx/star_sample.mp3",
    collision       = "assets/sfx/collision.mp3",
}

-- Loaded love.audio.Source objects, keyed by name.
local sources = {}

function M.init()
    if not love.audio or not love.audio.newSource then return end
    for name, path in pairs(M.sounds) do
        if love.filesystem and love.filesystem.getInfo then
            if not love.filesystem.getInfo(path, "file") then
                -- Skip missing asset gracefully.
                goto continue
            end
        end
        local kind = (name == "galaxy_discover") and "stream" or "static"
        local ok, src = pcall(love.audio.newSource, path, kind)
        if ok and src then
            sources[name] = src
        end
        ::continue::
    end
end

-- Play a sound once (one-shot).
function M.play(name)
    if not love.audio then return end
    local src = sources[name]
    if not src then return end
    src:stop()
    src:setLooping(false)
    src:play()
end

-- Start looping a sound.
function M.loop(name)
    if not love.audio then return end
    local src = sources[name]
    if not src then return end
    src:setLooping(true)
    if not src:isPlaying() then
        src:play()
    end
end

-- Stop a sound.
function M.stop(name)
    if not love.audio then return end
    local src = sources[name]
    if not src then return end
    src:stop()
end

return M
