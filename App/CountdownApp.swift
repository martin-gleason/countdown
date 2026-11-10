// Created: 2026-11-09 07:37 -06:00 · Edited: 2026-11-10 07:54 -06:00
import SwiftUI
import Combine
import WidgetKit
import CountdownCore
#if os(macOS)
import AppKit
#endif

/// The host app (`FR12`): shows the countdown, sets the shared target, picks this device's
/// style, and carries iCloud changes into the App Group for the widgets (spec §2).
@main
struct CountdownApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 640)
        #endif
    }
}

/// The store, wired to the App Group and to iCloud's key-value store.
@MainActor @Observable
final class AppModel {
    private let store: SharedCountdownStore
    private let cloud = NSUbiquitousKeyValueStore.default
    private(set) var record: CountdownRecord
    var deviceStyle: String {
        didSet { store.deviceStyle = deviceStyle; WidgetCenter.shared.reloadAllTimelines() }
    }
    private var observer: (any NSObjectProtocol)?

    init() {
        store = SharedCountdownStore(local: UserDefaults(suiteName: AppGroup.id) ?? .standard,
                                     cloud: NSUbiquitousKeyValueStore.default)
        record = store.current
        deviceStyle = store.deviceStyle ?? "hours"
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        cloud.synchronize()
        sync()
    }

    /// At launch, on becoming active, and on every iCloud change.
    func sync() {
        if store.sync() != .unchanged {
            record = store.current
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func save(_ edited: CountdownRecord) {
        store.save(edited)
        record = store.current
        WidgetCenter.shared.reloadAllTimelines()
    }
}
