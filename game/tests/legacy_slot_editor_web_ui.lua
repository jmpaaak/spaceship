local M = {}

-- INBOX (15)(c): tools/slot-editor web UI + runtime data/slot_config.json.
-- Missing file must keep current defaults (spin 10, miss 0, pair 15,
-- triple 40, STAR×3 75, solar/fringe/void multipliers 1/1.5/2).
function M.run()
    local expedition = require("game.expedition")
    local json = require("game.json")
    local html = love.filesystem.read("tools/slot-editor/index.html")
    local css = love.filesystem.read("tools/slot-editor/editor.css")
    local js = love.filesystem.read("tools/slot-editor/editor.js")
    assert(html, "INBOX 15(c): tools/slot-editor/index.html must exist")
    assert(css, "INBOX 15(c): tools/slot-editor/editor.css must exist")
    assert(js, "INBOX 15(c): tools/slot-editor/editor.js must exist")
    assert(html:find("Slot Editor", 1, true),
        "slot-editor HTML must title the Slot Editor")
    assert(js:find("spinCost", 1, true),
        "slot-editor JS must edit spinCost")
    assert(js:find("symbols", 1, true),
        "slot-editor JS must edit symbols")
    assert(js:find("payouts", 1, true),
        "slot-editor JS must edit payouts")
    assert(js:find("\"solar\"", 1, true) and js:find("\"fringe\"", 1, true)
        and js:find("\"void\"", 1, true),
        "slot-editor JS must edit solar/fringe/void profiles")

    local contents = love.filesystem.read("data/slot_config.json")
    assert(contents, "INBOX 15(c): data/slot_config.json must exist")
    local doc = json.decode(contents)
    assert(doc.spinCost == 10, "bundled spinCost default is 10")
    assert(doc.payouts and doc.payouts.miss == 0, "bundled miss payout is 0")
    assert(doc.payouts.pair == 3 and doc.payouts.triple == 10, "bundled pair/triple stay 3/10")
    assert(type(doc.symbols) == "table" and #doc.symbols >= 5,
        "bundled config must list slot symbols")
    assert(doc.profiles and doc.profiles.solar and doc.profiles.fringe
        and doc.profiles.void,
        "bundled config must include solar/fringe/void profiles")

    assert(type(expedition.loadSlotConfig) == "function",
        "INBOX 15(c): runtime must expose loadSlotConfig")
    assert(expedition.slotConfigPath == "data/slot_config.json",
        "runtime path must be data/slot_config.json")

    local loaded, loadErr = expedition.loadSlotConfig()
    assert(loaded, "bundled slot_config.json must load: " .. tostring(loadErr))
    assert(expedition.slotSpinCost == 10)
    assert(expedition.slotReward({ "MONEY", "PART", "SPEED" }) == 0)
    assert(expedition.slotReward({ "MONEY", "MONEY", "MONEY" }) == 10)

    local custom = [[{
      "schemaVersion": 2,
      "spinCost": 25,
      "symbols": [
        {"id": "MONEY", "name": "Money", "weight": 6},
        {"id": "PART", "name": "Part", "weight": 3},
        {"id": "SPEED", "name": "Speed", "weight": 4},
        {"id": "DURABILITY", "name": "Durability", "weight": 3},
        {"id": "HARVEST", "name": "Harvest", "weight": 4}
      ],
      "payouts": {"miss": 0, "pair": 5, "triple": 15},
      "profiles": {
        "solar":  {"weights": {"MONEY": 6, "PART": 3, "SPEED": 4, "DURABILITY": 3, "HARVEST": 4}, "multipliers": {"tripleMultiplier": 1.0}},
        "fringe": {"weights": {"MONEY": 5, "PART": 3, "SPEED": 4, "DURABILITY": 3, "HARVEST": 5}, "multipliers": {"tripleMultiplier": 1.5}},
        "void":   {"weights": {"MONEY": 4, "PART": 4, "SPEED": 4, "DURABILITY": 4, "HARVEST": 4}, "multipliers": {"tripleMultiplier": 2.0}}
      }
    }]]
    local applied, applyErr = expedition.loadSlotConfig({
        read = function() return custom end,
    })
    assert(applied, "custom slot config must apply: " .. tostring(applyErr))
    assert(expedition.slotSpinCost == 25,
        "custom spinCost must apply, got " .. tostring(expedition.slotSpinCost))
    assert(expedition.slotReward({ "MONEY", "MONEY", "PART" }) == 5,
        "custom pair payout must apply")
    assert(expedition.slotReward({ "MONEY", "MONEY", "MONEY" }) == 15,
        "custom triple must apply")

    local missingOk = expedition.loadSlotConfig({
        read = function() return nil end,
    })
    assert(not missingOk, "missing slot_config.json must not apply")
    assert(expedition.slotSpinCost == 10,
        "missing file restores default spinCost 10, got "
            .. tostring(expedition.slotSpinCost))
    assert(expedition.slotReward({ "MONEY", "MONEY", "MONEY" }) == 10,
        "missing file restores default jackpot 75")
end

return M