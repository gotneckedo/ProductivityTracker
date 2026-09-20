import Foundation

enum SpeechPermission: Equatable {
    case granted
    case denied
    case unavailable
}

/// Speech → text for quick task capture. On device where supported; audio is
/// never saved and the transcript only becomes a task if the user keeps it.
protocol SpeechTaskCapturing: AnyObject {
    var isAvailable: Bool { get }
    var isListening: Bool { get }
    func requestPermission() async -> SpeechPermission
    /// Starts listening. `onText` receives the running transcript.
    func start(onText: @escaping (String) -> Void) throws
    /// Stops listening and returns the final transcript.
    @discardableResult func stop() -> String
}

/// Scripted speech for tests and previews.
final class ScriptedSpeechCapture: SpeechTaskCapturing {
    var transcript: String
    var permission: SpeechPermission
    private(set) var isListening = false

    init(transcript: String, permission: SpeechPermission = .granted) {
        self.transcript = transcript
        self.permission = permission
    }

    var isAvailable: Bool { permission != .unavailable }

    func requestPermission() async -> SpeechPermission { permission }

    func start(onText: @escaping (String) -> Void) throws {
        isListening = true
        onText(transcript)
    }

    func stop() -> String {
        isListening = false
        return transcript
    }
}
