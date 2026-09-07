import re

def extract_funcs():
    with open("game/scenes/play.lua", "r") as f:
        content = f.read()

    # We will just write a new play_hud.lua
    # and use sed/awk to patch play.lua

extract_funcs()
