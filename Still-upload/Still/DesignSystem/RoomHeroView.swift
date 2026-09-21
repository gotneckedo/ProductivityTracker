import SwiftUI

/// The room is Still's one hero object. It is original, code-drawn pixel art on a
/// 160×132 virtual grid so sprites can replace individual objects without changing
/// its public API. Motion is limited to lamp warmth, rain, steam, dust, and leaves.
struct RoomHeroView: View {
    let sceneName: String
    var phase: StillDayPhase? = nil
    var dimmed = false
    var plantStage: PlantGrowthStage = .full
    var bookCount: Int = 2
    var doodle: PixelDoodle? = nil
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var resolvedPhase: StillDayPhase {
        phase ?? StillDayPhase.automatic(colorScheme: colorScheme)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [resolvedPhase.roomHalo, .clear], center: .center, startRadius: 2, endRadius: 130))
                .blur(radius: 18)
                .scaleEffect(x: 1.25, y: 0.78)
                .accessibilityHidden(true)

            Group {
                if reduceMotion {
                    RoomCanvas(sceneName: sceneName, phase: resolvedPhase, time: 0, dimmed: dimmed,
                               plantStage: plantStage, bookCount: bookCount, doodle: doodle)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
                        RoomCanvas(sceneName: sceneName, phase: resolvedPhase,
                                   time: timeline.date.timeIntervalSinceReferenceDate, dimmed: dimmed,
                                   plantStage: plantStage, bookCount: bookCount, doodle: doodle)
                    }
                }
            }
            .aspectRatio(160.0 / 132.0, contentMode: .fit)
            .drawingGroup(opaque: false, colorMode: .extendedLinear)

            VStack {
                HStack(spacing: StillTheme.Spacing.xs) {
                    Text(sceneName)
                        .font(StillTypography.caption)
                        .foregroundStyle(resolvedPhase.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: StillTheme.minimumTapSize)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(resolvedPhase.glassBorder, lineWidth: StillTheme.Stroke.hairline))
                    Spacer()
                    roomButton(symbol: "chevron.left", label: "Previous room", action: onPrevious)
                    roomButton(symbol: "chevron.right", label: "Next room", action: onNext)
                }
                .padding(.horizontal, StillTheme.Spacing.s)
                .padding(.top, StillTheme.Spacing.s)
                Spacer()
                PageDots(activeName: sceneName)
                    .padding(.bottom, StillTheme.Spacing.xs)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sceneName) room. A warm, original isometric study room with a desk, window, books, and growing plant.")
    }

    @ViewBuilder
    private func roomButton(symbol: String, label: String, action: (() -> Void)?) -> some View {
        if let action {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(StillTypography.footnote.weight(.semibold))
                    .foregroundStyle(resolvedPhase.ink)
                    .frame(width: StillTheme.minimumTapSize, height: StillTheme.minimumTapSize)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(resolvedPhase.glassBorder, lineWidth: StillTheme.Stroke.hairline))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
        }
    }
}

private struct PageDots: View {
    let activeName: String

    var body: some View {
        HStack(spacing: 5) {
            ForEach(["Rainy Bedroom", "Library Light", "Train Window", "Night City"], id: \.self) { name in
                Capsule()
                    .fill(name == activeName ? Color.white.opacity(0.9) : Color.white.opacity(0.38))
                    .frame(width: name == activeName ? 16 : 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct RoomCanvas: View {
    let sceneName: String
    let phase: StillDayPhase
    let time: Double
    let dimmed: Bool
    let plantStage: PlantGrowthStage
    let bookCount: Int
    let doodle: PixelDoodle?

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 160, size.height / 132)
            let origin = CGPoint(x: ((size.width - 160 * scale) / 2).rounded(.down),
                                 y: ((size.height - 132 * scale) / 2).rounded(.down))
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: scale, y: scale)
            RoomArtwork.draw(context: &context, sceneName: sceneName, phase: phase, time: time,
                             dimmed: dimmed, plantStage: plantStage, bookCount: bookCount, doodle: doodle)
        }
    }
}

private enum RoomArtwork {
    private static let out = Color(hex: 0x4A2F33)
    private static let size = CGSize(width: 160, height: 132)

    static func draw(context: inout GraphicsContext, sceneName: String, phase: StillDayPhase, time: Double,
                     dimmed: Bool, plantStage: PlantGrowthStage, bookCount: Int, doodle: PixelDoodle?) {
        let palette = Palette(phase: phase, sceneName: sceneName)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(palette.sky))
        drawSlab(context: &context, palette: palette)
        drawWalls(context: &context, palette: palette)
        drawWindow(context: &context, palette: palette, time: time, motion: !dimmed)
        drawBed(context: &context, palette: palette)
        drawDesk(context: &context, palette: palette, time: time, motion: !dimmed, bookCount: bookCount)
        drawPlant(context: &context, palette: palette, stage: plantStage, time: time, motion: !dimmed)
        if let doodle { drawDoodle(context: &context, palette: palette, doodle: doodle) }
        if dimmed {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x121221, opacity: 0.42)))
        }
    }

    private static func drawSlab(context: inout GraphicsContext, palette: Palette) {
        polygon(&context, [iso(0, 0, 0), iso(60, 0, 0), iso(60, 60, 0), iso(0, 60, 0)], palette.floor)
        polygon(&context, [iso(0, 60, 0), iso(60, 60, 0), iso(60, 60, -8), iso(0, 60, -8)], palette.slabRight)
        polygon(&context, [iso(60, 0, 0), iso(60, 60, 0), iso(60, 60, -8), iso(60, 0, -8)], palette.slabLeft)
    }

    private static func drawWalls(context: inout GraphicsContext, palette: Palette) {
        polygon(&context, [iso(0, 0, 0), iso(60, 0, 0), iso(60, 0, 44), iso(0, 0, 44)], palette.wallLeft)
        polygon(&context, [iso(60, 0, 0), iso(60, 60, 0), iso(60, 60, 44), iso(60, 0, 44)], palette.wallRight)
        line(&context, iso(0, 0, 0), iso(60, 0, 0), out, width: 1)
        line(&context, iso(60, 0, 0), iso(60, 60, 0), out, width: 1)
        line(&context, iso(60, 0, 0), iso(60, 0, 44), out, width: 1)
    }

    private static func drawWindow(context: inout GraphicsContext, palette: Palette, time: Double, motion: Bool) {
        box(&context, x: 17, y: 0, z: 19, width: 20, depth: 1, height: 17, top: palette.windowFrame, left: palette.windowFrame, right: palette.windowFrame)
        polygon(&context, [iso(19, 0, 20), iso(35, 0, 20), iso(35, 0, 34), iso(19, 0, 34)], palette.windowSky)
        line(&context, iso(27, 0, 20), iso(27, 0, 34), palette.windowFrame, width: 1.5)
        line(&context, iso(19, 0, 27), iso(35, 0, 27), palette.windowFrame, width: 1.5)
        let rainOffset = motion ? (time * 10).truncatingRemainder(dividingBy: 18) : 0
        for index in 0..<9 {
            let x = 20 + Double((index * 5) % 14)
            let y = 21 + (Double(index * 7) + rainOffset).truncatingRemainder(dividingBy: 12)
            line(&context, iso(x, 0, y), iso(x + 1, 0, y - 3), Color.white.opacity(0.42), width: 0.7)
        }
    }

    private static func drawBed(context: inout GraphicsContext, palette: Palette) {
        box(&context, x: 5, y: 32, z: 2, width: 20, depth: 11, height: 5, top: palette.bed, left: palette.bedShade, right: palette.bedShade)
        box(&context, x: 5, y: 32, z: 7, width: 7, depth: 5, height: 1, top: palette.pillow, left: palette.pillow, right: palette.pillow)
        box(&context, x: 20, y: 37, z: 0, width: 18, depth: 13, height: 0.5, top: palette.rug, left: palette.rug, right: palette.rug)
    }

    private static func drawDesk(context: inout GraphicsContext, palette: Palette, time: Double, motion: Bool, bookCount: Int) {
        box(&context, x: 28, y: 13, z: 15, width: 22, depth: 13, height: 3, top: palette.wood, left: palette.woodShade, right: palette.woodShade)
        for (x, y) in [(30.0, 14.0), (47.0, 14.0), (30.0, 23.0), (47.0, 23.0)] {
            box(&context, x: x, y: y, z: 0, width: 2, depth: 2, height: 15, top: palette.woodShade, left: palette.woodShade, right: palette.woodShade)
        }
        let visibleBooks = min(9, max(2, bookCount))
        for index in 0..<visibleBooks {
            let x = 46.0 + Double(index % 3) * 2.0
            let z = 19.0 + Double(index / 3) * 2.0
            box(&context, x: x, y: 9, z: z, width: 1.5, depth: 4, height: 3, top: index.isMultiple(of: 2) ? palette.book : palette.bookAlt, left: palette.book, right: palette.bookAlt)
        }
        context.fill(Path(ellipseIn: CGRect(x: 105, y: 47, width: 34, height: 26)), with: .color(palette.lampGlow.opacity(motion ? 0.20 + 0.05 * sin(time * 0.8) : 0.18)))
        box(&context, x: 40, y: 16, z: 18, width: 1, depth: 1, height: 9, top: out, left: out, right: out)
        box(&context, x: 37, y: 14, z: 27, width: 7, depth: 5, height: 3, top: palette.lamp, left: palette.lamp, right: palette.lamp)
        box(&context, x: 33, y: 17, z: 19, width: 3, depth: 3, height: 2, top: palette.mug, left: palette.mug, right: palette.mug)
        if motion {
            let steam = sin(time * 1.4) * 1.5
            line(&context, iso(34, 18, 22), iso(34 + steam, 18, 26), Color.white.opacity(0.5), width: 0.7)
        }
    }

    private static func drawPlant(context: inout GraphicsContext, palette: Palette, stage: PlantGrowthStage, time: Double, motion: Bool) {
        box(&context, x: 14, y: 8, z: 14, width: 7, depth: 6, height: 4, top: palette.pot, left: palette.potShade, right: palette.potShade)
        let leafCount: Int
        switch stage { case .sprout: leafCount = 4; case .leafy: leafCount = 8; case .full: leafCount = 13 }
        let sway = motion ? sin(time * 0.7) : 0
        for index in 0..<leafCount {
            let row = Double(index / 3)
            let side = Double(index % 3 - 1)
            let x = 17 + side * (2 + row * 0.4) + sway
            let y = 11 - row * 1.2
            let z = 19 + row * 2 + Double(index % 2)
            box(&context, x: x, y: y, z: z, width: 2.5, depth: 2.0, height: 1, top: palette.leaf, left: palette.leafShade, right: palette.leafShade)
        }
    }

    private static func drawDoodle(context: inout GraphicsContext, palette: Palette, doodle: PixelDoodle) {
        box(&context, x: 52, y: 27, z: 20, width: 1, depth: 1, height: 10, top: out, left: out, right: out)
        polygon(&context, [iso(52, 0, 28), iso(58, 0, 28), iso(58, 0, 35), iso(52, 0, 35)], palette.doodle)
        for y in 0..<PixelDoodle.size {
            for x in 0..<PixelDoodle.size {
                guard let hex = DoodlePalette.hex(for: doodle.color(x: x, y: y)) else { continue }
                let boardX = 52.35 + Double(x) * 0.34
                let boardZ = 28.25 + Double(15 - y) * 0.39
                polygon(&context, [iso(boardX, 0, boardZ), iso(boardX + 0.28, 0, boardZ), iso(boardX + 0.28, 0, boardZ + 0.32), iso(boardX, 0, boardZ + 0.32)], Color(hex: hex))
            }
        }
    }

    private static func iso(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
        CGPoint(x: 80 + (x - y), y: 54 + (x + y) / 2 - z)
    }

    private static func polygon(_ context: inout GraphicsContext, _ points: [CGPoint], _ color: Color) {
        guard let first = points.first else { return }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        context.fill(path, with: .color(color))
    }

    private static func line(_ context: inout GraphicsContext, _ from: CGPoint, _ to: CGPoint, _ color: Color, width: CGFloat) {
        var path = Path()
        path.move(to: from)
        path.addLine(to: to)
        context.stroke(path, with: .color(color), lineWidth: width)
    }

    private static func box(_ context: inout GraphicsContext, x: Double, y: Double, z: Double, width: Double, depth: Double, height: Double, top: Color, left: Color, right: Color) {
        polygon(&context, [iso(x, y, z + height), iso(x + width, y, z + height), iso(x + width, y + depth, z + height), iso(x, y + depth, z + height)], top)
        polygon(&context, [iso(x, y + depth, z), iso(x + width, y + depth, z), iso(x + width, y + depth, z + height), iso(x, y + depth, z + height)], left)
        polygon(&context, [iso(x + width, y, z), iso(x + width, y + depth, z), iso(x + width, y + depth, z + height), iso(x + width, y, z + height)], right)
    }

    private struct Palette {
        let sky: Color
        let wallLeft: Color
        let wallRight: Color
        let floor: Color
        let slabLeft: Color
        let slabRight: Color
        let windowFrame: Color
        let windowSky: Color
        let bed: Color
        let bedShade: Color
        let pillow: Color
        let rug: Color
        let wood: Color
        let woodShade: Color
        let book: Color
        let bookAlt: Color
        let lamp: Color
        let lampGlow: Color
        let mug: Color
        let pot: Color
        let potShade: Color
        let leaf: Color
        let leafShade: Color
        let doodle: Color

        init(phase: StillDayPhase, sceneName: String) {
            if sceneName == "Night City" {
                sky = Color(hex: 0x171B38); wallLeft = Color(hex: 0x353354); wallRight = Color(hex: 0x484064); windowSky = Color(hex: 0x151D44)
            } else if sceneName == "Library Light" {
                sky = Color(hex: 0xF2CFA2); wallLeft = Color(hex: 0xC88E68); wallRight = Color(hex: 0xE2B58D); windowSky = Color(hex: 0xE2A66F)
            } else if sceneName == "Train Window" {
                sky = Color(hex: 0xA7B9CC); wallLeft = Color(hex: 0x738699); wallRight = Color(hex: 0x94A5B6); windowSky = Color(hex: 0x6E91B1)
            } else {
                switch phase {
                case .morning:
                    sky = Color(hex: 0xCFE9F5); wallLeft = Color(hex: 0xF4E7D8); wallRight = Color(hex: 0xFBF3E8); windowSky = Color(hex: 0xB8D9EB)
                case .afternoon:
                    sky = Color(hex: 0x9FD3EE); wallLeft = Color(hex: 0xF1E3D2); wallRight = Color(hex: 0xF9EFE2); windowSky = Color(hex: 0x87C4E0)
                case .dusk:
                    sky = Color(hex: 0xDDA8C2); wallLeft = Color(hex: 0xE6C2B2); wallRight = Color(hex: 0xF0D2C0); windowSky = Color(hex: 0xB98BB8)
                case .night, .focus:
                    sky = Color(hex: 0x25264B); wallLeft = Color(hex: 0x47415F); wallRight = Color(hex: 0x534A69); windowSky = Color(hex: 0x202A55)
                }
            }
            floor = Color(hex: phase == .night || phase == .focus ? 0x80685E : 0xE6C59C)
            slabLeft = Color(hex: phase == .night || phase == .focus ? 0x4D4051 : 0xC99C70)
            slabRight = Color(hex: phase == .night || phase == .focus ? 0x41364C : 0xB98A60)
            windowFrame = Color(hex: phase == .night || phase == .focus ? 0xCCC3D9 : 0xFFFCF6)
            bed = Color(hex: 0xB6D9C5); bedShade = Color(hex: 0x83AC9C); pillow = Color(hex: 0xF7ECE4); rug = Color(hex: 0xEAB6C3)
            wood = Color(hex: 0xB9825E); woodShade = Color(hex: 0x8D5B45)
            book = Color(hex: 0x829DC4); bookAlt = Color(hex: 0xE2B06A)
            lamp = Color(hex: 0xFFE19C); lampGlow = Color(hex: 0xFFD186); mug = Color(hex: 0xD98470)
            pot = Color(hex: 0xD58A68); potShade = Color(hex: 0xA6604F); leaf = Color(hex: 0x5F9A74); leafShade = Color(hex: 0x3E7053)
            doodle = sceneName == "Night City" ? Color(hex: 0xA8A2E8) : Color(hex: 0xA8D7C4)
        }
    }
}
