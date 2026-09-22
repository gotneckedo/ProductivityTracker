import Foundation

/// Resolves the four verified public-domain EPUBs from an app or test bundle.
///
/// Xcode's synchronized resource groups are allowed to flatten a folder or
/// preserve it in the built bundle. Looking up the known filenames recursively
/// makes both layouts explicit while avoiding an accidental scan of user files.
enum BundledBookLocator {
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
}
