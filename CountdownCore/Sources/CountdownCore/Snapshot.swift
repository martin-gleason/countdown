// Created: 2026-11-08 21:19 -06:00 · Edited: 2026-11-08 21:19 -06:00
import Foundation

/// What a widget shows at one instant (`FR8`, settled by `D16`).
public enum CountdownPhase: Equatable, Sendable {
    /// One hour or more before the target: whole hours left, floored (`FR6`).
    case counting(hours: Int)
    /// Less than an hour left. Shown as "< 1" (`D16`).
    case finalHour
    /// The hour that starts at the target. Shown as "Now" (`D16`).
    case now
    /// An hour or more after the target, with count-up on: whole hours since, floored.
    case countingUp(hours: Int)
    /// An hour or more after the target, with count-up off.
    case done
}

/// Years, months and days, from Calendar components, never 86,400-second days (`FR7`).
public struct YearsMonthsDays: Equatable, Sendable {
    public var years: Int, months: Int, days: Int
    public init(years: Int, months: Int, days: Int) {
        self.years = years; self.months = months; self.days = days
    }
}

/// Everything a style needs to draw the countdown at `date`. No UI (`C2`).
///
/// **A boundary instant belongs to the earlier value.** Every value changes just *after* a
/// whole hour from the target: at exactly target − 1 h the count reads 1, at exactly the
/// target it reads "< 1", and at exactly target + 1 h it reads "Now". The floored count
/// (`FR6`) and Calendar components already behave this way; the phase rules are written to
/// match, so a timeline entry one second after each boundary (`D18`) is always current.
public struct CountdownSnapshot: Equatable, Sendable {
    public let date: Date
    public let phase: CountdownPhase
    /// Whole days left (or since, when counting up), from Calendar `.day`.
    public let days: Int
    public let ymd: YearsMonthsDays
    /// Share of start → target elapsed, 0...1. Nil without a valid start date (Ring and Bar fall back).
    public let progress: Double?

    /// - Parameters:
    ///   - calendar: carries the current time zone. Y/M/D and Days use it; hours do not.
    public init(at date: Date, target: Date, countUp: Bool, start: Date? = nil,
                calendar: Calendar = .current) {
        self.date = date
        let remaining = target.timeIntervalSince(date)
        let phase: CountdownPhase
        if remaining >= 3600 {
            phase = .counting(hours: hoursRemaining(from: date, to: target))
        } else if remaining >= 0 {
            phase = .finalHour
        } else if remaining >= -3600 {
            phase = .now
        } else {
            // Whole hours since the target, floored, with each boundary counted as the earlier
            // value: 1 from just after target + 1 h up to and including target + 2 h.
            let up = Int((date.timeIntervalSince(target) / 3600).rounded(.up)) - 1
            phase = countUp ? .countingUp(hours: up) : .done
        }
        self.phase = phase
        let (from, to) = remaining > 0 ? (date, target) : (target, date)
        switch phase {
        case .counting, .countingUp:
            let c = calendar.dateComponents([.year, .month, .day], from: from, to: to)
            ymd = YearsMonthsDays(years: c.year ?? 0, months: c.month ?? 0, days: c.day ?? 0)
            days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        case .finalHour, .now, .done:
            ymd = YearsMonthsDays(years: 0, months: 0, days: 0)
            days = 0
        }
        if let start, start < target {
            let p = date.timeIntervalSince(start) / target.timeIntervalSince(start)
            progress = min(max(p, 0), 1)
        } else {
            progress = nil
        }
    }
}
