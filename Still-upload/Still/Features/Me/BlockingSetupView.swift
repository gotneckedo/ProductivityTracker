import SwiftUI
#if canImport(FamilyControls) && os(iOS)
import FamilyControls
#endif

/// Choose apps, understand the shield, and optionally start an open-ended
/// schedule. This screen is reachable only behind `FeatureFlags.appBlocking`.
struct BlockingSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var isConfirmingEnd = false

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("App blocking")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("Choose a few apps that can wait. The shield stays kind: focus on your task, or take a little break.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    BlockingPreviewDiagram()
                    content
                    BlockingScheduleSection()
                    Button("End blocking now") { isConfirmingEnd = true }
                        .buttonStyle(QuietSecondaryButtonStyle(foreground: StillTheme.attention))
                        .frame(maxWidth: .infinity)
                    Text("This button always works. It does not end a focus timer.")
                        .font(StillTypography.caption)
                        .foregroundStyle(StillTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
            .stillScrollableViewport()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("End blocking now?", isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            Button("End blocking now", role: .destructive) { appState.endBlockingNow() }
            Button("Keep blocking", role: .cancel) {}
        } message: {
            Text("Your chosen apps open again right away. You can turn the schedule back on later.")
        }
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(FamilyControls) && canImport(ManagedSettings) && os(iOS)
        if let service = appState.container.blocking as? FamilyControlsBlockingService {
            FamilyControlsSetup(service: service)
        } else {
            unavailableNote
        }
        #else
        unavailableNote
        #endif
    }

    private var unavailableNote: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                Label("Preview", systemImage: "eye")
                    .font(StillTypography.caption.weight(.semibold))
                    .foregroundStyle(StillTheme.warm)
                Text(BlockingCopy.title(for: appState.blockingCapability, isShielding: appState.isShieldingApps))
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                Text(BlockingCopy.detail(for: appState.blockingCapability))
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct BlockingPreviewDiagram: View {
    var body: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                Text("What happens")
                    .font(StillTypography.bodyEmphasis)
                    .foregroundStyle(StillTheme.textPrimary)
                HStack(alignment: .top, spacing: StillTheme.Spacing.xs) {
                    PreviewStep(symbol: "clock", title: "Start time", detail: "Your schedule begins")
                    PreviewArrow()
                    PreviewStep(symbol: "shield.fill", title: "Gentle shield", detail: "Chosen apps can wait")
                    PreviewArrow()
                    PreviewStep(symbol: "wave.3.right", title: "Card tap", detail: "Blocking ends")
                }
                Text("Focus on your task, or take a little break. Still never locks you in.")
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PreviewStep: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: StillTheme.Spacing.xxs) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StillTheme.calmSoft)
                .frame(width: 42, height: 42)
                .overlay { Image(systemName: symbol).foregroundStyle(StillTheme.calm) }
            Text(title)
                .font(StillTypography.caption.weight(.semibold))
                .foregroundStyle(StillTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct PreviewArrow: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(StillTypography.caption.weight(.semibold))
            .foregroundStyle(StillTheme.textTertiary)
            .padding(.top, 13)
            .accessibilityHidden(true)
    }
}

private struct BlockingScheduleSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StillCard {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                Toggle("Start at a time", isOn: Binding(
                    get: { appState.blockingSchedule.isEnabled },
                    set: { enabled in
                        appState.setBlockingSchedule(
                            isEnabled: enabled,
                            startMinute: appState.blockingSchedule.startMinute,
                            presetID: appState.blockingSchedule.presetID
                        )
                    }
                ))
                .font(StillTypography.bodyEmphasis)
                .tint(StillTheme.accent)
                if appState.blockingSchedule.isEnabled {
                    DatePicker("Start", selection: startTime, displayedComponents: .hourAndMinute)
                        .font(StillTypography.body)
                    Picker("Preset", selection: presetID) {
                        ForEach(appState.presets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .font(StillTypography.body)
                }
                Text(scheduleDetail)
                    .font(StillTypography.footnote)
                    .foregroundStyle(StillTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if appState.blockingCapability == .simulationOnly {
                    Label("Preview", systemImage: "eye")
                        .font(StillTypography.caption.weight(.semibold))
                        .foregroundStyle(StillTheme.warm)
                        .padding(.horizontal, StillTheme.Spacing.xs)
                        .padding(.vertical, StillTheme.Spacing.xxs)
                        .background(StillTheme.warmSoft, in: Capsule())
                }
            }
        }
    }

    private var startTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: appState.blockingSchedule.startComponents) ?? .now },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                appState.setBlockingSchedule(
                    isEnabled: true,
                    startMinute: minute,
                    presetID: appState.blockingSchedule.presetID
                )
            }
        )
    }

    private var presetID: Binding<FocusPresetID> {
        Binding(
            get: { appState.blockingSchedule.presetID },
            set: { id in
                appState.setBlockingSchedule(
                    isEnabled: appState.blockingSchedule.isEnabled,
                    startMinute: appState.blockingSchedule.startMinute,
                    presetID: id
                )
            }
        )
    }

    private var scheduleDetail: String {
        switch appState.blockingSchedule.phase {
        case .disabled:
            return "Optional. When it is off, nothing starts in the background."
        case .waiting:
            return appState.blockingCapability == .authorized
                ? "At that time, iOS shields the apps in this preset. Blocking continues until you tap your Focus Card or choose End blocking now."
                : "The time and preset are saved, but this build cannot shield apps. Nothing is blocked until Screen Time access is available."
        case .blockingUntilCardTap:
            return appState.isShieldingApps
                ? "The schedule is active. Tap your Focus Card to end it, or use End blocking now below."
                : "The schedule is in preview. A card tap ends the preview; no apps are actually shielded in this build."
        }
    }
}

#if canImport(FamilyControls) && canImport(ManagedSettings) && os(iOS)
private struct FamilyControlsSetup: View {
    let service: FamilyControlsBlockingService
    @Environment(AppState.self) private var appState
    @State private var editingPresetID: FocusPresetID?
    @State private var selection = FamilyActivitySelection()
    @State private var isRequesting = false
    @State private var capability: BlockingCapability = .notAuthorized

    var body: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            if capability != .authorized {
                StillCard {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
                        Text("Screen Time permission")
                            .font(StillTypography.bodyEmphasis)
                            .foregroundStyle(StillTheme.textPrimary)
                        Text("iOS asks once. Still never sees which apps you use; the choices stay on this device.")
                            .font(StillTypography.footnote)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(isRequesting ? "Asking…" : "Allow Screen Time access") {
                            isRequesting = true
                            Task { @MainActor in
                                try? await service.requestAuthorization()
                                capability = service.capability
                                isRequesting = false
                            }
                        }
                        .buttonStyle(QuietPrimaryButtonStyle())
                        .disabled(isRequesting)
                    }
                }
            } else {
                ForEach(appState.presets) { preset in
                    let chosen = service.selection(for: preset.id)
                    let count = chosen.applicationTokens.count + chosen.categoryTokens.count + chosen.webDomainTokens.count
                    Button {
                        selection = chosen
                        editingPresetID = preset.id
                    } label: {
                        SettingRow(symbol: preset.blockerIntent == .none ? "circle.slash" : "shield",
                                   title: preset.name,
                                   value: preset.blockerIntent == .none ? "Off" : (count == 0 ? "Choose apps" : "\(count) chosen"),
                                   iconTint: StillTheme.calm, iconBackground: StillTheme.calmSoft)
                    }
                    .buttonStyle(.plain)
                    .disabled(preset.blockerIntent == .none)
                }
                QuietNote(text: "Presets set to no blocking are skipped. Change a preset's blocking in Session options.")
            }
        }
        .onAppear {
            service.refreshAuthorization()
            capability = service.capability
        }
        .familyActivityPicker(
            isPresented: Binding(get: { editingPresetID != nil }, set: { if !$0 { editingPresetID = nil } }),
            selection: Binding(
                get: { selection },
                set: { newValue in
                    selection = newValue
                    if let id = editingPresetID { service.setSelection(newValue, for: id) }
                }
            )
        )
    }
}
#endif
