#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Loops one `AVAudioPlayer` per ambient source and mixes them by volume.
///
/// Expected files are listed in the ambient audio appendix in `ASSET_AND_CONTENT_POLICY.md`. Missing
/// files are not an error: that source simply stays silent, and the UI shows
/// a calm "ready when sound files are added" note.
final class AVAmbientAudioPlayer: AmbientAudioPlaying {
    static let fileExtensions = ["m4a", "caf", "wav", "mp3"]
    /// A calm entrance; individual layer changes share the same short fade.
    private static let fadeDuration: TimeInterval = 3.5
    private static let stopFadeDuration: TimeInterval = 6

    private var players: [AmbientSourceID: AVAudioPlayer] = [:]
    private var mix: AmbientMix = .silent
    private(set) var isPlaying = false
    let status: AmbientAudioStatus

    init(bundle: Bundle = .main) {
        var loaded: [AmbientSourceID: AVAudioPlayer] = [:]
        for source in AmbientSource.all {
            guard let url = Self.url(for: source, in: bundle),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()
            loaded[source.id] = player
        }
        players = loaded
        status = loaded.isEmpty ? .assetsMissing : .ready
    }

    static func url(for source: AmbientSource, in bundle: Bundle) -> URL? {
        for ext in fileExtensions {
            if let url = bundle.url(forResource: source.assetBaseName, withExtension: ext) {
                return url
            }
            if let url = bundle.url(forResource: source.assetBaseName, withExtension: ext, subdirectory: "AmbientAudio") {
                return url
            }
        }
        return nil
    }

    func isAssetAvailable(_ source: AmbientSourceID) -> Bool {
        players[source] != nil
    }

    func apply(_ mix: AmbientMix) {
        self.mix = mix
        guard isPlaying else { return }
        if mix.isSilent {
            pause()
            return
        }
        for (id, player) in players {
            let volume = Float(mix.effectiveVolume(for: id))
            if volume > 0, !player.isPlaying {
                player.volume = 0
                player.play()
            }
            player.setVolume(volume, fadeDuration: Self.fadeDuration)
        }
    }

    func play() {
        guard !players.isEmpty, !mix.isSilent else {
            isPlaying = false
            return
        }
        activateSession()
        for (id, player) in players {
            let volume = Float(mix.effectiveVolume(for: id))
            guard volume > 0 else {
                player.pause()
                continue
            }
            if !player.isPlaying {
                player.volume = 0
                player.play()
            }
            player.setVolume(volume, fadeDuration: Self.fadeDuration)
        }
        isPlaying = true
    }

    func pause() {
        players.values.forEach { $0.pause() }
        isPlaying = false
    }

    func stop() {
        let activePlayers = Array(players.values)
        activePlayers.forEach { $0.setVolume(0, fadeDuration: Self.stopFadeDuration) }
        isPlaying = false
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.stopFadeDuration) { [weak self] in
            guard let self, !self.isPlaying else { return }
            activePlayers.forEach { player in
                player.stop()
                player.currentTime = 0
            }
            self.deactivateSession()
        }
    }

    private func activateSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif
    }

    private func deactivateSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }
}
#endif
