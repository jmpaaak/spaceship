import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('for k, v in pairs(solarWeights) do print("solarWeights key:", k, "val:", v) end; for k, v in pairs(fringeWeights) do print("fringeWeights key:", k, "val:", v) end; ', '')
code = code.replace('print("spinResult symbols:", spinResult.symbols[1], spinResult.symbols[2], spinResult.symbols[3]); ', '')

with open("game/self_test.lua", "w") as f:
    f.write(code)
