-- INBOX 61(36): SFX 3종 — galaxy_discover, star_sample (loop), collision (oneshot).
-- Standalone module (play.lua에 붙이지 말 것). Headless-safe: all ops are no-ops
-- when love.audio is nil.
local M = {}

-- Registered sound effect definitions: name → { path, loop }
M.defs = {
    galaxy_discover = { path = "assets/sfx/galaxy_discover.mp3", loop = false },
    star_sample     = { path = "assets/sfx/star_sample.mp3",     loop = true  },
    collision       = { path = "assets/sfx/collision.mp3",       loop = false },
    collect         = { path = "assets/sfx/collect.mp3",         loop = false },
    slot_spin       = { path = "assets/sfx/slot_spin.ogg",       loop = false },
    boost           = { path = "assets/sfx/boost.ogg",           loop = false },
}

-- Runtime sources (lazily created): name → love.Source
M.sources = {}

-- Per-session one-shot guards: name → true (for galaxy_discover per galaxy)
M.played = {}

local function hasAudio()
    return love and love.audio and love.audio.newSource
end

local function getSource(name)
    if not hasAudio() then return nil end
    if M.sources[name] then return M.sources[name] end
    local def = M.defs[name]
    if not def then return nil end
    -- Verify file exists
    if love.filesystem and love.filesystem.getInfo then
        if not love.filesystem.getInfo(def.path, "file") then return nil end
    end
    local ok, src = pcall(love.audio.newSource, def.path, "static")
    if not ok or not src then return nil end
    src:setLooping(def.loop == true)
    src:setVolume(0.6)
    M.sources[name] = src
    return src
end

--- INBOX (53): home / start galaxy is not a discovery. Skip milkyway and (0,0).
function M.playGalaxyDiscover(galaxy)
    if not galaxy then return end
    local id = galaxy.id
    local gx, gy = galaxy.gx or 0, galaxy.gy or 0
    if id == "milkyway" or id == "galaxy:0:0" or (gx == 0 and gy == 0) then
        return
    end
    M.play("galaxy_discover", id)
end

--- Play a one-shot SFX. For galaxy_discover, pass a unique key to avoid repeats.
--- @param name string  One of: "galaxy_discover", "star_sample", "collision"
--- @param uniqueKey string|nil  Optional dedup key (e.g. galaxyId for galaxy_discover)
--- @param volume number|nil  Optional volume (default 0.6). Debris uses 0.9 (1.5x).
function M.play(name, uniqueKey, volume)
    if uniqueKey then
        local guardKey = name .. ":" .. tostring(uniqueKey)
        if M.played[guardKey] then return end
        M.played[guardKey] = true
    end
    local vol = volume or 0.6
    M.lastVolume = vol
    local src = getSource(name)
    if not src then return end
    if src:isPlaying() and not M.defs[name].loop then
        src:stop()
    end
    src:setVolume(vol)
    src:play()
end

--- Stop a looping SFX (e.g. star_sample when leaving the well).
function M.stop(name)
    local src = M.sources[name]
    if src and src:isPlaying() then
        src:stop()
    end
end

--- Check if a named SFX is currently playing.
function M.isPlaying(name)
    local src = M.sources[name]
    return src ~= nil and src:isPlaying()
end

--- Reset one-shot guards (call on new expedition).
function M.resetGuards()
    M.played = {}
    M.lastVolume = nil
end

--- Release all sources (cleanup).
function M.releaseAll()
    for name, src in pairs(M.sources) do
        if src:isPlaying() then src:stop() end
        src:release()
    end
    M.sources = {}
    M.played = {}
    M.lastVolume = nil
end

return M
