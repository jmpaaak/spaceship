import re
import sys

with open("game/scenes/play.lua", "r") as f:
    lines = f.readlines()

out_lines = []
skip = False
for i, line in enumerate(lines):
    if line.startswith("function M.shopModalLayout("):
        skip = True
    elif line.startswith("function M.shopModalButtonRects("):
        skip = True
    elif line.startswith("function M.hitShopModalGearSlot("):
        skip = True

# Wait, this Python parsing is error-prone. Let's do it manually with sed.
