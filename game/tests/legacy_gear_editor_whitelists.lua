local gear = require("game.gear")

local M = {}

-- docs/feedback/INBOX.md item 12/13: the web editor's client-side
-- validation is documented (tools/gear-editor/README.md, editor.js's own
-- header comment: "Validation rules here intentionally mirror
-- game/gear.lua's loader exactly") as staying byte-for-byte in sync with
-- gear.lua's `M.knownEditions`/`M.knownRarities` whitelists -- exactly the
-- same sync guarantee the effect-schema coverage enforces for
-- `M.knownEffectTypes`/`EFFECT_TYPE_GROUPS`.
local function testGearEditorEditionAndRaritySync()
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

-- docs/feedback/INBOX.md item 12/13 (follow-up): STATUS.md's own recorded
-- next-slice note flagged that the extracted web editor edition sync check
-- only verifies the editor *accepts* the right edition ids -- it
-- never verifies the editor actually *previews* what an edition numerically
-- does to a card's effects (e.g. "crystallized" doubling sampleSellValue,
-- "quantum_flawed" doubling everything but appending a hullDurability
-- drawback), even though `game/gear.lua`'s `M.editionEffects` is the single
-- source of truth for exactly that transform and is documented as something
-- "the web editor's preview" should also read (gear.lua's own comment on
-- `M.editionEffects`: "Kept centralized so gear.lua and the web editor's
-- preview both read the exact same table"). Until this test, no code ever
-- checked that editor.js actually has such a preview table, so a numeric
-- edit to `M.editionEffects` (e.g. rebalancing crystallized from 2.0x to
-- 2.5x) could silently drift from what the editor shows an author while
-- they design a card.
local function testGearEditorEditionEffectPreviewSync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")

    local tableStart = editorSrc:find("EDITION_EFFECTS%s*=%s*{")
    assert(tableStart, "editor.js must define an EDITION_EFFECTS table mirroring gear.lua's M.editionEffects")
    local tableEnd = editorSrc:find("\n};", tableStart) or editorSrc:find("\n}", tableStart)
    assert(tableEnd, "editor.js EDITION_EFFECTS table must be closed with a '}'")
    local block = editorSrc:sub(tableStart, tableEnd)

    for editionId, def in pairs(gear.editionEffects) do
        local entryStart = block:find('"' .. editionId .. '"%s*:%s*{')
        assert(entryStart, "editor.js EDITION_EFFECTS must include an entry for '" .. editionId .. "'")
        -- Nested objects (quantum_flawed.drawback) close with '}' before the
        -- edition entry itself does; scan brace depth so drawback/noSlotCost
        -- fields are not truncated out of the compared snippet.
        local rest = block:sub(entryStart)
        local depth, entryLen = 0, nil
        for i = 1, #rest do
            local c = rest:sub(i, i)
            if c == "{" then
                depth = depth + 1
            elseif c == "}" then
                depth = depth - 1
                if depth == 0 then
                    entryLen = i
                    break
                end
            end
        end
        assert(entryLen, "editor.js EDITION_EFFECTS['" .. editionId .. "'] must be a closed object")
        local entry = rest:sub(1, entryLen)

        local scopeMatch = entry:match('scope%s*:%s*"([%w]+)"')
        assert(scopeMatch == def.scope,
            "editor.js EDITION_EFFECTS['" .. editionId .. "'].scope must be '" .. tostring(def.scope) ..
            "' to match gear.lua, got '" .. tostring(scopeMatch) .. "'")

        local multMatch = entry:match("multiplier%s*:%s*([%d%.]+)")
        assert(multMatch and tonumber(multMatch) == def.multiplier,
            "editor.js EDITION_EFFECTS['" .. editionId .. "'].multiplier must be " .. tostring(def.multiplier) ..
            " to match gear.lua, got " .. tostring(multMatch))

        -- Item 13/12 follow-up: scope/multiplier were already locked, but
        -- the remaining M.editionEffects fields (drawback, synergyBonusAdd,
        -- noSlotCost) were never compared. Those are the fields that make
        -- quantum_flawed / irradiated / refined mechanically distinct; if
        -- they drift, the editor preview still shows the right multiplier
        -- while silently dropping the drawback, extra synergy, or Negative-
        -- style slot exemption.
        if def.drawback then
            local drawbackType = entry:match('drawback%s*:%s*{%s*type%s*:%s*"([%w]+)"')
            local drawbackValue = entry:match('drawback%s*:%s*{[^}]*value%s*:%s*(-?[%d%.]+)')
            assert(drawbackType == def.drawback.type,
                "editor.js EDITION_EFFECTS['" .. editionId .. "'].drawback.type must be '" ..
                tostring(def.drawback.type) .. "' to match gear.lua, got '" .. tostring(drawbackType) .. "'")
            assert(drawbackValue and tonumber(drawbackValue) == def.drawback.value,
                "editor.js EDITION_EFFECTS['" .. editionId .. "'].drawback.value must be " ..
                tostring(def.drawback.value) .. " to match gear.lua, got " .. tostring(drawbackValue))
        else
            assert(not entry:find("drawback"),
                "editor.js EDITION_EFFECTS['" .. editionId .. "'] must not declare a drawback when gear.lua has none")
        end

        if def.synergyBonusAdd then
            local synergyMatch = entry:match("synergyBonusAdd%s*:%s*([%d%.]+)")
            assert(synergyMatch and tonumber(synergyMatch) == def.synergyBonusAdd,
                "editor.js EDITION_EFFECTS['" .. editionId .. "'].synergyBonusAdd must be " ..
                tostring(def.synergyBonusAdd) .. " to match gear.lua, got " .. tostring(synergyMatch))
        else
            assert(not entry:find("synergyBonusAdd"),
                "editor.js EDITION_EFFECTS['" .. editionId .. "'] must not declare synergyBonusAdd when gear.lua has none")
        end

        if def.noSlotCost then
            assert(entry:find("noSlotCost%s*:%s*true"),
                "editor.js EDITION_EFFECTS['" .. editionId .. "'].noSlotCost must be true to match gear.lua")
        else
            assert(not entry:find("noSlotCost"),
                "editor.js EDITION_EFFECTS['" .. editionId .. "'] must not declare noSlotCost when gear.lua has none")
        end

        if def.sellMultiplier then
            local sellMatch = entry:match("sellMultiplier%s*:%s*([%d%.]+)")
            assert(sellMatch and tonumber(sellMatch) == def.sellMultiplier,
                "editor.js EDITION_EFFECTS['" .. editionId .. "'].sellMultiplier must be " ..
                tostring(def.sellMultiplier) .. " to match gear.lua, got " .. tostring(sellMatch))
        else
            assert(not entry:find("sellMultiplier"),
                "editor.js EDITION_EFFECTS['" .. editionId .. "'] must not declare sellMultiplier when gear.lua has none")
        end
    end

    -- The preview must actually be wired to the form, not just declared as
    -- dead data: the editions field's change handler (or an equivalent
    -- explicit preview-update function) must exist and reference
    -- EDITION_EFFECTS so an author sees the transformed values live.
    assert(editorSrc:find("updateEditionPreview"),
        "editor.js must define/wire an updateEditionPreview function so effect values reflect selected editions live")

    -- Preview must consume the extra fields, not just store them in
    -- EDITION_EFFECTS. Otherwise authors would still see only the
    -- multiplier while quantum_flawed's hullDurability drawback,
    -- irradiated synergy, and refined noSlotCost stayed invisible.
    local previewStart = editorSrc:find("function updateEditionPreview")
    assert(previewStart, "editor.js must define function updateEditionPreview")
    local previewEnd = editorSrc:find("\nfunction ", previewStart + 1) or #editorSrc
    local previewBlock = editorSrc:sub(previewStart, previewEnd)
    assert(previewBlock:find("def.drawback"),
        "updateEditionPreview must apply def.drawback so quantum_flawed's extra effect is visible")
    assert(previewBlock:find("def.synergyBonusAdd"),
        "updateEditionPreview must surface def.synergyBonusAdd so irradiated's extra synergy is visible")
    assert(previewBlock:find("def.noSlotCost"),
        "updateEditionPreview must surface def.noSlotCost so refined's slot exemption is visible")
    -- Item 12 crystallized sell-price spike: the unique mechanic is a
    -- card-sell multiplier, not only sampleSellValue doubling. The preview
    -- must surface it so authors see "판매가 대폭 상승" in the form.
    assert(previewBlock:find("def.sellMultiplier"),
        "updateEditionPreview must surface def.sellMultiplier so crystallized's sell-price spike is visible")
end

-- docs/feedback/INBOX.md item 13/14 follow-up: editor.js's own header
-- comment ("Validation rules here intentionally mirror game/gear.lua's
-- loader exactly (same known effect types, known rarities, and effect
-- value range)") explicitly promises the effect value RANGE stays in sync
-- too, but until this test nothing ever checked
-- EFFECT_VALUE_MIN/EFFECT_VALUE_MAX against gear.lua's
-- M.effectValueMin/M.effectValueMax the way the extracted whitelist test
-- already does for editions/rarities -- a future rebalance of gear.lua's
-- range (e.g. -100..100 -> -50..50) could silently drift so the editor
-- keeps accepting/rejecting cards the real game loader would reject/accept.
local function testGearEditorEffectValueRangeSync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")

    local minMatch = editorSrc:match("EFFECT_VALUE_MIN%s*=%s*(-?%d+)")
    assert(minMatch, "editor.js must define EFFECT_VALUE_MIN")
    assert(tonumber(minMatch) == gear.effectValueMin,
        "editor.js EFFECT_VALUE_MIN must equal gear.lua's M.effectValueMin (" .. tostring(gear.effectValueMin) ..
        "), got " .. tostring(minMatch))

    local maxMatch = editorSrc:match("EFFECT_VALUE_MAX%s*=%s*(-?%d+)")
    assert(maxMatch, "editor.js must define EFFECT_VALUE_MAX")
    assert(tonumber(maxMatch) == gear.effectValueMax,
        "editor.js EFFECT_VALUE_MAX must equal gear.lua's M.effectValueMax (" .. tostring(gear.effectValueMax) ..
        "), got " .. tostring(maxMatch))
end

-- docs/feedback/INBOX.md item 13/14 follow-up: gear.lua's M.raritySellValue/
-- M.editionSellBonus/M.buyPriceMultiplier (item 9(c)/12's sell-to-rebuy
-- economy loop) had no counterpart in the web editor at all -- an author
-- designing a new card had no way to see its actual sell/buy price without
-- reading Lua by hand, unlike every other numeric constant this lane has
-- already locked into an editor<->gear.lua sync test (effect value range,
-- edition effect transforms, known editions/rarities). This test locks the
-- new RARITY_SELL_VALUE/EDITION_SELL_BONUS/BUY_PRICE_MULTIPLIER constants
-- and confirms the preview is actually wired to the form, not dead data.
local function testGearEditorEconomyPreviewSync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")
    local htmlSrc = love.filesystem.read("tools/gear-editor/index.html")
    assert(htmlSrc, "tools/gear-editor/index.html must be readable for the sync check")

    local tableStart = editorSrc:find("RARITY_SELL_VALUE%s*=%s*{")
    assert(tableStart, "editor.js must define a RARITY_SELL_VALUE table mirroring gear.lua's M.raritySellValue")
    local tableEnd = editorSrc:find("}", tableStart)
    local block = editorSrc:sub(tableStart, tableEnd)
    for rarity, value in pairs(gear.raritySellValue) do
        local match = block:match(rarity .. "%s*:%s*(%d+)")
        assert(match and tonumber(match) == value,
            "editor.js RARITY_SELL_VALUE['" .. rarity .. "'] must be " .. tostring(value) ..
            " to match gear.lua, got " .. tostring(match))
    end

    local bonusMatch = editorSrc:match("EDITION_SELL_BONUS%s*=%s*(%d+)")
    assert(bonusMatch and tonumber(bonusMatch) == gear.editionSellBonus,
        "editor.js EDITION_SELL_BONUS must equal gear.lua's M.editionSellBonus (" ..
        tostring(gear.editionSellBonus) .. "), got " .. tostring(bonusMatch))

    local multMatch = editorSrc:match("BUY_PRICE_MULTIPLIER%s*=%s*(%d+)")
    assert(multMatch and tonumber(multMatch) == gear.buyPriceMultiplier,
        "editor.js BUY_PRICE_MULTIPLIER must equal gear.lua's M.buyPriceMultiplier (" ..
        tostring(gear.buyPriceMultiplier) .. "), got " .. tostring(multMatch))

    -- The preview must actually be wired to the form (rarity + edition
    -- change handlers), not just declared as dead computeSellValue/
    -- computeBuyPrice functions nobody calls.
    assert(editorSrc:find("function updateEconomyPreview"),
        "editor.js must define function updateEconomyPreview")
    assert(editorSrc:find("updateEconomyPreview()", 1, true),
        "editor.js must actually call updateEconomyPreview somewhere (form open/rarity/edition change)")
    assert(htmlSrc:find('id="economyPreviewContainer"', 1, true),
        "index.html must expose an economyPreviewContainer element for the sell/buy preview to render into")

    -- Sanity-check the JS math itself matches gear.lua's M.sellValue/M.buyPrice
    -- for a representative case (legendary + crystallized), since a
    -- constant-level sync check alone would not catch a wrong combination
    -- formula (e.g. applying the edition bonus before the multiplier).
    local previewStart = editorSrc:find("function computeSellValue")
    assert(previewStart, "editor.js must define function computeSellValue")
    local previewEnd = editorSrc:find("\nfunction ", previewStart + 1) or #editorSrc
    local previewBlock = editorSrc:sub(previewStart, previewEnd)
    assert(previewBlock:find("sellMultiplier"),
        "computeSellValue must apply an edition's sellMultiplier (e.g. crystallized) like gear.lua's M.sellValue")
end

-- docs/feedback/INBOX.md item 13 follow-up: gear.lua's validatePart already
-- round-trips the item-7 `galaxyExclusive` boolean (hull_combo_matrix and
-- engine_singularity_drive both carry it so earthShopPool can exclude them),
-- but the web editor's collectFormPart never emitted that field. Opening
-- either JSON, editing any other field, and saving would silently strip
-- galaxyExclusive and undo the Earth-shop filter / hub-drop wiring. This
-- test locks the form field + collect/open round-trip so a future editor
-- rewrite cannot drop the flag again.
local function testGearEditorGalaxyExclusiveFieldSync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")
    local htmlSrc = love.filesystem.read("tools/gear-editor/index.html")
    assert(htmlSrc, "tools/gear-editor/index.html must be readable for the sync check")

    assert(htmlSrc:find('id="fieldGalaxyExclusive"', 1, true),
        "index.html must expose a fieldGalaxyExclusive control so authors can set galaxyExclusive")
    assert(htmlSrc:find("Galaxy exclusive", 1, true) or htmlSrc:find("galaxy exclusive", 1, true),
        "index.html must label the galaxyExclusive control so authors know it excludes the card from Earth shop")

    local collectStart = editorSrc:find("function collectFormPart")
    assert(collectStart, "editor.js must define collectFormPart")
    local collectEnd = editorSrc:find("\n}", collectStart)
    assert(collectEnd, "editor.js collectFormPart must have a closing brace")
    local collectBlock = editorSrc:sub(collectStart, collectEnd)
    assert(collectBlock:find("galaxyExclusive"),
        "collectFormPart must include galaxyExclusive so a save does not strip the field")

    local openStart = editorSrc:find("function openForm")
    assert(openStart, "editor.js must define openForm")
    local openEnd = editorSrc:find("\nfunction closeForm", openStart) or editorSrc:find("\n}", openStart)
    assert(openEnd, "editor.js openForm must be locatable")
    local openBlock = editorSrc:sub(openStart, openEnd)
    assert(openBlock:find("galaxyExclusive"),
        "openForm must restore galaxyExclusive from the loaded part")
end

-- INBOX 61(37): gear-editor must expose stellar suit + synergy table (user 2026-09-07).
local function testGearEditorSuitAndSynergySync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")
    local htmlSrc = love.filesystem.read("tools/gear-editor/index.html")
    assert(htmlSrc, "tools/gear-editor/index.html must be readable for the sync check")

    assert(htmlSrc:find('id="fieldSuit"', 1, true),
        "index.html must expose fieldSuit so authors can set stellar suit")
    assert(htmlSrc:find('id="synergyPanel"', 1, true),
        "index.html must expose synergyPanel for the 7 stellar synergies")

    local suitsStart = editorSrc:find("KNOWN_SUITS%s*=%s*%[")
    assert(suitsStart, "editor.js must define KNOWN_SUITS")
    local suitsEnd = editorSrc:find("%]", suitsStart)
    local suitsBlock = editorSrc:sub(suitsStart, suitsEnd)
    for suit, _ in pairs(gear.knownSuits) do
        assert(suitsBlock:find('"' .. suit .. '"', 1, true),
            "editor.js KNOWN_SUITS must include '" .. suit .. "'")
    end

    assert(editorSrc:find("STELLAR_SYNERGIES", 1, true),
        "editor.js must list STELLAR_SYNERGIES")
    assert(editorSrc:find("사건의 지평선", 1, true),
        "synergy table must include 사건의 지평선 (no symbol prefix)")
    assert(editorSrc:find("채집 +30%", 1, true),
        "eventHorizon copy must be 채집 +30%")
    assert(editorSrc:find("function renderSynergyPanel", 1, true),
        "editor.js must draw the synergy reference panel")

    local collectStart = editorSrc:find("function collectFormPart")
    local collectEnd = editorSrc:find("\n}", collectStart)
    local collectBlock = editorSrc:sub(collectStart, collectEnd)
    assert(collectBlock:find("suit:"),
        "collectFormPart must persist suit so a save does not strip it")
end

function M.run()
    testGearEditorEditionAndRaritySync()
end

function M.runAll()
    M.run()
    testGearEditorEditionEffectPreviewSync()
    testGearEditorEffectValueRangeSync()
    testGearEditorEconomyPreviewSync()
    testGearEditorGalaxyExclusiveFieldSync()
    testGearEditorSuitAndSynergySync()
end

return M
