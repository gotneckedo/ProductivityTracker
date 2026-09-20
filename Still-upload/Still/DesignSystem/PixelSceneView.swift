import SwiftUI

/// The boundary between session logic and visuals. A renderer draws a scene
/// definition at an intensity; it knows nothing about timers or sessions.
protocol FocusEnvironmentRendering {
    associatedtype Body: View
    @ViewBuilder func render(scene: SceneDefinition, intensity: AnimationIntensity) -> Body
}

/// Calm mode: a mostly static plant nook so the timer carries the screen.
struct CalmPlantRenderer: FocusEnvironmentRendering {
    /// V1.1 growth input. V1 always passes `.full`.
    var plantStage: PlantGrowthStage = .full

    func render(scene: SceneDefinition, intensity: AnimationIntensity) -> some View {
        CalmPlantCanvas(stage: plantStage)
    }
}

/// Scene mode: an original animated pixel loop.
struct SceneLoopRenderer: FocusEnvironmentRendering {
    func render(scene: SceneDefinition, intensity: AnimationIntensity) -> some View {
        AnimatedSceneCanvas(scene: scene, intensity: intensity)
    }
}

/// The single visual slot used by Focus, Active Focus, and the scene collection.
/// Give it a near-square frame (see `preferredAspectRatio`) so nothing is cropped.
struct PixelSceneView: View {
    static let preferredAspectRatio: CGFloat = 1.1

    let scene: SceneDefinition
    let mode: RenderMode
    let intensity: AnimationIntensity
    var plantStage: PlantGrowthStage = .full

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let resolved = intensity.resolved(reduceMotion: reduceMotion)
        Group {
            switch mode {
            case .calm:
                CalmPlantRenderer(plantStage: plantStage).render(scene: scene, intensity: resolved)
            case .scene:
                SceneLoopRenderer().render(scene: scene, intensity: resolved)
            }
        }
        // Canvas doesn't clip; the aspect-fill grid is larger than the frame.
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode == .calm ? "A small plant on a quiet shelf." : scene.accessibilityDescription)
        .accessibilityAddTraits(.isImage)
    }
}

/// Draws scene frames; TimelineView only runs when the intensity animates.
struct AnimatedSceneCanvas: View {
    let scene: SceneDefinition
    let intensity: AnimationIntensity

    var body: some View {
        if intensity.framesPerSecond > 0 {
            TimelineView(.animation(minimumInterval: 1.0 / intensity.framesPerSecond, paused: false)) { timeline in
                sceneFrame(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            sceneFrame(time: 0)
        }
    }

    private func sceneFrame(time: Double) -> some View {
        let motion: Double
        switch intensity {
        case .full: motion = 1
        case .gentle: motion = 0.6
        case .still: motion = 0
        }
        return Canvas { context, size in
            let painter = PixelPainter(context: context, size: size)
            SceneArtwork.draw(scene.rendererKind, painter: painter, palette: scene.palette, time: time, motion: motion)
        }
    }
}

struct CalmPlantCanvas: View {
    let stage: PlantGrowthStage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = colorScheme == .dark ? CalmPlantArtwork.Colors.dark : CalmPlantArtwork.Colors.light
        Canvas { context, size in
            let painter = PixelPainter(context: context, size: size)
            CalmPlantArtwork.draw(painter: painter, colors: colors, stage: stage)
        }
    }
}

extension SceneDefinition {
    /// The color the area around a scene should use so it feels continuous.
    var surroundColor: Color { Color(palette.shadow) }
}
