#!/bin/sh
# Created: 2026-11-08 20:59 -06:00 · Edited: 2026-11-08 21:14 -06:00
# The document gates (`C0`), run by pre-commit (and by CI from `C1`). Every check runs, so
# every problem is reported at once. Each check fails closed: none reads another project.
cd "$(dirname "$0")/.." || exit 1
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
# The vendored conventions carry their pin in the header; the body below it must hash to it.
conventions_pinned() {
    want=$(sed -nE 's/^ *pinned-sha256: ([0-9a-f]{64}).*/\1/p' docs/conventions.md | head -1)
    got=$(tail -n +6 docs/conventions.md | shasum -a 256 | cut -d' ' -f1)
    [ -n "$want" ] && [ "$want" = "$got" ] || { echo "pin ${want:-missing}, body hashes to $got"; return 1; }
}
run "vendored scripts match UPSTREAM_PIN" sh -c "grep -v '^#' scripts/UPSTREAM_PIN | shasum -a 256 -c -"
run "vendored conventions match their pin" conventions_pinned
run "register unique, sorted, statused"   python3 scripts/check_register.py docs/plans/00-register.md
run "every cited id is defined here"      python3 scripts/check_ids.py
run "status page regenerates clean"       python3 scripts/gen_status.py --check
exit $fail
