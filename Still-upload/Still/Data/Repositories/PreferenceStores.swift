import Foundation

protocol PreferencesStore: AnyObject {
    func load() -> UserPreferences
    func save(_ preferences: UserPreferences)
    func reset()
}

final class CodablePreferencesStore: PreferencesStore {
    private let store: KeyValueStore
    private let key = "still.preferences.v1"

    init(store: KeyValueStore) {
        self.store = store
    }

    func load() -> UserPreferences {
        guard let data = store.data(forKey: key),
              let preferences = try? RecordCoding.decoder().decode(UserPreferences.self, from: data) else {
            return UserPreferences()
        }
        return preferences
    }

    func save(_ preferences: UserPreferences) {
        store.set(try? RecordCoding.encoder().encode(preferences), forKey: key)
    }

    func reset() {
        store.set(nil, forKey: key)
    }
}

/// Presets live beside preferences: a small, user-editable list.
protocol PresetRepository: AnyObject {
    func allPresets() -> [FocusPreset]
    func preset(id: FocusPresetID) -> FocusPreset?
    func save(_ preset: FocusPreset)
    /// Removes a preset the user made. Built-ins can't be deleted.
    func delete(id: FocusPresetID)
    /// Restores built-ins, e.g. after onboarding personalizes defaults.
    func resetToBuiltIns(personalization: Personalization)
}

final class StoredPresetRepository: PresetRepository {
    private let store: KeyValueStore
    private let key = "still.presets.v1"

    init(store: KeyValueStore) {
        self.store = store
    }

    func allPresets() -> [FocusPreset] {
        let stored = loadStored()
        var result = PresetCatalog.builtIns(personalization: Personalization(goal: nil)).map { builtIn in
            stored.first { $0.id == builtIn.id } ?? builtIn
        }
        result.append(contentsOf: stored.filter { preset in !result.contains { $0.id == preset.id } })
        return result
    }

    func preset(id: FocusPresetID) -> FocusPreset? {
        allPresets().first { $0.id == id }
    }

    func save(_ preset: FocusPreset) {
        var stored = loadStored()
        var copy = preset
        copy.timer = preset.timer.validated()
        if let index = stored.firstIndex(where: { $0.id == preset.id }) {
            stored[index] = copy
        } else {
            stored.append(copy)
        }
        persist(stored)
    }

    func delete(id: FocusPresetID) {
        guard !PresetCatalog.builtInIDs.contains(id) else { return }
        persist(loadStored().filter { $0.id != id })
    }

    func resetToBuiltIns(personalization: Personalization) {
        persist(PresetCatalog.builtIns(personalization: personalization))
    }

    private func loadStored() -> [FocusPreset] {
        guard let data = store.data(forKey: key) else { return [] }
        return (try? RecordCoding.decoder().decode([FocusPreset].self, from: data)) ?? []
    }

    private func persist(_ presets: [FocusPreset]) {
        store.set(try? RecordCoding.encoder().encode(presets), forKey: key)
    }
}
