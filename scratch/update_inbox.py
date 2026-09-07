with open("docs/feedback/INBOX.md", "r") as f:
    lines = f.readlines()

# Extract lines 89-97 (0-indexed 88-97)
block = lines[88:97]
# Add "완료: " prefix to the last line or add a new line
block.append("    - 완료: Python 스크립트로 JSON 전수 재조정 완료. common(단일), uncommon(복합2), rare(multiply), legendary(flat+multiply) 적용. test fixtures(engine_emergency_boost_pod 등) 예외 처리 후 테스트 GREEN.\n")

# Strike out the title
block[0] = block[0].replace("(26) **부품 밸런스", "~~(26) **부품 밸런스").replace(")** (msg", ")**~~ (msg")

del lines[88:97]

# Find "## 처리 완료"
idx = lines.index("## 처리 완료\n")
lines.insert(idx + 1, "".join(block) + "\n")

with open("docs/feedback/INBOX.md", "w") as f:
    f.writelines(lines)
