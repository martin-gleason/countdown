#!/bin/sh
# Created: 2026-11-08 21:26 -06:00 · Edited: 2026-11-08 21:26 -06:00
# Read `swift test` output on stdin; print the tests that ran and passed (`C1`).
# Swift Testing's summary counts skipped (disabled) tests among those that "passed", so they
# are subtracted. No passing summary line means 0: a crash or failure never counts.
awk '
  /Test run with [0-9]+ tests? in [0-9]+ suites? passed/ {
      for (i = 1; i <= NF; i++) if ($i == "with") { n = $(i + 1); break }
  }
  /Test ".*" skipped/ { skipped++ }
  END { n = (n == "" ? 0 : n) - skipped; print (n < 0 ? 0 : n) }
'
