import Foundation

enum AmbientAudioStatus: Equatable {
    /// At least one source has a bundled file and can play.
    case ready
    /// No sound files are bundled. Controls still work and persist the mix.
    case assetsMissing
    /// The audio system could not be configured.
    case unavailable
}

/// Restrained ambient playback: no meters, no visualizers.
protocol AmbientAudioPlaying: AnyObject {
    var status: AmbientAudioStatus { get }
    var isPlaying: Bool { get }
    func isAssetAvailable(_ source: AmbientSourceID) -> Bool
    /// Applies levels immediately (with a short fade when playing).
    func apply(_ mix: AmbientMix)
    func play()
    func pause()
    func stop()
}

enum AmbientAudioCopy {
    static let assetsMissing = "Ambient audio is ready when sound files are added."
    static let unavailable = "Ambient audio isn't available right now."
    static let sourceMissing = "Sound file not added yet"
}

/// A no-op player for tests, previews, and platforms without AVFoundation.
/// It keeps state so the UI behaves exactly as with real audio.
final class SilentAmbientAudioPlayer: AmbientAudioPlaying {
    let status: AmbientAudioStatus
    private(set) var isPlaying = false
    private(set) var appliedMix: AmbientMix?
    private let availableSources: Set<AmbientSourceID>

    init(status: AmbientAudioStatus = .assetsMissing, availableSources: Set<AmbientSourceID> = []) {
        self.status = status
        self.availableSources = availableSources
    }

    func isAssetAvailable(_ source: AmbientSourceID) -> Bool {
        availableSources.contains(source)
    }

    func apply(_ mix: AmbientMix) {
        appliedMix = mix
    }

    func play() {
        isPlaying = !(appliedMix?.isSilent ?? true)
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
    }
}
