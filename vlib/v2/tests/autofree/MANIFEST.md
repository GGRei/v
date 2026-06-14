# V2-only autofree fixture manifest

Run these only with an explicit self-compiled V2 binary. `V2_NEXT` below must
not resolve to the repository root compiler, an environment-provided compiler
alias, a command runner, or any legacy-bootstrap test path.

Expected command shape after `-autofree` routing and autofree support are
implemented:

```bash
"$V2_NEXT" -autofree -o "$ART/af_family1" vlib/v2/tests/autofree/family1_shallow_array_push.v
"$V2_NEXT" -autofree -o "$ART/af_family2" vlib/v2/tests/autofree/family2_pointer_local_non_owning.v
"$V2_NEXT" -autofree -o "$ART/af_family3" vlib/v2/tests/autofree/family3_sumtype_payload_shared.v
"$V2_NEXT" -autofree -o "$ART/af_family4" vlib/v2/tests/autofree/family4_pointer_struct_fields.v
"$V2_NEXT" -autofree -o "$ART/af_family5" vlib/v2/tests/autofree/family5_escape_global_field_map_return.v
"$V2_NEXT" -autofree -o "$ART/af_boundary_canary" vlib/v2/tests/autofree/boundary_canary.v
"$V2_NEXT" -autofree -o "$ART/af_single_statement_array_cleanup" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_NEXT" -autofree -o "$ART/af_single_statement_string_array_cleanup" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
```

`boundary_canary.v` prints `14`.
`single_statement_array_cleanup.v` prints nothing; generated C should contain
`array__free(&items);` when the bounded cleanup path is active for hosted and
`-os cross` CleanC targets.
`single_statement_string_array_cleanup.v` prints nothing; generated C should
contain only the array container cleanup for the empty `[]string{}` local. It
must not contain `string__free` or recursive element cleanup.

Generated-C target contract:

```bash
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -o "$ART/af_single_statement_hosted" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -os cross -o "$ART/af_single_statement_cross" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os "$HOST_OS" -o "$ART/af_single_statement_freestanding" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os none -o "$ART/af_single_statement_none" vlib/v2/tests/autofree/single_statement_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -o "$ART/af_string_array_hosted" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -os cross -o "$ART/af_string_array_cross" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_NEXT" -gc none -cc cc -backend cleanc -keepc -o "$ART/no_af_string_array" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os "$HOST_OS" -o "$ART/af_string_array_freestanding" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
"$V2_NEXT" -autofree -gc none -cc cc -backend cleanc -keepc -freestanding -os none -o "$ART/af_string_array_none" vlib/v2/tests/autofree/single_statement_string_array_cleanup.v
```

The hosted and cross generated C should contain `array__free(&items);`.
The freestanding and no-host generated C should not contain that direct cleanup
until cleanup can be routed through platform-aware hooks.
The string-array generated C should never contain `string__free`; this fixture
only validates cleanup of an empty array container.
