// Created: 2026-11-08 21:19 -06:00 · Edited: 2026-11-08 21:19 -06:00
import Foundation

/// Calendars and instants shared by the tests. Every instant is built from a wall-clock
/// time in a named zone, so no test depends on the machine's own time zone.
enum Fixture {
    static func calendar(_ zone: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return c
    }

    static func date(_ wall: String, _ zone: String = "America/Chicago") -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: zone)
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: wall)!
    }

    static let chicago = calendar("America/Chicago")
    static let tokyo = calendar("Asia/Tokyo")
    static let kolkata = calendar("Asia/Kolkata")
}
