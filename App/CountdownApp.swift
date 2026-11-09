// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-09 07:37 -06:00
import SwiftUI
import CountdownCore

/// The host app (`FR12`). A placeholder until `F1-T5`.
@main
struct CountdownApp: App {
    var body: some Scene {
        WindowGroup {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 4) {
                    Text(hoursRemaining(from: context.date, to: Placeholder.target),
                         format: .number.grouping(.automatic))
                        .font(.system(.largeTitle, design: .rounded).monospacedDigit())
                    Text("hours")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
}
