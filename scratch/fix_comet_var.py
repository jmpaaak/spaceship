import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('solarWeights.COMET', 'solarWeights.MONEY')
code = code.replace('cometRoll', 'moneyRoll')
code = code.replace('COMET_weight', 'MONEY_weight')

with open("game/self_test.lua", "w") as f:
    f.write(code)
