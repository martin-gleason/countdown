# Plan — MVP, first gate (`G1`)

Created: 2026-11-08 20:46 -06:00 · Edited: 2026-11-08 21:20 -06:00

Covers `C0`, `C1` and `C2`, which together are spec Phase 1 (`D2`). The unit list, dependencies and status live in the [register](00-register.md). `F1`–`F3` and `C3` each get their own plan when their gate opens. **Nothing here starts until Marty says yes to `G1`.** Every task is `owner: agent` (`D13`), and the build runs serially (`D12`).

## C0

Scaffold. Nothing user-visible.

| Task | Work | Checkpoint |
|---|---|---|
| C0-T1 | `git init`; lowercase plural `docs/` dirs; vendor conventions with `turing-review/scripts/vendor.py` (pin `9615341`). The spec is already copied byte-identical to `docs/specs/`. | the vendored body matches upstream, and its SHA-256 equals the pin in its header |
| C0-T2 | CLAUDE.md from the cc-md template, filled from `D11`–`D14`; install `.claude/agents/adversarial-reviewer.md` | `check_instructions.py` lists the three new instruction files for Marty to acknowledge (`O8`) |
| C0-T3 | Hooks `H3`, `H4`, `H5`, `H7` in `.githooks/`, each proved by breaking it once | each hook's refusal output quoted in the PR |
| C0-T4 | Create the private repo `martin-gleason/countdown` (owner check first: it is his and not a fork), then push | `gh repo view` shows the owner and visibility; then `O7` |

## C1

Swift harness. Contract: [C1.md](C1.md). Shape:

- **run:** `swift test --package-path CountdownCore`. The `xcodebuild` compile check joins in `F1`, when an Xcode project exists.
- **count:** the executed-test count parsed from `swift test` output. Swift Testing reports tests, not individual `#expect`s, so this floor counts tests. (**Not yet checked** against Swift 6.4's output format.)
- **floor:** `CountdownCore/.test-floor`. **mutate:** `scripts/mutate.sh` runs find→replace edits from `tests/mutations.json`, each naming the test that must go red. **precommit:** `.githooks/pre-commit` (`H1`).

## C2

CountdownCore: a Swift package with no UI, for iOS, macOS and watchOS 26. **Waits on `O1` (requirement IDs to cite) and `O2` (the last-hour rule).**

| Task | Work | Checkpoint |
|---|---|---|
| C2-T1 | **Foundational, nothing user-visible.** Package skeleton, Swift Testing, wired into `C1`'s harness | `swift test` runs; the count is at or above the floor |
| C2-T2 | `CountdownSnapshot`: hours (floor), count-up, Days, Y/M/D, progress, the Now and done states (`O2`) | every spec §5 case has a named passing test (cases below) |
| C2-T3 | `CountdownStyle` decoder and per-family fallback with cycle detection; `hours.json`, `stacked.json` and `days.json` in package resources (`D8`) | every bundled file decodes; the bad and cyclic fixtures are refused |
| C2-T4 | Timeline builder: entry dates at `target − k·3600 s` (`D4`), 24 ahead, plus the target instant itself. Returns plain dates; no WidgetKit import | Asia/Kolkata, on-hour, off-hour and past-target cases pass |
| C2-T5 | Run mutations `M1`–`M7`; record each `Run`; set the floor | each `M` row reads `run`, with the failing test named |

**Test cases for C2-T2 and C2-T4.** The spec's DST dates (2026-03-08, 2026-11-01) fall before today, so the tests add dates inside the countdown: 2027-03-14 and 2027-11-07. The rest:

- Hour boundary ±1 s.
- Leap day: 2026-11-08 → 2030-11-08 = 4y 0m 0d, 1,461 days.
- Month-end: Jan 31 → Mar 1 = 1m 1d.
- Chicago → Tokyo at 23:00.
- Target −1 h, at the target, and +1 h, with both flag values.
- Days decrements at the target's wall-clock time in the current zone, not at midnight. This is Foundation's behavior, verified 2026-11-08: the count is 2 at 16:59 and 1 at 17:01 on 2030-06-28. The test pins it so a change is visible.

**G2 asks Marty to ratify:** the `CountdownSnapshot` and `CountdownStyle` field lists, and the JSON schema. This is "the core's shape" in spec §7.

-----
2026-11-08

#AI/Claude
