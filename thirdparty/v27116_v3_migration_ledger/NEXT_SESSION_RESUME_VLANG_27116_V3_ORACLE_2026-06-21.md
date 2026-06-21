# Vlang 27116 / V3 C Oracle Resume - 2026-06-21

## Hard Stop State

Work stopped on 2026-06-21 at 09:27 Europe/Paris because Codex credits are low.

Current workspace:

`/home/rei/dev-project/v27116_autofree_v3_migration_20260620`

Current branch:

`dev/v3-autofree-migration-20260620`

Current phase:

Phase 1 only: V3/C baseline oracle. Do not start Phase 2 autofree yet.

Current honest status:

The V3/C oracle is not 100% deployed yet. Seed V3 builds, the focused tests pass, and the function-value front progressed, but the seed -> self V3 chain still fails at generated C compilation because `markused` does not yet preserve all transitive runtime/helper roots.

## Absolute Process Rule

Codex is orchestrator and final validator only.

Codex must never edit production code, production tests, comments, filenames, cleanup hunks, diagnostic debris, or generated-code fixes directly.

The same pipeline is mandatory forever:

1. Diagnosticians/reviewers diagnose the blocker.
2. Orchestrator gives explicit authorization with a narrow write scope.
3. Engineer implements only inside that authorized scope.
4. Diagnosticians/reviewers return GO/HOLD.
5. Orchestrator runs validation/tests.
6. Accept or send back for rework.

Any production hunk outside that loop is invalid.

## What Was Done Since V3 Migration Started

The worktree was migrated to the new upstream V3 layout and rules:

- V3 README is the architecture source of truth.
- V2 code must adapt to V3, never the reverse.
- No native backend work belongs in this PR.
- Phase 1 targets the V3 C-output oracle only.
- Phase 2 autofree V3 starts only after Phase 1 is fully clean and pushed.
- V2 tree has been moved toward `vlib/v2_toberemoved`; do not resurrect V2 patterns.
- Ledger rules were added for V3 adaptation, no duplication, no bidouille, no internal phase/agent names, and no direct Codex code edits.

Baseline/oracle fronts already worked through and mostly validated:

- Top-level/main C oracle work.
- Conditional `$if` / `$else` top-level declarations.
- Parser control-condition fixes.
- Params struct / callback ABI work.
- Qualified struct literal authority.
- Fixed-array expected type generation.
- Function-value/callback symbol authority.
- Const alias function-value exact rooting.
- Function-value local call lowering with parameter-aware argument generation.
- Function-value tests now include imported option-return calls, const alias calls, homonym rejection, alias function types, and pointer-argument adaptation.

Important validations that passed before the current blocker:

```bash
VJOBS=1 v test vlib/v3/gen/c/tests/function_value_codegen_test.v vlib/v3/markused/markused_test.v
```

Result: `2 passed / 2 total`.

```bash
VJOBS=1 v test \
  vlib/v3/gen/c/tests/option_sumtype_codegen_test.v \
  vlib/v3/gen/c/tests/for_in_codegen_test.v \
  vlib/v3/gen/c/tests/fixed_array_codegen_test.v \
  vlib/v3/gen/c/tests/struct_init_codegen_test.v \
  vlib/v3/gen/c/tests/params_context_codegen_test.v \
  vlib/v3/gen/c/tests/function_value_codegen_test.v \
  vlib/v3/gen/c/tests/selector_method_codegen_test.v \
  vlib/v3/gen/c/tests/const_codegen_test.v \
  vlib/v3/markused/markused_test.v
```

Result: `9 passed / 9 total`.

Ledger validation passed before the latest self-chain attempt:

```bash
python3 tools/validate_ledger.py --scan-v3-markers --check-worktree-coverage ledger.md
```

## Last Fixed Blocker

The previous self-chain failure was:

`__map_val_4856` and `__map_val_4860` used before declaration in generated C for `types__TypeChecker__const_alias_fn_value_name`.

Root cause:

`tc.const_modules[...] or { ... }` was passed directly as an argument inside `if resolved := ...`, producing an unsafe V3 source shape for C output.

Engineer fix:

`vlib/v3/types/checker.v`

`const_alias_fn_value_name()` now computes:

- `const_module`
- `short_module`

before calling `const_alias_fn_value_name_for_key(...)`.

Reviewer status:

Two reviewers returned GO. They confirmed behavior preservation and no scope creep.

Validation after that fix:

- `v fmt -verify vlib/v3/types/checker.v`: passed.
- `git diff --check -- vlib/v3/types/checker.v`: passed.
- Focused tests: passed.
- Short bundle: passed.

The `__map_val_*` problem is gone.

## Current Blocker

Current self-chain command attempted:

```bash
/usr/bin/time -v env VJOBS=1 v -o /tmp/v3_migration_seed_fnvalue_recheck2 vlib/v3 && \
/usr/bin/time -v env VJOBS=1 /tmp/v3_migration_seed_fnvalue_recheck2 vlib/v3/v3.v -o /tmp/v3_migration_self_fnvalue_recheck2 && \
/usr/bin/time -v env VJOBS=1 /tmp/v3_migration_self_fnvalue_recheck2 vlib/v3/v3.v -o /tmp/v3_migration_self2_fnvalue_recheck2 && \
/usr/bin/time -v env VJOBS=1 /tmp/v3_migration_self2_fnvalue_recheck2 vlib/v3/v3.v -o /tmp/v3_migration_self3_fnvalue_recheck2 && \
/tmp/v3_migration_self3_fnvalue_recheck2 version
```

Stage 1 passed:

- `v -o /tmp/v3_migration_seed_fnvalue_recheck2 vlib/v3`
- Max RSS: about 407 MB.

Stage 2 failed during C compilation:

```text
strconv__f64_to_str_l calls strconv__f64_to_str but strconv__f64_to_str is not emitted
strconv__f64_to_str_l calls strconv__fxx_to_str_l_parse but strconv__fxx_to_str_l_parse is not emitted
bench__Bench__step calls time__StopWatch__elapsed but time__StopWatch__elapsed is not emitted
```

Stage 2 max RSS stayed low:

- About 190 MB.
- No swap issue.

## Reviewer Diagnosis For Current Blocker

Reviewer consensus:

This is a `markused` call-graph/rooting incompleteness, not a C compiler problem and not an autofree problem.

Two concrete root causes were identified:

- C-lowered synthetic aliases such as `strconv__f64_to_str_l` can be queued/emitted, but BFS does not reliably traverse the canonical V declaration body such as `strconv.f64_to_str_l`, so transitive callees like `strconv.f64_to_str` and `strconv.fxx_to_str_l_parse` are missed.
- Chained method calls such as `b.step_sw.elapsed().microseconds()` root the outer method but skip nested receiver calls, so `time.StopWatch.elapsed` is missed.

No-go fixes:

- Do not hardcode roots for `strconv` or `time`.
- Do not root all modules.
- Do not widen suffix fallback.
- Do not add dummy C prototypes.
- Do not touch CGen, transform, V2, native backends, or autofree for this blocker.

Authorized current write scope before stop:

- `vlib/v3/markused/markused.v`
- `vlib/v3/markused/markused_test.v`

Engineer result received during shutdown:

- `vlib/v3/markused/markused.v` was updated to add exact C-lowered synthetic-name canonicalization toward canonical V declaration keys.
- `vlib/v3/markused/markused.v` was updated so selector receiver expressions are traversed enough to keep nested method calls like `elapsed().microseconds()`.
- `vlib/v3/markused/markused_test.v` received focused canaries for synthetic `module__fn` traversal, nested receiver calls, and no function-value homonym/suffix leak.

Engineer-reported validations:

```bash
v fmt -verify vlib/v3/markused/markused.v vlib/v3/markused/markused_test.v
git diff --check -- vlib/v3/markused/markused.v vlib/v3/markused/markused_test.v
v test vlib/v3/markused/markused_test.v
```

Reported result: all passed.

Important: this markused patch has not yet received post-implementation reviewer GO and has not yet passed orchestrator self-chain validation. Treat it as implemented-but-pending-review, not accepted.

## Important Worktree Note

`git status` is very large because the V3 migration includes many upstream/V3 files and the V2-to-be-removed tree.

There are also untracked diagnostic-looking files at repository root:

- `-version.c`
- `version.c`

Do not let Codex remove them directly. If they must be removed, that cleanup must go through the same engineer/reviewer/orchestrator pipeline.

## Resume Checklist

On next session:

1. Start guard before any build/test:

```bash
systemctl --user start iag-system-guard.service
systemctl --user is-active iag-system-guard.service
free -h
```

2. Re-read:

```text
/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md
/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md
/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_V3_ORACLE_2026-06-21.md
/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md
/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md
```

3. Reactivate two external-dependency teams:

- Team A: 1 engineer + 2 diagnostician/reviewers.
- Team B: 1 engineer + 2 diagnostician/reviewers.

4. Make all agents re-read their role and the docs above.

5. Resume only the current blocker:

`markused` canonical alias + nested receiver call roots.

6. First action after restart: get reviewer GO/HOLD on the markused implementation already present in:

```text
vlib/v3/markused/markused.v
vlib/v3/markused/markused_test.v
```

No new implementation before that review.

7. If reviewers return GO, run:

```bash
v fmt -verify vlib/v3/markused/markused.v vlib/v3/markused/markused_test.v
git diff --check -- vlib/v3/markused/markused.v vlib/v3/markused/markused_test.v
VJOBS=1 v test vlib/v3/markused/markused_test.v
VJOBS=1 v test vlib/v3/gen/c/tests/function_value_codegen_test.v vlib/v3/markused/markused_test.v
```

Then run the short bundle again:

```bash
VJOBS=1 v test \
  vlib/v3/gen/c/tests/option_sumtype_codegen_test.v \
  vlib/v3/gen/c/tests/for_in_codegen_test.v \
  vlib/v3/gen/c/tests/fixed_array_codegen_test.v \
  vlib/v3/gen/c/tests/struct_init_codegen_test.v \
  vlib/v3/gen/c/tests/params_context_codegen_test.v \
  vlib/v3/gen/c/tests/function_value_codegen_test.v \
  vlib/v3/gen/c/tests/selector_method_codegen_test.v \
  vlib/v3/gen/c/tests/const_codegen_test.v \
  vlib/v3/markused/markused_test.v
```

Then rerun the self-chain:

```bash
/usr/bin/time -v env VJOBS=1 v -o /tmp/v3_migration_seed_after_markused vlib/v3 && \
/usr/bin/time -v env VJOBS=1 /tmp/v3_migration_seed_after_markused vlib/v3/v3.v -o /tmp/v3_migration_self_after_markused && \
/usr/bin/time -v env VJOBS=1 /tmp/v3_migration_self_after_markused vlib/v3/v3.v -o /tmp/v3_migration_self2_after_markused && \
/usr/bin/time -v env VJOBS=1 /tmp/v3_migration_self2_after_markused vlib/v3/v3.v -o /tmp/v3_migration_self3_after_markused && \
/tmp/v3_migration_self3_after_markused version
```

8. Only after self-chain passes, continue Phase 1 gates:

- `examples/tetris` compile and run correctly.
- `examples/2048` compile and run correctly.
- `vlib/v/tests/options/option_test.c.v` full green via V3.
- Hygiene PR review.
- Ledger/audit green.

9. Only then commit and push Phase 1 on a new GGRei/v branch.

10. Only after that start Phase 2 autofree V3. No Phase 2 commit/push without explicit user authorization.

## Current Completion Estimate

Phase 1 is not ready to PR.

Estimated state:

- V3 migration/oracle scaffolding: advanced.
- Function-value front: mostly validated.
- Self-chain: blocked at markused transitive roots.
- Tetris/2048/options final gates: not currently valid because self-chain is blocked.
- Autofree V3 Phase 2: not started and must remain blocked until Phase 1 is pushed.
