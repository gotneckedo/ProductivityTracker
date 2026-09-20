import SwiftUI

/// Motion tokens. Everything is slow and small; Reduce Motion removes movement.
enum StillMotion {
    static let quick: Double = 0.2
    static let standard: Double = 0.35
    static let slow: Double = 0.6
    static let entrance: Double = 0.5

    /// An ease for state changes, or a near-instant fade under Reduce Motion.
    static func ease(_ reduceMotion: Bool, duration: Double = standard) -> Animation {
        reduceMotion ? .linear(duration: 0.12) : .easeInOut(duration: duration)
    }
}

/// A small, slow fade-and-rise on first appearance. Under Reduce Motion it
/// only fades.
struct StillEntrance: ViewModifier {
    var delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: (isVisible || reduceMotion) ? 0 : 6)
            .onAppear {
                let animation: Animation = reduceMotion
                    ? .easeOut(duration: StillMotion.quick)
                    : .easeOut(duration: StillMotion.entrance).delay(delay)
                withAnimation(animation) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func stillEntrance(delay: Double = 0) -> some View {
        modifier(StillEntrance(delay: delay))
    }
}
