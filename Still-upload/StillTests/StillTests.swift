import XCTest
#if canImport(StillCore)
@testable import StillCore
#else
@testable import Still
#endif

/// A fixed Gregorian calendar in UTC so day boundaries are deterministic.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-03-10 09:00:00 UTC.
let referenceDate: Date = {
    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 10
    components.hour = 9
    return testCalendar.date(from: components)!
}()

func makeContainer(
    clock: ManualClock = ManualClock(referenceDate),
    notifications: RecordingNotificationScheduler = RecordingNotificationScheduler(authorization: .granted)
) -> DependencyContainer {
    DependencyContainer.inMemory(clock: clock, calendar: testCalendar, notifications: notifications)
}

func minutes(_ value: Double) -> TimeInterval { value * 60 }

extension TimerConfiguration {
    static func countdown(_ focusMinutes: Double) -> TimerConfiguration {
        var configuration = TimerConfiguration.standard
        configuration.mode = .countdown
        configuration.focusDuration = minutes(focusMinutes)
        return configuration
    }

    static func pomodoro(focus: Double, rest: Double, cycles: Int, autoBreaks: Bool = true, autoFocus: Bool = true) -> TimerConfiguration {
        TimerConfiguration(
            mode: .pomodoro,
            focusDuration: minutes(focus),
            breakDuration: minutes(rest),
            longBreakDuration: minutes(15),
            longBreakInterval: 0,
            cycleCount: cycles,
            autoStartBreaks: autoBreaks,
            autoStartFocus: autoFocus,
            routineID: nil
        )
    }

    static var countUp: TimerConfiguration {
        var configuration = TimerConfiguration.standard
        configuration.mode = .countUp
        return configuration
    }
}

func makeSession(_ configuration: TimerConfiguration, at date: Date = referenceDate, taskID: UUID? = nil) -> FocusSession {
    FocusTimerEngine().makeSession(
        id: UUID(),
        configuration: configuration,
        taskID: taskID,
        sceneID: .rainyBedroom,
        renderMode: .scene,
        presetID: .defaultPreset,
        source: .manual,
        at: date
    )
}

/// A completed session that ended at `end`.
func completedSession(endingAt end: Date, focusMinutes: Double = 25) -> FocusSession {
    let engine = FocusTimerEngine()
    let start = end.addingTimeInterval(-minutes(focusMinutes))
    let session = makeSession(.countdown(focusMinutes), at: start)
    return engine.advance(session, to: end).0
}

// MARK: - ActivityAndPersistenceTests

final class PuzzleTests: XCTestCase {
    func testBundledSudokuIsValidAndUnique() {
        let puzzle = BundledPuzzleLibrary.sudoku6
        XCTAssertEqual(puzzle.givens.count, 36)
        XCTAssertEqual(puzzle.solution.count, 36)
        for index in 0..<36 where puzzle.givens[index] != 0 {
            XCTAssertEqual(puzzle.givens[index], puzzle.solution[index], "given disagrees with solution at \(index)")
        }
        for index in 0..<36 {
            for peer in puzzle.peers(of: index) {
                XCTAssertNotEqual(puzzle.solution[index], puzzle.solution[peer])
            }
        }
        XCTAssertEqual(SudokuSolver.countSolutions(puzzle), 1)
    }

    func testSudokuGameplay() {
        var game = SudokuGame(puzzle: BundledPuzzleLibrary.sudoku6)
        XCTAssertFalse(game.hasProgress)

        let givenIndex = game.puzzle.givens.firstIndex { $0 != 0 }!
        game.select(givenIndex)
        XCTAssertFalse(game.enter(1), "givens are locked")

        let empty = game.puzzle.givens.firstIndex(of: 0)!
        game.select(empty)
        let peerValue = game.puzzle.peers(of: empty).compactMap { game.value(at: $0) }.first!
        XCTAssertTrue(game.enter(peerValue))
        XCTAssertFalse(game.conflictingIndices.isEmpty, "gentle conflict feedback")
        XCTAssertTrue(game.erase())

        for index in 0..<36 where game.puzzle.givens[index] == 0 {
            game.select(index)
            game.enter(game.puzzle.solution[index])
        }
        XCTAssertTrue(game.isSolved)
        XCTAssertTrue(game.conflictingIndices.isEmpty)
        game.select(empty)
        XCTAssertFalse(game.erase(), "finished puzzles are read-only")
    }

    func testBundledPicrossIsUnique() {
        let puzzle = BundledPuzzleLibrary.sprout
        XCTAssertEqual(puzzle.size, 5)
        XCTAssertEqual(puzzle.rowClues, [[1, 1], [1], [1], [5], [3]])
        XCTAssertEqual(puzzle.columnClues, [[1], [1, 2], [4], [1, 2], [1]])
        XCTAssertEqual(PicrossSolver.countSolutions(rowClues: puzzle.rowClues, columnClues: puzzle.columnClues, size: 5), 1)
    }

    func testPicrossGameplayIgnoresCrosses() {
        var game = PicrossGame(puzzle: BundledPuzzleLibrary.sprout)
        for index in game.puzzle.solution.indices {
            game.apply(game.puzzle.solution[index] ? .fill : .cross, at: index)
        }
        XCTAssertTrue(game.isSolved)
        XCTAssertTrue((0..<5).allSatisfy(game.isRowSatisfied))
    }

    func testPicrossToggle() {
        var game = PicrossGame(puzzle: BundledPuzzleLibrary.sprout)
        game.apply(.fill, at: 0)
        XCTAssertEqual(game.cells[0], .filled)
        game.apply(.fill, at: 0)
        XCTAssertEqual(game.cells[0], .empty)
        game.apply(.cross, at: 0)
        XCTAssertEqual(game.cells[0], .crossed)
    }

    func testWordSearchWordsAppearExactlyOnce() {
        let puzzle = BundledPuzzleLibrary.quietWords
        XCTAssertEqual(puzzle.rows.count, puzzle.size)
        XCTAssertTrue(puzzle.rows.allSatisfy { $0.count == puzzle.size })
        for word in puzzle.words {
            XCTAssertEqual(puzzle.occurrences(of: word).count, 1, word)
        }
    }

    func testWordSearchTapToSelectBothDirections() {
        let puzzle = BundledPuzzleLibrary.quietWords
        var game = WordSearchGame(puzzle: puzzle)
        for word in puzzle.words {
            let points = puzzle.occurrences(of: word)[0]
            let reversed = word == "TEA"
            _ = game.tap(reversed ? points.last! : points.first!)
            XCTAssertEqual(game.tap(reversed ? points.first! : points.last!), .found(word))
        }
        XCTAssertTrue(game.isSolved)
    }

    func testWordSearchRejectsNonLines() {
        var game = WordSearchGame(puzzle: BundledPuzzleLibrary.quietWords)
        _ = game.tap(GridPoint(row: 0, column: 0))
        XCTAssertEqual(game.tap(GridPoint(row: 1, column: 2)), .noMatch)
        XCTAssertEqual(game.tap(GridPoint(row: 3, column: 3)), .startedSelection(GridPoint(row: 3, column: 3)))
        XCTAssertEqual(game.tap(GridPoint(row: 3, column: 3)), .cleared)
    }

    func testPuzzleProgressSurvivesLeaving() throws {
        let container = makeContainer()
        var game = SudokuGame(puzzle: BundledPuzzleLibrary.sudoku6)
        let empty = game.puzzle.givens.firstIndex(of: 0)!
        game.select(empty)
        game.enter(game.puzzle.solution[empty])
        try container.puzzleProgress.save(game, puzzleID: game.puzzle.id, at: referenceDate)
        let loaded = container.puzzleProgress.load(SudokuGame.self, puzzleID: game.puzzle.id)
        XCTAssertEqual(loaded?.value(at: empty), game.puzzle.solution[empty])
    }
}

final class GuidedActivityTests: XCTestCase {
    func testBoxBreathingCycle() {
        let pattern = BreathingPattern.box
        XCTAssertEqual(pattern.totalDuration, 120)
        XCTAssertEqual(pattern.state(at: 0).label, "Inhale")
        XCTAssertEqual(pattern.state(at: 4).label, "Hold")
        XCTAssertEqual(pattern.state(at: 9).label, "Exhale")
        XCTAssertEqual(pattern.state(at: 13).label, "Hold")
        XCTAssertEqual(pattern.state(at: 17).label, "Inhale")
        XCTAssertEqual(pattern.state(at: 2).stepProgress, 0.5, accuracy: 0.0001)
        XCTAssertTrue(pattern.state(at: 120).isFinished)
        XCTAssertEqual(pattern.state(at: 60).remaining, 60)
    }

    func testStretchRoutineIsFourStepsWithSafetyNote() {
        let routine = StretchRoutine.desk
        XCTAssertEqual(routine.steps.count, 4)
        XCTAssertTrue(routine.safetyNote.contains("Stop if anything hurts"))
        XCTAssertTrue(routine.steps.allSatisfy { $0.duration > 0 })
    }

    func testActivityCountdown() {
        let countdown = ActivityCountdown(startedAt: referenceDate, duration: 60)
        XCTAssertEqual(countdown.remaining(at: referenceDate.addingTimeInterval(20)), 40)
        XCTAssertTrue(countdown.isFinished(at: referenceDate.addingTimeInterval(61)))
    }

    func testShortReadsHaveProvenanceAndEnd() {
        let library = BundledReadingLibrary()
        XCTAssertGreaterThanOrEqual(library.allItems().count, 3)
        for item in library.allItems() {
            XCTAssertFalse(item.title.isEmpty)
            XCTAssertFalse(item.author.isEmpty)
            XCTAssertFalse(item.licenseNote.isEmpty)
            XCTAssertEqual(item.license, .originalForStill)
            XCTAssertGreaterThanOrEqual(item.readMinutes, 1)
            XCTAssertLessThanOrEqual(item.readMinutes, 5, "short reads stay short")
        }
    }

    func testCreativePromptRotatesDaily() {
        let today = CreativePromptLibrary.prompt(for: referenceDate, calendar: testCalendar)
        let tomorrow = CreativePromptLibrary.prompt(for: referenceDate.addingTimeInterval(86_400), calendar: testCalendar)
        XCTAssertNotEqual(today.id, tomorrow.id)
    }

    func testCatalogHasEveryV1Activity() {
        let ids = Set(ActivityCatalog.available.map(\.id))
        XCTAssertEqual(ids, [.sudoku, .picross, .wordSearch, .shortRead, .creativePrompt, .brainDump, .guidedStretch, .boxBreathing, .doNothing])
        XCTAssertEqual(ActivityCatalog.grouped().map(\.category), [.puzzle, .quiet, .reset])
    }
}

final class BreakFlowTests: XCTestCase {
    func testUsageLifecycleIsPersistedAndIdempotent() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        let usage = container.breaks.begin(.doNothing, context: .shelf)
        XCTAssertEqual(container.breaks.usedToday(), [.doNothing])
        clock.advance(by: 60)
        container.breaks.finish(usageID: usage.id, outcome: .completed)
        container.breaks.finish(usageID: usage.id, outcome: .abandoned)
        let stored = container.usages.usage(id: usage.id)!
        XCTAssertEqual(stored.outcome, .completed)
        XCTAssertEqual(stored.endedAt, referenceDate.addingTimeInterval(60))

        clock.advance(by: 86_400)
        XCTAssertTrue(container.breaks.usedToday().isEmpty, "yesterday's use doesn't block today's suggestions")
    }

    func testStaleUsagesCloseAsAbandoned() {
        let container = makeContainer()
        let usage = container.breaks.begin(.sudoku, context: .shelf)
        container.breaks.closeStaleUsages()
        XCTAssertEqual(container.usages.usage(id: usage.id)?.outcome, .abandoned)
    }

    func testNotesSaveTrimmedAndSkipEmpty() {
        let container = makeContainer()
        XCTAssertNil(container.breaks.saveNote(text: "   ", kind: .brainDump, activityID: .brainDump, promptID: nil))
        let note = container.breaks.saveNote(text: "  groceries, call back  ", kind: .brainDump, activityID: .brainDump, promptID: nil)
        XCTAssertEqual(note?.text, "groceries, call back")
        XCTAssertEqual(container.breaks.recentNotes(kind: .brainDump).count, 1)
        XCTAssertTrue(container.breaks.recentNotes(kind: .creativeResponse).isEmpty)

        // Autosave updates the same note in place, then clearing removes it.
        let edited = container.breaks.saveNote(text: "groceries, call back, laundry", kind: .brainDump,
                                               activityID: .brainDump, promptID: nil, existingID: note?.id)
        XCTAssertEqual(edited?.id, note?.id)
        XCTAssertEqual(edited?.createdAt, note?.createdAt)
        XCTAssertEqual(container.breaks.recentNotes(kind: .brainDump).count, 1)
        container.breaks.deleteNote(id: note!.id)
        XCTAssertTrue(container.breaks.recentNotes(kind: .brainDump).isEmpty)
    }
}

final class PersistenceTests: XCTestCase {
    func testPreferencesDecodeWithMissingKeys() throws {
        let data = Data(#"{"hasCompletedOnboarding": true, "onboardingGoal": "scrollLess"}"#.utf8)
        let prefs = try RecordCoding.decoder().decode(UserPreferences.self, from: data)
        XCTAssertTrue(prefs.hasCompletedOnboarding)
        XCTAssertEqual(prefs.onboardingGoal, .scrollLess)
        XCTAssertEqual(prefs.defaultPresetID, .defaultPreset)
        XCTAssertEqual(prefs.animationIntensity, .full)
    }

    func testPreferencesTolerateUnknownEnumValues() throws {
        let data = Data(#"{"onboardingGoal": "somethingNew", "animationIntensity": "wild"}"#.utf8)
        let prefs = try RecordCoding.decoder().decode(UserPreferences.self, from: data)
        XCTAssertNil(prefs.onboardingGoal)
        XCTAssertEqual(prefs.animationIntensity, .full)
    }

    func testOnboardingPersonalizesPresetsWithoutLockingIn() {
        let container = makeContainer()
        container.preferences.completeOnboarding(goal: .calmerPhone)
        let preset = container.preferences.preset(.defaultPreset)
        XCTAssertEqual(preset.renderMode, .calm)
        XCTAssertTrue(preset.ambientMix.isSilent)
        XCTAssertEqual(preset.timer.focusDuration, minutes(25), "lands on a 25-minute default")
        XCTAssertTrue(container.preferencesStore.load().hasCompletedOnboarding)

        // The user can still change anything.
        var edited = preset
        edited.renderMode = .scene
        container.preferences.save(edited)
        XCTAssertEqual(container.preferences.preset(.defaultPreset).renderMode, .scene)

        container.preferences.resetOnboarding()
        XCTAssertFalse(container.preferencesStore.load().hasCompletedOnboarding)
    }

    func testPresetEditsAreValidated() {
        let container = makeContainer()
        var preset = container.preferences.preset(.study)
        preset.timer.cycleCount = 99
        container.preferences.save(preset)
        XCTAssertEqual(container.preferences.preset(.study).timer.cycleCount, TimerConfiguration.cycleRange.upperBound)
    }

    func testResetAllDataClearsEverything() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        PreviewFixtures.populate(container)
        XCTAssertFalse(container.sessions.allSessions().isEmpty)
        container.preferences.resetAllData()
        XCTAssertTrue(container.sessions.allSessions().isEmpty)
        XCTAssertTrue(container.tasks.allTasks().isEmpty)
        XCTAssertTrue(container.usages.allUsages().isEmpty)
        XCTAssertFalse(container.preferencesStore.load().hasCompletedOnboarding)
        XCTAssertTrue(container.events.recentEvents.isEmpty)
    }

    func testCorruptRecordsAreSkipped() throws {
        let store = InMemoryRecordStore()
        try store.upsert(StoredRecord(id: "bad", kind: .session, createdAt: referenceDate, updatedAt: referenceDate,
                                      schemaVersion: 1, payload: Data("not json".utf8)))
        let repository = StoredSessionRepository(store: store)
        try repository.save(completedSession(endingAt: referenceDate))
        XCTAssertEqual(repository.allSessions().count, 1)
    }

    func testWriteFailureIsReportedNotFatal() {
        let store = InMemoryRecordStore()
        let container = DependencyContainer(
            clock: ManualClock(referenceDate), calendar: testCalendar, recordStore: store,
            keyValueStore: InMemoryKeyValueStore(), notifications: RecordingNotificationScheduler(),
            audio: SilentAmbientAudioPlayer(), blocking: MockFocusBlockingService(), liveActivity: NoopLiveActivityUpdater()
        )
        var reported = 0
        container.focus.onPersistenceError = { _ in reported += 1 }
        store.failsWrites = true
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        XCTAssertEqual(reported, 1)
        XCTAssertNotNil(container.focus.activeSession, "the session keeps running in memory")
    }

    func testJournalRepositoryIsReadyForV11() throws {
        let container = makeContainer()
        try container.journal.save(JournalEntry(id: UUID(), day: testCalendar.startOfDay(for: referenceDate),
                                                createdAt: referenceDate, text: "Quiet day.", mood: .calm))
        XCTAssertEqual(container.journal.allEntries().first?.mood, .calm)
    }

    func testFixturesProduceMeaningfulStats() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        PreviewFixtures.populate(container)
        let stats = StatsCalculator(calendar: testCalendar).stats(sessions: container.sessions.allSessions(),
                                                                  usages: container.usages.allUsages(), now: clock.now)
        XCTAssertEqual(stats.completedSessions, 9)
        XCTAssertGreaterThan(stats.currentStreak, 0)
        XCTAssertFalse(stats.activityUsage.isEmpty)
    }
}

// MARK: - AppFlowTests

/// End-to-end checks of the primary loop at the app-state level:
/// onboarding → Focus → complete → "What instead?" → activity → Focus.
final class AppFlowTests: XCTestCase {
    var clock: ManualClock!
    var state: AppState!

    override func setUp() {
        super.setUp()
        clock = ManualClock(referenceDate)
        state = AppState(container: makeContainer(clock: clock))
        state.bootstrap()
    }

    func testOnboardingLandsOnFocusWithTwentyFiveMinuteDefault() {
        XCTAssertFalse(state.preferences.hasCompletedOnboarding)
        state.completeOnboarding(goal: .scrollLess)
        XCTAssertTrue(state.preferences.hasCompletedOnboarding)
        XCTAssertEqual(state.router.selectedTab, .focus)
        XCTAssertEqual(state.currentPreset.timer.focusDuration, minutes(25))
        XCTAssertEqual(state.personalization.categoryOrder.first, .puzzle)
    }

    func testPrimaryLoop() {
        state.completeOnboarding(goal: .focusBetter)
        let task = state.createTask(title: "Biology homework")!
        XCTAssertEqual(state.selectedTask?.id, task.id, "new tasks are selected for the next session")

        state.startFocus()
        let sessionID = try! XCTUnwrap(state.activeSession?.id)
        XCTAssertEqual(state.activeSession?.taskID, task.id)

        // Background for the whole session, then return.
        clock.advance(by: minutes(26))
        state.handleBecameActive()
        XCTAssertNil(state.activeSession)
        XCTAssertEqual(state.router.completion?.sessionID, sessionID)

        let suggestions = state.suggestions(for: sessionID)
        XCTAssertEqual(suggestions.activities.count, 3)
        XCTAssertEqual(state.suggestions(for: sessionID), suggestions, "stable while the screen is open")

        let pick = suggestions.activities[1]
        state.openSuggestion(pick, rank: 1, sessionID: sessionID)
        XCTAssertNil(state.router.completion)
        XCTAssertNil(state.preferences.pendingCompletionSessionID)
        XCTAssertEqual(state.router.selectedTab, .breakShelf)
        XCTAssertEqual(state.router.breakPath, [.breakActivity(pick.id, ActivityContext(entryPoint: .suggestion, sessionID: sessionID, suggestionRank: 1))])

        let usage = state.beginActivity(pick.id, context: ActivityContext(entryPoint: .suggestion, sessionID: sessionID, suggestionRank: 1))
        clock.advance(by: 90)
        state.finishActivity(usage.id, outcome: .completed)
        XCTAssertTrue(state.usedToday(pick.id))

        state.returnToFocusFromActivity()
        XCTAssertEqual(state.router.selectedTab, .focus)
        XCTAssertTrue(state.router.breakPath.isEmpty)

        XCTAssertEqual(state.stats.completedSessions, 1)
        XCTAssertEqual(state.stats.activitiesCompleted, 1)
        let names = state.container.events.recentEvents.map(\.name)
        XCTAssertTrue(names.contains(.breakSuggestionsPresented))
        XCTAssertEqual(names.last, .returnedToFocus)
        XCTAssertEqual(names.filter { $0 == .breakSuggestionsPresented }.count, 1)
    }

    func testSeeAllOpensShelfAndReturnToFocusClosesCompletion() {
        state.completeOnboarding(goal: .focusBetter)
        state.startFocus()
        clock.advance(by: minutes(25))
        state.tick()
        let id = try! XCTUnwrap(state.router.completion?.sessionID)
        state.openShelfFromCompletion()
        XCTAssertEqual(state.router.selectedTab, .breakShelf)
        XCTAssertTrue(state.router.breakPath.isEmpty)
        XCTAssertNil(state.router.completion)

        state.router.go(to: .sessionComplete(id))
        state.returnToFocusFromCompletion()
        XCTAssertEqual(state.router.selectedTab, .focus)
        XCTAssertNil(state.router.completion)
    }

    func testPendingCompletionReopensAfterRelaunch() {
        state.completeOnboarding(goal: .focusBetter)
        state.startFocus()
        let id = state.activeSession!.id
        clock.advance(by: minutes(40))

        let relaunched = AppState(container: DependencyContainer(
            clock: clock, calendar: testCalendar,
            recordStore: state.container.recordStore, keyValueStore: state.container.keyValueStore,
            notifications: RecordingNotificationScheduler(), audio: SilentAmbientAudioPlayer(),
            blocking: MockFocusBlockingService(), liveActivity: NoopLiveActivityUpdater()))
        relaunched.bootstrap()
        XCTAssertEqual(relaunched.router.completion?.sessionID, id)
    }

    func testDeepLinksAndFocusCardSimulator() {
        state.handle(url: URL(string: "still://start-focus?preset=study")!)
        XCTAssertNil(state.activeSession, "links wait until onboarding is finished")
        XCTAssertNotNil(state.notice)

        state.completeOnboarding(goal: .focusBetter)
        state.handle(url: URL(string: "still://start-focus?preset=study")!)
        XCTAssertEqual(state.activeSession?.presetID, .study)
        XCTAssertEqual(state.activeSession?.source, .deepLink)

        state.simulateFocusCard(presetID: .defaultPreset)
        XCTAssertEqual(state.activeSession?.presetID, .study, "a running session is left alone")
        XCTAssertEqual(state.notice?.text, "A session is already running. It's still going.")

        state.endSessionEarly()
        state.simulateFocusCard(presetID: .defaultPreset)
        XCTAssertEqual(state.activeSession?.presetID, .defaultPreset)
        XCTAssertEqual(state.activeSession?.source, .nfcSimulator)
        XCTAssertEqual(state.container.events.recentEvents.filter { $0.name == .nfcPresetRouted }.count, 3)
    }

    func testMuteIsTransientAndEndingEarlyReturnsHome() {
        state.completeOnboarding(goal: .focusBetter)
        state.startFocus()
        state.toggleMute()
        XCTAssertTrue(state.isAudioMuted)
        XCTAssertFalse(state.container.audio.isPlaying)
        state.endSessionEarly()
        XCTAssertFalse(state.isAudioMuted)
        XCTAssertNil(state.activeSession)
        XCTAssertNil(state.router.completion, "ended sessions don't open the completion screen")
        XCTAssertEqual(state.stats.completedSessions, 0)
    }

    func testSceneUnlockIsNoticedOnceThenAcknowledged() {
        state.completeOnboarding(goal: .focusBetter)
        for _ in 0..<7 {
            state.startFocus()
            clock.advance(by: minutes(25))
            state.tick()
            state.returnToFocusFromCompletion()
        }
        XCTAssertEqual(state.newlyUnlockedScenes.map(\.id), [.libraryLight])
        state.acknowledgeUnlockedScenes()
        XCTAssertTrue(state.newlyUnlockedScenes.isEmpty)
    }

    func testResetAllDataReturnsToOnboarding() {
        state.completeOnboarding(goal: .focusBetter)
        state.createTask(title: "Something")
        state.startFocus()
        state.resetAllData()
        XCTAssertFalse(state.preferences.hasCompletedOnboarding)
        XCTAssertNil(state.activeSession)
        XCTAssertTrue(state.todaysTasks.isEmpty)
        XCTAssertTrue(state.sessions.isEmpty)
    }

    func testPreviewStatesBuild() {
        XCTAssertNotNil(PreviewSupport.appState(activeSession: true).activeSession)
        XCTAssertEqual(PreviewSupport.appState(populated: true).stats.completedSessions, 9)
        let completed = PreviewSupport.completedSession()
        XCTAssertEqual(completed.state.suggestions(for: completed.sessionID).activities.count, 3)
    }
}

// MARK: - BreakSuggestionEngineTests

final class BreakSuggestionEngineTests: XCTestCase {
    let engine = BreakSuggestionEngine()

    func request(
        breakMinutes: Double = 5,
        usedToday: Set<BreakActivityID> = [],
        lastUsed: [BreakActivityID: Date] = [:],
        order: [ActivityCategory] = [.reset, .puzzle, .quiet],
        seed: Int = 0
    ) -> BreakSuggestionRequest {
        BreakSuggestionRequest(
            availableBreak: minutes(breakMinutes),
            catalog: ActivityCatalog.all,
            usedToday: usedToday,
            lastUsedAt: lastUsed,
            categoryOrder: order,
            daySeed: seed
        )
    }

    func testAlwaysExactlyThree() {
        for breakMinutes in [0.5, 1, 2, 5, 10, 30] {
            for seed in 0..<10 {
                let result = engine.suggestions(for: request(breakMinutes: breakMinutes, seed: seed))
                XCTAssertEqual(result.activities.count, 3, "break \(breakMinutes) seed \(seed)")
                XCTAssertEqual(Set(result.activities.map(\.id)).count, 3, "no duplicates")
            }
        }
    }

    func testThreeDifferentCategoriesWhenPossible() {
        let result = engine.suggestions(for: request(breakMinutes: 10))
        XCTAssertEqual(Set(result.activities.map(\.category)).count, 3)
        XCTAssertEqual(result.activities.map(\.category), [.reset, .puzzle, .quiet], "follows personalized order")
    }

    func testPersonalizedOrderChangesFirstCategory() {
        let result = engine.suggestions(for: request(breakMinutes: 10, order: [.puzzle, .quiet, .reset]))
        XCTAssertEqual(result.activities.first?.category, .puzzle)
    }

    func testActivitiesUsedTodayAreSkipped() {
        let used: Set<BreakActivityID> = [.boxBreathing, .brainDump, .sudoku, .shortRead]
        let result = engine.suggestions(for: request(breakMinutes: 10, usedToday: used))
        XCTAssertEqual(result.activities.count, 3)
        XCTAssertTrue(result.activities.allSatisfy { !used.contains($0.id) })
        XCTAssertFalse(result.isRevisit)
    }

    func testShortBreakPrefersActivitiesThatFit() {
        let result = engine.suggestions(for: request(breakMinutes: 2))
        XCTAssertTrue(result.activities.allSatisfy { $0.estimatedDuration <= minutes(2) })
    }

    func testVeryShortBreakFillsWithShortestActivities() {
        let result = engine.suggestions(for: request(breakMinutes: 1))
        XCTAssertEqual(result.activities.count, 3)
        XCTAssertTrue(result.activities.contains { $0.id == .doNothing })
        XCTAssertTrue(result.activities.allSatisfy { $0.estimatedDuration <= minutes(3) })
    }

    func testFallbackWhenEverythingWasUsedToday() {
        let all = Set(ActivityCatalog.all.map(\.id))
        let lastUsed: [BreakActivityID: Date] = [
            .doNothing: referenceDate.addingTimeInterval(-60),
            .boxBreathing: referenceDate.addingTimeInterval(-7200),
            .guidedStretch: referenceDate.addingTimeInterval(-3600)
        ]
        let result = engine.suggestions(for: request(breakMinutes: 2, usedToday: all, lastUsed: lastUsed))
        XCTAssertTrue(result.isRevisit)
        XCTAssertEqual(result.activities.count, 3)
        XCTAssertEqual(result.headline, "You've tried everything today. A few to revisit:")
        // Least recently used first.
        XCTAssertEqual(result.activities.map(\.id), [.boxBreathing, .guidedStretch, .doNothing])
    }

    func testPartialFreshListIsToppedUpWithUsedActivities() {
        let used = Set(ActivityCatalog.all.map(\.id)).subtracting([.picross])
        let result = engine.suggestions(for: request(breakMinutes: 10, usedToday: used))
        XCTAssertEqual(result.activities.count, 3)
        XCTAssertEqual(result.activities.first?.id, .picross)
        XCTAssertFalse(result.isRevisit)
    }

    func testDaySeedRotatesWithinCategory() {
        let dayOne = engine.suggestions(for: request(breakMinutes: 10, seed: 0))
        let dayTwo = engine.suggestions(for: request(breakMinutes: 10, seed: 1))
        XCTAssertNotEqual(dayOne.activities.map(\.id), dayTwo.activities.map(\.id))
    }

    func testPlannedActivitiesAreNeverSuggested() {
        var catalog = ActivityCatalog.all
        catalog.append(BreakActivity(id: BreakActivityID("doodle"), name: "Doodle", category: .quiet, summary: "",
                                     estimatedDuration: 60, implementationState: .planned, symbolName: "pencil", sortOrder: -1))
        var req = request(breakMinutes: 10, order: [.quiet])
        req.catalog = catalog
        let result = engine.suggestions(for: req)
        XCTAssertFalse(result.activities.contains { $0.id == BreakActivityID("doodle") })
    }

    func testControllerUsesSessionBreakAndUsageHistory() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        container.breaks.begin(.boxBreathing, context: .shelf)
        let session = makeSession(.pomodoro(focus: 25, rest: 2, cycles: 2))
        let result = container.breaks.suggestions(after: session, personalization: Personalization(goal: .calmerPhone), trackPresentation: false)
        XCTAssertEqual(result.availableBreak, minutes(2))
        XCTAssertFalse(result.activities.contains { $0.id == .boxBreathing }, "a fresh activity beats a repeat")
        XCTAssertEqual(result.activities.count, 3)
        XCTAssertFalse(result.isRevisit)
    }
}

// MARK: - FocusFlowControllerTests

final class FocusFlowControllerTests: XCTestCase {
    var clock: ManualClock!
    var notifications: RecordingNotificationScheduler!
    var container: DependencyContainer!

    override func setUp() {
        super.setUp()
        clock = ManualClock(referenceDate)
        notifications = RecordingNotificationScheduler(authorization: .granted)
        container = makeContainer(clock: clock, notifications: notifications)
        container.preferences.completeOnboarding(goal: .focusBetter)
    }

    // MARK: Completion vs abandonment

    func testCompletedSessionCountsAndOpensCompletionMoment() {
        let outcome = container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        guard case .started(let session) = outcome else { return XCTFail("expected start") }

        clock.advance(by: minutes(25))
        let events = container.focus.tick()

        XCTAssertEqual(events, [.sessionCompleted(session.id)])
        XCTAssertNil(container.focus.activeSession)
        XCTAssertEqual(container.sessions.session(id: session.id)?.state, .completed)
        XCTAssertEqual(container.focus.completedSessionCount, 1)
        XCTAssertEqual(container.preferencesStore.load().pendingCompletionSessionID, session.id)
        XCTAssertTrue(notifications.scheduled.isEmpty, "reminders are cleared at completion")
    }

    func testEndingEarlyIsAbandonedAndGrantsNoProgress() {
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        clock.advance(by: minutes(20))
        let event = container.focus.endEarly()

        guard case .sessionAbandoned(let id)? = event else { return XCTFail("expected abandoned") }
        XCTAssertEqual(container.sessions.session(id: id)?.state, .abandoned)
        XCTAssertEqual(container.focus.completedSessionCount, 0)
        XCTAssertNil(container.preferencesStore.load().pendingCompletionSessionID)

        let stats = StatsCalculator(calendar: testCalendar).stats(
            sessions: container.sessions.allSessions(), usages: [], now: clock.now)
        XCTAssertEqual(stats.completedSessions, 0)
        XCTAssertEqual(stats.totalFocus, 0)
        XCTAssertEqual(stats.currentStreak, 0)
    }

    func testPauseResumePersistsAndReschedules() {
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        XCTAssertEqual(notifications.scheduled.count, 1)

        clock.advance(by: minutes(5))
        container.focus.pause()
        XCTAssertEqual(container.sessions.liveSession()?.state, .paused)
        XCTAssertTrue(notifications.scheduled.isEmpty)
        XCTAssertFalse(container.audio.isPlaying)

        clock.advance(by: minutes(30))
        container.focus.resume()
        XCTAssertEqual(container.sessions.liveSession()?.state, .active)
        XCTAssertEqual(notifications.scheduled.first?.date, clock.now.addingTimeInterval(minutes(20)))
        XCTAssertEqual(container.focus.snapshot()?.remainingInPhase, minutes(20))
    }

    // MARK: Relaunch

    func testRestoreAfterRelaunchCompletesOverdueSession() {
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        let sessionID = container.focus.activeSession!.id

        // Simulate a cold launch 40 minutes later: a new controller, same storage.
        clock.advance(by: minutes(40))
        let relaunched = DependencyContainer(
            clock: clock, calendar: testCalendar,
            recordStore: container.recordStore, keyValueStore: container.keyValueStore,
            notifications: notifications, audio: SilentAmbientAudioPlayer(),
            blocking: MockFocusBlockingService(), liveActivity: NoopLiveActivityUpdater()
        )
        let events = relaunched.focus.restore()
        XCTAssertEqual(events, [.sessionCompleted(sessionID)])
        let stored = relaunched.sessions.session(id: sessionID)
        XCTAssertEqual(stored?.endedAt, referenceDate.addingTimeInterval(minutes(25)))
        XCTAssertEqual(relaunched.preferencesStore.load().pendingCompletionSessionID, sessionID)
    }

    func testRestoreKeepsPausedSessionPaused() {
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        clock.advance(by: minutes(10))
        container.focus.pause()

        clock.advance(by: minutes(300))
        let relaunched = DependencyContainer(
            clock: clock, calendar: testCalendar,
            recordStore: container.recordStore, keyValueStore: container.keyValueStore,
            notifications: notifications, audio: SilentAmbientAudioPlayer(),
            blocking: MockFocusBlockingService(), liveActivity: NoopLiveActivityUpdater()
        )
        XCTAssertTrue(relaunched.focus.restore().isEmpty)
        XCTAssertEqual(relaunched.focus.snapshot()?.state, .paused)
        XCTAssertEqual(relaunched.focus.snapshot()?.remainingInPhase, minutes(15))
    }

    // MARK: Tasks

    func testTaskIsAttachedToSessionAndCountedOnCompletion() {
        let task = container.taskController.create(title: "  Biology   homework ")!
        XCTAssertEqual(task.title, "Biology homework")

        let outcome = container.focus.start(presetID: .defaultPreset, taskID: task.id, source: .manual)
        XCTAssertEqual(outcome.session.taskID, task.id)
        XCTAssertEqual(container.tasks.task(id: task.id)?.attachedSessionID, outcome.session.id)

        clock.advance(by: minutes(25))
        container.focus.tick()
        let updated = container.tasks.task(id: task.id)!
        XCTAssertEqual(updated.completedSessionCount, 1)
        XCTAssertFalse(updated.isCompleted, "finishing a session does not mark the task done")

        container.taskController.setCompleted(id: task.id, true)
        XCTAssertTrue(container.tasks.task(id: task.id)!.isCompleted)
    }

    func testCompletedTaskIsNotAttachedToNewSession() {
        let task = container.taskController.create(title: "Done already")!
        container.taskController.setCompleted(id: task.id, true)
        let outcome = container.focus.start(presetID: .defaultPreset, taskID: task.id, source: .manual)
        XCTAssertNil(outcome.session.taskID)
    }

    func testAbandonedSessionDoesNotCountForTask() {
        let task = container.taskController.create(title: "Essay")!
        container.focus.start(presetID: .defaultPreset, taskID: task.id, source: .manual)
        clock.advance(by: minutes(3))
        container.focus.endEarly()
        XCTAssertEqual(container.tasks.task(id: task.id)?.completedSessionCount, 0)
    }

    func testBlankTaskTitleIsRejected() {
        XCTAssertNil(container.taskController.create(title: "   \n "))
        XCTAssertTrue(container.tasks.allTasks().isEmpty)
    }

    func testTodaysTasksShowsOpenThenDoneToday() {
        let a = container.taskController.create(title: "A")!
        clock.advance(by: 60)
        let b = container.taskController.create(title: "B")!
        container.taskController.setCompleted(id: a.id, true)
        XCTAssertEqual(container.taskController.todaysTasks().map(\.id), [b.id, a.id])

        clock.advance(by: 2 * 86_400)
        XCTAssertEqual(container.taskController.todaysTasks().map(\.id), [b.id], "done tasks from other days drop off")
    }

    // MARK: Presets and routing

    func testStudyPresetStartsPomodoroInCalmMode() {
        let outcome = container.focus.start(presetID: .study, taskID: nil, source: .deepLink)
        XCTAssertEqual(outcome.session.configuration.mode, .pomodoro)
        XCTAssertEqual(outcome.session.configuration.focusDuration, minutes(50))
        XCTAssertEqual(outcome.session.renderMode, .calm)
        XCTAssertEqual(outcome.session.presetID, .study)
        XCTAssertEqual((container.blocking as? MockFocusBlockingService)?.recordedIntents[outcome.session.id], .soft)
        XCTAssertFalse(container.blocking.isShielding, "the V1 mock never claims to shield apps")
    }

    func testUnknownPresetFallsBackToDefault() {
        let outcome = container.focus.start(presetID: FocusPresetID("nope"), taskID: nil, source: .deepLink)
        guard case .startedWithFallback(let session, let requested) = outcome else { return XCTFail() }
        XCTAssertEqual(session.presetID, .defaultPreset)
        XCTAssertEqual(requested, FocusPresetID("nope"))
    }

    func testSecondStartLeavesRunningSessionAlone() {
        let first = container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual).session
        let second = container.focus.start(presetID: .study, taskID: nil, source: .nfcSimulator)
        XCTAssertEqual(second, .alreadyRunning(first))
        XCTAssertEqual(container.sessions.allSessions().count, 1)
    }

    func testLockedSceneFallsBackToUnlockedScene() {
        var preset = container.preferences.preset(.defaultPreset)
        preset.sceneID = .nightCity
        container.preferences.save(preset)
        let session = container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual).session
        XCTAssertEqual(session.sceneID, .rainyBedroom)
    }

    // MARK: Notifications

    func testNotificationPermissionDeniedStillCompletesInApp() async {
        let denied = RecordingNotificationScheduler(authorization: .notDetermined, grantsOnRequest: false)
        let container = makeContainer(clock: clock, notifications: denied)
        container.preferences.completeOnboarding(goal: .scrollLess)

        let session = container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual).session
        let granted = await container.focus.requestNotificationPermissionIfNeeded()
        XCTAssertFalse(granted)
        XCTAssertTrue(denied.scheduled.isEmpty)
        XCTAssertEqual(container.preferencesStore.load().notificationPermissionGranted, false)
        XCTAssertEqual(container.events.recentEvents.last?.name, .notificationPermissionResult)

        // Asked only once.
        _ = await container.focus.requestNotificationPermissionIfNeeded()
        XCTAssertEqual(denied.requestCount, 1)

        clock.advance(by: minutes(25))
        XCTAssertEqual(container.focus.tick(), [.sessionCompleted(session.id)])
    }

    func testGrantedPermissionSchedulesPhaseEnd() async {
        let fresh = RecordingNotificationScheduler(authorization: .notDetermined, grantsOnRequest: true)
        let container = makeContainer(clock: clock, notifications: fresh)
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        XCTAssertTrue(fresh.scheduled.isEmpty, "nothing scheduled before permission")
        _ = await container.focus.requestNotificationPermissionIfNeeded()
        XCTAssertEqual(fresh.scheduled.map(\.date), [referenceDate.addingTimeInterval(minutes(25))])
    }

    // MARK: Events

    func testFunnelEventsAreRecordedInOrder() {
        let session = container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual).session
        clock.advance(by: minutes(25))
        container.focus.tick()
        let suggestions = container.breaks.suggestions(after: container.sessions.session(id: session.id),
                                                       personalization: Personalization(goal: .focusBetter),
                                                       trackPresentation: true)
        let usage = container.breaks.begin(suggestions.activities[0].id,
                                           context: ActivityContext(entryPoint: .suggestion, sessionID: session.id, suggestionRank: 0))
        clock.advance(by: 90)
        container.breaks.finish(usageID: usage.id, outcome: .completed)
        container.focus.acknowledgeCompletion(returningToFocus: true)

        let names = container.events.recentEvents.map(\.name)
        XCTAssertEqual(names, [
            .onboardingCompleted, .focusStarted, .focusCompleted, .breakSuggestionsPresented,
            .breakActivityStarted, .breakActivityCompleted, .returnedToFocus
        ])
    }
}

// MARK: - FocusTimerEngineTests

final class FocusTimerEngineTests: XCTestCase {
    let engine = FocusTimerEngine()

    // MARK: Countdown

    func testCountdownRemainingDerivesFromDates() {
        let session = makeSession(.countdown(25))
        let snapshot = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(minutes(10)))
        XCTAssertEqual(snapshot.remainingInPhase, minutes(15))
        XCTAssertEqual(snapshot.elapsedInPhase, minutes(10))
        XCTAssertEqual(snapshot.phaseEndDate, referenceDate.addingTimeInterval(minutes(25)))
        XCTAssertEqual(snapshot.phaseProgress!, 0.4, accuracy: 0.0001)
        XCTAssertTrue(snapshot.isRunning)
    }

    func testCountdownCompletesAtExactEndDateEvenWhenCheckedLate() {
        let session = makeSession(.countdown(25))
        // App was in the background for two hours.
        let (advanced, transitions) = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(120)))
        XCTAssertEqual(advanced.state, .completed)
        XCTAssertEqual(advanced.endedAt, referenceDate.addingTimeInterval(minutes(25)))
        XCTAssertEqual(advanced.completedFocusDuration, minutes(25))
        XCTAssertEqual(transitions.last, .sessionCompleted(at: referenceDate.addingTimeInterval(minutes(25))))
    }

    func testCountdownNotCompleteOneSecondEarly() {
        let session = makeSession(.countdown(25))
        let (advanced, transitions) = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(25) - 1))
        XCTAssertEqual(advanced.state, .active)
        XCTAssertTrue(transitions.isEmpty)
    }

    // MARK: Pause / resume

    func testPauseFreezesAndResumeContinues() {
        var session = makeSession(.countdown(25))
        session = engine.pause(session, at: referenceDate.addingTimeInterval(minutes(5))).0
        XCTAssertEqual(session.state, .paused)
        XCTAssertEqual(session.pauseCount, 1)

        // Paused for an hour: remaining time does not move.
        let whilePaused = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(minutes(65)))
        XCTAssertEqual(whilePaused.remainingInPhase, minutes(20))
        XCTAssertNil(whilePaused.phaseEndDate)
        XCTAssertTrue(whilePaused.isPaused)

        session = engine.resume(session, at: referenceDate.addingTimeInterval(minutes(65)))
        let after = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(minutes(70)))
        XCTAssertEqual(after.remainingInPhase, minutes(15))
        XCTAssertEqual(after.phaseEndDate, referenceDate.addingTimeInterval(minutes(85)))

        let (done, _) = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(90)))
        XCTAssertEqual(done.state, .completed)
        XCTAssertEqual(done.endedAt, referenceDate.addingTimeInterval(minutes(85)))
    }

    func testPausedSessionNeverCompletesOnItsOwn() {
        var session = makeSession(.countdown(25))
        session = engine.pause(session, at: referenceDate.addingTimeInterval(minutes(24))).0
        let (advanced, transitions) = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(600)))
        XCTAssertEqual(advanced.state, .paused)
        XCTAssertTrue(transitions.isEmpty)
    }

    func testPauseAfterEndCompletesInstead() {
        let session = makeSession(.countdown(25))
        let (result, transitions) = engine.pause(session, at: referenceDate.addingTimeInterval(minutes(30)))
        XCTAssertEqual(result.state, .completed)
        XCTAssertTrue(transitions.contains(.sessionCompleted(at: referenceDate.addingTimeInterval(minutes(25)))))
    }

    func testResumeSurvivesEncodeDecodeLikeAProcessRestart() throws {
        var session = makeSession(.countdown(25))
        session = engine.pause(session, at: referenceDate.addingTimeInterval(minutes(8))).0
        let data = try RecordCoding.encoder().encode(session)
        let restored = try RecordCoding.decoder().decode(FocusSession.self, from: data)
        XCTAssertEqual(restored, session)
        let resumed = engine.resume(restored, at: referenceDate.addingTimeInterval(minutes(30)))
        XCTAssertEqual(engine.snapshot(of: resumed, at: referenceDate.addingTimeInterval(minutes(30))).remainingInPhase, minutes(17))
    }

    // MARK: Count-up

    func testCountUpRunsOpenEnded() {
        let session = makeSession(.countUp)
        let snapshot = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(minutes(300)))
        XCTAssertEqual(snapshot.state, .active)
        XCTAssertNil(snapshot.remainingInPhase)
        XCTAssertNil(snapshot.phaseProgress)
        XCTAssertEqual(snapshot.displayedSeconds, minutes(300))
        XCTAssertEqual(snapshot.totalFocusElapsed, minutes(300))
    }

    func testCountUpFinishAboveThresholdCompletes() {
        var session = makeSession(.countUp)
        session = engine.pause(session, at: referenceDate.addingTimeInterval(minutes(10))).0
        session = engine.resume(session, at: referenceDate.addingTimeInterval(minutes(20)))
        let finished = engine.finishCountUp(session, at: referenceDate.addingTimeInterval(minutes(32)))
        XCTAssertEqual(finished.state, .completed)
        XCTAssertEqual(finished.completedFocusDuration, minutes(22), "paused time is excluded")
        XCTAssertEqual(finished.countedFocusDuration, minutes(22))
    }

    func testCountUpFinishBelowThresholdIsAbandoned() {
        let session = makeSession(.countUp)
        let finished = engine.finishCountUp(session, at: referenceDate.addingTimeInterval(minutes(4)))
        XCTAssertEqual(finished.state, .abandoned)
        XCTAssertEqual(finished.countedFocusDuration, 0)
    }

    // MARK: Pomodoro

    func testPomodoroPhasePlan() {
        let configuration = TimerConfiguration.pomodoro(focus: 25, rest: 5, cycles: 3)
        XCTAssertEqual(configuration.phases.map(\.kind), [.focus, .shortBreak, .focus, .shortBreak, .focus])
        XCTAssertEqual(configuration.focusBlockCount, 3)
        XCTAssertEqual(configuration.plannedFocusDuration, minutes(75))
    }

    func testPomodoroLongBreakInterval() {
        var configuration = TimerConfiguration.pomodoro(focus: 25, rest: 5, cycles: 5)
        configuration.longBreakInterval = 2
        XCTAssertEqual(configuration.phases.map(\.kind),
                       [.focus, .shortBreak, .focus, .longBreak, .focus, .shortBreak, .focus, .longBreak, .focus])
    }

    func testPomodoroAutoAdvancesThroughPhasesInBackground() {
        let session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2))
        // Mid-way through the second focus block.
        let snapshot = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(minutes(40)))
        XCTAssertEqual(snapshot.phaseKind, .focus)
        XCTAssertEqual(snapshot.phaseIndex, 2)
        XCTAssertEqual(snapshot.focusBlockNumber, 2)
        XCTAssertEqual(snapshot.remainingInPhase, minutes(15))
        XCTAssertEqual(snapshot.totalFocusElapsed, minutes(35))

        let (done, transitions) = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(90)))
        XCTAssertEqual(done.state, .completed)
        XCTAssertEqual(done.endedAt, referenceDate.addingTimeInterval(minutes(55)))
        XCTAssertEqual(done.completedFocusDuration, minutes(50))
        XCTAssertEqual(done.completedFocusPhases, 2)
        XCTAssertEqual(transitions, [
            .phaseCompleted(index: 0, kind: .focus, at: referenceDate.addingTimeInterval(minutes(25))),
            .phaseStarted(index: 1, kind: .shortBreak, at: referenceDate.addingTimeInterval(minutes(25))),
            .phaseCompleted(index: 1, kind: .shortBreak, at: referenceDate.addingTimeInterval(minutes(30))),
            .phaseStarted(index: 2, kind: .focus, at: referenceDate.addingTimeInterval(minutes(30))),
            .phaseCompleted(index: 2, kind: .focus, at: referenceDate.addingTimeInterval(minutes(55))),
            .sessionCompleted(at: referenceDate.addingTimeInterval(minutes(55)))
        ])
    }

    func testPomodoroWaitsWhenAutoStartIsOff() {
        var session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2, autoBreaks: true, autoFocus: false))
        let (waiting, transitions) = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(45)))
        XCTAssertTrue(waiting.isAwaitingNextPhase)
        XCTAssertEqual(transitions.last, .awaitingNextPhase(nextIndex: 2, kind: .focus))

        // Waiting does not consume time.
        let later = engine.snapshot(of: waiting, at: referenceDate.addingTimeInterval(minutes(120)))
        XCTAssertEqual(later.phaseKind, .shortBreak)
        XCTAssertEqual(later.remainingInPhase, 0)
        XCTAssertEqual(later.nextPhaseKind, .focus)
        XCTAssertNil(later.phaseEndDate)
        XCTAssertEqual(later.totalFocusElapsed, minutes(25))

        session = engine.startNextPhase(waiting, at: referenceDate.addingTimeInterval(minutes(120))).0
        let running = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(minutes(130)))
        XCTAssertEqual(running.phaseKind, .focus)
        XCTAssertEqual(running.remainingInPhase, minutes(15))
        XCTAssertEqual(running.totalFocusElapsed, minutes(35))
    }

    func testSkipBreakStartsNextFocusImmediately() {
        let session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2))
        let (skipped, _) = engine.skipBreak(session, at: referenceDate.addingTimeInterval(minutes(26)))
        XCTAssertEqual(skipped.phaseIndex, 2)
        let snapshot = engine.snapshot(of: skipped, at: referenceDate.addingTimeInterval(minutes(36)))
        XCTAssertEqual(snapshot.phaseKind, .focus)
        XCTAssertEqual(snapshot.remainingInPhase, minutes(15))
    }

    func testSkipBreakIsIgnoredDuringFocus() {
        let session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2))
        let (result, transitions) = engine.skipBreak(session, at: referenceDate.addingTimeInterval(minutes(10)))
        XCTAssertEqual(result.phaseIndex, 0)
        XCTAssertTrue(transitions.isEmpty)
    }

    // MARK: Abandonment

    func testAbandonEarlyMarksAbandonedWithoutProgress() {
        let session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2))
        let ended = engine.abandon(session, at: referenceDate.addingTimeInterval(minutes(40)))
        XCTAssertEqual(ended.state, .abandoned)
        XCTAssertEqual(ended.endedAt, referenceDate.addingTimeInterval(minutes(40)))
        XCTAssertEqual(ended.countedFocusDuration, 0, "abandoned sessions never count")
    }

    func testAbandonAfterNaturalEndKeepsCompletion() {
        let session = makeSession(.countdown(25))
        let ended = engine.abandon(session, at: referenceDate.addingTimeInterval(minutes(26)))
        XCTAssertEqual(ended.state, .completed)
    }

    // MARK: Boundaries for notifications

    func testUpcomingBoundariesFollowAutoStart() {
        let session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 3, autoBreaks: true, autoFocus: false))
        let boundaries = engine.upcomingBoundaries(session, from: referenceDate.addingTimeInterval(minutes(1)))
        XCTAssertEqual(boundaries.count, 2)
        XCTAssertEqual(boundaries[0].date, referenceDate.addingTimeInterval(minutes(25)))
        XCTAssertEqual(boundaries[0].nextKind, .shortBreak)
        XCTAssertFalse(boundaries[0].requiresUserToContinue)
        XCTAssertEqual(boundaries[1].date, referenceDate.addingTimeInterval(minutes(30)))
        XCTAssertTrue(boundaries[1].requiresUserToContinue)
    }

    func testUpcomingBoundariesEndWithSession() {
        let session = makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2))
        let boundaries = engine.upcomingBoundaries(session, from: referenceDate)
        XCTAssertEqual(boundaries.map(\.endsSession), [false, false, true])
        XCTAssertEqual(boundaries.last?.date, referenceDate.addingTimeInterval(minutes(55)))
    }

    func testNoBoundariesWhilePausedOrCountingUp() {
        let paused = engine.pause(makeSession(.countdown(25)), at: referenceDate).0
        XCTAssertTrue(engine.upcomingBoundaries(paused, from: referenceDate).isEmpty)
        XCTAssertTrue(engine.upcomingBoundaries(makeSession(.countUp), from: referenceDate).isEmpty)
    }

    // MARK: Configuration

    func testValidationClampsValues() {
        var configuration = TimerConfiguration.standard
        configuration.focusDuration = 10
        configuration.breakDuration = minutes(500)
        configuration.cycleCount = 40
        let validated = configuration.validated()
        XCTAssertEqual(validated.focusDuration, TimerConfiguration.focusRange.lowerBound)
        XCTAssertEqual(validated.breakDuration, TimerConfiguration.breakRange.upperBound)
        XCTAssertEqual(validated.cycleCount, TimerConfiguration.cycleRange.upperBound)
    }

    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatter.clock(minutes(25)), "25:00")
        XCTAssertEqual(DurationFormatter.clock(59.2), "01:00")
        XCTAssertEqual(DurationFormatter.clock(3725), "1:02:05")
        XCTAssertEqual(DurationFormatter.elapsedClock(0.9), "00:00")
        XCTAssertEqual(DurationFormatter.short(minutes(65)), "1 h 5 min")
        XCTAssertEqual(DurationFormatter.spoken(minutes(12) + 30), "12 minutes 30 seconds")
    }
}

// MARK: - RoutingAndPrivacyTests

final class DeepLinkTests: XCTestCase {
    let parser = DeepLinkParser()

    func testDefaultPresetLink() {
        XCTAssertEqual(parser.parse(URL(string: "still://start-focus?preset=default")!), .startFocus(presetID: .defaultPreset))
    }

    func testStudyPresetLink() {
        XCTAssertEqual(parser.parse(URL(string: "still://start-focus?preset=study")!), .startFocus(presetID: .study))
    }

    func testMissingPresetMeansDefault() {
        XCTAssertEqual(parser.parse(URL(string: "still://start-focus")!), .startFocus(presetID: .defaultPreset))
    }

    func testPathStyleAndCaseInsensitiveAction() {
        XCTAssertEqual(parser.parse(URL(string: "still:///start-focus?preset=study")!), .startFocus(presetID: .study))
        XCTAssertEqual(parser.parse(URL(string: "STILL://Start-Focus?preset=study")!), .startFocus(presetID: .study))
    }

    func testRejectsOtherSchemesActionsAndHostileValues() {
        XCTAssertNil(parser.parse(URL(string: "https://example.com/start-focus?preset=study")!))
        XCTAssertNil(parser.parse(URL(string: "still://delete-everything")!))
        XCTAssertNil(parser.parse(URL(string: "still://start-focus?preset=%3Cscript%3E")!))
        XCTAssertNil(parser.parse(URL(string: "still://start-focus?preset=" + String(repeating: "a", count: 41))!))
    }

    func testUniversalLinkHostsAreOptIn() {
        var withHost = DeepLinkParser()
        withHost.universalLinkHosts = ["focus.example.com"]
        XCTAssertEqual(withHost.parse(URL(string: "https://focus.example.com/start-focus?preset=study")!), .startFocus(presetID: .study))
    }

    func testPresetURLRoundTrips() {
        for preset in [PresetCatalog.defaultPreset(), PresetCatalog.study] {
            XCTAssertEqual(parser.parse(preset.startURL), .startFocus(presetID: preset.id))
        }
        XCTAssertEqual(PresetCatalog.study.startURL.absoluteString, "still://start-focus?preset=study")
    }

    func testNFCRouterRecognizesKnownPresets() {
        let router = DeepLinkPresetRouter(knownPresetIDs: [.defaultPreset, .study])
        XCTAssertEqual(router.route(URL(string: "still://start-focus?preset=study")!), .startPreset(.study))
        XCTAssertEqual(router.route(URL(string: "still://start-focus?preset=deepWork")!), .unknownPreset(FocusPresetID("deepWork")))
        XCTAssertEqual(router.route(URL(string: "still://settings")!), .notAFocusLink)
    }
}

final class RouteResolverTests: XCTestCase {
    func testCoreLoopRoutes() {
        let resolver = RouteResolver(flags: .v1)
        let id = UUID()
        XCTAssertEqual(resolver.destination(for: .sessionComplete(id), currentTab: .me).completionSessionID, id)
        XCTAssertEqual(resolver.destination(for: .sessionComplete(id), currentTab: .me).tab, .focus)

        let activity = AppRoute.breakActivity(.sudoku, ActivityContext(entryPoint: .suggestion, sessionID: id, suggestionRank: 1))
        let destination = resolver.destination(for: activity, currentTab: .focus)
        XCTAssertEqual(destination.tab, .breakShelf)
        XCTAssertEqual(destination.stack, [activity])

        XCTAssertEqual(resolver.destination(for: .breakShelf, currentTab: .focus), RouteDestination(tab: .breakShelf, stack: [], sheet: nil, completionSessionID: nil))
        XCTAssertEqual(resolver.destination(for: .focusHome, currentTab: .breakShelf).tab, .focus)
        XCTAssertEqual(resolver.destination(for: .focusConfiguration, currentTab: .focus).sheet, .focusConfiguration)
        XCTAssertEqual(resolver.destination(for: .tasks, currentTab: .me).tab, .me)
        XCTAssertEqual(resolver.destination(for: .nfcSetup, currentTab: .focus).stack, [.nfcSetup])
    }

    func testJournalIsHiddenInV1AndReadyBehindFlag() {
        XCTAssertEqual(AppTab.visibleTabs(flags: .v1), [.focus, .breakShelf, .me])
        XCTAssertEqual(RouteResolver(flags: .v1).destination(for: .journal, currentTab: .focus).tab, .me)

        var flags = FeatureFlags.v1
        flags.journalTab = true
        XCTAssertEqual(AppTab.visibleTabs(flags: flags), [.focus, .breakShelf, .journal, .me])
        XCTAssertEqual(RouteResolver(flags: flags).destination(for: .journal, currentTab: .focus).tab, .journal)
    }
}

final class EventPrivacyTests: XCTestCase {
    func testSanitizerRedactsFreeText() {
        XCTAssertEqual(EventProperties.sanitizedToken("Biology homework"), SafeToken.redacted)
        XCTAssertEqual(EventProperties.sanitizedToken("call mom @ 5"), SafeToken.redacted)
        XCTAssertEqual(EventProperties.sanitizedToken(String(repeating: "a", count: 40)), SafeToken.redacted)
        XCTAssertEqual(EventProperties.sanitizedToken(""), SafeToken.redacted)
        XCTAssertEqual(EventProperties.sanitizedToken("pomodoro"), "pomodoro")
        XCTAssertEqual(EventProperties.sanitizedToken("wordSearch"), "wordSearch")
    }

    func testUnknownIdentifiersAreAnonymized() {
        let props = EventProperties()
            .preset(FocusPresetID("Emma's secret plan"))
            .activity(BreakActivityID("my diary"))
        XCTAssertEqual(props.values[.presetID]?.description, "custom")
        XCTAssertEqual(props.values[.activityID]?.description, "custom")
    }

    func testDurationsAreBucketed() {
        XCTAssertEqual(EventProperties.bucket(for: 30), "under_1m")
        XCTAssertEqual(EventProperties.bucket(for: minutes(25)), "m15_30")
        XCTAssertEqual(EventProperties.bucket(for: minutes(90)), "over_60m")
    }

    func testPrivateTextNeverReachesTheEventLog() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        container.preferences.completeOnboarding(goal: .scrollLess)
        let secret = "Biology homework"
        let noteText = "I am worried about the exam"

        let task = container.taskController.create(title: secret)!
        let session = container.focus.start(presetID: .defaultPreset, taskID: task.id, source: .manual).session
        clock.advance(by: minutes(25))
        container.focus.tick()
        let usage = container.breaks.begin(.brainDump, context: ActivityContext(entryPoint: .suggestion, sessionID: session.id, suggestionRank: 2))
        container.breaks.saveNote(text: noteText, kind: .brainDump, activityID: .brainDump, promptID: nil)
        container.breaks.finish(usageID: usage.id, outcome: .completed)

        let allValues = container.events.recentEvents.flatMap { event in event.properties.values.values.map(\.description) }
        XCTAssertFalse(allValues.isEmpty)
        for value in allValues {
            XCTAssertFalse(value.contains("Biology"), "task title leaked: \(value)")
            XCTAssertFalse(value.contains("worried"), "note text leaked: \(value)")
            XCTAssertTrue(SafeToken.isSafe(value) || Int(value) != nil || value == "true" || value == "false")
        }
    }
}

final class LiveActivityAndNotificationTests: XCTestCase {
    func testLiveActivityMappingOmitsTaskAndReflectsState() {
        let engine = FocusTimerEngine()
        let session = makeSession(.countdown(25))
        let running = engine.snapshot(of: session, at: referenceDate.addingTimeInterval(60))
        let state = LiveActivityMapper.state(for: running, sceneName: "Rainy Bedroom", now: referenceDate.addingTimeInterval(60))!
        XCTAssertEqual(state.headline, "Focus")
        XCTAssertEqual(state.phaseEndDate, referenceDate.addingTimeInterval(minutes(25)))
        XCTAssertNil(state.frozenSeconds)

        let paused = engine.pause(session, at: referenceDate.addingTimeInterval(120)).0
        let pausedState = LiveActivityMapper.state(for: engine.snapshot(of: paused, at: referenceDate.addingTimeInterval(500)),
                                                   sceneName: "Rainy Bedroom", now: referenceDate.addingTimeInterval(500))!
        XCTAssertEqual(pausedState.headline, "Paused")
        XCTAssertNil(pausedState.phaseEndDate)
        XCTAssertEqual(pausedState.frozenSeconds, minutes(25) - 120)

        let done = engine.advance(session, to: referenceDate.addingTimeInterval(minutes(30))).0
        XCTAssertNil(LiveActivityMapper.state(for: engine.snapshot(of: done, at: referenceDate), sceneName: "", now: referenceDate))
    }

    func testNotificationCopyIsCalm() {
        let boundaries = FocusTimerEngine().upcomingBoundaries(
            makeSession(.pomodoro(focus: 25, rest: 5, cycles: 2, autoBreaks: true, autoFocus: false)), from: referenceDate)
        let copy = boundaries.map { NotificationCopy.content(for: $0) }
        XCTAssertEqual(copy.first?.title, "Focus block done")
        XCTAssertEqual(copy.last?.title, "Break's over")
        let session = FocusTimerEngine().upcomingBoundaries(makeSession(.countdown(25)), from: referenceDate)
        XCTAssertEqual(NotificationCopy.content(for: session[0]).title, "Session complete")
        for (title, body) in copy {
            XCTAssertFalse(title.contains("!") || body.contains("!"))
        }
    }

    func testBlockingCopyNeverClaimsShieldingInV1() {
        let mock = MockFocusBlockingService()
        XCTAssertEqual(BlockingCopy.title(for: mock.capability, isShielding: mock.isShielding), "Blocking setup is ready")
        XCTAssertFalse(BlockingCopy.detail(for: mock.capability).lowercased().contains("apps are blocked"))
    }

    func testAmbientSummaryLine() {
        var mix = AmbientMix.silent
        XCTAssertEqual(mix.summaryLine, "Sound off")
        mix.isEnabled = true
        mix.setLevel(0.7, for: .rain)
        XCTAssertEqual(mix.summaryLine, "Rain · 42%")
        mix.setLevel(0.3, for: .cafe)
        XCTAssertEqual(mix.summaryLine, "Rain + Café · 42%")
        mix.setMasterVolume(0)
        XCTAssertEqual(mix.summaryLine, "Sound off")
        XCTAssertEqual(mix.effectiveVolume(for: .rain), 0)
    }
}

// MARK: - StatsAndProgressionTests

final class StreakTests: XCTestCase {
    let streaks = StreakCalculator(calendar: testCalendar)

    func day(_ offset: Int, hour: Int = 10) -> Date {
        let start = testCalendar.startOfDay(for: referenceDate)
        return testCalendar.date(byAdding: .day, value: offset, to: start)!.addingTimeInterval(Double(hour) * 3600)
    }

    func testConsecutiveDaysEndingToday() {
        let sessions = [-2, -1, 0].map { completedSession(endingAt: day($0)) }
        let days = streaks.focusDays(from: sessions)
        XCTAssertEqual(streaks.currentStreak(days: days, today: day(0, hour: 20)), 3)
        XCTAssertEqual(streaks.longestStreak(days: days), 3)
    }

    func testMultipleSessionsOnOneDayCountOnce() {
        let sessions = [completedSession(endingAt: day(0, hour: 9)),
                        completedSession(endingAt: day(0, hour: 11)),
                        completedSession(endingAt: day(0, hour: 22))]
        let days = streaks.focusDays(from: sessions)
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(streaks.currentStreak(days: days, today: day(0, hour: 23)), 1)
    }

    func testStreakStillStandsBeforeFocusingToday() {
        let sessions = [-3, -2, -1].map { completedSession(endingAt: day($0)) }
        let days = streaks.focusDays(from: sessions)
        XCTAssertEqual(streaks.currentStreak(days: days, today: day(0, hour: 8)), 3)
    }

    func testGapResetsCurrentStreakButKeepsLongest() {
        let sessions = [-6, -5, -4, -3, -1, 0].map { completedSession(endingAt: day($0)) }
        let days = streaks.focusDays(from: sessions)
        XCTAssertEqual(streaks.currentStreak(days: days, today: day(0)), 2)
        XCTAssertEqual(streaks.longestStreak(days: days), 4)
    }

    func testMissingAWholeDayResetsToZero() {
        let sessions = [-3, -2].map { completedSession(endingAt: day($0)) }
        let days = streaks.focusDays(from: sessions)
        XCTAssertEqual(streaks.currentStreak(days: days, today: day(0)), 0)
        XCTAssertEqual(StatsCalculator.streakLine(current: 0), "A streak starts with any one session.")
    }

    func testAbandonedSessionsDoNotCreateFocusDays() {
        let engine = FocusTimerEngine()
        let abandoned = engine.abandon(makeSession(.countdown(25), at: day(0)), at: day(0).addingTimeInterval(600))
        XCTAssertTrue(streaks.focusDays(from: [abandoned]).isEmpty)
    }

    func testSessionIsAttributedToTheDayItEnded() {
        // Starts 23:50 on day -1, ends 00:15 on day 0.
        let end = testCalendar.startOfDay(for: referenceDate).addingTimeInterval(15 * 60)
        let session = completedSession(endingAt: end, focusMinutes: 25)
        XCTAssertEqual(streaks.focusDays(from: [session]), [testCalendar.startOfDay(for: referenceDate)])
    }
}

final class StatsCalculatorTests: XCTestCase {
    func testStatsDeriveFromPersistedData() {
        let calculator = StatsCalculator(calendar: testCalendar)
        let today = referenceDate
        let yesterday = testCalendar.date(byAdding: .day, value: -1, to: today)!
        let tenDaysAgo = testCalendar.date(byAdding: .day, value: -10, to: today)!
        let sessions = [
            completedSession(endingAt: today, focusMinutes: 25),
            completedSession(endingAt: today.addingTimeInterval(-7200), focusMinutes: 50),
            completedSession(endingAt: yesterday, focusMinutes: 30),
            completedSession(endingAt: tenDaysAgo, focusMinutes: 20),
            FocusTimerEngine().abandon(makeSession(.countdown(25), at: today), at: today.addingTimeInterval(300))
        ]
        let usages = [
            ActivityUsage(id: UUID(), activityID: .sudoku, startedAt: today, endedAt: today, outcome: .completed, context: .shelf),
            ActivityUsage(id: UUID(), activityID: .sudoku, startedAt: today, endedAt: today, outcome: .abandoned, context: .shelf),
            ActivityUsage(id: UUID(), activityID: .doNothing, startedAt: today, endedAt: today, outcome: .completed, context: .shelf)
        ]
        let stats = calculator.stats(sessions: sessions, usages: usages, now: today.addingTimeInterval(3600))

        XCTAssertEqual(stats.completedSessions, 4)
        XCTAssertEqual(stats.totalFocus, minutes(125))
        XCTAssertEqual(stats.todayFocus, minutes(75))
        XCTAssertEqual(stats.weekFocus, minutes(105))
        XCTAssertEqual(stats.averageSessionDuration, minutes(125) / 4)
        XCTAssertEqual(stats.currentStreak, 2)
        XCTAssertEqual(stats.lastSevenDays.count, 7)
        XCTAssertEqual(stats.lastSevenDays.last?.sessionCount, 2)
        XCTAssertEqual(stats.activitiesCompleted, 2)
        XCTAssertEqual(stats.activityUsage.first?.activityID, .sudoku)
        XCTAssertEqual(stats.activityUsage.first?.openedCount, 2)
    }

    func testEmptyHistory() {
        let stats = StatsCalculator(calendar: testCalendar).stats(sessions: [], usages: [], now: referenceDate)
        XCTAssertFalse(stats.hasHistory)
        XCTAssertEqual(stats.averageSessionDuration, 0)
        XCTAssertEqual(stats.lastSevenDays.map(\.focusDuration), Array(repeating: 0, count: 7))
    }
}

final class ProgressionTests: XCTestCase {
    let evaluator = ProgressionEvaluator()
    let catalog = SceneCatalog.all

    func testMilestonesMatchSpecification() {
        XCTAssertEqual(SceneCatalog.rainyBedroom.unlockRule, .initiallyUnlocked)
        XCTAssertEqual(SceneCatalog.libraryLight.unlockRule, .completedSessions(7))
        XCTAssertEqual(SceneCatalog.trainWindow.unlockRule, .completedSessions(15))
        XCTAssertEqual(SceneCatalog.nightCity.unlockRule, .completedSessions(25))
    }

    func testUnlocksAtExactThresholds() {
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 0).map(\.id), [.rainyBedroom])
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 6).map(\.id), [.rainyBedroom])
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 7).map(\.id), [.rainyBedroom, .libraryLight])
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 15).count, 3)
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 25).count, 4)
    }

    func testNextLockedSceneAndRemaining() {
        let next = evaluator.nextLockedScene(in: catalog, completedSessions: 4)
        XCTAssertEqual(next?.scene.id, .libraryLight)
        XCTAssertEqual(next?.remaining, 3)
        XCTAssertNil(evaluator.nextLockedScene(in: catalog, completedSessions: 30))
    }

    func testNewlyUnlockedBetweenCounts() {
        XCTAssertEqual(evaluator.newlyUnlocked(in: catalog, before: 6, after: 7).map(\.id), [.libraryLight])
        XCTAssertTrue(evaluator.newlyUnlocked(in: catalog, before: 7, after: 8).isEmpty)
        XCTAssertEqual(evaluator.newlyUnlocked(in: catalog, before: 0, after: 30).count, 3)
    }

    func testAbandonedSessionsDoNotUnlock() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        for _ in 0..<10 {
            container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
            clock.advance(by: minutes(10))
            container.focus.endEarly()
        }
        XCTAssertEqual(container.focus.completedSessionCount, 0)
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: container.focus.completedSessionCount).count, 1)
    }

    func testPlantStageIsFullUntilGrowthShips() {
        XCTAssertEqual(evaluator.plantStage(completedSessions: 0, growthEnabled: false), .full)
        XCTAssertEqual(evaluator.plantStage(completedSessions: 0, growthEnabled: true), .sprout)
        XCTAssertEqual(evaluator.plantStage(completedSessions: 12, growthEnabled: true), .full)
    }
}
