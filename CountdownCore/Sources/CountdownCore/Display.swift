// Created: 2026-11-10 07:50 -06:00 · Edited: 2026-11-10 08:03 -06:00
import Foundation

/// The words and numbers a style shows, worked out once so every family and the app agree
/// (`FR9`). The SwiftUI renderer only lays these out; nothing here imports a UI framework.
public struct CountdownDisplay: Equatable, Sendable {
    /// One number and its unit, e.g. "34,872" / "hours". Stacked has three.
    public struct Row: Equatable, Sendable {
        public let number: String
        public let unit: String
    }

    public let rows: [Row]
    /// The one-line form for accessoryInline, e.g. "34,872 h · Retirement" (spec §2).
    public let inline: String
    public let label: String
    /// The target in the zone it was entered in (`D6`).
    public let targetDate: String
    /// After the target with count-up on. `F3` styles it muted.
    public let isCountingUp: Bool

    /// - Parameter calendar: the device's current calendar and zone, the one the snapshot used.
    public init(snapshot: CountdownSnapshot, style: CountdownStyle, record: CountdownRecord,
                calendar: Calendar = .current, locale: Locale = .current) {
        let format = NumberFormatter()
        format.locale = locale
        format.numberStyle = .decimal
        format.usesGroupingSeparator = style.numberFormat.grouping
        func number(_ n: Int) -> String {
            if style.numberFormat.abbreviate && n >= 10_000 {
                format.maximumFractionDigits = 1
                format.roundingMode = .down          // never rounds up (`FR6`)
                return (format.string(from: NSNumber(value: Double(n) / 1000)) ?? "\(n)") + "k"
            }
            return format.string(from: NSNumber(value: n)) ?? "\(n)"
        }
        func unit(_ n: Int, _ one: String, _ many: String) -> String { n == 1 ? one : many }

        let rows: [Row], short: String
        isCountingUp = { if case .countingUp = snapshot.phase { true } else { false } }()
        switch snapshot.phase {
        case .finalHour:
            rows = [Row(number: "< 1", unit: "hour")]
            short = "< 1 h"
        case .now:
            rows = [Row(number: "Now", unit: "")]
            short = "Now"
        case .done:
            rows = [Row(number: "Done", unit: "")]
            short = "Done"
        case .counting(let hours), .countingUp(let hours):
            switch style.unit {
            case .hours:
                rows = [Row(number: number(hours), unit: unit(hours, "hour", "hours"))]
                short = "\(number(hours)) h"
            case .days:
                let d = snapshot.days
                rows = [Row(number: number(d), unit: unit(d, "day", "days"))]
                short = "\(number(d)) d"
            case .ymd, .sentence:
                let y = snapshot.ymd
                rows = [Row(number: "\(y.years)", unit: unit(y.years, "year", "years")),
                        Row(number: "\(y.months)", unit: unit(y.months, "month", "months")),
                        Row(number: "\(y.days)", unit: unit(y.days, "day", "days"))]
                short = "\(y.years)y \(y.months)m \(y.days)d"
            }
        }
        self.rows = rows
        label = record.label
        inline = record.label.isEmpty ? short : "\(short) · \(record.label)"
        let zone = TimeZone(identifier: record.timeZone) ?? calendar.timeZone
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = zone
        // The zone is named, so a wall time from another zone is not read as local (F1 review
        // finding 4): "Jun 30, 2030 at 5:00 PM CDT".
        let when = record.target.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale,
                             calendar: gregorian, timeZone: zone))
        targetDate = zone.abbreviation(for: record.target).map { "\(when) \($0)" } ?? when
    }
}
