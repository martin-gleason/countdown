// Created: 2026-11-10 07:50 -06:00 · Edited: 2026-11-10 08:03 -06:00
import Foundation
import Testing
@testable import CountdownCore

@Suite("Display")
struct DisplayTests {
    static let target = Date(timeIntervalSince1970: 1_909_087_200)   // 2030-06-30 17:00 Chicago
    static let us = Locale(identifier: "en_US")
    static let record = CountdownRecord(target: target, timeZone: "America/Chicago",
                                        label: "Retirement", countUp: true, modifiedAt: .distantPast)

    static func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    static func style(_ name: String) -> CountdownStyle { StyleLibrary.bundled.styles[name]! }

    static func display(_ name: String, at date: Date, zone: String = "America/Chicago",
                        record: CountdownRecord = record) -> CountdownDisplay {
        let cal = calendar(zone)
        let snap = CountdownSnapshot(at: date, target: record.target, countUp: record.countUp,
                                     start: record.start, calendar: cal)
        return CountdownDisplay(snapshot: snap, style: style(name), record: record, calendar: cal, locale: us)
    }

    @Test("FR10: Hours shows the grouped, floored count, and the inline form names the label")
    func hoursGrouped() {
        let d = Self.display("hours", at: Self.target.addingTimeInterval(-(34_872 * 3600 + 10)))
        #expect(d.rows == [.init(number: "34,872", unit: "hours")])
        #expect(d.inline == "34,872 h · Retirement")
    }

    @Test("FR10: Days counts calendar days; one day reads singular")
    func daysStyle() {
        let leapSpan = Self.calendar("America/Chicago").date(byAdding: .day, value: -1461, to: Self.target)!
        #expect(Self.display("days", at: leapSpan).rows == [.init(number: "1,461", unit: "days")])
        let oneDay = Self.target.addingTimeInterval(-(86_400 + 60))
        #expect(Self.display("days", at: oneDay).rows == [.init(number: "1", unit: "day")])
    }

    @Test("FR7: Stacked shows years, months and days from Calendar components")
    func stackedRows() {
        let fourYears = Self.calendar("America/Chicago").date(byAdding: .year, value: -4, to: Self.target)!
        let d = Self.display("stacked", at: fourYears)
        #expect(d.rows.map(\.number) == ["4", "0", "0"])
        #expect(d.rows.map(\.unit) == ["years", "months", "days"])
        #expect(d.inline == "4y 0m 0d · Retirement")
    }

    @Test("D16: the last hour reads < 1, the target's hour reads Now, then count-up or Done")
    func phases() {
        #expect(Self.display("hours", at: Self.target.addingTimeInterval(-60)).rows.first?.number == "< 1")
        #expect(Self.display("hours", at: Self.target.addingTimeInterval(60)).rows.first?.number == "Now")
        let up = Self.display("hours", at: Self.target.addingTimeInterval(2 * 3600 + 60))
        #expect(up.rows == [.init(number: "2", unit: "hours")] && up.isCountingUp)
        var off = Self.record
        off.countUp = false
        #expect(Self.display("hours", at: Self.target.addingTimeInterval(7200), record: off).inline == "Done · Retirement")
    }

    @Test("D6: the target date shows in the zone it was entered in, wherever the device is")
    func targetDateInEntryZone() {
        let d = Self.display("hours", at: Self.target.addingTimeInterval(-86_400 * 30), zone: "Asia/Tokyo")
        #expect(d.targetDate.contains("Jun 30, 2030"))
        #expect(d.targetDate.contains("5:00"))
        #expect(!d.targetDate.contains("Jul 1"))
        #expect(d.targetDate.hasSuffix("CDT"))
    }

    @Test("FR6: abbreviation floors, so 34,999 hours reads 34.9k, never 35k")
    func abbreviationFloors() throws {
        var s = Self.style("hours")
        s.numberFormat.abbreviate = true
        let snap = CountdownSnapshot(at: Self.target.addingTimeInterval(-(34_999 * 3600 + 10)),
                                     target: Self.target, countUp: false, calendar: Self.calendar("UTC"))
        let d = CountdownDisplay(snapshot: snap, style: s, record: Self.record,
                                 calendar: Self.calendar("UTC"), locale: Self.us)
        #expect(d.rows.first?.number == "34.9k")
    }
}
