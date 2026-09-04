import re

with open('docs/feedback/INBOX.md', 'r') as f:
    content = f.read()

# Mark (5) as complete
content = content.replace(
    "(5) **패널·상점 행**",
    "(5) ✅ 완료(2026-09-05) **패널·상점 행**"
)

# Move the item to 처리 완료
match = re.search(r'## 처리 대기\n\n(- \*\*모든 시각 에셋 ComfyUI 전면 재생성.*?\n\n(?:  .*\n)+)\n## 처리 완료', content, re.DOTALL)
if match:
    item_text = match.group(1)
    # Remove from 처리 대기
    content = content.replace(item_text, "")
    # Add to 처리 완료
    content = content.replace("## 처리 완료\n", "## 처리 완료\n\n" + item_text + "\n")
    
with open('docs/feedback/INBOX.md', 'w') as f:
    f.write(content)
