import SwiftUI

struct RoomCollectionView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSceneID: SceneID = .rainyBedroom
    @State private var selectedSlot: RoomSlot = .desk

    private var scene: SceneDefinition { appState.scene(selectedSceneID) }
    private var placements: [RoomPlacement] { appState.placedRoomObjects(in: selectedSceneID) }

    var body: some View {
        StillScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: StillTheme.Spacing.l) {
                    header
                    RoomHeroView(
                        sceneName: scene.name,
                        sceneID: scene.id,
                        plantStage: appState.plantStage,
                        bookCount: 2 + appState.books.count,
                        doodle: appState.doodles.max { $0.updatedAt < $1.updatedAt }?.doodle,
                        placedObjects: placements
                    )
                    .aspectRatio(160.0 / 132.0, contentMode: .fit)

                    roomPicker
                    slotPicker
                    catalog
                }
                .padding(.horizontal, StillTheme.Spacing.screen)
                .padding(.vertical, StillTheme.Spacing.m)
            }
        }
        .navigationTitle(Copy.Collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            selectedSceneID = appState.currentPreset.sceneID
            appState.acknowledgeRoomUnlocks()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text(Copy.Collection.title)
                .font(StillTypography.display)
                .foregroundStyle(StillTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(Copy.Collection.detail)
                .font(StillTypography.callout)
                .foregroundStyle(StillTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var roomPicker: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text("Room")
                .font(StillTypography.title3)
                .foregroundStyle(StillTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StillTheme.Spacing.xs) {
                    ForEach(SceneCatalog.all.filter(appState.isUnlocked)) { room in
                        Button(room.name) { selectedSceneID = room.id }
                            .buttonStyle(RoomCollectionPill(selected: selectedSceneID == room.id))
                            .accessibilityAddTraits(selectedSceneID == room.id ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var slotPicker: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            Text("Place in")
                .font(StillTypography.title3)
                .foregroundStyle(StillTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: StillTheme.Spacing.xs) {
                    ForEach(RoomSlot.allCases, id: \.self) { slot in
                        Button {
                            selectedSlot = slot
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(slot.displayName)
                                Text(placedName(in: slot) ?? Copy.Collection.emptySlot)
                                    .font(StillTypography.caption)
                                    .foregroundStyle(StillTheme.textTertiary)
                            }
                        }
                        .buttonStyle(RoomCollectionPill(selected: selectedSlot == slot))
                        .accessibilityLabel("\(Copy.Collection.slot(slot.displayName)), \(placedName(in: slot) ?? Copy.Collection.emptySlot)")
                        .accessibilityAddTraits(selectedSlot == slot ? .isSelected : [])
                    }
                }
            }
            if placements.contains(where: { $0.slot == selectedSlot }) {
                Button(Copy.Collection.remove) {
                    appState.removeRoomObject(from: selectedSceneID, slot: selectedSlot)
                }
                .buttonStyle(QuietTextButtonStyle())
                .accessibilityHint("Removes the object from this room. You still keep it in your collection.")
            }
        }
        .padding(StillTheme.Spacing.m)
        .stillGlass(radius: StillTheme.Radius.medium)
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: StillTheme.Spacing.s) {
            Text("Collection")
                .font(StillTypography.title)
                .foregroundStyle(StillTheme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StillTheme.Spacing.s) {
                ForEach(RoomObjectCatalog.all) { object in
                    objectCard(object)
                }
            }
        }
    }

    private func objectCard(_ object: RoomObject) -> some View {
        let unlocked = appState.roomCollection.unlockedObjectIDs.contains(object.id)
        let placedHere = placements.contains { $0.objectID == object.id }
        return VStack(alignment: .leading, spacing: StillTheme.Spacing.xs) {
            RoomObjectThumbnail(object: object, locked: !unlocked)
                .frame(height: 72)
                .accessibilityHidden(true)
            Text(object.name)
                .font(StillTypography.bodyEmphasis)
                .foregroundStyle(StillTheme.textPrimary)
            Text(unlocked ? object.summary : object.unlockRule.plainLanguage)
                .font(StillTypography.caption)
                .foregroundStyle(StillTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if unlocked {
                Button(placedHere ? Copy.Collection.placed : Copy.Collection.place) {
                    selectedSlot = object.slot
                    appState.placeRoomObject(object.id, in: selectedSceneID, slot: object.slot)
                }
                .buttonStyle(QuietSecondaryButtonStyle())
                .disabled(placedHere)
                .accessibilityHint("Places this in the \(object.slot.displayName.lowercased()) slot. It replaces anything there.")
            } else {
                Label(Copy.Collection.locked, systemImage: "lock")
                    .font(StillTypography.caption)
                    .foregroundStyle(StillTheme.textTertiary)
                    .frame(minHeight: StillTheme.minimumTapSize)
            }
        }
        .padding(StillTheme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .stillGlass(radius: StillTheme.Radius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(unlocked
            ? "\(object.name). Unlocked. \(object.summary). Goes in \(object.slot.displayName)."
            : "\(object.name). Locked. \(object.unlockRule.plainLanguage).")
    }

    private func placedName(in slot: RoomSlot) -> String? {
        guard let placement = placements.first(where: { $0.slot == slot }) else { return nil }
        return RoomObjectCatalog.object(placement.objectID)?.name
    }
}

private struct RoomCollectionPill: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StillTypography.caption)
            .foregroundStyle(StillTheme.textPrimary)
            .padding(.horizontal, StillTheme.Spacing.s)
            .frame(minHeight: StillTheme.minimumTapSize)
            .background(.white.opacity(selected ? 0.52 : 0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(selected ? 0.82 : 0.4), lineWidth: StillTheme.Stroke.hairline))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct RoomObjectThumbnail: View {
    let object: RoomObject
    let locked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(locked ? 0.08 : 0.24))
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(locked ? StillTheme.textTertiary.opacity(0.55) : StillTheme.accent)
                .shadow(color: locked ? .clear : StillTheme.accent.opacity(0.18), radius: 8)
        }
    }

    private var symbol: String {
        switch object.renderKey {
        case .trailingPlant: return "leaf"
        case .deskLamp, .candle, .stringLights: return "lightbulb"
        case .artPoster, .pinboard, .paperStars: return "rectangle.portrait"
        case .recordPlayer, .radio: return "music.note"
        case .wovenRug, .floorCushion, .catBed: return "circle.dashed"
        case .globe: return "globe.americas"
        case .bookends, .bookStack: return "books.vertical"
        case .pencilCup: return "pencil.and.ruler"
        case .tinyClock: return "clock"
        case .ceramicBird: return "bird"
        case .wateringCan: return "drop"
        case .telescope: return "scope"
        }
    }
}

#Preview("Your things") {
    NavigationStack { RoomCollectionView() }
        .environment(PreviewSupport.appState(populated: true))
}
