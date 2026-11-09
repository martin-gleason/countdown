// Created: 2026-11-08 21:20 -06:00 · Edited: 2026-11-08 21:44 -06:00
import Foundation
import Testing
@testable import CountdownCore

@Suite("Style")
struct StyleTests {
    static func decode(_ json: String) throws -> CountdownStyle {
        try JSONDecoder().decode(CountdownStyle.self, from: Data(json.utf8))
    }

    static func style(_ name: String, _ extra: String = "", arrangement: String = "stacked") -> CountdownStyle {
        var s = try! decode("""
        {"displayName": "\(name)", "unit": "hours", "arrangement": "\(arrangement)",
         "typography": {"textStyle": "title", "weight": "bold", "rounded": true, "monospacedDigits": true},
         "accentRole": "number", "numberFormat": {"grouping": true, "abbreviate": false}\(extra)}
        """)
        s.name = name
        return s
    }

    static func library(_ styles: CountdownStyle...) -> StyleLibrary {
        StyleLibrary(styles: Dictionary(uniqueKeysWithValues: styles.map { ($0.name, $0) }))
    }

    @Test("D8: every bundled style file decodes, and the bundle holds hours, stacked and days")
    func bundleDecodes() {
        let lib = StyleLibrary.bundled
        #expect(lib.failures.isEmpty, "\(lib.failures)")
        #expect(Set(lib.styles.keys) == ["hours", "stacked", "days"])
    }

    @Test("FR10: the bundled Hours matches the compiled-in default, field for field")
    func hoursIsDefault() throws {
        let bundled = try #require(StyleLibrary.bundled.styles["hours"])
        #expect(bundled == CountdownStyle.builtInHours)
    }

    @Test("FR9: a misspelt field at any level is refused, not ignored")
    func misspeltFieldsRefused() {
        let good = #"{"displayName":"x","unit":"hours","arrangement":"stacked","typography":{"textStyle":"title","weight":"bold","rounded":true,"monospacedDigits":true},"accentRole":"number","numberFormat":{"grouping":true,"abbreviate":false}"#
        #expect(throws: (any Error).self) { try Self.decode(good + #","familes":{}}"#) }
        #expect(throws: (any Error).self) { try Self.decode(good + #","families":{"accessoryCircular":{"fallbak":"days"}}}"#) }
        #expect(throws: (any Error).self) { try Self.decode(good.replacingOccurrences(of: #""rounded":true"#, with: #""rounded":true,"italic":true"#) + "}") }
        #expect(throws: (any Error).self) { try Self.decode(good.replacingOccurrences(of: #""abbreviate":false"#, with: #""abbreviate":false,"short":1"#) + "}") }
        #expect(throws: (any Error).self) { try Self.decode(good + #","families":{"accessoryInline":{"typography":{"textStyle":"body","weight":"bold","rounded":true,"monospacedDigits":true,"size":9}}}}"#) }
        #expect((try? Self.decode(good + #","families":{"accessoryInline":{"fallback":"hours"}}}"#)) != nil)
    }

    @Test("FR9: an unknown name or a cycle on accessoryInline still draws Hours at Inline size")
    func failuresKeepFamilyTypography() {
        let lib = StyleLibrary.bundled
        #expect(lib.resolve("neon", for: .accessoryInline, hasStartDate: false).style.typography.textStyle == .body)
        let cyc = Self.library(Self.style("ring", #","fallback":"ring""#, arrangement: "ring"))
        let r = cyc.resolve("ring", for: .accessoryInline, hasStartDate: false)
        #expect(r.issue == .cycle(["ring", "ring"]))
        #expect(r.style.typography.textStyle == .body)
    }

    @Test("FR9: a file with an unknown unit, an unknown family or a missing field is refused")
    func badFilesRefused() {
        let good = #"{"displayName":"x","unit":"hours","arrangement":"stacked","typography":{"textStyle":"title","weight":"bold","rounded":true,"monospacedDigits":true},"accentRole":"number","numberFormat":{"grouping":true,"abbreviate":false}"#
        #expect(throws: (any Error).self) { try Self.decode(good.replacingOccurrences(of: #""unit":"hours""#, with: #""unit":"minutes""#) + "}") }
        #expect(throws: (any Error).self) { try Self.decode(good + #","families":{"accessorySquare":{"fallback":"hours"}}}"#) }
        #expect(throws: (any Error).self) { try Self.decode(good.replacingOccurrences(of: #""accentRole":"number","#, with: "") + "}") }
        #expect(throws: (any Error).self) { try Self.decode(good + #","milestoneStep":0}"#) }
        #expect((try? Self.decode(good + "}")) != nil)
    }

    @Test("FR9: a bad file in a directory is recorded, and the good ones still load")
    func directoryRecordsFailures() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let hours = try #require(StyleLibrary.bundled.styles["hours"])
        try JSONEncoder().encode(hours).write(to: dir.appendingPathComponent("hours.json"))
        try Data("{not json".utf8).write(to: dir.appendingPathComponent("broken.json"))
        let lib = StyleLibrary(directory: dir)
        #expect(Set(lib.styles.keys) == ["hours"])
        #expect(Set(lib.failures.keys) == ["broken.json"])
    }

    @Test("FR9: Stacked on accessoryCircular falls back to Days; on Rectangular it draws itself")
    func familyFallback() {
        let lib = StyleLibrary.bundled
        #expect(lib.resolve("stacked", for: .accessoryCircular, hasStartDate: false).style.name == "days")
        #expect(lib.resolve("stacked", for: .accessoryRectangular, hasStartDate: false).style.name == "stacked")
        #expect(lib.resolve("stacked", for: .accessoryRectangular, hasStartDate: false).issue == nil)
    }

    @Test("FR9: Milestone on accessoryCircular falls back to Hours (spec §3)")
    func milestoneOnCircular() {
        let lib = Self.library(Self.style("hours"),
                               Self.style("milestone", #","families":{"accessoryCircular":{"fallback":"hours"}}"#,
                                          arrangement: "milestone"))
        let r = lib.resolve("milestone", for: .accessoryCircular, hasStartDate: true)
        #expect(r.style.name == "hours")
        #expect(r.issue == nil)
    }

    @Test("FR9: Ring without a start date falls back; with one it draws itself")
    func ringNeedsStart() {
        let lib = Self.library(Self.style("hours"), Self.style("days"),
                               Self.style("ring", #","fallback":"days""#, arrangement: "ring"))
        #expect(lib.resolve("ring", for: .systemSmall, hasStartDate: false).style.name == "days")
        #expect(lib.resolve("ring", for: .systemSmall, hasStartDate: true).style.name == "ring")
    }

    @Test("FR9: a fallback cycle is reported and ends at the built-in Hours, without hanging")
    func cycleDetected() {
        let lib = Self.library(Self.style("a", #","families":{"systemSmall":{"fallback":"b"}}"#),
                               Self.style("b", #","families":{"systemSmall":{"fallback":"a"}}"#))
        let r = lib.resolve("a", for: .systemSmall, hasStartDate: false)
        #expect(r.issue == .cycle(["a", "b", "a"]))
        #expect(r.style == .builtInHours)
    }

    @Test("FR9: an unknown style name ends at Hours and says so")
    func unknownName() {
        let r = StyleLibrary.bundled.resolve("neon", for: .systemSmall, hasStartDate: false)
        #expect(r.style.name == "hours")
        #expect(r.issue == .unknown("neon"))
    }

    @Test("FR9: a family rule's typography replaces the style's on that family only")
    func familyTypography() throws {
        let lib = StyleLibrary.bundled
        let inline = lib.resolve("hours", for: .accessoryInline, hasStartDate: false).style
        let small = lib.resolve("hours", for: .systemSmall, hasStartDate: false).style
        #expect(inline.typography.textStyle == .body)
        #expect(small.typography.textStyle == .largeTitle)
    }
}
