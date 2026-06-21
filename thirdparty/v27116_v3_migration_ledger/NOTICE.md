# V27116 V3 Migration Ledger Notice

This directory vendors the project ledger used for the V issue 27116 V3 migration
work. It is intentionally stored under `thirdparty/` so the migration state,
review rules, and validation script can travel with the development branch
without being mixed into the V3 compiler source tree.

## Purpose

The ledger is the control document for the V2-to-V3 migration and the later
V3-only autofree implementation. It is not compiler runtime data and it is not
used by V at build time. It exists to keep the migration auditable.

The ledger answers four questions for each migrated or proposed change:

1. What historical V2 or project item is being considered?
2. Is it adapted to the V3 architecture, obsolete, refused, or still pending?
3. Which tests or reviews prove the decision?
4. Is the hunk clean enough to keep in a future PR?

## Files

- `README.md`: operating rules for the ledger and the migration workflow.
- `ledger.md`: current canonical decision log for V3 migration items.
- `inventory_v2.md`: historical V2 inventory used to ensure no important item is
  forgotten during the migration.
- `NEXT_SESSION_RESUME_VLANG_27116_V3_ORACLE_2026-06-21.md`: latest handoff
  document for the active V3/C oracle phase, including current blocker,
  validation state, and resume checklist.
- `tools/validate_ledger.py`: local validation helper for ledger consistency and
  optional V3 worktree marker coverage.

Generated Python caches are deliberately not vendored.

## Workflow

The ledger is used before and after code changes.

Before implementation:

1. Read `README.md`.
2. Find or create the relevant item in `ledger.md`.
3. Classify the item as adapted, obsolete, refused, or pending.
4. Record the V3 architecture fit.
5. Record the planned validation.
6. Only then allow an engineer to implement the production change.

After implementation:

1. Review the production diff against the ledger item.
2. Record reviewer GO/HOLD.
3. Run the focused tests listed in the item.
4. Run the ledger validator.
5. Update the item to reflect the real result.

Codex remains the orchestrator/final validator only. Production code, production
tests, comments, filenames, cleanup hunks, and diagnostic debris must be changed
only by assigned engineers after diagnostics and before reviewer GO/HOLD.

## Validation Commands

Run from the repository root.

Basic ledger validation:

```bash
python3 thirdparty/v27116_v3_migration_ledger/tools/validate_ledger.py \
  thirdparty/v27116_v3_migration_ledger/ledger.md
```

Ledger validation with V3 marker scan:

```bash
python3 thirdparty/v27116_v3_migration_ledger/tools/validate_ledger.py \
  --scan-v3-markers \
  thirdparty/v27116_v3_migration_ledger/ledger.md
```

Ledger validation with worktree coverage:

```bash
python3 thirdparty/v27116_v3_migration_ledger/tools/validate_ledger.py \
  --scan-v3-markers \
  --check-worktree-coverage \
  thirdparty/v27116_v3_migration_ledger/ledger.md
```

The external audit copy can still be validated from its original location:

```bash
python3 /home/rei/dev-project/audit/v27116_v3_migration_ledger/tools/validate_ledger.py \
  --scan-v3-markers \
  --check-worktree-coverage \
  /home/rei/dev-project/audit/v27116_v3_migration_ledger/ledger.md
```

## Status Meanings

- `DIAG`: diagnosis is in progress.
- `PATCHED`: an engineer patch exists but has not yet received reviewer GO.
- `HOLD`: a reviewer refused the hunk or requested rework.
- `GO-V1`: reviewers accepted the hunk.
- `GO-V2`: orchestrator validation accepted the hunk after tests.
- `REWORK`: the hunk or strategy must be changed.
- `OBSOLETE`: the historical item does not fit V3 or is superseded.
- `REFUSED`: the item is intentionally not migrated.

## Project Rules Captured By The Ledger

- V3 README is the first architecture source of truth.
- V2 work must adapt to V3; V3 must not be bent around old V2 shapes.
- No duplication or quick workaround is acceptable when a V3-native design is
  required.
- Native backend work is outside the V3 C oracle/autofree PR scope.
- Phase 1 is the V3 C oracle baseline.
- Phase 2 is V3-only autofree and starts only after Phase 1 is clean and pushed.
- The V issue 27116 autofree requirements are hard constraints for Phase 2.
- Any useless diagnostic code, stale patch, internal agent name, or milestone
  marker must be removed or refused before PR readiness.

## Current Use In This Branch

This branch still has active V3 migration work. The ledger snapshot is included
so reviewers can inspect the complete historical decision trail. It should not
be treated as final upstream documentation unless the branch owner decides to
keep it for the PR. It can also be removed before PR submission if the project
prefers not to vendor migration governance material.
