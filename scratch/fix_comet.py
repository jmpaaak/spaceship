import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('fringeWeights.COMET < solarWeights.COMET', 'fringeWeights.MONEY < solarWeights.MONEY')
code = code.replace('COMET weight must be below solar COMET', 'MONEY weight must be below solar MONEY')

code = code.replace('COMET-COMET-COMET', 'MONEY-MONEY-MONEY')
code = code.replace('PLANET-PLANET-PLANET', 'PART-PART-PART')

with open("game/self_test.lua", "w") as f:
    f.write(code)
