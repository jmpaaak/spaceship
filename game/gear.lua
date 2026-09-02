-- docs/feedback/INBOX.md UI/HUD item 6 ("표본 9종 도감 정리 + 슬롯 6개를 개성 있는
-- 함선 장비 카드 UI로 전환"): the abstract "6 return slots" concept is being
-- reinterpreted as 6 named ship gear cards (Balatro-joker-style: each has a
-- distinct name/icon/ability) instead of faceless probability slots.
--
-- This first slice only introduces the card *catalog* (data) plus a pure
-- function mapping the run's *existing* meta-upgrade levels
-- (durabilityUpgradeLevel / sampleYieldUpgradeLevel / steeringUpgradeLevel)
-- onto three of the six named cards, exactly as the INBOX item allows
-- ("기존 업그레이드 시스템을 이름 있는 카드로 매핑"). The other three cards
-- from the user's session draft (LUCKY DICE / STREAK AMPLIFIER / PRECISION
-- GYRO) name mechanics (slot odds, streak multiplier, steering
-- responsiveness) that either have no purchasable upgrade path yet or are
-- not tied to a single existing numeric level, so they are listed in the
-- catalog (for future UI/menus to reference) but never report as
-- "equipped" by this slice -- upgradeField stays nil for them, which is an
-- honest reflection of "not yet purchasable", not a placeholder bug.
--
-- Deliberately engine-only/data-only for now: no rendering, no new
-- run fields, no shop UI. game/scenes/play.lua and the shop screen can
-- read M.equipped(run) in a later slice to draw an icon strip once the
-- visual design is worked out.
local M = {}

M.catalog = {
    {
        id = "overdrive_core",
        name = "OVERDRIVE CORE",
        icon = "\xe2\x9a\xa1", -- lightning bolt
        tag = "propulsion",
        description = "+STEER SPEED",
        upgradeField = "steeringUpgradeLevel",
    },
    {
        id = "reinforced_plating",
        name = "REINFORCED PLATING",
        icon = "\xf0\x9f\x9b\xa1", -- shield
        tag = "defense",
        description = "+HULL",
        upgradeField = "durabilityUpgradeLevel",
    },
    {
        id = "collection_magnet",
        name = "COLLECTION MAGNET",
        icon = "\xf0\x9f\xa7\xb2", -- magnet
        tag = "collection",
        description = "+SAMPLE VALUE",
        upgradeField = "sampleYieldUpgradeLevel",
    },
    {
        id = "lucky_dice",
        name = "LUCKY DICE",
        icon = "\xf0\x9f\x8e\xb2", -- dice
        tag = "luck",
        description = "SLOT ODDS (not yet purchasable)",
        upgradeField = nil,
    },
    {
        id = "streak_amplifier",
        name = "STREAK AMPLIFIER",
        icon = "\xf0\x9f\x94\x97", -- link
        tag = "luck",
        description = "STREAK MULT (not yet purchasable)",
        upgradeField = nil,
    },
    {
        id = "precision_gyro",
        name = "PRECISION GYRO",
        icon = "\xf0\x9f\xa7\xad", -- compass
        tag = "propulsion",
        description = "TURN RESPONSE (not yet purchasable)",
        upgradeField = nil,
    },
}

-- Item 6 reinterprets the existing "6 slot opportunities" concept as 6
-- named gear cards, so the catalog size intentionally mirrors
-- game/expedition.lua's slotCount() ceiling of 6 -- this constant lets
-- callers/tests assert that relationship without hardcoding the number
-- twice.
M.cardCount = #M.catalog

-- Returns the subset of M.catalog whose mapped upgradeField currently has
-- a level above 0 on this run, each entry shallow-copied with an added
-- `.level` field (the run's current level for that upgrade). Cards with no
-- upgradeField (not yet purchasable) never appear here. Pure function: it
-- only reads run fields, never mutates the run or the catalog.
function M.equipped(run)
    local result = {}
    for _, entry in ipairs(M.catalog) do
        if entry.upgradeField and (run[entry.upgradeField] or 0) > 0 then
            local equippedEntry = {}
            for k, v in pairs(entry) do
                equippedEntry[k] = v
            end
            equippedEntry.level = run[entry.upgradeField]
            result[#result + 1] = equippedEntry
        end
    end
    return result
end

return M
