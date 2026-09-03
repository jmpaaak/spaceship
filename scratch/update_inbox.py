import re

with open('docs/feedback/INBOX.md', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    if line.strip().startswith("3. **슬롯(부품) UI를 화면 좌/우측 네모 칸 아이콘 그리드로 전환 + 마우스오버 카드 설명:**"):
        line = line.replace("3. **슬롯", "3. ✅ 완료(2026-09-03, main 레인) — **슬롯")
        line = line.replace("마우스오버 카드 설명:**", "마우스오버 카드 설명:** `forecast_line` 텍스트 자체 제거 및 관련 로직 정리를 완료함. (UI에 카드 상시 노출 및 데이터 연동 작업은 `spaceship-gear` 레인이 항목9/13/14 완료 이후 이어서 처리하므로 main 레인 기준 1차 완료 처리).")
    new_lines.append(line)

with open('docs/feedback/INBOX.md', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)
