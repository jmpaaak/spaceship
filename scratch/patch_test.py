with open("game/self_test.lua", "r") as f:
    code = f.read()

test_update_logic = """
        slotScene:keypressed("l")

        -- INBOX 52(b): Reels are now animated. Advance time until they stop.
        while slotScene.slotState and slotScene.slotState.spinning do
            slotScene:update(0.1)
        end

        expedition.earthSlotSpin = originalSpin  -- restore
"""

code = code.replace(
    '        slotScene:keypressed("l")\n\n        expedition.earthSlotSpin = originalSpin  -- restore',
    test_update_logic
)

with open("game/self_test.lua", "w") as f:
    f.write(code)
