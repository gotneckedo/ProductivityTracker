import Foundation

extension Identifier where Tag == AmbientSourceTag {
    static let rain: AmbientSourceID = "rain"
    static let cafe: AmbientSourceID = "cafe"
    static let fireplace: AmbientSourceID = "fireplace"
    static let waves: AmbientSourceID = "waves"
}

/// A named ambient sound source and the bundle file it expects.
/// File names and licensing rules: see the ambient audio appendix in
/// ASSET_AND_CONTENT_POLICY.md.
struct AmbientSource: Hashable, Identifiable {
    let id: AmbientSourceID
    let displayName: String
    /// File name without extension. The player looks for `.m4a`, `.caf`, then `.wav`.
    let assetBaseName: String

    static let all: [AmbientSource] = [
        AmbientSource(id: .rain, displayName: "Rain", assetBaseName: "ambient_rain"),
        AmbientSource(id: .cafe, displayName: "Café", assetBaseName: "ambient_cafe"),
        AmbientSource(id: .fireplace, displayName: "Fireplace", assetBaseName: "ambient_fireplace"),
        AmbientSource(id: .waves, displayName: "Waves", assetBaseName: "ambient_waves")
    ]

    static func named(_ id: AmbientSourceID) -> AmbientSource? {
        all.first { $0.id == id }
    }
}

struct AmbientChannel: Codable, Hashable {
    var sourceID: AmbientSourceID
    /// 0...1. Zero means the source is off.
    var level: Double
}

/// Per-source levels plus a master volume. Persisted inside presets.
struct AmbientMix: Codable, Hashable {
    var channels: [AmbientChannel]
    var masterVolume: Double
    var isEnabled: Bool

    static let silent = AmbientMix(
        channels: AmbientSource.all.map { AmbientChannel(sourceID: $0.id, level: 0) },
        masterVolume: 0.42,
        isEnabled: false
    )

    static let gentleRain: AmbientMix = {
        var mix = AmbientMix.silent
        mix.isEnabled = true
        mix.setLevel(0.8, for: .rain)
        return mix
    }()

    func level(for source: AmbientSourceID) -> Double {
        channels.first { $0.sourceID == source }?.level ?? 0
    }

    mutating func setLevel(_ level: Double, for source: AmbientSourceID) {
        let clamped = min(max(level, 0), 1)
        if let index = channels.firstIndex(where: { $0.sourceID == source }) {
            channels[index].level = clamped
        } else {
            channels.append(AmbientChannel(sourceID: source, level: clamped))
        }
    }

    mutating func setMasterVolume(_ volume: Double) {
        masterVolume = min(max(volume, 0), 1)
    }

    /// Sources that will actually be audible.
    var audibleSources: [AmbientSourceID] {
        guard isEnabled, masterVolume > 0.001 else { return [] }
        return channels.filter { $0.level > 0.001 }.map(\.sourceID)
    }

    var isSilent: Bool { audibleSources.isEmpty }

    /// The effective playback volume for one source.
    func effectiveVolume(for source: AmbientSourceID) -> Double {
        guard isEnabled else { return 0 }
        return level(for: source) * masterVolume
    }

    /// Understated summary for the Focus screen, e.g. "Rain · 42%".
    var summaryLine: String {
        let names = audibleSources.compactMap { AmbientSource.named($0)?.displayName }
        guard !names.isEmpty else { return "Sound off" }
        let percent = Int((masterVolume * 100).rounded())
        let label = names.count > 2 ? "\(names[0]) + \(names.count - 1) more" : names.joined(separator: " + ")
        return "\(label) · \(percent)%"
    }
}
