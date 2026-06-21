# V2 Baseline and Autofree Historical Inventory

This inventory records V2 work that must not be forgotten during V3 migration.
Each item is classified by the V3 ledger decision scheme. The entries are not a
request to preserve V2 structure; they describe what must be adapted, refused,
made obsolete, or deferred in V3 terms.

## Item: External pivot matrix tetris 2048 option_test

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Orchestrator, Team A, Team B |
| Source ref | `examples/tetris/tetris.v`, `examples/2048/2048.v`, `vlib/v/tests/options/option_test.c.v` |
| Target refs | `vlib/v3/v3.v`, `vlib/v3/gen/c/cleanc.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | V3 must first compile/run these pivots in normal C-output mode, then compare normal versus autofree C-output after a real V3 autofree mode exists |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | V3 normal C-output compile for tetris and 2048; V3 normal C-output compile/run for option_test; later repeat with autofree |
| Reviewer verdict | Current V3 state is HOLD because baseline language/library support still blocks the pivots |
| Orchestrator verdict | Deferred until Team A/Team B baseline slices pass |

## Item: V2 examples gg module shadowing baseline

| Field | Value |
| --- | --- |
| Decision | OBSOLETE |
| Validation | GO-V2 |
| Owner | Team A historical, V3 import resolver if reproduced |
| Source ref | Audit blocker where tetris/2048 resolved `examples/gg/raycaster.v` instead of `vlib/gg` |
| Target refs | `vlib/v3/v3.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Do not port V2 module-resolution code; V3 recursive import selection owns this concern and should receive only a V3 reproduction if the bug reappears |
| V3 architecture fit | OBSOLETE because the V3/upstream mechanism described by `Adaptation rule` removes the need for a migration target |
| Required tests | Existing V3 import tests plus pivot compile gates |
| Hunk hygiene | DEFER; no production V3 hunk is authorized by this obsolete historical blocker |
| Reviewer verdict | Historical V2 baseline issue; no direct V3 patch without reproduction |
| Orchestrator verdict | Obsolete unless V3 reproduces it |

## Item: V2 result option portable C baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team B after Team A checker contract |
| Source ref | `vlib/v2/gen/cleanc/result_option_portable_test.v`, `vlib/v/tests/options/option_test.c.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/or.v`, `vlib/v3/gen/c/types.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/fn.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Rebuild option/result ABI through V3 TypeChecker, transform/or, and FlatGen; no V2 CleanC spelling or payload model import |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Dedicated V3 option/result C-output tests; full `option_test.c.v` normal C-output compile/run |
| Reviewer verdict | Pending; current task is diagnostic only |
| Orchestrator verdict | Deferred until checker collisions are resolved |

## Item: V2 portable checker baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A |
| Source ref | `vlib/v2/types/checker_portable_test.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/tests/type_checker_errors_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Express only the needed compatibility in V3 structured `Type` semantics and lexical scopes |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Checker positives and negatives for params structs, result/option, print builtin, fn literals, and contextual expressions |
| Reviewer verdict | Current checker work is under separate Team A review |
| Orchestrator verdict | Not accepted until reviewer GO |

## Item: V2 math min max clip baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team B after params baseline |
| Source ref | `vlib/v2/transformer/math_inline_test.v::math.min/max/clip`, `examples/2048/2048.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/monomorphize.v`, `vlib/v3/transform/fn.v`, `vlib/v3/tests/generics_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Do not hardcode CleanC math symbols; solve V3 generic call/type inference or a V3-native intrinsic/lowering for official math functions |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | `math.abs`, `math.min`, `math.max`, `math.clip` numeric positives; local shadow negative; 2048 C-output gate |
| Reviewer verdict | Pending |
| Orchestrator verdict | Deferred after tetris params/context gates |

## Item: V2 keyword dump math child transform

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team B if V3 reproduces |
| Source ref | `vlib/v2/transformer/math_inline_test.v::dump_math_children`, `examples/2048/2048.v` |
| Target refs | `vlib/v3/transform/fn.v`, `vlib/v3/transform/expr.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | If V3 has a dump/keyword operator path, transform child expressions in the V3 flat transform pipeline only for the proven shape |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Dump around official math calls plus negative for unrelated keyword operators |
| Reviewer verdict | Pending V3 reproduction |
| Orchestrator verdict | Deferred |

## Item: V2 monomorphize owned generic bindings

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team B or Team A depending checker ownership |
| Source ref | `vlib/v2/transformer/monomorphize_test.v` |
| Target refs | `vlib/v3/transform/monomorphize.v`, `vlib/v3/types/checker.v`, `vlib/v3/tests/generics_test.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | V3 generics must use V3 flat AST and structured type facts; do not copy V2 binding maps or ownership storage |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Generic function, struct, method, transitive call, multi-param, and option/result generic canaries in V3 |
| Reviewer verdict | Pending |
| Orchestrator verdict | Deferred until after current baseline blockers |

## Item: V2 gg sokol callback ABI baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team A or Team B after V3 callback reproduction |
| Source ref | `vlib/gg/gg.c.v`, `vlib/sokol/sapp/sapp_structs.c.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/struct.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Represent exact callback signatures and adapters in V3 C-output only if the V3 pivots expose the same ABI need |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Const callback positive, incompatible callback negative, no target-name hardcode |
| Reviewer verdict | Pending V3 evidence |
| Orchestrator verdict | Deferred |

## Item: V2 markused exported C roots

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team B |
| Source ref | `vlib/v2/markused/minimal_runtime_roots_test.v::stbi_export_roots`, `examples/tetris/tetris.v` |
| Target refs | `vlib/v3/markused/markused.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Keep V3 C-output roots required by external C objects through V3 markused reachability, not by disabling dead-code elimination |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Exported callback root positive; unrelated unused function still pruned |
| Reviewer verdict | Pending V3 reproduction |
| Orchestrator verdict | Deferred |

## Item: V2 dynamic nested const array baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team A if reproduced |
| Source ref | `examples/tetris/tetris.v::b_tetros` |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Route V3 dynamic nested arrays through a V3 runtime initialization shape when static C initialization is not valid |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Nested dynamic const arrays and no regression for static scalar arrays |
| Reviewer verdict | Pending |
| Orchestrator verdict | Deferred |

## Item: V2 minimal runtime init roots

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team B |
| Source ref | `vlib/v2/transformer/minimal_runtime_init_test.v`, `vlib/v2/markused/minimal_runtime_roots_test.v` |
| Target refs | `vlib/v3/markused/markused.v`, `vlib/v3/transform/transform.v`, `vlib/v3/v3.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Keep V3 runtime lifecycle roots only for real zero-argument init/deinit or required runtime entrypoints |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Zero-arg init/deinit roots; parameterized init/deinit not lifecycle roots |
| Reviewer verdict | Pending |
| Orchestrator verdict | Deferred |

## Item: V2 struct default pointer fields baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | PATCHED |
| Owner | Team A |
| Source ref | `examples/2048/2048.v::theme`, `vlib/v2/transformer/struct_default_codegen_test.v` |
| Target refs | `vlib/v3/transform/struct.v`, `vlib/v3/gen/c/struct.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Preserve V3 struct default resolution and pointer-field non-ownership; do not treat pointer defaults as owned cleanup targets |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Qualified defaults, pointer field without default remains nil/non-owned, partial defaults retained |
| Hunk hygiene | BASELINE candidate under review; keep only if the struct-default tests prove the V3-native seam and otherwise RESTORE |
| Reviewer verdict | Pending after current Team A review |
| Orchestrator verdict | Pending |

## Item: V2 explicit autofree mode contract

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A then Team B |
| Source ref | `vlib/v2/pref/autofree_flag_test.v` |
| Target refs | `vlib/v3/pref/pref.v`, `vlib/v3/v3.v`, `vlib/v3/gen/c/cleanc.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Add a real V3 `-autofree` C-output mode contract before emitting any cleanup; `$if autofree` alone is insufficient |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | CLI flag parse, user define propagation, no cleanup without flag, cleanup allowed only with flag and supported target |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred until baseline pivots compile normally |

## Item: V2 autofree ownership fact model

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A |
| Source ref | `vlib/v2/types/autofree_facts.v`, `vlib/v2/types/autofree_facts_test.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/transform.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Rebuild ownership facts from V3 flat AST plus structured type facts after transform; do not preserve V2 fact structs if they do not fit |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Fact collection positives and negatives for each admitted cleanup shape |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 fresh local dynamic array cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B C-output |
| Source ref | `vlib/v2/types/autofree_collect_test.v::fresh_empty_dynamic_array`, `vlib/v2/gen/cleanc/autofree_test.v::array_cleanup` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Admit only V3-proven fresh local arrays and emit `array__free` from explicit facts, not from names or syntax guesses |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Positive fresh local array cleanup; negatives for params, globals, fields, aliases, branch escape, return, and storage escape |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 single-statement string-array cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B C-output |
| Source ref | `vlib/v2/types/autofree_collect_test.v::single_statement_string_array`, `vlib/v2/gen/cleanc/autofree_test.v::single_statement_string_array` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Treat the single-statement `[]string` case as a V3-proven fresh local dynamic array cleanup, with no deep string element cleanup unless a separate V3 ownership proof exists |
| V3 architecture fit | ADAPTED because it narrows the historical string-array canary to the existing V3 fresh-array fact boundary and C-output cleanup seam |
| Required tests | Positive single-statement local `[]string` header cleanup; negatives for escaped array, alias, returned array, parameter, field, and deep element free assumptions |
| Reviewer verdict | Historical V2 canary must be re-expressed through V3 facts, not copied from V2 CleanC |
| Orchestrator verdict | Deferred |

## Item: V2 autofree escape and invalidation safety boundaries

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A |
| Source ref | `vlib/v2/types/autofree_collect_test.v::global_store_rhs_*`, `vlib/v2/types/autofree_collect_test.v::invalidated_local_*` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/transform.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Treat global/field/map/array storage, reassignment, alias ambiguity, capture, address escape, defer, branch escape, and unsupported calls as fail-closed non-release facts |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Negative collector tests for each escape/invalidation class before any C-output cleanup test |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 C-output cleanup emission bridge

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team B |
| Source ref | `vlib/v2/gen/cleanc/autofree.v`, `vlib/v2/gen/cleanc/autofree_test.v` |
| Target refs | `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/cleanc.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | V3 FlatGen consumes explicit V3 facts only; it must not rediscover ownership from callee names, syntax, or reconstructed V2 CleanC state |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Generated-C positive for each admitted fact plus exact-zero no-autofree/disabled paths |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 target runtime exact-zero contracts

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team B |
| Source ref | `vlib/v2/builder/cleanc_target_e2e_test.v::test_cleanc_autofree_array_cleanup_respects_target_runtime_contract` |
| Target refs | `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Hosted V3 C-output may emit cleanup only in enabled autofree mode; disabled/no-autofree and unsupported targets must remain exact-zero |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Generated-C count canaries for enabled, disabled, freestanding, and unsupported target modes |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 same-slot multi-cleanup reverse order

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B emission |
| Source ref | `vlib/v2/gen/cleanc/autofree_test.v::same_slot_cleanup` |
| Target refs | `vlib/v3/gen/c/stmt.v`, `vlib/v3/types/checker.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | If V3 admits multiple cleanups at one insertion point, emit atomically in safe reverse lexical order from facts |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Two local arrays, exact two frees under enabled mode, zero frees otherwise |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 final clone scalar array cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B emission |
| Source ref | `vlib/v2/types/autofree_collect_test.v::fresh_scalar_array_final_clone_cleanup` |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Only V3-proven fresh local clone-transfer shapes can be cleaned; local-source clone cleanup remains rejected without separate ownership proof |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Final clone positive, local-source clone negative, generated-C placement after final clone use |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 prefixed len cap array cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B emission |
| Source ref | `vlib/v2/types/autofree_collect_test.v::prefixed_cap_len_autofree_cleanup` |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Prefix len/cap array literals must share V3’s safe fresh-local proof gate, not a V2 shape string matcher |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Prefix empty, prefix len, prefix cap positives; string-resource and escape negatives |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 cap-only scalar array cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B emission |
| Source ref | `vlib/v2/types/autofree_collect_test.v::cap_only_scalar_array_local_from_param` |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | V3 may admit cap-only cleanup only for scalar/no-resource array element types and proven non-escaping locals |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Scalar positive, string/resource negative, bad source negative |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 lowered loop clone push cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B emission |
| Source ref | `vlib/v2/types/autofree_collect_test.v::loop_local_clone_push_binding`, `examples/tetris/tetris.v` |
| Target refs | `vlib/v3/transform/for.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Recognize V3’s real lowered clone/push shape, then emit cleanup only from collector insertion points after the push |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Tetris-like row clone/push positive; receiver, field, destination, clone temp, and scalar negatives |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 receiver field slice clone nested cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts, Team B emission |
| Source ref | `vlib/v2/gen/cleanc/autofree_test.v::test_cleanc_autofree_receiver_field_slice_clone_nested_then_cleanup_generates_local_only_free`, `examples/tetris/tetris.v::Game.draw_next_tetro` |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Preserve the intent only as a V3 fact for a local clone whose last use is proven; never clean receiver fields, slices, params, or selector sources |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Cleanup inside block after final use; negatives for receiver, receiver field, selector, slice source and parameter |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 eprintln string interpolation cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team B after facts or transform ownership proof |
| Source ref | `vlib/v2/gen/cleanc/autofree_test.v::test_cleanc_autofree_eprintln_string_interpolation_cleanup_respects_target_runtime_contract` |
| Target refs | `vlib/v3/transform/fn.v`, `vlib/v3/gen/c/str_intp.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | If V3 materializes owned interpolation temporaries, cleanup must follow V3 temp ownership facts and reject local/current-module/import shadows |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Builtin eprintln positive; local, current-module and selective-import shadow negatives; exact-zero disabled paths |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 fresh local string clone push cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team A facts then Team B emission |
| Source ref | Audit selected front `text := left + right; items << text` |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/str_intp.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Admit only a fresh owned local string producer cloned into an array push, then clean only the local source after the push |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Clone-push positive; direct push, literal, parameter, field, global, map, second use, alias, and branch negatives |
| Reviewer verdict | Historical next-front diagnosis only |
| Orchestrator verdict | Deferred until V3 baseline and earlier autofree facts exist |

## Item: V2 borrowed call string cleanup

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A facts then Team B emission |
| Source ref | Partial P1 borrowed-call string checkpoint in resume |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/fn.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Prove a local owned string is borrowed by a non-escaping direct V callee, then clean after call/last use; reject every unknown/external/interface/function-pointer path |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Borrowed-call positive; method, selector, imported, C, function-pointer, interface, unknown, store, return, and mut-call negatives |
| Reviewer verdict | Historical work stopped before completion |
| Orchestrator verdict | Deferred |

## Item: V2 borrowed pointer return struct field facts

| Field | Value |
| --- | --- |
| Decision | DEFERRED |
| Validation | TODO |
| Owner | Team A facts only |
| Source ref | `vlib/v2/types/autofree_collect_test.v::test_collect_autofree_prior_local_return_struct_literal_borrowed_pointer_field_initializer_*` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/struct.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Defer until a current V3 C-output release-site slice needs this fact; it remains a safety boundary, not an active cleanup target |
| V3 architecture fit | DEFERRED because the fact can fit V3 ownership analysis later, but it is not an active release-site prerequisite for the current slice |
| Required tests | Parameter borrowed pointer to local alias to returned struct field positive; duplicate, alias chain, arbitrary local and release negatives |
| Reviewer verdict | Historical GO for V2 facts-only; V3 keeps it deferred until a release-site owner needs it |
| Orchestrator verdict | Deferred |

## Item: V2 pointer fields non-owned boundary

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts |
| Source ref | Audit repeated rule: pointer fields without explicit owned lifecycle are non-cleanup targets |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/struct.v`, `vlib/v3/gen/c/struct.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Encode pointer fields as borrowed/non-owned unless V3 introduces an explicit ownership annotation and proof |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Pointer field default and assignment do not generate cleanup; owned local cleanup does not follow through pointer field storage |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 sumtype payload ownership boundary

| Field | Value |
| --- | --- |
| Decision | DEFERRED |
| Validation | TODO |
| Owner | Future V3 ownership work |
| Source ref | Audit limitation: no sumtype payload ownership cleanup in V2 final scope |
| Target refs | `vlib/v3/types/type.v`, `vlib/v3/transform/sum.v`, `vlib/v3/gen/c/struct.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Defer until V3 has explicit ownership facts for tagged union payload movement and drop order |
| V3 architecture fit | DEFERRED because it may fit V3 later but is outside the current V3 C-output autofree scope |
| Required tests | Sumtype payload move, match, assignment and cleanup ordering canaries before any release emission |
| Reviewer verdict | Deferred by scope |
| Orchestrator verdict | Deferred |

## Item: V2 shallow array copy and element ownership boundary

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A facts then Team B emission |
| Source ref | Audit limitation: shallow local array cleanup only, no array element or external storage cleanup |
| Target refs | `vlib/v3/transform/array.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | V3 may free a proven local array header/container only for admitted shapes; element/deep cleanup needs separate explicit ownership proof |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Shallow cleanup positive; no recursive element cleanup for string arrays, map entries, fields, or external storage |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 autofree helper markused roots

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team B |
| Source ref | Audit rule: helper/root lifecycle must be protected when cleanup emission requires runtime helpers |
| Target refs | `vlib/v3/markused/markused.v`, `vlib/v3/gen/c/cleanc.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Root only helpers needed by emitted V3 C-output cleanup; do not keep all runtime functions alive |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Cleanup helper emitted when used; unrelated helpers remain prunable |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 compact autofree suite and generated C canaries

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Team A and Team B |
| Source ref | `vlib/v2/types/autofree_collect_test.v`, `vlib/v2/gen/cleanc/autofree_test.v`, compact 13-file autofree suite |
| Target refs | `vlib/v3/tests/type_checker_errors_test.v`, `vlib/v3/gen/c/tests/for_in_codegen_test.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Recreate only V3-native minimal canaries for admitted facts and C-output, not the V2 fixture framework |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Focused fact tests, generated-C canaries, target-runtime exact-zero tests, and selected external pivots |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred |

## Item: V2 normal versus autofree generated C comparisons

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | TODO |
| Owner | Orchestrator |
| Source ref | Audit generated C counters for tetris, 2048 and option_test |
| Target refs | `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Preserve the validation method: compare normal V3 C-output against autofree V3 C-output after exact baseline pass |
| V3 architecture fit | ADAPTED because the item keeps only the V3-compatible intent described by `Adaptation rule` and must use the listed V3 target seams |
| Required tests | Count and inspect `string__free`, `array__free`, and drop deltas for pivots; runtime must remain green |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred until V3 autofree mode exists |

## Item: V1 Boehm comparison reference

| Field | Value |
| --- | --- |
| Decision | REFUSED |
| Validation | GO-V2 |
| Owner | Orchestrator documentation only |
| Source ref | V1 `-gc boehm` generated-C comparison artifacts for tetris, 2048 and option_test |
| Target refs | `vlib/v3/README.md` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Do not import Boehm strategy into V3 autofree; use it only as contextual reference that broad GC and deterministic local cleanup are different proof systems |
| V3 architecture fit | REFUSED because the item does not fit V3 architecture as described by `Adaptation rule`; it remains negative evidence only |
| Required tests | None as implementation gate; optional comparison artifacts remain orchestrator evidence |
| Hunk hygiene | DEFER; no production V3 hunk may be justified by this refused Boehm comparison reference |
| Reviewer verdict | Boehm parity claim refused |
| Orchestrator verdict | Context only, not a V3 implementation target |

## Item: Full examples sweep

| Field | Value |
| --- | --- |
| Decision | DEFERRED |
| Validation | DIAG |
| Owner | Orchestrator |
| Source ref | Top-level examples sweep under V2 CleanC autofree |
| Target refs | `vlib/v3/v3.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Use broad examples only after targeted V3 baseline and autofree pivots pass; do not make broad examples a precondition for the first V3 autofree slice |
| V3 architecture fit | DEFERRED because it may fit V3 later but is outside the current V3 C-output autofree scope |
| Required tests | Later controlled examples sweep with baseline/non-autofree comparison |
| Reviewer verdict | V2 sweep evidence recorded; V3 broad sweep deferred by scope |
| Orchestrator verdict | Deferred |

## Item: Compiler self-build memory reduction claim

| Field | Value |
| --- | --- |
| Decision | DEFERRED |
| Validation | DIAG |
| Owner | Future measured memory track |
| Source ref | Resume memory checkpoint, V3 autofree self-build reached about 15 GB before SIGTERM |
| Target refs | `vlib/v3/v3.v`, `vlib/v3/gen/c/cleanc.v`, `vlib/v3/markused/markused.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Do not claim memory reduction from narrow local cleanup; open a separate measured memory matrix if that becomes the objective |
| V3 architecture fit | DEFERRED because it may fit V3 later but is outside the current V3 C-output autofree scope |
| Required tests | Identical-cache memory matrix, phase attribution, release-site counts, and controlled self-build gates |
| Reviewer verdict | V2/V3 memory evidence recorded; memory reduction claim deferred from current C-output slice |
| Orchestrator verdict | Deferred |

## Item: Freestanding no-host autofree support

| Field | Value |
| --- | --- |
| Decision | DEFERRED |
| Validation | DIAG |
| Owner | Future target work |
| Source ref | V2 exact-zero checks for freestanding linux and none modes |
| Target refs | `vlib/v3/pref/pref.v`, `vlib/v3/gen/c/cleanc.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Current V3 C-output autofree scope is hosted only; unsupported targets must remain exact-zero until a separate target contract exists |
| V3 architecture fit | DEFERRED because it may fit V3 later but is outside the current V3 C-output autofree scope |
| Required tests | Exact-zero unsupported target checks before any freestanding cleanup support |
| Reviewer verdict | V2 exact-zero evidence recorded; V3 freestanding support deferred by scope |
| Orchestrator verdict | Deferred |

## Item: Deferred Native Backends

| Field | Value |
| --- | --- |
| Decision | DEFERRED |
| Validation | TODO |
| Owner | Future backend work |
| Source ref | Audit scope notes for ARM64/X64 native backend deferral |
| Target refs | `vlib/v3/gen/arm64/gen.v`, `vlib/v3/ssa/ssa.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Do not edit native backend autofree in this PR round; keep shared facts future-compatible only when needed by C-output now |
| V3 architecture fit | DEFERRED because it may fit V3 later but is outside the current V3 C-output autofree scope |
| Required tests | None in current round; future backend-specific tests required |
| Reviewer verdict | Deferred by explicit scope |
| Orchestrator verdict | Deferred |

## Item: V2 historical tree under v2_toberemoved

| Field | Value |
| --- | --- |
| Decision | REFUSED |
| Validation | GO-V2 |
| Owner | All teams |
| Source ref | `vlib/v2_toberemoved` historical rename and merge cleanup |
| Target refs | `vlib/v3/README.md` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Never migrate by modifying `vlib/v2_toberemoved`; keep it identical to upstream and re-express only validated intent in V3 |
| V3 architecture fit | REFUSED because the item does not fit V3 architecture as described by `Adaptation rule`; it remains negative evidence only |
| Required tests | Git diff against upstream for `vlib/v2_toberemoved`; no V3 production trace of ledger decisions |
| Hunk hygiene | DEFER; this item authorizes no production V3 hunk and any accidental trace must be removed before acceptance |
| Reviewer verdict | Refused as active implementation target |
| Orchestrator verdict | Accepted rule |

## Item: V2 CleanC autofree file consolidation

| Field | Value |
| --- | --- |
| Decision | OBSOLETE |
| Validation | GO-V2 |
| Owner | Team B historical |
| Source ref | `vlib/v2/gen/cleanc/autofree.v`, `vlib/v2/gen/cleanc/autofree_test.v` |
| Target refs | `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/fn.v` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | V3 should place cleanup integration at natural FlatGen/fact-consumer seams; V2 file consolidation is historical hygiene, not an architecture constraint |
| V3 architecture fit | OBSOLETE because the V3/upstream mechanism described by `Adaptation rule` removes the need for a migration target |
| Required tests | V3 generated-C canaries around the actual files touched |
| Hunk hygiene | DEFER; V2 file consolidation is not a production V3 hunk justification |
| Reviewer verdict | Obsolete as a structural migration rule |
| Orchestrator verdict | Context only |
