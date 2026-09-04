with open('docs/feedback/INBOX.md', 'r') as f:
    lines = f.readlines()

new_lines = []
in_item = False
item_lines = []

for line in lines:
    if line.startswith("- **모든 시각 에셋 ComfyUI 전면 재생성"):
        in_item = True
        item_lines.append(line)
    elif in_item and line.startswith("## 처리 완료"):
        in_item = False
        new_lines.append(line)
        new_lines.extend(item_lines)
    elif in_item:
        if line.strip() == "(5) **패널·상점 행** — 64×64를 풀스크린으로 쓰지 말 것. 필요하면 코너/타일용 작은 PNG만 생성하고 draw는 (0)의 비-stretch 경로. 기존 `shop_panel`/`loadout_panel`/`destroyed_panel` 등 64×64 패널 PNG는 재생성하되 draw가 늘리지 않게 (0)이 선행해야 한다.":
            item_lines.append("  (5) ✅ 완료(2026-09-05) **패널·상점 행** — 64×64를 풀스크린으로 쓰지 말 것. 필요하면 코너/타일용 작은 PNG만 생성하고 draw는 (0)의 비-stretch 경로. 기존 `shop_panel`/`loadout_panel`/`destroyed_panel` 등 64×64 패널 PNG는 재생성하되 draw가 늘리지 않게 (0)이 선행해야 한다.\n")
        else:
            item_lines.append(line)
    else:
        new_lines.append(line)

with open('docs/feedback/INBOX.md', 'w') as f:
    f.writelines(new_lines)

