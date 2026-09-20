import Foundation

/// A book on the shelf, cheap to list without parsing the whole file.
struct BookSummary: Codable, Hashable, Identifiable {
    enum Origin: String, Codable, Hashable {
        /// Shipped inside the app. Must be verified public domain
        /// (see ASSET_AND_CONTENT_POLICY.md).
        case bundled
        /// Imported by the reader from their own files. Stays on this device.
        case imported
    }

    var id: String
    var title: String
    var author: String
    var origin: Origin
    var sittingCount: Int
    var fileName: String
    var addedAt: Date

    var license: ContentLicense {
        origin == .bundled ? .publicDomain : .userProvided
    }
}

/// Books for the Short Read activity. A sitting ends; the next one waits.
protocol BookLibrary: AnyObject {
    func books() -> [BookSummary]
    func sittings(bookID: String) throws -> [BookSitting]
    @discardableResult func importBook(from url: URL) throws -> BookSummary
    func removeBook(id: String) throws
}

enum BookLibraryError: Error, Equatable {
    case notFound
    case tooLarge
    case unreadable
}

/// Stores imported EPUBs in Application Support and reads bundled ones from
/// the app. Parsed books are cached in memory for the session.
final class FileBookLibrary: BookLibrary {
    static let maximumFileSize = 30 * 1024 * 1024

    private let directory: URL
    private let bundledURLs: [URL]
    private let clock: Clock
    private let fileManager: FileManager
    private var cache: [String: [BookSitting]] = [:]
    private var bundledSummaries: [BookSummary]?
    private var indexCache: [BookSummary]?

    init(directory: URL, bundledURLs: [URL], clock: Clock, fileManager: FileManager = .default) {
        self.directory = directory
        self.bundledURLs = bundledURLs
        self.clock = clock
        self.fileManager = fileManager
    }

    /// The default on-device location.
    static func defaultDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Books", isDirectory: true)
    }

    func books() -> [BookSummary] {
        loadBundled() + loadIndex().sorted { $0.addedAt > $1.addedAt }
    }

    func sittings(bookID: String) throws -> [BookSitting] {
        if let cached = cache[bookID] { return cached }
        guard let url = fileURL(for: bookID) else { throw BookLibraryError.notFound }
        let book = try EPUBParser.parse(data: try Data(contentsOf: url))
        let sittings = SittingPlanner.sittings(for: book)
        cache[bookID] = sittings
        return sittings
    }

    @discardableResult
    func importBook(from url: URL) throws -> BookSummary {
        let data = try Data(contentsOf: url)
        guard data.count <= Self.maximumFileSize else { throw BookLibraryError.tooLarge }
        let book: EPUBBook
        do {
            book = try EPUBParser.parse(data: data)
        } catch {
            throw BookLibraryError.unreadable
        }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased()
        let id = "import-\(suffix)"
        let fileName = "\(id).epub"
        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
        let sittings = SittingPlanner.sittings(for: book)
        let summary = BookSummary(id: id, title: book.title, author: book.author, origin: .imported,
                                  sittingCount: sittings.count, fileName: fileName, addedAt: clock.now)
        var index = loadIndex()
        index.append(summary)
        try saveIndex(index)
        cache[id] = sittings
        return summary
    }

    func removeBook(id: String) throws {
        var index = loadIndex()
        guard let summary = index.first(where: { $0.id == id }) else { throw BookLibraryError.notFound }
        try? fileManager.removeItem(at: directory.appendingPathComponent(summary.fileName))
        index.removeAll { $0.id == id }
        try saveIndex(index)
        cache[id] = nil
    }

    // MARK: Storage

    private var indexURL: URL { directory.appendingPathComponent("library.json") }

    private func loadIndex() -> [BookSummary] {
        if let indexCache { return indexCache }
        let loaded: [BookSummary]
        if let data = try? Data(contentsOf: indexURL) {
            loaded = (try? RecordCoding.decoder().decode([BookSummary].self, from: data)) ?? []
        } else {
            loaded = []
        }
        indexCache = loaded
        return loaded
    }

    private func saveIndex(_ index: [BookSummary]) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try RecordCoding.encoder().encode(index).write(to: indexURL, options: .atomic)
        indexCache = index
    }

    private func loadBundled() -> [BookSummary] {
        if let bundledSummaries { return bundledSummaries }
        var result: [BookSummary] = []
        for url in bundledURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let id = Self.bundledID(for: url)
            guard let data = try? Data(contentsOf: url), let book = try? EPUBParser.parse(data: data) else { continue }
            let sittings = SittingPlanner.sittings(for: book)
            cache[id] = sittings
            result.append(BookSummary(id: id, title: book.title, author: book.author, origin: .bundled,
                                      sittingCount: sittings.count, fileName: url.lastPathComponent,
                                      addedAt: .distantPast))
        }
        bundledSummaries = result
        return result
    }

    private func fileURL(for bookID: String) -> URL? {
        if let bundled = bundledURLs.first(where: { Self.bundledID(for: $0) == bookID }) {
            return bundled
        }
        guard let summary = loadIndex().first(where: { $0.id == bookID }) else { return nil }
        return directory.appendingPathComponent(summary.fileName)
    }

    static func bundledID(for url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let safe = stem.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return "bundled-" + String(safe.prefix(40))
    }
}

/// A library with nothing in it, for tests and previews.
final class EmptyBookLibrary: BookLibrary {
    func books() -> [BookSummary] { [] }
    func sittings(bookID: String) throws -> [BookSitting] { throw BookLibraryError.notFound }
    func importBook(from url: URL) throws -> BookSummary { throw BookLibraryError.unreadable }
    func removeBook(id: String) throws { throw BookLibraryError.notFound }
}

/// Book reading rules: which sitting is next, and marking one finished.
final class BookReadingController {
    private let library: BookLibrary
    private let progress: ReadingProgressRepository
    private let clock: Clock
    var onPersistenceError: ((Error) -> Void)?

    init(library: BookLibrary, progress: ReadingProgressRepository, clock: Clock) {
        self.library = library
        self.progress = progress
        self.clock = clock
    }

    func books() -> [BookSummary] {
        library.books()
    }

    func progress(for bookID: String) -> ReadingProgress {
        progress.progress(bookID: bookID)
            ?? ReadingProgress(bookID: bookID, nextSitting: 0, finishedSittings: 0, updatedAt: clock.now)
    }

    /// The next sitting to read, or nil when the book is finished.
    func nextSitting(bookID: String) -> BookSitting? {
        guard let sittings = try? library.sittings(bookID: bookID) else { return nil }
        let index = progress(for: bookID).nextSitting
        return index < sittings.count ? sittings[index] : nil
    }

    /// Moves the bookmark past this sitting.
    func finishSitting(bookID: String, index: Int) {
        var current = progress(for: bookID)
        guard index >= current.nextSitting else { return }
        current.nextSitting = index + 1
        current.finishedSittings += 1
        current.updatedAt = clock.now
        do {
            try progress.save(current)
        } catch {
            onPersistenceError?(error)
        }
    }

    /// Starts the book over from the first sitting.
    func restart(bookID: String) {
        do {
            try progress.delete(bookID: bookID)
        } catch {
            onPersistenceError?(error)
        }
    }

    @discardableResult
    func importBook(from url: URL) throws -> BookSummary {
        try library.importBook(from: url)
    }

    func removeBook(id: String) {
        do {
            try library.removeBook(id: id)
            try progress.delete(bookID: id)
        } catch {
            onPersistenceError?(error)
        }
    }

    /// A sitting shaped like the other short reads, with its provenance.
    static func readingItem(_ sitting: BookSitting, book: BookSummary) -> ReadingItem {
        ReadingItem(
            id: "\(book.id)#\(sitting.index)",
            title: sitting.displayTitle,
            author: book.author,
            source: book.title,
            paragraphs: sitting.paragraphs,
            license: book.license,
            licenseNote: book.origin == .bundled
                ? "Public-domain text bundled with Still."
                : "Imported from your files. Stays on this device.",
            format: .epub
        )
    }
}
