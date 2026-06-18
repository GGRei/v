# V2-only autofree fixture manifest

Run these with an explicit path to a self-hosted V2 binary produced for the
current source tree. Set `V2_BIN` to that binary path before running the
commands below.

Expected command shape:

```bash
V2_BIN=/path/to/v2-self-hosted
OUT_DIR=/tmp/v2-autofree-fixtures
mkdir -p "$OUT_DIR"

"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/struct_field_array_push" vlib/v2/tests/autofree/struct_field_array_push.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/borrowed_parent_pointer_walk" vlib/v2/tests/autofree/borrowed_parent_pointer_walk.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/sumtype_payload_shared_copy" vlib/v2/tests/autofree/sumtype_payload_shared_copy.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/borrowed_pointer_struct_fields" vlib/v2/tests/autofree/borrowed_pointer_struct_fields.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/array_escape_global_field_map_return" vlib/v2/tests/autofree/array_escape_global_field_map_return.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/function_method_boundary_flow" vlib/v2/tests/autofree/function_method_boundary_flow.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/single_statement_array_cleanup" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -o "$OUT_DIR/single_statement_string_array_cleanup" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
```

`function_method_boundary_flow.v` prints `14`.
`struct_field_array_push.v` prints `1`.
`borrowed_parent_pointer_walk.v` prints `9`.
`sumtype_payload_shared_copy.v` prints `4`.
`borrowed_pointer_struct_fields.v` prints `0`.
`array_escape_global_field_map_return.v` prints `8`.
`single_statement_array_cleanup.v` prints nothing; generated C should contain
`array__free(&items);` when the bounded cleanup path is active for hosted and
`-os cross` CleanC targets.
`single_statement_string_array_cleanup.v` prints nothing; generated C should
contain only the array container cleanup for the empty `[]string{}` local. It
must not contain `string__free` or recursive element cleanup.

Generated-C target contract:

```bash
V2_BIN=/path/to/v2-self-hosted
OUT_DIR=/tmp/v2-autofree-generated-c
HOST_OS=linux
mkdir -p "$OUT_DIR"

"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -o "$OUT_DIR/single_statement_hosted" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -os cross -o "$OUT_DIR/single_statement_cross" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os "$HOST_OS" -o "$OUT_DIR/single_statement_freestanding" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os none -o "$OUT_DIR/single_statement_none" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -o "$OUT_DIR/string_array_hosted" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -os cross -o "$OUT_DIR/string_array_cross" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_BIN" --no-parallel -gc none -cc cc -backend cleanc -keepc -o "$OUT_DIR/string_array_without_autofree" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os "$HOST_OS" -o "$OUT_DIR/string_array_freestanding" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_BIN" --no-parallel -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os none -o "$OUT_DIR/string_array_none" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
```

The hosted and cross generated C should contain `array__free(&items);`.
The freestanding and no-host generated C should not contain that direct cleanup
until cleanup can be routed through platform-aware hooks.
The string-array generated C should never contain `string__free`; this fixture
only validates cleanup of an empty array container.
