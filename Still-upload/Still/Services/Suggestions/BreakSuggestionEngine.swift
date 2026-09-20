import Foundation

struct BreakSuggestionRequest {
    /// Break time available after the session.
    var availableBreak: TimeInterval
    var catalog: [BreakActivity]
    /// Activities already opened (started) today.
    var usedToday: Set<BreakActivityID>
    /// Most recent use per activity, for choosing what to revisit first.
    var lastUsedAt: [BreakActivityID: Date]
    var categoryOrder: [ActivityCategory]
    /// Rotates choices within a category from day to day (e.g. day of year).
    var daySeed: Int
}

struct BreakSuggestionSet: Equatable {
    var activities: [BreakActivity]
    /// True when everything that fits was already used today, so the
    /// suggestions are revisits.
    var isRevisit: Bool
    var availableBreak: TimeInterval

    var headline: String {
        isRevisit ? "You've tried everything today. A few to revisit:" : "What do you want to do instead?"
    }
}

/// Chooses exactly three finite activities for the session-complete moment.
///
/// Rules, in order:
/// 1. Only `available` activities are considered.
/// 2. Activities that fit in the available break come first; if fewer than
///    three fit, the shortest remaining activities fill the gap.
/// 3. Activities not used today are preferred, even if one runs a little past
///    the break. If none are left, the least recently used are offered as revisits.
/// 4. Picks rotate across categories (in the personalized order) so the three
///    feel different, e.g. one Reset, one Puzzle, one Quiet.
struct BreakSuggestionEngine {
    static let suggestionCount = 3

    func suggestions(for request: BreakSuggestionRequest) -> BreakSuggestionSet {
        let available = request.catalog.filter { $0.implementationState == .available }
        let count = min(Self.suggestionCount, available.count)
        guard count > 0 else {
            return BreakSuggestionSet(activities: [], isRevisit: false, availableBreak: request.availableBreak)
        }

        // 2. Build the time-appropriate pool.
        let budget = max(request.availableBreak, 60)
        var pool = available.filter { $0.estimatedDuration <= budget }
        if pool.count < count {
            let extras = available
                .filter { candidate in !pool.contains { $0.id == candidate.id } }
                .sorted { ($0.estimatedDuration, $0.category.sortOrder, $0.sortOrder) < ($1.estimatedDuration, $1.category.sortOrder, $1.sortOrder) }
            pool.append(contentsOf: extras.prefix(count - pool.count))
        }

        // 3. Prefer fresh activities. If too few fresh ones fit, a slightly
        //    longer fresh activity beats repeating one already done today.
        var fresh = pool.filter { !request.usedToday.contains($0.id) }
        if fresh.count < count {
            let longerFresh = available
                .filter { candidate in
                    !request.usedToday.contains(candidate.id) && !fresh.contains { $0.id == candidate.id }
                }
                .sorted { lhs, rhs in
                    (lhs.estimatedDuration, lhs.category.sortOrder, lhs.sortOrder)
                        < (rhs.estimatedDuration, rhs.category.sortOrder, rhs.sortOrder)
                }
            fresh.append(contentsOf: longerFresh.prefix(count - fresh.count))
        }
        var chosen = diversePick(from: fresh, count: count, request: request)
        let isRevisit = fresh.isEmpty

        if chosen.count < count {
            let used = pool
                .filter { candidate in !chosen.contains { $0.id == candidate.id } }
                .sorted { lhs, rhs in
                    let l = request.lastUsedAt[lhs.id] ?? .distantPast
                    let r = request.lastUsedAt[rhs.id] ?? .distantPast
                    return l == r ? lhs.sortOrder < rhs.sortOrder : l < r
                }
            chosen.append(contentsOf: used.prefix(count - chosen.count))
        }

        return BreakSuggestionSet(activities: chosen, isRevisit: isRevisit, availableBreak: request.availableBreak)
    }

    /// Round-robin across categories in the preferred order, rotating the
    /// starting activity inside each category by the day seed.
    private func diversePick(from candidates: [BreakActivity], count: Int, request: BreakSuggestionRequest) -> [BreakActivity] {
        var order = request.categoryOrder
        for category in ActivityCategory.allCases where !order.contains(category) {
            order.append(category)
        }

        var queues: [[BreakActivity]] = order.map { category in
            let items = candidates.filter { $0.category == category }.sorted { $0.sortOrder < $1.sortOrder }
            guard !items.isEmpty else { return [] }
            let shift = ((request.daySeed % items.count) + items.count) % items.count
            return Array(items[shift...] + items[..<shift])
        }

        var picked: [BreakActivity] = []
        while picked.count < count, queues.contains(where: { !$0.isEmpty }) {
            for index in queues.indices where picked.count < count && !queues[index].isEmpty {
                picked.append(queues[index].removeFirst())
            }
        }
        return picked
    }
}
