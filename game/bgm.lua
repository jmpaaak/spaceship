local M = {}

-- INBOX 61(42): one Space orchestral loop for the whole game (no playlist).
M.tracks = {
    "assets/sfx/space_orchestral.mp3",
}
M.looping = true
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
    if love.filesystem and love.filesystem.getInfo then
        if not love.filesystem.getInfo(path, "file") then return end
    end

    local ok, src = pcall(love.audio.newSource, path, "stream")
    if not ok or not src then return end

    src:setLooping(M.looping == true)
    src:setVolume(0.45)
    src:play()
    M.currentSource = src
end

function M.update()
    if not M.isPlaying or not M.currentSource then return end
    if M.looping then return end
    if not M.currentSource:isPlaying() then
        M.currentIndex = M.currentIndex + 1
        if M.currentIndex > #M.tracks then
            M.currentIndex = 1
        end
        M.playTrack(M.currentIndex)
    end
end

return M
