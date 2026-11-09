# Created: 2026-11-08 21:14 -06:00 · Edited: 2026-11-08 21:14 -06:00
"""Every cited ID resolves in THIS project (`C0`; replaces the corpus-wide citation check).

    python3 scripts/check_ids.py

A backticked ID such as `D4`, `RR3`, `C2-T4` or `FR6`, written in this project's own
files, must be defined here: as a row of docs/plans/00-register.md, or as an FR/NFR row of
the spec. A task ID resolves when its parent unit does. An ID written right after the word
"upstream" cites turing-review and is skipped.

Scanned: CLAUDE.md, docs/ (except the vendored docs/conventions.md and the generated
status page, whose wording is the vendored generator's), .githooks/, tests/,
CountdownCore/, .github/, and scripts/ except the files pinned in scripts/UPSTREAM_PIN.
It reads no other project, so it means the same thing on a lone CI clone as here.

Exit 1 on any unresolved ID, or when nothing was read.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTER = ROOT / "docs" / "plans" / "00-register.md"
SPEC = ROOT / "docs" / "specs" / "countdown-widget-spec.md"
ID = re.compile(r"(?<!upstream )`(?P<id>(?:NFR|FR|RR|[DOAHMGCF])\d+[a-z]?)(?P<task>-T\d+)?`")
SUFFIXES = {".md", ".py", ".sh", ".swift", ".yml", ".json", ""}


def defined() -> set[str]:
    reg = re.findall(r"^\| (?:~~)?([A-Z]{1,3}\d+[a-z]?)(?:~~)? \|",
                     REGISTER.read_text(encoding="utf-8"), re.M)
    spec = re.findall(r"^\| (N?FR\d+) \|", SPEC.read_text(encoding="utf-8"), re.M)
    return set(reg) | set(spec)


def files() -> list[Path]:
    pin = (ROOT / "scripts" / "UPSTREAM_PIN").read_text(encoding="utf-8")
    vendored = {ROOT / p for p in re.findall(r"^[0-9a-f]{64}\s+(\S+)", pin, re.M)}
    out = [ROOT / "CLAUDE.md"]
    for d in ("docs", ".githooks", "tests", "CountdownCore", ".github", "scripts"):
        out += [f for f in (ROOT / d).rglob("*") if f.is_file() and f.suffix in SUFFIXES
                and ".build" not in f.parts and "__pycache__" not in f.parts]
    skip = vendored | {ROOT / "docs" / "conventions.md", ROOT / "docs" / "plans" / "00-status.md",
            Path(__file__).resolve()}
    return [f for f in out if f.is_file() and f not in skip]


def main() -> int:
    ids, bad, seen = defined(), [], 0
    if not ids:
        print("IDs FAIL — nothing defined in the register or spec. Checking nothing is not a pass.")
        return 1
    for f in files():
        for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            for m in ID.finditer(line):
                seen += 1
                if m.group("id") not in ids:
                    bad.append(f"{f.relative_to(ROOT)}:{n}: `{m.group(0).strip('`')}` is not defined here")
    if not seen:
        print("IDs FAIL — no citations read. Checking nothing is not a pass.")
        return 1
    if bad:
        print(f"\nIDs FAIL — {len(bad)} unresolved\n")
        print("\n".join(f"  {b}" for b in bad))
        return 1
    print(f"IDs pass — {seen} citation(s), all defined in this project")
    return 0


if __name__ == "__main__":
    sys.exit(main())
