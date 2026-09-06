import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace(
    'print("solarWeights keys:", require("game.util").dump(solarWeights)) assert(fringeWeights.HARVEST > solarWeights.HARVEST,',
    'for k, v in pairs(solarWeights) do print("solarWeights key:", k, "val:", v) end; assert(fringeWeights.HARVEST > solarWeights.HARVEST,'
)

with open("game/self_test.lua", "w") as f:
    f.write(code)
