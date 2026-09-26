import Foundation

/// A locally saved combination of independent ambient layers. It is intentionally
/// not a music playlist: every stored value is just a Still `AmbientMix`.
struct SavedSoundscape: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var mix: AmbientMix

    init(id: UUID = UUID(), name: String, mix: AmbientMix) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(28))
        self.mix = mix.normalized()
    }
}

/// Built-in combinations use Still's independent layers and can always be
/// adjusted. They are never copied from another product's mix or branding.
enum SoundscapeCatalog {
    static let builtIns: [SavedSoundscape] = [
        make("Rainy Study", [.rain: 0.70, .fireplace: 0.25]),
        make("Coffee Shop", [.cafe: 0.60, .rain: 0.20]),
        make("Night Train", [.train: 0.62, .rain: 0.28]),
        make("Forest Cabin", [.forest: 0.55, .fireplace: 0.25, .wind: 0.18]),
        make("Library", [.library: 0.58, .rain: 0.10]),
        make("Ocean Evening", [.waves: 0.62, .wind: 0.25]),
        make("Deep Focus", [.brownNoise: 0.48, .rain: 0.12]),
        make("Silent", [:])
    ]

    static func roomDefault(for sceneID: SceneID) -> SavedSoundscape {
        if sceneID == .libraryLight { return builtIns[4] }
        if sceneID == .trainWindow { return builtIns[2] }
        if sceneID == .nightCity { return builtIns[1] }
        if sceneID == .autumnWindow || sceneID == .snowDay { return builtIns[3] }
        return builtIns[0]
    }

    private static func make(_ name: String, _ levels: [AmbientSourceID: Double]) -> SavedSoundscape {
        var mix = AmbientMix.silent
        mix.isEnabled = !levels.isEmpty
        mix.masterVolume = 0.56
        for (source, level) in levels { mix.setLevel(level, for: source) }
        return SavedSoundscape(id: UUID(uuidString: stableID(name)) ?? UUID(), name: name, mix: mix)
    }

    /// Stable UUIDs make selection accessible and deterministic across launches.
    private static func stableID(_ name: String) -> String {
        let values = name.utf8.map { String(format: "%02X", $0) }.joined()
        let padded = (values + String(repeating: "0", count: 32)).prefix(32)
        let string = String(padded)
        return "\(string.prefix(8))-\(string.dropFirst(8).prefix(4))-4\(string.dropFirst(13).prefix(3))-8\(string.dropFirst(17).prefix(3))-\(string.dropFirst(20).prefix(12))"
    }
}
