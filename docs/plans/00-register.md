# Register — Countdown

Created: 2026-11-08 21:00 -06:00 · Edited: 2026-11-08 21:16 -06:00

Every register for this project, one `##` each. Baseline: [countdown-widget-spec.md](../specs/countdown-widget-spec.md) (frozen 2026-11-08). **Where this register and the spec disagree, the register wins.** First-gate plan: [mvp.md](mvp.md). Open questions: [2026-11-08 spec review](../handoffs/2026-11-08-spec-review.md).

---

## Decisions (D)

Immutable once ratified. Supersede, never edit. A rejected row stays, struck through.

| ID | Status | Milestone | Decision |
|---|---|---|---|
| D1 | ratified 2026-11-08 | MVP | **The spec is the baseline**, including every row of its §6. |
| D2 | ratified 2026-11-08 | MVP | **Spec phases map to units.** Phase 1 → `C0` `C1` `C2` · Phase 2 → `F1` · Phase 3 → `F2` · Phase 4 → `F3` · Phase 5 → `C3`. Each phase gate becomes a `G` row. "Phase" is not used after this row. |
| D3 | ratified 2026-11-08 | MVP | **CountdownCore is a chore (`C2`), not a feature.** A user sees nothing until a widget draws it. The spec's core-first gate stays (`G2`). |
| D4 | ratified 2026-11-08 | MVP | **Timeline entries fall at `target − k·3600 s`, not at the local top of the hour.** This replaces the spec §5 test "all on the hour". Local top of the hour is wrong in :30/:45 time zones and for any target not on the hour. Evidence: handoff §1. |
| D5 | ratified 2026-11-08 | MVP | **One synced record under one iCloud key**: target, entry time zone, label, count-up flag, start date, modified-at. The newest modified-at wins. A device never writes defaults to iCloud. |
| D6 | ratified 2026-11-08 | MVP | **Store the time zone the target was entered in, and show the target date in that zone.** Y/M/D still use the current zone (spec §5). |
| D7 | ratified 2026-11-08 | MVP | **The style picker lists the bundled JSON files dynamically (an AppEntity query, not an AppEnum)** and includes "Device default", which the host app sets. This settles the spec's per-device vs per-widget style in §2. |
| D8 | ratified 2026-11-08 | MVP | **Style JSON lives in CountdownCore's resources**, so every target reads the same files, and the test suite decodes every bundled file. |
| D9 | ratified 2026-11-08 | MVP | **The Milestone step is 10,000 hours** (from the spec's own example: 34,872 → 30,000). A style field can override it. |
| D10 | ratified 2026-11-08 | MVP | **Accent: `F1` ships system tint only; `F3` adds the curated colors.** This settles the overlap between spec Phase 2 and Phase 4. |
| D11 | ratified 2026-11-08 | MVP | **Repo: private `martin-gleason/countdown`.** |
| D12 | ratified 2026-11-08 | MVP | **Builds run serially in-session.** CLAUDE.md carries no standing Workflow (ultracode) authorization, per spec "No fire-and-forget scaling". |
| D13 | ratified 2026-11-08 | MVP | **Learning level 5%.** The agent authors; Marty reviews every PR and builds in Xcode. |
| D14 | ratified 2026-11-08 | MVP | **No third-party dependencies.** Apple frameworks only. |
| D15 | ratified 2026-11-08 | MVP | **The spec gains `FR1`–`FR12`, `NFR1`–`NFR5` and a `## Stack` once, before its first commit, with no other words changed** (handoff Q1, option A). |
| D16 | ratified 2026-11-08 | MVP | **The hour before the target shows "< 1", the hour starting at the target shows "Now", and after that the count-up runs from 1 or the done state shows** (handoff Q2, option A). Settles `FR8`. |
| D17 | ratified 2026-11-08 | MVP | **Distribution: reinstall from Xcode once a year, with a recurring reminder** (handoff Q5, option A). Mitigates `RR3`. |

## Features (F)

| ID | Feature | Status | Spec | Depends on | Plan |
|---|---|---|---|---|---|
| F1 | Lock Screen and Mac desktop widgets: Hours, Stacked and Days styles, the host app, iCloud sync | not built | Phase 2 | `C2`, `O6` | at `G2` |
| F2 | Apple Watch complications | not built | Phase 3 | `F1` | at `G3` |
| F3 | Sentence, Ring, Bar and Milestone styles, accent colors, the count-up state, Dynamic Type, VoiceOver | not built | Phase 4 | `F1` | at `G4` |

## Chores (C)

| ID | Chore | P | Status | Owner | Depends on | Plan |
|---|---|---|---|---|---|---|
| C0 | Scaffold: git, vendored conventions (turing-review `9615341`), CLAUDE.md, reviewer agent, status page, private GitHub repo | P0 | built 2026-11-08 — private repo `martin-gleason/countdown` created and pushed; waiting on the PR merge | agent | `G1` | [mvp](mvp.md#c0) |
| C1 | Build the Swift harness (run · count · floor · mutate · precommit) | P0 | built 2026-11-08 — also created the CountdownCore package and its first function (hours, `FR6`) so the harness has real code to break; waiting on the PR merge | agent | `C0` | [C1](C1.md) |
| C2 | CountdownCore package: snapshot math, style decoder, timeline builder, tests | P0 | open | agent | `C1` | [mvp](mvp.md#c2) |
| C3 | Install signed builds on every device, configure once, set the yearly reinstall reminder (`D17`), confirm still running after 8 days | P1 | open | human | `F3` | at `G5` |

## Gates (G)

A gate is an event: the owner's explicit yes. It is recorded here when it happens.

| ID | Gate | Status | What crossing it means |
|---|---|---|---|
| G1 | MVP plan and the `C0`–`C2` breakdown | done 2026-11-08 — "questions answered, begin g1" | Begin `C0`. |
| G2 | Core shape ratified: tests green, including the hour-boundary, leap-day and DST cases | open | Write the `F1` plan. |
| G3 | `F1` renders on iPhone and Mac in all three rendering modes; a target set on one appears on the other | open | Write the `F2` plan. |
| G4 | `F2` complication is live on a watch face | open | Write the `F3` plan. |
| G5 | `F3` passes at the largest Dynamic Type size and under VoiceOver | open | Begin `C3`. |
| G6 | MVP: still running on every device after 8 days | open | MVP shipped. |

## Risks (RR)

| ID | Risk | Status | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|---|---|
| RR1 | A widget sees a target change only after its host app runs on that device, and the Watch app may rarely run. | open | high | low | The target is set once. `F1`/`F2` spikes: read iCloud from the extension; WatchConnectivity complication push. | agent |
| RR2 | iCloud key-value store on watchOS and inside a widget extension is **unverified here**. | open | medium | high | Run a device spike before `F1`/`F2` rely on it; the row records the command and its output. | agent |
| RR3 | Signed builds expire: developer provisioning profiles last about a year (**from memory, not checked**), and a lapsed membership stops them sooner. The 8-day gate does not test a 3.6-year life. | open | high | high | `D17`: yearly reinstall with a reminder, set in `C3`. | owner |
| RR4 | A new device writes default values over the real target before iCloud delivers it. | open | medium | high | `D5`, plus mutation `M8`. | agent |
| RR5 | A five-digit Hours number on accessoryCircular, or Sentence on accessoryInline, does not fit at large type. | open | high | medium | Per-family fallback and abbreviation; checked at `G3` and `G5`. | agent |
| RR6 | WidgetKit and Liquid Glass APIs differ between the iOS 26 floor and the Xcode 27.2 SDK in use. | open | medium | medium | Spec §3 check of Apple's docs as `F1-T1`. | agent |
| RR7 | GitHub's macOS runners may not have Xcode 27 or Swift 6.4, so CI cannot build. **Unverified.** | open | medium | medium | `C1` checks the runner image first; the local pre-commit stays the gate meanwhile. | agent |
| RR8 | A malformed style JSON shows only at runtime, as a blank widget. | open | medium | medium | `D8`: every bundled file is decoded in tests; mutation `M5`. | agent |

## Owner items (O)

| ID | Item | P | Status |
|---|---|---|---|
| O1 | The spec has no `FR`/`NFR` IDs and no Stack section, so drift and the harness check have nothing to cite. Choose how to add them (handoff Q1). | P0 | done 2026-11-08 — `D15` |
| O2 | Choose what the widget shows in the last hour before the target and the first hour after it (handoff Q2). | P0 | done 2026-11-08 — `D16` |
| O3 | Lock the learning level, ratifying or changing `D13` (handoff Q3). | P0 | done 2026-11-08 — `D13` |
| O4 | Choose between a standing Workflow authorization and serial builds, ratifying or changing `D12` (handoff Q4). | P1 | done 2026-11-08 — `D12` |
| O5 | Choose a distribution route that lasts until 2030-06-30 (handoff Q5, `RR3`). | P2 | done 2026-11-08 — `D17` |
| O6 | Confirm the paid Apple Developer membership is active and give the Team ID for the App Group and iCloud identifiers. | P1 | open |
| O7 | After `C0`, turn on branch protection for `main`: PR required, CI required, rebase-merge only. | P1 | open |
| O8 | Read `CLAUDE.md`, the reviewer and the vendored conventions, then run `check_instructions.py --acknowledge --date <day>` in turing-review on this project. | P1 | open |

## Agent items (A)

| ID | Item | P | Status |
|---|---|---|---|
| A1 | Upstream `stamp.py` exempts neither vendored scripts nor a frozen spec. Here `scripts/check_stamps.py` covers both, but the spec's first commit went in before it existed, with the waiver in its body. Propose the exemptions in turing-review. | P2 | open |
| A2 | `pre-commit` reads the working tree, not the staged tree. In `C1`, run it on an exported index, as MusicShare does. | P1 | done 2026-11-08 — `C1` exports the index |
| A3 | Upstream `gen_status.py` treats an unknown flag such as `--help` as a request to write. Report it in turing-review. | P2 | open |
| A4 | Upstream `stamp.py --check` compares Edited with the last commit at minute resolution, so an edit within the same minute passes unstamped. `check_stamps.py` closes it here. Propose the fix in turing-review. | P2 | open |

## Hooks (H)

Plan-local labels. Never in a commit, branch or PR title. The vendored scripts print upstream numbers: upstream `H1` is `H4` here, upstream `H3` is `H3`, and upstream `H15` is `H5`.

| ID | Hook | Surface | Protects | Status |
|---|---|---|---|---|
| H1 | `swift test` plus the count floor, run on the staged tree | pre-commit | test gate | built 2026-11-08 (`C1`) |
| H2 | Document gates, the trace, `swift test` and the floor on a `macos-26` runner; the `xcodebuild` compile check joins in `F1` | CI | test gate | built 2026-11-08 (`C1`); first run is the `C1` PR |
| H3 | Commit grammar `<type>(<F/C id>): …`, with no register ID | commit-msg | ID grammar | built 2026-11-08 (`C0`) |
| H4 | The status page regenerates clean | pre-commit + CI | the status page stays current | built 2026-11-08 (`C0`) |
| H5 | Every staged file carries a current Created · Edited stamp | pre-commit | the stamp rule (upstream `D76`) | built 2026-11-08 (`C0`) |
| H6 | Every test cites an `FR` or a `D`, and every `FR` has a test | pre-commit + CI | drift, both directions | built 2026-11-08 (`C1`) |
| H7 | A doc losing over 60% of its lines needs `Rewrites: <path> — <why>` | commit-msg | overwrite by shell redirect | built 2026-11-08 (`C0`) |
| H8 | A staged change to anything in `docs/specs/` is refused | pre-commit | the frozen spec (`D1`) | built 2026-11-08 (`C0`) |

## Mutations (M)

All `proposed` until applied to shipped code and seen to fail.

| ID | Mutation | Caught by | Status |
|---|---|---|---|
| M1 | Hours rounds instead of floors | `HoursTests/neverRoundsUp` | killed 2026-11-08 — Run: run |
| M2 | Y/M/D built from 86,400-second days | DST and month-end cases | proposed |
| M3 | Timeline entries at the local top of the hour (`D4`) | Asia/Kolkata timeline case | proposed |
| M4 | Count-up after the target uses the countdown's sign or floor | target +1 h, both flag values | proposed |
| M5 | A style fallback cycle is not detected | decoder cycle fixture (must fail, not hang) | proposed |
| M6 | Ring/Bar progress not clamped to 0…1 | now before start; now after target | proposed |
| M7 | Days computed as seconds ÷ 86,400 | DST-day Days case | proposed |
| M8 | A missing iCloud value replaced by the default and written back (`D5`) | first-launch merge case (`F1`) | proposed |

-----
2026-11-08

#AI/Claude
