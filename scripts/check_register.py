# Created: 2026-08-30 14:07 -05:00 · Edited: 2026-09-24 08:22 -05:00
"""H5 — register rows are well formed. Exit 1 on any problem; every problem is listed.

    python3 scripts/check_register.py [register.md ...]

Checks, per table:
  1. Every row has as many cells as the header. A raw `|` inside a cell splits it;
     write `\\|`. (`D55`)
  2. The table has a Status column, and the status is read from that column only —
     never from a word somewhere else in the row. (`D53`)
  3. No row has an empty status. Empty is not "probably open".
  4. The status starts with a known word (see STATUS below).
  5. No ID appears twice in a section.
  6. Rows are sorted by ID, so the next free number is the last row plus one.
Only sections whose heading ends in a register letter are checked — `## Decisions (D)`,
`## Agent items (A)`. Any other heading, `###` included, ends the register above it.
And overall: a file that yields no rows fails. Checking nothing is not a pass.

Rules 1–4 were ported 2026-09-24 from ZenPom's `check_register_rows.py` (`D71`).
"""
from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from register import _FENCE, _ROW, _cells, _is_delim  # noqa: E402

# A status cell must START with one of these. Text after it is allowed:
# "**closed** — fixed by X" is fine.
STATUS = ("not built", "open", "closed", "done", "proposed", "ratified", "rejected",
          "superseded", "resolved", "held", "unknown", "built", "killed", "survived")
STATUS_HEADS = {"status", "state"}
H2 = re.compile(r"^#{2,3}\s+(.*)$")
REGISTER_HEAD = re.compile(r"\(([A-Z]{1,2})\)\s*$")


def key(i: str):
    """Sort key. `C28` < `C32` < `F7b` < `F8` < `F8-M2` < `F8-M10` < `F10` < `M1`."""
    m = re.match(r"([A-Z]+-?[A-Z]?)(\d+)([a-z]?)(?:-M(\d+)([a-z]?))?$", i)
    if not m:
        return (i, 0, "", -1, "")
    p, n, l, sn, sl = m.groups()
    return (p, int(n), l, int(sn) if sn else -1, sl or "")


def first_word(cell: str) -> str:
    s = re.sub(r"[*~`]", "", cell).strip().lower()
    return next((w for w in STATUS if s.startswith(w)), "")


def check(path: Path) -> tuple[list[str], int]:
    """Problems found, and how many rows were read."""
    out: list[str] = []
    section, heads, prev, fenced = "", [], "", False
    rows: list[str] = []
    total = 0
    warned_no_status: set[str] = set()

    def close_section() -> None:
        for i, n in Counter(rows).items():
            if n > 1:
                out.append(f"§ {section}: `{i}` appears {n} times. One ID, one item.")
        ordered = sorted(rows, key=key)
        if rows != ordered:
            first = next(r for r, o in zip(rows, ordered) if r != o)
            out.append(f"§ {section}: not sorted by ID (first out of place: `{first}`).")

    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if _FENCE.match(line):
            fenced, heads, prev = not fenced, [], ""
            continue
        if fenced:
            continue
        if m := H2.match(line):
            close_section()
            section, heads, prev, rows = m.group(1).strip(), [], "", []
            continue
        s = line.strip()
        if not s.startswith("|"):
            heads, prev = [], ""
            continue
        if _is_delim(s):
            heads = _cells(prev) if prev else []
            prev = line
            continue
        prev = line
        m = _ROW.match(line)
        if not m or not heads or not REGISTER_HEAD.search(section):
            continue
        total += 1
        rid = m.group("key")
        rows.append(rid)
        cells = _cells(line)
        if len(cells) != len(heads):
            out.append(f"line {n}: `{rid}` has {len(cells)} cells, the header has "
                       f"{len(heads)}. A raw `|` in a cell splits it — write `\\|`.")
        low = [re.sub(r"[*`~]", "", h).strip().lower() for h in heads]
        col = next((i for i, h in enumerate(low) if h in STATUS_HEADS), None)
        if col is None:
            if section not in warned_no_status:
                warned_no_status.add(section)
                out.append(f"§ {section}: the table has no Status column. Every row needs one.")
            continue
        if m.group("id"):              # a struck ID is closed, whatever the cell says
            continue
        cell = cells[col] if col < len(cells) else ""
        if not re.sub(r"[*~`\s]", "", cell):
            out.append(f"line {n}: `{rid}` has an empty status.")
        elif not first_word(cell):
            out.append(f"line {n}: `{rid}` status {cell[:40]!r} does not start with a "
                       f"known word: {', '.join(STATUS)}.")
    close_section()
    return out, total


def main(argv: list[str]) -> int:
    named = [Path(p) for p in argv[1:]]
    paths = named or sorted(Path(".").rglob("*register*.md"))
    missing = [p for p in named if not p.is_file()]
    if missing:                        # a typo'd path is an error, never a silent pass
        print(f"\nH5 FAIL — not found: {', '.join(map(str, missing))}\n")
        return 1
    problems, total = [], 0
    for p in paths:
        found, rows = check(p)
        total += rows
        problems += [f"{p}: {x}" for x in found]
    if not total:
        problems.append("no register rows were read. Checking nothing is not a pass.")
    if problems:
        print(f"\nH5 FAIL — {len(problems)} problem(s)\n")
        for x in problems:
            print(f"  {x}")
        print()
        return 1
    print(f"H5 pass — {total} rows in {len(paths)} register(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
