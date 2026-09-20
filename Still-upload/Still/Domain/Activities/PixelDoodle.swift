import Foundation

/// A 16×16 drawing made in the Pixel Doodle activity. Pixels are palette
/// indices (0 = empty) so a doodle is a few hundred bytes and redraws in any
/// appearance.
struct PixelDoodle: Codable, Hashable {
    static let size = 16
    /// Index 0 is "no paint". The rest map to `DoodlePalette.colors`.
    var pixels: [UInt8]

    init(pixels: [UInt8]? = nil) {
        let count = Self.size * Self.size
        if let pixels, pixels.count == count {
            self.pixels = pixels.map { min($0, UInt8(DoodlePalette.colors.count)) }
        } else {
            self.pixels = Array(repeating: 0, count: count)
        }
    }

    var isBlank: Bool { pixels.allSatisfy { $0 == 0 } }

    var paintedCount: Int { pixels.filter { $0 != 0 }.count }

    func color(x: Int, y: Int) -> UInt8 {
        guard Self.contains(x: x, y: y) else { return 0 }
        return pixels[y * Self.size + x]
    }

    /// Paints one cell. Returns false when nothing changed.
    @discardableResult
    mutating func paint(x: Int, y: Int, color: UInt8) -> Bool {
        guard Self.contains(x: x, y: y), color <= UInt8(DoodlePalette.colors.count) else { return false }
        let index = y * Self.size + x
        guard pixels[index] != color else { return false }
        pixels[index] = color
        return true
    }

    /// Flood-fills the region of matching color starting at a cell.
    mutating func fill(x: Int, y: Int, color: UInt8) {
        guard Self.contains(x: x, y: y) else { return }
        let target = self.color(x: x, y: y)
        guard target != color else { return }
        var stack = [(x, y)]
        while let (cx, cy) = stack.popLast() {
            guard Self.contains(x: cx, y: cy), self.color(x: cx, y: cy) == target else { continue }
            pixels[cy * Self.size + cx] = color
            stack.append(contentsOf: [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)])
        }
    }

    mutating func clear() {
        pixels = Array(repeating: 0, count: Self.size * Self.size)
    }

    static func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < size && y < size
    }
}

/// A soft, fixed palette that matches the rest of the app. RGB hex values.
enum DoodlePalette {
    static let colors: [UInt32] = [
        0x2B3140, // ink
        0x8FAF8A, // sage
        0x6F9170, // moss
        0x8FA7BF, // dusty blue
        0xECB597, // peach
        0xD39AA0, // rose
        0xE3C87E, // butter
        0xFBF1DC  // cream
    ]

    static let names = ["Ink", "Sage", "Moss", "Blue", "Peach", "Rose", "Butter", "Cream"]

    /// The hex for a stored palette index (1-based). Nil for empty cells.
    static func hex(for index: UInt8) -> UInt32? {
        guard index > 0, Int(index) <= colors.count else { return nil }
        return colors[Int(index) - 1]
    }
}

enum ActivityArtifactKind: String, Codable, Hashable {
    case doodle
}

/// Something made during a break that's worth keeping (V1.1: doodles).
/// A sibling of `ActivityNote`, which stays text-only.
struct ActivityArtifact: Codable, Identifiable, Hashable {
    var id: UUID
    var activityID: BreakActivityID
    var kind: ActivityArtifactKind
    var createdAt: Date
    var updatedAt: Date
    var doodle: PixelDoodle?
}
