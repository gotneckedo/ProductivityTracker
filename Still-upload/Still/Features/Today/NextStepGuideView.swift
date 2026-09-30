import SwiftUI

/// A deliberately small decision aid. It produces one concrete local action,
/// rather than opening a conversational assistant or collecting personal data.
struct NextStepGuideView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: MomentNeed? = nil

    var body: some View {
        NavigationStack {
            StillScreen {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    Text("WHAT KIND OF MOMENT IS THIS?")
                        .font(StillTypography.caption)
                        .tracking(1.3)
                        .foregroundStyle(StillTheme.textTertiary)
                    Text(selected?.reassurance ?? "You do not need to figure out everything right now.")
                        .font(StillTypography.display)
                        .foregroundStyle(StillTheme.textPrimary)
                    VStack(spacing: StillTheme.Spacing.s) {
                        ForEach(MomentNeed.allCases, id: \.self) { need in
                            Button { selected = need } label: {
                                HStack {
                                    Image(systemName: need.symbol).frame(width: 28)
                                    Text(need.title).font(StillTypography.bodyEmphasis)
                                    Spacer()
                                    if selected == need { Image(systemName: "checkmark.circle.fill") }
                                }
                                .foregroundStyle(StillTheme.textPrimary)
                                .padding(StillTheme.Spacing.m)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .stillGlass(radius: StillTheme.Radius.medium)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected == need ? .isSelected : [])
                        }
                    }
                    if let selected {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                            Text(selected.action(appState: appState))
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textSecondary)
                            Button(selected.buttonTitle) { act(selected) }
                                .buttonStyle(QuietPrimaryButtonStyle())
                        }
                        .padding(StillTheme.Spacing.m)
                        .stillGlass()
                    }
                }
                .padding(StillTheme.Spacing.screen)
            }
            .navigationTitle("A next step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    private func act(_ need: MomentNeed) {
        dismiss()
        switch need {
        case .work:
            if let task = appState.todaysTasks.first(where: { !$0.isCompleted }) { appState.selectTask(task.id) }
            appState.startFocus(presetID: .lowEnergy, source: .manual)
        case .break:
            appState.router.go(to: .breakShelf)
        case .restless:
            appState.router.go(to: .breakActivity(.guidedStretch, .shelf))
        case .overwhelmed:
            appState.startFocus(presetID: .tinyStart, source: .manual)
        case .scrolling:
            appState.router.go(to: .breakActivity(.doNothing, .shelf))
        }
    }
}

private enum MomentNeed: CaseIterable {
    case work, `break`, restless, overwhelmed, scrolling

    var title: String {
        switch self {
        case .work: return "I need to work"
        case .break: return "I need a break"
        case .restless: return "I'm restless"
        case .overwhelmed: return "I'm overwhelmed"
        case .scrolling: return "I want to stop scrolling"
        }
    }
    var symbol: String {
        switch self {
        case .work: return "checkmark.circle"
        case .break: return "cup.and.saucer"
        case .restless: return "figure.walk"
        case .overwhelmed: return "cloud"
        case .scrolling: return "hand.raised"
        }
    }
    var reassurance: String {
        switch self {
        case .work: return "One small round is enough to begin."
        case .break: return "A real break can have an end."
        case .restless: return "Move a little before you decide what is next."
        case .overwhelmed: return "Make the next thing smaller."
        case .scrolling: return "Put your phone down when this step is done."
        }
    }
    var buttonTitle: String {
        switch self {
        case .work: return "Start 10 min"
        case .break: return "Choose a break"
        case .restless: return "Start a stretch"
        case .overwhelmed: return "Start a tiny round"
        case .scrolling: return "Take two quiet minutes"
        }
    }
    func action(appState: AppState) -> String {
        switch self {
        case .work:
            let title = appState.todaysTasks.first(where: { !$0.isCompleted })?.title ?? "Open the first thing that needs you"
            return "Open \(title). Work for 10 minutes, then choose again."
        case .break: return "Choose one finite reset. When it ends, leave Still or return to your work."
        case .restless: return "Stand up, stretch gently, and come back only if you want to."
        case .overwhelmed: return "Pick the first visible step. Five quiet minutes is a real start."
        case .scrolling: return "Set the phone down after this short pause. You do not need another feed."
        }
    }
}
