import re

with open('docs/feedback/INBOX.md', 'r') as f:
    content = f.read()

# Extract item 28
item_28_pattern = r"(  \(28\) \*\*부스트 버튼 UI \+ 부스트 중 RCS 강화\*\*.+?이펙트 추가\.\n)"
match = re.search(item_28_pattern, content, re.DOTALL)
if match:
    item_28_text = match.group(1)
    # Remove it from the pending section
    content = content.replace(item_28_text, "")
    
    # Add it to the top of "## 처리 완료"
    completed_section = "## 처리 완료\n"
    completed_text = f"(61.28) **부스트 버튼 UI + 부스트 중 RCS 강화:**\n  - 완료: `game/scenes/play_boost.lua` 분리 생성. BOOST 버튼 우측 하단 배치 및 터치 연동 (`expedition.spendBoost`). 부스트 중 RCS 금빛 + 크기/속도 증가 + 속도선 이펙트 추가. play.lua 의존성 최소화.\n\n"
    
    content = content.replace(completed_section, completed_section + completed_text)
    
    with open('docs/feedback/INBOX.md', 'w') as f:
        f.write(content)
    print("Patched INBOX.md")
else:
    print("Could not find item 28")
