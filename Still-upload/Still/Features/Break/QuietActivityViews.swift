import SwiftUI
import UniformTypeIdentifiers

// MARK: - Short Read

/// A few finite, cited pieces, plus books read one sitting at a time. Pick
/// one, read it, reach "End."
struct ShortReadActivityView: View {
    let onFinished: () -> Void
    @Environment(AppState.self) private var appState
    @State private var selectedID: String?
    @State private var openBook: OpenSitting?
    @State private var isImporting = false
    @State private var removingBook: BookSummary?

    /// A book sitting being read.
    struct OpenSitting: Equatable {
        let book: BookSummary
        let sitting: BookSitting
    }

    var body: some View {
        let library = appState.container.readingLibrary
        if let open = openBook {
            ReadingItemView(
                item: BookReadingController.readingItem(open.sitting, book: open.book),
                finishTitle: "Finish this sitting",
                onFinish: {
                    appState.finishSitting(bookID: open.book.id, index: open.sitting.index)
                    onFinished()
                },
                onChooseAnother: { openBook = nil }
            )
        } else if let id = selectedID, let item = library.item(id: id) {
            ReadingItemView(item: item, finishTitle: "Finish reading", onFinish: onFinished,
                            onChooseAnother: { selectedID = nil })
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
                booksSection
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.epub]) { result in
                if case .success(let url) = result {
                    appState.importBook(from: url)
                }
            }
            .confirmationDialog("Remove this book?", isPresented: Binding(get: { removingBook != nil }, set: { if !$0 { removingBook = nil } }), titleVisibility: .visible) {
                Button("Remove \(removingBook?.title ?? "book")", role: .destructive) {
                    if let book = removingBook { appState.removeBook(book.id) }
                    removingBook = nil
                }
                Button("Cancel", role: .cancel) { removingBook = nil }
            } message: {
                Text("It's deleted from Still on this device. The original file isn't touched.")
            }
        }
    }

    private var booksSection: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            SectionHeader(title: "Books", detail: "One sitting is a few minutes. Your place is kept for next time.")
                .padding(.top, StillTheme.Spacing.m)
            ForEach(appState.books) { book in
                BookCard(
                    book: book,
                    progress: appState.readingProgress(bookID: book.id),
                    onOpen: { open(book) },
                    onRestart: { appState.restartBook(book.id) },
                    onRemove: book.origin == .imported ? { removingBook = book } : nil
                )
            }
            Button {
                isImporting = true
            } label: {
                Label("Add an EPUB from Files", systemImage: "plus")
            }
            .buttonStyle(QuietSecondaryButtonStyle())
            .accessibilityHint("Imports a DRM-free EPUB book. It stays on this device.")
            Text("Public-domain books, like those from Project Gutenberg or Standard Ebooks, work well.")
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func open(_ book: BookSummary) {
        if let sitting = appState.nextSitting(bookID: book.id) {
            openBook = OpenSitting(book: book, sitting: sitting)
        } else {
            appState.notice = StillNotice(text: "You've finished \(book.title). Long-press it to start over.")
        }
    }
}

private struct BookCard: View {
    let book: BookSummary
    let progress: ReadingProgress
    let onOpen: () -> Void
    let onRestart: () -> Void
    let onRemove: (() -> Void)?

    private var isFinished: Bool { progress.nextSitting >= book.sittingCount && book.sittingCount > 0 }

    var body: some View {
        Button(action: onOpen) {
            StillCard {
                HStack(alignment: .top, spacing: StillTheme.Spacing.s) {
                    Image(systemName: "book.closed")
                        .font(StillTypography.title3)
                        .foregroundStyle(StillTheme.textSecondary)
                        .frame(width: 32)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text(book.title)
                            .font(StillTypography.bodyEmphasis)
                            .foregroundStyle(StillTheme.textPrimary)
                            .lineLimit(2)
                        Text(book.author)
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                        Text(status)
                            .font(StillTypography.caption)
                            .foregroundStyle(StillTheme.textTertiary)
                        PixelProgressRow(progress: fraction, count: 16)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.title), by \(book.author)")
        .accessibilityValue(status)
        .accessibilityHint(isFinished ? "Finished." : "Opens the next sitting.")
        .contextMenu {
            Button(action: onRestart) {
                Label("Start from the beginning", systemImage: "arrow.counterclockwise")
            }
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove book", systemImage: "trash")
                }
            }
        }
    }

    private var fraction: Double {
        guard book.sittingCount > 0 else { return 0 }
        return Double(min(progress.nextSitting, book.sittingCount)) / Double(book.sittingCount)
    }

    private var status: String {
        if isFinished { return "Finished · \(book.license.displayName)" }
        return "Sitting \(progress.nextSitting + 1) of \(book.sittingCount) · \(book.license.displayName)"
    }
}

/// The reader shared by short reads and book sittings.
struct ReadingItemView: View {
    let item: ReadingItem
    let finishTitle: String
    let onFinish: () -> Void
    let onChooseAnother: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                Text(item.title)
                    .font(StillTypography.readingTitle)
                    .foregroundStyle(StillTheme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(item.format == .epub
                     ? "\(item.source) · \(item.author) · \(item.readMinutes) min"
                     : "\(item.author) · \(item.readMinutes) min read")
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
            Text(item.format == .epub ? item.licenseNote : "\(item.source). \(item.licenseNote)")
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button(finishTitle, action: onFinish)
                .buttonStyle(QuietPrimaryButtonStyle())
            Button("Choose another", action: onChooseAnother)
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
