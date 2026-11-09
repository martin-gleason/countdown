# G2 — the core's shape

Created: 2026-11-08 21:30 -06:00 · Edited: 2026-11-08 21:47 -06:00

Spec §7 says nothing scales past Phase 1 until the core's shape is ratified. This is that shape: what `CountdownCore` (chore `C2`) exposes to the widgets, and one amendment found while building it. **Answer under each question. An unanswered question stays open.**

## What a widget gets

**`CountdownSnapshot(at:target:countUp:start:calendar:)`**, one per timeline entry:

| Field | Meaning |
|---|---|
| `phase` | `counting(hours:)` from 1 h out · `finalHour` ("< 1") · `now` (the hour starting at the target) · `countingUp(hours:)` or `done` after that (`D16`) |
| `days` | Calendar days left, or since when counting up |
| `ymd` | years, months and days, from Calendar components in the current zone |
| `progress` | 0…1 from start to target; `nil` without a start date, so Ring and Bar fall back |

**`timelinePlan(from:target:calendar:)`**: now, then an entry one second after every change in what is shown over the next 24 hours (each whole hour from the target, each local midnight, and any other change the builder finds by checking). The widget reloads after the last entry.

**`StyleLibrary.bundled.resolve(name, for: family, hasStartDate:)`**: the style to draw, following fallbacks. It never fails. An unknown name, a cycle or a too-long chain ends at the built-in Hours and says why.

## A style file

```json
{
  "displayName": "Stacked",
  "unit": "ymd",                     // hours | days | ymd | sentence
  "arrangement": "stacked",          // stacked | inline | ring | bar | milestone
  "typography": {"textStyle": "title2", "weight": "semibold", "rounded": true, "monospacedDigits": true},
  "accentRole": "number",            // number | unit | progress | none
  "numberFormat": {"grouping": false, "abbreviate": false},
  "milestoneStep": 10000,            // optional, milestone only (D9)
  "fallback": "days",                // optional: when this style cannot draw (Ring/Bar with no start)
  "families": {                      // optional, per family: a fallback, or replacement typography
    "accessoryCircular": {"fallback": "days"}
  }
}
```

An unknown value, an unknown family name, a missing field or a non-positive `milestoneStep` is refused. A bad file never stops the others loading, and the tests fail if any bundled file is bad. The JSON comments above are for this page only; the real files have none.

---

## Q1 — Ratify `D18` (amends `D4`)

`D4` put entries on each whole hour from the target. Building and reviewing it showed two problems:

1. **On the boundary is too early.** A floored count changes just *after* the boundary, so an entry dated on it showed the old number for the hour. Entries now sit one second after.
2. **Whole hours are not the only changes.** Calendar's month-end clamping makes Y/M/D step at **local midnight**. In :30 and :45 zones (India, Nepal, Newfoundland, Adelaide, Chatham), and for any target not on the hour, midnight is not a whole hour from the target. The review measured a stale Y/M/D for 30–45 minutes about once a month. So entries now also sit at each local midnight. Every interval is then checked, and any remaining change is found by bisection.

The guarantee: what a widget shows lags the true value by at most one second. `TimelineTests/yearAroundTarget` walks the widget's real reload cycle through a full year in four zones and two targets, and checks that it holds.

One side effect, which Foundation and spec `FR7` produce: across some month-end midnights Y/M/D steps **up** (for example 3y 6m 0d → 3y 6m 1d), because months differ in length. Days and hours never step up.

- **A (recommended):** ratify `D18`.
- **B:** narrow the promise to hours and Days only, and accept a stale Y/M/D at some midnights. That is less code, and Stacked and Sentence would show the wrong thing for up to 45 minutes.

**Answer:**

## Q2 — Ratify the shape above, and cross `G2`

Crossing G2 lets the `F1` plan begin: the widgets, the host app and iCloud sync. You will need to build in Xcode from there.

- **A (recommended):** ratify the shape as written and cross `G2`.
- **B:** change something first (say what).

**Answer:**
