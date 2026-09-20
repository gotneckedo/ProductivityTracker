import SwiftUI

// MARK: - Short Read

/// A few finite, cited pieces. Pick one, read it, reach "End."
struct ShortReadActivityView: View {
    let onFinished: () -> Void
    @Environment(AppState.self) private var appState
    @State private var selectedID: String?

    var body: some View {
        let library = appState.container.readingLibrary
        if let id = selectedID, let item = library.item(id: id) {
            reader(item)
        } else {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                Text("Pick one. Each is a few minutes long, and each one ends.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(library.allItems()) { item in
                    Button {
                        selectedID = item.id
                    } label: {
                        StillCard {
                            VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                                Text(item.title)
                                    .font(StillTypography.bodyEmphasis)
                                    .foregroundStyle(StillTheme.textPrimary)
                                Text("\(item.readMinutes) min read · \(item.license.displayName)")
                                    .font(StillTypography.footnote)
                                    .foregroundStyle(StillTheme.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this reading.")
                }
            }
        }
    }

    private func reader(_ item: ReadingItem) -> some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                Text(item.title)
                    .font(StillTypography.readingTitle)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("\(item.author) · \(item.readMinutes) min read")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
            }
            ForEach(Array(item.paragraphs.enumerated()), id: \.offset) { entry in
                Text(entry.element)
                    .font(StillTypography.reading)
                    .foregroundStyle(StillTheme.textPrimary)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("End.")
                .font(StillTypography.reading.italic())
                .foregroundStyle(StillTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, StillTheme.Spacing.s)
            PixelDivider()
            Text("\(item.source). \(item.licenseNote)")
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Finish reading", action: onFinished)
                .buttonStyle(QuietPrimaryButtonStyle())
            Button("Choose another") { selectedID = nil }
                .buttonStyle(QuietTextButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Text activities with autosave

/// A bounded text editor that saves to this device as you type.
struct AutosavingTextEditor: View {
    let kind: ActivityNoteKind
    let activityID: BreakActivityID
    let promptID: String?
    let placeholder: String
    var characterLimit: Int = 2_000
    var minHeight: CGFloat = 200

    @Environment(AppState.self) private var appState
    @State private var text = ""
    @State private var noteID: UUID?
    @State private var saveState: SaveState = .idle

    enum SaveState {
        case idle
        case saving
        case saved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(StillTypography.body)
                        .foregroundStyle(StillTheme.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .font(StillTypography.body)
                    .foregroundStyle(StillTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .accessibilityLabel(placeholder)
            }
            .padding(StillTheme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .fill(StillTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: StillTheme.Radius.medium, style: .continuous)
                    .strokeBorder(StillTheme.border, lineWidth: StillTheme.Stroke.hairline)
            )

            HStack {
                Text(statusText)
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.textTertiary)
                Spacer()
                Text("\(text.count)/\(characterLimit)")
                    .font(StillTypography.caption.monospacedDigit())
                    .foregroundStyle(StillTheme.textTertiary)
                    .accessibilityLabel("\(text.count) of \(characterLimit) characters")
            }
        }
        .onChange(of: text) { _, newValue in
            if newValue.count > characterLimit {
                text = String(newValue.prefix(characterLimit))
            }
            saveState = .saving
        }
        .task(id: text) {
            // Debounced autosave: leaving the activity never loses what was typed.
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            save()
        }
        .onDisappear(perform: save)
    }

    private var statusText: String {
        switch saveState {
        case .idle: return "Saves on this device as you type."
        case .saving: return "Saving…"
        case .saved: return noteID == nil ? "Nothing saved." : "Saved on this device."
        }
    }

    private func save() {
        guard saveState == .saving else { return }
        noteID = appState.autosaveNote(text: text, kind: kind, activityID: activityID, promptID: promptID, existingID: noteID)
        saveState = .saved
    }
}

struct CreativePromptActivityView: View {
    var body: some View {
        let prompt = CreativePromptLibrary.prompt(for: Date())
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            StillCard(tint: StillTheme.highlightSoft) {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                    Text(prompt.text)
                        .font(StillTypography.title3)
                        .foregroundStyle(StillTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(prompt.guidance)
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
            }
            AutosavingTextEditor(
                kind: .creativeResponse,
                activityID: .creativePrompt,
                promptID: prompt.id,
                placeholder: "Write a few lines…",
                characterLimit: 600,
                minHeight: 160
            )
            Text("Tap Done when you've written enough. It stays on this device.")
                .font(StillTypography.footnote)
                .foregroundStyle(StillTheme.textSecondary)
        }
    }
}

// MARK: - Brain Dump

struct BrainDumpActivityView: View {
    @Environment(AppState.self) private var appState
    @State private var showsEarlier = false

    var body: some View {
        let earlier = appState.recentNotes(.brainDump, limit: 3)
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            Text("Write down whatever is taking up space. Lists, worries, reminders. It stays on this device.")
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            AutosavingTextEditor(
                kind: .brainDump,
                activityID: .brainDump,
                promptID: nil,
                placeholder: "Start anywhere…",
                minHeight: 240
            )
            if !earlier.isEmpty {
                DisclosureGroup("Earlier notes", isExpanded: $showsEarlier) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        ForEach(earlier) { note in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(StillTypography.caption)
                                    .foregroundStyle(StillTheme.textTertiary)
                                Text(note.text)
                                    .font(StillTypography.footnote)
                                    .foregroundStyle(StillTheme.textSecondary)
                                    .lineLimit(4)
                            }
                        }
                    }
                    .padding(.top, StillTheme.Spacing.xs)
                }
                .font(StillTypography.callout)
                .tint(StillTheme.textSecondary)
            }
        }
    }
}

#Preview("Short read") {
    ActivityContainerView(activityID: .shortRead, context: .shelf)
        .environment(PreviewSupport.appState())
}
