// Created: 2026-11-08 21:20 -06:00 · Edited: 2026-11-08 21:20 -06:00
import Foundation

/// The instants a widget timeline needs (`FR11`, as amended by `D4`). Plain dates; the
/// widget extension wraps them in WidgetKit entries and reloads after `reloadAfter`.
public struct TimelinePlan: Equatable, Sendable {
    /// `now` first, then each instant where the displayed value can change.
    public let entries: [Date]
    /// When the widget should ask for a new plan (WidgetKit's `.atEnd`).
    public var reloadAfter: Date { entries.last! }
}

/// Entries one second after each `target + k·3600 s`, never at the local top of the hour
/// (`D4`, as amended by proposed `D18`).
///
/// Every value a snapshot shows changes only at these instants: hours by construction,
/// and Days and Y/M/D because they step when the clock passes the target's wall time,
/// which is a whole number of hours from the target in every zone whose offset and DST
/// shift are whole hours. (Lord Howe's 30-minute DST shift is the one known exception.)
///
/// Why one second after: a floored count changes just *after* a boundary, not at it (at
/// exactly target − 1 h the count still reads 1). An entry dated on the boundary would show
/// the old value for the whole hour. One second after, every value is already the new one.
/// How long after a boundary an entry is dated.
public let settle: TimeInterval = 1

public func timelinePlan(from now: Date, target: Date, ahead count: Int = 24) -> TimelinePlan {
    precondition(count > 0, "a timeline needs at least one entry ahead")
    let anchor = target.addingTimeInterval(settle)
    let k = Int((now.timeIntervalSince(anchor) / 3600).rounded(.down)) + 1
    let ahead = (0..<count).map { anchor.addingTimeInterval(Double(k + $0) * 3600) }
    return TimelinePlan(entries: [now] + ahead)
}
