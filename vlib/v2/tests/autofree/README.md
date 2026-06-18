# V2 autofree maintainer fixtures

These files are source fixtures for V2-only `-autofree` ownership/escape work.
They are intended to be compiled explicitly.

Compile/run them with an explicit path to a self-hosted V2 binary produced for
the current source tree. Do not rely on compiler aliases or implicit tool
selection for these fixtures.
Run these fixtures in serial mode with `--no-parallel`; the V2 parallel path is
not part of this fixture contract.

See `MANIFEST.md` for the exact V2-only invocation shape.

`function_method_boundary_flow.v` is a normal external target for end-to-end
function, method, parameter, receiver and return boundary coverage. It prints
`14` and does not inspect compiler internals.

`struct_field_array_push.v` covers pushing borrowed string values into a struct
field array and returning the containing struct.

`borrowed_parent_pointer_walk.v` covers walking a parent pointer chain without
claiming ownership of borrowed nodes.

`sumtype_payload_shared_copy.v` covers copying holders that contain shared
sumtype payload values.

`borrowed_pointer_struct_fields.v` covers struct fields that store borrowed
parent pointers alongside owned child arrays.

`array_escape_global_field_map_return.v` covers arrays escaping through global,
field, map and return-value paths.

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
