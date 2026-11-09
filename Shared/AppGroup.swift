// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-09 07:37 -06:00
import Foundation

/// The App Group the host app writes and the widget reads (`F1`). Each platform uses the form
/// Apple documents for it: `group.` on iOS; the Team-ID prefix on macOS, which needs no
/// provisioning profile. Must match Entitlements/*.entitlements.
enum AppGroup {
    #if os(macOS)
    static let id = "KH6NBQRZBY.com.martingleason.countdown"
    #else
    static let id = "group.com.martingleason.countdown"
    #endif
}

/// The spec's target until the store exists (`F1-T2`): 2030-06-30 17:00 America/Chicago.
enum Placeholder {
    static let target = Date(timeIntervalSince1970: 1_909_087_200)
}
