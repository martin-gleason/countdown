// Created: 2026-11-10 07:54 -06:00 · Edited: 2026-11-10 07:54 -06:00
import SwiftUI
import Combine
import CountdownCore
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    let model: AppModel
    @State private var draft = CountdownRecord.specDefault
    @State private var hasStart = false
    @State private var now = Date.now
    @Environment(\.scenePhase) private var scenePhase
    /// `TimelineView(.everyMinute)` froze on the Mac (2026-11-10), so the clock is re-read on a
    /// timer, on activation and on wake.
    private let tick = Timer.publish(every: 30, tolerance: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Form {
                Section { countdown }
                Section("Target, shared by all your devices") {
                    TextField("Label", text: $draft.label)
                    Picker("Time zone", selection: $draft.timeZone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0) }
                    }
                    DatePicker("Date and time", selection: $draft.target)
                        .environment(\.timeZone, TimeZone(identifier: draft.timeZone) ?? .current)
                    Toggle("Count up after the target", isOn: $draft.countUp)
                    Toggle("Start date (for Ring and Bar)", isOn: $hasStart)
                    if hasStart {
                        DatePicker("Start", selection: Binding(get: { draft.start ?? .now },
                                                               set: { draft.start = $0 }))
                    }
                    Button("Save") {
                        var r = draft
                        r.start = hasStart ? (draft.start ?? .now) : nil
                        model.save(r)
                    }
                    .disabled(!isEdited)
                }
                Section("This device") {
                    Picker("Style", selection: Binding(get: { model.deviceStyle },
                                                       set: { model.deviceStyle = $0 })) {
                        ForEach(styles, id: \.name) { Text($0.displayName).tag($0.name) }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Countdown")
        }
        .onAppear { load() }
        .onChange(of: model.record) { load() }
        .onReceive(tick) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = .now; model.sync() }
        }
        #if os(macOS)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in now = .now }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidWakeNotification)) { _ in now = .now }
        #endif
    }

    /// The device's style, drawn as the medium widget draws it, then the live seconds (`D21`).
    private var countdown: some View {
        let record = model.record
        let style = StyleLibrary.bundled.resolve(model.deviceStyle, for: .systemMedium,
                                                 hasStartDate: record.start != nil).style
        let snapshot = CountdownSnapshot(at: now, target: record.target, countUp: record.countUp,
                                         start: record.start)
        return VStack(alignment: .leading, spacing: 8) {
            StyleView(display: CountdownDisplay(snapshot: snapshot, style: style, record: record),
                      style: style, family: .systemMedium)
                .frame(minHeight: 140)
            if record.target > now {
                Text(timerInterval: now...record.target, countsDown: true)
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var styles: [CountdownStyle] {
        StyleLibrary.bundled.styles.values.sorted { $0.displayName < $1.displayName }
    }

    private var isEdited: Bool {
        var a = draft, b = model.record
        a.start = hasStart ? draft.start : nil
        a.modifiedAt = b.modifiedAt
        b.modifiedAt = a.modifiedAt
        return a != b
    }

    private func load() {
        draft = model.record
        hasStart = model.record.start != nil
    }
}
