# Created: 2026-09-24 08:22 -05:00 · Edited: 2026-09-24 09:31 -05:00
"""Write or check the Created/Edited stamp at the top of a file (`D76`).

    python3 scripts/stamp.py FILE...      # add a stamp, or move Edited to now
    python3 scripts/stamp.py --check      # H15: every staged file carries a current stamp

The stamp is one line near the top of the file:

    Created: 2026-09-24 08:55 -05:00 · Edited: 2026-09-24 09:40 -05:00

Markdown gets it as a plain line under the title. Code gets it as a comment on the
first line (after a shebang). Created comes from git's first commit of the file when
there is one, otherwise now. Edited is always now.

`--check` looks at the files staged for commit. Each must carry a stamp in its first
five lines, and a file that was committed before must have an Edited time later than
that commit — otherwise the edit was not stamped.

What it measures: Edited minus Created is elapsed calendar time, not hours of effort.
Git keeps the full history; the stamp puts the span where a reader sees it.
"""
from __future__ import annotations

import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

COMMENT = {".py": "#", ".sh": "#", ".yml": "#", ".yaml": "#", ".r": "#", ".R": "#",
           ".js": "//", ".ts": "//", ".swift": "//", ".rs": "//", ".go": "//"}
DOCS = {".md"}
FMT = "%Y-%m-%d %H:%M %z"
STAMP = re.compile(r"Created: (?P<c>\d{4}-\d\d-\d\d(?: \d\d:\d\d [+-]\d\d:?\d\d)?)"
                   r" · Edited: (?P<e>\d{4}-\d\d-\d\d \d\d:\d\d [+-]\d\d:?\d\d)")
# Files that must not carry a clock: a generated page (status, the H12 ledger) would
# never match its own regeneration, and a vendored conventions copy is upstream's text, not ours.
EXEMPT = re.compile(r"(^|/)(00-status\.md|00-instructions\.md|docs/conventions\.md)$|(^|/)tests/fixtures/")


def now() -> str:
    return _colon(datetime.now().astimezone().strftime(FMT))


def _colon(s: str) -> str:
    """-0500 -> -05:00, which is easier to read."""
    return re.sub(r"([+-]\d\d)(\d\d)$", r"\1:\2", s)


def _parse(s: str) -> datetime:
    if len(s) == 10:                                  # a date-only Created
        s += " 00:00 +00:00"
    return datetime.strptime(re.sub(r"([+-]\d\d):(\d\d)$", r"\1\2", s), FMT)


def git(*args: str, cwd: Path | None = None) -> str:
    """Run git in the current directory, so the tool works in any repo."""
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def first_commit(path: Path) -> str:
    out = git("log", "--diff-filter=A", "--follow", "--format=%ad",
              "--date=format:%Y-%m-%d %H:%M %z", "--", path.name, cwd=path.resolve().parent)
    return _colon(out.splitlines()[-1]) if out else ""


def body_start(lines: list[str]) -> int:
    """Index of the first line after YAML front matter; 0 when there is none."""
    if lines and lines[0] == "---" and "---" in lines[1:]:
        return lines.index("---", 1) + 1
    return 0


def stamp_text(text: str, suffix: str, created: str) -> str:
    lines = text.split("\n")
    top = body_start(lines)
    for n in range(top, min(top + 5, len(lines))):
        line = lines[n]
        if m := STAMP.search(line):
            lines[n] = line[:m.start("e")] + now() + line[m.end("e"):]
            return "\n".join(lines)
    body = f"Created: {created} · Edited: {now()}"
    if suffix in DOCS:
        if top:                                  # YAML front matter must stay first
            at, insert = top, [body]
        else:
            at = 1 if lines and lines[0].startswith("# ") else 0
            insert = [body, ""] if at == 0 else ["", body]
    else:
        at = 1 if lines and lines[0].startswith("#!") else 0
        insert = [f"{COMMENT[suffix]} {body}"]
    return "\n".join(lines[:at] + insert + lines[at:])


def stampable(rel: str) -> bool:
    return (Path(rel).suffix in DOCS or Path(rel).suffix in COMMENT) and not EXEMPT.search(rel)


def write(paths: list[str]) -> int:
    for p in map(Path, paths):
        if not stampable(p.as_posix()):
            print(f"  skip  {p} (type not stamped, or exempt)")
            continue
        text = p.read_text(encoding="utf-8")
        p.write_text(stamp_text(text, p.suffix, first_commit(p) or now()), encoding="utf-8")
        print(f"  stamped  {p}")
    return 0


def check() -> int:
    staged = git("diff", "--cached", "--name-only", "--diff-filter=AM").splitlines()
    files = [f for f in staged if stampable(f)]
    if not files:
        print("H15 — nothing staged that takes a stamp. Nothing to check.")
        return 0
    bad = []
    for f in files:
        lines = git("show", f":{f}").split("\n")
        head = "\n".join(lines[body_start(lines):][:5])
        m = STAMP.search(head)
        if not m:
            bad.append(f"{f}: no `Created: … · Edited: …` line in the first five lines")
            continue
        last = git("log", "-1", "--format=%cd", "--date=format:%Y-%m-%d %H:%M %z", "--", f)
        if last and _parse(m.group("e")) < _parse(_colon(last)):
            bad.append(f"{f}: Edited {m.group('e')} is older than its last commit ({_colon(last)})")
    if bad:
        print(f"\nH15 FAIL — {len(bad)} file(s)\n")
        for b in bad:
            print(f"  {b}")
        print("\n  Fix: python3 scripts/stamp.py <file>... then git add them again.\n")
        return 1
    print(f"H15 pass — {len(files)} staged file(s) stamped")
    return 0


if __name__ == "__main__":
    args = sys.argv[1:]
    sys.exit(check() if args == ["--check"] else write(args) if args else (print(__doc__), 1)[1])
