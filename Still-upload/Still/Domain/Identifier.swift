import Foundation

/// A string-backed, strongly typed identifier.
///
/// `Tag` is a phantom type, so a `SceneID` can never be passed where a
/// `BreakActivityID` is expected. Identifiers encode as a bare string, which
/// keeps persisted payloads readable and lets future content (seasonal scenes,
/// new activities) arrive as data without an enum migration.
struct Identifier<Tag>: Hashable, Codable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var description: String { rawValue }
}

enum BreakActivityTag {}
enum SceneTag {}
enum FocusPresetTag {}
enum AmbientSourceTag {}

typealias BreakActivityID = Identifier<BreakActivityTag>
typealias SceneID = Identifier<SceneTag>
typealias FocusPresetID = Identifier<FocusPresetTag>
typealias AmbientSourceID = Identifier<AmbientSourceTag>
