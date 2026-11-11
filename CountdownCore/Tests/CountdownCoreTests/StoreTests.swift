// Created: 2026-11-10 07:46 -06:00 · Edited: 2026-11-10 07:46 -06:00
import Foundation
import Testing
@testable import CountdownCore

/// A key-value store in memory that counts its writes.
final class MemoryBacking: KeyValueBacking {
    var values: [String: Any] = [:]
    var writes = 0
    func data(forKey key: String) -> Data? { values[key] as? Data }
    func set(_ value: Any?, forKey key: String) { values[key] = value; writes += 1 }
}

@Suite("Store")
struct StoreTests {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func record(_ label: String, modified: Date) -> CountdownRecord {
        CountdownRecord(target: Date(timeIntervalSince1970: 1_909_087_200), timeZone: "America/Chicago",
                        label: label, countUp: true, start: t0, modifiedAt: modified)
    }

    @Test("FR4: saving writes the record to the App Group and to iCloud, stamped now")
    func saveWritesBoth() {
        let local = MemoryBacking(), cloud = MemoryBacking()
        let store = SharedCountdownStore(local: local, cloud: cloud)
        store.save(Self.record("Retirement", modified: .distantPast), now: Self.t0)
        #expect(store.record?.modifiedAt == Self.t0)
        #expect(SharedCountdownStore.decode(cloud.data(forKey: SharedCountdownStore.recordKey)) == store.record)
    }

    @Test("D5: a new device with nothing in iCloud writes nothing, then takes the real record")
    func firstLaunchKeepsRemote() {
        let local = MemoryBacking(), cloud = MemoryBacking()
        let store = SharedCountdownStore(local: local, cloud: cloud)
        #expect(store.sync() == .unchanged)
        #expect(cloud.writes == 0 && local.writes == 0)
        #expect(store.current == .specDefault)

        let real = Self.record("Retirement", modified: Self.t0)
        cloud.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(real)
        #expect(store.sync() == .tookRemote)
        #expect(store.record == real)
    }

    @Test("D5: the record changed most recently wins, in both directions")
    func newestWins() {
        let older = Self.record("older", modified: Self.t0)
        let newer = Self.record("newer", modified: Self.t0.addingTimeInterval(60))

        let (l1, c1) = (MemoryBacking(), MemoryBacking())
        l1.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(older)
        c1.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(newer)
        let s1 = SharedCountdownStore(local: l1, cloud: c1)
        #expect(s1.sync() == .tookRemote)
        #expect(s1.record == newer)

        let (l2, c2) = (MemoryBacking(), MemoryBacking())
        l2.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(newer)
        c2.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(older)
        let s2 = SharedCountdownStore(local: l2, cloud: c2)
        #expect(s2.sync() == .pushedLocal)
        #expect(SharedCountdownStore.decode(c2.data(forKey: SharedCountdownStore.recordKey)) == newer)
    }

    @Test("D5: equal records leave both stores untouched, and a widget's store never syncs")
    func quietWhenEqual() {
        let r = Self.record("same", modified: Self.t0)
        let local = MemoryBacking(), cloud = MemoryBacking()
        local.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(r)
        cloud.values[SharedCountdownStore.recordKey] = SharedCountdownStore.encode(r)
        #expect(SharedCountdownStore(local: local, cloud: cloud).sync() == .unchanged)
        #expect(SharedCountdownStore(local: local).sync() == .unchanged)
        #expect(local.writes == 0 && cloud.writes == 0)
    }

    @Test("D7: Device default draws this device's style, Hours when it has none, and stays local")
    func deviceDefaultStyle() {
        let local = MemoryBacking(), cloud = MemoryBacking()
        let store = SharedCountdownStore(local: local, cloud: cloud)
        #expect(store.styleName(for: nil) == "hours")
        store.deviceStyle = "stacked"
        #expect(store.styleName(for: nil) == "stacked")
        #expect(store.styleName(for: SharedCountdownStore.deviceDefault) == "stacked")
        #expect(store.styleName(for: "days") == "days")
        #expect(cloud.writes == 0)
    }

    @Test("FR4: a damaged stored value reads as no record, and the App Group's UserDefaults works as a store")
    func damagedAndReal() throws {
        let local = MemoryBacking()
        local.values[SharedCountdownStore.recordKey] = Data("not json".utf8)
        #expect(SharedCountdownStore(local: local).record == nil)

        let suite = "CountdownCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SharedCountdownStore(local: defaults)
        store.save(Self.record("Retirement", modified: .distantPast), now: Self.t0)
        #expect(SharedCountdownStore(local: defaults).record?.label == "Retirement")
    }
}
