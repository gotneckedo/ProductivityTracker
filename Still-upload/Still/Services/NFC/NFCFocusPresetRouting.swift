import Foundation

enum NFCRoutingResult: Equatable {
    case startPreset(FocusPresetID)
    /// A well-formed link naming a preset this device doesn't have.
    case unknownPreset(FocusPresetID)
    case notAFocusLink
}

/// Turns a URL (from an NFC tag, Universal Link, Shortcut, or the in-app
/// simulator) into a preset to start.
///
/// Real tag behavior: an iPhone cannot react to an arbitrary blank tag while
/// the app is closed. A tag must be written with an NDEF URI record containing
/// the preset URL. iOS reads URL records in the background and offers to open
/// the app; with a configured associated domain, a Universal Link record opens
/// it directly. This must be verified on hardware (see README).
protocol NFCFocusPresetRouting {
    func route(_ url: URL) -> NFCRoutingResult
}

struct DeepLinkPresetRouter: NFCFocusPresetRouting {
    var parser = DeepLinkParser()
    var knownPresetIDs: Set<FocusPresetID>

    func route(_ url: URL) -> NFCRoutingResult {
        guard case .startFocus(let presetID)? = parser.parse(url) else { return .notAFocusLink }
        return knownPresetIDs.contains(presetID) ? .startPreset(presetID) : .unknownPreset(presetID)
    }
}

/// The honest setup guide shown on the Focus Card screen.
enum FocusCardGuide {
    static let summary = "A Focus Card is any writable NFC tag programmed with a Still link. Tap it with your iPhone to start a preset."

    static let steps: [String] = [
        "Get a writable NFC tag (NTAG213 or similar). A blank tag does nothing on its own.",
        "Use an NFC writing app to add a URL record with the link below.",
        "Hold the top of your iPhone near the tag. iOS shows a banner; tap it to open Still.",
        "Still starts the preset. If a session is already running, it leaves that session alone."
    ]

    static let hardwareNote = "Tag reading depends on your iPhone model and iOS settings, so test your card on your own device. The simulator below runs the same route without a tag."
}

// MARK: - CoreNFCTagReader

// V2 scaffold for in-app tag scanning and tag writing.
//
// Compiled only when the `STILL_CORENFC` Swift flag is set (Build Settings →
// Other Swift Flags → -DSTILL_CORENFC), because it also needs:
//   • the "Near Field Communication Tag Reading" capability
//     (com.apple.developer.nfc.readersession.formats = [NDEF])
//   • NFCReaderUsageDescription in Info.plist
//   • a physical iPhone (the simulator cannot scan)
//
// V1 does not need this file: tags written with a still:// URL open the app
// through the URL scheme, which `DeepLinkParser` already handles.
#if canImport(CoreNFC) && os(iOS) && STILL_CORENFC
import CoreNFC
import Foundation

final class CoreNFCTagReader: NSObject, NFCNDEFReaderSessionDelegate {
    private var session: NFCNDEFReaderSession?
    private var completion: ((URL?) -> Void)?

    static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    /// Scans one tag and returns the first URL record, if any.
    func scan(completion: @escaping (URL?) -> Void) {
        guard Self.isAvailable else {
            completion(nil)
            return
        }
        self.completion = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        session?.alertMessage = "Hold your iPhone near your Focus Card."
        session?.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let url = messages
            .flatMap(\.records)
            .compactMap { $0.wellKnownTypeURIPayload() }
            .first
        DispatchQueue.main.async { [weak self] in
            self?.completion?(url)
            self?.completion = nil
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.completion?(nil)
            self?.completion = nil
        }
    }

    // TODO(V2-writing): implement tag writing with `readerSession(_:didDetect:)`,
    // `connect(to:)`, `queryNDEFStatus`, and `writeNDEF` using
    // `NFCNDEFPayload.wellKnownTypeURIPayload(url: preset.startURL)`.
}
#endif
