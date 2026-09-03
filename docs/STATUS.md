# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- INBOX 항목 11(연료 소진 관련 잔재 UI/문구 전면 제거)의 마지막 남은 작업인 (a) `launchForecastLine`/`forecast_line`의 연료 기반 프레이밍 잔재를 완전히 제거함.
  - `game/expedition.lua`에서 더 이상 사용되지 않는 연료 기반 예보 계산 함수 `M.launchForecast`를 삭제함.
  - `game/scenes/play.lua`의 `draw()` 내에 방치되어 잠재적 크래시(`printf(nil)`)를 유발할 수 있었던 `loadout.forecast`, `nextLaunch.shipPreviewForecast`, `nextLaunch.hullPreviewForecast`, `nextLaunch.forecast` 등 렌더링 코드 4곳을 모두 찾아 삭제함.
  - `game/self_test.lua`에 `testLaunchForecastRemoved()`를 추가하여 이들 기능과 변수들이 완전히 제거되었음을 단언(assert)으로 회귀 검증함.
- 토큰 최적화 규칙에 따라 항목 11이 전부 완결되었음을 확인하고 `## 처리 대기`에서 `## 처리 완료`로 이동함.
- 엔진 테스트 및 전체 검증 (`make verify`) 통과.

## Next Slice
- `docs/feedback/INBOX.md`에서 아직 완료되지 않은 잔여 UI/HUD 항목(특히 main 레인 할당분 또는 순수 UI 항목)을 찾거나, 새로운 피드백을 처리할 예정.
