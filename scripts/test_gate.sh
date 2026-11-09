#!/bin/sh
# Created: 2026-11-08 21:26 -06:00 · Edited: 2026-11-08 21:26 -06:00
# The test gate (`C1`), shared by pre-commit and CI: one run of the suite, which must exit 0,
# and a passing count at or above tests/TEST_FLOOR. Fails closed on a malformed floor.
# Optional $1: a scratch path, as for run_tests.sh.
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(sh "$root/scripts/run_tests.sh" "$@" 2>&1); rc=$?
count=$(printf '%s\n' "$out" | sh "$root/scripts/parse_count.sh")
floor=$(tr -d ' \t\n' < "$root/tests/TEST_FLOOR")
summary=$(printf '%s\n' "$out" | grep -E 'Test run with|Executed [0-9]+ test' | tail -2)
fail=0
if [ "$rc" -ne 0 ]; then
    printf '  FAIL  test run exited %s\n' "$rc"
    printf '%s\n' "$out" | grep -E '✘|error:|failed' | head -15 | sed 's/^/          /'
    fail=1
fi
case "$floor" in
    ''|*[!0-9]*) printf '  FAIL  tests/TEST_FLOOR must hold one whole number; it holds "%s"\n' "$floor"; exit 1 ;;
esac
if [ "$count" -lt "$floor" ]; then
    printf '  FAIL  test floor: %s ran and passed, floor is %s\n' "$count" "$floor"
    fail=1
elif [ "$fail" -eq 0 ]; then
    printf '  ok    tests (%s passed, floor %s)\n' "$count" "$floor"
fi
printf '%s\n' "$summary" | sed 's/^/          /'
exit $fail
