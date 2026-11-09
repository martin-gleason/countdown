// Created: 2026-11-08 21:20 -06:00 · Edited: 2026-11-08 21:44 -06:00
import Foundation

/// The widget families this project draws (spec §2). Raw values match WidgetKit's names;
/// the core imports no UI framework.
public enum Family: String, Codable, CaseIterable, Sendable {
    case accessoryInline, accessoryCircular, accessoryRectangular, accessoryCorner
    case systemSmall, systemMedium
}

/// A style, decoded from a bundled `Styles/<name>.json` (`FR9`, `D8`). Field list per spec §3.
/// A designer adds a style by adding a file; no Swift changes.
public struct CountdownStyle: Codable, Equatable, Sendable {
    public enum Unit: String, Codable, Sendable { case hours, days, ymd, sentence }
    public enum Arrangement: String, Codable, Sendable { case stacked, inline, ring, bar, milestone }
    public enum AccentRole: String, Codable, Sendable { case number, unit, progress, none }
    public enum TextStyle: String, Codable, Sendable {
        case largeTitle, title, title2, title3, headline, body, caption
    }
    public enum Weight: String, Codable, Sendable { case regular, medium, semibold, bold, heavy }

    public struct Typography: Codable, Equatable, Sendable {
        public var textStyle: TextStyle
        public var weight: Weight
        public var rounded: Bool
        public var monospacedDigits: Bool
    }

    public struct NumberFormat: Codable, Equatable, Sendable {
        /// Thousands separators: 31,915.
        public var grouping: Bool
        /// Short units where space is tight: "3y 7m 21d", "31,915 h".
        public var abbreviate: Bool
    }

    /// What changes for one family. `fallback` names the style to draw instead.
    public struct FamilyRule: Codable, Equatable, Sendable {
        public var fallback: String?
        public var typography: Typography?
    }

    /// The file's name without `.json`; set by the library, not read from the file.
    public var name: String = ""
    public var displayName: String
    public var unit: Unit
    public var arrangement: Arrangement
    public var typography: Typography
    public var accentRole: AccentRole
    public var numberFormat: NumberFormat
    /// Milestone step in hours (`D9`). Read only by the milestone arrangement.
    public var milestoneStep: Int?
    /// The style to draw when this one cannot be drawn (no start date for Ring or Bar).
    public var fallback: String?
    public var families: [Family: FamilyRule]?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case displayName, unit, arrangement, typography, accentRole, numberFormat
        case milestoneStep, fallback, families
    }

    public init(from decoder: Decoder) throws {
        try Self.refuseUnknownKeys(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayName = try c.decode(String.self, forKey: .displayName)
        unit = try c.decode(Unit.self, forKey: .unit)
        arrangement = try c.decode(Arrangement.self, forKey: .arrangement)
        typography = try c.decode(Typography.self, forKey: .typography)
        accentRole = try c.decode(AccentRole.self, forKey: .accentRole)
        numberFormat = try c.decode(NumberFormat.self, forKey: .numberFormat)
        milestoneStep = try c.decodeIfPresent(Int.self, forKey: .milestoneStep)
        fallback = try c.decodeIfPresent(String.self, forKey: .fallback)
        // Keys must be real family names; an unknown key is an error, not a silent no-op.
        if let raw = try c.decodeIfPresent([String: FamilyRule].self, forKey: .families) {
            var out: [Family: FamilyRule] = [:]
            for (key, rule) in raw {
                guard let family = Family(rawValue: key) else {
                    throw DecodingError.dataCorruptedError(forKey: .families, in: c,
                        debugDescription: "unknown family '\(key)'")
                }
                out[family] = rule
            }
            families = out
        }
        if let step = milestoneStep, step <= 0 {
            throw DecodingError.dataCorruptedError(forKey: .milestoneStep, in: c,
                debugDescription: "milestoneStep must be positive")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(unit, forKey: .unit)
        try c.encode(arrangement, forKey: .arrangement)
        try c.encode(typography, forKey: .typography)
        try c.encode(accentRole, forKey: .accentRole)
        try c.encode(numberFormat, forKey: .numberFormat)
        try c.encodeIfPresent(milestoneStep, forKey: .milestoneStep)
        try c.encodeIfPresent(fallback, forKey: .fallback)
        if let families {
            try c.encode(Dictionary(uniqueKeysWithValues: families.map { ($0.key.rawValue, $0.value) }),
                         forKey: .families)
        }
    }

    /// A misspelt field (`"familes"`, `"fallbak"`) is an error, like an unknown family name,
    /// never a silent no-op: the files are written by hand (spec §3).
    static func refuseUnknownKeys(_ decoder: Decoder) throws {
        let typography: Set<String> = ["textStyle", "weight", "rounded", "monospacedDigits"]
        func check(_ c: KeyedDecodingContainer<AnyKey>, _ allowed: Set<String>, _ where_: String) throws {
            let unknown = c.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
            if !unknown.isEmpty {
                throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                    debugDescription: "unknown field(s) in \(where_): \(unknown.joined(separator: ", "))"))
            }
        }
        let top = try decoder.container(keyedBy: AnyKey.self)
        try check(top, Set(CodingKeys.allCases.map(\.stringValue)), "the style")
        if top.contains(AnyKey("typography")) {
            try check(top.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("typography")), typography, "typography")
        }
        if top.contains(AnyKey("numberFormat")) {
            try check(top.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("numberFormat")),
                      ["grouping", "abbreviate"], "numberFormat")
        }
        if top.contains(AnyKey("families")) {
            let families = try top.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("families"))
            for key in families.allKeys {
                let rule = try families.nestedContainer(keyedBy: AnyKey.self, forKey: key)
                try check(rule, ["fallback", "typography"], "families.\(key.stringValue)")
                if rule.contains(AnyKey("typography")) {
                    try check(rule.nestedContainer(keyedBy: AnyKey.self, forKey: AnyKey("typography")),
                              typography, "families.\(key.stringValue).typography")
                }
            }
        }
    }

    /// Ring and Bar draw progress, which needs a start date.
    public var needsStartDate: Bool { arrangement == .ring || arrangement == .bar }

    /// The default style, compiled in, so a broken or missing hours.json still draws (`RR8`).
    public static let builtInHours: CountdownStyle = {
        var s = try! JSONDecoder().decode(CountdownStyle.self, from: Data(#"""
        {"displayName": "Hours", "unit": "hours", "arrangement": "stacked",
         "typography": {"textStyle": "largeTitle", "weight": "semibold", "rounded": true, "monospacedDigits": true},
         "accentRole": "number", "numberFormat": {"grouping": true, "abbreviate": false},
         "families": {"accessoryInline": {"typography": {"textStyle": "body", "weight": "semibold", "rounded": true, "monospacedDigits": true}}}}
        """#.utf8))
        s.name = "hours"
        return s
    }()
}

/// A coding key for any field name, used to list the fields a file actually has.
struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// Why a resolve did not return the style that was asked for.
public enum StyleIssue: Equatable, Sendable {
    case unknown(String)
    case cycle([String])
    case tooDeep
}

/// Every bundled style, by name, plus the files that failed to decode (`D8`, `RR8`).
public struct StyleLibrary: Sendable {
    public let styles: [String: CountdownStyle]
    /// File name → decoder error text. Tests require this to be empty for the bundle.
    public let failures: [String: String]

    public init(styles: [String: CountdownStyle], failures: [String: String] = [:]) {
        self.styles = styles
        self.failures = failures
    }

    /// Decodes every `*.json` in `directory`. A bad file is recorded, never fatal.
    public init(directory: URL) {
        var styles: [String: CountdownStyle] = [:], failures: [String: String] = [:]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "json" {
            let name = url.deletingPathExtension().lastPathComponent
            do {
                var style = try JSONDecoder().decode(CountdownStyle.self, from: Data(contentsOf: url))
                style.name = name
                styles[name] = style
            } catch {
                failures[url.lastPathComponent] = String(describing: error)
            }
        }
        self.init(styles: styles, failures: failures)
    }

    /// The styles bundled in this package (`Sources/CountdownCore/Styles`).
    public static let bundled = StyleLibrary(
        directory: Bundle.module.resourceURL!.appendingPathComponent("Styles"))

    /// The style to draw for `name` on `family`, following fallbacks. Never fails: an unknown
    /// name, a cycle or a chain longer than the library ends at the built-in Hours, with the
    /// reason reported.
    public func resolve(_ name: String, for family: Family, hasStartDate: Bool)
        -> (style: CountdownStyle, issue: StyleIssue?) {
        var current = name
        var visited: [String] = []
        for _ in 0...styles.count {
            guard let style = styles[current] else {
                return (hours(for: family), .unknown(current))
            }
            visited.append(current)
            let next: String?
            if let rule = style.families?[family], let fb = rule.fallback {
                next = fb
            } else if style.needsStartDate && !hasStartDate {
                next = style.fallback ?? "hours"
            } else {
                var drawn = style
                if let t = style.families?[family]?.typography { drawn.typography = t }
                return (drawn, nil)
            }
            guard let next else { break }
            if visited.contains(next) {
                return (hours(for: family), .cycle(visited + [next]))
            }
            current = next
        }
        return (hours(for: family), .tooDeep)
    }

    /// Where every failure ends: the bundled Hours (or the compiled-in one), with this family's
    /// typography applied, so a broken name still draws at the right size (`RR5`).
    func hours(for family: Family) -> CountdownStyle {
        var s = styles["hours"] ?? .builtInHours
        if let t = s.families?[family]?.typography { s.typography = t }
        return s
    }
}
