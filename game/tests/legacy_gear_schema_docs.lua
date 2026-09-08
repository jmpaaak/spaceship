local M = {}

-- docs/feedback/INBOX.md item 13 follow-up (named next slice after the
-- web-editor galaxyExclusive round-trip): GEAR_SCHEMA.md's Card-shape
-- table is the author-facing contract for hull_parts.json /
-- engine_parts.json. Item 7 added `galaxyExclusive` to validatePart /
-- earthShopPool / exploreHub, and the editor now round-trips it, but the
-- schema table + example JSON still omit the field — so an author reading
-- the documented card shape would never know the flag exists and could
-- not add a new galaxy-exclusive card from the spec alone. This test
-- locks the Card-shape section (not a later follow-up note) so the field
-- cannot silently drop out of the published schema again.
function M.run()
    local schemaSrc = love.filesystem.read("docs/GEAR_SCHEMA.md")
    assert(schemaSrc, "docs/GEAR_SCHEMA.md must be readable for the schema-table check")

    local cardStart = schemaSrc:find("## Card shape", 1, true)
    assert(cardStart, "GEAR_SCHEMA.md must have a Card shape section")
    local effectStart = schemaSrc:find("## Effect shape", cardStart, true)
    assert(effectStart, "GEAR_SCHEMA.md Card shape must be followed by Effect shape")
    local cardSection = schemaSrc:sub(cardStart, effectStart - 1)

    assert(cardSection:find('"galaxyExclusive"', 1, true),
        "GEAR_SCHEMA.md Card-shape example JSON must include galaxyExclusive so authors see the field")
    assert(cardSection:find("`galaxyExclusive`", 1, true),
        "GEAR_SCHEMA.md Card-shape field table must document `galaxyExclusive`")
    assert(cardSection:find("earthShopPool", 1, true) or cardSection:find("Earth shop", 1, true),
        "GEAR_SCHEMA.md galaxyExclusive notes must mention Earth-shop exclusion")
    assert(cardSection:find("exploreHub", 1, true) or cardSection:find("hub", 1, true),
        "GEAR_SCHEMA.md galaxyExclusive notes must mention hub-drop acquisition")
end

return M
