# STATUS
preflight PASS 진입. INBOX 항목 「은하계 실제 고유 이름 부여」와 「우주선 추진(공기 분출)을 전방향으로 개선」을 완료했다.

- `game/world.lua`의 `M.galaxyName`을 수정하여 `gx, gy` 좌표로부터 결정론적 해시(`math.floor(hash(...) * 1000000)`)를 생성, `game/i18n.lua`에 이미 정의된 `galaxy_names`(20종)과 `galaxy_suffixes`(8종)를 조합해 고유 이름을 반환하도록 구현했다.
- `game/ship.lua`의 `M.update`를 전방향(8방향) 입력을 지원하도록 개선하여, 대각선 이동 시에도 정규화된 속도로 이동하게 했다.
- `game/scenes/play.lua`의 렌더 로직을 수정하여, 수평(bank)/수직(lift) 분사를 개별적으로 생성하지 않고, 이동 벡터의 정반대 방향을 계산해 하나로 통합된 추진 이펙트를 단일 분사구에서 내뿜도록 리팩터링했다.
- `game/self_test.lua`에 `M.galaxyName`의 결정성과 `game/ship.lua`의 상/하/좌/우/대각선 추력 벡터 크기 균일성에 대한 회귀 테스트를 추가했다.
- `make verify` 전체 GREEN 통과.
- `docs/feedback/INBOX.md`에서 두 항목을 모두 `## 처리 완료`로 이동시켰다.

다음 사이클 다음 슬라이스: 다음 우선순위 항목인 **생성 에셋 LLM 비전 검토 제외** (정책 문서화) 또는 그 다음 구현 항목(UI 아이콘 상시 노출 등 잔여 항목, 단 gear 레인과 조율 필요시 건너뜀)을 진행한다.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
