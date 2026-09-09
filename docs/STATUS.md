## Current Status

- Resolved INBOX 69: Remapped specimen hue families to match the four gear suits: solar (0.00-0.25), nebula (0.25-0.50), void (0.50-0.75), and pulsar (0.75-1.00).
- Replaced all legacy "azure" and "ember" occurrences with "solar" and "nebula" across JSON data, gear IDs, file paths, and test files. Localized specimen catalog using existing `i18n.lua` suit labels (솔라/네뷸라/보이드/펄서).
- Verified by `game/tests/sample_suits.lua`, full `make test`, and `make verify` (all GREEN).

## Next slice

- INBOX 70: Adjust the vertical spacing between the title scene ship and "Jimmy's" / spaceship text to 0~4px.
