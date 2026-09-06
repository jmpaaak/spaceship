import re

with open("game/self_test.lua", "r") as f:
    code = f.read()

def inject_loop(match):
    scene_var = match.group(1)
    if scene_var in ("brokeScene", "nonSettleScene"):
        return match.group(0)
    return f"""{scene_var}:keypressed("l")
    {scene_var}:keypressed("l"); while {scene_var}.slotState and not {scene_var}.slotState.reels[1].stopped do {scene_var}:update(0.1) end
    {scene_var}:keypressed("l"); while {scene_var}.slotState and not {scene_var}.slotState.reels[2].stopped do {scene_var}:update(0.1) end
    {scene_var}:keypressed("l"); while {scene_var}.slotState and {scene_var}.slotState.spinning do {scene_var}:update(0.1) end"""

code = re.sub(r'([a-zA-Z0-9_]+):keypressed\("l"\)', inject_loop, code)

with open("game/self_test.lua", "w") as f:
    f.write(code)
