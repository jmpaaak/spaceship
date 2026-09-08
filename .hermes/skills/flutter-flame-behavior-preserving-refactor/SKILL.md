---
name: flutter-flame-behavior-preserving-refactor
description: Refactor Flutter+Flame code without changing behavior
version: 1.0.0
metadata:
  hermes:
    tags: [dart, flutter, flame, refactoring, testing]
    category: development
---

# Flutter+Flame Behavior-Preserving Refactoring

## When to Use

Use this skill when splitting or cleaning a Flutter application with a Flame
game skeleton while gameplay, rendering, controls, navigation, and persistence
must remain unchanged. Apply it before adding behavior to an oversized
`FlameGame`, component, widget, input handler, or test harness.

Keep balance, product policy, visual redesign, dependency upgrades, and changed
test expectations out of a structural refactor.

## Procedure

1. Establish the behavior contract before moving code.
   - Locate the repository's real analyze, test, and build commands.
   - Add or identify characterization tests for the responsibility being
     moved, and observe a meaningful failure for newly added coverage.
   - Record public Dart APIs, component lifecycle order, input propagation and
     handled-event semantics, overlay/router ordering, mutable singleton state,
     tick order, clocks, RNG seeds, and collection ordering.

2. Scan the target responsibility and classify findings.
   - Mark dead code, duplicate helpers, magic values, long argument lists, and
     repeatedly created objects such as immutable styles or paints.
   - Trace constructors, mixins, registrations, routes, assets, and callers
     before treating anything as unused.
   - Defer unrelated findings rather than mixing cleanup patterns.

3. Select one responsibility and one pattern.
   - Use Extract Class/Component for one lifecycle-owned behavior.
   - Use Extract Method for a cohesive calculation.
   - Use a named constant only when its meaning and scope are stable.
   - Use an immutable configuration/value object for a long argument list that
     represents one concept.
   - Reuse only immutable resources or lifecycle-owned objects; never share a
     mutable `Vector2`, paint, timer, or component merely to reduce allocation.
   - Avoid broad regex replacement and update explicit references only.

4. Separate pure rules from Flutter and Flame adapters.
   - Put deterministic domain calculations in plain Dart modules without
     Flutter widgets, Flame components, rendering, or platform channels.
   - Keep `FlameGame`, component lifecycle, canvas/rendering, gestures, keys,
     overlays, and services in thin adapters.
   - Pass elapsed time, input, RNG, configuration, and state explicitly across
     the boundary.

5. Preserve lifecycle and compatibility.
   - Keep `onLoad`, `onMount`, update/render, removal, pause/resume, and disposal
     timing and ordering intact.
   - Preserve component priorities, input propagation, gesture pointer IDs,
     route/overlay behavior, constructor defaults, return values, exceptions,
     and singleton-versus-instance semantics.
   - Delegate from the old public boundary when all callers cannot move in the
     same slice. Do not weaken assertions or reapprove visual goldens.

6. Verify, then update references.
   - Run focused unit/widget/game tests, then the project's existing analyzer,
     full tests, and build/package checks.
   - Search for stale imports and duplicate implementations, and confirm the
     pure module has no Flutter or Flame dependency.
   - After GREEN, update imports, registrations, architecture notes, and the
     exact next extraction slice.

## Verification

- Fixed elapsed-time and RNG inputs preserve determinism and outputs.
- Component lifecycle, priorities, input propagation, and overlays are
  unchanged.
- Existing public constructors and methods remain compatible.
- Pure Dart rules run without a Flutter binding or Flame engine.
- No policy, balance, UI behavior, or approved golden changed.
- Focused tests and all existing repository checks pass.
- One responsibility moved and the original owner became materially smaller.