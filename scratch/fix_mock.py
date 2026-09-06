with open("game/self_test.lua", "r") as f:
    code = f.read()

# Fix the mock reward from 75 to 100
code = code.replace('reward = 75,', 'reward = 100,')
code = code.replace('symbols[1] == "HARVEST",\n            "item 15(b): earthShopSlotResult.symbols must reflect',
    'symbols[1] == "MONEY",\n            "item 15(b): earthShopSlotResult.symbols must reflect')
code = code.replace('message:find("%+%$75")', 'message:find("%+%$100")')

with open("game/self_test.lua", "w") as f:
    f.write(code)
