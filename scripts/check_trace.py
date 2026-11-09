# Created: 2026-11-08 21:11 -06:00 · Edited: 2026-11-08 21:11 -06:00
"""Requirement trace, register hook H6 (`C1`): drift, checked in both directions.

    python3 scripts/check_trace.py

Backward: every Swift Testing `@Test` carries a display name citing a real `FR<n>` or
`NFR<n>` from the spec's requirements table, or a ratified `D<n>` from the register.
Forward: every `FR`/`NFR` is cited by at least one test, or is listed in
tests/UNTESTED_REQUIREMENTS. That list is a ratchet: it may shrink and never grow
(compared with the committed version at HEAD).

Exit 1 on any problem. Reports every one.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "specs" / "countdown-widget-spec.md"
REGISTER = ROOT / "docs" / "plans" / "00-register.md"
TESTS = ROOT / "CountdownCore" / "Tests"
UNTESTED = ROOT / "tests" / "UNTESTED_REQUIREMENTS"
TEST = re.compile(r"@Test(?:\s*\((?P<args>[^)]*)\))?\s*(?:@\w+\s*)*func\s+(?P<name>\w+)", re.S)
CITE = re.compile(r"\b(NFR\d+|FR\d+|D\d+)\b")


def requirements() -> set[str]:
    rows = re.findall(r"^\| (N?FR\d+) \|", SPEC.read_text(encoding="utf-8"), re.M)
    return set(rows)


def ratified() -> set[str]:
    rows = re.findall(r"^\| (D\d+) \| ratified", REGISTER.read_text(encoding="utf-8"), re.M)
    return set(rows)


def listed(text: str) -> set[str]:
    return {line.split("#")[0].strip() for line in text.splitlines()} - {""}


def main() -> int:
    reqs, decisions = requirements(), ratified()
    if not reqs:
        print("H6 FAIL — no FR/NFR rows read from the spec. Checking nothing is not a pass.")
        return 1
    problems, cited, tests = [], set(), 0
    for f in sorted(TESTS.rglob("*.swift")):
        rel = f.relative_to(ROOT)
        for m in TEST.finditer(f.read_text(encoding="utf-8")):
            tests += 1
            ids = CITE.findall(m.group("args") or "")
            good = [i for i in ids if i in reqs or i in decisions]
            bad = [i for i in ids if i not in reqs and i not in decisions]
            for i in bad:
                problems.append(f"{rel}: {m.group('name')} cites {i}, which is not a requirement or a ratified decision")
            if not good:
                problems.append(f"{rel}: {m.group('name')} cites no FR, NFR or ratified D in its display name")
            cited |= set(good)
    untested = listed(UNTESTED.read_text(encoding="utf-8")) if UNTESTED.is_file() else set()
    for r in sorted(reqs - cited - untested, key=lambda x: (x[0], int(re.sub(r"\D", "", x)))):
        problems.append(f"{r} has no test and is not in tests/UNTESTED_REQUIREMENTS")
    for r in sorted(untested & cited):
        problems.append(f"{r} now has a test; remove it from tests/UNTESTED_REQUIREMENTS")
    head = subprocess.run(["git", "show", "HEAD:tests/UNTESTED_REQUIREMENTS"], cwd=ROOT,
                          capture_output=True, text=True)
    if head.returncode == 0:
        grew = untested - listed(head.stdout)
        for r in sorted(grew):
            problems.append(f"{r} was added to tests/UNTESTED_REQUIREMENTS; the list may only shrink")
    if not tests:
        problems.append("no @Test found under CountdownCore/Tests. Checking nothing is not a pass.")
    if problems:
        print(f"\nH6 FAIL — {len(problems)} problem(s)\n")
        for p in problems:
            print(f"  {p}")
        print()
        return 1
    print(f"H6 pass — {tests} test(s) trace to the spec or the register; "
          f"{len(cited)} requirement(s) tested, {len(untested)} listed as untested")
    return 0


if __name__ == "__main__":
    sys.exit(main())
