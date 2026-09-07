local M = {}

M.tracks = {
    "assets/sfx/title_bgm.mp3",
    "assets/sfx/observing_the_star.ogg"
}
M.currentIndex = 1
M.currentSource = nil
M.isPlaying = false

function M.start()
    if not love.audio or not love.audio.newSource then return end
    if M.isPlaying then return end
    M.isPlaying = true
    M.playTrack(M.currentIndex)
end

function M.playTrack(index)
    if not love.audio or not love.audio.newSource then return end
    if M.currentSource then
        M.currentSource:stop()
        M.currentSource = nil
    end
    
    local path = M.tracks[index]
    -- Check if file exists to avoid crash
    if love.filesystem and love.filesystem.getInfo then
        if not love.filesystem.getInfo(path, "file") then return end
    end
    
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok or not src then return end
    
    src:setLooping(false)
    src:setVolume(0.45)
    src:play()
    M.currentSource = src
end

function M.update()
    if not M.isPlaying or not M.currentSource then return end
    if not M.currentSource:isPlaying() then
        M.currentIndex = M.currentIndex + 1
        if M.currentIndex > #M.tracks then
            M.currentIndex = 1
        end
        M.playTrack(M.currentIndex)
    end
end

return M
