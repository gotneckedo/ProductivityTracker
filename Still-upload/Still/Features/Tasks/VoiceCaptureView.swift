import SwiftUI

/// Say a task, check it, add it. Audio isn't stored; nothing is saved until
/// you tap Add.
struct VoiceCaptureView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var transcript = ""
    @State private var phase: Phase = .idle
    @State private var draft: CapturedTaskDraft?

    enum Phase: Equatable {
        case idle
        case listening
        case review
        case denied
        case failed
    }

    var body: some View {
        NavigationStack {
            StillScreen {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    Text(prompt)
                        .font(StillTypography.callout)
                        .foregroundStyle(StillTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    StillCard {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                            if phase == .review, let draft {
                                Text(draft.title)
                                    .font(StillTypography.bodyEmphasis)
                                    .foregroundStyle(StillTheme.textPrimary)
                                if let due = draft.dueAt {
                                    Text(DueDateDescriber(calendar: appState.container.calendar)
                                        .describe(due, now: appState.container.clock.now))
                                        .font(StillTypography.footnote)
                                        .foregroundStyle(StillTheme.textSecondary)
                                }
                            } else {
                                Text(transcript.isEmpty ? "…" : transcript)
                                    .font(StillTypography.body)
                                    .foregroundStyle(transcript.isEmpty ? StillTheme.textTertiary : StillTheme.textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Spacer()

                    switch phase {
                    case .listening:
                        Button("Stop", action: stop)
                            .buttonStyle(QuietPrimaryButtonStyle())
                    case .review:
                        Button("Add task") {
                            if let draft { appState.createTask(from: draft, source: .voice) }
                            dismiss()
                        }
                        .buttonStyle(QuietPrimaryButtonStyle())
                        .disabled(draft == nil)
                        Button("Try again", action: listen)
                            .buttonStyle(QuietTextButtonStyle())
                            .frame(maxWidth: .infinity)
                    case .idle, .failed:
                        Button("Start listening", action: listen)
                            .buttonStyle(QuietPrimaryButtonStyle())
                    case .denied:
                        Button("Close") { dismiss() }
                            .buttonStyle(QuietSecondaryButtonStyle())
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
            .navigationTitle("Say a task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        appState.container.speech?.stop()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear(perform: listen)
        .onDisappear { appState.container.speech?.stop() }
    }

    private var prompt: String {
        switch phase {
        case .idle: return "Tap to start, then say the task. You can add \"by Friday\" or \"tomorrow\"."
        case .listening: return "Listening. Tap Stop when you're done."
        case .review: return "Here's the task. Add it, or try again."
        case .denied: return "Still needs microphone and speech permission to hear a task. You can allow them in Settings, or type the task instead."
        case .failed: return "That didn't work. Try again, or type the task instead."
        }
    }

    private func listen() {
        guard let speech = appState.container.speech else {
            phase = .failed
            return
        }
        transcript = ""
        draft = nil
        Task { @MainActor in
            switch await speech.requestPermission() {
            case .granted:
                do {
                    try speech.start { text in
                        transcript = text
                    }
                    phase = .listening
                } catch {
                    phase = .failed
                }
            case .denied:
                phase = .denied
            case .unavailable:
                phase = .failed
            }
        }
    }

    private func stop() {
        let final = appState.container.speech?.stop() ?? transcript
        let text = final.isEmpty ? transcript : final
        draft = appState.draftTask(fromTranscript: text)
        phase = draft == nil ? .failed : .review
    }
}
