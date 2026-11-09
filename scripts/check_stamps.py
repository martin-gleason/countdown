# Created: 2026-11-08 20:59 -06:00 · Edited: 2026-11-08 21:14 -06:00
"""Stamps and the frozen spec, register hooks H5 and H8 (`C0`).

    python3 scripts/check_stamps.py

Runs the vendored `stamp.py --check` unchanged, with two additions to what it skips:

- **every file listed in scripts/UPSTREAM_PIN.** They are copied unedited from upstream,
  so their stamps are upstream's or absent, and editing them would break the pin.
- **the frozen spec in docs/specs/.** It never takes a stamp, because it never changes.

It also closes a gap in `stamp.py --check`, which compares Edited with the last commit at
minute resolution: **a staged modification whose stamp line is unchanged from HEAD fails.**
Any edit therefore needs a fresh `python3 scripts/stamp.py <file>`.

And one refusal: **a staged change to anything under docs/specs/ fails** (H8). The spec is
the baseline. A change in scope is a `D<n>` in the register. Bypass only with
`git commit --no-verify`, deliberately, recording the reason in the commit body.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import stamp  # noqa: E402  (vendored, beside this file)

PIN = "scripts/UPSTREAM_PIN"
PIN_LINE = re.compile(r"^[0-9a-f]{64}\s+(?P<path>\S.*?)\s*$")
FROZEN = "docs/specs/"


def pinned() -> set[str]:
    """Paths in the staged scripts/UPSTREAM_PIN, falling back to the working tree's."""
    text = stamp.git("show", f":{PIN}")
    if not text and Path(PIN).is_file():
        text = Path(PIN).read_text(encoding="utf-8")
    return {m.group("path") for line in text.splitlines()
            if (m := PIN_LINE.match(line.strip()))}


def frozen_changes() -> list[str]:
    """Spec files staged as modified, deleted or renamed. Adding a new one is allowed."""
    rows = stamp.git("diff", "--cached", "--name-status", "--no-renames").splitlines()
    return [r.split("\t", 1)[1] for r in rows
            if r[:1] in "MD" and r.split("\t", 1)[1].startswith(FROZEN)]


def unrestamped(skip) -> list[str]:
    """Modified, stamp-taking files whose stamp line is identical in the index and at HEAD."""
    rows = stamp.git("diff", "--cached", "--name-only", "--diff-filter=M").splitlines()
    out = []
    for f in rows:
        if skip(f):
            continue
        staged = stamp.STAMP.search(stamp.git("show", f":{f}"))
        head = stamp.STAMP.search(stamp.git("show", f"HEAD:{f}"))
        if staged and head and staged.group(0) == head.group(0):
            out.append(f)
    return out


def main() -> int:
    fail = 0
    for path in frozen_changes():
        print(f"H8 FAIL — {path} is frozen. Record the change as a D<n> in the register.")
        fail = 1
    vendored = pinned()
    takes_stamp = stamp.stampable
    # stamp.check() looks its filter up as a module global, so this is the one seam.
    stamp.stampable = lambda rel: (rel not in vendored and not rel.startswith(FROZEN)
                                   and takes_stamp(rel))
    for f in unrestamped(lambda rel: not stamp.stampable(rel)):
        print(f"H5 FAIL — {f} was edited but its stamp line did not change. Run: python3 scripts/stamp.py {f}")
        fail = 1
    return stamp.check() or fail


if __name__ == "__main__":
    sys.exit(main())
