local PlayScene = require("game.scenes.play")

local M = {}

function M.run(riskScene)
    -- (17a) devPlaceholder footer has been fully removed.
    assert(PlayScene.devPlaceholderFontSize == nil,
        "devPlaceholderFontSize must be removed (item 17a)")
    assert(PlayScene.devPlaceholderAlpha == nil,
        "devPlaceholderAlpha must be removed (item 17a)")
    -- Item 41: HUD font unified to 22px across all phases (launch = ascending).
    assert(PlayScene.hudFontSize and PlayScene.hudFontSize == 22,
        "hudFontSize must be 22px after item 41 unification: " .. tostring(PlayScene.hudFontSize))
    assert(PlayScene.hudLineStep and PlayScene.hudLineStep >= 26 and PlayScene.hudLineStep <= 34,
        "hudLineStep must be 26-34px after item 41: " .. tostring(PlayScene.hudLineStep))
    assert(PlayScene.hudGalaxyShift and PlayScene.hudGalaxyShift >= 26 and PlayScene.hudGalaxyShift <= 34,
        "hudGalaxyShift must be 26-34px after item 41: " .. tostring(PlayScene.hudGalaxyShift))

    riskScene.expedition.phase = "settlement"
    -- Item 11: slot count (S%02d) is always 0 since item-15 abolished
    -- in-flight slots; the "S00" segment is dead/misleading UI that implies
    -- a slot mechanic still exists. Remove it from all non-launch phases so
    -- hud_status no longer references slotOpportunities at all.
    assert(riskScene:hudLines().status == "H3/3 SETTLE",
        "item-11: settlement-phase HUD status must not show dead S00 slot segment: "
        .. tostring(riskScene:hudLines().status))
    assert(not riskScene:hudLines().status:find("S%d%d"),
        "item-11: no phase must show dead slot-count segment after item-15 abolition")
    assert(not riskScene:hudLines().status:find("F%d"),
        "hud status must not show a misleading fuel-cap readout")
    -- Item 11: launch phase now also uses hud_status_no_slots (same format as
    -- all other phases) — the old per-phase conditional was removed since
    -- S%02d (slotOpportunities) is always 0 and the entire field is dead.
    riskScene.expedition.phase = "launch"
    assert(riskScene:hudLines().status == "H3/3 LAUNCH",
        "launch-phase status must not show a slot count segment: "
        .. tostring(riskScene:hudLines().status))
    assert(not riskScene:hudLines().status:find("S%d%d"),
        "launch-phase status must not show a slot count segment")
    riskScene.expedition.phase = "ascending"
    local ascendingHud = riskScene:hudLines()
    -- (17b) samples HUD line removed; only distance, cash, status remain in ascending.
    assert(ascendingHud.samples == nil,
        "hudLines().samples must be nil after item 17b removal")
    -- "고도(ALT)" -> "거리(DIST)" relabel (docs/feedback/INBOX.md item 2,
    -- 2026-09-03): the user misread the ALT/CASH line + adjacent fuel
    -- status line as "fuel gates altitude". hud_distance must no longer say
    -- ALT, and drawing the status line must leave an explicit gap
    -- (PlayScene.hudPrimaryStatusGap) below the distance line so the fuel
    -- gauge visually separates from the distance-from-Earth readout.
    -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
    -- third slice): the CASH readout gets a small coin icon paired with it,
    -- mirroring the shield icon added for hull durability. hudLines() must
    -- expose the DIST and CASH segments separately (instead of one combined
    -- "primary" string) so draw() can insert the coin icon between them.
    assert(ascendingHud.distance:match("^DIST %d") ~= nil,
        "hudLines().distance must read DIST: " .. tostring(ascendingHud.distance))
    assert(not ascendingHud.distance:find("ALT"),
        "hudLines().distance must not contain the old ALT label: "
        .. tostring(ascendingHud.distance))
    assert(ascendingHud.cash:match("^CASH %$%d") ~= nil,
        "hudLines().cash must read CASH $N: " .. tostring(ascendingHud.cash))
    assert(PlayScene.hudPrimaryStatusGap and PlayScene.hudPrimaryStatusGap > 0,
        "PlayScene.hudPrimaryStatusGap must exist and separate DIST/CASH from the fuel status line")
    -- Item 41: one stat per line. Ascending with galaxy + best (always shown) =
    -- 5 lines (galaxy, dist, cash, status, best) → 4 + 5*30 = 154.
    assert(PlayScene.hudHeight("ascending", ascendingHud, 0) == 154,
        "ascending HUD band height must be 154 after item 41: "
        .. tostring(PlayScene.hudHeight("ascending", ascendingHud, 0)))
    -- Without galaxy, without best: 3 lines (dist, cash, status) → 4 + 3*30 = 94.
    local noGalaxyHud = { distance = "DIST 0", cash = "CASH $0", status = "H3/3 ASC" }
    assert(PlayScene.hudHeight("ascending", noGalaxyHud, 0) == 94,
        "ascending HUD (no galaxy) height must be 94: "
        .. tostring(PlayScene.hudHeight("ascending", noGalaxyHud, 0)))
    -- With galaxy + best: 5 lines → 4 + 5*30 = 154.
    local fullHud = { distance = "DIST 0", cash = "CASH $0", status = "H3/3 LAUNCH",
        galaxy = "SOLAR SYSTEM", best = "RECORD 0" }
    assert(PlayScene.hudHeight("launch", fullHud, 0) == 154,
        "launch HUD (galaxy+best) height must be 154: "
        .. tostring(PlayScene.hudHeight("launch", fullHud, 0)))

    -- Item 38d: best record must be visible in ascending phase too.
    assert(ascendingHud.best ~= nil,
        "item 38d: hudLines().best must be non-nil during ascending phase")
    assert(ascendingHud.best:find("RECORD") ~= nil,
        "item 38d: ascending best line must contain 'RECORD': " .. tostring(ascendingHud.best))

    -- Item 38c: durability HP block rendering constants must exist.
    assert(PlayScene.hpBlockSize and PlayScene.hpBlockSize >= 10,
        "item 38c: hpBlockSize must exist and be >= 10px: " .. tostring(PlayScene.hpBlockSize))
    assert(PlayScene.hpBlockGap and PlayScene.hpBlockGap >= 2,
        "item 38c: hpBlockGap must exist and be >= 2px: " .. tostring(PlayScene.hpBlockGap))

    -- Item 41: ascending with galaxy + best = 5 lines → 4 + 5*30 = 154.
    assert(PlayScene.hudHeight("ascending", ascendingHud, 0) == 154,
        "item 41: ascending HUD with galaxy+best must be 154: "
        .. tostring(PlayScene.hudHeight("ascending", ascendingHud, 0)))

    assert(ascendingHud.earth == nil)
    assert(ascendingHud.returnProgress == nil)

    -- Item 21: HUD distance must show euclidean distance from Earth center,
    -- not the virtual run.altitude.
    local distScene21 = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    distScene21.expedition.phase = "ascending"
    distScene21.expedition.altitude = 9999  -- internal altitude differs from ship position
    distScene21.ship.x = 300
    distScene21.ship.y = 75 - 400  -- earthCenterY=75, so dy=-400
    -- euclidean = sqrt(300^2 + 400^2) = 500
    local hud21 = distScene21:hudLines()
    assert(hud21.distance == "DIST 500",
        "item-21: HUD distance must show euclidean distance from Earth (expected 'DIST 500', got '"
        .. tostring(hud21.distance) .. "')")
end

return M
