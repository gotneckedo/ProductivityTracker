import SwiftUI
#if canImport(FamilyControls) && os(iOS)
import FamilyControls
#endif

/// Choose which apps each preset shields during a session. Only reachable
/// when `FeatureFlags.appBlocking` is on, which requires Apple's Family
/// Controls entitlement. Setup is explained, never forced.
struct BlockingSetupView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                        Text("App blocking")
                            .font(StillTypography.title)
                            .foregroundStyle(StillTheme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text("While a session runs, Still can shield the apps you pick. You can always end blocking early from the session screen.")
                            .font(StillTypography.callout)
                            .foregroundStyle(StillTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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
                                   value: preset.blockerIntent == .none ? "Off" : (count == 0 ? "Choose apps" : "\(count) chosen"))
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
                    if let id = editingPresetID {
                        service.setSelection(newValue, for: id)
                    }
                }
            )
        )
    }
}
#endif
