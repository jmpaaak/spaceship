# Spaceship — Game Direction

## Fantasy

Pilot a small, persistent spacecraft beyond mapped space. Every sector can reveal an unknown world, strange environment, resource, signal, or story.

## Core loop

1. Read the starfield and choose a direction.
2. Manage momentum and limited fuel while crossing procedural sectors.
3. Approach an unknown planet closely enough to discover it.
4. Record the world in the ship log.
5. Decide whether to investigate, harvest, trade, repair, or continue deeper.

## Current vertical slice

- Infinite deterministic sector coordinates
- Rotation, thrust, inertia, drag, and fuel consumption
- Procedural stars and planets
- Proximity-based planet discovery counter
- Pixel-perfect 320×180 landscape presentation

## Next milestones

- Landing/exploration scene per planet archetype
- Persistent discovery log and named procedural worlds
- Fuel/resource decisions and ship upgrades
- Signals, anomalies, hazards, and encounters
- Seeded save files and expedition endings
