// Created: 2026-11-10 07:52 -06:00 · Edited: 2026-11-10 07:52 -06:00
import AppIntents
import CountdownCore

/// The per-widget choice, made in Edit Widget (`FR5`). Accent arrives with `F3` (`D10`).
struct StyleIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Countdown style"
    static let description = IntentDescription("Choose how this widget shows the countdown.")

    @Parameter(title: "Style")
    var style: StyleEntity?

    init() {}
}

/// A style the picker offers: every bundled style file, found at run time, plus "Device
/// default" (`D7`). Adding a JSON file adds a choice; no Swift changes.
struct StyleEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Style"
    static let defaultQuery = StyleQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    static let deviceDefault = StyleEntity(id: SharedCountdownStore.deviceDefault, name: "Device default")

    static var all: [StyleEntity] {
        [deviceDefault] + StyleLibrary.bundled.styles.values
            .sorted { $0.displayName < $1.displayName }
            .map { StyleEntity(id: $0.name, name: $0.displayName) }
    }
}

struct StyleQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StyleEntity] {
        StyleEntity.all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [StyleEntity] { StyleEntity.all }

    func defaultResult() async -> StyleEntity? { .deviceDefault }
}
