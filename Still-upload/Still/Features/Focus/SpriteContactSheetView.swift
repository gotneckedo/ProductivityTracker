import SwiftUI

/// A review surface for the authored package. It is reachable only by the
/// DEBUG screenshot route; the shipped product uses the individual sprite
/// assets through RoomHeroView and activity tiles.
struct SpriteContactSheetView: View {
    var body: some View {
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                        VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                            Text("Original pixel sprites")
                                .font(StillTypography.display)
                                .foregroundStyle(StillTheme.textPrimary)
                            Text("Rooms, starter furniture, 20 collectibles, break icons, and empty-state illustrations drawn for Still.")
                                .font(StillTypography.callout)
                                .foregroundStyle(StillTheme.textSecondary)
                        }

                        Image("StillSpriteContactSheet")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .accessibilityLabel("Still original pixel sprite contact sheet. It shows eight room scenes, twenty collectible objects, ten break icons, a Focus Card, bird, and three empty state illustrations.")

                        QuietNote(text: "All assets in this sheet are generated locally from Still’s checked-in pixel geometry. No reference-app art is included.", symbol: "checkmark.seal")
                        Color.clear.frame(height: 1).id("sprite-sheet-bottom")
                    }
                    .padding(.horizontal, StillTheme.Spacing.screen)
                    .padding(.vertical, StillTheme.Spacing.m)
                }
                .stillScrollableViewport()
                .onAppear {
                    #if DEBUG
                    guard DemoLaunch.shouldScrollToBottom("sprite-contact-sheet") else { return }
                    DispatchQueue.main.async { proxy.scrollTo("sprite-sheet-bottom", anchor: .bottom) }
                    #endif
                }
            }
        }
        .navigationTitle("Sprite sheet")
        .navigationBarTitleDisplayMode(.inline)
    }
}
