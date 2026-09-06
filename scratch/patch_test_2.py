with open("game/self_test.lua", "r") as f:
    code = f.read()

test_update_logic = """
        slotScene:keypressed("l") -- start spin

        -- Stop reel 1
        slotScene:keypressed("l")
        while slotScene.slotState and not slotScene.slotState.reels[1].stopped do slotScene:update(0.1) end
        
        -- Stop reel 2
        slotScene:keypressed("l")
        while slotScene.slotState and not slotScene.slotState.reels[2].stopped do slotScene:update(0.1) end
        
        -- Stop reel 3
        slotScene:keypressed("l")
        while slotScene.slotState and slotScene.slotState.spinning do slotScene:update(0.1) end

        expedition.earthSlotSpin = originalSpin  -- restore
"""

code = code.replace(
    '''        slotScene:keypressed("l")

        -- INBOX 52(b): Reels are now animated. Advance time until they stop.
        while slotScene.slotState and slotScene.slotState.spinning do
            slotScene:update(0.1)
        end

        expedition.earthSlotSpin = originalSpin  -- restore''',
    test_update_logic
)

with open("game/self_test.lua", "w") as f:
    f.write(code)
