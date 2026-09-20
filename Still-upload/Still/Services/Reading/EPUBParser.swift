import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A parsed book: plain paragraphs per chapter. Styling, images, and notes
/// are dropped on purpose; the reader is for a few calm minutes of text.
struct EPUBBook: Hashable {
    struct Chapter: Hashable {
        var title: String
        var paragraphs: [String]

        var wordCount: Int {
            paragraphs.reduce(0) { $0 + $1.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }
        }
    }

    var title: String
    var author: String
    var rights: String?
    var chapters: [Chapter]
}

/// One sitting: a chapter, or a part of a long chapter, sized for a break.
struct BookSitting: Hashable, Identifiable {
    var index: Int
    var chapterTitle: String
    var part: Int
    var partCount: Int
    var paragraphs: [String]

    var id: Int { index }

    var displayTitle: String {
        partCount > 1 ? "\(chapterTitle) · Part \(part) of \(partCount)" : chapterTitle
    }

    var wordCount: Int {
        paragraphs.reduce(0) { $0 + $1.split(whereSeparator: { $0 == " " || $0 == "\n" }).count }
    }
}

/// Where a reader is in one book.
struct ReadingProgress: Codable, Hashable {
    var bookID: String
    /// The sitting that opens next.
    var nextSitting: Int
    var finishedSittings: Int
    var updatedAt: Date
}

/// Splits chapters into break-sized sittings at paragraph boundaries.
enum SittingPlanner {
    /// About three to four minutes at 200 words a minute.
    static let targetWords = 700
    /// A trailing part shorter than this joins the part before it.
    static let minimumWords = 250

    static func sittings(for book: EPUBBook) -> [BookSitting] {
        var result: [BookSitting] = []
        for chapter in book.chapters where chapter.wordCount > 0 {
            let parts = split(chapter.paragraphs)
            for (offset, paragraphs) in parts.enumerated() {
                result.append(BookSitting(index: result.count, chapterTitle: chapter.title,
                                          part: offset + 1, partCount: parts.count, paragraphs: paragraphs))
            }
        }
        return result
    }

    static func split(_ paragraphs: [String]) -> [[String]] {
        var parts: [[String]] = []
        var current: [String] = []
        var words = 0
        for paragraph in paragraphs {
            let count = paragraph.split(separator: " ").count
            if words > 0 && words + count > targetWords {
                parts.append(current)
                current = []
                words = 0
            }
            current.append(paragraph)
            words += count
        }
        if !current.isEmpty {
            if words < minimumWords, let last = parts.popLast() {
                parts.append(last + current)
            } else {
                parts.append(current)
            }
        }
        return parts
    }
}

/// Reads an EPUB 2 or 3 file into chapters of plain paragraphs.
enum EPUBParser {
    enum Failure: Error, Equatable {
        case missingContainer
        case missingPackage
        case emptyBook
    }

    static func parse(data: Data) throws -> EPUBBook {
        let archive = try ZipArchive(data: data)
        guard archive.contains("META-INF/container.xml") else { throw Failure.missingContainer }
        let container = XMLDocumentReader.read(try archive.string(for: "META-INF/container.xml"))
        guard let packagePath = container.firstAttribute(element: "rootfile", name: "full-path") else {
            throw Failure.missingPackage
        }
        let package = XMLDocumentReader.read(try archive.string(for: packagePath))
        let baseDirectory = packagePath.components(separatedBy: "/").dropLast().joined(separator: "/")

        var manifest: [String: (href: String, mediaType: String)] = [:]
        for item in package.elements(named: "item") {
            if let id = item["id"], let href = item["href"] {
                manifest[id] = (href, item["media-type"] ?? "")
            }
        }

        var chapters: [EPUBBook.Chapter] = []
        for itemref in package.elements(named: "itemref") where itemref["linear"] != "no" {
            guard let id = itemref["idref"], let item = manifest[id] else { continue }
            guard item.mediaType.contains("html") || item.href.hasSuffix("html") || item.href.hasSuffix("htm") else { continue }
            let path = resolve(item.href, relativeTo: baseDirectory)
            guard let markup = try? archive.string(for: path) else { continue }
            let chapter = XHTMLText.chapter(from: markup, fallbackTitle: "Part \(chapters.count + 1)")
            if chapter.wordCount >= 20 {
                chapters.append(chapter)
            }
        }
        guard !chapters.isEmpty else { throw Failure.emptyBook }

        let title = package.firstText(element: "title").flatMap(clean) ?? "Untitled"
        let author = package.firstText(element: "creator").flatMap(clean) ?? "Unknown author"
        let rights = package.firstText(element: "rights").flatMap(clean)
        return EPUBBook(title: title, author: author, rights: rights, chapters: chapters)
    }

    /// Joins an href to the package folder, dropping fragments and decoding %20.
    static func resolve(_ href: String, relativeTo base: String) -> String {
        var path = href.components(separatedBy: "#").first ?? href
        path = path.removingPercentEncoding ?? path
        var parts = base.isEmpty ? [] : base.components(separatedBy: "/")
        for component in path.components(separatedBy: "/") {
            switch component {
            case "", ".": continue
            case "..": if !parts.isEmpty { parts.removeLast() }
            default: parts.append(component)
            }
        }
        return parts.joined(separator: "/")
    }

    private static func clean(_ text: String) -> String? {
        let collapsed = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }
}

// MARK: - XML helpers

/// A tiny element list for container.xml and the OPF package. Namespace
/// prefixes are dropped ("dc:title" matches "title").
struct XMLDocumentReader {
    struct Element {
        var name: String
        var attributes: [String: String]
        var text: String

        subscript(key: String) -> String? { attributes[key] }
    }

    var elements: [Element] = []

    static func read(_ markup: String) -> XMLDocumentReader {
        let delegate = CollectingDelegate()
        let parser = XMLParser(data: Data(XHTMLText.xmlSafe(markup).utf8))
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        _ = parser.parse()
        return XMLDocumentReader(elements: delegate.elements)
    }

    func elements(named name: String) -> [Element] {
        elements.filter { $0.name == name }
    }

    func firstAttribute(element: String, name: String) -> String? {
        elements(named: element).first?[name]
    }

    func firstText(element: String) -> String? {
        elements(named: element).first.map(\.text)
    }

    private final class CollectingDelegate: NSObject, XMLParserDelegate {
        var elements: [Element] = []
        private var open: [Int] = []

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let local = elementName.components(separatedBy: ":").last ?? elementName
            elements.append(Element(name: local, attributes: attributeDict, text: ""))
            open.append(elements.count - 1)
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard let index = open.last else { return }
            elements[index].text += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            _ = open.popLast()
        }
    }
}

/// Turns one XHTML chapter into a title and plain paragraphs.
enum XHTMLText {
    private static let blockElements: Set<String> = [
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "pre",
        "td", "th", "dt", "dd", "figcaption", "section", "article", "tr", "br", "hr"
    ]
    private static let headingElements: Set<String> = ["h1", "h2", "h3"]
    private static let skippedElements: Set<String> = ["head", "script", "style", "title", "nav"]

    static func chapter(from markup: String, fallbackTitle: String) -> EPUBBook.Chapter {
        let delegate = ParagraphDelegate()
        let parser = XMLParser(data: Data(xmlSafe(markup).utf8))
        parser.delegate = delegate
        if parser.parse() || !delegate.paragraphs.isEmpty {
            delegate.flush()
            var paragraphs = delegate.paragraphs
            let title = delegate.heading ?? fallbackTitle
            // Drop a leading paragraph that just repeats the heading.
            if let first = paragraphs.first, first == delegate.heading {
                paragraphs.removeFirst()
            }
            return EPUBBook.Chapter(title: title, paragraphs: paragraphs)
        }
        return EPUBBook.Chapter(title: fallbackTitle, paragraphs: fallbackParagraphs(markup))
    }

    /// Replaces HTML-only named entities (which XML parsers reject) with
    /// numeric references, and drops the DOCTYPE.
    static func xmlSafe(_ markup: String) -> String {
        var text = markup
        if let doctype = text.range(of: "<!DOCTYPE[^>]*>", options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(doctype)
        }
        guard text.contains("&") else { return text }
        guard let regex = try? NSRegularExpression(pattern: "&([A-Za-z][A-Za-z0-9]{1,15});") else { return text }
        let source = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: last, length: match.range.location - last))
            let name = source.substring(with: match.range(at: 1))
            if ["amp", "lt", "gt", "quot", "apos"].contains(name) {
                result += "&\(name);"
            } else if let code = namedEntities[name] {
                result += "&#\(code);"
            } else {
                result += " "
            }
            last = match.range.location + match.range.length
        }
        result += source.substring(from: last)
        return result
    }

    static let namedEntities: [String: Int] = [
        "nbsp": 160, "mdash": 8212, "ndash": 8211, "lsquo": 8216, "rsquo": 8217, "ldquo": 8220,
        "rdquo": 8221, "hellip": 8230, "copy": 169, "reg": 174, "trade": 8482, "deg": 176,
        "eacute": 233, "egrave": 232, "ecirc": 234, "euml": 235, "aacute": 225, "agrave": 224,
        "acirc": 226, "auml": 228, "atilde": 227, "aring": 229, "aelig": 230, "ccedil": 231,
        "iacute": 237, "igrave": 236, "icirc": 238, "iuml": 239, "oacute": 243, "ograve": 242,
        "ocirc": 244, "ouml": 246, "otilde": 245, "oslash": 248, "uacute": 250, "ugrave": 249,
        "ucirc": 251, "uuml": 252, "ntilde": 241, "szlig": 223, "Eacute": 201, "Agrave": 192,
        "Ccedil": 199, "Ouml": 214, "Uuml": 220, "Auml": 196, "laquo": 171, "raquo": 187,
        "middot": 183, "bull": 8226, "shy": 173, "thinsp": 8201, "ensp": 8194, "emsp": 8195,
        "pound": 163, "euro": 8364, "cent": 162, "sect": 167, "para": 182, "frac12": 189,
        "frac14": 188, "frac34": 190, "times": 215, "divide": 247, "prime": 8242, "Prime": 8243
    ]

    /// Last resort for markup that isn't well-formed XML.
    static func fallbackParagraphs(_ markup: String) -> [String] {
        var text = markup
        for pattern in ["<(script|style|head)[^>]*>.*?</\\1>"] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: " ")
            }
        }
        if let blocks = try? NSRegularExpression(pattern: "</?(p|div|h[1-6]|li|br|blockquote|tr)[^>]*>", options: .caseInsensitive) {
            text = blocks.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "\n\n")
        }
        if let tags = try? NSRegularExpression(pattern: "<[^>]+>") {
            text = tags.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: "")
        }
        text = decodeBasicEntities(text)
        return text.components(separatedBy: "\n\n")
            .map { $0.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ") }
            .filter { !$0.isEmpty }
    }

    private static func decodeBasicEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    private final class ParagraphDelegate: NSObject, XMLParserDelegate {
        var paragraphs: [String] = []
        var heading: String?
        private var buffer = ""
        private var skipDepth = 0
        private var headingDepth = 0
        private var headingBuffer = ""
        private var inBody = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            let name = local(elementName)
            if name == "body" { inBody = true }
            if XHTMLText.skippedElements.contains(name) { skipDepth += 1; return }
            if XHTMLText.blockElements.contains(name) { flush() }
            if XHTMLText.headingElements.contains(name) { headingDepth += 1 }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = local(elementName)
            if XHTMLText.skippedElements.contains(name) { skipDepth = max(0, skipDepth - 1); return }
            if XHTMLText.headingElements.contains(name) {
                headingDepth = max(0, headingDepth - 1)
                if heading == nil {
                    let text = headingBuffer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
                    if !text.isEmpty { heading = String(text.prefix(80)) }
                }
                headingBuffer = ""
            }
            if XHTMLText.blockElements.contains(name) { flush() }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard skipDepth == 0, inBody else { return }
            buffer += string
            if headingDepth > 0 { headingBuffer += string }
        }

        func flush() {
            let text = buffer.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
            if !text.isEmpty { paragraphs.append(text) }
            buffer = ""
        }

        private func local(_ name: String) -> String {
            (name.components(separatedBy: ":").last ?? name).lowercased()
        }
    }
}
