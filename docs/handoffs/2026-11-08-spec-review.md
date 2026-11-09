# Spec review and G1 questions

Created: 2026-11-08 21:00 -06:00 · Edited: 2026-11-08 21:00 -06:00

A review of [countdown-widget-spec.md](../specs/countdown-widget-spec.md) by Turing, before `G1`. Findings that need a decision are rows in the [register](../plans/00-register.md). This file holds the evidence and the five questions. **Answer under each question. An unanswered question stays open; it is never taken as a no.**

## 1. What was checked by running it

`swift datecheck.swift` with Apple Swift 6.4.2 on macOS 27, run 2026-11-08 20:4x CST:

| Spec claim | Result |
|---|---|
| Nov 8 2026 → Nov 8 2030 = 4y 0m 0d, 1,461 days | **holds** |
| Jan 31 → Mar 1 = 1m 1d (2027; also 2028, a leap year) | **holds** |
| Timeline "all on the hour" | **fails outside whole-hour zones.** In Asia/Kolkata the hours count is 41 at 10:29:59 and 40 at 10:30:01, so an entry at 10:00 shows a stale number for 30 minutes. It also fails for any target not on the hour. → `D4` |
| §8 open dependency | **resolved.** `~/Local_Dev_Projects/turing-review` (origin `martin-gleason/code-process-review`, HEAD `9615341`) is present, and its `conventions.md` is identical to the cc-md pinned copy (`diff` empty). |

Also seen: there are 31,915 hours left now, against the spec's illustrative 34,872. Days decrements at 17:00 Chicago time, not at midnight. `C2` pins this behavior in a test.

**Gates:** `gates.py` passes every local gate. It prints **NOT Turing over the corpus**, because one sibling project's status-page check (`H1`) failed. That is outside this project and is left alone.

## 2. Findings recorded as rows

- **Inconsistencies:** per-device vs per-widget style (`D7`); the accent appearing in both Phase 2 and Phase 4 (`D10`); "Phase" is a retired word (`D2`); CountdownCore is not user value (`D3`).
- **Underspecified:** the Milestone step (`D9`); the zone the target date is shown in (`D6`); how fields merge when synced (`D5`).
- **Risks:** a 3.6-year life on 1-year signing (`RR3`); iCloud default overwrite on first launch (`RR4`); unverified iCloud behavior on watchOS and in extensions (`RR2`).

---

## Q1 — Requirement IDs and Stack (`O1`) · blocks `C2`

The spec has no `FR`/`NFR` IDs and no `## Stack`, so the drift hook (`H6`) and the harness check (`H14`) have nothing to read. The spec has not been committed yet.

- **A (recommended):** before the first commit, add the IDs and the Stack block below to the spec once, changing no other words. The edit lands in the same commit that first records the spec.
- **B:** keep the spec byte-identical and add `docs/specs/requirements.md` as a second frozen baseline.

Proposed IDs, each traced to a spec section:

| ID | Requirement | Spec |
|---|---|---|
| FR1 | iOS Lock Screen: accessoryInline, Circular, Rectangular | §2 |
| FR2 | macOS: systemSmall, systemMedium | §2 |
| FR3 | watchOS: accessoryCorner, Circular, Rectangular, Inline | §2 |
| FR4 | Shared target, label, count-up flag and start date, set once and synced by iCloud KVS + App Group | §2 |
| FR5 | Per-widget style and accent via Edit Widget | §2 |
| FR6 | Hours = floor((target − now) / 3600), never rounded up | §5 |
| FR7 | Y/M/D from Calendar components in the current zone | §5 |
| FR8 | Target reached: Now, then count-up if the flag is on, else a done state | §5 |
| FR9 | Styles are bundled JSON drawn by one renderer, with per-family fallback | §3 |
| FR10 | Seven initial styles; Hours is the default | §3 |
| FR11 | Timeline: hourly entries, 24 ahead, `.atEnd` | §5 |
| FR12 | A host app per platform: show the countdown, set the target, pick the device style | §2 |
| NFR1 | Minimum iOS 26 / macOS 26 / watchOS 26 | §6 |
| NFR2 | Legible in full color, accented and vibrant, at the largest Dynamic Type, with VoiceOver | §3, §7 |
| NFR3 | System container background; monospaced digits; no added shadows or gradients | §3 |
| NFR4 | A change appears on another device within a minute of its app running | §5 |
| NFR5 | Keeps working on every device until 2030-06-30 | §1, §7 |

```
## Stack
- language: Swift 6.4
- framework: SwiftUI, WidgetKit, AppIntents
- runner: swift test (Swift Testing), xcodebuild for app targets
- layout: one Xcode project + local package CountdownCore/
- ci: GitHub Actions macOS runner (unverified, RR7)
```

**Answer:**
Go wit option A

## Q2 — The last hour and the first hour after (`O2`) · blocks `C2`

The hours floor reads 0 from 16:00:01 to 17:00, and count-up also reads 0 from 17:00 to 18:00. The spec says "Now within the target hour", which can mean either hour.

- **A (recommended):** 16:00–17:00 shows "< 1"; 17:00–18:00 shows "Now"; from 18:00, count-up from 1 (or the done state). This is closest to the spec, which files "Now" under *Target reached*.
- **B:** "Now" from 16:00 to 17:00; count-up starts at 0 at 17:00.
- **C:** "Now" across both hours, 16:00–18:00.

**Answer:**
Go with A

## Q3 — Learning level (`D13`)

5% means the agent writes all the Swift, and you review every PR and build in Xcode. This matches the spec's workflow and your other Swift projects. 10% adds occasional small pieces for you to write.

- **A (recommended):** 5%. **B:** 10%.

**Answer:**
5%

## Q4 — Workflow authorization (`D12`)

The cc-md template puts a sentence in CLAUDE.md that authorizes multi-agent Workflow builds at every gate. The spec says "No fire-and-forget scaling." These conflict.

- **A (recommended):** leave the sentence out; builds run serially in-session, and the adversarial review still runs.
- **B:** keep the template sentence.

**Answer:**
Leave the sentence out
## Q5 — Distribution until 2030 (`O5`, `RR3`) · needed at `G5`, not now

Builds installed from Xcode stop when the profile expires (about a year, **not checked**). TestFlight builds expire after 90 days (**from memory, not checked**).

- **A (recommended):** reinstall from Xcode once a year, with a recurring reminder. **B:** a private App Store listing. **C:** decide at `G5`.

**Answer:**
go with A
-----
2026-11-08

#AI/Claude
