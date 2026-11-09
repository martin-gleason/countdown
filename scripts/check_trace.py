# Created: 2026-11-08 21:11 -06:00 · Edited: 2026-11-08 21:28 -06:00
"""Requirement trace, register hook H6 (`C1`): drift, checked in both directions.

    python3 scripts/check_trace.py [--base REV] [--scratch-path DIR]

Backward: every Swift Testing `@Test` has a display name citing a real `FR<n>`/`NFR<n>`
from the spec's requirements table, or a ratified `D<n>` from the register.
Forward: every `FR`/`NFR` is cited by at least one test, or is listed in
tests/UNTESTED_REQUIREMENTS, a ratchet that may shrink and never grow compared with
`--base` (default `HEAD`; CI passes the merge base, since there HEAD is the commit
under test).

**The tests read are the tests that exist.** Sources are parsed with comments removed and
string contents masked, so `@Test(…)` arguments with parentheses, traits and `arguments:`
parse, and a commented-out test is not a test. The parsed test functions are then compared
with `swift test list`, which names what was actually built: a test the parser missed, a
test inside `#if false`, or an XCTest method fails the check rather than passing silently.

Exit 1 on any problem. Reports every one.
"""
from __future__ import annotations

import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "specs" / "countdown-widget-spec.md"
REGISTER = ROOT / "docs" / "plans" / "00-register.md"
PACKAGE = ROOT / "CountdownCore"
TESTS = PACKAGE / "Tests"
UNTESTED = ROOT / "tests" / "UNTESTED_REQUIREMENTS"
CITE = re.compile(r"\b(NFR\d+|FR\d+|D\d+)\b")


def mask(src: str) -> str:
    """Same length as `src`: comments become spaces, string contents become `_`.

    Handles `//`, nested `/* */`, "…", raw #"…"#, and multi-line \"\"\"…\"\"\" literals.
    Newlines are kept so offsets and line numbers still line up.
    """
    out, i, n = list(src), 0, len(src)

    def blank(a: int, b: int, ch: str) -> None:
        for j in range(a, b):
            if out[j] != "\n":
                out[j] = ch

    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            blank(i, j, " ")
            i = j
        elif src.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif src.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            blank(i, j, " ")
            i = j
        elif src[i] == '"' or (src[i] == "#" and re.match(r'#+"', src[i:])):
            hashes = len(re.match(r"#*", src[i:]).group(0))
            q = i + hashes
            triple = src.startswith('"""', q)
            open_len = 3 if triple else 1
            close = ('"""' if triple else '"') + "#" * hashes
            j = q + open_len
            while j < n:
                if hashes == 0 and src[j] == "\\":
                    j += 2
                    continue
                if src.startswith(close, j):
                    break
                if not triple and src[j] == "\n":
                    break
                j += 1
            blank(q + open_len, j, "_")
            i = j + len(close)
        else:
            i += 1
    return "".join(out)


def balanced(masked: str, start: int) -> int:
    """Index just past the `)` matching the `(` at `start`, in masked text."""
    depth = 0
    for j in range(start, len(masked)):
        if masked[j] == "(":
            depth += 1
        elif masked[j] == ")":
            depth -= 1
            if depth == 0:
                return j + 1
    return len(masked)


def parse(path: Path) -> list[tuple[str, str, int]]:
    """(function name, display name or "", line) for each @Test in `path`."""
    src = path.read_text(encoding="utf-8")
    m = mask(src)
    found = []
    for t in re.finditer(r"@Test\b", m):
        j = t.end()
        name = ""
        k = j
        while k < len(m) and m[k] in " \t\n":
            k += 1
        if k < len(m) and m[k] == "(":
            end = balanced(m, k)
            first = re.match(r'\s*(#*)"', src[k + 1:end])
            if first:
                s = k + 1 + first.end()          # just inside the opening quote
                e = m.find('"', s)
                name = src[s:e]
            j = end
        rest = m[j:]
        while True:                              # attributes and modifiers before `func`
            a = re.match(r"\s*@\w+", rest)
            if a:
                after = a.end()
                if rest[after:after + 1] == "(":
                    after = balanced(rest, after)
                rest = rest[after:]
                continue
            mod = re.match(r"\s*(static|mutating|nonisolated|private|fileprivate|internal|public)\b", rest)
            if mod:
                rest = rest[mod.end():]
                continue
            break
        f = re.match(r"\s*func\s+(\w+)", rest)
        line = src.count("\n", 0, t.start()) + 1
        found.append((f.group(1) if f else "", name, line))
    return found


def listed_tests(scratch: str | None) -> list[str] | None:
    """Function base names from `swift test list`, or None if it could not run."""
    cmd = ["swift", "test", "list", "--package-path", str(PACKAGE)]
    if scratch:
        cmd += ["--scratch-path", scratch]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        return None
    # `Module.Suite/func(args)` for a test in a type; `Module.func()` for a free function.
    names = []
    for line in r.stdout.splitlines():
        line = line.strip()
        if not re.match(r"^\w+\.\S+$", line):
            continue
        last = line.rsplit("/", 1)[-1] if "/" in line else line.split(".", 1)[1]
        names.append(re.sub(r"\(.*$", "", last))
    return names


def requirements() -> set[str]:
    return set(re.findall(r"^\| (N?FR\d+) \|", SPEC.read_text(encoding="utf-8"), re.M))


def ratified() -> set[str]:
    return set(re.findall(r"^\| (D\d+) \| ratified", REGISTER.read_text(encoding="utf-8"), re.M))


def entries(text: str) -> set[str]:
    return {line.split("#")[0].strip() for line in text.splitlines()} - {""}


def main(argv: list[str]) -> int:
    base = argv[argv.index("--base") + 1] if "--base" in argv else "HEAD"
    scratch = argv[argv.index("--scratch-path") + 1] if "--scratch-path" in argv else None
    reqs, decisions = requirements(), ratified()
    if not reqs:
        print("H6 FAIL — no FR/NFR rows read from the spec. Checking nothing is not a pass.")
        return 1
    problems, cited, parsed = [], set(), []
    for f in sorted(TESTS.rglob("*.swift")):
        rel = f.relative_to(ROOT)
        for func, name, line in parse(f):
            if not func:
                problems.append(f"{rel}:{line}: @Test with no function after it could not be read")
                continue
            parsed.append(func)
            ids = CITE.findall(name)
            good = [i for i in ids if i in reqs or i in decisions]
            for i in ids:
                if i not in reqs and i not in decisions:
                    problems.append(f"{rel}:{line}: {func} cites {i}, which is not a requirement or a ratified decision")
            if not good:
                problems.append(f"{rel}:{line}: {func} cites no FR, NFR or ratified D in its display name")
            cited |= set(good)
    built = listed_tests(scratch)
    if built is None:
        problems.append("`swift test list` failed, so the parsed tests could not be checked against the built ones")
    else:
        for name, n in (Counter(built) - Counter(parsed)).items():
            problems.append(f"{name}: built and run, but not parsed as a Swift Testing @Test "
                            f"(an XCTest method, or a form this parser misses) ×{n}")
        for name, n in (Counter(parsed) - Counter(built)).items():
            problems.append(f"{name}: parsed as an @Test but not built (inside #if, or not compiled) ×{n}")
    untested = entries(UNTESTED.read_text(encoding="utf-8")) if UNTESTED.is_file() else set()
    for r in sorted(reqs - cited - untested, key=lambda x: (x[0], int(re.sub(r"\D", "", x)))):
        problems.append(f"{r} has no test and is not in tests/UNTESTED_REQUIREMENTS")
    for r in sorted(untested & cited):
        problems.append(f"{r} now has a test; remove it from tests/UNTESTED_REQUIREMENTS")
    prior = subprocess.run(["git", "show", f"{base}:tests/UNTESTED_REQUIREMENTS"], cwd=ROOT,
                           capture_output=True, text=True)
    if prior.returncode == 0:
        for r in sorted(untested - entries(prior.stdout)):
            problems.append(f"{r} was added to tests/UNTESTED_REQUIREMENTS since {base}; the list may only shrink")
    if not parsed:
        problems.append("no @Test found under CountdownCore/Tests. Checking nothing is not a pass.")
    if problems:
        print(f"\nH6 FAIL — {len(problems)} problem(s)\n")
        for p in problems:
            print(f"  {p}")
        print()
        return 1
    print(f"H6 pass — {len(parsed)} test(s), matching `swift test list`, trace to the spec or the "
          f"register; {len(cited)} requirement(s) tested, {len(untested)} listed as untested")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
