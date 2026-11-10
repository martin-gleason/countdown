// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-10 07:35 -06:00
import SwiftUI
import Combine
import CountdownCore
#if os(macOS)
import AppKit
#endif

/// The host app (`FR12`). A placeholder until `F1-T5`.
@main
struct CountdownApp: App {
    var body: some Scene {
        WindowGroup { HoursNow() }
    }
}

/// Hours to the target, kept current. `TimelineView(.everyMinute)` was used first and showed the
/// launch value five hours later on the Mac (2026-11-10). So the clock is re-read on a 30-second
/// timer, whenever the app becomes active, and when the Mac or its display wakes.
struct HoursNow: View {
    @State private var now = Date.now
    @Environment(\.scenePhase) private var scenePhase
    private let tick = Timer.publish(every: 30, tolerance: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            Text(hoursRemaining(from: now, to: Placeholder.target), format: .number.grouping(.automatic))
                .font(.system(.largeTitle, design: .rounded).monospacedDigit())
            Text("hours")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .onReceive(tick) { now = $0 }
        .onChange(of: scenePhase) { _, phase in if phase == .active { now = .now } }
        #if os(macOS)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in now = .now }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)) { _ in now = .now }
        #endif
    }
}
