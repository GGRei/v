# V Issue 27116 - V3 Migration Decision Ledger

## Initial Chantiers Setup Controls

The following items preserve the start-of-chantier constraints as validated
ledger entries, not as untracked prose.

## Item: Clean V3 migration workspace and GGRei master baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Worktree `/home/rei/dev-project/v27116_autofree_v3_migration_20260620` created for the V3 migration against the initial GGRei/master V3 baseline |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Treat the clean worktree and upstream V3 baseline as the migration reference; do not preserve divergent V2 checkpoint files as active code |
| V3 architecture fit | ADAPTED because it anchors migration work to the real V3 upstream baseline before any V2 intent is re-expressed |
| Required tests | `git status --short`; `git diff --exit-code origin/master -- vlib/v2_toberemoved` when checking old-tree hygiene |
| Hunk hygiene | BASELINE workspace reference only; this item does not accept a production V3 hunk |
| Reviewer verdict | Accepted as the baseline reference rule |
| Orchestrator verdict | GO-V2 |

## Item: V2 intent adapts to V3 premium rule

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | All teams |
| Source ref | Owner premium rule: V2 code and ideas must adapt to V3; V3 must not be bent to V2 |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/inventory_v2.md` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Every retained V2 behavior must be re-expressed through a natural V3 parser, checker, transform, markused or C-output seam |
| V3 architecture fit | ADAPTED because the rule explicitly protects V3 architecture and rejects direct V2 shape imports |
| Required tests | Ledger validation plus reviewer check that every item has `Adaptation rule` and `V3 architecture fit` |
| Reviewer verdict | Hard refusal criterion accepted |
| Orchestrator verdict | GO-V2 |

## Item: Maintainer issue 27116 autofree CI re-enable super gate

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator, Team A facts, Team B C-output |
| Source ref | https://github.com/vlang/v/issues/27116 |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/inventory_v2.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/examples/tetris/tetris.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v/tests/options/option_test.c.v` |
| Docs | https://github.com/vlang/v/issues/27116, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/inventory_v2.md` |
| Adaptation rule | Treat issue #27116 as the high-priority autofree CI re-enable gate: CI may be re-enabled only after a self-compiled autofree compiler compiles a representative subset without aborts, explicitly including `examples/tetris` and `vlib/v/tests/options/option_test.c.v`. Track these known bug classes as fail-closed blockers before any autofree runtime claim: shared sub-buffers via shallow array push; non-owning pointer locals; sumtype payload double-free; pointer struct fields treated as owned; locals leaked into globals/struct fields. Required V3 design approach: real ownership model and escape analysis for locals stored into external storage; idempotent `_free` for shared types where relevant; do not auto-emit `_free` for pointer struct fields by default; do not `_v_free` the variant box inside auto-generated sumtype `_free`. Historical maintainer wording focused V2, but this workspace adapts the issue intent to current V3 C-output chantier because V3 supersedes the V2 path here; no V1 work and no V2 shape copying are authorized. Inventory links: `inventory_v2.md::V2 autofree escape and invalidation safety boundaries`, `inventory_v2.md::V2 shallow array copy and element ownership boundary`, `inventory_v2.md::V2 pointer fields non-owned boundary`, `inventory_v2.md::V2 sumtype payload ownership boundary`. |
| V3 architecture fit | ADAPTED because the maintainer CI gate is re-expressed as V3 baseline plus V3 ownership-fact and V3 C-output proof requirements, while refusing V1 work, V2 shape copying, and native backend patches in this round |
| Required tests | Mandatory route before CI re-enable: build a self-compiled autofree compiler, then compile the representative subset without aborts, including `examples/tetris` and `vlib/v/tests/options/option_test.c.v`; add focused V3 ownership tests for shallow array push sharing, non-owning pointer locals, sumtype payload boxes, pointer struct fields, and locals escaping to globals/struct fields before generated-C cleanup tests |
| Reviewer verdict | Accepted as ledger super-rule; individual bug families remain in inventory items and must receive reviewer GO before implementation |
| Orchestrator verdict | GO-V2 for ledger rule only; autofree CI re-enable remains blocked until the required V3 tests pass |

## Item: Mandatory V3 README pre-read

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | All engineers and reviewers |
| Source ref | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Use the V3 README as the first architecture source before diagnosing or changing V3 code |
| V3 architecture fit | ADAPTED because it forces every migration decision to start from documented V3 architecture |
| Required tests | Reviewer checklist must confirm README was read before implementation review |
| Reviewer verdict | Accepted as mandatory context |
| Orchestrator verdict | GO-V2 |

## Item: V3 C-output only chantier scope

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Current chantier scope: V3 C-output only for issue 27116; ARM64/X64/native backend work deferred |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/inventory_v2.md` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Allow only V3 C-output baseline/autofree work in this round; native backend concerns may be recorded but not patched |
| V3 architecture fit | ADAPTED because it confines current work to V3 C-output seams and leaves backend-specific architecture untouched |
| Required tests | Ledger validator must reject native backend target refs outside `Deferred Native Backends` |
| Reviewer verdict | Accepted scope boundary |
| Orchestrator verdict | GO-V2 |

## Item: No duplication hack or example hardcode rule

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | All teams |
| Source ref | Review rule: no duplication, no bidouille, no hardcoded example-specific fixes |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/tools/validate_ledger.py` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Prefer canonical V3 helpers and architecture seams; reject local duplicate helpers, probe-only branches, and example-name checks |
| V3 architecture fit | ADAPTED because it keeps V3 implementation general and prevents test-pivot special cases from shaping production code |
| Required tests | Reviewer diff inspection plus focused regression tests for the actual general seam touched |
| Reviewer verdict | Accepted as reviewer HOLD/NO-GO criterion |
| Orchestrator verdict | GO-V2 |

## Item: Production hunk hygiene and upstream restore gate

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | All teams |
| Source ref | User golden rule: any bad, useless, probe-only, or superseded code must be removed and restored to upstream shape |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3` |
| Docs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Each touched production hunk must be classified as `KEEP`, `BASELINE`, `REWORK`, `RESTORE`, or `DEFER`; `RESTORE` hunks return to upstream shape, `REWORK` hunks block acceptance, and `BASELINE` hunks must cite their earlier accepted ledger/audit provenance |
| V3 architecture fit | ADAPTED because V3 migration acceptance is based on explicit hunk provenance and upstream-restore decisions instead of leaving dead migration experiments in production code |
| Required tests | Reviewer diff classification before `GO-V2`; focused regression tests for `KEEP` and `BASELINE`; no production hunk with `REWORK` or `RESTORE` may remain in final diff |
| Hunk hygiene | KEEP as an external ledger/validator rule; no production V3 code hunk is introduced by this item |
| Reviewer verdict | Accepted as hard review gate |
| Orchestrator verdict | GO-V2 |

## Item: Historical V3 changed-file hygiene backlog

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | All teams |
| Source ref | Retroactive worktree coverage scan over `git diff --name-only -- vlib/v3` |
| Target refs | `vlib/v3/bench/bench.v`, `vlib/v3/flat/flat.v`, `vlib/v3/markused/markused_test.v`, `vlib/v3/ssa/optimize/cfg.v`, `vlib/v3/ssa/optimize/dominators.v`, `vlib/v3/ssa/optimize/fold.v`, `vlib/v3/ssa/optimize/mem2reg.v`, `vlib/v3/ssa/optimize/phi.v`, `vlib/v3/ssa/optimize/verifier.v`, `vlib/v3/tests/for_in_codegen_test.v`, `vlib/v3/tests/parser_c_output_shape/parser_c_output_shape_test.v`, `vlib/v3/tests/parser_c_output_shape_test.v`, `vlib/v3/tests/qualified_alias_multireturn/qualified_alias_multireturn_test.v`, `vlib/v3/tests/ssa_optimize_dominators_test.v`, `vlib/v3/tests/ssa_optimize_mem2reg_test.v`, `vlib/v3/tests/ssa_optimize_phi_test.v` |
| Docs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Treat these historical V3 edits as unresolved hygiene backlog until each file is either classified by a narrower ledger item or restored to upstream shape; this item is only a signal, not acceptance |
| V3 architecture fit | ADAPTED because the backlog forces V3 touched files to be reviewed against V3 architecture before any PR-ready claim |
| Required tests | `python3 tools/validate_ledger.py --check-worktree-coverage ledger.md`; reviewer classification for every listed file before final `GO-V2` |
| Hunk hygiene | REWORK for all listed files until narrower KEEP, BASELINE, DEFER, or removal decisions replace this backlog classification |
| Reviewer verdict | HOLD pending per-file classification |
| Orchestrator verdict | Not accepted as final PR hygiene |

## Item: V3 autofree target issue coverage gate

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator and all reviewers |
| Source ref | User rule: autofree cleanup signaling must restart from the beginning of the chantier and stay tied to maintainer issue #27116 |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/tools/validate_ledger.py`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/pref/pref.v` |
| Docs | https://github.com/vlang/v/issues/27116, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Any changed V3 production file whose relative or absolute target path, filename, directory path, current content, staged diff, unstaged diff, untracked content or intent-to-add content mentions `autofree` must be covered by a ledger item that links to the maintainer issue #27116 super gate before it can be accepted; this includes `is_autofree`, `autofree_flag`, and future `vlib/v3/autofree/foo.v` implementation files. A broad target such as `vlib/v3` is never sufficient for this autofree issue coverage: the covering item must target the exact file or an explicit relevant subdirectory such as `vlib/v3/autofree/`, so V3 autofree helpers, flags, runtime hooks or C-output conditionals cannot bypass the ownership, escape, pointer-field, sumtype and CI re-enable conditions. |
| V3 architecture fit | ADAPTED because V3 autofree-related implementation remains governed by specific V3 ledger coverage and maintainer issue constraints even when the code lives in generically named V3 files or is only staged, unstaged, untracked, or intent-to-add; root-wide V3 targets are treated as hygiene context, not as acceptance for autofree semantics |
| Required tests | `python3 tools/validate_ledger.py --self-test` including the negative `vlib/v3/pref/pref.v` `is_autofree` canary that fails under broad `vlib/v3` coverage and passes under a specific target; `python3 tools/validate_ledger.py --scan-v3-markers --check-worktree-coverage ledger.md` |
| Hunk hygiene | KEEP as an external ledger/validator rule; no production V3 code hunk is introduced by this item |
| Reviewer verdict | Accepted as hard review gate for future autofree production files |
| Orchestrator verdict | GO-V2 |

## Item: Orchestrator engineer reviewer separation rule

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Chantiers rule: Codex does not own production decisions alone; engineers implement, reviewers validate, orchestrator gates |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md` |
| Docs | `/home/rei/dev-project/iag_infinity/.subagents/references/v27116-orchestration-doctrine.md`, `/home/rei/dev-project/iag_infinity/.subagents/roles/external-dependency-engineer.md` |
| Adaptation rule | Track implementation only after owner/reviewer GO; ledger items must preserve reviewer and orchestrator verdict fields |
| V3 architecture fit | ADAPTED because V3 changes remain gated by role ownership and reviewer validation instead of unilateral code movement |
| Required tests | Ledger validation must require reviewer verdict and orchestrator verdict on every item |
| Reviewer verdict | Accepted process gate |
| Orchestrator verdict | GO-V2; Codex is orchestrator/validator only and must never author production code. The immutable production pipeline is diagnostic first, implementation by engineers, reviewer GO/HOLD, orchestrator validation/tests, then accept or rework. Any production hunk outside this pipeline is invalid |

## Item: Infinite no-code orchestrator invariant

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator, all engineers, all reviewers |
| Source ref | User hard rule, 2026-06-20T21:36:55+02:00 and reinforced 2026-06-21T00:53:13+02:00: Codex never touches production code and repeats the same pipeline indefinitely |
| Target refs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md` |
| Docs | `/home/rei/dev-project/iag_infinity/iag_infinity/AGENTS.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Treat the no-code orchestrator boundary as a permanent V3 chantier process gate: Codex may coordinate, authorize, test, validate and update external audit metadata, but any production code, production test, cleanup, rename, comment or diagnostic-debris removal must be implemented by the assigned engineer after diagnostics and before reviewer GO/HOLD |
| V3 architecture fit | ADAPTED because it protects V3 architecture from unilateral edits and forces every V3 source change through role separation, reviewer validation and scoped test evidence before acceptance |
| Required tests | Before accepting any production hunk, reviewers must confirm diagnostic provenance, engineer ownership and no direct orchestrator-authored production edit; orchestrator must then run the scoped validation gates |
| Hunk hygiene | KEEP as external process metadata only; this ledger item introduces no production V3 code hunk |
| Reviewer verdict | Accepted as mandatory process invariant for every future production hunk |
| Orchestrator verdict | GO-V2; no exception for urgency, obvious fixes, cleanup, tests, filenames, comments, diagnostic-debris removal, or small hunks |

## Item: Infinite no-code orchestrator invariant reinforcement 2026-06-21T02:33:49+02:00

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator, all engineers, all reviewers |
| Source ref | User hard rule reinforced 2026-06-21T02:33:49+02:00: Codex never touches production code and keeps the same pipeline forever |
| Target refs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md` |
| Docs | `/home/rei/dev-project/iag_infinity/iag_infinity/AGENTS.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md` |
| Adaptation rule | Codex is permanently limited to orchestration, authorization, validation, testing and external metadata. Production code, tests, comments, filenames, cleanup and diagnostic debris must be changed only by engineers after diagnostics and before reviewer GO/HOLD. |
| V3 architecture fit | ADAPTED because it prevents unilateral V3 source changes and preserves reviewer-gated V3 architecture decisions |
| Required tests | For every production hunk, confirm engineer ownership, reviewer GO/HOLD, orchestrator validation and hunk hygiene before acceptance |
| Hunk hygiene | KEEP as external process metadata only; no production V3 code hunk is introduced by this item |
| Reviewer verdict | Mandatory invariant; reviewers must reject any production hunk outside the pipeline |
| Orchestrator verdict | GO-V2; same pipeline forever: diagnostic -> authorization -> engineer implementation -> reviewer GO/HOLD -> orchestrator validation/tests -> accept or rework |

## Item: Infinite no-code orchestrator invariant reinforcement 2026-06-21T04:37:16+02:00

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator, all engineers, all reviewers |
| Source ref | User hard rule reinforced 2026-06-21T04:37:16+02:00: Codex never touches production code and keeps the same pipeline indefinitely |
| Target refs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md` |
| Docs | `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md` |
| Adaptation rule | Codex is permanently limited to orchestration, authorization, validation, tests, and external audit metadata. Production code, production tests, comments, filenames, cleanup hunks and diagnostic artifacts must be changed only by assigned engineers after diagnostics and before reviewer GO/HOLD. |
| V3 architecture fit | ADAPTED because it protects the V3 architecture from unilateral edits and keeps every mutation reviewer-gated |
| Required tests | Every accepted production hunk must have diagnostic provenance, engineer ownership, reviewer GO/HOLD, orchestrator validation, and hunk hygiene evidence |
| Hunk hygiene | KEEP as external process metadata only; no production V3 code hunk is introduced by this item |
| Reviewer verdict | Mandatory invariant; reviewers must reject any direct orchestrator production edit |
| Orchestrator verdict | GO-V2; same pipeline indefinitely: diagnostic -> explicit authorization -> engineer implementation -> reviewer GO/HOLD -> orchestrator validation/tests -> accept or rework |

## Item: Imported C struct function-pointer field initializer authority

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Carson implementation; Cicero/Banach/Chandrasekhar/Kierkegaard reviewer diagnostics; Codex orchestrator validation only |
| Source ref | Tetris generated-C probe after V3 typed function-pointer field initializer front: nested `sapp.Desc{...}` fields still emitted raw short symbols such as `gg_init_sokol_window` instead of checker-authoritative canonical symbols |
| Target refs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/types/checker.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/struct.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/tests/function_value_codegen_test.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/markused/markused.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Extend the V3 checker-authoritative function-value field initializer path through imported or alias C/typedef struct literals, including nested struct literals, without CGen name guessing or V2-shaped fallback behavior |
| V3 architecture fit | ADAPTED because the fix must flow from V3 type/checker facts into C output, preserving exact symbol authority and typed-userdata wrapper facts instead of hardcoding example or backend-specific callback names |
| Required tests | Imported/qualified alias to C/typedef struct with function-pointer fields; nested literal `Outer{ desc: mod.Desc{ cb: frame } }`; exact signature direct/no-wrapper; typed userdata wrapper; event userdata wrapper; homonym/shadow canary; wrong arity, wrong return, non-pointer mismatch and function-variable mismatch rejected before C |
| Hunk hygiene | KEEP as V3 checker-authoritative field metadata adaptation; reviewers found no hardcode for tetris/gg/sokol/sapp/sapp_desc/callback field names, no suffix/global scan, no raw blanket cast, no root-all, no function-variable lowering, no option/result/nested-array/cleanup/comptime/sort/runtime/autofree/native/V2 scope creep |
| Reviewer verdict | GO-V1 from Cicero, Banach, Chandrasekhar and Kierkegaard |
| Orchestrator verdict | GO-V2 after fmt/diff, focused V3 function-value/markused tests, ledger validation and seed->self->self2->self3. Tetris probe confirms raw nested callback names are fixed and exposes the next blocker: callback C const-pointer ABI for `event_userdata_cb`. |

## Item: Machine guard before heavy commands

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator and runner |
| Source ref | Local AGENTS machine guard rule for `iag-system-guard.service` and memory/swap check before tests/builds |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md` |
| Docs | `/home/rei/dev-project/iag_infinity/iag_infinity/AGENTS.md` |
| Adaptation rule | Treat the guard as an execution precondition for validation runs; it is external to V3 code and must not become production logic |
| V3 architecture fit | ADAPTED because it protects the V3 validation environment without modifying V3 architecture |
| Required tests | `systemctl --user start iag-system-guard.service`; `systemctl --user is-active iag-system-guard.service`; `free -h` before heavy work |
| Reviewer verdict | Accepted as local machine precondition |
| Orchestrator verdict | GO-V2 |

## Item: Official V3 seed self self2 pipeline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Official V3 C-output pipeline uses seed, self, then self2 with observed RSS gates |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/v3.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Use seed/self/self2 as the official baseline route and record memory observations separately from autofree claims |
| V3 architecture fit | ADAPTED because it validates V3 through its own C-output compiler path before any autofree slice claims success |
| Required tests | `v -o /tmp/v3_migration_seed vlib/v3`; `/tmp/v3_migration_seed vlib/v3/v3.v -o /tmp/v3_migration_self`; `/tmp/v3_migration_self vlib/v3/v3.v -o /tmp/v3_migration_self2` |
| Hunk hygiene | BASELINE self-build route evidence only; this item does not accept a production V3 hunk |
| Reviewer verdict | Accepted route, individual gates below hold the exact observed RSS |
| Orchestrator verdict | GO-V2 |

## Item: Maintainer pivot external gates

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A then Team B |
| Source ref | Maintainer pivots `examples/tetris/tetris.v`, `examples/2048/2048.v`, `vlib/v/tests/options/option_test.c.v` |
| Target refs | `/home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/examples/tetris/tetris.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/examples/2048/2048.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v/tests/options/option_test.c.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Treat pivots as external baseline gates for V3 C-output, not as places to hardcode behavior |
| V3 architecture fit | ADAPTED because the pivots pressure V3 language and C-output seams while forbidding example-specific production patches |
| Required tests | The three dedicated baseline gate commands listed below after seed/self/self2 exists |
| Reviewer verdict | HOLD until the three pivot-specific gate items are accepted |
| Orchestrator verdict | Not accepted |

## Current V3 Baseline Gates

Critical gates are represented as ledger items so the validator enforces owner,
target refs, docs, required tests and verdicts.

## Item: Baseline gate seed build v to v3_migration_seed

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Stage-1 V3 self-build route `v -o /tmp/v3_migration_seed vlib/v3` |
| Target refs | `vlib/v3/v3.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Keep this as V3 baseline evidence only; it does not authorize any V2-shaped autofree import |
| V3 architecture fit | ADAPTED because it validates the existing V3 driver path before any autofree C-output facts are consumed |
| Required tests | `v -o /tmp/v3_migration_seed vlib/v3` |
| Hunk hygiene | BASELINE self-build evidence only; no production hunk is accepted by this gate |
| Reviewer verdict | Baseline route accepted |
| Orchestrator verdict | GO-V2, PASS, max RSS about 383 MB, swap 0 |

## Item: Baseline gate self build seed to self

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Stage-2 V3 self-build route `/tmp/v3_migration_seed vlib/v3/v3.v -o /tmp/v3_migration_self` |
| Target refs | `vlib/v3/v3.v`, `vlib/v3/gen/c/` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Keep C-output self-build as a prerequisite gate, not as autofree proof |
| V3 architecture fit | ADAPTED because it exercises the V3 C-output pipeline through the V3 driver without changing V3 architecture for V2 |
| Required tests | `/tmp/v3_migration_seed vlib/v3/v3.v -o /tmp/v3_migration_self` |
| Hunk hygiene | BASELINE self-build evidence only; no production hunk is accepted by this gate |
| Reviewer verdict | Baseline route accepted |
| Orchestrator verdict | GO-V2, PASS, max RSS about 275 MB, swap 0 |

## Item: Baseline gate self build self to self2

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Orchestrator |
| Source ref | Stage-3 V3 self-build route `/tmp/v3_migration_self vlib/v3/v3.v -o /tmp/v3_migration_self2` |
| Target refs | `vlib/v3/v3.v`, `vlib/v3/gen/c/` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Preserve this as the accepted V3 baseline compiler route before autofree gates |
| V3 architecture fit | ADAPTED because it confirms repeated V3 C-output self-build viability using V3-owned flow |
| Required tests | `/tmp/v3_migration_self vlib/v3/v3.v -o /tmp/v3_migration_self2` |
| Hunk hygiene | BASELINE self-build evidence only; no production hunk is accepted by this gate |
| Reviewer verdict | Baseline route accepted |
| Orchestrator verdict | GO-V2, PASS, max RSS about 548 MB, swap 0 |

## Item: Baseline gate tetris normal V3 C output

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A |
| Source ref | `examples/tetris/tetris.v` |
| Target refs | `vlib/v3/parser/parser.v`, `vlib/v3/types/checker.v`, `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Fix only strict V3 params and contextual typing baseline failures before autofree work |
| V3 architecture fit | ADAPTED because the gate targets normal V3 language support, not V2 CleanC behavior |
| Required tests | `/tmp/v3_migration_self2 examples/tetris/tetris.v -o /tmp/v3_tetris_probe` |
| Reviewer verdict | HOLD on omitted params and empty-array context |
| Orchestrator verdict | Not accepted |

## Item: Baseline gate 2048 normal V3 C output

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A then Team B |
| Source ref | `examples/2048/2048.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/monomorphize.v`, `vlib/v3/gen/c/fn.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Fix V3 params first, then math/generic baseline through V3 type and transform semantics |
| V3 architecture fit | ADAPTED because the gate keeps generic math and params fixes in V3 checker/transform/C-output layers |
| Required tests | `/tmp/v3_migration_self2 examples/2048/2048.v -o /tmp/v3_2048_probe` |
| Reviewer verdict | HOLD on params plus math/generic baseline |
| Orchestrator verdict | Not accepted |

## Item: Baseline gate option_test normal V3 C output

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team B |
| Source ref | `vlib/v/tests/options/option_test.c.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/or.v`, `vlib/v3/gen/c/types.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/fn.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Diagnose and implement result/IError/or-block/?void support through V3 checker, transform and C-output seams |
| V3 architecture fit | ADAPTED because the gate is a V3 baseline prerequisite and explicitly rejects treating option/result as autofree work |
| Required tests | `/tmp/v3_migration_self2 vlib/v/tests/options/option_test.c.v -o /tmp/v3_option_test_probe` |
| Reviewer verdict | HOLD on IError/result/or-block/?void families |
| Orchestrator verdict | Not accepted |

## Item: Parser `@[params]`

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A |
| Source ref | V2 params struct support needed by user-facing APIs; current pivots include `vlib/time/stopwatch.v::new_stopwatch` and `vlib/gg/gg.c.v::Context.end` |
| Target refs | `vlib/v3/parser/parser.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Attribute must attach only to the immediately following struct declaration |
| V3 architecture fit | ADAPTED because params metadata belongs to the V3 parser declaration path and must not be represented as leaked global parser state |
| Refusal reason for first patch | `pending_params` can leak from a misplaced attribute to a later struct |
| Required tests | positive params struct; misplaced `@[params]` does not mark next struct |
| Reviewer verdict | Lovelace HOLD, Banach REFUSE |
| Orchestrator verdict | Not accepted |

## Item: Checker omitted params struct argument

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A |
| Source ref | `vlib/time/stopwatch.v::new_stopwatch`, `vlib/gg/gg.c.v::Context.end` |
| Target refs | `vlib/v3/types/checker.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Allow only the exact shape: trailing omitted or named args targeting a real `@[params]` struct |
| V3 architecture fit | ADAPTED because omitted params are a V3 checker call-shape rule proven before generation |
| Refusal reason for first patch | Named `field_init` call args collapse too broadly |
| Required tests | non-params omitted arg rejected; named args on non-params rejected; unknown params field rejected; wrong field type rejected |
| Reviewer verdict | Lovelace HOLD, Banach REFUSE |
| Orchestrator verdict | Not accepted |

## Item: CGen params struct argument emission

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A |
| Source ref | Params struct emission needed after checker proves calls such as `vlib/time/stopwatch.v::new_stopwatch` |
| Target refs | `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/struct.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | CGen may emit params struct literals only after checker proves the shape valid |
| V3 architecture fit | ADAPTED because CGen receives a checker-proven V3 params shape and only emits the corresponding C struct literal |
| Refusal reason for first patch | Default fallback can hide invalid checker states |
| Required tests | Invalid named params must fail before generation |
| Reviewer verdict | Lovelace HOLD, Banach REFUSE |
| Orchestrator verdict | Not accepted |

## Item: Contextual empty array assignment

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A |
| Source ref | `examples/tetris/tetris.v::Game.field` empty array reset shape |
| Target refs | `vlib/v3/gen/c/stmt.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Expected type may flow into `[]` only from a real contextual destination |
| V3 architecture fit | ADAPTED because contextual `[]` typing is a V3 expression-generation baseline rule, not an autofree workaround |
| Current finding | No blocker yet, but canary coverage is required |
| Required tests | Positive `[][]int`; no/non-array context canary if practical |
| Hunk hygiene | REWORK until reviewers confirm the active hunk location and test coverage; no `GO-V2` allowed while this remains REWORK |
| Reviewer verdict | Pending after params strictness is fixed |
| Orchestrator verdict | Pending |

## Item: Disabled conditional function facts and C hook shims

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A checker facts, Team B C-output |
| Source ref | V3 flat AST disabled conditional function facts and generated C references to disabled runtime hooks |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/gen/c/cleanc.v`, `vlib/v3/tests/conditional_fn_facts/conditional_fn_facts_test.v`, `vlib/v3/gen/c/tests/disabled_conditional_call_codegen_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Re-express disabled conditional calls as checker-owned V3 facts and C-output shims only when the real function is absent; shims must not hide used/rooted functions or replace markused correctness |
| V3 architecture fit | ADAPTED because disabled conditional behavior is consumed through V3 flat facts and C-output preamble seams instead of textual V2 fallback logic |
| Required tests | `vlib/v3/tests/conditional_fn_facts/conditional_fn_facts_test.v`; `vlib/v3/gen/c/tests/disabled_conditional_call_codegen_test.v`; review that real used functions suppress shims |
| Hunk hygiene | BASELINE candidate under review; keep only if both tests pass and reviewers confirm the shims do not mask real markused/rooting bugs |
| Reviewer verdict | HOLD until focused tests and reviewer classification pass |
| Orchestrator verdict | Pending |

## Item: Platform macro identifier C-name guards

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Team A checker/C-name baseline |
| Source ref | Linux toolchains may expose `unix`/`linux` as preprocessor macros, conflicting with generated C identifiers during V3 self-build |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/v3.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Treat platform macro names as C-output identifier hazards in the same V3 `c_name` guard path as C reserved words; do not add example-specific renames |
| V3 architecture fit | ADAPTED because it extends the existing V3 C-name sanitation seam for host C macro portability |
| Required tests | V3 self-build seed/self/self2 on Linux; add or keep a focused C-name canary before final `GO-V2` |
| Hunk hygiene | BASELINE candidate under review; keep only if self-build or a focused canary proves the macro collision and no broader rename is introduced |
| Reviewer verdict | HOLD until focused proof is attached |
| Orchestrator verdict | Pending |

## Item: V3 self-build generated-C blockers after alias helper fix

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team A type/smartcast, Team B C-output |
| Source ref | `/tmp/v3_migration_seed vlib/v3/v3.v -o /tmp/v3_migration_self` after replacing the imported-constructor helper with a string sentinel; generated C first exposes fixed-array indexing while compiling code originating from `vlib/v3/gen/arm64/linker.v`, but native backend files are not a target of this item |
| Target refs | `vlib/v3/gen/c/for.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/markused/markused.v`, `vlib/v3/ssa/builder.v`, `vlib/v3/transform/transform.v`, `vlib/v3/types/checker.v`, `vlib/v3/types/type.v`, `vlib/time/format.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/v27116_v3_migration_ledger/README.md` |
| Adaptation rule | Classify and fix the remaining self-build C-output failures through V3-native seams only: fixed array C literal/indexing, optional value materialization, map array update emission, sumtype method/smartcast codegen, multi-return sumtype field access, and byte-array/string conversion in time formatting |
| V3 architecture fit | ADAPTED because the item treats self-build failures as V3 C-output baseline blockers before any autofree claim, without native backend or V2 shape imports |
| Required tests | Re-run seed->self self-build; add or use focused V3 tests for each accepted fix family before moving past DIAG/PATCHED |
| Hunk hygiene | REWORK until each failure family is reduced to a focused V3-native patch or proven cascade and removed from this blocker |
| Reviewer verdict | Not started; must split root families before implementation |
| Orchestrator verdict | Pending |

## Item: Option/result baseline

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | HOLD |
| Owner | Team B |
| Source ref | `vlib/v/tests/options/option_test.c.v` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/transform/or.v`, `vlib/v3/gen/c/types.v`, `vlib/v3/gen/c/struct.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/markused/markused.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Implement through V3 checker/transform/C-output design, not V2 direct import |
| V3 architecture fit | ADAPTED because option/result support must be rebuilt through V3 checker, transform/or and C-output ABI seams |
| Current finding | IError/result/or-block/?void families fail in normal V3 baseline |
| Required tests | Dedicated option/result V3 C-output tests, then `option_test.c.v` |
| Reviewer verdict | Not started |
| Orchestrator verdict | Deferred until Team A checker slice is accepted |

## Item: Baseline V3 C oracle for native backend comparison

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | V3 baseline C oracle team |
| Source ref | Downstream native backend request; current observed failure: `examples/tetris/tetris.v` reaches generated C through the self-built V3 compiler, carries generic C directives/flags correctly and no longer emits positional `. =` initializers, then fails C compilation on later V3 baseline gaps |
| Target refs | `vlib/v3/parser/parser.v`, `vlib/v3/scanner/scanner.v`, `vlib/v3/pref/pref.v`, `vlib/v3/transform/transform.v`, `vlib/v3/transform/monomorphize.v`, `vlib/v3/types/checker.v`, `vlib/v3/markused/markused.v`, `vlib/v3/gen/c/gen.v`, `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/struct.v`, `vlib/v3/gen/c/types.v`, `vlib/v3/gen/c/tests/c_directive_transport_test.v`, `vlib/v3/gen/c/tests/struct_init_codegen_test.v`, `vlib/v3/gen/c/tests/option_sumtype_codegen_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md` |
| Adaptation rule | Stabilize the V3 `-b c` oracle for real examples and fixtures first; then validate `examples/tetris`, `examples/2048`, and the maintainer representative `vlib/v/tests/options/option_test.c.v` under normal V3 C-output; do not depend on, modify, or name native backends; first PR scope is baseline V3/C only and explicitly excludes autofree implementation |
| V3 architecture fit | ADAPTED because the oracle work belongs to the existing V3 parse -> transform -> check -> markused -> C-output pipeline and explicitly excludes native backend patches |
| Required tests | `examples/hello_world.v -b c` compile/run exact stdout; `examples/fizz_buzz.v -b c` compile/run exact stdout; reduced top-level `println('x')`; reduced top-level user-function call; explicit `fn main()` no duplicate C main; generated C contains `int main(` when needed; top-level called functions preserved by markused; generated C does not define a recursive `exit` wrapper; C compiler/linker failures return clean non-zero without segfault; then `examples/tetris`, `examples/2048`, and `vlib/v/tests/options/option_test.c.v` normal V3 C-output gates; directive transport canary for `#include/#define/#flag`; positional struct initializer canary; TCC if available plus system `cc` on generated C with strict warnings where available |
| Reviewer verdict | GO-V1 for top-level synthetic main after module non-main canary; GO-V1 for non-recursive builtin `exit` C-output; GO for Team A generic C directive/flag transport, including quote-aware `@VEXEROOT` and token/group-aware compile/link split; GO for Team B positional struct initializer/type-authority and optional/result payload wrapper canaries |
| Orchestrator verdict | Latest seed/self/self2 PASS with `/tmp/v3_migration_self2_after_flags_quote`, max RSS about 492 MB and swap 0; explicit-main hello PASS; top-level fizz_buzz PASS; tetris still FAILS at C compile but progressed: `dot_equal_count=0` and generated cc command carries sokol/fontstash/stb include/link flags. Remaining baseline V3/C families are qualified embedded fields, unresolved generics (`math__T`), top-level `$if` declarations, C alias nested literals, method/call authority, C const macro collisions, function-value qualification/reachability, callback pointer adaptation, option/result propagation, function-variable/or-expr lowering, selector local-shadow authority, and comptime tokens in expressions. Next implementation should start with declaration/type roots, then generics, then selector/call authority. Autofree excluded from first PR |

## Item: Two-phase delivery gate, baseline first then autofree

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Orchestrator and all teams |
| Source ref | User golden overnight directive from 2026-06-20 |
| Target refs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/examples/tetris/tetris.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/examples/2048/2048.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v/tests/options/option_test.c.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `https://github.com/vlang/v/issues/27116` |
| Adaptation rule | ARRET INTERDIT until the complete two-phase sequence reaches its defined end. Phase 1 is a complete V3 C oracle delivery: tetris and 2048 must compile and then run correctly through the V3 C path with no segfault, panic, abort, or invalid runtime behavior; `vlib/v/tests/options/option_test.c.v` must be full green through V3, including compile, run, and contained assertions/tests. Only after Phase 1 reaches 100% with PR-clean V3-native architecture may the branch be committed and pushed to GGRei/v. Phase 2 then switches to V3 autofree only and must make tetris/2048 generated C contain the expected ownership cleanups everywhere required by the V3 ownership model. Phase 2 must not be committed or pushed without explicit later approval. The only allowed wait/stop point is after Phase 2 reaches the autofree proof target for tetris and 2048 generated C. |
| V3 architecture fit | ADAPTED because baseline language/C-output support is stabilized before autofree semantics, and autofree then builds on the V3-native oracle instead of V2 artifacts or native backend shortcuts |
| Required tests | Phase 1: seed/self/self2, hello/fizz/top-level oracle tests, tetris compile then runtime correctness with no crash, 2048 compile then runtime correctness with no crash, `vlib/v/tests/options/option_test.c.v` full green through V3, hygiene scan, ledger validation. Phase 2: normal vs autofree generated-C comparison for tetris/2048, expected cleanup presence/placement, no cleanup where ownership does not require it, and maintainer issue #27116 bug-family gates |
| Hunk hygiene | DEFER autofree hunks until Phase 1 is complete and pushed; baseline C-oracle hunks remain subject to per-front KEEP/REWORK/RESTORE review |
| Reviewer verdict | Process gate accepted by user; reviewers must enforce phase separation |
| Orchestrator verdict | Active. Baseline Phase 1 in progress; no voluntary stop, standby, agent shutdown, or chantier end is allowed before the full ordered sequence reaches its explicit waiting point. Do not start autofree implementation yet |

## Deferred Native Backends

Native ARM64/X64 backend autofree remains outside this chantier. The controlled
decision item is in `inventory_v2.md::Deferred Native Backends`.

## Item: Generic template no-leak and fail-closed usage

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Team B implementation, Team A and all diagnostician/reviewers validation |
| Source ref | `examples/tetris/tetris.v` generated-C failure with `math__T` / `struct math__DivResult`; focused regression `vlib/v3/gen/c/tests/generic_no_leak_codegen_test.v` |
| Target refs | `vlib/v3/flat/flat.v`, `vlib/v3/parser/parser.v`, `vlib/v3/types/checker.v`, `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/struct.v`, `vlib/v3/gen/c/tests/generic_no_leak_codegen_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Unsupported generic templates are recorded and skipped as templates in V3 flat/checker/C-output, while real used unsupported generic applications fail before C generation |
| V3 architecture fit | ADAPTED because the generic-template facts are carried through V3 flat metadata and consumed by V3 checker/C-output gates instead of porting V2 monomorphization shortcuts |
| Required tests | `VJOBS=1 v test vlib/v3/gen/c/tests/generic_no_leak_codegen_test.v`; seed -> self -> self2; tetris generated-C probe confirming no `math__T` and no `struct math__DivResult` |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; no production hunk may mention internal agent/phase names |
| Reviewer verdict | Team A GO; Lovelace GO; Banach GO; Chandrasekhar GO; Kierkegaard GO |
| Orchestrator verdict | GO-V2. Local validation passed, seed/self/self2 passed, and tetris progressed to the next baseline V3/C blocker family |

## Item: V3 alias composite fixed-array struct literal authority

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Team B implementation, Team A and all diagnostician/reviewers validation |
| Source ref | `examples/tetris/tetris.v` generated-C failure with `gfx__Color` emitted as a value inside nested alias/composite fixed-array literals |
| Target refs | `vlib/v3/parser/parser.v`, `vlib/v3/transform/struct.v`, `vlib/v3/types/checker.v`, `vlib/v3/gen/c/array.v`, `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/struct.v`, `vlib/v3/gen/c/tests/fixed_array_codegen_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Resolve module-qualified struct literals and fixed-array element expected types through V3 parser/checker/transform/C-output authority. No CGen fallback, no tetris hardcode, no V2-shaped short-name rescue, and `C.*` remains outside this qualified-struct path |
| V3 architecture fit | ADAPTED because V3 parser accepts the bounded qualified type-literal syntax, V3 checker owns import-alias and local-shadow authority, V3 transform resolves known alias struct facts fail-closed, and V3 C output uses expected fixed-array element types instead of guessing from expression spelling |
| Required tests | `VJOBS=1 v test vlib/v3/gen/c/tests/fixed_array_codegen_test.v vlib/v3/gen/c/tests/struct_init_codegen_test.v vlib/v3/gen/c/tests/params_context_codegen_test.v vlib/v3/gen/c/tests/option_sumtype_codegen_test.v vlib/v3/gen/c/tests/for_in_codegen_test.v vlib/v3/tests/qualified_alias_multireturn/qualified_alias_multireturn_test.v`; next heavy gate is seed -> self -> self2, then tetris generated-C probe |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; accepted hunks are scoped to V3 qualified struct literal authority and fixed-array expected-type C output |
| Reviewer verdict | Team A GO; Lovelace GO; Banach GO; Chandrasekhar GO; Kierkegaard GO |
| Orchestrator verdict | GO-V2. Scoped `v fmt -verify` passed, scoped `git diff --check` passed, six focused V3 tests passed, and ledger validator passed. Seed/self/self2 plus tetris probe remain the next mandatory validation |

## Item: V3 control-condition block versus qualified struct literal disambiguation

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | PATCHED |
| Owner | Team B implementation, Team A and all diagnostician/reviewers validation |
| Source ref | V3 self-build failure where `import os; os.exists('/tmp')` was reported as unknown because `if cerror == C.EINTR { ... }` in `vlib/os/os.c.v` was parsed as a `C.EINTR{...}` struct literal and desynchronized later declarations |
| Target refs | `vlib/v3/parser/parser.v`, `vlib/v3/tests/parser_control_condition/parser_control_condition_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Resolve the ambiguity at the V3 parser seam for expressions immediately followed by a required block. `if`, if-guards, condition-only `for`, `for-in`, C-style `for` post expressions, `match` subjects and branch conditions, and `select` branches must stop before a real block `{` while still preserving completed qualified struct literals such as `module.Type{}`, `module.Type{field: value}` and `C.Type{}` in valid expression positions. No `os.exists`, `C.EINTR`, tetris, checker, CGen, driver, V2 or native-backend workaround is accepted. |
| V3 architecture fit | ADAPTED because the decision is kept inside V3 parser expression/block disambiguation, with checker and C output remaining strict consumers of the resulting flat AST |
| Required tests | `v fmt -verify vlib/v3/parser/parser.v vlib/v3/tests/parser_control_condition/parser_control_condition_test.v`; `git diff --check -- vlib/v3/parser/parser.v vlib/v3/tests/parser_control_condition/parser_control_condition_test.v`; `VJOBS=1 v test vlib/v3/tests/parser_control_condition/parser_control_condition_test.v`; `VJOBS=1 v test vlib/v3/gen/c/tests/fixed_array_codegen_test.v vlib/v3/gen/c/tests/struct_init_codegen_test.v vlib/v3/gen/c/tests/params_context_codegen_test.v vlib/v3/gen/c/tests/option_sumtype_codegen_test.v vlib/v3/gen/c/tests/for_in_codegen_test.v vlib/v3/tests/qualified_alias_multireturn/qualified_alias_multireturn_test.v`; `v -o /tmp/v3_migration_seed_control_condition vlib/v3`; `/tmp/v3_migration_seed_control_condition vlib/v3/v3.v -o /tmp/v3_migration_self_control_condition`; `/tmp/v3_migration_self_control_condition vlib/v3/v3.v -o /tmp/v3_migration_self2_control_condition`; tetris generated-C probe with `/tmp/v3_migration_self2_control_condition` |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; accepted hunks are scoped to V3 parser expression/block disambiguation and focused parser-control regression tests |
| Reviewer verdict | Team A GO; Lovelace GO; Banach GO; Chandrasekhar GO; Kierkegaard GO |
| Orchestrator verdict | GO-V2. Scoped `v fmt -verify` passed, scoped `git diff --check` passed, focused parser-control test passed, six V3 C-output canary tests passed, seed/self/self2 passed, and the original `unknown function os.exists` self-build failure is gone. Tetris now reaches generated-C failures in later baseline families, led by `rand__PRNG__string` selection and `block_size` C macro collision. |

## Item: Tetris post-generic C-output blocker family

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Team A diagnostic root-cause split, Team B implementation only after authorization |
| Source ref | `examples/tetris/tetris.v` generated C after accepted generic-template, alias/composite literal, and parser control-condition fronts |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/markused/markused.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/stmt.v`, `vlib/v3/gen/c/struct.v`, `vlib/v3/gen/c/types.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Diagnose and fix only V3-native C-output/type-authority roots. Accepted previous fronts are generic-template no-leak, nested alias/composite literal authority, and parser block/literal disambiguation. Current generated-C failures include string/rand selector authority (`rand__PRNG__string` selected for string conversion), C macro/name collision around `block_size`, callback pointer adaptation, function-value/module qualification holes, option/result propagation, and later comptime token lowering. |
| V3 architecture fit | ADAPTED because each fix must live in the V3 parse -> transform -> check -> markused -> C-output pipeline, with no V2-shaped migration and no example-specific tetris workaround |
| Required tests | Focused V3 C-output regression for each accepted root family; seed -> self -> self2 after accepted patch; tetris compile/run gate after blocker family is closed |
| Hunk hygiene | REWORK until each family is reduced to a focused implementation and reviewed; no catch-all patch is acceptable |
| Reviewer verdict | Pending diagnostic consensus |
| Orchestrator verdict | Pending. No implementation is authorized yet |

## Obsolete / Refused Items

## Item: Callback C const-pointer ABI authority

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | GO-V2 |
| Owner | Team B implementation only after authorization; Team A and all diagnostician/reviewers for diagnosis/review |
| Source ref | `examples/tetris/tetris.v` generated-C failure after imported/alias C struct callback field authority: `.event_userdata_cb = gg__gg_event_fn` is symbol-authoritative but rejected by C because the field expects `const sapp_event*` while the emitted callback signature uses `struct sapp_event*` |
| Target refs | `vlib/v3/parser/parser.v`, `vlib/v3/types/checker.v`, `vlib/v3/types/type.v`, `vlib/v3/gen/c/fn.v`, `vlib/v3/gen/c/cleanc.v`, `vlib/v3/gen/c/struct.v`, `vlib/v3/gen/c/fn_d_parallel.v`, `vlib/v3/gen/c/tests/function_value_codegen_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Preserve callback C ABI const-pointer authority through the V3 parser -> checker -> C-output path. V1 precedent may inform the design: pointer parameters that are not mutable and whose names start with `const_` are emitted as C const pointer parameters. Because V3 `parse_type_name()` currently drops function-type parameter names, this item authorizes a minimal parser extension local to function-type parameter parsing so checker/type facts can preserve the ABI signal. The V3 implementation must not erase constness by a broad compatibility rule and must not recover it through late string guessing or hardcoded callback names. |
| V3 architecture fit | ADAPTED because the const-pointer ABI fact must be represented and consumed by the V3 checker/C-output authority already used for function-value and imported C struct field initializers, rather than by V2-shaped CGen suffix scans or example-specific casts |
| Required tests | Focused V3 C-output tests for exact imported C struct callback fields with `const_* &C.Type`; nested imported alias struct callback field; typed userdata wrapper with const first pointer and userdata-only cast; negative non-const target into const expected field; non-pointer `const_` name does not become const; homonym/shadow canary remains exact; VJOBS=1 and VJOBS=2 function-value test; related markused/disabled conditional/selector tests; seed->self->self2->self3; tetris probe |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; no production hunk in this item contains authorized hardcoded tetris/gg/sokol/sapp names, raw blanket function-pointer casts, suffix scans, root-all, native backend work, V2 work, autofree work, or unrelated blocker-family changes |
| Reviewer verdict | Diagnostic GO from Cicero, Banach, Chandrasekhar and Kierkegaard; later GO from all four reviewers to extend scope minimally to `vlib/v3/parser/parser.v` because function-type parameter names are dropped before checker/C-output can preserve the expected const ABI. Reviewer v1 HOLD from Cicero after implementation: mutable `const_*` pointer params must not become C `const`, and inverse const ABI mismatch (const target into non-const expected field) must be rejected before C. After first rework, Cicero/Banach/Chandrasekhar returned GO, but Kierkegaard returned HOLD because aliases to `FnType` lose const-pointer ABI masks at struct field sites. Final reviewer GO from Cicero, Banach, Chandrasekhar and Kierkegaard after alias-mask and V3-safe source-shape reworks |
| Orchestrator verdict | GO-V2 for the callback C const-pointer ABI front. All reviewers returned GO after the alias and V3-safe source-shape reworks. Scoped format/diff/tests passed, ledger validation passed, seed -> self -> self2 -> self3 passed, fresh self C no longer contains `Optional_Array mask = __if_val` or `mask << child->op` patterns, and self-build RSS stayed about 821 MB with no meaningful swap. Tetris now fails at the next checker blocker before C generation: `frame_fn` cannot use `fn(&Game)` for `gg.FNCb`, and `event_fn` cannot use `fn(&gg.Event, &Game)` for `gg.FNEvent`. Next diagnostic must classify typed-userdata wrapper authority for alias-backed callback fields before any implementation. Codex remains orchestrator/final validator only and must not edit production code/tests/comments/filenames/cleanup/diagnostic debris; the immutable pipeline remains diagnostic -> explicit authorization -> engineer implementation -> reviewer GO/HOLD -> orchestrator validation/tests -> accept or rework |

## Item: Named params typed-userdata callback authority

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | PATCHED |
| Owner | Team B implementation only after authorization; Team A and all diagnostician/reviewers for diagnosis/review |
| Source ref | `examples/tetris/tetris.v` checker failure after callback C const-pointer ABI self-build passed: `frame_fn` rejects `fn(&Game)` for `gg.FNCb`, and `event_fn` rejects `fn(&gg.Event, &Game)` for `gg.FNEvent` |
| Target refs | `vlib/v3/types/checker.v`, `vlib/v3/gen/c/tests/function_value_codegen_test.v` |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Reuse the checker-owned typed-userdata callback authority for named-argument/trailing params struct fields. `check_named_params_args` must resolve named field RHS values using the same expected field type and const ABI mask facts as struct literals, then let CGen consume existing `resolved_fn_value` / `fn_value_userdata_wrapper` facts. |
| V3 architecture fit | ADAPTED because the fix belongs to V3 checker field compatibility for params-struct named arguments, not to CGen fallbacks, V2 behavior, native backends, or example-specific callback casts |
| Required tests | Focused named-params alias callback tests: plain userdata wrapper positive, event-plus-userdata wrapper positive, exact callback direct positive, wrong arity/return/userdata negatives, function variable negative if still disallowed, and existing struct-literal callback tests |
| Hunk hygiene | REWORK until seed/self parity is restored; named-params patch passed focused review/tests and self-build, but self-generated compiler still rejects tetris callbacks that the seed compiler accepts |
| Reviewer verdict | Diagnostic GO from Cicero, Banach, Chandrasekhar and Kierkegaard; implementation review GO from all four reviewers on the named-params patch |
| Orchestrator verdict | HOLD. Scoped format/diff/tests passed, ledger validation passed, and seed -> self -> self2 -> self3 passed. However, seed compiler accepts tetris callbacks and emits wrapper C, while self/self3 reject the same callbacks at checker. The front is not accepted until the self-host parity root is diagnosed and fixed. Codex remains orchestrator/final validator only and must not edit production code/tests/comments/filenames/cleanup/diagnostic debris |

## Item: Nested value-if lowering parity

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | PATCHED |
| Owner | Team B implementation only after authorization; Team A and all diagnostician/reviewers for diagnosis/review |
| Source ref | Seed compiler accepts tetris callback wrappers, but self/self3 reject because self-generated parser corrupts function-type alias parameter strings from nested string-valued `if` expressions in `parse_type_name` |
| Target refs | `vlib/v3/transform/if.v`, focused V3 transform/CGen tests |
| Docs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md`, `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md` |
| Adaptation rule | Tail `.if_expr` nodes inside value-if branch blocks must be lowered as the branch value and assigned to the target temp, not emitted as unused statements. This preserves V3 value semantics generally and avoids parser-specific source-shape workarounds |
| V3 architecture fit | ADAPTED because the fix belongs to V3 transform lowering for value-producing control flow, before checker/C-output self-host parity can be trusted |
| Required tests | Focused nested value-if canary returning strings through array push/call arg/RHS, existing function-value callback tests, seed -> self -> self2/self3, and self tetris reaches generated C with wrapper symbols |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; no parser-only workaround, no callback checker/CGen patch for this symptom, no hardcoded parser/tetris/gg/FNCb/FNEvent, no V2/native/autofree/example edits |
| Reviewer verdict | Diagnostic GO from Cicero, Banach, Chandrasekhar and Kierkegaard; implementation review GO from all four reviewers |
| Orchestrator verdict | GO-V2. Scoped format/diff/tests passed, ledger validation passed, seed -> self -> self2 -> self3 passed, and self3 tetris now passes checker and emits callback wrappers. Tetris now fails on later generated-C baseline families, so next work must classify those C-output failures by root family before any implementation |

## Item: Fixed-array nested value materialization

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Carson implementation only after authorization; Cicero/Banach/Chandrasekhar/Kierkegaard reviewer diagnostics; Codex orchestrator validation only |
| Source ref | `examples/tetris/tetris.v` generated-C failures after nested value-if parity: nested fixed-array for-in emits scalar `int` element and multi-return fixed-array payloads become non-indexable generic arrays |
| Target refs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/types/checker.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/transform/for.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/transform/type_propagation.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/for.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/stmt.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/fn.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/tests/for_in_codegen_test.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/tests/fixed_array_codegen_test.v` |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Preserve fixed-array and nested fixed-array type authority through V3 checker/transform/C-output so aggregate element values and fixed-array multi-return payloads are materialized as indexable C storage. This is a V3 baseline C-output front only and must not import V2-shaped rules. |
| V3 architecture fit | ADAPTED because fixed-array value fidelity belongs to the existing V3 parse -> transform -> check -> markused -> C-output pipeline before any autofree claim |
| Required tests | Focused nested fixed-array for-in test proving no scalar `int row = rows[i]`; dynamic array for-in canary; fixed-array multi-return payload/index test; existing fixed-array init/copy tests; later seed -> self -> self2/self3 and tetris probe after reviewer GO |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; no tetris/gg/sokol hardcode, no function-value, option/result, cleanup/defer, panic(IError), module const, comptime, C extern/global, sort, native backend, V2 or autofree hunk is accepted in this front |
| Reviewer verdict | Diagnostic consensus from Cicero, Banach and Kierkegaard selected this as the next single front; Chandrasekhar's function-value front was deferred. After implementation reworks, Cicero, Banach, Chandrasekhar and Kierkegaard returned GO on transformed-pipeline proof, checker suffix parsing, bounded transform inference and self-build-safe multi-return source shape |
| Orchestrator verdict | GO-V2. Scoped fmt/diff passed, focused fixed-array/for-in tests passed, related 7-test V3/C bundle passed, ledger validator passed, seed -> self -> self2 -> self3 passed with max RSS about 846616 KB and zero swaps. Tetris now reaches C compilation without the previous nested fixed-array `b_tetros0` and fixed-array multi-return `bounds[3]` failures. Remaining tetris failures are independent later V3 baseline families |

## Item: Option/result identity return lowering

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Carson implementation only after authorization; Cicero/Banach/Chandrasekhar/Kierkegaard reviewer diagnostics; Codex orchestrator validation only |
| Source ref | `examples/tetris/tetris.v` generated-C failures after fixed-array parity include nested optional wrappers for forwarding functions such as `rand__u32n` and `rand__intn` |
| Target refs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/stmt.v`, plus a focused V3 C-output option/result regression test if implementation requires it |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | In V3 C output, a function returning an option/result must directly return an expression that already has the same option/result ABI type, while plain payload expressions still use the existing wrapper path |
| V3 architecture fit | ADAPTED because this is a narrow V3-native C-output ABI authority correction based on checker-resolved return/expression types, not a V2 import and not an autofree patch |
| Required tests | Direct result forwarding, direct option forwarding if supported by the same ABI path, plain payload return still wraps, mismatched option/result types are not masked by CGen, and existing `or {}` lowering remains unchanged |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; no special case for `rand`, `u32n`, `intn`, tetris, option payload casts, broad option/result rewrite, checker relaxation, function-value work, cleanup/defer, panic(IError), module const, comptime token, C extern/global, sort, native backend, V2 or autofree changes |
| Reviewer verdict | Banach and Kierkegaard selected this as the best next single front. Initial implementation review returned GO from Banach, Chandrasekhar and Kierkegaard, but Cicero found scope leakage because broadening `expr_really_returns_optional()` also affected optional argument lowering outside return statements. After rework, Cicero, Banach, Chandrasekhar and Kierkegaard returned GO on return-specific recognition and strengthened same-ABI mismatch/or-block canaries |
| Orchestrator verdict | GO-V2. Scoped fmt/diff passed, focused option/result CGen test passed, ledger validator passed. Identity returns are direct only for matching option/result ABI expressions, payload returns still wrap, same-ABI semantic mismatches are rejected before CGen, and `or {}` unwrap coverage remains tied to the same optional local |

## Item: Receiver method call return-type authority for option/result ABI

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Carson implementation only after authorization; Cicero/Banach/Chandrasekhar/Kierkegaard reviewer diagnostics; Codex orchestrator validation only |
| Source ref | After option/result identity return GO-V2, `examples/tetris/tetris.v` still emits nested wrappers for `rand__u32n` and `rand__intn`, e.g. `.value = rand__PRNG__u32n(...)`, proving the receiver method call expression is not carrying trusted option/result return ABI authority |
| Target refs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/types/checker.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/stmt.v` only if it consumes an existing/new checker fact, parallel CGen clone only if a new fact channel is introduced, focused V3 C-output tests |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Preserve V3 checker-owned return type authority for receiver method/selector calls, including qualified or global receivers, so option/result identity return lowering can trust the call expression without CGen guessing |
| V3 architecture fit | ADAPTED because method call return typing belongs to the V3 checker/typed fact pipeline and C output may only consume those facts; it is not a V2 import, CGen suffix scan, or autofree patch |
| Required tests | Reduced global receiver method returning option/result direct-return canary, local receiver method direct-return canary, payload-return method still wraps, same-ABI semantic mismatch remains rejected before CGen, transform/recheck pipeline canary, selector collision canary proving no suffix/global fallback, imported alias constructor canary, imported sumtype constructor canary, focused option/result CGen test, related V3/C bundle, seed -> self -> self2 -> self3, tetris probe |
| Hunk hygiene | KEEP after reviewer and orchestrator validation; no hardcode for `rand`, `PRNG`, `u32n`, `intn`, tetris or vlib examples; no broad option/result rewrite, payload casts, function-value `f_read`, cleanup/defer, panic(IError), module const, comptime token, C global/rooting, sort, native backend, V2 or autofree changes |
| Reviewer verdict | Cicero, Banach and Kierkegaard selected this front after option/result GO-V2. Chandrasekhar selected local function-value `f_read` as an independent later front. Initial implementation review returned GO from Cicero and Banach, but HOLD from Chandrasekhar and Kierkegaard because selector resolution could use broad base-independent global lookup. After rework, all four reviewers returned GO on exact qualified selector authority and fail-closed namespace CGen emission. Self-build failure reopened the item; Cicero, Banach, Chandrasekhar and Kierkegaard agreed on a narrow imported-constructor rework gated by `imported_type_constructor_call`, without restoring generic namespace fallback. Cicero held V1 because `cleanc.v` prefix-cast helper accepted sumtypes; V2 rework restored alias/struct-only there and all four reviewers returned GO |
| Orchestrator verdict | GO-V2. Format verify, diff check, focused option/sumtype constructor test, related 7-test V3/C bundle, ledger validator, seed -> self -> self2 -> self3 all passed. Tetris probe no longer fails on the previous `unknown__Type(types, ...)`, `unknown__NodeId(flat, ...)`, `unknown__ValueID(ssa, ...)` constructor family; remaining tetris failures are independent V3/C fronts: cleanup/defer local scope, function-value call lowering, fn-type cast parsing, panic(IError), C/time constructors, comptime tokens, C extern/rooting, array sort lowering and global roots |

## Item: Function-value local call lowering

| Field | Value |
| --- | --- |
| Decision | ADAPTED |
| Validation | DIAG |
| Owner | Carson implementation only after authorization; Cicero/Banach/Chandrasekhar/Kierkegaard reviewer diagnostics; Codex orchestrator validation only |
| Source ref | Tetris generated C after imported-constructor GO-V2 emits `int f_read = os__read_bytes; int __or_opt = f_read(fpath);` and raw V function type syntax such as `fn(Array_u32)__time_seed_64(seed)` |
| Target refs | `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/types/checker.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/stmt.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/gen/c/fn.v`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/markused/markused.v` only if exact function-value rooting is required, focused V3 C-output tests |
| Docs | `/home/rei/dev-project/audit/vlang_issue_27116_v2_autofree_audit_20260608.md`, `/home/rei/dev-project/audit/NEXT_SESSION_RESUME_VLANG_27116_AUTOFREE_2026-06-12.md`, `/home/rei/dev-project/v27116_autofree_v3_migration_20260620/vlib/v3/README.md` |
| Adaptation rule | Preserve exact V3 checker authority for function values assigned to locals or used as call expressions, then emit valid C function pointer storage/calls with the callee return ABI, including option/result; do not convert function values to `int`, `voidptr`, raw V `fn(...)` syntax or suffix-matched function names |
| V3 architecture fit | ADAPTED because function values are typed facts from checker/transform consumed by C output; implementation must fit V3 FnType and markused authority, not V2, tetris-specific or CGen text fallback behavior |
| Required tests | Local optional-return function value call emits function pointer storage and preserves `Optional_*` call result; imported function value call resolves exactly and roots the referenced function if needed; non-option function value call returns the concrete type; alias FnType local variable call works; raw generated C contains no `fn(` syntax for function-value casts/calls; wrong arity/return mismatch is rejected before CGen; local/import shadow and homonym canaries prove no suffix/global fallback |
| Hunk hygiene | KEEP only after reviewer and orchestrator validation; no hardcode for `os`, `read_bytes`, `asset`, `tetris`, `rand`, `time_seed_64` or platform names; no cleanup/defer, panic(IError), comptime token, extern/global/rooting, sort, native backend, V2 or autofree changes in this front |
| Reviewer verdict | Cicero, Banach, Chandrasekhar and Kierkegaard selected this front after imported-constructor GO-V2 because it is the most upstream remaining root and covers the `f_read` failure plus raw `fn(...)` C syntax without touching unrelated fronts |
| Orchestrator verdict | DIAG accepted; implementation may start only inside the stated scope |

Final `OBSOLETE` and `REFUSED` classifications are recorded in the validated
inventory items. First patch refusals in active baseline items remain reviewer
state, not final architectural refusals.
