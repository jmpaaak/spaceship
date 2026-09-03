import re

with open('docs/feedback/INBOX.md', 'r', encoding='utf-8') as f:
    text = f.read()

# Split into pending and completed sections
parts = text.split("## 처리 완료")
pending = parts[0]
completed = parts[1] if len(parts) > 1 else ""

# Extract the two blocks
pattern1 = r"(?s)(- \*\*UI 대개편 6건.*?(?=\n\n\n|\n- \*\*))"
match1 = re.search(pattern1, pending)
block1 = match1.group(1) if match1 else ""

pattern2 = r"(?s)(- \*\*생성 에셋 LLM 비전 검토 제외.*?(?=\n\n- \*\*))"
match2 = re.search(pattern2, pending)
block2 = match2.group(1) if match2 else ""

# Remove them from pending
if block1:
    pending = pending.replace(block1, "")
if block2:
    pending = pending.replace(block2, "")

# Clean up empty lines
pending = re.sub(r'\n{3,}', '\n\n', pending)

# Insert them at the top of completed
new_completed = "\n\n"
if block1:
    new_completed += block1.strip() + "\n\n"
if block2:
    new_completed += block2.strip() + "\n\n"
new_completed += completed.lstrip()

with open('docs/feedback/INBOX.md', 'w', encoding='utf-8') as f:
    f.write(pending + "## 처리 완료" + new_completed)
