"""H3 — the two-tier grammar guard.  D14, enforced at the only moment it is cheap.

Structural IDs (`F3`, `F1-T2`, `C1`, `F4c`) are the only IDs that appear in git.
Register IDs (`D` `O` `H` `M` `RR` `FR` `NFR`) are cited by name in plans, reviews
and source comments, and never in a commit subject, a branch, or a PR title.

Exists because this repo broke its own rule on the commit that built the previous
hook:

    feat(C1): H5 register integrity — unique, sorted, status required

`H5` is a hook ID.  It reads as harmless, and it is exactly the drift D14 forbids:
once a register ID is a legal thing to write in git, `git log --grep` stops being a
structural index and the two tiers collapse into one.  The scope was right — `C1`
built it — so the fix is one word out of the subject, and the body is where `H5`
belonged all along.

**Register IDs in the BODY are correct usage and are never flagged.**  A commit body
routinely explains "this closes O5"; that is the citation the grammar is for.  Only
the first line — subject and scope — is constrained.

Also checks the conventional-commit form: `<type>(<id>): <description>`, types
feat|fix|test|chore|docs|refactor|ci, scope a structural ID.

    python3 scripts/check_commit_msg.py .git/COMMIT_EDITMSG
    python3 scripts/check_commit_msg.py --branch F2/timer-engine

Install the hook (the owner's call, not this script's):

    git config core.hooksPath .githooks

Exit 1 on any violation.  Reports every violation, not just the first.
"""
from __future__ import annotations
import re, subprocess, sys
from pathlib import Path

TYPES = ("feat", "fix", "test", "chore", "docs", "refactor", "ci")

# A register ID: D/O/H/M single-letter, plus RR, FR, NFR.  Longest alternative
# first, so `NFR3` is one ID and not `FR3` with an N stuck to it.  The lookbehind
# keeps `ADD1` and `2xD3` out; the lookahead keeps `H5N1` out.
#
# Known false positives, kept deliberately: `M1` (the chip) and `O365` are
# indistinguishable from a mutation and an owner item by shape alone.  The
# check errs toward stopping the commit, because the cost is rewording a
# subject and the cost of the other error is the grammar quietly rotting.
REGISTER = re.compile(r"(?<![A-Za-z0-9])(NFR|FR|RR|[DOHM])(\d+)(?![A-Za-z0-9])")

# A structural ID: F3, C1, F4c, F1-T2, C2-T10, F4c-T1.
STRUCTURAL = re.compile(r"^[FC]\d+[a-z]?(-T\d+)?$")

SUBJECT = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]*)\))?(?P<bang>!?): (?P<desc>.+)$")

# git writes these itself, or writes them for you.  Not ours to grade.
GENERATED = re.compile(r"^(Merge |Revert |fixup!|squash!|amend!)")

WHERE_INSTEAD = ("cite the `F`/`C` task that builds or closes it in the scope, "
                 "and explain it in the body — a register ID in the body is correct")


def subject_of(text: str) -> str:
    """First real line of a commit message file.

    Strips git's comment lines and everything below the `--verbose` scissors,
    because those carry the whole staged diff and would otherwise be scanned
    for register IDs that are not in the message at all.
    """
    lines = []
    for line in text.splitlines():
        if line.startswith("# ------------------------ >8"):
            break
        if line.startswith("#"):
            continue
        lines.append(line)
    for line in lines:
        if line.strip():
            return line.rstrip()
    return ""


def register_ids(s: str) -> list[str]:
    """Register IDs in `s`, in order, each reported once."""
    seen, out = set(), []
    for m in REGISTER.finditer(s):
        if m.group(0) not in seen:
            seen.add(m.group(0))
            out.append(m.group(0))
    return out


def check_subject(subject: str) -> list[str]:
    problems = []
    m = SUBJECT.match(subject)
    scope = m.group("scope") if m else None

    for i in register_ids(subject):
        where = "scope" if scope and i in register_ids(scope) else "subject line"
        problems.append(f"`{i}` is a register ID and appears in the {where} — "
                        f"{WHERE_INSTEAD}")

    if not m:
        problems.append("not a conventional commit: expected "
                        "`<type>(<id>): <description>`, types "
                        f"{'|'.join(TYPES)}")
        return problems
    if m.group("type") not in TYPES:
        problems.append(f"`{m.group('type')}` is not a commit type — "
                        f"use one of {'|'.join(TYPES)}")
    if scope is None:
        problems.append("no scope — the structural ID goes in the scope: "
                        f"`{m.group('type')}(F3): {m.group('desc')[:40]}`")
    else:
        for part in [p.strip() for p in scope.split(",")]:
            if not STRUCTURAL.match(part):
                problems.append(f"`{part}` is not a structural ID — the scope is "
                                "`F<n>`, `C<n>`, `F<n>-T<m>`, `C<n>-T<m>` or a retrofit "
                                "letter (`F4c`)")
    return problems


def check_branch(name: str) -> list[str]:
    # A branch has no body to cite from, so the advice differs from a commit's.
    return [f"`{i}` is a register ID and appears in the branch name — name the "
            f"branch for the `F`/`C` task that builds or closes it, e.g. `F2/timer-engine`"
            for i in register_ids(name)]


def report(what: str, subject: str, problems: list[str]) -> int:
    if problems:
        print(f"\nH3 FAIL — {len(problems)} problem(s)\n")
        print(f"  {what}: {subject}\n")
        for x in problems:
            print(f"  {x}")
        print()
        return 1
    print(f"H3 pass — {what}: {subject}")
    return 0


DEFAULT_DEPTH = 25
BASELINE = Path(__file__).resolve().parent.parent / "tests" / "H3_CORPUS_BASELINE"


def corpus_projects(root: Path) -> list[tuple[Path, str]]:
    """The same set `check_compliance.py` reviews, minus the scope exclusions.

    `D36` made that walk recursive. Excluding the exclusions is not a nicety: the first
    run of this swept `Meshtastic-Apple`, which the owner ruled out of scope, and 20 of
    its commits made up the largest block of the failure list. A check that grades
    projects nobody agreed to grade is one that gets ignored.
    """
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "cc", Path(__file__).resolve().parent / "check_compliance.py")
    cc = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(cc)
    try:
        excl = cc.excluded()
    except Exception:
        excl = {}
    out = []
    for p in cc.discover(root):
        name = cc.label(p)
        if name in excl or p.name in excl:
            continue
        out.append((p, name))
    return out


def check_corpus(root: Path, depth: int = DEFAULT_DEPTH, strict: bool = False,
                 baseline: int | None = None) -> int:
    """`D37` — run the subject rule over every project's recent history.

    `H3` is a commit-msg hook, and a commit-msg hook is per-clone config: `core.hooksPath`
    cannot be carried by a commit, so it is installed where somebody ran one command and
    nowhere else. It was in 1 clone of 14 when a single re-vendor put a register ID in
    the subject of 13 commits and nothing objected. Trying harder to install it
    everywhere protects only the clones that ran it and reports nothing about the rest;
    checking afterwards reports on all of them.

    Only the subject is graded. A register ID in the body is correct usage, and a sweep
    that flagged bodies would fail nearly every commit this project has made — which is
    how a check gets switched off.

    By default only the `D14` rule is graded — no register ID in the subject. That is
    the rule this repository enforces across every project and the one `D37` was
    ratified to catch. Conventional-commit *form* is graded only under `--strict`,
    because most of the corpus predates its adoption: the first full run returned 167
    failures, of which 161 were form and 15 were the real breach. A sweep that is
    permanently red on history is a sweep nobody runs, and the ratchet rule in
    `conventions.md` says so directly.
    """
    projects = corpus_projects(root)
    if not projects:
        print(f"H3 corpus — no projects found under {root}")
        return 0
    bad, seen = [], 0
    for p, name in projects:
        out = subprocess.run(["git", "-C", str(p), "log", f"-{depth}",
                              "--format=%H%x1f%s"], capture_output=True, text=True)
        if out.returncode != 0:
            continue
        for line in out.stdout.splitlines():
            if "\x1f" not in line:
                continue
            sha, subject = line.split("\x1f", 1)
            seen += 1
            if GENERATED.match(subject):
                continue
            problems = check_subject(subject)
            if not strict:
                problems = [x for x in problems if "subject line" in x]
            if problems:
                bad.append((name, sha[:8], subject, problems))
    rule = "full subject grammar" if strict else "D14 only — no register ID in a subject"

    # A ratchet, not an assertion of zero. `conventions.md`: where a gap already exists,
    # let the number shrink or hold, never grow — a permanently red gate is one somebody
    # deletes. The 12 on record are pushed history in six projects and cannot be
    # rewritten. What must never happen again is 13 fresh ones in a single command,
    # which is what `RR33` was.
    floor = 0 if baseline is None else baseline
    if baseline is None and not strict and BASELINE.is_file():
        try:
            floor = int(BASELINE.read_text().split()[0])
        except (ValueError, IndexError):
            floor = 0

    if not bad:
        print(f"H3 corpus pass — {seen} subject(s) across {len(projects)} project(s), "
              f"last {depth} each ({rule})")
        return 0
    over = len(bad) > floor
    verdict = "FAIL" if over else "pass"
    print(f"\nH3 corpus {verdict} — {len(bad)} subject(s) of {seen} across "
          f"{len(projects)} project(s) ({rule}), baseline {floor}\n")
    for name, sha, subject, problems in bad:
        print(f"  {name} {sha}: {subject}")
        for pr in problems:
            print(f"      {pr}")
    if over:
        print(f"\n  {len(bad) - floor} more than the baseline of {floor}. These are new.")
        print("  Reword the subject and amend; the register ID belongs in the body.\n")
        return 1
    if len(bad) < floor:
        print(f"\n  below the baseline of {floor} — lower tests/H3_CORPUS_BASELINE "
              f"to {len(bad)} so it cannot drift back up.\n")
    else:
        print(f"\n  at the baseline of {floor}: pushed history, not new breaches.\n")
    return 0


def main(argv: list[str]) -> int:
    args = argv[1:]
    if not args:
        print(__doc__.strip().splitlines()[0])
        print("\nusage: check_commit_msg.py <commit-msg-file> | --branch <name>"
              " | --corpus [root] [--depth N]")
        return 2

    if args[0] == "--corpus":
        rest = args[1:]
        depth = DEFAULT_DEPTH
        if "--depth" in rest:
            i = rest.index("--depth")
            depth = int(rest[i + 1])
            rest = rest[:i] + rest[i + 2:]
        strict = "--strict" in rest
        rest = [r for r in rest if r != "--strict"]
        override = None
        if "--baseline" in rest:
            i = rest.index("--baseline")
            override = int(rest[i + 1])
            rest = rest[:i] + rest[i + 2:]
        root = Path(rest[0]).resolve() if rest else Path(__file__).resolve().parent.parent.parent
        return check_corpus(root, depth, strict, override)

    if args[0] == "--branch":
        if len(args) < 2:
            print("--branch needs a branch name")
            return 2
        name = args[1]
        return report("branch", name, check_branch(name))

    path = Path(args[0])
    if not path.is_file():
        print(f"H3: no such commit message file: {path}")
        return 2
    subject = subject_of(path.read_text(encoding="utf-8"))
    if not subject:
        print("H3 FAIL — the commit message is empty")
        return 1
    if GENERATED.match(subject):
        print(f"H3 pass — git-generated subject, not graded: {subject}")
        return 0
    return report("subject", subject, check_subject(subject))


if __name__ == "__main__":
    sys.exit(main(sys.argv))
