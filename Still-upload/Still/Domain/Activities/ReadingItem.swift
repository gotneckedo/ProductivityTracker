import Foundation

enum ContentLicense: String, Codable, Hashable {
    /// Written for Still; owned by the app publisher.
    case originalForStill
    /// Verified public-domain text (none bundled in V1).
    case publicDomain
    /// Licensed from a third party (none bundled in V1).
    case licensed
    /// A book the reader imported from their own files. Never redistributed.
    case userProvided

    var displayName: String {
        switch self {
        case .originalForStill: return "Original writing for Still"
        case .publicDomain: return "Public domain"
        case .licensed: return "Licensed"
        case .userProvided: return "From your files"
        }
    }
}

enum ReadingFormat: String, Codable, Hashable {
    /// Plain paragraphs bundled in the app.
    case shortText
    /// One sitting from an EPUB book (see `BookLibrary`).
    case epub
}

/// A finite piece of reading with explicit provenance.
struct ReadingItem: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let author: String
    let source: String
    let paragraphs: [String]
    let license: ContentLicense
    let licenseNote: String
    let format: ReadingFormat

    var wordCount: Int {
        paragraphs.reduce(0) { total, paragraph in
            total + paragraph.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        }
    }

    /// Approximate minutes at 200 words per minute, never less than one.
    var readMinutes: Int {
        max(1, Int((Double(wordCount) / 200).rounded(.up)))
    }
}

/// Boundary for reading content. V1 ships a bundled library; V1.1 can add an
/// EPUB-backed provider without touching the reader route.
protocol ReadingContentProviding {
    func allItems() -> [ReadingItem]
    func item(id: String) -> ReadingItem?
}

struct CreativePrompt: Hashable, Identifiable {
    let id: String
    let text: String
    /// A bounded suggestion for how much to write.
    let guidance: String
}
