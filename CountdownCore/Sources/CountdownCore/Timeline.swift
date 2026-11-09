// Created: 2026-11-08 21:24 -06:00 · Edited: 2026-11-08 21:44 -06:00
import Foundation

/// The instants a widget timeline needs (`FR11`, as amended by `D4` and proposed `D18`).
/// Plain dates; the widget extension wraps them in WidgetKit entries and reloads after
/// `reloadAfter`.
public struct TimelinePlan: Equatable, Sendable {
    /// `now` first, then each instant at which a shown value has just changed.
    public let entries: [Date]
    /// When the widget should ask for a new plan (WidgetKit's `.atEnd`).
    public var reloadAfter: Date { entries.last! }
}

/// How long after a change instant an entry is dated, so the new value is already showing
/// whatever convention a value uses at the instant itself.
public let settle: TimeInterval = 1

/// What a widget shows, for change detection. Progress is excluded: it moves continuously
/// and Ring and Bar do not promise to-the-second accuracy.
struct Shown: Equatable {
    let phase: CountdownPhase, days: Int, ymd: YearsMonthsDays
    init(_ d: Date, _ target: Date, _ calendar: Calendar) {
        let s = CountdownSnapshot(at: d, target: target, countUp: true, calendar: calendar)
        phase = s.phase; days = s.days; ymd = s.ymd
    }
}

/// Entries for the next `count` whole hours from the target, plus every other instant in
/// that span where a shown value changes.
///
/// Candidates, each dated `settle` after the instant:
/// - every `target + k·3600 s`, where hours and the phase change (`D4`);
/// - every local midnight, where Calendar's month-end clamping can step Y/M/D.
///
/// Then each interval is **checked, not assumed**: if the shown value 1 s before the next
/// entry differs from the value at the entry, the change instant is found by bisection to
/// the second and an entry is added there. This covers whatever Foundation does at wall
/// times that a DST change skips or repeats. (DST transitions as candidates added nothing the
/// check did not already find, under mutation testing, so they are not listed.) The one
/// assumption is that a value never changes and changes back inside one interval.
public func timelinePlan(from now: Date, target: Date, calendar: Calendar = .current,
                         ahead count: Int = 24) -> TimelinePlan {
    precondition(count > 0, "a timeline needs at least one entry ahead")
    let anchor = target.addingTimeInterval(settle)
    let k = Int((now.timeIntervalSince(anchor) / 3600).rounded(.down)) + 1
    var candidates = (0..<count).map { anchor.addingTimeInterval(Double(k + $0) * 3600) }
    let end = candidates.last!

    var day = calendar.startOfDay(for: now)
    while let next = calendar.date(byAdding: .day, value: 1, to: day) {
        let midnight = calendar.startOfDay(for: next)
        if midnight >= end { break }
        candidates.append(midnight.addingTimeInterval(settle))
        day = midnight
    }

    var entries = [now] + Set(candidates.filter { $0 > now }).sorted()
    var i = 0
    while i < entries.count - 1 {
        let a = entries[i], b = entries[i + 1]
        let first = Shown(a, target, calendar)
        if b.timeIntervalSince(a) > 1, Shown(b.addingTimeInterval(-1), target, calendar) != first {
            var lo = a, hi = b.addingTimeInterval(-1)       // value(lo) == first, value(hi) != first
            while hi.timeIntervalSince(lo) > 1 {
                let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
                if Shown(mid, target, calendar) == first { lo = mid } else { hi = mid }
            }
            entries.insert(hi, at: i + 1)                  // hi already shows the new value
        }
        i += 1
    }
    return TimelinePlan(entries: entries)
}
