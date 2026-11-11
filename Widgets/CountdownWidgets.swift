// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-10 07:52 -06:00
import SwiftUI
import WidgetKit
import CountdownCore

/// The widget extension (`F1`, `FR1`, `FR2`). It reads the App Group only; iCloud is the
/// host app's job (spec §2).
@main
struct CountdownWidgets: WidgetBundle {
    var body: some Widget { CountdownWidget() }
}

struct CountdownEntry: TimelineEntry {
    let date: Date
    let record: CountdownRecord
    let styleName: String
}

struct CountdownProvider: AppIntentTimelineProvider {
    private var store: SharedCountdownStore {
        SharedCountdownStore(local: UserDefaults(suiteName: AppGroup.id) ?? .standard)
    }

    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry(date: .now, record: .specDefault, styleName: "hours")
    }

    func snapshot(for configuration: StyleIntent, in context: Context) async -> CountdownEntry {
        let store = store
        return CountdownEntry(date: .now, record: store.current,
                              styleName: store.styleName(for: configuration.style?.id))
    }

    /// An entry one second after every change in what is shown, from CountdownCore (`D18`).
    func timeline(for configuration: StyleIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let store = store
        let record = store.current
        let name = store.styleName(for: configuration.style?.id)
        let plan = timelinePlan(from: .now, target: record.target)
        return Timeline(entries: plan.entries.map { CountdownEntry(date: $0, record: record, styleName: name) },
                        policy: .after(plan.reloadAfter))
    }
}

struct CountdownWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: CountdownEntry

    var body: some View {
        let family = Family(widgetFamily) ?? .systemSmall
        let resolved = StyleLibrary.bundled.resolve(entry.styleName, for: family,
                                                    hasStartDate: entry.record.start != nil)
        let snapshot = CountdownSnapshot(at: entry.date, target: entry.record.target,
                                         countUp: entry.record.countUp, start: entry.record.start)
        StyleView(display: CountdownDisplay(snapshot: snapshot, style: resolved.style, record: entry.record),
                  style: resolved.style, family: family)
            .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Countdown", intent: StyleIntent.self, provider: CountdownProvider()) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("How long until then.")
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

// Previews: one per family, with an entry per bundled style. Step through the entries, and
// switch the canvas between full color, accented and vibrant.
private func previewEntry(_ style: String) -> CountdownEntry {
    CountdownEntry(date: .now, record: .specDefault, styleName: style)
}

#if os(macOS)
#Preview("Small", as: .systemSmall) { CountdownWidget() } timeline: {
    previewEntry("hours"); previewEntry("stacked"); previewEntry("days")
}
#Preview("Medium", as: .systemMedium) { CountdownWidget() } timeline: {
    previewEntry("hours"); previewEntry("stacked"); previewEntry("days")
}
#else
#Preview("Inline", as: .accessoryInline) { CountdownWidget() } timeline: {
    previewEntry("hours"); previewEntry("stacked"); previewEntry("days")
}
#Preview("Circular", as: .accessoryCircular) { CountdownWidget() } timeline: {
    previewEntry("hours"); previewEntry("stacked"); previewEntry("days")
}
#Preview("Rectangular", as: .accessoryRectangular) { CountdownWidget() } timeline: {
    previewEntry("hours"); previewEntry("stacked"); previewEntry("days")
}
#endif
