## Current Status

- INBOX 59 is partially complete: the former 229,041-byte `assets/sfx/collision.mp3` is preserved byte-for-byte as `assets/sfx/collect.mp3`, and `game/sfx.lua` now routes existing planet/moon/comet `collect` calls to that clip.
- `game/tests/sfx.lua` verifies the MP3 path, format, and complete preserved length. The focused engine-hosted suite is GREEN.
- INBOX 76 was removed from pending as superseded by completed INBOX 78: the obsolete 8766-only Asset Studio/server no longer exists, with a regression test preventing its return.

## Next slice

- Finish INBOX 59 by obtaining the specified Pixabay Space Explosion with reverb (id 101449), replacing `assets/sfx/collision.mp3`, recording its license/source, and verifying planet collision volume 0.6 plus debris volume 0.9.
