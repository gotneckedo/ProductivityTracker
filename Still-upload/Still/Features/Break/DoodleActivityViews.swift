import SwiftUI

// MARK: - Pixel Doodle

/// A 16×16 grid, eight soft colors, and nothing to get right. The doodle
/// saves to the gallery as you draw.
struct PixelDoodleActivityView: View {
    @Environment(AppState.self) private var appState
    @State private var doodle = PixelDoodle()
    @State private var colorIndex: UInt8 = 1
    @State private var tool: Tool = .pen
    @State private var savedID: UUID?
    @State private var isConfirmingClear = false

    enum Tool: String, CaseIterable, Hashable {
        case pen
        case fill
        case eraser

        var title: String {
            switch self {
            case .pen: return "Pen"
            case .fill: return "Fill"
            case .eraser: return "Eraser"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            Text("Draw anything. It saves to your gallery in Me as you go.")
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            DoodleCanvas(doodle: doodle, showsGrid: true)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(GeometryReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in paint(at: value.location, in: proxy.size) }
                                .onEnded { _ in autosave() }
                        )
                })
                .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: StillTheme.Radius.small, style: .continuous)
                        .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Drawing grid")
                .accessibilityValue("\(doodle.paintedCount) of 256 squares painted")

            SelectionPill(options: Tool.allCases, selection: $tool, title: { $0.title })

            HStack(spacing: StillTheme.Spacing.xs) {
                ForEach(1...DoodlePalette.colors.count, id: \.self) { index in
                    let value = UInt8(index)
                    let isSelected = colorIndex == value && tool != .eraser
                    Button {
                        colorIndex = value
                        if tool == .eraser { tool = .pen }
                    } label: {
                        Circle()
                            .fill(Color(hex: DoodlePalette.colors[index - 1]))
                            .overlay(Circle().strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline))
                            .padding(isSelected ? 3 : 6)
                            .overlay(Circle().strokeBorder(isSelected ? StillTheme.textPrimary : Color.clear, lineWidth: 2))
                            .frame(width: 36, height: 36)
                            .frame(maxWidth: .infinity, minHeight: StillTheme.minimumTapSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(DoodlePalette.names[index - 1])
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }

            HStack {
                if savedID != nil {
                    Label("Saved to your gallery", systemImage: "checkmark")
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textTertiary)
                }
                Spacer()
                Button("Start over") {
                    if doodle.isBlank { return }
                    isConfirmingClear = true
                }
                .buttonStyle(QuietTextButtonStyle())
                .disabled(doodle.isBlank)
            }
        }
        .confirmationDialog("Start a new doodle?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Keep this one and start new") {
                doodle.clear()
                savedID = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This doodle stays in your gallery.")
        }
    }

    private func paint(at location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let x = Int(location.x / size.width * CGFloat(PixelDoodle.size))
        let y = Int(location.y / size.height * CGFloat(PixelDoodle.size))
        guard PixelDoodle.contains(x: x, y: y) else { return }
        switch tool {
        case .pen: doodle.paint(x: x, y: y, color: colorIndex)
        case .eraser: doodle.paint(x: x, y: y, color: 0)
        case .fill: doodle.fill(x: x, y: y, color: colorIndex)
        }
    }

    private func autosave() {
        savedID = appState.autosaveDoodle(doodle, existingID: savedID)
    }
}

/// Draws a doodle's pixels. Empty cells show the paper, with an optional
/// faint grid while drawing.
struct DoodleCanvas: View {
    let doodle: PixelDoodle
    var showsGrid: Bool = false

    var body: some View {
        Canvas { context, size in
            let cell = min(size.width, size.height) / CGFloat(PixelDoodle.size)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(StillTheme.surface))
            for y in 0..<PixelDoodle.size {
                for x in 0..<PixelDoodle.size {
                    let rect = CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell)
                    if let hex = DoodlePalette.hex(for: doodle.color(x: x, y: y)) {
                        // Slight overlap hides hairline seams between cells.
                        context.fill(Path(rect.insetBy(dx: -0.25, dy: -0.25)), with: .color(Color(hex: hex)))
                    } else if showsGrid {
                        let dot = CGRect(x: rect.midX - 1, y: rect.midY - 1, width: 2, height: 2)
                        context.fill(Path(dot), with: .color(StillTheme.border))
                    }
                }
            }
        }
    }
}

// MARK: - Gallery

/// Doodles saved from breaks. Stay on this device.
struct DoodleGalleryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewing: ActivityArtifact?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: StillTheme.Spacing.m)]

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("Doodles")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Small drawings from your breaks. They stay on this device.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                    }
                    if appState.doodles.isEmpty {
                        StillCard {
                            EmptyState(symbol: "paintbrush.pointed", title: "No doodles yet",
                                       message: "Pick Pixel Doodle on the Break tab and draw something small.")
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: StillTheme.Spacing.m) {
                            ForEach(appState.doodles) { artifact in
                                if let doodle = artifact.doodle {
                                    Button {
                                        viewing = artifact
                                    } label: {
                                        DoodleCanvas(doodle: doodle)
                                            .aspectRatio(1, contentMode: .fit)
                                            .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.small, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: StillTheme.Radius.small, style: .continuous)
                                                    .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Doodle from \(artifact.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            appState.deleteDoodle(artifact.id)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
            .stillScrollableViewport()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(item: $viewing) { artifact in
            DoodleDetailView(artifact: artifact) {
                appState.deleteDoodle(artifact.id)
                viewing = nil
            }
        }
    }
}

private struct DoodleDetailView: View {
    let artifact: ActivityArtifact
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StillScreen {
                VStack(spacing: StillTheme.Spacing.l) {
                    if let doodle = artifact.doodle {
                        DoodleCanvas(doodle: doodle)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous))
                            .accessibilityLabel("Doodle")
                    }
                    Text(artifact.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete doodle", systemImage: "trash")
                    }
                    .buttonStyle(QuietTextButtonStyle(foreground: StillTheme.attention))
                }
                .padding(StillTheme.Spacing.screen)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("Pixel Doodle") {
    ScrollView {
        PixelDoodleActivityView()
            .padding()
    }
    .environment(PreviewSupport.appState())
}
