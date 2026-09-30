import Foundation

enum BlockingSchedulePhase: String, Codable, Equatable {
    case disabled
    case waiting
    case blockingUntilCardTap
}

struct BlockingSchedule: Codable, Equatable {
    var isEnabled: Bool
    /// Minutes after local midnight.
    var startMinute: Int
    var presetID: FocusPresetID
    var phase: BlockingSchedulePhase
    /// The local calendar day on which the schedule most recently started.
    var activeDay: Date?

    static let defaultStartMinute = 20 * 60

    static func disabled(presetID: FocusPresetID = .defaultPreset) -> BlockingSchedule {
        BlockingSchedule(
            isEnabled: false,
            startMinute: defaultStartMinute,
            presetID: presetID,
            phase: .disabled,
            activeDay: nil
        )
    }

    func validated() -> BlockingSchedule {
        var copy = self
        copy.startMinute = min(max(startMinute, 0), (24 * 60) - 1)
        if !copy.isEnabled {
            copy.phase = .disabled
            copy.activeDay = nil
        } else if copy.phase == .disabled {
            copy.phase = .waiting
        }
        return copy
    }
}

protocol BlockingScheduleStore: AnyObject {
    func load(defaultPresetID: FocusPresetID) -> BlockingSchedule
    func save(_ schedule: BlockingSchedule)
    func reset()
}

final class KeyValueBlockingScheduleStore: BlockingScheduleStore {
    private let store: KeyValueStore
    private let key = "still.blocking.schedule.v1"

    init(store: KeyValueStore) {
        self.store = store
    }

    func load(defaultPresetID: FocusPresetID) -> BlockingSchedule {
        guard let data = store.data(forKey: key),
              let decoded = try? RecordCoding.decoder().decode(BlockingSchedule.self, from: data) else {
            return .disabled(presetID: defaultPresetID)
        }
        return decoded.validated()
    }

    func save(_ schedule: BlockingSchedule) {
        store.set(try? RecordCoding.encoder().encode(schedule.validated()), forKey: key)
    }

    func reset() {
        store.set(nil, forKey: key)
    }
}

enum BlockingScheduleTransition: Equatable {
    case none
    case started
    case endedByCardTap
    case endedManually
}

/// Pure schedule coordinator. It owns intent and persistence; the injected
/// blocking service remains the source of truth for whether iOS is truly
/// shielding anything.
final class BlockingScheduleController {
    private let clock: Clock
    private let calendar: Calendar
    private let store: BlockingScheduleStore
    private let blocking: FocusBlockingService

    private(set) var schedule: BlockingSchedule

    init(
        clock: Clock,
        calendar: Calendar,
        store: BlockingScheduleStore,
        blocking: FocusBlockingService,
        defaultPresetID: FocusPresetID = .defaultPreset
    ) {
        self.clock = clock
        self.calendar = calendar
        self.store = store
        self.blocking = blocking
        schedule = store.load(defaultPresetID: defaultPresetID)
    }

    var isActuallyShielding: Bool { blocking.isShielding }

    func update(isEnabled: Bool, startMinute: Int, presetID: FocusPresetID) {
        if schedule.phase == .blockingUntilCardTap {
            blocking.endShieldingNow()
        }
        schedule = BlockingSchedule(
            isEnabled: isEnabled,
            startMinute: startMinute,
            presetID: presetID,
            phase: isEnabled ? .waiting : .disabled,
            activeDay: nil
        ).validated()
        persist()
        if isEnabled {
            _ = refresh(at: clock.now)
        }
    }

    @discardableResult
    func refresh(at date: Date? = nil) -> BlockingScheduleTransition {
        guard schedule.isEnabled else {
            if schedule.phase != .disabled {
                schedule.phase = .disabled
                schedule.activeDay = nil
                persist()
            }
            return .none
        }
        guard schedule.phase != .blockingUntilCardTap else { return .none }

        let now = date ?? clock.now
        let day = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .minute, value: schedule.startMinute, to: day)!
        guard now >= start else { return .none }

        schedule.phase = .blockingUntilCardTap
        schedule.activeDay = day
        blocking.scheduleDidStart(presetID: schedule.presetID)
        persist()
        return .started
    }

    @discardableResult
    func cardTapped() -> BlockingScheduleTransition {
        guard schedule.phase == .blockingUntilCardTap else { return .none }
        blocking.endShieldingNow()
        schedule.phase = schedule.isEnabled ? .waiting : .disabled
        schedule.activeDay = nil
        persist()
        return .endedByCardTap
    }

    @discardableResult
    func endNow() -> BlockingScheduleTransition {
        guard schedule.phase == .blockingUntilCardTap || blocking.isShielding else { return .none }
        blocking.endShieldingNow()
        schedule.phase = schedule.isEnabled ? .waiting : .disabled
        schedule.activeDay = nil
        persist()
        return .endedManually
    }

    func reset() {
        blocking.endShieldingNow()
        store.reset()
        schedule = .disabled()
    }

    private func persist() {
        store.save(schedule)
    }
}

extension BlockingSchedule {
    var startComponents: DateComponents {
        DateComponents(hour: startMinute / 60, minute: startMinute % 60)
    }
}
