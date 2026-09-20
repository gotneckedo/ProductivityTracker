import Foundation
import SwiftUI

/// Draws on a 64×64 virtual pixel grid inside a Canvas, scaled to fill the
/// available space (aspect fill, centered). Integer pixel sizes and origins
/// keep edges crisp. Scenes keep important details inside the central area
/// (roughly columns 14–50, rows 9–55) so any aspect ratio reads well.
struct PixelPainter {
    static let columns: CGFloat = 64
    static let rows: CGFloat = 64

    let context: GraphicsContext
    let size: CGSize
    let pixel: CGFloat
    let origin: CGPoint

    init(context: GraphicsContext, size: CGSize) {
        self.context = context
        self.size = size
        let raw = max(size.width / Self.columns, size.height / Self.rows)
        let pixelSize = max(1, raw.rounded(.up))
        pixel = pixelSize
        origin = CGPoint(
            x: ((size.width - pixelSize * Self.columns) / 2).rounded(.down),
            y: ((size.height - pixelSize * Self.rows) / 2).rounded(.down)
        )
    }

    /// Fills the whole canvas, including any area outside the grid.
    func fillBackground(_ color: Color) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(color))
    }

    /// A rectangle in grid units. Positions are floored to whole pixels.
    func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double, _ color: Color, opacity: Double = 1) {
        guard width > 0, height > 0, opacity > 0 else { return }
        let frame = CGRect(
            x: origin.x + CGFloat(x.rounded(.down)) * pixel,
            y: origin.y + CGFloat(y.rounded(.down)) * pixel,
            width: CGFloat(width.rounded()) * pixel,
            height: CGFloat(height.rounded()) * pixel
        )
        context.fill(Path(frame), with: .color(color.opacity(opacity)))
    }

    func dot(_ x: Double, _ y: Double, _ color: Color, opacity: Double = 1) {
        rect(x, y, 1, 1, color, opacity: opacity)
    }

    /// A filled pixel disc.
    func disc(centerX: Double, centerY: Double, radius: Double, _ color: Color, opacity: Double = 1) {
        let r = Int(radius)
        for dy in -r...r {
            let half = (radius * radius - Double(dy * dy)).squareRoot().rounded(.down)
            rect(centerX - half, centerY + Double(dy), half * 2 + 1, 1, color, opacity: opacity)
        }
    }

    /// Soft pixel glow: concentric squares of falling opacity.
    func glow(centerX: Double, centerY: Double, radius: Int, _ color: Color, strength: Double) {
        guard radius > 0 else { return }
        for ring in stride(from: radius, through: 1, by: -1) {
            let fraction = 1 - Double(ring) / Double(radius + 1)
            let side = Double(ring * 2 + 1)
            rect(centerX - Double(ring), centerY - Double(ring), side, side, color, opacity: strength * fraction * 0.35)
        }
    }

    /// Horizontal bands between two colors: a pixel-art gradient.
    func bandedGradient(x: Double, y: Double, width: Double, height: Double, from top: Color, to bottom: Color, bands: Int) {
        let count = max(1, bands)
        let bandHeight = height / Double(count)
        for index in 0..<count {
            let t = count == 1 ? 0 : Double(index) / Double(count - 1)
            rect(x, y + Double(index) * bandHeight, width, bandHeight.rounded(.up), top)
            rect(x, y + Double(index) * bandHeight, width, bandHeight.rounded(.up), bottom, opacity: t)
        }
    }

    /// Deterministic pseudo-random value in 0..<1 for stable pixel details.
    static func noise(_ a: Int, _ b: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: (a &* 73_856_093) ^ (b &* 19_349_663))
        h ^= h >> 13
        h = h &* 0x5bd1_e995
        h ^= h >> 15
        return Double(h % 10_000) / 10_000
    }
}
