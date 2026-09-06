import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

old_custom = """    local custom = [[{
      "schemaVersion": 1,
      "spinCost": 25,
      "symbols": [
        {"id": "COMET", "name": "Comet", "weight": 5},
        {"id": "PLANET", "name": "Planet", "weight": 4},
        {"id": "STAR", "name": "Star", "weight": 1}
      ],
      "payouts": {"miss": 0, "pair": 20, "triple": 50, "jackpot": 100},
      "profiles": {
        "solar":  {"weights": {"COMET": 5, "PLANET": 4, "STAR": 1}, "multipliers": {"tripleSTAR": 1.0}},
        "fringe": {"weights": {"COMET": 4, "PLANET": 4, "STAR": 2}, "multipliers": {"tripleSTAR": 1.5}},
        "void":   {"weights": {"COMET": 3, "PLANET": 4, "STAR": 3}, "multipliers": {"tripleSTAR": 2.0}}
      }
    }]]"""

new_custom = """    local custom = [[{
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
    }]]"""

code = code.replace(old_custom, new_custom)

with open("game/self_test.lua", "w") as f:
    f.write(code)
