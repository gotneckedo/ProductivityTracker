import Foundation

/// A deliberately small palette that keeps subjects recognizable without making
/// the calm interface feel like a rainbow. Persist the semantic case, not an
/// appearance-specific SwiftUI color.
enum SubjectColor: String, Codable, CaseIterable, Hashable, Identifiable {
    case sage
    case sky
    case lavender
    case peach
    case rose
    case butter
    case mint
    case slate

    var id: String { rawValue }

    /// A platform-neutral sRGB value used by SwiftUI and by pure presentation
    /// models. These eight values are the complete curated palette.
    var hex: UInt32 {
        switch self {
        case .sage: return 0x91B9A3
        case .sky: return 0x91B8D8
        case .lavender: return 0xB1A2D2
        case .peach: return 0xE4AA8D
        case .rose: return 0xD9A0AA
        case .butter: return 0xDFC77F
        case .mint: return 0x8FCDB8
        case .slate: return 0x9EA9BF
        }
    }

    /// The palette's original soft tones remain for capsules and chart fills.
    /// Subject names render in this paired, opaque color so a small overline
    /// stays AA-readable against Still's light page and glass surfaces.
    var textHex: UInt32 {
        switch self {
        case .sage: return 0x3F7A62
        case .sky: return 0x3F6E9E
        case .lavender: return 0x6D5B99
        case .peach: return 0x9E593F
        case .rose: return 0x9C4A5A
        case .butter: return 0x8E6712
        case .mint: return 0x23745F
        case .slate: return 0x4F5E7A
        }
    }

    /// Stable across launches and platforms (unlike Swift's randomized Hasher).
    static func migratedColor(for name: String) -> SubjectColor {
        let value = name.lowercased().unicodeScalars.enumerated().reduce(0) { partial, element in
            partial &+ (element.offset + 1) &* Int(element.element.value)
        }
        return allCases[value % allCases.count]
    }
}

/// A first-class subject carried by tasks, timeline and statistics data.
/// Subjects are values on purpose: edits remain local to the task and persist in
/// the same atomic task record.
struct Subject: Codable, Hashable, Identifiable {
    var name: String
    var color: SubjectColor

    var id: String { "\(name.lowercased())-\(color.rawValue)" }

    init(name: String, color: SubjectColor) {
        self.name = name
        self.color = color
    }

    static func migrated(fromCourse course: String) -> Subject? {
        guard let name = normalizedName(course) else { return nil }
        return Subject(name: name, color: .migratedColor(for: name))
    }

    static func normalizedName(_ raw: String) -> String? {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(40))
    }
}

extension SubjectColor {
    /// Human-readable palette names for the color picker and accessibility.
    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

extension Subject {
    static let biology = Subject(name: "Biology", color: .sage)
    static let literature = Subject(name: "Literature", color: .rose)
}
