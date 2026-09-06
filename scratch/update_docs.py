import re

# STATUS.md
with open("docs/STATUS.md", "r") as f:
    status = f.read()

new_slice = """## Next slice

- Process next item from `docs/feedback/INBOX.md` pending list.

## Previous

- INBOX (52b/52c) complete: Slot machine redesign — replaced 3-symbol legacy system with 5-symbol system (MONEY, PART, SPEED, DURABILITY, HARVEST), touch-to-stop reel logic, new payouts (miss=0, pair=3x, triple=10x), and PIL-generated machine frame and symbols.
- INBOX (52a) complete: PIL-generated 5 slot symbols + machine body.
"""

status = re.sub(r'## Next slice.*(?=## Previous)', new_slice, status, flags=re.DOTALL)

with open("docs/STATUS.md", "w") as f:
    f.write(status)

# INBOX.md
with open("docs/feedback/INBOX.md", "r") as f:
    inbox = f.read()

# Find the (52) item and move it.
match = re.search(r'\(52\) \*\*슬롯머신 리디자인.*? GREEN \+ 커밋 순서: \(a\) PIL 심볼\+본체 생성 \(b\) 릴 스톱 로직 \(c\) 배당 교체 \+ draw\n', inbox, flags=re.DOTALL)
if match:
    item_text = match.group(0)
    inbox = inbox.replace(item_text, "")
    inbox = inbox.replace("## 처리 완료\n", "## 처리 완료\n\n" + item_text + "\n")

with open("docs/feedback/INBOX.md", "w") as f:
    f.write(inbox)
