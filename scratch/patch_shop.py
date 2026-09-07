import re
import sys

with open("game/scenes/play.lua", "r") as f:
    play_lines = f.readlines()

def get_lines(start, end):
    return play_lines[start-1:end]

shop_layout = get_lines(319, 337)
shop_rects = get_lines(339, 342)
shop_hit = get_lines(3075, 3100)
shop_draw = get_lines(4201, 4248)

with open("game/scenes/play_shop.lua", "r") as f:
    shop_lua = f.read()

# We need to rewrite the functions to use PS. and _M.
def rewrite_to_ps(lines, func_name):
    # Change function M.foo to function PS.foo
    lines[0] = lines[0].replace(f"function M.{func_name}", f"function PS.{func_name}")
    # Also change M. inside the function to _M.
    text = "".join(lines)
    text = text.replace(" M.", " _M.")
    return text

shop_layout_str = rewrite_to_ps(shop_layout, "shopModalLayout")
shop_rects_str = rewrite_to_ps(shop_rects, "shopModalButtonRects")
shop_hit_str = rewrite_to_ps(shop_hit, "hitShopModalGearSlot")

draw_inner = "".join(shop_draw)
draw_inner = draw_inner.replace(" M.", " _M.")
shop_draw_str = "function PS.drawShopModal(self)\n" + draw_inner + "end\n"

# Append these to play_shop.lua before install(M)
insert_pos = shop_lua.find("---------------------------------------------------------------------------\n-- install(M)")

new_shop_lua = shop_lua[:insert_pos] + \
    "---------------------------------------------------------------------------\n-- Shop Modal (Extracted from play.lua)\n---------------------------------------------------------------------------\n" + \
    shop_layout_str + "\n" + shop_rects_str + "\n" + shop_hit_str + "\n" + shop_draw_str + "\n" + \
    shop_lua[insert_pos:]

# Update install(M)
install_pos = new_shop_lua.find("    M.drawDestroyedOverlay     = PS.drawDestroyedOverlay")
new_shop_lua = new_shop_lua[:install_pos] + \
    "    M.shopModalLayout          = PS.shopModalLayout\n" + \
    "    M.shopModalButtonRects     = PS.shopModalButtonRects\n" + \
    "    M.hitShopModalGearSlot     = PS.hitShopModalGearSlot\n" + \
    "    M.drawShopModal            = PS.drawShopModal\n" + \
    new_shop_lua[install_pos:]

with open("game/scenes/play_shop.lua", "w") as f:
    f.write(new_shop_lua)

# Remove the blocks from play.lua
new_play_lines = []
for i, line in enumerate(play_lines):
    idx = i + 1
    if 319 <= idx <= 337: continue
    if 339 <= idx <= 342: continue
    if 3075 <= idx <= 3100: continue
    if 4201 <= idx <= 4248: continue
    
    if idx == 4201:
        new_play_lines.append("    if self.shopModal then\n        self:drawShopModal()\n    end\n")
    else:
        new_play_lines.append(line)

# Since we skipped 4201..4248, we need to make sure we inserted the replacement correctly.
# Wait, if we skip 4201, when idx == 4201 it is skipped! So it won't be appended.
# Fix:
new_play_lines = []
for i, line in enumerate(play_lines):
    idx = i + 1
    if 319 <= idx <= 337: continue
    if 339 <= idx <= 342: continue
    if 3075 <= idx <= 3100: continue
    if 4201 <= idx <= 4248:
        if idx == 4201:
            new_play_lines.append("    if self.shopModal then\n        self:drawShopModal()\n    end\n")
        continue
    new_play_lines.append(line)

with open("game/scenes/play.lua", "w") as f:
    f.writelines(new_play_lines)
