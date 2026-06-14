# V2 autofree maintainer fixtures

These files are source fixtures for V2-only `-autofree` ownership/escape work.
They are not a runner and are intended to be compiled explicitly.

Compile/run them only with an explicit self-compiled V2 binary. Do not use the
repository root compiler, environment-provided compiler aliases, command
runners, or any legacy bootstrap path for these fixtures.

See `MANIFEST.md` for the exact V2-only invocation shape.

`boundary_canary.v` is a normal external target for end-to-end function,
method, parameter, receiver and return boundary coverage. It prints `14` and
does not inspect compiler internals.

`single_statement_array_cleanup.v` is a normal external target for generated-C
validation of an ordinary function whose body is exactly `items := []int{}`. It
prints nothing; generated C should contain `array__free(&items);` when the
bounded cleanup path is active for hosted and `-os cross` CleanC targets.

`single_statement_string_array_cleanup.v` is the matching empty dynamic array
case for `mut items := []string{}`. It validates container cleanup only:
generated C should contain `array__free(&items);` for hosted and `-os cross`
CleanC targets, but must not contain `string__free` or recursive element
cleanup.

Freestanding and no-host targets must not emit a direct `array__free(&items);`
cleanup from these fixtures until cleanup can be routed through platform-aware
hooks.
