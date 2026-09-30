import Foundation

/// Ranks the finite Break shelf. Onboarding provides the cold-start seed; as
/// activities are used, frequency and recency become the stronger signals.
struct BreakShelfRanking {
    func ranked(
        catalog: [BreakActivity],
        usages: [ActivityUsage],
        personalization: Personalization
    ) -> [BreakActivity] {
        let available = catalog.filter { $0.implementationState == .available }
        let categoryOrder = personalization.categoryOrder
        let counts = Dictionary(grouping: usages, by: \.activityID).mapValues(\.count)
        let lastUsed = Dictionary(grouping: usages, by: \.activityID).mapValues { group in
            group.map(\.startedAt).max() ?? .distantPast
        }

        return available.sorted { lhs, rhs in
            let lhsCount = counts[lhs.id] ?? 0
            let rhsCount = counts[rhs.id] ?? 0
            if lhsCount != rhsCount { return lhsCount > rhsCount }

            if lhsCount > 0 {
                let lhsDate = lastUsed[lhs.id] ?? .distantPast
                let rhsDate = lastUsed[rhs.id] ?? .distantPast
                if lhsDate != rhsDate { return lhsDate > rhsDate }
            }

            let lhsCategory = categoryOrder.firstIndex(of: lhs.category) ?? categoryOrder.count
            let rhsCategory = categoryOrder.firstIndex(of: rhs.category) ?? categoryOrder.count
            if lhsCategory != rhsCategory { return lhsCategory < rhsCategory }
            if lhs.category.sortOrder != rhs.category.sortOrder {
                return lhs.category.sortOrder < rhs.category.sortOrder
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }
}

/// Pull-to-refresh only changes the presentation order of automatically ranked
/// suggestions. A person's explicit shelf order always wins.
enum BreakShelfRotation {
    static func rotated<T>(_ values: [T], offset: Int) -> [T] {
        guard !values.isEmpty else { return [] }
        let safeOffset = ((offset % values.count) + values.count) % values.count
        return Array(values.dropFirst(safeOffset)) + Array(values.prefix(safeOffset))
    }
}
