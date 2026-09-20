import Foundation
import SwiftUI

/// Original pixel scenes drawn with code. Each function draws one frame.
///
/// `time` drives the loops (seconds); `motion` scales speed (0 = still frame).
/// Motion is deliberately small: rain, a lamp's glow, dust, passing hills,
/// windows lighting up. Nothing bounces or flashes.
enum SceneArtwork {
    struct Colors {
        let shadow: Color
        let base: Color
        let surface: Color
        let warm: Color
        let accent: Color
        let accentAlt: Color
        let highlight: Color

        init(_ palette: ScenePalette) {
            shadow = Color(palette.shadow)
            base = Color(palette.base)
            surface = Color(palette.surface)
            warm = Color(palette.warmLight)
            accent = Color(palette.accent)
            accentAlt = Color(palette.accentAlt)
            highlight = Color(palette.highlight)
        }
    }

    static func draw(_ kind: SceneRendererKind, painter: PixelPainter, palette: ScenePalette, time: Double, motion: Double) {
        let colors = Colors(palette)
        switch kind {
        case .rainyBedroom: rainyBedroom(painter, colors, time, motion)
        case .libraryLight: libraryLight(painter, colors, time, motion)
        case .trainWindow: trainWindow(painter, colors, time, motion)
        case .nightCity: nightCity(painter, colors, time, motion)
        }
    }

    // MARK: Rainy Bedroom

    private static func rainyBedroom(_ p: PixelPainter, _ c: Colors, _ time: Double, _ motion: Double) {
        p.fillBackground(c.base)
        p.rect(0, 0, 64, 8, c.shadow, opacity: 0.35)

        // Floor and rug.
        p.rect(0, 52, 64, 12, c.shadow)
        p.rect(0, 52, 64, 1, c.surface, opacity: 0.6)
        p.rect(18, 56, 28, 3, c.accentAlt, opacity: 0.3)

        // Window with night sky and far-off lights.
        p.rect(17, 9, 30, 32, c.surface)
        p.bandedGradient(x: 19, y: 11, width: 26, height: 28, from: c.shadow, to: c.base, bands: 4)
        for index in 0..<9 {
            let y = 34 + (PixelPainter.noise(index, 3) * 3).rounded(.down)
            p.dot(20 + Double(index * 3), y, c.warm, opacity: 0.35)
        }

        // Rain running down the glass.
        for index in 0..<22 {
            let x = 19 + Double((index * 7) % 26)
            let speed = (9 + Double(index % 4) * 3) * motion
            let y = 11 + (time * speed + Double(index) * 9.3).truncatingRemainder(dividingBy: 27)
            if y <= 36 {
                p.rect(x, y, 1, 2, c.highlight, opacity: 0.55)
            }
        }

        // Mullions and sill.
        p.rect(31, 11, 2, 28, c.surface)
        p.rect(19, 24, 26, 1, c.surface)
        p.rect(15, 40, 34, 2, c.surface)
        p.rect(15, 42, 34, 1, c.shadow, opacity: 0.5)

        // Plant on the sill; the top leaves sway very slightly.
        p.rect(20, 36, 7, 1, c.accentAlt)
        p.rect(21, 37, 5, 3, c.accentAlt)
        p.rect(21, 37, 5, 1, c.shadow, opacity: 0.25)
        let sway = (sin(time * 0.6) * motion).rounded()
        let lowLeaves: [(Double, Double)] = [(23, 35), (22, 34), (24, 34), (21, 33), (25, 33), (23, 34)]
        let highLeaves: [(Double, Double)] = [(20, 32), (26, 32), (23, 32), (22, 31), (24, 30), (23, 29)]
        for (x, y) in lowLeaves { p.dot(x, y, c.accent) }
        for (x, y) in highLeaves { p.dot(x + sway, y, c.accent) }

        // Desk, books, and a lamp with a slow warm glow.
        let glowStrength = 0.85 + 0.15 * sin(time * 0.7) * motion
        p.glow(centerX: 55, centerY: 38, radius: 10, c.warm, strength: glowStrength)
        p.rect(40, 46, 22, 2, c.surface)
        p.rect(42, 48, 2, 4, c.surface)
        p.rect(58, 48, 2, 4, c.surface)
        p.rect(46, 45, 16, 1, c.warm, opacity: 0.25)
        p.rect(43, 43, 7, 2, c.accentAlt, opacity: 0.9)
        p.rect(44, 41, 5, 2, c.accent)
        p.rect(53, 45, 5, 1, c.shadow)
        p.rect(55, 38, 1, 7, c.shadow)
        p.rect(53, 34, 5, 1, c.warm)
        p.rect(52, 35, 7, 3, c.warm)

        // Bed.
        p.rect(3, 40, 3, 13, c.surface)
        p.rect(6, 44, 21, 3, c.highlight, opacity: 0.55)
        p.rect(7, 42, 7, 3, c.highlight, opacity: 0.8)
        p.rect(6, 46, 21, 6, c.accentAlt, opacity: 0.85)
        p.rect(6, 46, 21, 1, c.highlight, opacity: 0.3)
        p.rect(25, 52, 2, 2, c.surface)
    }

    // MARK: Library Light

    private static func libraryLight(_ p: PixelPainter, _ c: Colors, _ time: Double, _ motion: Double) {
        p.fillBackground(c.base)
        p.rect(0, 56, 64, 8, c.shadow)
        p.rect(0, 56, 64, 1, c.surface, opacity: 0.5)

        // Tall arched window.
        p.rect(41, 5, 16, 41, c.surface)
        p.bandedGradient(x: 43, y: 7, width: 12, height: 37, from: c.highlight, to: c.warm, bands: 5)
        p.rect(48, 7, 2, 37, c.surface)
        p.rect(43, 20, 12, 1, c.surface)
        p.rect(43, 32, 12, 1, c.surface)
        p.rect(41, 5, 2, 2, c.base)
        p.rect(55, 5, 2, 2, c.base)

        // Light shaft falling across the room.
        for row in 20..<56 {
            let x = 42 - Double(row - 20) * 0.55
            p.rect(x, Double(row), 12, 1, c.warm, opacity: 0.10)
        }

        // Bookcase with deterministic spines.
        p.rect(3, 6, 34, 50, c.surface)
        p.rect(5, 8, 30, 46, c.shadow, opacity: 0.55)
        let spineColors = [c.accent, c.accentAlt, c.warm, c.highlight, c.surface]
        let compartments: [(top: Double, floor: Double)] = [(8, 17), (19, 28), (30, 39), (41, 50)]
        for (shelf, compartment) in compartments.enumerated() {
            var x = 5.0
            var book = 0
            while x < 34 {
                let width = 1 + (PixelPainter.noise(shelf * 17 + book, 7) * 2).rounded(.down)
                let height = 5 + (PixelPainter.noise(shelf, book * 3 + 1) * 4).rounded(.down)
                let colorIndex = Int(PixelPainter.noise(book + 11, shelf + 5) * Double(spineColors.count)) % spineColors.count
                if PixelPainter.noise(shelf + 3, book + 9) > 0.12 {
                    p.rect(x, compartment.floor - height, width, height, spineColors[colorIndex], opacity: 0.9)
                }
                x += width + (PixelPainter.noise(book, shelf + 20) > 0.8 ? 1 : 0)
                book += 1
            }
            p.rect(3, compartment.floor, 34, 2, c.surface)
        }

        // Small side table with a candle-warm lamp.
        p.glow(centerX: 52, centerY: 47, radius: 6, c.warm, strength: 0.7 + 0.2 * sin(time * 0.5) * motion)
        p.rect(44, 51, 14, 2, c.accentAlt, opacity: 0.85)
        p.rect(45, 53, 1, 3, c.accentAlt, opacity: 0.85)
        p.rect(56, 53, 1, 3, c.accentAlt, opacity: 0.85)
        p.rect(51, 47, 3, 4, c.warm)
        p.rect(46, 49, 4, 2, c.highlight, opacity: 0.8)

        // Dust drifting in the light.
        for index in 0..<12 {
            let baseY = 24 + PixelPainter.noise(index, 2) * 30
            let y = 24 + (baseY - 24 + time * 0.8 * motion + Double(index) * 2).truncatingRemainder(dividingBy: 30)
            let shaftX = 42 - (y - 20) * 0.55
            let x = shaftX + 1 + PixelPainter.noise(index, 1) * 10 + sin(time * 0.3 + Double(index)) * motion
            let twinkle = 0.45 + 0.25 * sin(time * 0.8 + Double(index)) * motion
            p.dot(x, y, c.highlight, opacity: twinkle)
        }
    }

    // MARK: Train Window

    private static func trainWindow(_ p: PixelPainter, _ c: Colors, _ time: Double, _ motion: Double) {
        p.fillBackground(c.accentAlt)
        p.rect(0, 0, 64, 5, c.shadow, opacity: 0.35)

        let left = 8.0
        let right = 56.0
        let top = 9.0
        let horizon = 45.0

        // Sky and sun.
        p.bandedGradient(x: left, y: top, width: right - left, height: horizon - top, from: c.surface, to: c.base, bands: 6)
        p.glow(centerX: 42, centerY: 26, radius: 6, c.highlight, strength: 0.6)
        p.disc(centerX: 42, centerY: 26, radius: 4, c.warm)

        // Three layers of hills sliding past at different speeds.
        let far = time * 0.6 * motion
        let mid = time * 2.0 * motion
        let near = time * 9.0 * motion
        for column in Int(left)..<Int(right) {
            let x = Double(column)
            let farTop = (31 + 2.5 * sin((x + far) / 5) + 1.5 * sin((x + far) / 2.3)).rounded()
            p.rect(x, farTop, 1, horizon - farTop, c.surface)
            p.rect(x, farTop, 1, horizon - farTop, c.shadow, opacity: 0.2)
            let midTop = (37 + 2 * sin((x + mid) / 4)).rounded()
            p.rect(x, midTop, 1, horizon - midTop, c.accent)
        }
        p.rect(left, 42, right - left, 3, c.accent)
        p.rect(left, 42, right - left, 3, c.shadow, opacity: 0.35)

        // Telephone poles passing close by.
        let spacing = 30.0
        for index in 0..<3 {
            let raw = (Double(index) * spacing - near).truncatingRemainder(dividingBy: spacing * 2)
            let x = left + (raw < 0 ? raw + spacing * 2 : raw)
            if x >= left && x < right {
                p.rect(x, 28, 1, horizon - 28, c.shadow, opacity: 0.75)
                p.rect(x - 1, 29, 3, 1, c.shadow, opacity: 0.75)
            }
        }

        // Rounded window frame.
        p.rect(left - 2, top - 2, right - left + 4, 2, c.shadow, opacity: 0.35)
        p.dot(left, top, c.accentAlt)
        p.dot(right - 1, top, c.accentAlt)
        p.dot(left, horizon - 1, c.accentAlt)
        p.dot(right - 1, horizon - 1, c.accentAlt)

        // Table with a cup and a book.
        p.rect(4, 46, 56, 2, c.surface)
        p.rect(4, 48, 56, 1, c.shadow, opacity: 0.5)
        p.rect(14, 42, 4, 4, c.highlight)
        p.rect(18, 43, 1, 2, c.highlight)
        p.rect(15, 42, 2, 1, c.accentAlt, opacity: 0.5)
        p.rect(24, 44, 9, 2, c.base)
        p.rect(24, 44, 9, 1, c.highlight, opacity: 0.4)

        // Seat backs.
        p.rect(0, 52, 64, 12, c.shadow)
        p.rect(0, 52, 64, 1, c.surface, opacity: 0.3)
    }

    // MARK: Night City

    private static func nightCity(_ p: PixelPainter, _ c: Colors, _ time: Double, _ motion: Double) {
        p.bandedGradient(x: 0, y: 0, width: 64, height: 54, from: c.shadow, to: c.base, bands: 6)

        for index in 0..<14 {
            let x = (PixelPainter.noise(index, 41) * 62).rounded(.down)
            let y = 2 + (PixelPainter.noise(index, 42) * 18).rounded(.down)
            let twinkle = 0.4 + 0.2 * sin(time * 0.5 + Double(index) * 1.7) * motion
            p.dot(x, y, c.highlight, opacity: twinkle)
        }
        p.glow(centerX: 47, centerY: 11, radius: 7, c.highlight, strength: 0.5)
        p.disc(centerX: 47, centerY: 11, radius: 3.5, c.highlight)

        // Buildings with windows that slowly light and dim.
        var x = 0.0
        var building = 0
        while x < 64 {
            let width = 5 + (PixelPainter.noise(building, 51) * 5).rounded(.down)
            let top = 22 + (PixelPainter.noise(building, 52) * 18).rounded(.down)
            p.rect(x, top, width, 54 - top, c.surface)
            if building % 2 == 1 {
                p.rect(x, top, width, 54 - top, c.shadow, opacity: 0.3)
            }
            var row = top + 2
            var rowIndex = 0
            while row < 52 {
                var column = x + 1
                var columnIndex = 0
                while column < x + width - 1 {
                    let offset = PixelPainter.noise(building * 7 + columnIndex, rowIndex) * 20
                    let epoch = Int(((time * motion) + offset) / 9)
                    let lit = PixelPainter.noise(building * 31 + columnIndex, rowIndex * 13 + epoch) > 0.64
                    p.dot(column, row, lit ? c.warm : c.shadow, opacity: lit ? 0.9 : 0.35)
                    column += 2
                    columnIndex += 1
                }
                row += 3
                rowIndex += 1
            }
            x += width
            building += 1
        }

        // The sill we are looking out from, with a plant silhouette.
        p.rect(0, 54, 64, 10, c.shadow)
        p.rect(0, 54, 64, 1, c.accent, opacity: 0.25)
        p.rect(9, 50, 6, 4, c.shadow)
        let leaves: [(Double, Double)] = [(12, 49), (11, 48), (13, 47), (10, 46), (14, 46), (12, 45), (11, 44), (13, 43)]
        for (lx, ly) in leaves { p.dot(lx, ly, c.shadow) }
    }
}

/// The calm renderer's quiet plant nook. Static by design so the timer leads.
enum CalmPlantArtwork {
    struct Colors {
        let wall: Color
        let wallShade: Color
        let shelf: Color
        let shelfShadow: Color
        let window: Color
        let windowFrame: Color
        let pot: Color
        let potShade: Color
        let soil: Color
        let leaf: Color
        let leafDark: Color
        let leafLight: Color
        let book: Color
        let bookAlt: Color

        static let light = Colors(
            wall: Color(hex: 0xF3EBDD), wallShade: Color(hex: 0xEADFCC), shelf: Color(hex: 0xD9C7AE),
            shelfShadow: Color(hex: 0xC4B094), window: Color(hex: 0xE4EBF0), windowFrame: Color(hex: 0xDCCFBC),
            pot: Color(hex: 0xE2A889), potShade: Color(hex: 0xC98E72), soil: Color(hex: 0x8A6F5A),
            leaf: Color(hex: 0x8FAF8A), leafDark: Color(hex: 0x6F9170), leafLight: Color(hex: 0xB5CDAE),
            book: Color(hex: 0x9FB4C7), bookAlt: Color(hex: 0xE3C87E)
        )

        static let dark = Colors(
            wall: Color(hex: 0x232837), wallShade: Color(hex: 0x1E2230), shelf: Color(hex: 0x3A3F52),
            shelfShadow: Color(hex: 0x2C3040), window: Color(hex: 0x2B3448), windowFrame: Color(hex: 0x363C50),
            pot: Color(hex: 0xC98E72), potShade: Color(hex: 0xA9765F), soil: Color(hex: 0x5E4D40),
            leaf: Color(hex: 0x8FAF8A), leafDark: Color(hex: 0x6A8A6B), leafLight: Color(hex: 0xA9C4A3),
            book: Color(hex: 0x7F95AB), bookAlt: Color(hex: 0xBFA86C)
        )
    }

    static func draw(painter p: PixelPainter, colors c: Colors, stage: PlantGrowthStage) {
        p.fillBackground(c.wall)
        p.rect(0, 46, 64, 18, c.wallShade)

        // A soft window.
        p.rect(39, 9, 15, 17, c.windowFrame)
        p.rect(40, 10, 13, 15, c.window)
        p.rect(46, 10, 1, 15, c.windowFrame)
        p.rect(40, 17, 13, 1, c.windowFrame)

        // Shelf.
        p.rect(10, 44, 44, 2, c.shelf)
        p.rect(10, 46, 44, 1, c.shelfShadow)

        // Books and a cup.
        p.rect(14, 38, 2, 6, c.book)
        p.rect(16, 39, 2, 5, c.bookAlt)
        p.rect(18, 40, 5, 4, c.pot, opacity: 0.55)
        p.rect(43, 40, 4, 4, c.windowFrame)
        p.rect(47, 41, 1, 2, c.windowFrame)

        // Pot.
        p.rect(26, 35, 12, 2, c.pot)
        p.rect(27, 37, 10, 5, c.pot)
        p.rect(28, 42, 8, 2, c.potShade)
        p.rect(27, 35, 10, 1, c.soil)

        // Plant. It grows with completed sessions: sprout, leafy, full.
        let stem: [(Double, Double)] = stage == .sprout
            ? [(32, 34), (32, 33), (32, 32)]
            : [(32, 34), (32, 33), (32, 32), (32, 31), (32, 30)]
        let sproutLeaves: [(Double, Double, Int)] = stage == .sprout
            ? [(31, 31, 0), (33, 31, 0), (30, 30, 1), (34, 30, 2)]
            : [(31, 29, 0), (33, 29, 0), (30, 28, 1), (34, 28, 1)]
        let leafy: [(Double, Double, Int)] = [(29, 31, 0), (35, 31, 0), (28, 30, 1), (36, 30, 1), (30, 27, 2), (34, 27, 2), (32, 27, 0)]
        let full: [(Double, Double, Int)] = [
            (27, 29, 1), (37, 29, 1), (26, 28, 0), (38, 28, 0), (29, 25, 2), (35, 25, 2),
            (31, 24, 0), (33, 24, 1), (32, 23, 2), (28, 26, 0), (36, 26, 0), (30, 22, 1), (34, 22, 1)
        ]
        for (x, y) in stem { p.dot(x, y, c.leafDark) }
        var leaves = sproutLeaves
        if stage.rawValue >= PlantGrowthStage.leafy.rawValue { leaves += leafy }
        if stage == .full { leaves += full }
        let tones = [c.leaf, c.leafDark, c.leafLight]
        for (x, y, tone) in leaves {
            p.rect(x, y, 1, 1, tones[tone % tones.count])
        }
        if stage == .full {
            p.rect(30, 30, 1, 1, c.leafDark)
            p.rect(34, 30, 1, 1, c.leafDark)
        }
    }
}
