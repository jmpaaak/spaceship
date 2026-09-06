import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

code = code.replace('== 15,\n        "INBOX 15(b): pair payout stays 15"', '== 3,\n        "INBOX 52(b): pair payout is 3"')
code = code.replace('({ "COMET", "COMET", "COMET" }) == 40', '({ "PART", "PART", "PART" }) == 10')
code = code.replace('"INBOX 15(b): non-STAR triple payout stays 40"', '"INBOX 52(b): triple payout is 10"')
code = code.replace('({ "MONEY", "MONEY", "MONEY" }) == 75', '({ "MONEY", "MONEY", "MONEY" }) == 10')
code = code.replace('"INBOX 15(b): STAR jackpot stays 75"', '"INBOX 52(b): triple payout is 10"')

code = code.replace('solarWeights.PLANET', 'solarWeights.PART')
code = code.replace('fringeWeights.PLANET', 'fringeWeights.PART')
code = code.replace('voidWeights.PLANET', 'voidWeights.PART')

with open("game/self_test.lua", "w") as f:
    f.write(code)
