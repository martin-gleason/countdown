# Created: 2026-08-30 13:15 -05:00 · Edited: 2026-09-24 08:22 -05:00
"""Canonical register parser.  F1-T1.

Reads a `00-register.md` and returns typed rows.  Pure: no network, no writes.
The ONLY format this understands is the canonical one in conventions.md.
Legacy project layouts are converted by one-time extractors, never parsed here.

**Columns are read by name, never by position.**  Three defects lived here, all one
root cause — the parser guessed:

  1. Title was "the first non-empty cell that isn't a priority".  The Decisions table
     is `| ID | Status | Milestone | Decision |`, so every `D` row's title came back
     as its own status word: `D1` had `title='ratified'`.
  2. Status was a substring scan over every cell, so a row whose *prose* said "closed"
     parsed closed.  `O5` in this repo's register says `open` in its Status column and
     "one closed and one open" in its text; it parsed closed and silently never synced.
  3. Cells split on a raw `|`, so markdown's escaped `\\|` truncated the cell.  `D9`'s
     decision text contains ``(`human` \\| `agent`)`` and lost everything after it.

The fix is one mechanism for all three: find the table's header row (the line above the
`|---|` delimiter), map heading -> column index, and read the cell you actually want.
Column 0 is always the ID, because `_ROW` anchors the ID to the first cell — so a table
whose first heading is `Key` or `#` rather than `ID` still parses.

`scripts/gen_status.py` solved 1 and 2 correctly in its own `columns()` and
`status_of()`, and carries `_SPLIT` for 3.  Those were workarounds for this file being
wrong.  **gen_status can now drop `status_of()`'s fallback and its private `_SPLIT`** —
`Item.status` is read from the named Status column here, and `register._SPLIT` is
exported below.  (Do not edit gen_status.py from here; that file has its own owner.)
"""
from __future__ import annotations
import re
from dataclasses import dataclass, field
from pathlib import Path

# Register IDs that may sync to Todoist, and the label each carries.
SYNCABLE = {"O": "@verify", "C": "@chores", "D": "@Review", "G": "@Review"}

# Register P0..P2 -> Todoist p1..p3 (td inverts: p1 is HIGHEST).
PRIORITY_TO_TD = {"P0": "p1", "P1": "p2", "P2": "p3"}

CLOSED = {"closed", "done", "rejected", "superseded", "ratified", "resolved"}


@dataclass
class Item:
    id: str                      # O29, C8, D30, G-F7
    kind: str                    # O | C | D | G
    title: str
    priority: str = ""           # P0 | P1 | P2 | ""
    status: str = "open"
    owner: str = "human"
    labels: list[str] = field(default_factory=list)
    todoist_id: str = ""
    project: str = ""
    why: str = ""                # why it is still open — the sentence a title cannot hold
    source: str = ""             # file:line this row was reconstructed from

    @property
    def is_open(self) -> bool:
        return self.status.lower() not in CLOSED

    @property
    def syncs(self) -> bool:
        """Human-owned open work, or agent work flagged for learning.

        A DECISION syncs only when its status is literally `proposed` -- `F1.md`:
        "`D<n>` in `proposed`". It is not enough for it to be un-closed. Reconstructed
        registers carry `status: unknown` wherever the source document was silent, and
        `unknown` is not `proposed`: it means nobody recorded a status, not that the
        owner owes a ratification.

        Caught on the dry run before the second project ever synced. Without it, sixty
        already-ratified decisions -- several of whose titles literally begin "O1
        closed:" -- would have arrived on the owner's phone as things to rule on.
        """
        if self.kind == "D":
            return self.status.lower().strip(" *") == "proposed"
        if not self.is_open:
            return False
        if self.owner == "agent":
            return "@Learning" in self.labels
        return self.kind in SYNCABLE

    @property
    def td_priority(self) -> str:
        return PRIORITY_TO_TD.get(self.priority, "p4")

    def td_labels(self) -> list[str]:
        base = [SYNCABLE.get(self.kind, "")] if not self.labels else list(self.labels)
        return [l for l in base if l]

    def td_content(self) -> str:
        return f"[{self.id}] {self.title}"


# The key also takes a unit-scoped mutation ID, `F8-M1` or `C33-M2`. ZenPom uses them and
# the old pattern dropped all 97 (probe, 2026-09-24).
_ROW = re.compile(r"^\|\s*(?P<id>~~)?\*{0,2}(?P<key>[A-Z]{1,2}-?[A-Z]?\d+[a-z]?(?:-M\d+[a-z]?)?)\*{0,2}~{0,2}\s*\|(?P<rest>.*)\|?\s*$")
_FENCE = re.compile(r"^\s*(```|~~~)")
_H2 = re.compile(r"^##\s+(.*)$")
_SPLIT = re.compile(r"(?<!\\)\|")        # a `\|` inside a cell is not a column break
_DELIM_CELL = re.compile(r"^:?-{2,}:?$")

# Longest first: "not built" must win over "built".
_STATUS_WORDS = ["not built", "superseded", "proposed", "ratified", "rejected",
                 "resolved", "unknown", "closed", "built", "held", "open", "done"]

# Heading vocabulary.  Matched case-insensitively, after markup is stripped.
_STATUS_HEADS = {"status", "state"}
_PRIORITY_HEADS = {"p", "pri", "priority"}
_LABEL_HEADS = {"mode", "label", "labels"}
# Headings that carry the row's prose, in no particular order — a table has one.
_TITLE_HEADS = {"title", "item", "decision", "risk", "hook", "mutation", "chore",
                "gate", "name", "summary", "description", "task"}
# Everything a title is definitely NOT, for the case where no heading above matched.
_NOT_TITLE = (_STATUS_HEADS | _PRIORITY_HEADS | _LABEL_HEADS |
              {"id", "#", "key", "ref", "milestone", "owner", "surface", "protects",
               "likelihood", "impact", "mitigation", "date", "notes", "evidence",
               "kind", "type", "new?", "test", "todoist", "todoist id", "project"})


def parse(path: str | Path) -> list[Item]:
    """Parse a canonical register into Items, in file order."""
    text = Path(path).read_text(encoding="utf-8")
    section, items, cols, prev, fenced = "", [], {}, "", False
    for line in text.splitlines():
        stripped = line.strip()
        if _FENCE.match(line):              # a table shown inside ``` is an example, not a row
            fenced, cols, prev = not fenced, {}, ""
            continue
        if fenced:
            continue
        if m := _H2.match(line):
            section, cols, prev = m.group(1).strip(), {}, ""
            continue
        if not stripped.startswith("|"):
            # A table ends at the first line that is not a row; its headings end with it.
            cols, prev = {}, ""
            continue
        if _is_delim(stripped):
            # The line above a `|---|` delimiter is the header row, whatever it is named.
            cols = _resolve(_cells(prev)) if prev else {}
            prev = line
            continue
        prev = line
        m = _ROW.match(line)
        if not m:
            continue
        items.append(_row_to_item(m.group("key"), _cells(line), cols, section,
                                  struck=bool(m.group("id"))))
    return items


def _cells(line: str) -> list[str]:
    """A markdown row's cells, honouring `\\|`.  Handles rows with or without the
    trailing pipe; the ID is always cell 0."""
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|") and not s.endswith("\\|"):
        s = s[:-1]
    return [c.strip().replace("\\|", "|") for c in _SPLIT.split(s)]


def _is_delim(stripped: str) -> bool:
    cells = _cells(stripped)
    return bool(cells) and all(_DELIM_CELL.match(c) for c in cells)


def _head(cell: str) -> str:
    return re.sub(r"[*`~]", "", cell).strip().lower()


def _resolve(heads: list[str]) -> dict[str, int]:
    """heading row -> {'title'|'status'|'priority'|'labels': column index}.

    Only the columns that are actually present appear in the result, so a caller can
    tell "this table has no Status column" from "its Status cell was empty" — the two
    need different fallbacks and conflating them is how defect 2 got in.
    """
    low = [_head(h) for h in heads]
    out: dict[str, int] = {}
    for name, group in (("status", _STATUS_HEADS), ("priority", _PRIORITY_HEADS),
                        ("labels", _LABEL_HEADS),
                        ("why", {"why", "why it is still open", "reason", "rationale"}),
                        ("source", {"source", "from"})):
        idx = next((n for n, h in enumerate(low) if h in group), None)
        if idx is not None:
            out[name] = idx
    # Column 0 is the ID by construction, so the title is never there.
    title = next((n for n, h in enumerate(low) if n and h in _TITLE_HEADS), None)
    if title is None:
        title = next((n for n, h in enumerate(low) if n and h and h not in _NOT_TITLE), None)
    if title is not None:
        out["title"] = title
    return out


def _norm_status(cell: str, exact: bool = False) -> str:
    """A status word, or "".  `exact` refuses a prefix match — used when scanning
    unnamed cells, where "closed the loop" must not read as `closed`."""
    s = re.sub(r"[*~`]", "", cell).strip().lower()
    if not s:
        return ""
    for w in _STATUS_WORDS:
        if s == w or (not exact and s.startswith(w)):
            return w
    return ""


def _row_to_item(key: str, cells: list[str], cols: dict[str, int], section: str,
                 struck: bool) -> Item:
    kind = "M" if "-M" in key else re.match(r"[A-Z]+", key).group(0)[0]

    def col(name: str) -> str:
        n = cols.get(name)
        return cells[n] if n is not None and n < len(cells) else ""

    # Priority.  Named column wins; an empty named column means unset, not "go looking".
    if "priority" in cols:
        raw = re.sub(r"[*`~ ]", "", col("priority"))
        prio = raw if raw in PRIORITY_TO_TD else ""
    else:
        prio = next((c for c in cells if c.strip() in PRIORITY_TO_TD), "")

    # Status.  Strikethrough on the ID is the row shouting; the Status column is next.
    if struck:
        status = "closed"
    elif "status" in cols:
        status = _norm_status(col("status"))
    else:
        status = next((w for c in cells if (w := _norm_status(c, exact=True))), "")

    # Title.  Named column, or the first cell after the ID that is not metadata.
    if "title" in cols:
        title = _clean(col("title"))
    else:
        title = _clean(next((c for c in cells[1:]
                             if c and c.strip() not in PRIORITY_TO_TD
                             and not _norm_status(c, exact=True)
                             and not c.startswith("@")), ""))

    owner = "agent" if "Needs the agent" in section else "human"
    # Mode is carried explicitly as an @label cell. "@?" means the extractor
    # could not tell and is asking, rather than guessing.
    if "labels" in cols:
        one = col("labels").strip()
        labels = [one] if one.startswith("@") else []
    else:
        labels = [c.strip() for c in cells if c.strip().startswith("@")]
    def cell(name: str) -> str:
        n = cols.get(name)
        return _clean(cells[n]) if n is not None and n < len(cells) else ""

    return Item(id=key, kind=kind, title=title, priority=prio,
                status=status or "unknown", owner=owner, labels=labels,
                why=cell("why"), source=cell("source"))


def _clean(s: str) -> str:
    # Strikethrough is markup saying "this is done" — not an instruction to delete the
    # words.  This used to drop the content: `| ~~O1~~ | ~~Rule `D16`~~ |` parsed to an
    # empty title, which renders as "[O1] " in Todoist and as a blank cell on the status
    # page.  Same root cause as the three above: the parser destroying a cell instead of
    # reading it.  Strikethrough is carried by `Item.status`, where it can be queried.
    s = re.sub(r"~~(.*?)~~", r"\1", s)
    s = re.sub(r"\*\*(.*?)\*\*", r"\1", s)
    s = re.sub(r"[`*_~]", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s[:120]
