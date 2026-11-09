#!/bin/sh
# Created: 2026-11-08 21:12 -06:00 · Edited: 2026-11-08 21:26 -06:00
# Harness `count` (`C1`): print one integer, the tests that ran and passed.
# Optional $1: a scratch path, as for run_tests.sh.
root=$(cd "$(dirname "$0")/.." && pwd)
sh "$root/scripts/run_tests.sh" "$@" 2>&1 | sh "$root/scripts/parse_count.sh"
