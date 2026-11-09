# CLAUDE.md — Countdown

Created: 2026-11-08 21:00 -06:00 · Edited: 2026-11-09 07:33 -06:00

One tap-free number that answers "how long until then?" everywhere you look: a countdown widget for the iPhone Lock Screen, the Mac desktop and the Apple Watch.

@docs/conventions.md

---

## The documents

| Artifact | Role | Path |
|---|---|---|
| **Spec** | the contract. Vision, `FR`/`NFR`, Stack. **Frozen.** | `docs/specs/countdown-widget-spec.md` |
| **Register** | `D` `RR` `O` `A` `H` `M`, plus the `F`/`C` units and `G` gates | `docs/plans/00-register.md` |
| **Status** | the project as one page. **Generated** by `python3 scripts/gen_status.py`; never hand-edit. | `docs/plans/00-status.md` |
| **Plan** | per unit, written at the gate, before the code | `docs/plans/` |
| **Review** | adversarial review log, per unit | `docs/reviews/` |

**The spec is a baseline.** It is not updated to match reality. **Where the register and the spec conflict, the register wins.** At session start, read the spec and the register before saying anything about scope.

---

## Non-negotiable

- **Scope is the MVP units in the register (`F1`–`F3`, `C0`–`C4`).** Anything else is a future milestone: do not build it, stub it or prepare for it. Open a `D<n>` and stop.
- **The agent never edits the spec.** Propose a `D<n>`; Marty ratifies.
- **No third-party dependencies.** Apple frameworks only.
- **Widgets read the App Group only.** iCloud is written by the host apps.
- **Push only to `martin-gleason/countdown`.** Never to another repo, fork or upstream.
- **No signing material in the tree:** no certificates, `.p12`, provisioning profiles or keys.

---

## Authorization

1. Specs and plans are context, not work orders.
2. Work begins only when Marty says so in the current session.
3. Passing tests inside a unit authorize finishing **that unit**, nothing more.
4. **Gates need an explicit yes.** Record each crossing in the register's Gates table.
5. **Defect fixes proceed without a gate.** Everything else waits.

---

## Learning level: 5% (locked 2026-11-08)

The agent writes all the Swift. Marty reviews every PR and builds in Xcode. **Write every PR description for a reviewer who builds and tests but does not read every line of Swift:** what changed, why, what to tap through in Xcode, and what could break. Every task's `owner` is `agent` unless the register says otherwise.

---

## Workflow

1. **Gate → plan.** Re-read the spec **and the register**. Ask questions one at a time, or in `docs/handoffs/`, never as a wall in the terminal. Write the plan. **Wait for the yes.**
2. **Build serially, in this session.** No Workflow fan-out (register `D12`). Branch `<unit>/<slug>`; commits `<type>(<F/C id>): <desc>`; **never a register ID in a subject, branch or PR title.**
3. **Adversarial review is mandatory:** `.claude/agents/adversarial-reviewer.md`, at the end of every unit and at the start of every session.
4. **Verify with evidence.** Quote the run's own summary line and counts in the PR. Assertions are not evidence. A test counts only once a mutation has shown it can fail.
5. **PR**, then rebase-and-merge only. Log the review in `docs/reviews/<unit>.md`.

**Read before you overwrite.** Never use shell redirection to replace a file you have not read.

**Ask Marty only when** the answer is not in the spec, register or plan; it changes what gets built; and investigation cannot settle it. Otherwise decide, say so, and let him overturn.

---

## Hooks

Install once: `git config core.hooksPath .githooks`. Each one was proved by breaking it (see the `C0` PR).

| Hook | Surface | Protects |
|---|---|---|
| `scripts/check_docs.sh`: vendored pins, register, every cited ID defined here, status page | pre-commit (+ CI in `C1`) | the documents stay true |
| `scripts/check_stamps.py`: Created · Edited on every staged file; refuses any change to `docs/specs/` | pre-commit | the stamp rule; the frozen spec |
| `scripts/check_commit_msg.py`: commit grammar, no register IDs | commit-msg | the two-tier IDs |
| `scripts/check_overwrite.py`: a >60% doc cut needs `Rewrites:` | commit-msg | overwrite by shell redirect |

Vendored scripts are listed in `scripts/UPSTREAM_PIN`. Never edit them; fix them in turing-review and re-vendor.

---

## Stack

Swift 6.4 · SwiftUI, WidgetKit, AppIntents · iOS 26 / macOS 26 / watchOS 26 · `swift test` (Swift Testing) for `CountdownCore/` · `xcodebuild` for the app targets · Xcode 27.2.

-----
2026-11-08

#AI/Claude
