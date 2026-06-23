# Dungeon Async Executor Demo

A small `gg` dungeon crawler demo showing how `gg`, `x.async`, and
`x.executor` fit together:

- `dungeon_core` owns pure game state, commands, generation, and snapshots.
- `dungeon_gg` owns the window, input adapter, owner executor, async pool,
  material registry, and rendering.
- Every `GameState` mutation after startup runs through short `x.executor`
  jobs drained by the frame loop with a fixed budget.
- Key `m` submits bounded background generation through `x.async.Pool`; workers
  generate and clone payloads, then post owner apply/failure jobs.
- Rendering uses semantic material IDs mapped to colors today and texture keys
  later; no texture loading or direct Sokol code is part of the MVP.

Controls:

- QWERTY: `w` / `s` move forward/back, `q` / `e` strafe left/right,
  `a` / `d` turn left/right
- AZERTY: `z` / `s` move forward/back (`w` is accepted as an alias),
  `a` / `e` strafe left/right, `q` / `d` turn left/right
- left/right arrows: turn left/right aliases
- `f`: interact
- `m`: request async dungeon generation
- `escape`: quit

The AZERTY profile keeps user-facing key labels in the HUD even on backends
that report `q`/`a` as physical QWERTY-style key codes.

Keyboard layout is auto-detected best-effort on Linux, macOS, and Windows. The
portable override variables are checked first:
`DUNGEON_KEYBOARD_LAYOUT=qwerty|azerty` or
`DUNGEON_ASYNC_EXECUTOR_KEYBOARD_LAYOUT=qwerty|azerty`.

Without an override, the demo checks OS-specific probes when available:
`localectl`/`setxkbmap` on Linux, PowerShell language input tips on Windows,
and Apple keyboard layout defaults on macOS. It then uses portable environment
and locale hints. Missing commands, empty output, and non-zero exits are
ignored. The final fallback is QWERTY, so use an override if auto-detection is
wrong.

Run from the repository root:

```sh
./v run examples/dungeon_async_executor
```

Build and test:

```sh
./v test examples/dungeon_async_executor
./v -o /tmp/dungeon_async_executor_demo examples/dungeon_async_executor
```
