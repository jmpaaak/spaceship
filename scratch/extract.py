import re

with open('game/expedition.lua', 'r') as f:
    text = f.read()

# Define slot functions
slot_funcs = [
    "loadSlotConfig",
    "slotSymbolProbability",
    "slotExpectedValue",
    "galaxyDistance",
    "slotTier",
    "slotSpinCostFor",
    "galaxySlotOddsProfile",
    "earthSlotWeights",
    "earthSlotTotalWeight",
    "earthSlotSpin"
]

# We need to extract the slot variables at the top of expedition.lua
# Lines 14 to 45 approx
var_pattern = r'(-- INBOX \(52b\):.*?M\.slotConfigPath = "data/slot_config\.json")\n'
var_match = re.search(var_pattern, text, re.DOTALL)
var_str = var_match.group(1) if var_match else ""

# Extract functions
func_bodies = {}
for fn in slot_funcs:
    pattern = r'function M\.' + fn + r'\(.*?\).*?^end\n'
    match = re.search(pattern, text, re.DOTALL | re.MULTILINE)
    if match:
        func_bodies[fn] = match.group(0)
    else:
        print(f"NOT FOUND: {fn}")

# Build expedition_slot.lua
slot_mod = """local M = {}
local json = require("game.json")

""" + var_str + "\n\n"

for fn in slot_funcs:
    if fn in func_bodies:
        # replace M. with M. inside the body is fine, because we use local M = {}
        # Wait, M.earthSlotOddsProfiles, etc are defined as M. in var_str
        slot_mod += func_bodies[fn] + "\n"

# In earthSlotSpin, it uses gearModule and enginePartsModule. We need to add require at the top.
slot_mod = slot_mod.replace('local json = require("game.json")', 'local json = require("game.json")\nlocal gearModule = require("game.gear")\nlocal enginePartsModule = require("game.engine_parts")')

with open('game/expedition_slot.lua', 'w') as f:
    f.write(slot_mod)

# Now modify expedition.lua to replace these functions with delegations,
# and remove the var definitions, replaced by delegations.

new_text = text
if var_match:
    new_text = new_text.replace(var_match.group(1), '-- (Slot variables extracted to expedition_slot.lua)')

for fn in slot_funcs:
    if fn in func_bodies:
        # Instead of replacing the entire function with a one-liner, just replace it with a delegation.
        # But wait, what arguments do they take? Let's just parse the arguments from the signature
        sig_match = re.search(r'function M\.' + fn + r'\((.*?)\)', func_bodies[fn])
        if sig_match:
            args = sig_match.group(1)
            delegation = f"function M.{fn}({args})\n    return require('game.expedition_slot').{fn}({args})\nend\n"
            new_text = new_text.replace(func_bodies[fn], delegation)

# Also delegate the variables at the top or bottom of expedition.lua
var_delegation = """
local expedition_slot = require('game.expedition_slot')
M.slotSymbols = expedition_slot.slotSymbols
M.slotWeights = expedition_slot.slotWeights
M.slotTotalWeight = expedition_slot.slotTotalWeight
M.slotPayouts = expedition_slot.slotPayouts
M.earthSlotOddsProfiles = expedition_slot.earthSlotOddsProfiles
M.earthSlotRewardMultipliers = expedition_slot.earthSlotRewardMultipliers
M.slotSpinCost = expedition_slot.slotSpinCost
M.slotConfigPath = expedition_slot.slotConfigPath
"""

new_text = new_text.replace('-- (Slot variables extracted to expedition_slot.lua)', var_delegation)

with open('scratch/expedition_new.lua', 'w') as f:
    f.write(new_text)
