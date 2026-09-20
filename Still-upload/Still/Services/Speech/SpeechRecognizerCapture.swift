#if canImport(Speech) && os(iOS)
import AVFoundation
import Foundation
import Speech

/// Speech-to-text task capture with SFSpeechRecognizer. Prefers on-device
/// recognition; audio is streamed to the recognizer and never stored.
///
/// Needs `NSSpeechRecognitionUsageDescription` and
/// `NSMicrophoneUsageDescription` in Info.plist.
final class SpeechRecognizerCapture: SpeechTaskCapturing {
    private let recognizer: SFSpeechRecognizer?
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var hasTap = false
    private(set) var isListening = false

    init(locale: Locale = .current) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    var isAvailable: Bool {
        recognizer?.isAvailable == true
    }

    func requestPermission() async -> SpeechPermission {
        guard recognizer != nil else { return .unavailable }
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speech == .authorized else { return .denied }
        let microphone: Bool = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return microphone ? .granted : .denied
    }

    func start(onText: @escaping (String) -> Void) throws {
        guard let recognizer, recognizer.isAvailable else { throw CaptureError.unavailable }
        stopEngine()
        latest = ""

        let session = AVAudioSession.sharedInstance()
        // .mixWithOthers keeps ambient sound from being cut off abruptly.
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .mixWithOthers, .defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        hasTap = true
        engine.prepare()
        try engine.start()
        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.latest = text
                    onText(text)
                }
            }
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async { self.stopEngine() }
            }
        }
    }

    @discardableResult
    func stop() -> String {
        request?.endAudio()
        stopEngine()
        return latest
    }

    private func stopEngine() {
        if engine.isRunning {
            engine.stop()
        }
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        let wasListening = isListening
        task?.cancel()
        task = nil
        request = nil
        isListening = false
        if wasListening {
            // Hand audio back to ambient playback.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }
    }

    enum CaptureError: Error {
        case unavailable
    }
}
#endif
