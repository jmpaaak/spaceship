# Spaceship

지구에서 출발해 최대 높이에 도전하고, 미지의 행성 표본을 모아 귀환·정산·강화하는 **세로형 모바일 로그라이트**입니다.

## 핵심 루프

- 지구에서 출발해 위로 상승
- 멀리 갈수록 가치 높은 행성 표본 획득
- 연료 0에서 자동 귀환 및 거리 기반 슬롯 머신
- 안전 귀환 시 표본을 돈으로 교환
- 우주선 구매와 연료·내구도·조종·수익 강화
- 내구도 0이면 돈·우주선·강화까지 초기화
- 개인 최고 높이만 영구 보존

## 개발 상태

현재 첫 세로 플레이 가능 slice를 개발 중입니다. Lua 도형은 gameplay 검증용 `DEV PLACEHOLDER`이며 최종 시각 에셋이 아닙니다.

모든 최종 시각 에셋은 AetherForgeAI/AetherAI 공식 UI/API 결과만 사용합니다. 자세한 계약은 [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md)를 참고하세요.

## 실행과 검증

```bash
love .
make verify LOVE=/Users/jm/.local/bin/love
```

## 저장소

이 프로젝트는 [`jmpaaak/love2d-game-skeleton`](https://github.com/jmpaaak/love2d-game-skeleton)에서 생성되었습니다.

## License

MIT — see [LICENSE](LICENSE).
