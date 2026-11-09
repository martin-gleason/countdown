// Created: 2026-11-08 21:20 -06:00 · Edited: 2026-11-08 21:20 -06:00
import Foundation
import Testing
@testable import CountdownCore

@Suite("Timeline")
struct TimelineTests {
    let target = ratifiedTarget

    @Test("D4: in Asia/Kolkata the first entry after 10:00 is 10:30:01, when the hour count has changed")
    func kolkataHalfHour() {
        let now = Fixture.date("2030-06-29 10:00:00", "Asia/Kolkata")
        let plan = timelinePlan(from: now, target: target)
        #expect(plan.entries[1] == Fixture.date("2030-06-29 10:30:01", "Asia/Kolkata"))
        #expect(hoursRemaining(from: now, to: target) == 41)
        #expect(hoursRemaining(from: plan.entries[1], to: target) == 40)
    }

    @Test("D4: a target at 17:30 puts every entry at half past")
    func offHourTarget() {
        let t = Fixture.date("2030-06-30 17:30:00")
        let plan = timelinePlan(from: Fixture.date("2030-06-29 09:05:00"), target: t)
        for e in plan.entries.dropFirst() {
            #expect(Fixture.chicago.component(.minute, from: e) == 30)
        }
    }

    @Test("FR11: now first, then 24 entries strictly increasing and one hour apart")
    func shape() {
        let plan = timelinePlan(from: Fixture.date("2030-06-29 09:05:00"), target: target)
        #expect(plan.entries.count == 25)
        #expect(plan.entries[1] == Fixture.date("2030-06-29 10:00:01"))
        for (a, b) in zip(plan.entries.dropFirst(), plan.entries.dropFirst(2)) {
            #expect(b.timeIntervalSince(a) == 3600)
        }
        #expect(plan.reloadAfter == plan.entries.last)
    }

    @Test("FR11: now exactly on an entry instant schedules the next one, not itself")
    func onBoundary() {
        let now = target.addingTimeInterval(-3 * 3600 + 1)
        let plan = timelinePlan(from: now, target: target)
        #expect(plan.entries[1] == target.addingTimeInterval(-2 * 3600 + 1))
    }

    @Test("D16: the target instant and the hour after it are entries, so Now and count-up start on time")
    func crossesTarget() {
        let plan = timelinePlan(from: target.addingTimeInterval(-90 * 60), target: target)
        #expect(plan.entries.contains(target.addingTimeInterval(1)))
        #expect(plan.entries.contains(target.addingTimeInterval(3601)))
        let phases = plan.entries.map {
            CountdownSnapshot(at: $0, target: target, countUp: true, calendar: Fixture.chicago).phase
        }
        #expect(phases.prefix(5) == [.counting(hours: 1), .finalHour, .now, .countingUp(hours: 1), .countingUp(hours: 2)])
    }

    @Test("FR11: nothing shown changes between two entries, in Chicago, Tokyo and Kolkata")
    func constantBetweenEntries() {
        struct Shown: Equatable { let phase: CountdownPhase; let days: Int; let ymd: YearsMonthsDays }
        for cal in [Fixture.chicago, Fixture.tokyo, Fixture.kolkata] {
            // From 3 days out to past the count-up start, sampled every minute and one second
            // before each next entry.
            let plan = timelinePlan(from: target.addingTimeInterval(-70 * 3600 - 1234), target: target, ahead: 75)
            func shown(_ d: Date) -> Shown {
                let s = CountdownSnapshot(at: d, target: target, countUp: true, calendar: cal)
                return Shown(phase: s.phase, days: s.days, ymd: s.ymd)
            }
            for (a, b) in zip(plan.entries, plan.entries.dropFirst()) {
                let first = shown(a)
                var t = a
                while t < b {
                    #expect(shown(t) == first, "\(cal.timeZone.identifier): changed at \(t), between entries \(a) and \(b)")
                    t = min(t.addingTimeInterval(60), b.addingTimeInterval(-1))
                    if t == b.addingTimeInterval(-1) { #expect(shown(t) == first); break }
                }
            }
        }
    }
}
