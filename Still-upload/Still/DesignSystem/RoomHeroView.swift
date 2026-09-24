import SwiftUI

/// The room is Still's one hero object. It is original, code-drawn pixel art on a
/// 160×132 virtual grid so sprites can replace individual objects without changing
/// its public API. Motion is limited to lamp warmth, rain, steam, dust, and leaves.
struct RoomHeroView: View {
    let sceneName: String
    var sceneID: SceneID = .rainyBedroom
    var phase: StillDayPhase? = nil
    var dimmed = false
    var plantStage: PlantGrowthStage = .full
    var bookCount: Int = 2
    var doodle: PixelDoodle? = nil
    var placedObjects: [RoomPlacement] = []
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var showsControls = true

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

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

            Ellipse()
                .fill(Color.black.opacity(dimmed ? 0.28 : 0.12))
                .blur(radius: 13)
                .frame(width: 190, height: 24)
                .offset(y: 52)
                .accessibilityHidden(true)

            RoomMotes(phase: resolvedPhase, dimmed: dimmed)
                .accessibilityHidden(true)

            Group {
                if reduceMotion {
                    RoomCanvas(sceneName: sceneName, sceneID: sceneID, phase: resolvedPhase, time: 0, dimmed: dimmed,
                               plantStage: plantStage, bookCount: bookCount, doodle: doodle, placedObjects: placedObjects)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
                        RoomCanvas(sceneName: sceneName, sceneID: sceneID, phase: resolvedPhase,
                                   time: timeline.date.timeIntervalSinceReferenceDate, dimmed: dimmed,
                                   plantStage: plantStage, bookCount: bookCount, doodle: doodle, placedObjects: placedObjects)
                    }
                }
            }
            .aspectRatio(160.0 / 132.0, contentMode: .fit)
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .offset(y: reduceMotion ? 0 : (isFloating ? -3 : 2))

            if showsControls {
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
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                isFloating = true
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

private struct RoomMotes: View {
    let phase: StillDayPhase
    let dimmed: Bool

    var body: some View {
        GeometryReader { proxy in
            let points: [(CGFloat, CGFloat, CGFloat)] = [(0.19, 0.44, 2), (0.76, 0.30, 1.5), (0.84, 0.64, 2), (0.28, 0.24, 1)]
            ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(phase.roomHalo.opacity(dimmed ? 0.32 : 0.62))
                    .frame(width: point.2, height: point.2)
                    .position(x: proxy.size.width * point.0, y: proxy.size.height * point.1)
            }
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
    let sceneID: SceneID
    let phase: StillDayPhase
    let time: Double
    let dimmed: Bool
    let plantStage: PlantGrowthStage
    let bookCount: Int
    let doodle: PixelDoodle?
    let placedObjects: [RoomPlacement]

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 160, size.height / 132)
            let origin = CGPoint(x: ((size.width - 160 * scale) / 2).rounded(.down),
                                 y: ((size.height - 132 * scale) / 2).rounded(.down))
            context.translateBy(x: origin.x, y: origin.y)
            context.scaleBy(x: scale, y: scale)
            RoomArtwork.draw(context: &context, sceneName: sceneName, sceneID: sceneID, phase: phase, time: time,
                             dimmed: dimmed, plantStage: plantStage, bookCount: bookCount, doodle: doodle,
                             placedObjects: placedObjects)
        }
    }
}

private enum RoomArtwork {
    private static let out = Color(hex: 0x4A2F33)
    private static let size = CGSize(width: 160, height: 132)

    static func draw(context: inout GraphicsContext, sceneName: String, sceneID: SceneID, phase: StillDayPhase, time: Double,
                     dimmed: Bool, plantStage: PlantGrowthStage, bookCount: Int, doodle: PixelDoodle?,
                     placedObjects: [RoomPlacement]) {
        let palette = Palette(phase: phase, sceneName: sceneName)
        // The room is a complete corner: two opaque wall planes and a floor.
        // All lighting is painted into those planes before furniture arrives,
        // so it reads as light in the room rather than an oval on top of it.
        drawWalls(context: &context, palette: palette)
        drawFloor(context: &context, palette: palette)
        switch sceneID {
        case .rainyBedroom, .autumnWindow, .snowDay:
            drawRainyBedroom(context: &context, palette: palette, time: time, motion: !dimmed, plantStage: plantStage, bookCount: bookCount)
        case .libraryLight, .springRain:
            drawLibraryLight(context: &context, palette: palette, time: time, motion: !dimmed, plantStage: plantStage, bookCount: bookCount)
        case .trainWindow:
            drawTrainWindow(context: &context, palette: palette, time: time, motion: !dimmed, plantStage: plantStage, bookCount: bookCount)
        case .nightCity:
            drawNightCity(context: &context, palette: palette, time: time, motion: !dimmed, plantStage: plantStage, bookCount: bookCount)
        default:
            // A future scene without a dedicated renderer remains a complete,
            // warm room rather than a blank canvas.
            drawRainyBedroom(context: &context, palette: palette, time: time, motion: !dimmed, plantStage: plantStage, bookCount: bookCount)
        }
        if let doodle { drawDoodle(context: &context, palette: palette, doodle: doodle) }
        drawPlacedObjects(context: &context, palette: palette, placements: placedObjects, time: time, motion: !dimmed)
    }

    private static func drawFloor(context: inout GraphicsContext, palette: Palette) {
        let floorPoints = [iso(0, 0, 0), iso(60, 0, 0), iso(60, 60, 0), iso(0, 60, 0)]
        let floorPath = shapePath(floorPoints)
        context.fill(floorPath, with: .color(palette.floor))
        let light = iso(40, 18, 0.1)
        context.drawLayer { layer in
            layer.clip(to: floorPath)
            layer.fill(
                Path(CGRect(x: light.x - 34, y: light.y - 25, width: 68, height: 52)),
                with: .radialGradient(
                    Gradient(colors: [palette.lampGlow.opacity(0.34), palette.lampGlow.opacity(0.10), .clear]),
                    center: light,
                    startRadius: 1,
                    endRadius: 34
                )
            )
        }
        polygon(&context, [iso(0, 60, 0), iso(60, 60, 0), iso(60, 60, -8), iso(0, 60, -8)], palette.slabRight)
        polygon(&context, [iso(60, 0, 0), iso(60, 60, 0), iso(60, 60, -8), iso(60, 0, -8)], palette.slabLeft)
    }

    private static func drawWalls(context: inout GraphicsContext, palette: Palette) {
        let backWall = shapePath([iso(0, 0, 0), iso(60, 0, 0), iso(60, 0, 44), iso(0, 0, 44)])
        let sideWall = shapePath([iso(60, 0, 0), iso(60, 60, 0), iso(60, 60, 44), iso(60, 0, 44)])
        context.fill(backWall, with: .color(palette.wallLeft))
        context.fill(sideWall, with: .color(palette.wallRight))

        // The warm pool rises behind the lamp. Clipping keeps both wall planes
        // solid and makes the falloff part of the architecture, not a screen-
        // space translucent layer.
        let light = iso(40, 0, 25)
        context.drawLayer { layer in
            layer.clip(to: backWall)
            layer.fill(
                Path(CGRect(x: light.x - 38, y: light.y - 34, width: 76, height: 68)),
                with: .radialGradient(
                    Gradient(colors: [palette.lampGlow.opacity(0.40), palette.lampGlow.opacity(0.12), .clear]),
                    center: light,
                    startRadius: 1,
                    endRadius: 38
                )
            )
        }
        line(&context, iso(0, 0, 0), iso(60, 0, 0), out, width: 1)
        line(&context, iso(60, 0, 0), iso(60, 60, 0), out, width: 1)
        line(&context, iso(60, 0, 0), iso(60, 0, 44), out, width: 1)
    }

    private static func drawRainyBedroom(context: inout GraphicsContext, palette: Palette, time: Double,
                                         motion: Bool, plantStage: PlantGrowthStage, bookCount: Int) {
        drawWindow(context: &context, palette: palette, time: time, motion: motion)
        drawBed(context: &context, palette: palette)
        drawDesk(context: &context, palette: palette, time: time, motion: motion, bookCount: bookCount)
        drawPlant(context: &context, palette: palette, stage: plantStage, time: time, motion: motion)
    }

    private static func drawLibraryLight(context: inout GraphicsContext, palette: Palette, time: Double,
                                         motion: Bool, plantStage: PlantGrowthStage, bookCount: Int) {
        // A tall, warm window and a full left-hand wall of shelves make this
        // room intentionally unlike the starter bedroom.
        box(&context, x: 42, y: 0, z: 8, width: 13, depth: 1, height: 31,
            top: palette.windowFrame, left: palette.windowFrame, right: palette.windowFrame)
        polygon(&context, [iso(44, 0, 10), iso(53, 0, 10), iso(53, 0, 36), iso(44, 0, 36)], palette.windowSky)
        line(&context, iso(48.5, 0, 10), iso(48.5, 0, 36), palette.windowFrame, width: 1)
        line(&context, iso(44, 0, 22), iso(53, 0, 22), palette.windowFrame, width: 1)
        // A quiet light shaft and drifting dust.
        for index in 0..<6 {
            let point = iso(38 - Double(index) * 2.8, 16 + Double(index) * 2, 0.4)
            context.fill(Path(ellipseIn: CGRect(x: point.x - 1, y: point.y - 1, width: 2, height: 2)),
                         with: .color(palette.lampGlow.opacity(motion ? 0.22 : 0.16)))
        }
        for shelf in 0..<4 {
            let height = 8.0 + Double(shelf) * 7
            box(&context, x: 4, y: 0, z: height, width: 29, depth: 2, height: 1.3,
                top: palette.wood, left: palette.woodShade, right: palette.woodShade)
            for book in 0..<7 {
                let x = 5.5 + Double(book) * 3.5
                let h = 3.0 + Double((book + shelf) % 3)
                box(&context, x: x, y: 0.2, z: height + 1.3, width: 2.2, depth: 1.4, height: h,
                    top: (book + shelf).isMultiple(of: 2) ? palette.book : palette.bookAlt,
                    left: palette.book, right: palette.bookAlt)
            }
        }
        box(&context, x: 31, y: 20, z: 12, width: 18, depth: 12, height: 3,
            top: palette.wood, left: palette.woodShade, right: palette.woodShade)
        box(&context, x: 36, y: 22, z: 16, width: 3, depth: 3, height: 2,
            top: palette.mug, left: palette.mug, right: palette.mug)
        drawPlant(context: &context, palette: palette, stage: plantStage, time: time, motion: motion)
        if bookCount > 4 {
            box(&context, x: 45, y: 18, z: 16, width: 5, depth: 5, height: 2,
                top: palette.bookAlt, left: palette.book, right: palette.bookAlt)
        }
    }

    private static func drawTrainWindow(context: inout GraphicsContext, palette: Palette, time: Double,
                                        motion: Bool, plantStage: PlantGrowthStage, bookCount: Int) {
        // The room becomes a carriage: a panoramic window, a table, and seat
        // backs. Hills slide past instead of rain falling down a bedroom pane.
        polygon(&context, [iso(8, 0, 15), iso(53, 0, 15), iso(53, 0, 39), iso(8, 0, 39)], palette.windowFrame)
        polygon(&context, [iso(10, 0, 17), iso(51, 0, 17), iso(51, 0, 37), iso(10, 0, 37)], palette.windowSky)
        let offset = motion ? (time * 4).truncatingRemainder(dividingBy: 18) : 0
        for hill in 0..<7 {
            let x = 11 + Double(hill) * 7 - offset
            let base = 22 + Double(hill % 3)
            polygon(&context, [iso(x, 0, base), iso(x + 8, 0, base + 7), iso(x + 15, 0, base), iso(x + 15, 0, 17), iso(x, 0, 17)],
                    hill.isMultiple(of: 2) ? palette.leafShade : palette.leaf)
        }
        line(&context, iso(30, 0, 17), iso(30, 0, 37), palette.windowFrame, width: 1)
        box(&context, x: 14, y: 22, z: 8, width: 32, depth: 13, height: 3,
            top: palette.wood, left: palette.woodShade, right: palette.woodShade)
        box(&context, x: 5, y: 39, z: 1, width: 17, depth: 13, height: 9,
            top: palette.bed, left: palette.bedShade, right: palette.bedShade)
        box(&context, x: 39, y: 39, z: 1, width: 17, depth: 13, height: 9,
            top: palette.bed, left: palette.bedShade, right: palette.bedShade)
        box(&context, x: 27, y: 26, z: 12, width: 3, depth: 3, height: 3,
            top: palette.mug, left: palette.mug, right: palette.mug)
        if motion { line(&context, iso(28, 27, 16), iso(29 + sin(time) * 1.2, 27, 20), Color.white.opacity(0.45), width: 0.7) }
        drawPlant(context: &context, palette: palette, stage: plantStage, time: time, motion: motion)
        if bookCount > 2 {
            box(&context, x: 34, y: 28, z: 12, width: 7, depth: 5, height: 1.2,
                top: palette.book, left: palette.book, right: palette.bookAlt)
        }
    }

    private static func drawNightCity(context: inout GraphicsContext, palette: Palette, time: Double,
                                      motion: Bool, plantStage: PlantGrowthStage, bookCount: Int) {
        // A desk faces a low skyline. Small windows warm and dim slowly, rather
        // than reusing the rainy-bedroom bed/window arrangement.
        polygon(&context, [iso(7, 0, 15), iso(54, 0, 15), iso(54, 0, 39), iso(7, 0, 39)], palette.windowFrame)
        polygon(&context, [iso(9, 0, 17), iso(52, 0, 17), iso(52, 0, 37), iso(9, 0, 37)], palette.windowSky)
        for building in 0..<7 {
            let x = 10 + Double(building) * 6
            let height = 7.0 + Double((building * 5) % 8)
            polygon(&context, [iso(x, 0, 17), iso(x + 5, 0, 17), iso(x + 5, 0, 17 + height), iso(x, 0, 17 + height)], palette.wallRight.opacity(0.72))
            for window in 0..<3 {
                let lit = !motion || Int(time / 5 + Double(building + window)).isMultiple(of: 3)
                if lit {
                    let point = iso(x + 1.2 + Double(window), 0, 19 + Double(window) * 2)
                    context.fill(Path(CGRect(x: point.x, y: point.y, width: 1.4, height: 1.4)), with: .color(palette.lamp))
                }
            }
        }
        box(&context, x: 21, y: 18, z: 12, width: 27, depth: 17, height: 3,
            top: palette.wood, left: palette.woodShade, right: palette.woodShade)
        box(&context, x: 29, y: 21, z: 16, width: 10, depth: 3, height: 8,
            top: palette.wallRight, left: palette.wallLeft, right: palette.wallRight)
        box(&context, x: 43, y: 22, z: 17, width: 1, depth: 1, height: 9,
            top: out, left: out, right: out)
        box(&context, x: 40, y: 20, z: 26, width: 7, depth: 5, height: 3,
            top: palette.lamp, left: palette.lamp, right: palette.lamp)
        drawPlant(context: &context, palette: palette, stage: plantStage, time: time, motion: motion)
        if bookCount > 3 {
            for index in 0..<min(4, bookCount) {
                box(&context, x: 11 + Double(index) * 3, y: 6, z: 10, width: 2, depth: 3, height: 5,
                    top: index.isMultiple(of: 2) ? palette.book : palette.bookAlt, left: palette.book, right: palette.bookAlt)
            }
        }
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

    /// Original tiny sprites selected by catalog render keys. Asset-backed replacements can
    /// be resolved before this call later without changing persistence or placement rules.
    private static func drawPlacedObjects(context: inout GraphicsContext, palette: Palette,
                                          placements: [RoomPlacement], time: Double, motion: Bool) {
        for placement in placements {
            guard let object = RoomObjectCatalog.object(placement.objectID) else { continue }
            drawObject(context: &context, key: object.renderKey, palette: palette, time: time, motion: motion)
        }
    }

    private static func drawObject(context: inout GraphicsContext, key: RoomObjectRenderKey,
                                   palette: Palette, time: Double, motion: Bool) {
        switch key {
        case .trailingPlant:
            box(&context, x: 24, y: 2, z: 20, width: 5, depth: 4, height: 3, top: palette.pot, left: palette.potShade, right: palette.potShade)
            for index in 0..<5 {
                let drop = Double(index) * 1.8
                box(&context, x: 25 + Double(index % 2) * 2, y: 2, z: 19 - drop, width: 2, depth: 1.5, height: 1,
                    top: palette.leaf, left: palette.leafShade, right: palette.leafShade)
            }
        case .deskLamp:
            box(&context, x: 37, y: 22, z: 18, width: 1, depth: 1, height: 7, top: out, left: out, right: out)
            box(&context, x: 34, y: 20, z: 24, width: 7, depth: 5, height: 3, top: palette.lamp, left: palette.lamp, right: palette.lamp)
        case .artPoster:
            polygon(&context, [iso(5, 0, 23), iso(14, 0, 23), iso(14, 0, 35), iso(5, 0, 35)], palette.bookAlt)
            polygon(&context, [iso(7, 0, 25), iso(12, 0, 25), iso(12, 0, 33), iso(7, 0, 33)], palette.doodle)
        case .recordPlayer:
            box(&context, x: 54, y: 12, z: 11, width: 5, depth: 8, height: 4, top: palette.wood, left: palette.woodShade, right: palette.woodShade)
            context.stroke(Path(ellipseIn: CGRect(x: 118, y: 55, width: 9, height: 6)), with: .color(out), lineWidth: 1)
        case .wovenRug:
            polygon(&context, [iso(27, 37, 0.6), iso(47, 37, 0.6), iso(47, 52, 0.6), iso(27, 52, 0.6)], palette.book)
            for stripe in 0..<4 { line(&context, iso(30 + Double(stripe * 5), 38, 0.8), iso(30 + Double(stripe * 5), 50, 0.8), palette.highlight, width: 0.7) }
        case .catBed:
            context.fill(Path(ellipseIn: CGRect(x: 54, y: 90, width: 26, height: 12)), with: .color(palette.rug))
            context.stroke(Path(ellipseIn: CGRect(x: 54, y: 90, width: 26, height: 12)), with: .color(out), lineWidth: 1)
            context.stroke(Path(ellipseIn: CGRect(x: 59, y: 93, width: 16, height: 6)), with: .color(palette.pillow), lineWidth: 2)
        case .stringLights:
            line(&context, iso(6, 0, 39), iso(51, 0, 39), palette.woodShade, width: 0.7)
            for index in 0..<7 {
                let point = iso(8 + Double(index) * 7, 0, 38.5 - Double(index % 2))
                context.fill(Path(ellipseIn: CGRect(x: point.x - 1.2, y: point.y - 1.2, width: 2.4, height: 2.4)), with: .color(palette.lamp.opacity(motion ? 0.75 + 0.2 * sin(time + Double(index)) : 0.85)))
            }
        case .globe:
            let center = iso(55, 10, 18)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(palette.book))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(out), lineWidth: 1)
            line(&context, CGPoint(x: center.x, y: center.y + 4), CGPoint(x: center.x, y: center.y + 8), out, width: 1)
        case .bookends:
            box(&context, x: 53, y: 11, z: 10, width: 1, depth: 6, height: 7, top: palette.bookAlt, left: palette.bookAlt, right: palette.bookAlt)
            box(&context, x: 58, y: 11, z: 10, width: 1, depth: 6, height: 7, top: palette.bookAlt, left: palette.bookAlt, right: palette.bookAlt)
        case .bookStack:
            for index in 0..<3 { box(&context, x: 29, y: 14, z: 18 + Double(index) * 1.5, width: 7, depth: 5, height: 1.2, top: index.isMultiple(of: 2) ? palette.book : palette.bookAlt, left: palette.book, right: palette.bookAlt) }
        case .pencilCup:
            box(&context, x: 31, y: 22, z: 18, width: 3, depth: 3, height: 4, top: palette.mug, left: palette.mug, right: palette.potShade)
            for index in 0..<3 { line(&context, iso(31.7 + Double(index) * 0.7, 23, 22), iso(31.7 + Double(index) * 0.7, 23, 27 + Double(index % 2)), index == 1 ? palette.book : palette.bookAlt, width: 0.8) }
        case .tinyClock:
            let center = iso(55, 12, 19)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(palette.pillow))
            context.stroke(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(out), lineWidth: 1)
            line(&context, center, CGPoint(x: center.x, y: center.y - 2), out, width: 0.7)
        case .ceramicBird:
            let center = iso(39, 22, 20)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 2, width: 6, height: 4)), with: .color(palette.doodle))
            polygon(&context, [CGPoint(x: center.x + 2, y: center.y), CGPoint(x: center.x + 5, y: center.y + 1), CGPoint(x: center.x + 2, y: center.y + 2)], palette.bookAlt)
        case .paperStars:
            for index in 0..<5 {
                let p = iso(36 + Double(index) * 4, 0, 29 + Double(index % 2) * 4)
                polygon(&context, [CGPoint(x: p.x, y: p.y - 2), CGPoint(x: p.x + 1, y: p.y), CGPoint(x: p.x, y: p.y + 2), CGPoint(x: p.x - 1, y: p.y)], palette.lamp)
            }
        case .wateringCan:
            box(&context, x: 31, y: 2, z: 19, width: 5, depth: 4, height: 4, top: palette.book, left: palette.book, right: palette.bookAlt)
            line(&context, iso(36, 3, 21), iso(40, 2, 24), palette.book, width: 2)
        case .floorCushion:
            context.fill(Path(ellipseIn: CGRect(x: 91, y: 93, width: 23, height: 11)), with: .color(palette.bookAlt))
            context.stroke(Path(ellipseIn: CGRect(x: 91, y: 93, width: 23, height: 11)), with: .color(out), lineWidth: 1)
        case .pinboard:
            polygon(&context, [iso(39, 0, 23), iso(49, 0, 23), iso(49, 0, 35), iso(39, 0, 35)], palette.wood)
            for index in 0..<3 {
                let x = 40.5 + Double(index) * 2.7
                polygon(&context, [iso(x, 0, 25), iso(x + 2, 0, 25), iso(x + 2, 0, 29), iso(x, 0, 29)], index == 1 ? palette.doodle : palette.pillow)
            }
        case .radio:
            box(&context, x: 53, y: 11, z: 10, width: 6, depth: 6, height: 5, top: palette.wood, left: palette.woodShade, right: palette.woodShade)
            let p = iso(58.5, 12, 13)
            context.stroke(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(palette.pillow), lineWidth: 1)
        case .candle:
            box(&context, x: 43, y: 23, z: 18, width: 2, depth: 2, height: 4, top: palette.pillow, left: palette.pillow, right: palette.pillow)
            let flame = iso(44, 24, 24)
            context.fill(Path(ellipseIn: CGRect(x: flame.x - 1, y: flame.y - 2, width: 2, height: 3)), with: .color(palette.lamp.opacity(motion ? 0.7 + 0.25 * sin(time * 2) : 0.85)))
        case .telescope:
            line(&context, iso(24, 4, 23), iso(34, 2, 29), out, width: 2.4)
            line(&context, iso(29, 3, 25), iso(26, 5, 18), palette.woodShade, width: 1)
            line(&context, iso(29, 3, 25), iso(33, 6, 18), palette.woodShade, width: 1)
        }
    }

    private static func iso(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
        CGPoint(x: 80 + (x - y), y: 54 + (x + y) / 2 - z)
    }

    private static func shapePath(_ points: [CGPoint]) -> Path {
        guard let first = points.first else { return Path() }
        var path = Path()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private static func polygon(_ context: inout GraphicsContext, _ points: [CGPoint], _ color: Color) {
        let path = shapePath(points)
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
        let highlight: Color

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
            highlight = Color(hex: phase == .night || phase == .focus ? 0xD8D1F2 : 0xFFF7EA)
        }
    }
}
