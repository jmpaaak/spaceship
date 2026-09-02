# 병렬 자율개발 레인 (Parallel Autonomous Dev Lanes)

단일 `loop.sh`는 완전 순차적이라, INBOX 맨 위 항목 하나가 여러 사이클에 걸쳐
세분화(마이크로 슬라이싱)되는 동안 우선순위가 낮게 등록된(하지만 더 중요할 수
있는) 하위 항목들은 손도 못 대는 병목이 생긴다. 이를 해결하기 위해
`git worktree`로 동일 저장소의 독립 체크아웃을 여러 개 만들고, 각 체크아웃에
**서로 다른 담당 영역(레인)**을 배정해 각자의 `loop.sh`를 병렬로 돌린다.

## 핵심 아이디어

- `git worktree add`로 같은 저장소를 가리키는 여러 워킹 디렉토리를 만든다 —
  `.git` 객체 저장소는 공유하되 워킹 트리와 브랜치는 독립적이다.
- 각 worktree는 **자신만의 `loop/` 세트**(`loop.sh`/`env.sh`/`PROMPT.md`/
  `.plist`)를 가지므로 서로의 `.lock` 디렉토리를 밟지 않는다(`loop.sh`의
  `mkdir "${LOCK_DIR}"` 락은 worktree-local이라 자동으로 격리된다).
- 레인은 **파일/모듈 단위로 겹치지 않게** 나눈다 — 같은 파일을 두 레인이
  동시에 건드리면 merge 충돌이 난다. 예: UI 텍스트 레인 vs 신규 데이터+에디터
  레인 vs 월드/경제 로직 레인.
- 레인 PROMPT.md는 스켈레톤 공통 `PROMPT.md`를 베이스로 하되, 맨 위에
  "이 레인은 INBOX의 다음 항목만 처리한다"는 명시적 스코프 제약을 추가한다.

## 반드시 풀어야 할 문제와 대응책

1. **작업 중복 배정** — 두 레인이 같은 INBOX 항목을 동시에 집으면 중복 작업.
   → 레인별 PROMPT.md에 "이 레인이 담당하는 항목 번호/제목"을 하드코딩해서
   박아둔다(INBOX 전체를 자유 선택하게 두지 않는다).
2. **Git merge 충돌** — 같은 파일을 여러 레인이 동시에 수정.
   → 레인을 파일/모듈 경계로 쪼갠다(신규 파일 위주 작업은 거의 항상 안전).
   불가피하게 겹치면 병합 시 사람이 개입하거나 `merge-reconciler` 스킬로
   중재한다.
3. **공유 문서 동시 쓰기 경쟁** (`docs/STATUS.md`, `docs/feedback/INBOX.md`) —
   두 루프가 동시에 이 파일들을 고쳐 쓰면 서로의 갱신을 덮어쓸 수 있다.
   → (a) 레인마다 `docs/STATUS_<LANE>.md`처럼 레인 전용 상태 파일을 쓰게
   하거나, (b) 메인 브랜치로 병합(rebase)하기 직전에만 짧게 INBOX.md를
   갱신하고 즉시 커밋·푸시해 창을 좁힌다. (b)를 기본값으로 권장한다.
4. **원격(origin) push 경쟁** — 여러 레인이 동시에 같은 브랜치로 push하면
   비선형 히스토리 충돌. → 레인마다 **별도 브랜치**로 push하고, 사람 또는
   별도 통합 사이클이 주기적으로 `main`으로 merge한다. 레인 브랜치를 절대
   force-push하지 않는다.
5. **리소스 경쟁(CPU/API 레이트리밋)** — 레인 수만큼 LLM 요청이 동시에
   나가므로 rate limit에 더 잘 걸린다. → 각 `env.sh`의 `FALLBACK_MODEL`
   fallback 체인을 반드시 유지하고, 레인 수는 동시에 감당 가능한 API
   동시성 한도 이내로 제한한다(경험상 2~3개가 안전).

## 사용법 — `loop/scaffold_lane.sh`

```bash
loop/scaffold_lane.sh <lane-name> <worktree-parent-dir> "<scope-description>"
```

예:
```bash
loop/scaffold_lane.sh gear /Users/jm/orca/workspaces/spaceship-lanes \
  "항목 13(부품 JSON 외부화+웹 에디터) → 9(부품 20~30종+시너지) → 10(엔진 슬롯 분리) → 12(등급/에디션) → 14(효과 스키마) 순서로만 처리한다. game/scenes/play.lua, game/i18n.lua, docs/feedback/INBOX.md 처리대기 섹션 상단부는 이 레인이 건드리지 않는다(메인 레인 담당)."
```

이 스크립트는:
1. `git worktree add -b <project>-<lane-name> <parent-dir>/<lane-name> <base-branch>`
2. `loop/loop.sh`, `env.sh`, `run_agent.py`, `preflight.py`,
   `classify_provider_failure.py`, `control.sh`, `.plist`를 새 worktree로
   복사(경로만 치환)
3. 레인 전용 `PROMPT.md`(공통 PROMPT.md + 위 scope-description을 최상단에
   삽입)를 생성
4. `launchctl bootstrap`으로 등록해 즉시 백그라운드로 돌리기 시작

## 통합(머지) 주기

레인은 영원히 분리된 채로 두지 않는다 — 사람(또는 예약된 통합 작업)이
주기적으로(예: 몇 시간~하루 단위) 각 레인 브랜치를 확인해 `make verify` 통과
시 `main`으로 merge하고, 레인 worktree를 최신 `main`으로 `git reset --hard`
해 다음 배정 항목으로 재시작한다.
