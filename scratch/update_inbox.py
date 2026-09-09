import sys

with open("docs/feedback/INBOX.md", "r") as f:
    lines = f.readlines()

# find item 78 start
start_idx = -1
for i, line in enumerate(lines):
    if line.startswith("(78)"):
        start_idx = i
        break

end_idx = start_idx
for i in range(start_idx + 1, len(lines)):
    if lines[i].strip() == "" or lines[i].startswith("("):
        end_idx = i
        break

item_lines = lines[start_idx:end_idx]
del lines[start_idx:end_idx]

# append the latest progress to the last line of the item
last_line = item_lines[-1]
new_note = " [완료 2026-09-09] 대표 중심별 `star_sun_nasa_gsfc_20171208_archive_e002035`와 허브행성 `hub_neptune_nasa_pia00046`의 실제 LÖVE 런타임 캡처를 추가했다. 런타임 디코드, NEAREST 스케일링, 고유 해시 검증 결과를 `docs/assets/CELESTIAL_RUNTIME_CAPTURES.json`에 기록했다. Lane C(함선 스프라이트)는 사용자의 자격 증명 복구(human-gated)를 대기하며, 코드와 에셋 구현이 가능한 나머지 모든 범위는 완료되었으므로 '처리 완료'로 이동한다.\n"
item_lines[-1] = last_line.rstrip() + new_note

# find "## 처리 완료"
done_idx = -1
for i, line in enumerate(lines):
    if line.startswith("## 처리 완료"):
        done_idx = i
        break

# insert after "## 처리 완료"
lines.insert(done_idx + 1, "\n")
for i, line in enumerate(item_lines):
    lines.insert(done_idx + 2 + i, line)

with open("docs/feedback/INBOX.md", "w") as f:
    f.writelines(lines)
