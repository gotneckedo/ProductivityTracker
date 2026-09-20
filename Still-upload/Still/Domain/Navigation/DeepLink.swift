import Foundation

/// External entry points: URL scheme today, Universal Links and NFC tags later.
///
/// Supported in V1:
///   still://start-focus?preset=default
///   still://start-focus?preset=study
enum DeepLink: Equatable {
    case startFocus(presetID: FocusPresetID)

    static let scheme = "still"
    static let startFocusHost = "start-focus"

    var url: URL {
        switch self {
        case .startFocus(let presetID):
            var components = URLComponents()
            components.scheme = DeepLink.scheme
            components.host = DeepLink.startFocusHost
            components.queryItems = [URLQueryItem(name: "preset", value: presetID.rawValue)]
            return components.url ?? URL(string: "still://start-focus")!
        }
    }
}

struct DeepLinkParser {
    /// Hosts accepted for future Universal Links (https://<host>/start-focus?preset=…).
    /// Empty in V1 because no associated domain is configured.
    var universalLinkHosts: Set<String> = []

    func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased() else { return nil }

        let action: String
        if scheme == DeepLink.scheme {
            // Accept still://start-focus and still:///start-focus.
            let host = components.host?.lowercased() ?? ""
            let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
            action = host.isEmpty ? path : host
        } else if scheme == "https", let host = components.host?.lowercased(), universalLinkHosts.contains(host) {
            action = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        } else {
            return nil
        }

        guard action == DeepLink.startFocusHost else { return nil }

        let rawPreset = components.queryItems?.first { $0.name.lowercased() == "preset" }?.value ?? FocusPresetID.defaultPreset.rawValue
        guard let preset = Self.sanitizedPresetID(rawPreset) else { return nil }
        return .startFocus(presetID: preset)
    }

    /// Preset IDs are short identifiers; anything else is rejected.
    static func sanitizedPresetID(_ raw: String) -> FocusPresetID? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) && $0.isASCII }) else { return nil }
        return FocusPresetID(trimmed)
    }
}
