# Feedback Inbox

## 처리 대기

- **세로 상승형 로그라이트 핵심 루프 (2026-09-01, 사용자 확정, 최우선):** 지구에서 세로 화면으로 출발해 가능한 한 높이 상승하며 여러 행성의 표본을 얻는다. 멀수록 표본 가치와 위험이 증가한다. 연료가 0이면 자동 귀환하며 귀환 거리만큼 슬롯 머신 기회를 얻는다. 안전하게 지구에 도착하면 표본과 슬롯 보상을 돈으로 바꾸고 새 우주선 구매 또는 강화를 통해 다음 원정 이점을 얻는다. 행성 충돌로 내구도가 0이면 귀환 실패이며 미정산 표본뿐 아니라 보유 돈·구매 우주선·강화까지 모두 초기화하고 개인 최고 높이만 보존한다. `launch → ascending → returning/slots → settlement/shop → relaunch` 전체를 실제 플레이 가능하게 만든다.

- **AetherForgeAI/AetherAI-only 최종 에셋 (2026-09-01, 사용자 확정, 최우선):** 우주선·지구·행성·표본·이펙트·슬롯 심볼·상점 아이콘·배경을 포함한 모든 최종 시각 에셋은 공식 AetherAI UI/API에서 생성·다운로드한 결과만 사용한다. Python/Pillow·Lua 도형·다른 이미지 생성기는 최종 미술 source로 금지한다. 로그인/공식 export 전 Lua 도형은 gameplay용 `DEV PLACEHOLDER`로만 유지하고 미술 완료로 보고하지 않는다. crawling·scraping·bot·macro를 사용하지 않으며 공식 generation/asset ID, URL, terms, prompt/settings, 원본 hash와 runtime QA를 기록한다.

- **행성·이펙트 발라트로 스타일 카드형 비주얼 강화 (2026-09-02, 사용자 요청, 우선):** 사용자가 현재 행성이 "너무 밋밋하다"고 지적하며 발라트로류 카드 게임 특유의 스타일리쉬한 연출(강한 외곽 글로우/림 라이트, 부드러운 그림자, 채도 높은 그라디언트, 등급별 반짝임·파티클, 임팩트 시 스케일 펀치·흔들림)을 요청했다. 최종 텍스처는 여전히 AetherAI-only 정책을 따르되, `game/scenes/play.lua`의 Lua 도형 렌더링 레이어(외곽 글로우 링, 그라디언트 채우기, 등급별 파티클/반짝임, 표본 획득·충돌 시 pop/shake 이펙트)는 `game-effect-studio`가 만든 impact/particles/lighting 레시피를 참고해 즉시 개선 가능하며 이는 최종 텍스처 교체가 아니라 렌더링 연출이므로 AetherAI-only 제약과 무관하게 이번 사이클부터 진행한다. `world.sampleTier`(common/rare/epic)별로 색·글로우 강도·파티클 밀도를 차등화한다.

## 처리 완료
