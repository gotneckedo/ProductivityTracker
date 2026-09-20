import Foundation

/// Something the UI should react to after a focus action.
enum FocusFlowEvent: Equatable {
    case sessionStarted(UUID)
    case phaseStarted(FocusPhaseKind)
    case awaitingNextPhase(FocusPhaseKind)
    case sessionCompleted(UUID)
    case sessionAbandoned(UUID)
}

enum FocusStartOutcome: Equatable {
    case started(FocusSession)
    /// A session is already running; it is left untouched.
    case alreadyRunning(FocusSession)
    /// The requested preset doesn't exist; the default preset started instead.
    case startedWithFallback(FocusSession, requested: FocusPresetID)

    var session: FocusSession {
        switch self {
        case .started(let s), .alreadyRunning(let s), .startedWithFallback(let s, _): return s
        }
    }
}

/// Orchestrates a focus session across the timer, persistence, tasks,
/// notifications, audio, blocking intent, Live Activity, and local events.
///
/// Platform-neutral and fully unit-tested; `AppState` only mirrors its results.
final class FocusFlowController {
    private let clock: Clock
    private let timer: FocusTimerService
    private let sessions: SessionRepository
    private let tasks: TaskRepository
    private let presets: PresetRepository
    private let preferences: PreferencesStore
    private let notifications: LocalNotificationScheduling
    private let audio: AmbientAudioPlaying
    private let blocking: FocusBlockingService
    private let liveActivity: LiveActivityUpdating
    private let events: EventTracking
    private let scenes: [SceneDefinition]
    private let progression = ProgressionEvaluator()

    private(set) var activeSession: FocusSession?
    /// Called when a write fails, so the UI can show a calm notice.
    var onPersistenceError: ((Error) -> Void)?

    init(
        clock: Clock,
        timer: FocusTimerService = FocusTimerEngine(),
        sessions: SessionRepository,
        tasks: TaskRepository,
        presets: PresetRepository,
        preferences: PreferencesStore,
        notifications: LocalNotificationScheduling,
        audio: AmbientAudioPlaying,
        blocking: FocusBlockingService,
        liveActivity: LiveActivityUpdating,
        events: EventTracking,
        scenes: [SceneDefinition] = SceneCatalog.all
    ) {
        self.clock = clock
        self.timer = timer
        self.sessions = sessions
        self.tasks = tasks
        self.presets = presets
        self.preferences = preferences
        self.notifications = notifications
        self.audio = audio
        self.blocking = blocking
        self.liveActivity = liveActivity
        self.events = events
        self.scenes = scenes
    }

    // MARK: - Lifecycle

    /// Restores a session after launch. Overdue phases are completed with their
    /// exact end dates; a session that finished while the app was closed goes
    /// straight to its completion moment.
    @discardableResult
    func restore() -> [FocusFlowEvent] {
        guard let live = sessions.liveSession() else {
            activeSession = nil
            return []
        }
        activeSession = live
        let flowEvents = tick()
        if let session = activeSession, session.state.isLive {
            audio.apply(presetMix(for: session))
            if session.state == .active { audio.play() }
            scheduleNotifications()
            updateLiveActivity()
        }
        return flowEvents
    }

    func snapshot() -> TimerSnapshot? {
        activeSession.map { timer.snapshot(of: $0, at: clock.now) }
    }

    var completedSessionCount: Int {
        sessions.allSessions().filter { $0.state == .completed }.count
    }

    // MARK: - Starting

    @discardableResult
    func start(presetID: FocusPresetID, taskID: UUID?, source: SessionSource) -> FocusStartOutcome {
        if let running = activeSession, running.state.isLive {
            return .alreadyRunning(running)
        }

        let requested = presets.preset(id: presetID)
        let preset = requested
            ?? presets.preset(id: .defaultPreset)
            ?? PresetCatalog.defaultPreset()

        let resolvedTaskID: UUID? = {
            guard preset.taskBehavior == .useSelectedTask, let id = taskID,
                  let task = tasks.task(id: id), !task.isCompleted else { return nil }
            return id
        }()

        let scene = scenes.first { $0.id == preset.sceneID }
        let sceneID = scene.map { progression.isUnlocked($0, completedSessions: completedSessionCount) } == true
            ? preset.sceneID
            : SceneCatalog.rainyBedroom.id

        let session = timer.makeSession(
            id: UUID(),
            configuration: preset.timer,
            taskID: resolvedTaskID,
            sceneID: sceneID,
            renderMode: preset.renderMode,
            presetID: preset.id,
            source: source,
            at: clock.now
        )
        activeSession = session
        persist(session)

        if let id = resolvedTaskID, var task = tasks.task(id: id) {
            task.attachedSessionID = session.id
            persistTask(task)
        }

        audio.apply(preset.ambientMix)
        audio.play()
        blocking.sessionDidStart(sessionID: session.id, intent: preset.blockerIntent)
        scheduleNotifications()
        updateLiveActivity()

        events.track(.focusStarted, EventProperties()
            .timerMode(session.configuration.mode)
            .preset(preset.id)
            .source(source)
            .userInitiated(source == .manual))

        return requested == nil ? .startedWithFallback(session, requested: presetID) : .started(session)
    }

    // MARK: - Ticking

    /// Advances the running session to now. Call once a second while visible
    /// and whenever the app returns to the foreground.
    @discardableResult
    func tick() -> [FocusFlowEvent] {
        guard let session = activeSession, session.state == .active else { return [] }
        let (advanced, transitions) = timer.advance(session, to: clock.now)
        guard !transitions.isEmpty else { return [] }
        return apply(advanced, transitions: transitions)
    }

    // MARK: - User actions

    func pause() {
        guard let session = activeSession, session.state == .active, !session.isAwaitingNextPhase else { return }
        let (paused, transitions) = timer.pause(session, at: clock.now)
        let flowEvents = apply(paused, transitions: transitions)
        guard !flowEvents.contains(where: Self.isTerminal), paused.state == .paused else { return }
        audio.pause()
        notifications.cancelAll()
        updateLiveActivity()
        events.track(.focusPaused, EventProperties().timerMode(paused.configuration.mode).userInitiated(true))
    }

    func resume() {
        guard let session = activeSession, session.state == .paused else { return }
        let resumed = timer.resume(session, at: clock.now)
        activeSession = resumed
        persist(resumed)
        audio.play()
        scheduleNotifications()
        updateLiveActivity()
        events.track(.focusResumed, EventProperties().timerMode(resumed.configuration.mode).userInitiated(true))
    }

    @discardableResult
    func startNextPhase() -> [FocusFlowEvent] {
        guard let session = activeSession else { return [] }
        let (next, transitions) = timer.startNextPhase(session, at: clock.now)
        return apply(next, transitions: transitions)
    }

    @discardableResult
    func skipBreak() -> [FocusFlowEvent] {
        guard let session = activeSession else { return [] }
        let (next, transitions) = timer.skipBreak(session, at: clock.now)
        return apply(next, transitions: transitions)
    }

    /// Count-up only. Completes if long enough, otherwise records abandoned.
    @discardableResult
    func finishCountUp() -> FocusFlowEvent? {
        guard let session = activeSession, session.configuration.mode == .countUp else { return nil }
        let finished = timer.finishCountUp(session, at: clock.now)
        return settle(finished)
    }

    /// Ends early behind a confirmation in the UI. Grants no progression.
    @discardableResult
    func endEarly() -> FocusFlowEvent? {
        guard let session = activeSession else { return nil }
        let ended = timer.abandon(session, at: clock.now)
        return settle(ended)
    }

    /// Applies a new ambient mix to a running session (e.g. mute from the active screen).
    func applyMixToRunningSession(_ mix: AmbientMix) {
        audio.apply(mix)
        if let session = activeSession, session.state == .active, !mix.isSilent {
            audio.play()
        } else if mix.isSilent {
            audio.pause()
        }
    }

    // MARK: - Completion moment

    /// Clears the pending "What instead?" screen.
    func acknowledgeCompletion(returningToFocus: Bool) {
        var prefs = preferences.load()
        prefs.pendingCompletionSessionID = nil
        preferences.save(prefs)
        if returningToFocus {
            events.track(.returnedToFocus, EventProperties().userInitiated(true))
        }
    }

    func recordReturnToFocus() {
        events.track(.returnedToFocus, EventProperties().userInitiated(true))
    }

    // MARK: - Notifications

    /// Asks for notification permission once, at the first session start.
    /// Denial is fine: the in-app completion path never depends on it.
    @discardableResult
    func requestNotificationPermissionIfNeeded() async -> Bool {
        var prefs = preferences.load()
        if prefs.hasRequestedNotificationPermission {
            return prefs.notificationPermissionGranted ?? false
        }
        let status = await notifications.authorizationStatus()
        let granted: Bool
        switch status {
        case .granted:
            granted = true
        case .denied:
            granted = false
        case .notDetermined:
            granted = await notifications.requestAuthorization()
            events.track(.notificationPermissionResult, EventProperties().granted(granted).userInitiated(true))
        }
        prefs = preferences.load()
        prefs.hasRequestedNotificationPermission = true
        prefs.notificationPermissionGranted = granted
        preferences.save(prefs)
        scheduleNotifications()
        return granted
    }

    // MARK: - Internals

    private static func isTerminal(_ event: FocusFlowEvent) -> Bool {
        switch event {
        case .sessionCompleted, .sessionAbandoned: return true
        default: return false
        }
    }

    private func apply(_ session: FocusSession, transitions: [TimerTransition]) -> [FocusFlowEvent] {
        var flowEvents: [FocusFlowEvent] = []
        for transition in transitions {
            switch transition {
            case .phaseStarted(_, let kind, _):
                flowEvents.append(.phaseStarted(kind))
            case .awaitingNextPhase(_, let kind):
                flowEvents.append(.awaitingNextPhase(kind))
            case .phaseCompleted, .sessionCompleted:
                break
            }
        }

        if session.state.isLive {
            activeSession = session
            persist(session)
            if !transitions.isEmpty {
                scheduleNotifications()
                updateLiveActivity()
            }
            return flowEvents
        }

        if let terminal = settle(session) {
            flowEvents.append(terminal)
        }
        return flowEvents
    }

    /// Persists a finished session and releases every session resource.
    private func settle(_ session: FocusSession) -> FocusFlowEvent? {
        guard !session.state.isLive else {
            activeSession = session
            persist(session)
            return nil
        }
        persist(session)
        activeSession = nil

        notifications.cancelAll()
        audio.stop()
        blocking.sessionDidEnd(sessionID: session.id)
        liveActivity.end(sessionID: session.id)

        let base = EventProperties().timerMode(session.configuration.mode).preset(session.presetID)
        if session.state == .completed {
            if let id = session.taskID, var task = tasks.task(id: id) {
                task.completedSessionCount += 1
                task.attachedSessionID = session.id
                persistTask(task)
            }
            var prefs = preferences.load()
            prefs.pendingCompletionSessionID = session.id
            preferences.save(prefs)
            events.track(.focusCompleted, base.duration(session.completedFocusDuration))
            return .sessionCompleted(session.id)
        } else {
            let elapsed = (session.endedAt ?? clock.now).timeIntervalSince(session.startedAt)
            events.track(.focusAbandoned, base.duration(elapsed).userInitiated(true))
            return .sessionAbandoned(session.id)
        }
    }

    private func presetMix(for session: FocusSession) -> AmbientMix {
        presets.preset(id: session.presetID)?.ambientMix ?? .silent
    }

    private func scheduleNotifications() {
        guard let session = activeSession, session.state == .active else {
            notifications.cancelAll()
            return
        }
        let boundaries = timer.upcomingBoundaries(session, from: clock.now)
        if boundaries.isEmpty {
            notifications.cancelAll()
        } else {
            notifications.schedule(boundaries, sessionID: session.id)
        }
    }

    private func updateLiveActivity() {
        guard let session = activeSession else { return }
        let snapshot = timer.snapshot(of: session, at: clock.now)
        let sceneName = scenes.first { $0.id == session.sceneID }?.name ?? "Still"
        if let state = LiveActivityMapper.state(for: snapshot, sceneName: sceneName, now: clock.now) {
            liveActivity.startOrUpdate(sessionID: session.id, state: state)
        }
    }

    private func persist(_ session: FocusSession) {
        do {
            try sessions.save(session)
        } catch {
            onPersistenceError?(error)
        }
    }

    private func persistTask(_ task: TaskItem) {
        do {
            try tasks.save(task)
        } catch {
            onPersistenceError?(error)
        }
    }
}
