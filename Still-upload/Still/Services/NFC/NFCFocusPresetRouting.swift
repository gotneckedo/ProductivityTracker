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

// MARK: - CoreNFC reading and writing

// In-app tag scanning and tag writing. Real tags already work without this:
// a tag written (by any NFC app) with a still:// link opens Still through the
// URL scheme, which `DeepLinkParser` handles.
//
// Compiled only when the `STILL_CORENFC` Swift flag is set (Build Settings →
// Other Swift Flags → -DSTILL_CORENFC), because it also needs:
//   • the "Near Field Communication Tag Reading" capability
//     (com.apple.developer.nfc.readersession.formats = [NDEF]), which needs a
//     paid developer account
//   • NFCReaderUsageDescription in Info.plist
//   • a physical iPhone (the simulator cannot scan)
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
}

enum NFCWriteResult: Equatable {
    case written
    case readOnly
    case tooSmall
    case notSupported
    case failed
    case cancelled
}

/// Writes a preset's link to a blank or rewritable NDEF tag (NTAG213 or
/// similar), so tapping it later starts that preset.
final class CoreNFCTagWriter: NSObject, NFCNDEFReaderSessionDelegate {
    private var session: NFCNDEFReaderSession?
    private var url: URL?
    private var completion: ((NFCWriteResult) -> Void)?

    static var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    func write(_ url: URL, completion: @escaping (NFCWriteResult) -> Void) {
        guard Self.isAvailable else {
            completion(.notSupported)
            return
        }
        self.url = url
        self.completion = completion
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the tag to write your Focus Card."
        session?.begin()
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Writing uses didDetect tags below.
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard tags.count == 1, let tag = tags.first else {
            session.alertMessage = "More than one tag found. Hold just one tag near your iPhone."
            session.restartPolling()
            return
        }
        session.connect(to: tag) { [weak self] error in
            guard let self else { return }
            if error != nil {
                self.finish(session, .failed, message: "Couldn't connect to the tag.")
                return
            }
            tag.queryNDEFStatus { status, capacity, error in
                guard error == nil else {
                    self.finish(session, .failed, message: "Couldn't read the tag.")
                    return
                }
                switch status {
                case .notSupported:
                    self.finish(session, .notSupported, message: "This tag can't store a link.")
                case .readOnly:
                    self.finish(session, .readOnly, message: "This tag is locked and can't be changed.")
                case .readWrite:
                    guard let url = self.url, let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
                        self.finish(session, .failed, message: "Couldn't prepare the link.")
                        return
                    }
                    let message = NFCNDEFMessage(records: [payload])
                    guard message.length <= capacity else {
                        self.finish(session, .tooSmall, message: "This tag is too small for the link.")
                        return
                    }
                    tag.writeNDEF(message) { error in
                        if error != nil {
                            self.finish(session, .failed, message: "Writing didn't finish. Try again.")
                        } else {
                            session.alertMessage = "Your Focus Card is ready."
                            session.invalidate()
                            self.complete(.written)
                        }
                    }
                @unknown default:
                    self.finish(session, .notSupported, message: "This tag isn't supported.")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        if let nfcError = error as? NFCReaderError, nfcError.code == .readerSessionInvalidationErrorUserCanceled {
            complete(.cancelled)
        } else {
            complete(.failed)
        }
    }

    private func finish(_ session: NFCNDEFReaderSession, _ result: NFCWriteResult, message: String) {
        session.invalidate(errorMessage: message)
        complete(result)
    }

    private func complete(_ result: NFCWriteResult) {
        DispatchQueue.main.async { [weak self] in
            self?.completion?(result)
            self?.completion = nil
        }
    }
}
#endif
