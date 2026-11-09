# Conventions — Countdown only

Created: 2026-11-08 21:12 -06:00 · Edited: 2026-11-08 21:12 -06:00

Rules true of this project and no other. The baseline is `docs/conventions.md` (vendored, never edited).

## Harness

- run: sh scripts/run_tests.sh
- count: sh scripts/count_tests.sh
- floor: tests/TEST_FLOOR
- mutate: python3 scripts/mutate.py
- precommit: .githooks/pre-commit

`count` is the number of Swift Testing tests that ran and passed, read from the run's own summary line. Swift Testing does not report individual `#expect` calls, so the floor counts tests.

## Test names cite what they prove

Every `@Test` has a display name that starts with the `FR`, `NFR` or ratified `D` it proves, for example `@Test("FR6: …")`. `scripts/check_trace.py` enforces this.
