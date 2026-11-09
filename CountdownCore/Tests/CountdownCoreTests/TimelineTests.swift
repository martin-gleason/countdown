// Created: 2026-11-08 21:24 -06:00 · Edited: 2026-11-08 21:48 -06:00
import Foundation
import Testing
@testable import CountdownCore

@Suite("Timeline")
struct TimelineTests {
    let target = ratifiedTarget

    func hourEntries(_ plan: TimelinePlan, _ t: Date) -> [Date] {
        plan.entries.dropFirst().filter {
            let r = $0.timeIntervalSince(t.addingTimeInterval(settle)).truncatingRemainder(dividingBy: 3600)
            return r == 0
        }
    }

    @Test("D4: in Asia/Kolkata the first entry after 10:00 is 10:30:01, when the hour count has changed")
    func kolkataHalfHour() {
        let now = Fixture.date("2030-06-29 10:00:00", "Asia/Kolkata")
        let plan = timelinePlan(from: now, target: target, calendar: Fixture.kolkata)
        #expect(plan.entries[1] == Fixture.date("2030-06-29 10:30:01", "Asia/Kolkata"))
        #expect(hoursRemaining(from: now, to: target) == 41)
        #expect(hoursRemaining(from: plan.entries[1], to: target) == 40)
    }

    @Test("D4: a target at 17:30 puts every hourly entry at half past")
    func offHourTarget() {
        let t = Fixture.date("2030-06-30 17:30:00")
        let plan = timelinePlan(from: Fixture.date("2030-06-29 09:05:00"), target: t, calendar: Fixture.chicago)
        let hourly = hourEntries(plan, t)
        #expect(hourly.count == 24)
        for e in hourly {
            #expect(Fixture.chicago.component(.minute, from: e) == 30)
        }
    }

    @Test("FR11: now first, then 24 hourly entries, strictly increasing")
    func shape() {
        let plan = timelinePlan(from: Fixture.date("2030-06-29 09:05:00"), target: target, calendar: Fixture.chicago)
        #expect(plan.entries[1] == Fixture.date("2030-06-29 10:00:01"))
        #expect(hourEntries(plan, target).count == 24)
        #expect(zip(plan.entries, plan.entries.dropFirst()).allSatisfy { $0 < $1 })
        #expect(plan.reloadAfter == plan.entries.last)
    }

    @Test("FR11: now exactly on an entry instant schedules the next one, not itself")
    func onBoundary() {
        let now = target.addingTimeInterval(-3 * 3600 + 1)
        let plan = timelinePlan(from: now, target: target, calendar: Fixture.chicago)
        #expect(plan.entries[1] == target.addingTimeInterval(-2 * 3600 + 1))
    }

    @Test("D16: entries just after the target and an hour after it, so Now and count-up start on time")
    func crossesTarget() {
        let plan = timelinePlan(from: target.addingTimeInterval(-90 * 60), target: target, calendar: Fixture.chicago)
        #expect(plan.entries.contains(target.addingTimeInterval(1)))
        #expect(plan.entries.contains(target.addingTimeInterval(3601)))
        let phases = plan.entries.map {
            CountdownSnapshot(at: $0, target: target, countUp: true, calendar: Fixture.chicago).phase
        }
        #expect(phases.prefix(5) == [.counting(hours: 1), .finalHour, .now, .countingUp(hours: 1), .countingUp(hours: 2)])
    }

    @Test("FR11: Y/M/D steps at Kolkata midnight on Dec 30, and an entry is there")
    func kolkataMonthEndMidnight() {
        // Review trigger: Y/M/D read 3y6m0d at 18:00:01 UTC and 3y6m1d at 18:30:01 UTC.
        let now = Fixture.date("2026-12-30 23:00:00", "Asia/Kolkata")
        let plan = timelinePlan(from: now, target: target, calendar: Fixture.kolkata)
        #expect(plan.entries.contains(Fixture.date("2026-12-31 00:00:01", "Asia/Kolkata")))
    }

    @Test("FR11: nothing shown changes between two entries, from 395 days before the target to 60 after",
          arguments: ["America/Chicago", "Asia/Kolkata", "America/St_Johns", "Pacific/Chatham"],
                     ["2030-06-30 17:00:00", "2028-06-30 02:30:00"])
    func yearAroundTarget(zone: String, targetWall: String) {
        // A year holds every month end and both DST changes. The promise (`D18`): what an entry
        // shows stays right until one second before the next entry. So each interval is
        // sampled at the midpoint of that span, which the builder never looks at, and at its end.
        let cal = Fixture.calendar(zone)
        let t = Fixture.date(targetWall)
        var now = t.addingTimeInterval(-395 * 86400 - 1234)
        let stop = t.addingTimeInterval(60 * 86400)
        var bad = 0
        while now < stop {
            let plan = timelinePlan(from: now, target: t, calendar: cal)
            for (a, b) in zip(plan.entries, plan.entries.dropFirst()) {
                let first = Shown(a, t, cal)
                let mid = a.addingTimeInterval((b.timeIntervalSince(a) - 1) / 2)
                if Shown(mid, t, cal) != first || Shown(b.addingTimeInterval(-1), t, cal) != first {
                    bad += 1
                    if bad <= 3 { Issue.record("\(zone), target \(targetWall): changed between \(a) and \(b)") }
                }
            }
            now = plan.reloadAfter
        }
        #expect(bad == 0)
    }
}
