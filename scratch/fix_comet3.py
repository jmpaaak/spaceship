import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('voidWeights.COMET', 'voidWeights.MONEY')
code = code.replace('fringeWeights.COMET', 'fringeWeights.MONEY')
code = code.replace('solarWeights.COMET', 'solarWeights.MONEY')
code = code.replace('planetRoll', 'partRoll')
code = code.replace('COMET bucket', 'MONEY bucket')
code = code.replace('PLANET bucket', 'PART bucket')

with open("game/self_test.lua", "w") as f:
    f.write(code)
