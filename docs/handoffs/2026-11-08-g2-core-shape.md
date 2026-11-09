# G2 — the core's shape

Created: 2026-11-08 21:30 -06:00 · Edited: 2026-11-08 21:30 -06:00

Spec §7 says nothing scales past Phase 1 until the core's shape is ratified. This is that shape: what `CountdownCore` (chore `C2`) exposes to the widgets, and one amendment found while building it. **Answer under each question. An unanswered question stays open.**

## What a widget gets

**`CountdownSnapshot(at:target:countUp:start:calendar:)`**, one per timeline entry:

| Field | Meaning |
|---|---|
| `phase` | `counting(hours:)` from 1 h out · `finalHour` ("< 1") · `now` (the hour starting at the target) · `countingUp(hours:)` or `done` after that (`D16`) |
| `days` | Calendar days left, or since when counting up |
| `ymd` | years, months and days, from Calendar components in the current zone |
| `progress` | 0…1 from start to target; `nil` without a start date, so Ring and Bar fall back |

**`timelinePlan(from:target:)`**: now, plus 24 entries one second after each whole hour from the target. The widget reloads after the last entry.

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

Entries dated exactly on the hour boundary showed the old number for the whole hour, because a floored count changes just *after* the boundary. So entries sit **one second after** each boundary, and every boundary instant belongs to the earlier value. At exactly 17:00:00 on the target day, the widget reads "< 1"; one second later it reads "Now". The tests that found this are `TimelineTests/constantBetweenEntries` and `crossesTarget`.

- **A (recommended):** ratify `D18`.
- **B:** keep exact boundaries and change the rules instead (for example, round the instant up). That is more code, for a one-second difference nobody sees.

**Answer:**

## Q2 — Ratify the shape above, and cross `G2`

Crossing G2 lets the `F1` plan begin: the widgets, the host app and iCloud sync. You will need to build in Xcode from there.

- **A (recommended):** ratify the shape as written and cross `G2`.
- **B:** change something first (say what).

**Answer:**
