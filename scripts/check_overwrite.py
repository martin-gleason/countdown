# Created: 2026-11-08 20:59 -06:00 · Edited: 2026-11-08 21:14 -06:00
"""Overwrite guard, register hook H7 (`C0`).

A staged markdown file that loses more than 60% of the lines it had at HEAD (or is
deleted; a rename is measured against its old content, so a pure move passes) must be declared in the commit message with a line:

    Rewrites: <path> — <why>

This closes the shell-redirect hole: the Write tool refuses to overwrite an unread
file, and `>` does not.

    python3 scripts/check_overwrite.py .git/COMMIT_EDITMSG

Exit 1 on any undeclared rewrite. Reports every one.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

LIMIT = 0.60


def git(*args: str) -> str:
    r = subprocess.run(["git", *args], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def head_lines(path: str) -> int:
    return len(git("show", f"HEAD:{path}").splitlines())


def offenders() -> list[tuple[str, int, int]]:
    """(path, lines removed, lines at HEAD) for each staged doc over the limit."""
    if not git("rev-parse", "--verify", "-q", "HEAD").strip():
        return []                     # first commit: nothing existed to overwrite
    out = []
    # -z with rename detection: a rename is `added\tremoved\t\0old\0new\0` and is measured
    # against the old path, so a pure move (archiving a plan) loses nothing.
    fields = git("diff", "--cached", "--numstat", "-M", "-z").split("\0")
    i = 0
    while i < len(fields) - 1:
        added, removed, path = fields[i].split("\t", 2)
        if path == "":                       # rename: the next two fields are old, new
            path, i = fields[i + 1], i + 3
        else:
            i += 1
        if not path.endswith(".md") or removed == "-":
            continue
        before = head_lines(path)
        if before and int(removed) / before > LIMIT:
            out.append((path, int(removed), before))
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_overwrite.py <commit-message-file>", file=sys.stderr)
        return 2
    message = Path(argv[1]).read_text(encoding="utf-8")
    declared = set(re.findall(r"^Rewrites:\s*(\S+)", message, re.M))
    bad = [o for o in offenders() if o[0] not in declared]
    for path, removed, before in bad:
        print(f"H7 FAIL — {path} loses {removed} of {before} lines. "
              f"Add 'Rewrites: {path} — <why>' to the message, or restore it.")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
