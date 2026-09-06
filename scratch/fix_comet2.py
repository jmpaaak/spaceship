import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('== "COMET"', '== "MONEY"')
code = code.replace('== "PLANET"', '== "PART"')
code = code.replace('a COMET triple', 'a MONEY triple')

with open("game/self_test.lua", "w") as f:
    f.write(code)
