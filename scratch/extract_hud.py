import re
import sys

play_lua_path = "game/scenes/play.lua"
hud_lua_path = "game/scenes/play_hud.lua"

with open(play_lua_path, "r") as f:
    lines = f.readlines()

def get_block(start_regex, end_regex=None, extract=True):
    start_idx = -1
    for i, line in enumerate(lines):
        if re.search(start_regex, line):
            start_idx = i
            break
    if start_idx == -1: return None
    end_idx = -1
    if end_regex:
        for i in range(start_idx+1, len(lines)):
            if re.search(end_regex, lines[i]):
                end_idx = i
                break
    else:
        # find matching `end` for lua function block
        depth = 0
        for i in range(start_idx, len(lines)):
            line = lines[i]
            if re.search(r'\b(function|if|for|while|do)\b', line) and not re.search(r'end\s*$', line) and not 'local function' in line and not line.strip().startswith('--'):
                # rough heuristic, better to count exactly
                pass
    return start_idx, end_idx

# It's safer to just let me manually write the script that extracts the functions I need.
