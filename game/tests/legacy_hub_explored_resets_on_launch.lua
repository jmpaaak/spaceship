local M = {}

-- Item 7(b)/8: hub exploration state must reset on each new expedition so
-- hubs can be re-explored for gear drops on subsequent safe runs. `destroy()`
-- already resets hubExplored / lastVisitedGalaxyId as part of the full meta
-- wipe; the gap is `launch()` (safe relaunch from settlement): without the
-- reset, a player who safely returns from an expedition keeps their hubExplored
-- map, which prevents `exploreHub` from firing on the same galaxy again next
-- run, silently starving them of hub drops they should legitimately earn.
-- lastVisitedGalaxyId should also clear at launch because the Earth shop slot
-- spin (which reads it) always occurs BEFORE the next launch, so a new
-- expedition has no "last visited galaxy" yet.
function M.run()
    local expedition = require("game.expedition")

    -- Explore a hub on the first expedition, then complete a safe return.
    local exPart = {
        id = "test_hub_exclusive", name = "HubEx", nameKo = "허브전용", icon = "▲",
        rarity = "rare", tags = { "altitude" }, editions = {}, galaxyExclusive = true,
        effects = { { type = "speed", value = 3 } },
    }
    local run = expedition.new()
    expedition.launch(run)
    -- First expedition: explore the hub.
    local drop = expedition.exploreHub(run, "andromeda", { exPart })
    assert(drop ~= nil, "first hub exploration must yield a gear drop")
    assert(run.hubExplored["andromeda"] == true,
        "hubExplored must record the visited galaxy after exploreHub")
    assert(run.lastVisitedGalaxyId == "andromeda",
        "lastVisitedGalaxyId must be set after exploreHub")

    -- A second exploreHub call on the same galaxy this expedition must be refused.
    local drop2 = expedition.exploreHub(run, "andromeda", { exPart })
    assert(drop2 == nil, "duplicate exploreHub in same expedition must return nil")

    -- Simulate safe return: altitude to 0 drives settle() inside update().
    run.phase = "ascending"
    expedition.settle(run)



    assert(run.phase == "settlement",
        "update must drive returning run to settlement")

    -- Relaunch for the second expedition.
    local ok = expedition.launch(run)
    assert(ok, "launch from settlement must succeed")
    assert(run.phase == "ascending")

    -- After relaunch, hubExplored must be empty so the player can earn the
    -- andromeda hub drop again this expedition.
    assert(run.hubExplored["andromeda"] == nil,
        "hubExplored must be nil for every galaxy after a safe relaunch "
        .. "(was " .. tostring(run.hubExplored["andromeda"]) .. ")")

    -- lastVisitedGalaxyId must also be nil after launch (the new expedition
    -- hasn't visited any hub yet, and the Earth shop slot spin for the
    -- previous settlement already used the old value).
    assert(run.lastVisitedGalaxyId == nil,
        "lastVisitedGalaxyId must be nil after launch from settlement "
        .. "(was " .. tostring(run.lastVisitedGalaxyId) .. ")")

    -- Verify the drop works again on the second expedition (the regression target).
    local drop3 = expedition.exploreHub(run, "andromeda", { exPart })
    assert(drop3 ~= nil,
        "hub exploration must yield a drop again on a subsequent expedition after safe relaunch")

    -- Ensure destroy() still resets the same fields (regression safety for
    -- the existing path, not new behavior).
    local run2 = expedition.new()
    expedition.launch(run2)
    expedition.exploreHub(run2, "triangulum", { exPart })
    assert(run2.hubExplored["triangulum"] == true)
    run2.durability = 1
    expedition.damage(run2, 5) -- lethal -> destroy()
    assert(run2.phase == "destroyed")
    assert(run2.hubExplored["triangulum"] == nil,
        "destroy() must also reset hubExplored (regression)")
    assert(run2.lastVisitedGalaxyId == nil,
        "destroy() must also reset lastVisitedGalaxyId (regression)")
end

return M
