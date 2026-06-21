#!/usr/bin/env python3
"""Validate the V issue 27116 V3 migration ledger.

This is an external audit helper. It does not import or execute V code.
"""

from __future__ import annotations

import argparse
import glob
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


DECISIONS = {"ADAPTED", "REFUSED", "OBSOLETE", "DEFERRED"}
VALIDATIONS = {"TODO", "DIAG", "PATCHED", "HOLD", "GO-V1", "GO-V2"}
HUNK_HYGIENE_STATES = {"KEEP", "BASELINE", "REWORK", "RESTORE", "DEFER"}

DEFAULT_WORKSPACE = Path("/home/rei/dev-project/v27116_autofree_v3_migration_20260620")
NATIVE_TOKENS = (
    "arm64",
    "x64",
    "amd64",
    "native backend",
    "native backends",
    "vlib/v3/gen/arm64",
    "vlib/v3/gen/x64",
)
MARKER_RE = re.compile(
    r"(?i:\b(codex|agent)\b|migration ledger|v27116_v3_migration_ledger)"
    r"|\bP[0-3]\b|\b(ADAPTED|PORTED|REFUSED|OBSOLETE|DEFERRED)\b"
)
AUTOFREE_RE = re.compile(r"(?i)autofree")
ISSUE_27116_URL = "https://github.com/vlang/v/issues/27116"
ISSUE_27116_REQUIRED_TERMS = (
    "self-compiled autofree compiler",
    "examples/tetris",
    "vlib/v/tests/options/option_test.c.v",
    "shared sub-buffers",
    "non-owning pointer locals",
    "sumtype payload double-free",
    "pointer struct fields",
    "locals leaked into globals/struct fields",
    "ownership model",
    "escape analysis",
    "idempotent `_free`",
    "do not auto-emit `_free` for pointer struct fields",
    "do not `_v_free` the variant box",
    "V3 supersedes the V2 path",
)
ISSUE_27116_SUPER_GATE_NAME = "Maintainer issue 27116 autofree CI re-enable super gate"


@dataclass
class LedgerItem:
    source: Path
    name: str
    line: int
    fields: dict[str, str]
    body: str


def normalize_field(name: str) -> str:
    return re.sub(r"\s+", " ", name.strip().lower())


def parse_table_fields(lines: list[str]) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if len(cells) < 2:
            continue
        key, value = cells[0], cells[1]
        if not key or key.lower() == "field" or set(key) <= {"-"}:
            continue
        if set(value) <= {"-", " "}:
            continue
        fields[normalize_field(key)] = value
    return fields


def parse_items(text: str, source: Path) -> list[LedgerItem]:
    lines = text.splitlines()
    items: list[LedgerItem] = []
    current_name = ""
    current_line = 0
    current_lines: list[str] = []

    def flush() -> None:
        if current_name:
            body = "\n".join(current_lines)
            items.append(
                LedgerItem(
                    source=source,
                    name=current_name,
                    line=current_line,
                    fields=parse_table_fields(current_lines),
                    body=body,
                )
            )

    for idx, line in enumerate(lines, start=1):
        match = re.match(r"^##\s+Item:\s*(.+?)\s*$", line)
        if match:
            flush()
            current_name = match.group(1).strip()
            current_line = idx
            current_lines = []
            continue
        if current_name and line.startswith("## "):
            flush()
            current_name = ""
            current_line = 0
            current_lines = []
            continue
        if current_name:
            current_lines.append(line)
    flush()
    return items


def field_value(item: LedgerItem, aliases: tuple[str, ...]) -> str | None:
    for alias in aliases:
        value = item.fields.get(normalize_field(alias))
        if value is not None:
            return value
    return None


def validate_items(items: list[LedgerItem]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    if not items:
        errors.append("no '## Item:' sections found")
        return errors, warnings

    required = {
        "Decision": ("Decision",),
        "Validation": ("Validation", "Status"),
        "Owner": ("Owner",),
        "Source ref": ("Source ref",),
        "Target refs": ("Target refs",),
        "Docs": ("Docs",),
        "Adaptation rule": ("Adaptation rule",),
        "V3 architecture fit": ("V3 architecture fit",),
        "required tests": ("Required tests",),
        "reviewer verdict": ("Reviewer verdict",),
        "orchestrator verdict": ("Orchestrator verdict",),
    }

    for item in items:
        where = f"{item.source.name}:{item.name}:{item.line}"
        decision = field_value(item, required["Decision"])
        validation = field_value(item, required["Validation"])
        if decision not in DECISIONS:
            errors.append(
                f"{where}: Decision must be one of "
                f"{sorted(DECISIONS)}, got {decision!r}"
            )
        if validation not in VALIDATIONS:
            errors.append(
                f"{where}: Validation must be one of "
                f"{sorted(VALIDATIONS)}, got {validation!r}"
            )
        if decision == "DEFERRED" and validation not in {"TODO", "DIAG"}:
            errors.append(
                f"{where}: DEFERRED items must use TODO or DIAG validation, "
                f"got {validation!r}"
            )
        for label, aliases in required.items():
            value = field_value(item, aliases)
            if value is None or value.strip() == "":
                errors.append(f"{where}: missing {label}")
            elif value.strip().upper() in {"TBD", "TODO?", "UNKNOWN"}:
                warnings.append(f"{where}: weak {label}: {value!r}")
        architecture_fit = field_value(item, required["V3 architecture fit"])
        if architecture_fit:
            if "V3" not in architecture_fit:
                errors.append(
                    f"{where}: V3 architecture fit must explicitly mention V3"
                )
            if decision in DECISIONS and decision not in architecture_fit.upper():
                errors.append(
                    f"{where}: V3 architecture fit must explain the "
                    f"{decision} decision"
                )

        target_refs = field_value(item, required["Target refs"]) or ""
        target_paths = extract_paths_from_ref_text(target_refs)
        if not target_paths:
            errors.append(f"{where}: Target refs must contain at least one path")
        touches_v3 = any(normalize_v3_path(path) is not None for path in target_paths)
        hunk_hygiene = field_value(item, ("Hunk hygiene",))
        hunk_hygiene_required = touches_v3 and validation in {"PATCHED", "GO-V1", "GO-V2"}
        if hunk_hygiene_required or hunk_hygiene:
            if not hunk_hygiene:
                errors.append(
                    f"{where}: patched or accepted V3 production target "
                    f"requires Hunk hygiene with one of "
                    f"{sorted(HUNK_HYGIENE_STATES)}"
                )
            else:
                present = {
                    state
                    for state in HUNK_HYGIENE_STATES
                    if re.search(rf"\b{re.escape(state)}\b", hunk_hygiene)
                }
                if not present:
                    errors.append(
                        f"{where}: Hunk hygiene must include at least one "
                        f"known state from {sorted(HUNK_HYGIENE_STATES)}, "
                        f"got {hunk_hygiene!r}"
                    )
                if validation in {"GO-V1", "GO-V2"} and present & {"REWORK", "RESTORE"}:
                    errors.append(
                        f"{where}: accepted validation cannot keep "
                        f"REWORK/RESTORE hunk hygiene: {hunk_hygiene!r}"
                    )
        target_text = target_refs.lower()
        is_deferred_native = normalize_field(item.name) == "deferred native backends" and decision == "DEFERRED"
        if any(token in target_text for token in NATIVE_TOKENS) and not is_deferred_native:
            errors.append(
                f"{where}: native backend target is forbidden "
                "outside the Deferred Native Backends section"
            )
        docs = field_value(item, required["Docs"]) or ""
        docs_lower = docs.lower()
        if not (".md" in docs_lower or "readme" in docs_lower or "audit" in docs_lower or "http" in docs_lower):
            errors.append(
                f"{where}: Docs must reference a doc/audit/README path or URL"
            )

    errors.extend(validate_issue_27116_super_rule(items))
    errors.extend(validate_v3_autofree_target_coverage(items))

    return errors, warnings


def issue_27116_missing_terms(item: LedgerItem) -> list[str]:
    return [
        term
        for term in ISSUE_27116_REQUIRED_TERMS
        if term.lower() not in item.body.lower()
    ]


def item_links_issue_27116(item: LedgerItem) -> bool:
    body = item.body.lower()
    return (
        ISSUE_27116_URL in item.body
        or "issue #27116" in body
        or ISSUE_27116_SUPER_GATE_NAME.lower() in body
    )


def validate_issue_27116_super_rule(items: list[LedgerItem]) -> list[str]:
    matching_items = [item for item in items if ISSUE_27116_URL in item.body]
    if not matching_items:
        return [
            f"missing maintainer issue #27116 super-rule: no item references {ISSUE_27116_URL}"
        ]

    errors: list[str] = []
    for item in matching_items:
        missing_terms = issue_27116_missing_terms(item)
        if not missing_terms:
            return []
        where = f"{item.source.name}:{item.name}:{item.line}"
        errors.append(
            f"{where}: issue #27116 reference is incomplete; missing terms: "
            + ", ".join(missing_terms)
        )
    return errors


def validate_v3_autofree_target_coverage(items: list[LedgerItem]) -> list[str]:
    errors: list[str] = []
    super_gate_ok = any(
        ISSUE_27116_URL in item.body and not issue_27116_missing_terms(item)
        for item in items
    )
    if not super_gate_ok:
        return errors

    for item in items:
        target_refs = field_value(item, ("Target refs",)) or ""
        autofree_targets = sorted(
            path
            for path in extract_v3_paths_from_ref_text(target_refs)
            if is_v3_autofree_path(path)
        )
        if not autofree_targets:
            continue
        if not item_links_issue_27116(item):
            where = f"{item.source.name}:{item.name}:{item.line}"
            errors.append(
                f"{where}: V3 autofree target(s) must link to issue #27116 "
                f"super gate before acceptance: {', '.join(autofree_targets)}"
            )
    return errors


def is_v3_autofree_path(path: str) -> bool:
    rel = normalize_v3_path(path)
    if rel is None:
        return False
    return (
        rel == "vlib/v3/autofree"
        or rel.startswith("vlib/v3/autofree/")
        or "autofree" in Path(rel).name.lower()
    )


def changed_v3_path_mentions_autofree(path: str, workspace: Path) -> bool:
    rel = normalize_v3_path(path)
    if rel is None:
        return False
    if is_v3_autofree_path(rel):
        return True
    abs_path = workspace / rel
    try:
        if abs_path.is_file() and AUTOFREE_RE.search(
            abs_path.read_text(encoding="utf-8", errors="ignore")
        ):
            return True
    except OSError:
        pass
    for args in (
        ["git", "diff", "-U0", "--", rel],
        ["git", "diff", "--cached", "-U0", "--", rel],
    ):
        try:
            proc = subprocess.run(
                args,
                cwd=workspace,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except OSError:
            return False
        if proc.returncode != 0:
            continue
        for line in proc.stdout.splitlines():
            if line.startswith("+++") or line.startswith("---"):
                continue
            if line.startswith("+") or line.startswith("-"):
                if AUTOFREE_RE.search(line):
                    return True
    return False


def normalize_v3_path(path: str) -> str | None:
    cleaned = path.strip().strip("`'\"").split("::", 1)[0].rstrip(".,;")
    cleaned = cleaned.replace("\\", "/")
    while cleaned.startswith("./"):
        cleaned = cleaned[2:]
    marker = "vlib/v3"
    idx = cleaned.find(marker)
    if idx < 0:
        return None
    before_ok = idx == 0 or cleaned[idx - 1] == "/"
    after_idx = idx + len(marker)
    after_ok = after_idx == len(cleaned) or cleaned[after_idx] == "/"
    if not before_ok or not after_ok:
        return None
    return cleaned[idx:].rstrip("/")


def extract_v3_paths_from_ref_text(ref_text: str) -> set[str]:
    paths: set[str] = set()
    for path in extract_paths_from_ref_text(ref_text):
        rel = normalize_v3_path(path)
        if rel is not None:
            paths.add(rel)
    return paths


def extract_paths_from_ref_text(ref_text: str) -> set[str]:
    paths: set[str] = set()
    for ref in re.findall(r"`([^`]+)`", ref_text):
        path = ref.split("::", 1)[0]
        if "/" in path:
            paths.add(path)
    for ref in re.findall(r"([A-Za-z0-9_./-]+/[A-Za-z0-9_./*?-]+(?:::[A-Za-z0-9_]+)?)", ref_text):
        path = ref.split("::", 1)[0].rstrip(".,;")
        paths.add(path)
    return paths


def extract_target_paths(items: list[LedgerItem]) -> set[str]:
    paths: set[str] = set()
    for item in items:
        target_refs = field_value(item, ("Target refs",))
        if not target_refs:
            continue
        paths.update(extract_v3_paths_from_ref_text(target_refs))
    return paths


def v3_target_covers_path(target: str, path: str) -> bool:
    target = target.rstrip("/")
    return path == target or path.startswith(target + "/")


def is_broad_v3_root_target(target: str) -> bool:
    return normalize_v3_path(target) == "vlib/v3"


def extract_specific_v3_targets_from_ref_text(ref_text: str) -> set[str]:
    return {
        target
        for target in extract_v3_paths_from_ref_text(ref_text)
        if not is_broad_v3_root_target(target)
    }


def git_changed_paths(args: list[str], workspace: Path) -> tuple[set[str], list[str]]:
    try:
        proc = subprocess.run(
            args,
            cwd=workspace,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except OSError as exc:
        return set(), [f"worktree coverage: cannot run {' '.join(args)}: {exc}"]
    if proc.returncode != 0:
        return set(), [
            f"worktree coverage: {' '.join(args)} failed: {proc.stderr.strip()}"
        ]
    return {
        rel
        for line in proc.stdout.splitlines()
        if (rel := normalize_v3_path(line.strip())) is not None
    }, []


def git_status_paths(workspace: Path) -> tuple[set[str], list[str]]:
    try:
        proc = subprocess.run(
            ["git", "status", "--porcelain=v1", "--untracked-files=all", "--", "vlib/v3"],
            cwd=workspace,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except OSError as exc:
        return set(), [f"worktree coverage: cannot run git status: {exc}"]
    if proc.returncode != 0:
        return set(), [
            "worktree coverage: git status failed: " + proc.stderr.strip()
        ]
    paths: set[str] = set()
    for line in proc.stdout.splitlines():
        if len(line) < 4:
            continue
        raw = line[3:]
        if " -> " in raw:
            parts = raw.split(" -> ")
        else:
            parts = [raw]
        for part in parts:
            rel = normalize_v3_path(part)
            if rel is not None:
                paths.add(rel)
    return paths, []


def changed_v3_paths(workspace: Path) -> tuple[set[str], list[str]]:
    changed: set[str] = set()
    errors: list[str] = []
    commands = (
        ["git", "diff", "--name-only", "--", "vlib/v3"],
        ["git", "diff", "--cached", "--name-only", "--", "vlib/v3"],
        ["git", "ls-files", "--others", "--exclude-standard", "--", "vlib/v3"],
    )
    for args in commands:
        paths, new_errors = git_changed_paths(args, workspace)
        changed.update(paths)
        errors.extend(new_errors)
    status_paths, status_errors = git_status_paths(workspace)
    changed.update(status_paths)
    errors.extend(status_errors)
    return changed, errors


def check_worktree_coverage(items: list[LedgerItem], workspace: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    changed_set, change_errors = changed_v3_paths(workspace)
    if change_errors:
        return change_errors, warnings
    changed = sorted(changed_set)
    covered = sorted(extract_target_paths(items))
    missing: list[str] = []
    for path in changed:
        if not any(v3_target_covers_path(target, path) for target in covered):
            missing.append(path)
    for path in missing:
        errors.append(f"worktree coverage: changed V3 file has no ledger target ref: {path}")
    for path in changed:
        if not changed_v3_path_mentions_autofree(path, workspace):
            continue
        matching_items = [
            item
            for item in items
            if any(
                v3_target_covers_path(target, path)
                for target in extract_specific_v3_targets_from_ref_text(
                    field_value(item, ("Target refs",)) or ""
                )
            )
        ]
        if not matching_items:
            errors.append(
                "worktree coverage: changed V3 autofree-related file lacks "
                f"specific issue #27116 ledger target: {path}"
            )
            continue
        if not any(item_links_issue_27116(item) for item in matching_items):
            errors.append(
                "worktree coverage: changed V3 autofree-related file is not linked "
                "to issue #27116 super gate by a specific target: "
                f"{path}"
            )
    if not changed:
        warnings.append("worktree coverage: no changed vlib/v3 files detected")
    return errors, warnings


def scan_v3_markers(items: list[LedgerItem], workspace: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    for rel in sorted(extract_target_paths(items)):
        pattern = workspace / rel
        matches = [Path(p) for p in glob.glob(str(pattern))]
        if not matches:
            if changed_path_removed(rel, workspace):
                continue
            warnings.append(f"marker scan: target path not found: {rel}")
            continue
        for path in matches:
            if path.is_dir():
                for sub in path.rglob("*.v"):
                    errors.extend(scan_file_for_markers(sub, workspace))
            elif path.is_file():
                errors.extend(scan_file_for_markers(path, workspace))
    return errors, warnings


def changed_path_removed(rel: str, workspace: Path) -> bool:
    for args in (
        ["git", "diff", "--name-status", "--", rel],
        ["git", "diff", "--cached", "--name-status", "--", rel],
    ):
        try:
            proc = subprocess.run(
                args,
                cwd=workspace,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except OSError:
            return False
        for line in proc.stdout.splitlines():
            parts = line.split("\t")
            if not parts:
                continue
            status = parts[0]
            if status.startswith("D") and len(parts) > 1 and parts[1] == rel:
                return True
            if status.startswith("R") and len(parts) > 1 and parts[1] == rel:
                return True
    return False


def scan_file_for_markers(path: Path, workspace: Path) -> list[str]:
    errors: list[str] = []
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError as exc:
        return [f"marker scan: cannot read {path}: {exc}"]
    rel = path.relative_to(workspace) if path.is_relative_to(workspace) else path
    for idx, line in enumerate(text.splitlines(), start=1):
        if MARKER_RE.search(line):
            errors.append(f"{rel}:{idx}: forbidden marker: {line.strip()}")
    return errors


def ledger_files_for(path: Path) -> list[Path]:
    files = [path]
    if path.name == "ledger.md":
        for extra in sorted(path.parent.glob("inventory_*.md")):
            if extra not in files:
                files.append(extra)
    return files


def self_test() -> int:
    errors: list[str] = []

    def check(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    def test_item(name: str, target_refs: str, links_issue: bool) -> LedgerItem:
        body = ISSUE_27116_URL if links_issue else ""
        return LedgerItem(
            source=Path("self_test.md"),
            name=name,
            line=1,
            fields={"target refs": target_refs},
            body=body,
        )

    check(AUTOFREE_RE.search("is_autofree") is not None, "is_autofree not detected")
    check(AUTOFREE_RE.search("autofree_flag") is not None, "autofree_flag not detected")
    check(
        normalize_v3_path("/tmp/ws/vlib/v3/autofree/foo.v::test") == "vlib/v3/autofree/foo.v",
        "absolute vlib/v3 target ref not normalized",
    )
    check(
        normalize_v3_path("vlib/v3/gen/c/stmt.v") == "vlib/v3/gen/c/stmt.v",
        "relative vlib/v3 target ref not normalized",
    )
    check(is_v3_autofree_path("vlib/v3/autofree/foo.v"), "autofree directory not detected")

    with tempfile.TemporaryDirectory() as tmp:
        workspace = Path(tmp)
        subprocess.run(["git", "init", "-q"], cwd=workspace, check=True)
        staged = workspace / "vlib/v3/pref/pref.v"
        intent = workspace / "vlib/v3/gen/c/fn.v"
        untracked = workspace / "vlib/v3/autofree/foo.v"
        staged.parent.mkdir(parents=True, exist_ok=True)
        intent.parent.mkdir(parents=True, exist_ok=True)
        untracked.parent.mkdir(parents=True, exist_ok=True)
        staged.write_text("module pref\nconst is_autofree = true\n", encoding="utf-8")
        intent.write_text("module c\nconst autofree_flag = true\n", encoding="utf-8")
        untracked.write_text("module autofree\n", encoding="utf-8")
        subprocess.run(["git", "add", "vlib/v3/pref/pref.v"], cwd=workspace, check=True)
        subprocess.run(["git", "add", "-N", "vlib/v3/gen/c/fn.v"], cwd=workspace, check=True)
        changed, change_errors = changed_v3_paths(workspace)
        check(not change_errors, "changed_v3_paths reported errors: " + "; ".join(change_errors))
        for rel in (
            "vlib/v3/pref/pref.v",
            "vlib/v3/gen/c/fn.v",
            "vlib/v3/autofree/foo.v",
        ):
            check(rel in changed, f"{rel} not collected as changed")
            check(
                changed_v3_path_mentions_autofree(rel, workspace),
                f"{rel} not detected as autofree-related",
            )

    with tempfile.TemporaryDirectory() as tmp:
        workspace = Path(tmp)
        subprocess.run(["git", "init", "-q"], cwd=workspace, check=True)
        pref = workspace / "vlib/v3/pref/pref.v"
        pref.parent.mkdir(parents=True, exist_ok=True)
        pref.write_text("module pref\nconst is_autofree = true\n", encoding="utf-8")
        subprocess.run(["git", "add", "vlib/v3/pref/pref.v"], cwd=workspace, check=True)
        broad_only_errors, _ = check_worktree_coverage(
            [test_item("broad", "vlib/v3", True)],
            workspace,
        )
        check(
            any("vlib/v3/pref/pref.v" in error for error in broad_only_errors),
            "broad vlib/v3 target incorrectly satisfied autofree #27116 coverage",
        )
        specific_errors, _ = check_worktree_coverage(
            [
                test_item("broad", "vlib/v3", True),
                test_item("specific", "vlib/v3/pref/pref.v", True),
            ],
            workspace,
        )
        check(
            not specific_errors,
            "specific autofree #27116 target did not satisfy coverage: "
            + "; ".join(specific_errors),
        )

    if errors:
        for error in errors:
            print(f"SELF-TEST ERROR: {error}")
        print(f"SELF-TEST FAIL: {len(errors)} error(s)")
        return 1
    print("SELF-TEST PASS")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "ledger",
        nargs="?",
        default="ledger.md",
        help="ledger Markdown file to validate (default: ledger.md)",
    )
    parser.add_argument(
        "--scan-v3-markers",
        action="store_true",
        help="scan V3 target files for forbidden Codex/agent/P0-P3 markers",
    )
    parser.add_argument(
        "--check-worktree-coverage",
        action="store_true",
        help="ensure every changed vlib/v3 file is referenced by the ledger",
    )
    parser.add_argument(
        "--workspace",
        default=str(DEFAULT_WORKSPACE),
        help=f"V3 workspace for marker scan (default: {DEFAULT_WORKSPACE})",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="run internal canaries for V3 autofree path and git-state detection",
    )
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    ledger_path = Path(args.ledger)
    ledger_paths = ledger_files_for(ledger_path)
    missing = [path for path in ledger_paths if not path.exists()]
    if missing:
        print(f"ERROR: ledger not found: {missing[0]}", file=sys.stderr)
        return 2

    items: list[LedgerItem] = []
    for path in ledger_paths:
        text = path.read_text(encoding="utf-8")
        items.extend(parse_items(text, path))
    errors, warnings = validate_items(items)

    if args.scan_v3_markers:
        marker_errors, marker_warnings = scan_v3_markers(items, Path(args.workspace))
        errors.extend(marker_errors)
        warnings.extend(marker_warnings)
    if args.check_worktree_coverage:
        coverage_errors, coverage_warnings = check_worktree_coverage(items, Path(args.workspace))
        errors.extend(coverage_errors)
        warnings.extend(coverage_warnings)

    for warning in warnings:
        print(f"WARNING: {warning}")
    for error in errors:
        print(f"ERROR: {error}")

    print(f"checked {len(items)} ledger item(s) across {len(ledger_paths)} file(s)")
    if errors:
        print(f"FAIL: {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1
    print(f"PASS: 0 error(s), {len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
