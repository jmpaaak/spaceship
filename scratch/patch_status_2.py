with open('docs/STATUS.md', 'r') as f:
    lines = f.readlines()

insert_idx = -1
for i, line in enumerate(lines):
    if line.startswith("## Next slice"):
        insert_idx = i
        break

if insert_idx != -1:
    lines.insert(insert_idx, "- INBOX 61(28): Boost button UI & Boost FX\n")
    lines.insert(insert_idx + 1, "  - Created `game/scenes/play_boost.lua` to extract boost logic and avoid bloating `play.lua`.\n")
    lines.insert(insert_idx + 2, "  - Added BOOST button UI in bottom-right corner with charge counter.\n")
    lines.insert(insert_idx + 3, "  - Enhanced RCS particles during boost (golden color, 2.5x radius, faster spawn).\n")
    lines.insert(insert_idx + 4, "  - Added vertical speed lines visual effect during boost.\n\n")

with open('docs/STATUS.md', 'w') as f:
    f.writelines(lines)
