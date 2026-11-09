#!/bin/sh
# Created: 2026-11-08 21:11 -06:00 · Edited: 2026-11-08 21:11 -06:00
# Harness `count` (`C1`): print one integer, the number of tests that executed and passed.
# Read from Swift Testing's own summary line, so a suite that stops running reads 0, not
# green. Optional $1: a scratch path, as for run_tests.sh.
root=$(cd "$(dirname "$0")/.." && pwd)
out=$(sh "$root/scripts/run_tests.sh" "$@" 2>&1)
n=$(printf '%s\n' "$out" | sed -nE 's/.*Test run with ([0-9]+) tests? in [0-9]+ suites? passed.*/\1/p' | tail -1)
echo "${n:-0}"
