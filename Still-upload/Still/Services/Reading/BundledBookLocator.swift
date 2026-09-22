import Foundation

/// Resolves the four verified public-domain EPUBs from an app or test bundle.
///
/// Xcode's synchronized resource groups are allowed to flatten a folder or
/// preserve it in the built bundle. Looking up the known filenames recursively
/// makes both layouts explicit while avoiding an accidental scan of user files.
enum BundledBookLocator {
    struct Metadata: Hashable {
        let title: String
        let author: String
        let sittingCount: Int
    }

    /// The catalog is authored from the four bundled EPUB manifests. It keeps
    /// the shelf immediate at launch; EPUB parsing remains lazy when a reader
    /// opens a specific book.
    static let catalog: [String: Metadata] = [
        "e-m-forster_short-fiction.epub": Metadata(title: "Short Fiction", author: "E. M. Forster", sittingCount: 121),
        "henry-david-thoreau_essays.epub": Metadata(title: "Essays", author: "Henry David Thoreau", sittingCount: 402),
        "robert-louis-stevenson_travel-essays.epub": Metadata(title: "Travel Essays", author: "Robert Louis Stevenson", sittingCount: 394),
        "saki_short-fiction.epub": Metadata(title: "Short Fiction", author: "Saki", sittingCount: 381)
    ]

    static let expectedFileNames: Set<String> = [
        "e-m-forster_short-fiction.epub",
        "henry-david-thoreau_essays.epub",
        "robert-louis-stevenson_travel-essays.epub",
        "saki_short-fiction.epub"
    ]

    static func urls(in bundle: Bundle) -> [URL] {
        let candidateRoots = [
            bundle.resourceURL,
            bundle.resourceURL?.appendingPathComponent("PublicDomainBooks", isDirectory: true),
            bundle.resourceURL?.appendingPathComponent("Resources/PublicDomainBooks", isDirectory: true)
        ].compactMap { $0 }

        var urls = Set<URL>()
        for root in candidateRoots where FileManager.default.fileExists(atPath: root.path) {
            if let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in enumerator where expectedFileNames.contains(url.lastPathComponent) {
                    urls.insert(url)
                }
            }
        }
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func metadata(for url: URL) -> Metadata? {
        catalog[url.lastPathComponent]
    }
}
