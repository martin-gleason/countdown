#!/bin/sh
# Created: 2026-11-08 20:59 -06:00 · Edited: 2026-11-08 21:00 -06:00
# The document gates (`C0`), shared by pre-commit and CI. Run from the repository root.
# Every check runs, so every problem is reported at once.
cd "$(git rev-parse --show-toplevel)" || exit 1
fail=0
run() {
    name=$1; shift
    if out=$("$@" 2>&1); then
        printf '  ok    %s\n' "$name"
    else
        printf '  FAIL  %s\n' "$name"
        printf '%s\n' "$out" | sed 's/^/          /' | head -20
        fail=1
    fi
}
run "vendored scripts match UPSTREAM_PIN" sh -c "grep -v '^#' scripts/UPSTREAM_PIN | shasum -a 256 -c -"
run "register unique, sorted, statused"   python3 scripts/check_register.py docs/plans/00-register.md
run "every cited id resolves"             python3 scripts/check_citations.py docs CLAUDE.md
run "status page regenerates clean"       python3 scripts/gen_status.py --check
exit $fail
