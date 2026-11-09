# Created: 2026-11-08 21:11 -06:00 · Edited: 2026-11-08 21:11 -06:00
"""Harness `mutate` (`C1`): apply each named mutation, confirm its test goes red, restore.

    python3 scripts/mutate.py            # run every mutation in tests/mutations.json
    python3 scripts/mutate.py M1         # run one
    python3 scripts/mutate.py --write    # also write each result into the register

tests/mutations.json holds the mechanics: the file, the exact text to find (it must occur
exactly once), its replacement, and `caught_by`, the Swift Testing identifier of the test
that must fail (for example `HoursTests/neverRoundsUp`). The register's Mutations table
holds the description and the result; every id here must have a row there.

A mutation is `killed` only when all three hold:
  1. the named test runs and passes on the untouched code;
  2. with the edit applied, that test runs (exactly one test executed) and fails;
  3. the file is restored byte-identical afterwards.
Anything else is `survived` (the test stayed green) or an error (the mutation is invalid).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "tests" / "mutations.json"
REGISTER = ROOT / "docs" / "plans" / "00-register.md"
RAN = re.compile(r"Test run with (\d+) tests? in \d+ suites? (passed|failed)")


def run_one_test(caught_by: str) -> tuple[int, str]:
    """(tests executed, 'passed'|'failed'|'none') for a --filter run of one test."""
    r = subprocess.run(["swift", "test", "--package-path", str(ROOT / "CountdownCore"),
                        "--filter", re.escape(caught_by)],
                       capture_output=True, text=True)
    m = None
    for m in RAN.finditer(r.stdout + r.stderr):
        pass
    if not m:
        return 0, "none"
    return int(m.group(1)), m.group(2)


def mutate(m: dict) -> tuple[str, str]:
    """(result, detail). result is killed | survived | invalid."""
    path = ROOT / m["file"]
    original = path.read_bytes()
    text = original.decode("utf-8")
    if text.count(m["find"]) != 1:
        return "invalid", f"`find` occurs {text.count(m['find'])} times in {m['file']}, not once"
    n, state = run_one_test(m["caught_by"])
    if n != 1 or state != "passed":
        return "invalid", f"on clean code `{m['caught_by']}` ran {n} test(s), {state}"
    try:
        path.write_text(text.replace(m["find"], m["replace"]), encoding="utf-8")
        n, state = run_one_test(m["caught_by"])
    finally:
        path.write_bytes(original)
    if path.read_bytes() != original:
        return "invalid", f"{m['file']} was not restored"
    if n == 1 and state == "failed":
        return "killed", f"`{m['caught_by']}` failed with the edit applied"
    return "survived", f"with the edit applied `{m['caught_by']}` ran {n} test(s), {state}"


def write_register(results: dict[str, str]) -> None:
    text = REGISTER.read_text(encoding="utf-8")
    today = date.today().isoformat()
    for mid, result in results.items():
        run = "run" if result == "killed" else "escaped"
        row = re.compile(rf"^(\| {mid} \|.*\| )[^|]*( \|)$", re.M)
        text, n = row.subn(rf"\g<1>{result} {today} — Run: {run}\g<2>", text)
        if n != 1:
            raise SystemExit(f"mutate: register has {n} rows for {mid}, expected 1")
    REGISTER.write_text(text, encoding="utf-8")


def main(argv: list[str]) -> int:
    write = "--write" in argv
    wanted = [a for a in argv[1:] if not a.startswith("-")]
    mutations = json.loads(SPEC.read_text(encoding="utf-8"))
    register = REGISTER.read_text(encoding="utf-8")
    missing = [m["id"] for m in mutations if not re.search(rf"^\| {m['id']} \|", register, re.M)]
    if missing:
        print(f"mutate: no register row for {', '.join(missing)}")
        return 1
    chosen = [m for m in mutations if not wanted or m["id"] in wanted]
    if not chosen:
        print("mutate: no mutations selected. Running nothing is not a pass.")
        return 1
    results, bad = {}, 0
    for m in chosen:
        result, detail = mutate(m)
        print(f"  {m['id']:4} {result:8} {detail}")
        if result == "invalid":
            bad = 1
        else:
            results[m["id"]] = result
            bad |= result != "killed"
    if write and results:
        write_register(results)
    killed = sum(r == "killed" for r in results.values())
    print(f"mutate: {killed} of {len(chosen)} killed")
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv))
