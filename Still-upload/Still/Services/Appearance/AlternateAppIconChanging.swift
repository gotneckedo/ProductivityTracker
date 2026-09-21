import Foundation

/// Result of asking the operating system to change Still's Home Screen icon.
enum AppIconChangeOutcome: Equatable {
    case changed
    case unavailable
}

/// Platform boundary for alternate app icons. Domain and controller code never
/// import UIKit; the live adapter is the only type that calls UIApplication.
protocol AlternateAppIconChanging: AnyObject {
    var supportsAlternateIcons: Bool { get }
    var currentAlternateIconName: String? { get }

    func setAlternateIconName(
        _ name: String?,
        completion: @escaping (Result<AppIconChangeOutcome, Error>) -> Void
    )
}

/// Used by tests, previews, and platforms that do not support alternate icons.
final class UnavailableAlternateAppIconChanger: AlternateAppIconChanging {
    var supportsAlternateIcons: Bool { false }
    var currentAlternateIconName: String? { nil }

    func setAlternateIconName(
        _ name: String?,
        completion: @escaping (Result<AppIconChangeOutcome, Error>) -> Void
    ) {
        completion(.success(.unavailable))
    }
}

#if canImport(UIKit) && os(iOS)
import UIKit

/// The UIKit-bound live implementation. Asset names come only from
/// `AppAccentPalette`, so callers cannot request an undeclared icon.
final class UIKitAlternateAppIconChanger: AlternateAppIconChanging {
    private let application: UIApplication

    init(application: UIApplication = .shared) {
        self.application = application
    }

    var supportsAlternateIcons: Bool { application.supportsAlternateIcons }
    var currentAlternateIconName: String? { application.alternateIconName }

    func setAlternateIconName(
        _ name: String?,
        completion: @escaping (Result<AppIconChangeOutcome, Error>) -> Void
    ) {
        guard application.supportsAlternateIcons else {
            completion(.success(.unavailable))
            return
        }
        guard application.alternateIconName != name else {
            completion(.success(.changed))
            return
        }
        application.setAlternateIconName(name) { error in
            if let error {
                completion(.failure(error))
            } else {
                completion(.success(.changed))
            }
        }
    }
}
#endif

/// Deterministic test double for validating icon-name routing.
final class RecordingAlternateAppIconChanger: AlternateAppIconChanging {
    var supportsAlternateIcons: Bool
    var currentAlternateIconName: String?
    private(set) var requestedNames: [String?] = []
    var nextResult: Result<AppIconChangeOutcome, Error>

    init(
        supportsAlternateIcons: Bool = true,
        currentAlternateIconName: String? = nil,
        nextResult: Result<AppIconChangeOutcome, Error> = .success(.changed)
    ) {
        self.supportsAlternateIcons = supportsAlternateIcons
        self.currentAlternateIconName = currentAlternateIconName
        self.nextResult = nextResult
    }

    func setAlternateIconName(
        _ name: String?,
        completion: @escaping (Result<AppIconChangeOutcome, Error>) -> Void
    ) {
        requestedNames.append(name)
        if case .success(.changed) = nextResult {
            currentAlternateIconName = name
        }
        completion(nextResult)
    }
}
