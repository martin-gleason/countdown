"""H2 — citation integrity.  Every register ID cited in the docs has a row.

Exists because a sibling project's `D14` was cited by name in five production
source files while existing in no document at all — one of them opened with
"Ratified decision D14 is that..." against a decision nobody could look up.
A cited ID is a promise that the reader can go and read it.  This checks the
promise, and nothing else: it does not know what an ID *means*, only whether
it can be found.

Exit 1 on any violation.  Reports every violation, not just the first.

--------------------------------------------------------------------------
What counts as a citation.  Each exclusion is argued, because an over-eager
checker gets deleted, and a deleted checker is worse than no checker.

`docs/audits/` is not scanned — AND it is the dictionary of foreign IDs.
    That directory holds registers extracted from *other* projects, so it is
    wall-to-wall IDs that this register will never contain.  Excluding it is
    obvious.  The non-obvious half: this repo's own prose quotes those same
    foreign IDs on purpose — the register's `O5` reads "ZenPom reuses `O23`,
    `O24`, `O25`", and `O6` names six ZenPom items by number.  Flagging those
    is exactly the wolf-crying that gets a hook deleted.
    So every ID appearing anywhere in `docs/audits/` resolves.  Not a list of
    project names to maintain, a lookup: the test H2 actually cares about is
    "can a reader find this ID in this repo", and for those, they can — one
    directory over, in the extracted register.  An ID that was never extracted
    still fails, which is right: nobody can look that one up either.

Fenced code blocks are skipped.
    `docs/plans/F1.md` renders sample Todoist rows — `[O29] The Silence
    button` — inside a fence.  A picture of a task is not a citation of one.
    ``` and ~~~ fences only; indented code blocks are not detected, because
    telling one from a wrapped table cell is not worth the bug.

Inline code spans are NOT skipped.
    Most real citations in this corpus are backticked — "See `D3`", "`D14` —
    cited in five source files".  Dropping code spans would blind the checker
    to the majority of its own subject matter.  Backticks are emphasis here,
    not quotation.

Each file is read once, by resolved path.
    `skills/cc-md/references/conventions.starter.md` is a symlink to
    `conventions.md` (`D19`), and reporting one line under two paths teaches
    the reader to distrust the line numbers.

Known blind spots, stated rather than papered over:
  - `M1`, `H1`, `D3` and friends are ordinary English elsewhere — an Apple M1,
    an <h1>, a D3 chart.  Written bare in prose, they will be flagged.  The
    alternative — demanding backticks — would miss the register's own bare
    table-cell rows, which is the citation form that matters most.  A stray
    hit is one reword; a missed dangling citation is the `D14` failure.
  - A right ID meaning the wrong thing is invisible here.  `F1.md`'s `RR3`
    resolves to the register's `RR3` while describing a different risk.
    H5 catches duplicate IDs inside a register; nothing yet catches an ID that
    two documents define differently.
  - `FR`/`NFR` live in `SPEC.md`, not the register (`D16`).  That file does not
    exist yet, so this hook has never seen one and does not read it.  When
    `docs/specs/SPEC.md` lands, add it to DEFINES — untested here, so it is
    not wired in on speculation.
"""
from __future__ import annotations
import re, sys
from pathlib import Path

REGISTER = Path("docs/plans/00-register.md")
AUDITS = Path("docs/audits")

KINDS = r"(?:NFR|FR|RR|[DOHM])"
# A row defines an ID when the ID is the first cell, struck or bolded or plain.
ROW = re.compile(rf"^\|\s*~{{0,2}}\*{{0,2}}({KINDS}\d+)\*{{0,2}}~{{0,2}}\s*\|")
# A citation is the bare token.  Not after a word char, `#` or `/`, so hashes,
# tags and paths (`docs/chores/D4.md`) are left alone; `\d+\b` so `D14a` — a
# retrofit letter, not a register ID — is not read as `D14`.
CITE = re.compile(rf"(?<![\w#/]){KINDS}\d+\b")
FENCE = re.compile(r"^\s*(```|~~~)")


def cited(path: Path) -> list[tuple[int, str]]:
    """Every (line number, ID) cited in a markdown file, outside fences."""
    out, fenced = [], False
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced:
            continue
        seen = set()
        for m in CITE.finditer(line):
            if m.group(0) not in seen:
                seen.add(m.group(0))
                out.append((n, m.group(0)))
    return out


def defined(path: Path) -> set[str]:
    """IDs that have a row in a register file."""
    return {m.group(1) for line in path.read_text(encoding="utf-8").splitlines()
            if (m := ROW.match(line))}


def spec_ids() -> set[str]:
    """`FR`/`NFR` defined in a spec, in this project or any other in the corpus.

    `conventions.md`: *"`FR`/`NFR` are the exception: they live in `SPEC.md`, because they
    ARE the baseline the register is measured against."* Looking for them in the register
    is looking in the wrong file — latent until this repo became the first to define any,
    and then it failed on the very document that states the rule.
    """
    out: set[str] = set()
    workspace = Path(__file__).resolve().parent.parent.parent
    for spec in list(workspace.glob("*/docs/specs/*.md")) + list(workspace.glob("*/docs/SPEC.md")):
        body = spec.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"\*\*(N?FR\d{1,3})\*\*|^\s*[-*]\s*\*{0,2}(N?FR\d{1,3})\b",
                             body, re.M):
            out.add(m.group(1) or m.group(2))
    return out


def corpus_ids() -> set[str]:
    """IDs a reader can look up in some other project's register.

    This repo's own prose discusses the corpus by name — `O23` and `O24` in ZenPom, `C3`
    killed by that project's `D18`. Those are real, checkable citations; they just are
    not about this repo. They used to resolve against extracted copies kept in
    `docs/audits/`, and when a project took ownership of its own register those copies
    were retired and twenty citations dangled overnight.

    So resolve against the corpus itself. If a project in `Local_Dev_Projects` has the
    row, the reader can look it up, which is the only thing this check is really asking.
    """
    out: set[str] = set()
    workspace = Path(__file__).resolve().parent.parent.parent
    for reg in workspace.glob("*/docs/plans/00-register.md"):
        for m in re.finditer(r"^\|\s*~{0,2}\*{0,2}((?:D|O|RR|H|M|C|G|FR|NFR)\d{1,3}[a-z]?)",
                             reg.read_text(encoding="utf-8", errors="replace"), re.M):
            out.add(m.group(1))
    return out


def quoted(audits: Path) -> set[str]:
    """IDs a reader can look up in another project's extracted register.

    Every token, not only rows: ZenPom's `O24` is named in that register's
    own duplicate-ID note without having a row of its own.
    """
    if not audits.is_dir():
        return set()
    return {i for p in sorted(audits.rglob("*.md")) for _, i in cited(p)}


def docs(roots: list[Path], skip: Path) -> list[Path]:
    """Markdown under roots, each real file once, minus .git and the audits."""
    seen, out = set(), []
    skip = skip.resolve()
    for r in roots:
        for p in ([r] if r.is_file() else sorted(r.rglob("*.md"))):
            if p.suffix != ".md" or ".git" in p.parts:
                continue
            real = p.resolve()
            if real in seen or skip in real.parents:
                continue
            seen.add(real)
            out.append(p)
    return out


def check(roots: list[Path]) -> tuple[list[str], int, int]:
    if not REGISTER.is_file():
        return [f"{REGISTER} not found — run this from the repo root"], 0, 0
    known = defined(REGISTER) | corpus_ids() | spec_ids()
    elsewhere = quoted(AUDITS)
    problems, n = [], 0
    files = docs(roots, AUDITS)
    for p in files:
        for line, i in cited(p):
            n += 1
            if i in known or i in elsewhere:
                continue
            problems.append(f"{p}:{line}: `{i}` is cited but has no row in "
                            f"{REGISTER}, and no other project's register here "
                            f"names it — the reader cannot look it up")
    return problems, n, len(files)


def main(argv: list[str]) -> int:
    roots = [Path(p) for p in argv[1:]] or [Path(".")]
    # Same defect as H5 had: a root named on the command line and never found
    # printed "H2 pass — 0 citation(s) in 0 file(s)" and exited 0. Scanning
    # nothing is not the same as finding nothing wrong.
    missing = [r for r in roots if not r.exists()]
    if missing and argv[1:]:
        print(f"\nH2 FAIL — {len(missing)} path(s) named but not found\n")
        for m in missing:
            print(f"  {m}: no such file or directory")
        print()
        return 1
    problems, n, files = check(roots)
    if not files and argv[1:]:
        print(f"\nH2 FAIL — the named path(s) contain no markdown to scan\n")
        return 1
    # `RR22`: without the sibling projects on disk, an id belonging to another project
    # cannot be looked up from here. That is not the id being wrong, and it is not the
    # check passing. It is a check that could not run, and it says so.
    here = Path(__file__).resolve().parent.parent
    corpus_here = any(r for r in here.parent.glob("*/docs/plans/00-register.md")
                      if r.parent.parent.parent != here)   # this repo is not the corpus
    if problems and not corpus_here:
        print(f"\nH2 — {len(problems)} citation(s) could not be resolved, and the corpus "
              f"is not checked out here.\n")
        print("  A citation to another project's register cannot be looked up from a lone")
        print("  clone. That is not a pass and it is not a failure: it is a check that")
        print("  could not run. Run it where the corpus is.\n")
        for x in problems[:8]:
            print(f"  unresolved: {x.split('`')[1] if '`' in x else x}")
        print()
        return 0
    if problems:
        print(f"\nH2 FAIL — {len(problems)} problem(s)\n")
        for x in problems:
            print(f"  {x}")
        print()
        return 1
    print(f"H2 pass — {n} citation(s) in {files} file(s), all resolve")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
