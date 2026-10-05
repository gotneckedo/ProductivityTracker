import SwiftUI

/// A review surface for the authored package. It is reachable only by DEBUG
/// screenshot routes; the shipped product uses individual sprites through the
/// room renderer and activity tiles.
struct SpriteContactSheetView: View {
    private var isSleepRoomReview: Bool {
        #if DEBUG
        return DemoLaunch.requestedScreen == "room-sleep"
        #else
        return false
        #endif
    }

    var body: some View {
        StillScreen {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
                        if isSleepRoomReview {
                            sleepRoomReview
                        } else {
                            packageReview
                        }
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
        .navigationTitle(isSleepRoomReview ? "Sleep room" : "Sprite sheet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sleepRoomReview: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            Text("Sleep room")
                .font(StillTypography.display)
                .foregroundStyle(StillTheme.textPrimary)
            Text("Reserved art for the later DEBUG-only alarm-preview state. This screen does not arm or simulate an alarm.")
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
            Image("StillRoomAlarmSleep")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .accessibilityLabel("Reserved sleep room pixel art with a bed, moonlit window, desk, and lamp.")
        }
    }

    private var packageReview: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.m) {
            VStack(alignment: .leading, spacing: StillTheme.Spacing.xxs) {
                Text("Pixel asset review")
                    .font(StillTypography.display)
                    .foregroundStyle(StillTheme.textPrimary)
                Text("Room bases and 20 collectible sprites use the supplied square pixel-art package. Cat and utility sprites remain local Still assets.")
                    .font(StillTypography.callout)
                    .foregroundStyle(StillTheme.textSecondary)
            }

            Image("StillExternalCollectibleSpriteSheet")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .accessibilityLabel("Supplied collectible sprite sheet with twenty room objects arranged in four rows.")

            StillInsetList {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
                    Text("Room bases")
                        .font(StillTypography.bodyEmphasis)
                        .foregroundStyle(StillTheme.textPrimary)
                    Text("Eight supplied 512 point transparent room bases load through the same sprite-first scene keys. The temporary generated room art is not shown here.")
                        .font(StillTypography.footnote)
                        .foregroundStyle(StillTheme.textSecondary)
                }
            }

            Image("StillCatSpriteContactSheet")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .accessibilityLabel("Still cat contact sheet with four coats and six poses each.")

            QuietNote(text: "The supplied room and collectible artwork is integrated for review. Its source declaration is recorded in the asset policy.", symbol: "checkmark.seal")
            QuietNote(text: "Cat poses: sit, idle, walk, sleep, stretch, and look up. Every pose has four local Still coats.", symbol: "pawprint")
        }
    }
}
