import Foundation

/// When a scene becomes available. Values live in `SceneCatalog` data,
/// never in views.
enum SceneUnlockRule: Codable, Hashable {
    case initiallyUnlocked
    /// Unlocks once this many focus sessions have been completed.
    case completedSessions(Int)

    var requiredSessions: Int {
        switch self {
        case .initiallyUnlocked: return 0
        case .completedSessions(let count): return count
        }
    }
}

/// V1.1 plant growth. The calm renderer already receives this value;
/// V1 always passes `.full` (see `FeatureFlags.plantGrowthStages`).
enum PlantGrowthStage: Int, Codable, CaseIterable, Hashable {
    case sprout = 0
    case leafy = 1
    case full = 2
}

/// Session-milestone progression. Pure and deterministic.
struct ProgressionEvaluator {
    func isUnlocked(_ scene: SceneDefinition, completedSessions: Int) -> Bool {
        completedSessions >= scene.unlockRule.requiredSessions
    }

    func unlockedScenes(in catalog: [SceneDefinition], completedSessions: Int) -> [SceneDefinition] {
        catalog
            .filter { isUnlocked($0, completedSessions: completedSessions) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// The next scene still waiting, with how many sessions remain.
    func nextLockedScene(in catalog: [SceneDefinition], completedSessions: Int) -> (scene: SceneDefinition, remaining: Int)? {
        catalog
            .filter { !isUnlocked($0, completedSessions: completedSessions) }
            .sorted { $0.unlockRule.requiredSessions < $1.unlockRule.requiredSessions }
            .first
            .map { ($0, $0.unlockRule.requiredSessions - completedSessions) }
    }

    /// Scenes that crossed their threshold between two counts.
    func newlyUnlocked(in catalog: [SceneDefinition], before: Int, after: Int) -> [SceneDefinition] {
        guard after > before else { return [] }
        return catalog
            .filter { !isUnlocked($0, completedSessions: before) && isUnlocked($0, completedSessions: after) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Plant stage derived from completed sessions (V1.1 renderer input).
    func plantStage(completedSessions: Int, growthEnabled: Bool) -> PlantGrowthStage {
        guard growthEnabled else { return .full }
        switch completedSessions {
        case ..<3: return .sprout
        case 3..<10: return .leafy
        default: return .full
        }
    }
}
