import re

with open('docs/STATUS.md', 'r') as f:
    content = f.read()

# Replace the Next slice
next_slice_pattern = r"## Next slice\n\n.*?(?=\n##|$)"
new_next_slice = "## Next slice\n\n- INBOX-61(29): 행운 % 표시 + 헬프(?) 아이콘 + 게임 설명 패널 (play_help.lua 분리)"

content = re.sub(next_slice_pattern, new_next_slice, content, flags=re.DOTALL)

with open('docs/STATUS.md', 'w') as f:
    f.write(content)
print("Patched STATUS.md")
