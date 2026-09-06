import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('solarWeights.COMET + solarWeights.PLANET + solarWeights.HARVEST', 'solarWeights.MONEY + solarWeights.PART + solarWeights.SPEED + solarWeights.DURABILITY + solarWeights.HARVEST')
code = code.replace('fringeWeights.COMET + fringeWeights.PLANET + fringeWeights.HARVEST', 'fringeWeights.MONEY + fringeWeights.PART + fringeWeights.SPEED + fringeWeights.DURABILITY + fringeWeights.HARVEST')
code = code.replace('voidWeights.COMET + voidWeights.PLANET + voidWeights.HARVEST', 'voidWeights.MONEY + voidWeights.PART + voidWeights.SPEED + voidWeights.DURABILITY + voidWeights.HARVEST')

# Wait, check for COMET+PLANET inside "last bucket" comment
code = code.replace('COMET+PLANET', 'MONEY+PART+SPEED+DURABILITY')

with open("game/self_test.lua", "w") as f:
    f.write(code)
