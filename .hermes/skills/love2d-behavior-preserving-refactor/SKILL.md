---
name: love2d-behavior-preserving-refactor
description: Refactor LÖVE2D code without changing behavior
version: 1.0.0
metadata:
  hermes:
    tags: [lua, love2d, refactoring, testing]
    category: development
---

# LÖVE2D Behavior-Preserving Refactoring

## When to Use

Use this skill when splitting or cleaning a LÖVE2D Lua project while its game
rules, frame behavior, controls, persistence, and public APIs must remain
unchanged. It is especially useful before adding features to an oversized
scene, callback, state module, or test runner.

Do not use a structural refactor as cover for balance, policy, asset, copy, or
test-expectation changes. Make those separate, reviewable slices.

## Procedure

1. Establish the behavior contract before moving code.
   - Locate the project's real test and verification commands.
   - Add or identify characterization coverage for the responsibility being
     moved. Observe a meaningful failure before implementing missing coverage.
   - Record the public module API, callback consumption order and return
     booleans, mutable module state and object identity, RNG seeds/sources,
     update order, and deterministic table traversal assumptions.

2. Scan only the target responsibility and classify findings.
   - Mark dead code, duplicate helpers, magic values, long argument lists, and
     repeatedly created objects.
   - Trace callers and references before deciding that code is unused.
   - Keep findings outside the chosen slice on a follow-up list; do not combine
     unrelated cleanup.

3. Choose one responsibility and one pattern for the slice.
   - Use Extract Module or Extract Function for a cohesive rule or adapter.
   - Use a named constant only when the value's meaning and scope are stable.
   - Use a parameter table when a long argument list represents one concept.
   - Reuse immutable or explicitly reset objects only when identity and
     mutation cannot leak between frames or callers.
   - Avoid broad regex replacement. Move the smallest coherent block and
     update explicit references.

4. Separate pure rules from framework adapters.
   - Pure rule modules must not read or call `love.*`; pass time, input, RNG,
     configuration, and state through a small API.
   - Keep graphics, audio, filesystem, window, and callback integration in a
     thin LÖVE adapter.
   - Preserve callback consumption order, pointer capture through release,
     module state lifetime, draw/update ordering, and determinism.

5. Preserve compatibility at the old boundary.
   - Require the extracted module and delegate through the existing public API
     when callers cannot move in the same slice.
   - Preserve argument defaults, return value count, consumed booleans, side
     effect timing, error behavior, and singleton-versus-instance semantics.
   - Do not approve changed snapshots or weaken assertions to make the move
     pass.

6. Verify, then update references.
   - Run the focused characterization test, then the project's existing full
     test and package/verification commands.
   - Search for stale symbols, duplicated implementations, and accidental new
     `love.*` calls in the pure module.
   - Only after GREEN, update imports, module maps, status notes, and the exact
     next extraction slice.

## Verification

- The same inputs and RNG seed produce the same state and outputs.
- Callback consumption order and pointer ownership are unchanged.
- Existing public entry points still work through compatible delegation.
- Pure modules load in an engine-hosted test without invoking `love.*`.
- No production policy, balance value, or expected behavior changed.
- Focused tests and all existing project checks pass without re-approval.
- The source file is materially smaller and only one responsibility moved.