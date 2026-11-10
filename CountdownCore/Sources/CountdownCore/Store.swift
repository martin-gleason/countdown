// Created: 2026-11-10 07:46 -06:00 · Edited: 2026-11-10 08:03 -06:00
import Foundation

/// The one synced record (`FR4`, `D5`): what every device counts down to.
public struct CountdownRecord: Codable, Equatable, Sendable {
    public var target: Date
    /// The zone the target was entered in, shown with the target date (`D6`).
    public var timeZone: String
    public var label: String
    public var countUp: Bool
    public var start: Date?
    /// Set when a person changes the record on some device. The newest wins.
    public var modifiedAt: Date

    public init(target: Date, timeZone: String, label: String, countUp: Bool,
                start: Date? = nil, modifiedAt: Date) {
        self.target = target; self.timeZone = timeZone; self.label = label
        self.countUp = countUp; self.start = start; self.modifiedAt = modifiedAt
    }

    /// Shown until a person sets something: the spec's target. **Never stored** (`D5`).
    public static let specDefault = CountdownRecord(
        target: Date(timeIntervalSince1970: 1_909_087_200), timeZone: "America/Chicago",
        label: "Retirement", countUp: false, modifiedAt: .distantPast)
}

/// A key-value store: the App Group's `UserDefaults`, iCloud's `NSUbiquitousKeyValueStore`,
/// or an in-memory one in tests.
public protocol KeyValueBacking: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ value: Any?, forKey key: String)
}

extension UserDefaults: KeyValueBacking {}
extension NSUbiquitousKeyValueStore: KeyValueBacking {}

/// What a sync did.
public enum SyncResult: Equatable, Sendable {
    case unchanged
    /// iCloud held a newer record; it was copied into this device's App Group.
    case tookRemote
    /// This device held a newer record; it was written to iCloud.
    case pushedLocal
}

/// What a guarded save did.
public enum SaveResult: Equatable, Sendable {
    case saved
    /// A newer record arrived while the edit was open. Nothing was written.
    case superseded
}

/// The App Group copy, mirrored to iCloud by the host apps (spec §2). Widgets construct it
/// with no `cloud`: they read the App Group only.
public final class SharedCountdownStore {
    public static let recordKey = "countdown.record.v1"
    public static let deviceStyleKey = "countdown.deviceStyle"
    /// The widget picker's "Device default" choice (`D7`).
    public static let deviceDefault = "device-default"

    private let local: KeyValueBacking
    private let cloud: KeyValueBacking?

    public init(local: KeyValueBacking, cloud: KeyValueBacking? = nil) {
        self.local = local; self.cloud = cloud
    }

    /// The record a person set, on this device or another; `nil` until then.
    public var record: CountdownRecord? { Self.decode(local.data(forKey: Self.recordKey)) }

    /// What to show: the record, or the spec's default without storing it.
    public var current: CountdownRecord { record ?? .specDefault }

    /// A person changed the record on this device.
    public func save(_ record: CountdownRecord, now: Date = .now) {
        var r = record
        r.modifiedAt = now
        let data = Self.encode(r)
        local.set(data, forKey: Self.recordKey)
        cloud?.set(data, forKey: Self.recordKey)
    }

    /// Save an edit that began from `base`: the record the editor loaded, or `nil` when it
    /// started from the spec's default. Syncs first, and **refuses the edit if a different record
    /// has arrived since**, so a new device opened before iCloud delivers cannot push the default
    /// target over the real one by changing one field (`D5`, `RR4`; F1 review finding 1).
    @discardableResult
    public func save(_ record: CountdownRecord, editing base: CountdownRecord?,
                     now: Date = .now) -> SaveResult {
        sync()
        guard self.record == base else { return .superseded }
        save(record, now: now)
        return .saved
    }

    /// Reconcile with iCloud: at launch and on every iCloud change. The newest record wins,
    /// and nothing is ever written that a person did not set (`D5`, `RR4`).
    @discardableResult
    public func sync() -> SyncResult {
        guard let cloud else { return .unchanged }
        let localRecord = record
        guard let remote = Self.decode(cloud.data(forKey: Self.recordKey)) else {
            // iCloud has nothing yet: a new device, or iCloud has not delivered. Never fill it.
            if let l = localRecord {
                cloud.set(Self.encode(l), forKey: Self.recordKey)
                return .pushedLocal
            }
            return .unchanged
        }
        guard let l = localRecord else {
            local.set(Self.encode(remote), forKey: Self.recordKey)
            return .tookRemote
        }
        if remote.modifiedAt > l.modifiedAt {
            local.set(Self.encode(remote), forKey: Self.recordKey)
            return .tookRemote
        }
        if l.modifiedAt > remote.modifiedAt {
            cloud.set(Self.encode(l), forKey: Self.recordKey)
            return .pushedLocal
        }
        return .unchanged
    }

    /// This device's own style, set in its host app. Never synced (spec §2).
    public var deviceStyle: String? {
        get { local.data(forKey: Self.deviceStyleKey).flatMap { String(data: $0, encoding: .utf8) } }
        set { local.set(newValue.map { Data($0.utf8) }, forKey: Self.deviceStyleKey) }
    }

    /// The style a widget draws: its own choice, or this device's style for "Device default"
    /// or no choice (`D7`), or Hours when the device has none.
    public func styleName(for choice: String?) -> String {
        guard let choice, choice != Self.deviceDefault else {
            return deviceStyle ?? "hours"
        }
        return choice
    }

    static func encode(_ r: CountdownRecord) -> Data {
        (try? JSONEncoder().encode(r)) ?? Data()
    }

    static func decode(_ data: Data?) -> CountdownRecord? {
        data.flatMap { try? JSONDecoder().decode(CountdownRecord.self, from: $0) }
    }
}
