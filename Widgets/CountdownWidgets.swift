// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-09 07:37 -06:00
import SwiftUI
import WidgetKit
import CountdownCore

/// The widget extension (`F1`). A placeholder until `F1-T4`: Hours to the spec's target,
/// on the timeline CountdownCore plans (`D18`).
@main
struct CountdownWidgets: WidgetBundle {
    var body: some Widget { HoursWidget() }
}

struct HoursEntry: TimelineEntry {
    let date: Date
}

struct HoursProvider: TimelineProvider {
    func placeholder(in context: Context) -> HoursEntry { HoursEntry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (HoursEntry) -> Void) {
        completion(HoursEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HoursEntry>) -> Void) {
        let plan = timelinePlan(from: .now, target: Placeholder.target)
        completion(Timeline(entries: plan.entries.map(HoursEntry.init), policy: .after(plan.reloadAfter)))
    }
}

struct HoursWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Countdown", provider: HoursProvider()) { entry in
            VStack(spacing: 0) {
                Text(hoursRemaining(from: entry.date, to: Placeholder.target),
                     format: .number.grouping(.automatic))
                    .font(.system(.title, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .widgetAccentable()
                Text("hours").font(.caption2)
            }
            .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Countdown")
        .description("Hours until the target.")
        .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(macOS)
        [.systemSmall, .systemMedium]
        #else
        [.accessoryInline, .accessoryCircular, .accessoryRectangular]
        #endif
    }
}
