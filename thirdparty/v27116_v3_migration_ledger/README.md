# V Issue 27116 - V3 Migration Ledger

This directory is an external migration control surface. It is intentionally
outside the V source tree so it can be removed without touching the project.

Workspace currently audited:

```text
/home/rei/dev-project/v27116_autofree_v3_migration_20260620
```

## Purpose

Track every V2 autofree/baseline idea considered for V3 and force an explicit
decision before implementation is accepted.

No entry in this ledger is production code. It is orchestration/audit metadata
only.

This ledger should be operational, not just descriptive. The expected workflow is
to validate it with an external checker before resuming or accepting migration
work, so missing decisions, owners, tests or reviewer verdicts are caught early.

Golden rule for this module: it is external, removable audit metadata. It must
leave zero trace in the V3 source tree. Production V3 files must not mention this
module, the migration ledger, or ledger decision states.

## Permanent Orchestration Pipeline

Codex is the orchestrator and final validator only. Codex must never author,
patch, refactor, clean, or rename production V code directly in this chantier.

This is an infinite invariant, not a local convention. It applies to every
production hunk, test hunk, cleanup hunk, rename, comment, helper, and
diagnostic-debris removal. Codex may edit this external ledger/audit metadata
and may run validation commands, but Codex must not directly mutate production
V source. Any required production mutation belongs to the assigned engineer.

The production pipeline is immutable and repeats forever until the chantier is
complete:

```text
1. Diagnostic by engineers and diagnostician/reviewers.
2. Explicit implementation authorization by the orchestrator.
3. Implementation by the assigned engineer only.
4. Reviewer v1 GO/HOLD on the implemented diff.
5. Orchestrator v2 validation with scoped tests, heavy gates when required,
   and hunk-hygiene checks.
6. Accept, or send back for rework and repeat the same pipeline.
```

Any production hunk created outside this pipeline is invalid. It must be
reworked by an engineer or restored to upstream shape before PR readiness.

No hunk is exempt because it is small, obvious, already reviewed in prose, or
needed to unblock a test. The same loop is mandatory forever: diagnostic,
orchestrator authorization, engineer implementation, reviewer GO/HOLD,
orchestrator validation, accept or rework.

Reinforcement 2026-06-21: this pipeline is infinite and applies to every
future continuation of this chantier. Codex must not directly edit production
code, production tests, production comments, production filenames, cleanup
hunks, or diagnostic-debris removal. Only external audit/ledger/resume metadata
may be updated directly by Codex.

Reinforcement 2026-06-21T02:33:49+02:00: there is no shortcut mode. Codex stays
orchestrator/final validator only forever; every production mutation must go
through diagnostic, explicit authorization, engineer implementation, reviewer
GO/HOLD, orchestrator validation/tests, then accept or rework.

Reinforcement 2026-06-21T04:37:16+02:00: the same pipeline remains mandatory for
every future hunk, including cleanup and test hunks. Codex must not directly
change production code, production tests, production comments, filenames,
cleanup, or diagnostic artifacts. Any direct production mutation by the
orchestrator is invalid until reworked by an engineer through the full pipeline.

## Decision States

```text
ADAPTED   V2 idea retained, but redesigned to fit V3 architecture.
REFUSED   Not suitable for V3, unsafe, too broad, or contrary to upstream design.
OBSOLETE  Solved upstream, replaced by V3 design, or no longer needed.
DEFERRED  Valid idea, but outside the current C-output-only PR scope.
```

`PORTED` is intentionally not a valid decision for this chantier. Even when a
V2 behavior is retained, the accepted state is `ADAPTED` plus an explicit V3
architecture fit.

## Validation States

```text
TODO       not started
DIAG       diagnosis in progress
PATCHED    engineer patch exists, not reviewer-approved
HOLD       reviewer refused or requested changes
GO-V1      reviewers accepted
GO-V2      orchestrator accepted after local validation
```

## Hunk Hygiene States

Every code hunk touched during migration must be classifiable during review.
This is separate from the item decision state because an accepted idea can still
leave behind obsolete probes, duplicated helpers, or partial experiments.

```text
KEEP        required by the accepted V3 implementation and covered by tests
BASELINE    historical baseline fix already accepted and still required
REWORK      useful intent, but current shape is too broad or not V3-native
RESTORE     remove the hunk and return that code to upstream shape
DEFER       valid future work, but not part of this PR/work slice
```

No item can move to `GO-V2` while a touched production hunk remains unclassified
or classified as `REWORK`/`RESTORE`. If a hunk is `BASELINE`, the ledger must
name the earlier item or audit section that accepted it.

## Mandatory Fields

Each item in `ledger.md` must include:

```text
- decision state: ADAPTED / REFUSED / OBSOLETE / DEFERRED
- validation state: TODO / DIAG / PATCHED / HOLD / GO-V1 / GO-V2
- owner team
- source ref; use path::test_name when a source test is known
- target refs; use path::test_name for tests or path for non-test files
- docs; include at least one relevant audit, doctrine, or README reference
- exact adaptation/refusal reason
- V3 architecture fit
- tests required
- reviewer verdict
- final orchestrator verdict
- hunk hygiene, when production code is already touched or reviewed
```

`V3 architecture fit` must make the decision explicit:

```text
ADAPTED   explain how the item is re-expressed through V3 architecture.
REFUSED   explain why the item does not fit V3 and must stay rejected.
OBSOLETE  explain which V3/upstream mechanism makes the item unnecessary.
DEFERRED  explain why it is outside current scope but may fit V3 later.
```

The validator requires this field to mention both `V3` and the item's decision
state, so a placeholder cannot pass as an architecture-fit justification.

## Golden Rules

```text
1. V3 upstream architecture wins. V2 code adapts to V3, never the reverse.
2. Current implementation scope is V3 C output only.
3. Native ARM64/X64 backend autofree is deferred.
4. No duplication, no quick hacks, no example-specific fixes.
5. No production names/comments with internal agent or phase markers.
6. Baseline V3 C output must compile/run before any autofree runtime claim.
7. Anything useless after validation must be removed, not left as dead code.
8. Engineers implement; diagnosticians review; orchestrator validates and tests.
9. V3 C output is the oracle for native backend comparison; improve that oracle
   without modifying native backends or adding backend-specific workarounds.
10. Touched hunks must be classified as KEEP, BASELINE, REWORK, RESTORE, or
    DEFER before approval; RESTORE means return to upstream shape.
11. Any changed V3 production file whose name, current content, staged diff, or
    unstaged diff mentions `autofree` must be linked to the issue #27116 super
    gate before acceptance through a specific file or subdirectory target; a
    broad `vlib/v3` target is not enough for this autofree check.
12. Codex never authors production V code directly. The only valid production
    route is diagnostic, orchestrator authorization, engineer implementation,
    reviewer GO/HOLD, orchestrator validation, then accept or rework.
```

## Files

```text
ledger.md         active decision ledger
inventory_*.md    detailed historical inventories auto-loaded with ledger.md
tools/            external validation helpers; removable with this whole directory
```

## Usage

Validate the active ledger from this directory:

```sh
python3 tools/validate_ledger.py ledger.md
```

When `ledger.md` is validated, the checker also validates every
`inventory_*.md` file in this directory. This keeps the main ledger compact
while making the historical inventory mandatory.

Optional marker scan for V3 target files named by ledger items:

```sh
python3 tools/validate_ledger.py ledger.md --scan-v3-markers
```

Worktree coverage for changed V3 files:

```sh
python3 tools/validate_ledger.py ledger.md --scan-v3-markers --check-worktree-coverage
```

The marker scan reads the V3 workspace but does not modify it. It flags
markers matching `Codex`, `agent`, `P0` through `P3`, `migration ledger`,
`v27116_v3_migration_ledger`, active ledger decision states, or the invalid
legacy token `PORTED` in listed `vlib/v3/...` target files. The default is strict
and scans tests too when a test file is listed as a target ref.

The validator also enforces issue #27116 autofree coverage. The ledger must keep
one complete super-gate item that includes the maintainer-required ownership and
double-free conditions. If a changed V3 production file is autofree-related
through its filename, directory path, current content, staged diff, unstaged
diff, or untracked/intent-to-add content, its ledger coverage must explicitly
link back to that super gate through a specific file target or an explicit
subdirectory target below `vlib/v3`. A broad root target such as `vlib/v3` can
cover general worktree hygiene, but it is ignored for this issue #27116 autofree
coverage rule. This catches `is_autofree`, `autofree_flag`, helper flags,
runtime hooks, C-output conditionals, absolute or relative target refs, future
`vlib/v3/autofree/...` implementation files, and generically named files like
`pref.v`, `stmt.v`, or `cleanc.v`.

Internal validator canaries, independent of the V workspace:

```sh
python3 tools/validate_ledger.py --self-test
```
