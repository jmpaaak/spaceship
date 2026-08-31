# LÖVE2D Game Skeleton

A small, tested foundation for landscape pixel games built with LÖVE 11.5.

## Included

- 320×180 virtual canvas with nearest-neighbor scaling
- reusable viewport/input coordinate transform
- scene stack and keyboard-controlled player
- bounded headless smoke mode
- deterministic `.love` packaging with private/build-file exclusions
- Lua unit tests and GitHub Actions CI

## Run

```bash
love .
```

Move with WASD or arrow keys. Press Escape to quit.

## Verify

```bash
make verify LOVE=/path/to/love LUA=/path/to/lua
```

## Create a game

Use the repository as a GitHub template, then change the identity/title in `conf.lua` and replace `game/scenes/play.lua` with the first playable vertical slice.

## Provenance

This skeleton was distilled from reusable engine patterns in `man-of-korea`; it contains no story content, purchased assets, generated art, credentials, logs, or user data from that project.

## License

MIT — see [LICENSE](LICENSE).
