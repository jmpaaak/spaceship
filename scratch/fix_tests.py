import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

# Replace COMET, PLANET, STAR with new symbols
code = code.replace('solarWeights.COMET and solarWeights.PLANET and solarWeights.STAR', 'solarWeights.MONEY and solarWeights.HARVEST')
code = code.replace('"earthSlotWeights must include COMET, PLANET, and STAR keys"', '"earthSlotWeights must include new keys"')

code = code.replace('fringeWeights.STAR > solarWeights.STAR', 'fringeWeights.HARVEST > solarWeights.HARVEST')
code = code.replace('solarWeights.STAR', 'solarWeights.HARVEST')
code = code.replace('solarWeights.COMET + solarWeights.PLANET + solarWeights.STAR', 'solarWeights.MONEY + solarWeights.PART + solarWeights.SPEED + solarWeights.DURABILITY + solarWeights.HARVEST')
code = code.replace('voidWeights.COMET + voidWeights.PLANET + voidWeights.STAR', 'voidWeights.MONEY + voidWeights.PART + voidWeights.SPEED + voidWeights.DURABILITY + voidWeights.HARVEST')
code = code.replace('fringeWeights.COMET + fringeWeights.PLANET + fringeWeights.STAR', 'fringeWeights.MONEY + fringeWeights.PART + fringeWeights.SPEED + fringeWeights.DURABILITY + fringeWeights.HARVEST')

# Fix symbols for the deterministic rolls
code = code.replace('symbols = { "COMET", "PLANET", "STAR" }', 'symbols = { "MONEY", "PART", "SPEED" }')
code = code.replace('symbols = { "STAR", "STAR", "STAR" }', 'symbols = { "MONEY", "MONEY", "MONEY" }')
code = code.replace('expedition.slotReward({ "COMET", "PLANET", "STAR" })', 'expedition.slotReward({ "MONEY", "PART", "SPEED" })')
code = code.replace('expedition.slotReward({ "STAR", "STAR", "STAR" })', 'expedition.slotReward({ "MONEY", "MONEY", "MONEY" })')
code = code.replace('expedition.slotReward({ "COMET", "COMET", "PLANET" })', 'expedition.slotReward({ "MONEY", "MONEY", "PART" })')

code = code.replace('and missSpin.symbols[3] == "STAR"', 'and missSpin.symbols[3] == "SPEED"')
code = code.replace('"COMET-PLANET-STAR rolls must be a true miss', '"MONEY-PART-SPEED rolls must be a true miss')

code = code.replace('symbols[1] == "STAR"', 'symbols[1] == "HARVEST"')
code = code.replace('symbols[2] == "STAR"', 'symbols[2] == "HARVEST"')
code = code.replace('symbols[3] == "STAR"', 'symbols[3] == "HARVEST"')
code = code.replace('select STAR', 'select HARVEST')
code = code.replace('triple-STAR', 'triple-HARVEST')

code = code.replace('assert(solarSpin.reward == 75,', 'assert(solarSpin.reward == 100,')
code = code.replace('baseline 75', 'baseline 100')

code = code.replace('== 85', '== 110')
code = code.replace('+ 75', '+ 100')
code = code.replace('+75', '+100')
code = code.replace('20-10+75=85', '20-10+100=110')
code = code.replace('20-10+10=20', '20-10+100=110')

code = code.replace('assert(doc.payouts.pair == 15 and doc.payouts.triple == 40\n        and doc.payouts.jackpot == 75,\n        "bundled pair/triple/jackpot stay 15/40/75")',
    'assert(doc.payouts.pair == 3 and doc.payouts.triple == 10, "bundled pair/triple stay 3/10")')
code = code.replace('doc.symbols) == "table" and #doc.symbols >= 3', 'doc.symbols) == "table" and #doc.symbols >= 5')

code = code.replace('== 20,\n        "custom pair payout must apply"', '== 5,\n        "custom pair payout must apply"')
code = code.replace('== 100,\n        "custom jackpot must apply"', '== 15,\n        "custom triple must apply"')


with open("game/self_test.lua", "w") as f:
    f.write(code)
