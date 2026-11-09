// Created: 2026-11-08 21:19 -06:00 · Edited: 2026-11-08 21:19 -06:00
import Foundation
import Testing
@testable import CountdownCore

@Suite("Snapshot")
struct SnapshotTests {
    let target = ratifiedTarget

    func phase(_ offset: TimeInterval, countUp: Bool) -> CountdownPhase {
        CountdownSnapshot(at: target.addingTimeInterval(offset), target: target,
                          countUp: countUp, calendar: Fixture.chicago).phase
    }

    // MARK: D16 — the hour before, the hour of, and after the target

    @Test("D16: exactly one hour before reads 1 hour; one second later reads < 1")
    func finalHourStarts() {
        #expect(phase(-3600, countUp: true) == .counting(hours: 1))
        #expect(phase(-3599, countUp: true) == .finalHour)
        #expect(phase(-1, countUp: false) == .finalHour)
    }

    @Test("D16: the hour starting at the target reads Now, with either flag")
    func nowHour() {
        #expect(phase(0, countUp: true) == .finalHour)      // the boundary belongs to the earlier value
        #expect(phase(1, countUp: true) == .now)
        #expect(phase(1, countUp: false) == .now)
        #expect(phase(3600, countUp: true) == .now)
        #expect(phase(3600, countUp: false) == .now)
    }

    @Test("FR8: just after an hour past the target, count-up starts at 1, or done shows")
    func afterTarget() {
        #expect(phase(3601, countUp: true) == .countingUp(hours: 1))
        #expect(phase(3601, countUp: false) == .done)
    }

    @Test("FR8: count-up floors; an hour and a half after reads 1, not 2")
    func countUpFloors() {
        #expect(phase(5400, countUp: true) == .countingUp(hours: 1))
        #expect(phase(7200, countUp: true) == .countingUp(hours: 1))
        #expect(phase(7201, countUp: true) == .countingUp(hours: 2))
    }

    // MARK: FR7 — Y/M/D and Days from Calendar components

    @Test("FR7: Nov 8 2026 to Nov 8 2030 is 4y 0m 0d and 1,461 days, across Feb 29 2028")
    func leapDay() {
        let s = CountdownSnapshot(at: Fixture.date("2026-11-08 00:00:00"),
                                  target: Fixture.date("2030-11-08 00:00:00"),
                                  countUp: true, calendar: Fixture.chicago)
        #expect(s.ymd == YearsMonthsDays(years: 4, months: 0, days: 0))
        #expect(s.days == 1461)
    }

    @Test("FR7: Jan 31 to Mar 1 is 1m 1d, in a common year and a leap year")
    func monthEnd() {
        for year in ["2027", "2028"] {
            let s = CountdownSnapshot(at: Fixture.date("\(year)-01-31 00:00:00"),
                                      target: Fixture.date("\(year)-03-01 00:00:00"),
                                      countUp: true, calendar: Fixture.chicago)
            #expect(s.ymd == YearsMonthsDays(years: 0, months: 1, days: 1), "\(year)")
        }
    }

    @Test("FR7: the same instant in Chicago and Tokyo gives the same hours and its own Y/M/D")
    func timeZoneChange() {
        // 2030-02-28 20:00 in Chicago is 2030-03-01 11:00 in Tokyo.
        let now = Fixture.date("2030-02-28 20:00:00")
        let chi = CountdownSnapshot(at: now, target: target, countUp: true, calendar: Fixture.chicago)
        let tyo = CountdownSnapshot(at: now, target: target, countUp: true, calendar: Fixture.tokyo)
        #expect(chi.phase == tyo.phase)
        #expect(chi.ymd == YearsMonthsDays(years: 0, months: 4, days: 1))
        #expect(tyo.ymd == YearsMonthsDays(years: 0, months: 3, days: 29))
    }

    @Test("FR7: Chicago to Tokyo at 23:00 keeps the hour count")
    func travelAt2300() {
        let now = Fixture.date("2030-06-28 23:00:00")
        let chi = CountdownSnapshot(at: now, target: target, countUp: true, calendar: Fixture.chicago)
        let tyo = CountdownSnapshot(at: now, target: target, countUp: true, calendar: Fixture.tokyo)
        #expect(chi.phase == .counting(hours: 42))
        #expect(tyo.phase == .counting(hours: 42))
    }

    @Test("FR7: Days counts calendar days across spring-forward, not 86,400-second days",
          arguments: [("2026-03-07 12:00:00", "2026-03-09 12:00:00"),   // spec §5 date
                      ("2027-03-13 12:00:00", "2027-03-15 12:00:00")])  // inside the countdown
    func springForward(from: String, to: String) {
        let s = CountdownSnapshot(at: Fixture.date(from), target: Fixture.date(to),
                                  countUp: true, calendar: Fixture.chicago)
        #expect(s.phase == .counting(hours: 47))
        #expect(s.days == 2)
        #expect(s.ymd == YearsMonthsDays(years: 0, months: 0, days: 2))
    }

    @Test("FR7: Days counts calendar days across fall-back",
          arguments: [("2026-10-31 12:00:00", "2026-11-02 12:00:00"),   // spec §5 date
                      ("2027-11-06 12:00:00", "2027-11-08 12:00:00")])  // inside the countdown
    func fallBack(from: String, to: String) {
        let s = CountdownSnapshot(at: Fixture.date(from), target: Fixture.date(to),
                                  countUp: true, calendar: Fixture.chicago)
        #expect(s.phase == .counting(hours: 49))
        #expect(s.days == 2)
    }

    @Test("FR7: Days steps down at the target's wall-clock time, not at midnight")
    func daysStepAtTargetTime() {
        func days(_ wall: String) -> Int {
            CountdownSnapshot(at: Fixture.date(wall), target: target, countUp: true,
                              calendar: Fixture.chicago).days
        }
        #expect(days("2030-06-28 16:59:00") == 2)
        #expect(days("2030-06-28 17:01:00") == 1)
        #expect(days("2030-06-29 00:01:00") == 1)
    }

    // MARK: FR9 — progress, for Ring and Bar

    @Test("FR9: progress is clamped to 0...1 and nil without a valid start")
    func progress() {
        let start = target.addingTimeInterval(-1000 * 3600)
        func p(_ offset: TimeInterval, start: Date?) -> Double? {
            CountdownSnapshot(at: target.addingTimeInterval(offset), target: target,
                              countUp: true, start: start, calendar: Fixture.chicago).progress
        }
        #expect(p(-500 * 3600, start: start) == 0.5)
        #expect(p(-2000 * 3600, start: start) == 0)
        #expect(p(10 * 3600, start: start) == 1)
        #expect(p(-10, start: nil) == nil)
        #expect(p(-10, start: target) == nil)
    }
}
