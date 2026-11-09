// Created: 2026-11-08 21:10 -06:00 · Edited: 2026-11-08 21:10 -06:00
import Foundation
import Testing
@testable import CountdownCore

/// The ratified target: 2030-06-30 17:00 America/Chicago, which is 22:00 UTC (spec §6).
let ratifiedTarget = Date(timeIntervalSince1970: 1_909_087_200)

@Suite("Hours")
struct HoursTests {
    @Test("FR6: the ratified target is 2030-06-30 22:00 UTC")
    func targetInstant() {
        #expect(ISO8601DateFormatter().string(from: ratifiedTarget) == "2030-06-30T22:00:00Z")
    }

    @Test("FR6: exactly one hour before reads 1; one second later reads 0")
    func hourBoundary() {
        #expect(hoursRemaining(from: ratifiedTarget.addingTimeInterval(-3600), to: ratifiedTarget) == 1)
        #expect(hoursRemaining(from: ratifiedTarget.addingTimeInterval(-3599), to: ratifiedTarget) == 0)
        #expect(hoursRemaining(from: ratifiedTarget.addingTimeInterval(-3601), to: ratifiedTarget) == 1)
    }

    @Test("FR6: an hour and a half before reads 1, never rounded up to 2")
    func neverRoundsUp() {
        #expect(hoursRemaining(from: ratifiedTarget.addingTimeInterval(-5400), to: ratifiedTarget) == 1)
        #expect(hoursRemaining(from: ratifiedTarget.addingTimeInterval(-7199), to: ratifiedTarget) == 1)
    }
}
