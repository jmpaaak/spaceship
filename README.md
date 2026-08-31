# Spaceship

**우주선을 타고 무한한 미지의 행성들을 찾아 떠나는 탐험 게임.**

This repository was generated from [`jmpaaak/love2d-game-skeleton`](https://github.com/jmpaaak/love2d-game-skeleton) and initialized as a playable LÖVE2D prototype.

## Playable now

- Rotate with **A/D** or **Left/Right**
- Thrust with **W**, **Up**, or **Space**
- Drift through deterministic, effectively unbounded space sectors
- Discover procedural planets by flying close to them
- Track sector coordinates, fuel, and discovery count

## Run

```bash
love .
```

## Verify

```bash
make verify LOVE=/path/to/love
```

The verification target runs engine-hosted unit tests, a headless source smoke test, creates a clean `.love` package, inspects its contents, and launches the packaged game.

## Direction

See [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the exploration loop and next milestones.

## Technology

- LÖVE 11.5 / Lua
- 320×180 internal canvas
- nearest-neighbor landscape scaling
- deterministic procedural sector generation

## License

MIT — see [LICENSE](LICENSE).
