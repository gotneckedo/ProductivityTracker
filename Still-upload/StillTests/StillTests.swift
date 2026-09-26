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

    func testSudokuDigitCompletesOnlyAfterSixPlacements() {
        var game = SudokuGame(puzzle: BundledPuzzleLibrary.sudoku6)
        let digit = 1
        XCTAssertLessThan(game.placedCount(of: digit), game.puzzle.size)
        XCTAssertFalse(game.isDigitComplete(digit), "Fresh keypad digits stay at full contrast")

        for index in game.puzzle.givens.indices where game.placedCount(of: digit) < game.puzzle.size {
            guard !game.puzzle.isGiven(index) else { continue }
            game.select(index)
            XCTAssertTrue(game.enter(digit))
        }

        XCTAssertEqual(game.placedCount(of: digit), game.puzzle.size)
        XCTAssertTrue(game.isDigitComplete(digit), "Only the sixth placed instance retires the digit")
        XCTAssertFalse(game.isDigitComplete(2), "Other keypad digits remain available")
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

final class TimerSnapshotTests: XCTestCase {
    func testLiveEndDateUsesCurrentRenderTimeAndRemainingDuration() {
        let engine = FocusTimerEngine()
        let session = makeSession(.countdown(25), at: referenceDate)
        let renderTime = referenceDate.addingTimeInterval(90)
        let snapshot = engine.snapshot(of: session, at: renderTime)

        XCTAssertEqual(
            snapshot.endDate(from: renderTime),
            referenceDate.addingTimeInterval(25 * 60),
            "The status line is derived from now plus the live remaining duration."
        )
    }

    func testPausedSnapshotHasNoFutureEndDate() {
        let engine = FocusTimerEngine()
        let session = makeSession(.countdown(25), at: referenceDate)
        let paused = engine.pause(session, at: referenceDate.addingTimeInterval(60)).0
        let snapshot = engine.snapshot(of: paused, at: referenceDate.addingTimeInterval(90))

        XCTAssertNil(snapshot.endDate(from: referenceDate.addingTimeInterval(90)))
    }

    func testPreviewFixtureEndTimeMatchesItsInjectedClock() {
        let start = referenceDate.addingTimeInterval(-7 * 60)
        let state = PreviewSupport.appState(populated: true, activeSession: true, clockStart: start)
        let now = state.container.clock.now

        XCTAssertEqual(now, referenceDate)
        let snapshot = try! XCTUnwrap(state.snapshot)
        XCTAssertEqual(try! XCTUnwrap(snapshot.remainingInPhase), 18 * 60, accuracy: 0.1)
        XCTAssertEqual(snapshot.endDate(from: now), referenceDate.addingTimeInterval(18 * 60))
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

    func testCatalogHasEveryActivity() {
        let ids = Set(ActivityCatalog.available.map(\.id))
        XCTAssertEqual(ids, [.sudoku, .picross, .wordSearch, .shortRead, .creativePrompt, .pixelDoodle,
                             .brainDump, .guidedStretch, .boxBreathing, .doNothing])
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
        XCTAssertEqual(state.notice?.text, "A focus session is already running.")

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
        for _ in 0..<2 {
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

    func testAddingFiveMinutesExtendsOnlyTheRunningSession() {
        container.focus.start(presetID: .defaultPreset, taskID: nil, source: .manual)
        clock.advance(by: minutes(5))
        container.focus.addFiveMinutes()

        XCTAssertEqual(container.focus.snapshot()?.remainingInPhase, minutes(25))
        XCTAssertEqual(container.focus.activeSession?.configuration.focusDuration, minutes(30))
        XCTAssertEqual(container.presets.preset(id: .defaultPreset)?.timer.focusDuration, minutes(25))
        XCTAssertEqual(notifications.scheduled.first?.date, clock.now.addingTimeInterval(minutes(25)))
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

    func testTaskChecklistPersistsAndTogglesIndependently() {
        let task = container.taskController.create(title: "Biology review")!
        XCTAssertTrue(container.taskController.addStep(taskID: task.id, title: "Read chapter 4"))
        let step = try! XCTUnwrap(container.tasks.task(id: task.id)?.steps.first)

        container.taskController.toggleStep(taskID: task.id, stepID: step.id)
        XCTAssertTrue(container.tasks.task(id: task.id)?.steps.first?.isCompleted == true)
        XCTAssertFalse(container.tasks.task(id: task.id)?.isCompleted == true)

        container.taskController.deleteStep(taskID: task.id, stepID: step.id)
        XCTAssertTrue(container.tasks.task(id: task.id)?.steps.isEmpty == true)
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

    func testPlaceholderUniversalHostUsesTheProductionParserBoundary() {
        let url = StillLinks.startFocusURL(presetID: .study)
        XCTAssertEqual(url.host, StillLinks.universalHost)
        XCTAssertEqual(parser.parse(url), .startFocus(presetID: .study))
        XCTAssertEqual(StillLinks.focusCardSetupURL.host, StillLinks.universalHost)
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

    func testTodayOwnsReflectionAndIsAlwaysTheHomeTab() {
        XCTAssertEqual(AppTab.visibleTabs(flags: .v1), [.today, .focus, .breakShelf, .me])
        XCTAssertEqual(RouteResolver(flags: .v1).destination(for: .journal, currentTab: .focus).tab, .today)
        XCTAssertEqual(RouteResolver(flags: .current).destination(for: .today, currentTab: .focus).tab, .today)
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
        XCTAssertEqual(NotificationCopy.content(for: session[0]).title, "Study session complete")
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
        XCTAssertNil(StatsCalculator.streakValue(0), "a numeric zero streak is never presented")
        XCTAssertEqual(StatsCalculator.streakValue(1), "1 day")
        XCTAssertEqual(StatsCalculator.streakValue(3), "3 days")
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

    func testDayWeekMonthAndYearRangesUseCalendarBoundaries() {
        let calculator = StatsCalculator(calendar: testCalendar)
        let today = referenceDate
        let sessions = [
            completedSession(endingAt: today, focusMinutes: 10),
            completedSession(endingAt: testCalendar.date(byAdding: .day, value: -6, to: today)!, focusMinutes: 20),
            completedSession(endingAt: testCalendar.date(byAdding: .day, value: -7, to: today)!, focusMinutes: 30),
            completedSession(endingAt: testCalendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10))!, focusMinutes: 40),
            completedSession(endingAt: testCalendar.date(from: DateComponents(year: 2025, month: 12, day: 31, hour: 10))!, focusMinutes: 50)
        ]
        let stats = calculator.stats(sessions: sessions, usages: [], now: today)

        XCTAssertEqual(stats.data(for: .day)?.focusDuration, minutes(10))
        XCTAssertEqual(stats.data(for: .day)?.points.count, 1)
        XCTAssertEqual(stats.data(for: .week)?.focusDuration, minutes(30))
        XCTAssertEqual(stats.data(for: .week)?.points.count, 7)
        XCTAssertEqual(stats.data(for: .month)?.focusDuration, minutes(60))
        XCTAssertEqual(stats.data(for: .month)?.points.count, 31)
        XCTAssertEqual(stats.data(for: .year)?.focusDuration, minutes(100))
        XCTAssertEqual(stats.data(for: .year)?.points.count, 12)
    }

    func testOwnUsualUsesPriorFocusDaysAndExcludesToday() {
        let calculator = StatsCalculator(calendar: testCalendar)
        let sessions = [
            completedSession(endingAt: testCalendar.date(byAdding: .day, value: -3, to: referenceDate)!, focusMinutes: 20),
            completedSession(endingAt: testCalendar.date(byAdding: .day, value: -2, to: referenceDate)!, focusMinutes: 40),
            completedSession(endingAt: referenceDate, focusMinutes: 90)
        ]
        let stats = calculator.stats(sessions: sessions, usages: [], now: referenceDate)

        XCTAssertEqual(stats.usualDailyFocus, minutes(30))
        XCTAssertEqual(stats.data(for: .week)?.usualReferenceFocus, minutes(30))
        XCTAssertEqual(stats.data(for: .day)?.comparisonToUsual, .more)
        XCTAssertEqual(StatsCalculator.comparison(focus: minutes(30), usual: minutes(30)), .aboutUsual)
        XCTAssertEqual(StatsCalculator.comparison(focus: minutes(10), usual: minutes(30)), .lighter)
    }

    func testRangePointsKeepSubjectFocusSegments() {
        let biology = TaskItem(title: "Lab notes", createdAt: referenceDate, subject: .biology)
        let literature = TaskItem(title: "Essay", createdAt: referenceDate, subject: .literature)
        var first = completedSession(endingAt: referenceDate.addingTimeInterval(-30 * 60), focusMinutes: 20)
        var second = completedSession(endingAt: referenceDate, focusMinutes: 25)
        first.taskID = biology.id
        second.taskID = literature.id

        let stats = StatsCalculator(calendar: testCalendar).stats(
            sessions: [first, second], usages: [], tasks: [biology, literature], now: referenceDate
        )
        let segments = stats.data(for: .day)?.points.first?.subjectSegments ?? []
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.first { $0.subject == .biology }?.focusDuration, minutes(20))
        XCTAssertEqual(segments.first { $0.subject == .literature }?.focusDuration, minutes(25))
    }

    func testCalendarDaysUseNeutralQuietAndUpcomingStates() {
        let now = testCalendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9))!
        let focused = testCalendar.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 10))!
        let month = StatsCalculator(calendar: testCalendar).calendarMonth(
            sessions: [completedSession(endingAt: focused)],
            now: now
        )

        XCTAssertEqual(month.days.count, 31)
        XCTAssertEqual(month.days.first { testCalendar.component(.day, from: $0.date) == 4 }?.kind, .focused)
        XCTAssertEqual(month.days.first { testCalendar.component(.day, from: $0.date) == 5 }?.kind, .quiet)
        XCTAssertEqual(month.days.first { testCalendar.component(.day, from: $0.date) == 11 }?.kind, .upcoming)
        XCTAssertFalse(FocusCalendarDayKind.allRawValuesForTesting.contains("missed"))
    }
}

private extension FocusCalendarDayKind {
    static var allRawValuesForTesting: [String] {
        [FocusCalendarDayKind.focused, .quiet, .upcoming].map(\.rawValue)
    }
}

final class BlockingScheduleTests: XCTestCase {
    func testScheduleStartsAtTimeAndEndsOnlyOnCardTapOrOverride() {
        let clock = ManualClock(referenceDate)
        let keyValues = InMemoryKeyValueStore()
        let mock = MockFocusBlockingService()
        let controller = BlockingScheduleController(
            clock: clock,
            calendar: testCalendar,
            store: KeyValueBlockingScheduleStore(store: keyValues),
            blocking: mock
        )

        controller.update(isEnabled: true, startMinute: 10 * 60, presetID: .study)
        XCTAssertEqual(controller.schedule.phase, .waiting)
        XCTAssertEqual(controller.refresh(at: referenceDate.addingTimeInterval(59 * 60)), .none)
        XCTAssertEqual(controller.refresh(at: referenceDate.addingTimeInterval(60 * 60)), .started)
        XCTAssertEqual(controller.schedule.phase, .blockingUntilCardTap)
        XCTAssertEqual(mock.scheduledPresetID, .study)
        XCTAssertEqual(controller.refresh(at: referenceDate.addingTimeInterval(4 * 60 * 60)), .none)
        XCTAssertEqual(controller.schedule.phase, .blockingUntilCardTap)
        XCTAssertEqual(controller.cardTapped(), .endedByCardTap)
        XCTAssertEqual(controller.schedule.phase, .waiting)
        XCTAssertNil(mock.scheduledPresetID)
    }

    func testSchedulePersistsAndManualEndPersistsWaitingState() {
        let keyValues = InMemoryKeyValueStore()
        let mock = MockFocusBlockingService()
        let store = KeyValueBlockingScheduleStore(store: keyValues)
        let first = BlockingScheduleController(
            clock: ManualClock(referenceDate),
            calendar: testCalendar,
            store: store,
            blocking: mock
        )
        first.update(isEnabled: true, startMinute: 8 * 60 + 15, presetID: .deepWork)
        XCTAssertEqual(first.schedule.phase, .blockingUntilCardTap)
        XCTAssertEqual(mock.scheduledPresetID, .deepWork)

        let restored = BlockingScheduleController(
            clock: ManualClock(referenceDate),
            calendar: testCalendar,
            store: store,
            blocking: mock
        )
        XCTAssertEqual(restored.schedule.phase, .blockingUntilCardTap)
        XCTAssertEqual(restored.schedule.startMinute, 8 * 60 + 15)
        XCTAssertEqual(restored.schedule.presetID, .deepWork)
        XCTAssertEqual(restored.endNow(), .endedManually)

        let afterEnd = BlockingScheduleController(
            clock: ManualClock(referenceDate),
            calendar: testCalendar,
            store: store,
            blocking: mock
        )
        XCTAssertEqual(afterEnd.schedule.phase, .waiting)
        XCTAssertTrue(afterEnd.schedule.isEnabled)
    }

    func testMockRecordsIntentButNeverClaimsShielding() {
        let mock = MockFocusBlockingService()
        mock.scheduleDidStart(presetID: .defaultPreset)
        XCTAssertEqual(mock.scheduledPresetID, .defaultPreset)
        XCTAssertFalse(mock.isShielding)
        XCTAssertEqual(mock.capability, .simulationOnly)
    }
}

final class CopyCountTests: XCTestCase {
    func testSingularSessionAndFocusDayCopy() {
        XCTAssertEqual(Copy.Count.session(1), "1 session")
        XCTAssertEqual(Copy.Count.session(2), "2 sessions")
        XCTAssertEqual(Copy.Count.focusDay(1), "1 focus day")
        XCTAssertEqual(Copy.Count.focusDay(3), "3 focus days")
        XCTAssertEqual(Copy.Count.sessionLabel(1), "session")
        XCTAssertEqual(Copy.Count.focusDayLabel(1), "focus day")
        XCTAssertEqual(RoomUnlockRule.focusDays(1).plainLanguage, "Focus on 1 focus day total")
    }

    func testCatCoatsHaveDistinctSpriteAssetsAndLegacyDefault() throws {
        XCTAssertEqual(Set(CatCoat.allCases.map(\.spriteAssetName)).count, CatCoat.allCases.count)
        let legacy = try RecordCoding.decoder().decode(UserPreferences.self, from: Data(#"{"schemaVersion":3}"#.utf8))
        XCTAssertEqual(legacy.catCoat, .ginger)
        XCTAssertEqual(legacy.schemaVersion, UserPreferences.currentSchemaVersion)
    }
}

final class ProgressionTests: XCTestCase {
    let evaluator = ProgressionEvaluator()
    let catalog = SceneCatalog.all

    func testMilestonesMatchSpecification() {
        XCTAssertEqual(SceneCatalog.rainyBedroom.unlockRule, .initiallyUnlocked)
        XCTAssertEqual(SceneCatalog.libraryLight.unlockRule, .completedSessions(2))
        XCTAssertEqual(SceneCatalog.trainWindow.unlockRule, .completedSessions(6))
        XCTAssertEqual(SceneCatalog.nightCity.unlockRule, .completedSessions(12))
    }

    func testCoreScenesUseFourDistinctRendererLayouts() {
        XCTAssertEqual(
            Set(SceneCatalog.all.map(\.rendererKind)),
            Set([.rainyBedroom, .libraryLight, .trainWindow, .nightCity])
        )
    }

    func testUnlocksAtExactThresholds() {
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 0).map(\.id), [.rainyBedroom])
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 2).map(\.id), [.rainyBedroom, .libraryLight])
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 6).map(\.id), [.rainyBedroom, .libraryLight, .trainWindow])
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: 12).count, 4)
    }

    func testAllUnlockedPreviewFixtureSeedsRequestedSessionCount() {
        let clock = ManualClock(referenceDate)
        let container = DependencyContainer.inMemory(clock: clock, calendar: testCalendar)
        PreviewFixtures.populate(container, completedSessions: 30)

        let count = container.sessions.allSessions().filter { $0.state == .completed }.count
        XCTAssertEqual(count, 30)
        XCTAssertEqual(evaluator.unlockedScenes(in: catalog, completedSessions: count).count, 4)
    }

    func testNextLockedSceneAndRemaining() {
        let next = evaluator.nextLockedScene(in: catalog, completedSessions: 4)
        XCTAssertEqual(next?.scene.id, .trainWindow)
        XCTAssertEqual(next?.remaining, 2)
        XCTAssertNil(evaluator.nextLockedScene(in: catalog, completedSessions: 30))
    }

    func testNewlyUnlockedBetweenCounts() {
        XCTAssertEqual(evaluator.newlyUnlocked(in: catalog, before: 1, after: 2).map(\.id), [.libraryLight])
        XCTAssertTrue(evaluator.newlyUnlocked(in: catalog, before: 2, after: 3).isEmpty)
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


// MARK: - V1.1+ features

final class FeatureFlagTests: XCTestCase {
    func testCurrentFlagsShipTodayPlantAndWidgetsButNotBlocking() {
        let flags = FeatureFlags.current
        XCTAssertTrue(flags.journalTab)
        XCTAssertTrue(flags.plantGrowthStages)
        XCTAssertTrue(flags.liveActivities)
        XCTAssertFalse(flags.appBlocking, "Blocking stays off until Apple approves the entitlement.")
        XCTAssertEqual(AppTab.visibleTabs(flags: flags), [.today, .focus, .breakShelf, .me])
    }

    func testEveryP9StandInIsOffInV1CurrentAndRelease() {
        for (name, flags) in [("v1", FeatureFlags.v1), ("current", .current), ("release", .release)] {
            XCTAssertFalse(flags.wakeUpPreview, "Wake up stand-in must be off in \(name).")
            XCTAssertFalse(flags.seasonalPurchasesPreview, "Purchase stand-in must be off in \(name).")
            XCTAssertFalse(flags.googleCalendarPreview, "Google sample events must be off in \(name).")
            XCTAssertFalse(flags.brandedFocusCardPreview, "Card placeholder must be off in \(name).")
        }
    }

    func testDisabledFlagsReplaceInjectedStandInsWithNoopBoundaries() {
        let container = DependencyContainer.inMemory(
            clock: ManualClock(referenceDate),
            calendar: testCalendar,
            flags: .v1,
            googleCalendar: SampleGoogleCalendarAdapter(now: referenceDate, calendar: testCalendar),
            purchases: LocalPurchaseService(),
            focusCardOffering: PlaceholderFocusCardOffering()
        )
        XCTAssertFalse(container.googleCalendar.isStandIn)
        XCTAssertFalse(container.purchases.isStandIn)
        XCTAssertNil(container.focusCardOffering.offer)
        XCTAssertEqual(container.wakeUp.delivery, .notificationFallback)
    }

    func testV1AndCurrentBothKeepBlockingOffWithoutEntitlement() {
        XCTAssertFalse(FeatureFlags.v1.appBlocking)
        XCTAssertFalse(FeatureFlags.current.appBlocking)
        XCTAssertTrue(DependencyContainer.inMemory(flags: .current).blocking is MockFocusBlockingService)
    }

    func testNewRoutesResolve() {
        let resolver = RouteResolver(flags: .current)
        XCTAssertEqual(resolver.destination(for: .presets, currentTab: .focus), RouteDestination(tab: .me, stack: [.presets], sheet: nil, completionSessionID: nil))
        XCTAssertEqual(resolver.destination(for: .dayTimeline, currentTab: .breakShelf).sheet, .dayTimeline)
        XCTAssertEqual(resolver.destination(for: .dayTimeline, currentTab: .breakShelf).tab, .breakShelf)
        XCTAssertEqual(resolver.destination(for: .habits, currentTab: .focus).tab, .today)
        XCTAssertEqual(RouteResolver(flags: .v1).destination(for: .habits, currentTab: .focus).stack, [])
        XCTAssertEqual(resolver.destination(for: .doodleGallery, currentTab: .focus).stack, [.doodleGallery])
        XCTAssertEqual(resolver.destination(for: .calendarSettings, currentTab: .focus).stack, [.calendarSettings])
        XCTAssertEqual(resolver.destination(for: .getFocusCard, currentTab: .focus).stack, [.getFocusCard])
    }

    func testRouterKeepsATodayStack() {
        let router = AppRouter(flags: .current)
        router.go(to: .journal)
        XCTAssertEqual(router.selectedTab, .today)
        XCTAssertEqual(router.todayPath, [])
    }
}

final class JournalControllerTests: XCTestCase {
    func testOneLinePerDayReplacesRatherThanAppends() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        let journal = container.journalController
        journal.saveToday(text: "  First   try\nat a line ", mood: nil)
        journal.saveToday(text: "Better line", mood: .calm)
        XCTAssertEqual(container.journal.allEntries().count, 1)
        XCTAssertEqual(journal.todaysEntry()?.text, "Better line")
        XCTAssertEqual(journal.todaysEntry()?.mood, .calm)
        XCTAssertEqual(container.events.recentEvents.filter { $0.name == .journalEntrySaved }.count, 1)
    }

    func testBlankLineWithoutMoodRemovesToday() {
        let container = makeContainer()
        container.journalController.saveToday(text: "Something", mood: nil)
        container.journalController.saveToday(text: "   ", mood: nil)
        XCTAssertNil(container.journalController.todaysEntry())
        XCTAssertTrue(container.journal.allEntries().isEmpty)
    }

    func testNormalizationCollapsesAndCaps() {
        XCTAssertEqual(JournalController.normalized("a\n\n b   c"), "a b c")
        XCTAssertEqual(JournalController.normalized(String(repeating: "x", count: 400)).count, JournalEntry.maximumLength)
    }

    func testPastEntriesAreNewestFirstAndRunCountsDays() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        for offset in [3, 2, 1] {
            clock.set(testCalendar.date(byAdding: .day, value: -offset, to: referenceDate)!)
            container.journalController.saveToday(text: "Day \(offset)", mood: nil)
        }
        clock.set(referenceDate)
        XCTAssertEqual(container.journalController.pastEntries().map(\.text), ["Day 1", "Day 2", "Day 3"])
        XCTAssertEqual(container.journalController.currentRun(), 3)
        container.journalController.saveToday(text: "Today", mood: .bright)
        XCTAssertEqual(container.journalController.currentRun(), 4)
        XCTAssertEqual(container.journalController.pastEntries().count, 3, "Today is not in Earlier.")
    }

    func testJournalTextNeverReachesAnalytics() {
        let container = makeContainer()
        container.journalController.saveToday(text: "private thought", mood: .heavy)
        for event in container.events.recentEvents {
            XCTAssertFalse(event.properties.values.values.contains { $0.description.contains("private") })
        }
    }
}

final class HabitControllerTests: XCTestCase {
    func testCreateToggleAndRun() {
        let clock = ManualClock(referenceDate)
        let container = makeContainer(clock: clock)
        let habits = container.habitController
        let water = habits.create(title: "  Water   the plants ")!
        XCTAssertEqual(water.title, "Water the plants")
        habits.setDone(habitID: water.id, on: testCalendar.date(byAdding: .day, value: -1, to: referenceDate)!, true)
        habits.toggleToday(habitID: water.id)
        let day = habits.today().first!
        XCTAssertTrue(day.isDoneToday)
        XCTAssertEqual(day.currentRun, 2)
        XCTAssertEqual(day.lastSevenDays, [false, false, false, false, false, true, true])
        habits.toggleToday(habitID: water.id)
        XCTAssertFalse(habits.today().first!.isDoneToday)
        XCTAssertEqual(habits.today().first!.currentRun, 1, "Yesterday still counts until today ends.")
    }

    func testCheckingInTwiceIsIdempotent() {
        let container = makeContainer()
        let habit = container.habitController.create(title: "Stretch")!
        container.habitController.setDone(habitID: habit.id, on: referenceDate, true)
        container.habitController.setDone(habitID: habit.id, on: referenceDate.addingTimeInterval(3600), true)
        XCTAssertEqual(container.habits.checkIns(habitID: habit.id).count, 1)
    }

    func testLimitArchiveAndDelete() {
        let container = makeContainer()
        let habits = container.habitController
        let created = (1...6).compactMap { habits.create(title: "Habit \($0)") }
        XCTAssertEqual(created.count, HabitDefinition.maximumActive)
        XCTAssertFalse(habits.canAddHabit)
        XCTAssertNil(habits.create(title: "   "))
        habits.archive(id: created[0].id)
        XCTAssertEqual(habits.today().count, 4)
        XCTAssertTrue(habits.canAddHabit)
        habits.setDone(habitID: created[1].id, on: referenceDate, true)
        habits.delete(id: created[1].id)
        XCTAssertTrue(container.habits.checkIns(habitID: created[1].id).isEmpty)
    }

    func testRunLineIsOnlyKind() {
        XCTAssertNil(HabitController.runLine(0))
        XCTAssertNil(HabitController.runLine(1))
        XCTAssertEqual(HabitController.runLine(3), "3 days in a row")
    }
}

final class PresetManagementTests: XCTestCase {
    func testBuiltInsIncludeDeepWorkQuickFocusAndLowEnergyStarts() {
        let container = makeContainer()
        let ids = container.presets.allPresets().map(\.id)
        XCTAssertEqual(ids, [.defaultPreset, .study, .deepWork, .quickFocus, .lowEnergy, .tinyStart])
        XCTAssertEqual(PresetCatalog.deepWork.timer.focusDuration, 90 * 60)
        XCTAssertEqual(PresetCatalog.quickFocus.timer.focusDuration, 15 * 60)
        XCTAssertEqual(PresetCatalog.lowEnergy.timer.focusDuration, 10 * 60)
        XCTAssertEqual(PresetCatalog.tinyStart.timer.focusDuration, 5 * 60)
    }

    func testCreateRenameDeleteCustomPreset() {
        let container = makeContainer()
        let prefs = container.preferences
        let base = prefs.preset(.study)
        let custom = prefs.createPreset(named: "  Morning   pages ", basedOn: base)!
        XCTAssertTrue(custom.id.rawValue.hasPrefix("custom-"))
        XCTAssertEqual(custom.name, "Morning pages")
        XCTAssertFalse(custom.isBuiltIn)
        XCTAssertEqual(custom.timer, base.timer)
        XCTAssertEqual(DeepLinkParser().parse(custom.startURL), .startFocus(presetID: custom.id), "Custom presets get working card links.")

        prefs.renamePreset(custom.id, to: "Pages")
        XCTAssertEqual(prefs.preset(custom.id).name, "Pages")

        prefs.setDefaultPreset(custom.id)
        prefs.deletePreset(custom.id)
        XCTAssertNil(container.presets.preset(id: custom.id))
        XCTAssertEqual(prefs.current.defaultPresetID, .defaultPreset, "Deleting the default falls back to Default.")
    }

    func testBuiltInsCannotBeDeletedAndCountIsCapped() {
        let container = makeContainer()
        let prefs = container.preferences
        prefs.deletePreset(.study)
        XCTAssertNotNil(container.presets.preset(id: .study))
        var made = 0
        while prefs.createPreset(named: "P\(made)", basedOn: prefs.preset(.defaultPreset)) != nil { made += 1 }
        XCTAssertEqual(container.presets.allPresets().count, PresetCatalog.maximumPresets)
        XCTAssertNil(prefs.createPreset(named: "One more", basedOn: prefs.preset(.defaultPreset)))
    }

    func testCustomPresetsAreAnonymizedInEvents() {
        let props = EventProperties().preset(FocusPresetID("custom-abc123"))
        XCTAssertEqual(props.values[.presetID]?.description, "custom")
        XCTAssertEqual(EventProperties().preset(.deepWork).values[.presetID]?.description, "deepWork")
    }

    func testStartingACustomPresetUsesItsTimer() {
        let container = makeContainer()
        var base = container.preferences.preset(.defaultPreset)
        base.timer.focusDuration = 40 * 60
        let custom = container.preferences.createPreset(named: "Forty", basedOn: base)!
        let session = container.focus.start(presetID: custom.id, taskID: nil, source: .deepLink).session
        XCTAssertEqual(session.presetID, custom.id)
        XCTAssertEqual(session.configuration.focusDuration, 40 * 60)
    }
}

final class TaskScheduleTests: XCTestCase {
    private func day(_ offset: Int, hour: Int = 9) -> Date {
        let start = testCalendar.startOfDay(for: referenceDate)
        return testCalendar.date(byAdding: .hour, value: offset * 24 + hour, to: start)!
    }

    func testDueDateWording() {
        let describer = DueDateDescriber(calendar: testCalendar)
        // referenceDate is Tuesday, March 10, 2026.
        XCTAssertEqual(describer.describe(day(0), now: referenceDate), "Due today")
        XCTAssertEqual(describer.describe(day(1), now: referenceDate), "Due tomorrow")
        XCTAssertEqual(describer.describe(day(3), now: referenceDate), "Due Friday")
        XCTAssertEqual(describer.describe(day(9), now: referenceDate), "Due Mar 19")
        XCTAssertEqual(describer.describe(day(-1), now: referenceDate), "Past due · yesterday")
        XCTAssertEqual(describer.describe(day(-3), now: referenceDate), "Past due · Saturday")
        XCTAssertEqual(describer.describe(day(-20), now: referenceDate), "Past due · Feb 18")
        XCTAssertFalse(describer.describe(day(-1), now: referenceDate).contains("Missed"))
        XCTAssertTrue(describer.isOverdue(day(-1), now: referenceDate))
        XCTAssertFalse(describer.isOverdue(day(0, hour: 1), now: referenceDate))
        XCTAssertEqual(describer.shortTime(day(0, hour: 16)), "4 PM")
        XCTAssertEqual(describer.shortTime(testCalendar.date(byAdding: .minute, value: 5, to: day(0, hour: 0))!), "12:05 AM")
    }

    func testUpdateDetailsAndUpcoming() {
        let container = makeContainer()
        let tasks = container.taskController
        let lab = tasks.create(title: "Lab report")!
        let read = tasks.create(title: "Read chapter")!
        _ = tasks.create(title: "No dates")
        tasks.updateDetails(id: lab.id, dueAt: day(2), scheduledAt: nil, course: "  Chemistry ")
        tasks.updateDetails(id: read.id, dueAt: nil, scheduledAt: day(0, hour: 15), course: nil)
        XCTAssertEqual(tasks.task(id: lab.id)?.subject?.name, "Chemistry")
        XCTAssertNil(tasks.task(id: lab.id)?.homework?.course)
        XCTAssertEqual(tasks.upcomingTasks().map(\.title), ["Read chapter", "Lab report"])
        tasks.updateDetails(id: lab.id, dueAt: nil, scheduledAt: nil, course: " ")
        XCTAssertNil(tasks.task(id: lab.id)?.subject)
        XCTAssertEqual(tasks.upcomingTasks().map(\.title), ["Read chapter"])
    }

    func testTimelineOrdersTasksSessionsAndEvents() {
        let due = TaskItem(title: "Due today", createdAt: day(-1), dueAt: day(0, hour: 23))
        let scheduled = TaskItem(title: "At three", createdAt: day(-1), scheduledAt: day(0, hour: 15))
        let tomorrow = TaskItem(title: "Tomorrow", createdAt: day(-1), scheduledAt: day(1, hour: 10))
        let engine = FocusTimerEngine()
        var session = engine.makeSession(id: UUID(), configuration: .countdown(25), taskID: nil, sceneID: .rainyBedroom,
                                         renderMode: .scene, presetID: .defaultPreset, source: .manual, at: day(0, hour: 11))
        session = engine.advance(session, to: day(0, hour: 12)).0
        let event = ExternalCalendarEvent(id: "e1", title: "Dentist", startsAt: day(0, hour: 8), endsAt: day(0, hour: 9), sourceIdentifier: "cal")
        let result = DayTimelineBuilder(calendar: testCalendar).items(for: referenceDate, tasks: [due, scheduled, tomorrow],
                                                                       sessions: [session], events: [event])
        XCTAssertEqual(result.dueToday.map(\.title), ["Due today"])
        XCTAssertEqual(result.timed.map(\.title), ["Dentist", "Focus", "At three"])
        XCTAssertEqual(result.timed.last?.duration, 30 * 60)
    }

    func testSubjectPaletteMigrationAndControllerUpdates() throws {
        XCTAssertEqual(SubjectColor.allCases.count, 8)
        XCTAssertEqual(Set(SubjectColor.allCases.map(\.hex)).count, 8)

        let legacy = """
        {"id":"00000000-0000-0000-0000-000000000001","title":"Lab","createdAt":0,
         "homework":{"course":" Biology ","assignmentKind":null}}
        """
        let decoded = try RecordCoding.decoder().decode(TaskItem.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.subject, Subject.migrated(fromCourse: "Biology"))
        XCTAssertTrue(decoded.steps.isEmpty, "old records remain tolerant of missing steps")
        XCTAssertEqual(decoded.repeatRule, .once)

        let container = makeContainer()
        let task = container.taskController.create(title: "Lab")!
        let subject = Subject(name: "Chemistry", color: .lavender)
        container.taskController.updateDetails(
            id: task.id, dueAt: nil, scheduledAt: day(0, hour: 14), subject: subject,
            plannedDuration: 55 * 60, dayPeriod: .afternoon,
            repeatRule: TaskRepeatRule(frequency: .weekly, weekdays: [3])
        )
        let stored = try XCTUnwrap(container.tasks.task(id: task.id))
        XCTAssertEqual(stored.subject, subject)
        XCTAssertEqual(stored.plannedDuration, 55 * 60)
        XCTAssertEqual(stored.dayPeriod, .afternoon)
        XCTAssertEqual(stored.repeatRule.frequency, .weekly)
    }

    func testRecurrenceAndPerOccurrenceCompletion() {
        let weekly = TaskRepeatRule(frequency: .weekly, interval: 2, weekdays: [3, 5])
        XCTAssertTrue(weekly.occurs(on: day(0), anchoredAt: day(0), calendar: testCalendar))
        XCTAssertTrue(weekly.occurs(on: day(2), anchoredAt: day(0), calendar: testCalendar))
        XCTAssertFalse(weekly.occurs(on: day(7), anchoredAt: day(0), calendar: testCalendar))
        XCTAssertTrue(weekly.occurs(on: day(14), anchoredAt: day(0), calendar: testCalendar))

        let monthly = TaskRepeatRule(frequency: .monthly)
        let january31 = testCalendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        let february28 = testCalendar.date(from: DateComponents(year: 2026, month: 2, day: 28))!
        XCTAssertTrue(monthly.occurs(on: february28, anchoredAt: january31, calendar: testCalendar))

        let container = makeContainer()
        let task = container.taskController.create(title: "Review notes")!
        container.taskController.updateDetails(
            id: task.id, dueAt: day(0), scheduledAt: nil, subject: .biology,
            dayPeriod: .evening, repeatRule: TaskRepeatRule(frequency: .daily)
        )
        container.taskController.setCompleted(id: task.id, on: day(0), true)
        let stored = container.tasks.task(id: task.id)!
        XCTAssertTrue(stored.isCompleted(on: day(0), calendar: testCalendar))
        XCTAssertFalse(stored.isCompleted(on: day(1), calendar: testCalendar), "future occurrence stays open")
        XCTAssertNil(stored.completedAt, "series itself is not globally completed")
    }

    func testTimelineGroupsPeriodsAndCarriesSubjectPresentation() {
        let tasks = [
            TaskItem(title: "Loose", createdAt: day(0), dueAt: day(0), dayPeriod: .anytime),
            TaskItem(title: "Read", createdAt: day(0), subject: .literature, dueAt: day(0), dayPeriod: .morning),
            TaskItem(title: "Lab", createdAt: day(0), subject: .biology, scheduledAt: day(0, hour: 13), plannedDuration: 75 * 60)
        ]
        let timeline = DayTimelineBuilder(calendar: testCalendar).items(for: day(0), tasks: tasks, sessions: [], events: [])
        XCTAssertEqual(timeline.untimedGroups.map(\.period), [.anytime, .morning])
        XCTAssertEqual(timeline.untimedGroups[1].items.first?.subject, .literature)
        XCTAssertEqual(timeline.timed.first?.subject, .biology)
        XCTAssertEqual(timeline.timed.first?.duration, 75 * 60)
    }

    func testPreviewFixtureSessionsNeverOverlap() {
        let container = makeContainer()
        PreviewFixtures.populate(container)
        let completed = container.sessions.allSessions().filter { $0.state == .completed }
        for (index, lhs) in completed.enumerated() {
            guard let lhsEnd = lhs.endedAt else { continue }
            for rhs in completed.dropFirst(index + 1) {
                guard let rhsEnd = rhs.endedAt else { continue }
                XCTAssertFalse(lhs.startedAt < rhsEnd && rhs.startedAt < lhsEnd,
                               "fixture sessions \(lhs.id) and \(rhs.id) overlap")
            }
        }
    }

    func testSpokenTaskParsing() {
        let parser = SpokenTaskParser(calendar: testCalendar)
        let friday = parser.draft(from: "finish the lab report by Friday", now: referenceDate)
        XCTAssertEqual(friday?.title, "Finish the lab report")
        XCTAssertEqual(friday?.dueAt, testCalendar.startOfDay(for: day(3)))
        let tomorrow = parser.draft(from: "call Sam tomorrow.", now: referenceDate)
        XCTAssertEqual(tomorrow?.title, "Call Sam")
        XCTAssertEqual(tomorrow?.dueAt, testCalendar.startOfDay(for: day(1)))
        let dueBy = parser.draft(from: "essay outline due by Tuesday", now: referenceDate)
        XCTAssertEqual(dueBy?.title, "Essay outline")
        XCTAssertEqual(dueBy?.dueAt, testCalendar.startOfDay(for: day(7)), "Same weekday means next week.")
        let plain = parser.draft(from: "water the plants", now: referenceDate)
        XCTAssertEqual(plain?.title, "Water the plants")
        XCTAssertNil(plain?.dueAt)
        XCTAssertEqual(parser.draft(from: "tomorrow", now: referenceDate)?.title, "Tomorrow")
        XCTAssertNil(parser.draft(from: "   ", now: referenceDate))
    }

    func testVoiceDraftBecomesSelectedTask() {
        let state = AppState(container: makeContainer())
        let draft = state.draftTask(fromTranscript: "read chapter four today")!
        let task = state.createTask(from: draft, source: .voice)
        XCTAssertEqual(task?.captureSource, .voice)
        XCTAssertEqual(state.selectedTask?.id, task?.id)
        XCTAssertEqual(state.dueLine(for: task!), "Due today")
    }

    func testCalendarEventsOnlyWhenAllowed() {
        let event = ExternalCalendarEvent(id: "e", title: "Class", startsAt: referenceDate, endsAt: referenceDate.addingTimeInterval(3600), sourceIdentifier: "c")
        let adapter = NoCalendarAdapter(access: .granted, events: [event])
        let container = DependencyContainer.inMemory(clock: ManualClock(referenceDate), calendar: testCalendar, calendarAdapter: adapter)
        let state = AppState(container: container)
        XCTAssertTrue(state.timeline(for: referenceDate).timed.isEmpty, "Off until the person turns it on.")
        state.setShowsCalendarEvents(true)
        XCTAssertEqual(state.timeline(for: referenceDate).timed.map(\.title), ["Class"])
    }
}

final class ActivityPresentationTests: XCTestCase {
    func testShelfStatusesExplainSavedProgressAndCompletions() {
        XCTAssertEqual(
            ActivityPresentation.status(for: .sudoku, data: ActivityStatusData(hasSavedProgress: true)),
            ActivityStatus(text: "Saved progress", kind: .inProgress)
        )
        XCTAssertEqual(
            ActivityPresentation.status(for: .picross, data: ActivityStatusData(completedCount: 2)),
            ActivityStatus(text: "Solved 2 times", kind: .completed)
        )
        XCTAssertEqual(
            ActivityPresentation.status(for: .pixelDoodle, data: ActivityStatusData(artifactCount: 1)),
            ActivityStatus(text: "1 doodle on your wall", kind: .collection)
        )
        XCTAssertEqual(
            ActivityPresentation.status(for: .shortRead),
            ActivityStatus(text: "A short public-domain read", kind: .fresh)
        )
    }
}

final class PixelDoodleTests: XCTestCase {
    func testPaintFillAndBlank() {
        var doodle = PixelDoodle()
        XCTAssertTrue(doodle.isBlank)
        XCTAssertTrue(doodle.paint(x: 2, y: 3, color: 4))
        XCTAssertFalse(doodle.paint(x: 2, y: 3, color: 4), "Same color is not a change.")
        XCTAssertFalse(doodle.paint(x: 16, y: 0, color: 1), "Out of bounds is ignored.")
        XCTAssertEqual(doodle.color(x: 2, y: 3), 4)
        // A closed ring, then fill outside it: the inside stays empty.
        var ring = PixelDoodle()
        for i in 5...9 { ring.paint(x: i, y: 5, color: 1); ring.paint(x: i, y: 9, color: 1); ring.paint(x: 5, y: i, color: 1); ring.paint(x: 9, y: i, color: 1) }
        ring.fill(x: 0, y: 0, color: 2)
        XCTAssertEqual(ring.color(x: 7, y: 7), 0)
        XCTAssertEqual(ring.color(x: 15, y: 15), 2)
        XCTAssertEqual(ring.paintedCount, 256 - 9)
        ring.clear()
        XCTAssertTrue(ring.isBlank)
    }

    func testDecodingRejectsWrongSizesAndClampsColors() {
        XCTAssertTrue(PixelDoodle(pixels: [1, 2, 3]).isBlank)
        let clamped = PixelDoodle(pixels: Array(repeating: 200, count: 256))
        XCTAssertEqual(clamped.color(x: 0, y: 0), UInt8(DoodlePalette.colors.count))
        XCTAssertNil(DoodlePalette.hex(for: 0))
        XCTAssertEqual(DoodlePalette.hex(for: 1), DoodlePalette.colors[0])
    }

    func testAutosaveCreatesUpdatesAndRemovesBlank() {
        let state = AppState(container: makeContainer())
        var doodle = PixelDoodle()
        doodle.paint(x: 1, y: 1, color: 2)
        let id = state.autosaveDoodle(doodle, existingID: nil)
        XCTAssertNotNil(id)
        doodle.paint(x: 2, y: 2, color: 3)
        XCTAssertEqual(state.autosaveDoodle(doodle, existingID: id), id)
        XCTAssertEqual(state.doodles.count, 1)
        XCTAssertEqual(state.doodles.first?.doodle?.paintedCount, 2)
        XCTAssertNil(state.autosaveDoodle(PixelDoodle(), existingID: id))
        XCTAssertTrue(state.doodles.isEmpty)
    }

    func testDoodleIsOnTheShelf() {
        XCTAssertEqual(ActivityCatalog.activity(.pixelDoodle)?.category, .quiet)
    }
}

final class RoomCollectionTests: XCTestCase {
    private let evaluator = RoomUnlockEvaluator()

    func testCatalogHasTwentyOriginalReplaceableObjectsAndEveryFixedSlot() {
        XCTAssertEqual(RoomObjectCatalog.all.count, 20)
        XCTAssertEqual(Set(RoomObjectCatalog.all.map(\.id)).count, 20)
        XCTAssertEqual(Set(RoomObjectCatalog.all.map(\.sortOrder)), Set(0..<20))
        XCTAssertEqual(Set(RoomObjectCatalog.all.map(\.slot)), Set(RoomSlot.allCases))
        XCTAssertTrue(RoomObjectCatalog.all.allSatisfy { !$0.name.isEmpty && !$0.unlockRule.plainLanguage.isEmpty })
        XCTAssertTrue(RoomObjectCatalog.all.allSatisfy { $0.spriteAssetName == nil }, "V1 objects are original code-drawn art with a sprite replacement seam.")
        XCTAssertEqual(Set(RoomObjectCatalog.all.map(\.unlockRule).map(ruleKind)),
                       ["sessions", "days", "reads", "doodles", "completedActivities", "triedActivities", "category", "allActivities", "minutes"])
    }

    func testEveryCatalogUnlockRuleAtItsBoundary() {
        for object in RoomObjectCatalog.all {
            let pair = histories(around: object.unlockRule)
            XCTAssertFalse(evaluator.isSatisfied(object.unlockRule, by: pair.before), "Unlocked too early: \(object.name)")
            XCTAssertTrue(evaluator.isSatisfied(object.unlockRule, by: pair.at), "Did not unlock: \(object.name)")
        }
    }

    func testEarnedObjectsNeverRevokeWhenHistoryShrinks() {
        let store = InMemoryRecordStore()
        let repository = StoredRoomCollectionRepository(store: store)
        let controller = RoomCollectionController(repository: repository, clock: ManualClock(referenceDate))
        let allHistory = RoomActivityHistory(completedSessions: 100, focusDays: 30, completedReads: 20,
                                             savedDoodles: 10, completedActivities: 30,
                                             triedActivityIDs: Set(ActivityCatalog.available.map(\.id)), focusedMinutes: 2_000)
        let earned = controller.evaluate(allHistory)
        XCTAssertEqual(earned, Set(RoomObjectCatalog.all.map(\.id)))

        XCTAssertTrue(controller.evaluate(.empty).isEmpty)
        XCTAssertEqual(controller.state().unlockedObjectIDs, Set(RoomObjectCatalog.all.map(\.id)))
    }

    func testRoomCollectionMigrationDefaultsMissingKeysAndKeepsEarnedIDs() throws {
        let legacy = Data(#"{"unlockedObjectIDs":["desk-lamp"]}"#.utf8)
        let decoded = try RecordCoding.decoder().decode(RoomCollectionState.self, from: legacy)
        XCTAssertEqual(decoded.unlockedObjectIDs, [.deskLamp])
        XCTAssertTrue(decoded.acknowledgedObjectIDs.isEmpty)
        XCTAssertTrue(decoded.placements.isEmpty)
        XCTAssertEqual(decoded.schemaVersion, RoomCollectionState.currentSchemaVersion)

        let store = InMemoryRecordStore()
        try store.upsert(StoredRecord(id: "room-collection", kind: .roomCollection,
                                      createdAt: referenceDate, updatedAt: referenceDate,
                                      schemaVersion: 0, payload: legacy))
        let controller = RoomCollectionController(repository: StoredRoomCollectionRepository(store: store),
                                                  clock: ManualClock(referenceDate))
        _ = controller.evaluate(.empty)
        XCTAssertTrue(controller.state().unlockedObjectIDs.contains(.deskLamp))
    }

    func testPlaceReplaceMoveRemoveAndPersistInFixedSlots() throws {
        let store = InMemoryRecordStore()
        let repository = StoredRoomCollectionRepository(store: store)
        let controller = RoomCollectionController(repository: repository, clock: ManualClock(referenceDate))
        var state = RoomCollectionState(unlockedObjectIDs: Set(RoomObjectCatalog.all.map(\.id)))
        try repository.save(state, at: referenceDate)

        let perSlot = Dictionary(grouping: RoomObjectCatalog.all, by: \.slot)
        for slot in RoomSlot.allCases {
            let object = try XCTUnwrap(perSlot[slot]?.first)
            try controller.place(object.id, in: .rainyBedroom, slot: slot)
        }
        XCTAssertEqual(controller.state().placements.count, RoomSlot.allCases.count)

        let deskObjects = try XCTUnwrap(perSlot[.desk])
        XCTAssertGreaterThanOrEqual(deskObjects.count, 2)
        try controller.place(deskObjects[1].id, in: .rainyBedroom, slot: .desk)
        state = controller.state()
        XCTAssertEqual(state.placements.filter { $0.sceneID == .rainyBedroom && $0.slot == .desk }.map(\.objectID), [deskObjects[1].id])

        try controller.place(deskObjects[1].id, in: .libraryLight, slot: .desk)
        XCTAssertEqual(controller.state().placements.filter { $0.objectID == deskObjects[1].id }.count, 2,
                       "The same earned object can decorate separate rooms.")
        controller.remove(from: .rainyBedroom, slot: .desk)
        XCTAssertNil(controller.state().placements.first { $0.sceneID == .rainyBedroom && $0.slot == .desk })
        XCTAssertNotNil(controller.state().placements.first { $0.sceneID == .libraryLight && $0.slot == .desk })

        XCTAssertEqual(StoredRoomCollectionRepository(store: store).load(), controller.state(), "Placements persist through a repository reopen.")
    }

    func testPlacementRejectsLockedUnknownAndWrongSlotObjects() throws {
        let store = InMemoryRecordStore()
        let repository = StoredRoomCollectionRepository(store: store)
        let controller = RoomCollectionController(repository: repository, clock: ManualClock(referenceDate))
        XCTAssertThrowsError(try controller.place(.deskLamp, in: .rainyBedroom, slot: .desk)) {
            XCTAssertEqual($0 as? RoomPlacementFailure, .locked)
        }
        try repository.save(RoomCollectionState(unlockedObjectIDs: [.deskLamp]), at: referenceDate)
        XCTAssertThrowsError(try controller.place(.deskLamp, in: .rainyBedroom, slot: .wall)) {
            XCTAssertEqual($0 as? RoomPlacementFailure, .wrongSlot)
        }
        XCTAssertThrowsError(try controller.place("unknown", in: .rainyBedroom, slot: .desk)) {
            XCTAssertEqual($0 as? RoomPlacementFailure, .unknownObject)
        }
    }

    func testUnlockAcknowledgementDoesNotChangeOwnership() throws {
        let store = InMemoryRecordStore()
        let repository = StoredRoomCollectionRepository(store: store)
        let controller = RoomCollectionController(repository: repository, clock: ManualClock(referenceDate))
        try repository.save(RoomCollectionState(unlockedObjectIDs: [.deskLamp, .globe]), at: referenceDate)
        controller.acknowledgeUnlocks()
        let state = controller.state()
        XCTAssertEqual(state.acknowledgedObjectIDs, [.deskLamp, .globe])
        XCTAssertEqual(state.unlockedObjectIDs, [.deskLamp, .globe])
    }

    private func histories(around rule: RoomUnlockRule) -> (before: RoomActivityHistory, at: RoomActivityHistory) {
        var before = RoomActivityHistory.empty
        var at = RoomActivityHistory.empty
        switch rule {
        case .completedSessions(let value): before.completedSessions = value - 1; at.completedSessions = value
        case .focusDays(let value): before.focusDays = value - 1; at.focusDays = value
        case .completedReads(let value): before.completedReads = value - 1; at.completedReads = value
        case .savedDoodles(let value): before.savedDoodles = value - 1; at.savedDoodles = value
        case .completedActivities(let value): before.completedActivities = value - 1; at.completedActivities = value
        case .triedActivities(let value):
            let ids = ActivityCatalog.available.map(\.id)
            before.triedActivityIDs = Set(ids.prefix(value - 1)); at.triedActivityIDs = Set(ids.prefix(value))
        case .triedCategory(let category):
            let ids = ActivityCatalog.available.filter { $0.category == category }.map(\.id)
            before.triedActivityIDs = Set(ids.dropLast()); at.triedActivityIDs = Set(ids)
        case .triedEveryActivity:
            let ids = ActivityCatalog.available.map(\.id)
            before.triedActivityIDs = Set(ids.dropLast()); at.triedActivityIDs = Set(ids)
        case .focusedMinutes(let value): before.focusedMinutes = value - 1; at.focusedMinutes = value
        }
        return (before, at)
    }

    private func ruleKind(_ rule: RoomUnlockRule) -> String {
        switch rule {
        case .completedSessions: return "sessions"
        case .focusDays: return "days"
        case .completedReads: return "reads"
        case .savedDoodles: return "doodles"
        case .completedActivities: return "completedActivities"
        case .triedActivities: return "triedActivities"
        case .triedCategory: return "category"
        case .triedEveryActivity: return "allActivities"
        case .focusedMinutes: return "minutes"
        }
    }
}

let deflateDynamicFixture = "7czRCcAgDEXRVd4EncYFAgYiNSo2Rdy+pQt0gfd7uZxkiiml4dQREFyhkjem7TBHb4h3WKXlvrCsVP1CFR+w213zgUSCBAkSJEiQIEGCxB/xAA=="
let deflateFixedFixture = "KyzNTC1RKEQi0/KTS4sB"
let deflateStoredFixture = "ARwA4/9zdG9yZWQgYmxvY2ssIG5vIGNvbXByZXNzaW9u"
let epubFixture = "UEsDBBQAAAAAAAAAIQBvYassFAAAABQAAAAIAAAAbWltZXR5cGVhcHBsaWNhdGlvbi9lcHViK3ppcFBLAwQUAAAACAAxDDRdHTIDNp8AAADiAAAAFgAAAE1FVEEtSU5GL2NvbnRhaW5lci54bWxVjkEOwiAURPc9BWFrWnRLgCYmrjXxBF/6q0TgE6BGby+6qHE3ycy8GTU+g2cPzMVR1Hw3bPloOmUpVnAR87/FWjgWzZccJUFxRUYIWGS1khLGiewSMFb5jckVwk3HmMpEdXYei1klmxfv+wT1pvnxsD+dxafTCAOlmbOAk4O+vhJqDil5Z6G2L4Lwkkqr2TtccdPGuDBK/PidEuu2eQNQSwMEFAAAAAgAMQw0XVoqMdhjAQAAEQMAABEAAABPRUJQUy9jb250ZW50Lm9wZqWSzU7DMBCE7zyFZYkTatyEA6hKUsGBMwh4AGNvmlUd29ibtrw9bpqU8ichcbN2Zr+xRy6Xu86wDYSIzlY8z+acgVVOo11V/PnpbnbNl/VZ6aVayxWw5Lax4i2RXwix3W4z1L7JXFiJYj6/Es43/AN3ucf1Fl97mKEGS9gghIqj5vUZY2UHJLUkecAutDqSfR/MQNVKgIEu7UaRZ7kYFtOqVgtCMlDfsIcegdgTRGK3zq1LcdSOVhVAkgv1I6ExgzUOtml+NAZctRTr+/7FoGLadRLt4ByF/a3FdO3DG6TFJgFHBhJ0DHXFrdxw1gZohmO2a6kznHWgUc7ozUPFpfcpRFKqSgzyxW5v8cF5CIQQDxDxlazyCUywI6Fa6QnCeTHP/57yHVr8BC3+Q4xxQkZ6M5ANg1PQISlNxdjrSZVl9GjhhJlACTv1yZlJskx/ybpP0Se21NNvSjFFjimlGD94/Q5QSwMEFAAAAAgAMQw0XXFyHBmEAAAArAAAAA8AAABPRUJQUy9uYXYueGh0bWwljkEOgzAMBL+y4gFYVU9UaS59iQGriWQSlBhCf99Cr6vRzLpgi+JYNNVnF8zWB1FrrW/3Ppc33YZhoONkOu/GPH+8S7x7l9U7jf6Vk0myiiBFUEPedEaSXQpGQRGewRWMKfBq1zjxVgXRECtSNmhMwgVsYNXe0U/q6LTT1aF/k84H/gtQSwMEFAAAAAgAMQw0XSmBRexzAQAA8QIAABoAAABPRUJQUy90ZXh0L2NoYXB0ZXIgMS54aHRtbN2SwU7cMBCG7zzF1Ic9lQwWly7rDRK7SCBRQFUQ7dHEk9hKYqfxbMOq6rvXSUDi0CfoyaP5/29mNGN1+dq18IuG6ILfCpmdCSBfBuN8vRUHrk6/iMv8RH3aP+yKH4/XYDn5H5+u7m53IE4Rn893iPtiD99viq93IDOJeH0vQFjm/gJxHMdsPM/CUGPxDV8nXMoJeI8zw0akDnPhNIyP23+wcr1eL4TIlSVtcsWOW8p3FqTCJVaRj+npf3d6qJ2/OPujcEkpnJkT9RLMMRWQidM907DyL7HfPHhKDpn0Pr9lGHUEDbHTbQtDCN2qMzrazZIgHw61BQ5QEbVgqTUZKOry+8A2bU1hisETGTJgQspkCvu5dGEJGuI0KpStK5tkCFUF2hvgJE2tYCTP8PPgiEHX2vnPs9Q4P3nfBLaaodMNRTiGA/jArqTZV7ahbDL4/xp9XCEt5KRWbogMvR4YVrrrN+lsS8GERXpbPC5Hx+n35H8BUEsDBBQAAAAIADEMNF19zcyKyQAAAHYKAAAZAAAAT0VCUFMvdGV4dC9jaGFwdGVyMi54aHRtbO2WMQ7CMAxFd05hMaNGlKkoZOEKXCCkhkRJ41KMQm9PWjgBW6Rslt6X3vAWS8tDgPcQ4vO0tczjUYiUUpMODU13se+6TryXzVZJi7pXkh0HVGcLrRTfW4ovuVI/q420baZ6ZJzgkijDVslRXSyCR857MMEZjz3Q7QY69sAZTUQDJIwMj5dDBn3XLu5W5F1ctj/AVjMM2uMTZnpBJHYG150JZHwDVfS3SIqxpipDVFMVI6qpihHVVMWIaqpiRGsqsX6H+RvMv6T6AFBLAwQUAAAACAAxDDRdeuvRABEAAAAPAAAADwAAAE9FQlBTL3N0eWxlLmNzcytQqFbITSxKz8yzUjBQqAUAUEsBAhQDFAAAAAAAAAAhAG9hqywUAAAAFAAAAAgAAAAAAAAAAAAAAIABAAAAAG1pbWV0eXBlUEsBAhQDFAAAAAgAMQw0XR0yAzafAAAA4gAAABYAAAAAAAAAAAAAAIABOgAAAE1FVEEtSU5GL2NvbnRhaW5lci54bWxQSwECFAMUAAAACAAxDDRdWiox2GMBAAARAwAAEQAAAAAAAAAAAAAAgAENAQAAT0VCUFMvY29udGVudC5vcGZQSwECFAMUAAAACAAxDDRdcXIcGYQAAACsAAAADwAAAAAAAAAAAAAAgAGfAgAAT0VCUFMvbmF2LnhodG1sUEsBAhQDFAAAAAgAMQw0XSmBRexzAQAA8QIAABoAAAAAAAAAAAAAAIABUAMAAE9FQlBTL3RleHQvY2hhcHRlciAxLnhodG1sUEsBAhQDFAAAAAgAMQw0XX3NzIrJAAAAdgoAABkAAAAAAAAAAAAAAIAB+wQAAE9FQlBTL3RleHQvY2hhcHRlcjIueGh0bWxQSwECFAMUAAAACAAxDDRdeuvRABEAAAAPAAAADwAAAAAAAAAAAAAAgAH7BQAAT0VCUFMvc3R5bGUuY3NzUEsFBgAAAAAHAAcAwgEAADkGAAAAAA=="

final class EPUBReaderTests: XCTestCase {
    private func bytes(_ base64: String) -> [UInt8] { [UInt8](Data(base64Encoded: base64)!) }

    func testAppBundleLocatorListsAllFourBundledBooks() {
        #if SWIFT_PACKAGE
        // SwiftPM mirrors the app bundle layout with the copied test resource
        // bundle; the Xcode branch below validates the real app target.
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: AppState.self)
        #endif
        let urls = BundledBookLocator.urls(in: bundle)
        let names = Set(urls.map(\.lastPathComponent))
        XCTAssertEqual(names, BundledBookLocator.expectedFileNames)
        XCTAssertEqual(urls.count, BundledBookLocator.expectedFileNames.count)
    }

    func testBundledBookCatalogCoversEveryExpectedFile() {
        XCTAssertEqual(Set(BundledBookLocator.catalog.keys), BundledBookLocator.expectedFileNames)
        XCTAssertTrue(BundledBookLocator.catalog.values.allSatisfy { !$0.title.isEmpty && !$0.author.isEmpty && $0.sittingCount > 0 })
    }

    func testEveryBundledStandardEbookResourceParsesAndIsPublicDomain() throws {
        let expected: [String: (title: String, author: String)] = [
            "e-m-forster_short-fiction": ("Short Fiction", "E. M. Forster"),
            "henry-david-thoreau_essays": ("Essays", "Henry David Thoreau"),
            "robert-louis-stevenson_travel-essays": ("Travel Essays", "Robert Louis Stevenson"),
            "saki_short-fiction": ("Short Fiction", "Saki")
        ]
        #if SWIFT_PACKAGE
        let resourceBundle = Bundle.module
        #else
        let resourceBundle = Bundle(for: EPUBReaderTests.self)
        #endif
        // SwiftPM places fixtures in the test bundle, while an Xcode unit-test
        // run may place the same folder in the host app bundle. Consult both
        // locations by explicit expected stem so target resource layout never
        // changes the provenance assertion.
        let bundles = [resourceBundle, Bundle(for: AppState.self), Bundle.main]
        let urls = expected.keys.compactMap { stem in
            bundles.lazy.compactMap { bundle in
                bundle.url(forResource: stem, withExtension: "epub", subdirectory: "PublicDomainBooks")
                    ?? bundle.url(forResource: stem, withExtension: "epub")
            }.first
        }
        XCTAssertEqual(urls.count, expected.count)
        for url in urls {
            let stem = url.deletingPathExtension().lastPathComponent
            let metadata = try XCTUnwrap(expected[stem], "Unexpected bundled EPUB: \(stem)")
            let book = try EPUBParser.parse(data: Data(contentsOf: url))
            XCTAssertEqual(book.title, metadata.title, stem)
            XCTAssertEqual(book.author, metadata.author, stem)
            XCTAssertFalse(book.chapters.isEmpty, stem)
            XCTAssertGreaterThan(SittingPlanner.sittings(for: book).count, 0, stem)
        }

        let library = FileBookLibrary(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString),
                                      bundledURLs: urls, clock: ManualClock(referenceDate))
        let summaries = library.books()
        XCTAssertEqual(summaries.count, expected.count)
        XCTAssertTrue(summaries.allSatisfy { summary in
            summary.origin == .bundled && summary.license == .publicDomain && summary.sittingCount > 0
        })
    }

    func testInflateAllBlockTypes() throws {
        let expected = String(repeating: "The rain kept a steady rhythm on the window while the lamp hummed. ", count: 40)
        XCTAssertEqual(String(bytes: try Inflate.decompress(bytes(deflateDynamicFixture)), encoding: .utf8), expected)
        XCTAssertEqual(String(bytes: try Inflate.decompress(bytes(deflateFixedFixture)), encoding: .utf8), "quiet quiet quiet focus")
        XCTAssertEqual(String(bytes: try Inflate.decompress(bytes(deflateStoredFixture)), encoding: .utf8), "stored block, no compression")
    }

    func testInflateRejectsGarbageAndBombs() {
        XCTAssertThrowsError(try Inflate.decompress([0xFF, 0xFF, 0xFF]))
        XCTAssertThrowsError(try Inflate.decompress(bytes(deflateDynamicFixture), limit: 100)) { error in
            XCTAssertEqual(error as? Inflate.Failure, .tooLarge)
        }
        XCTAssertThrowsError(try Inflate.decompress(Array(bytes(deflateDynamicFixture).prefix(10))))
    }

    func testParsesEPUBChaptersTitlesAndEntities() throws {
        let book = try EPUBParser.parse(data: Data(base64Encoded: epubFixture)!)
        XCTAssertEqual(book.title, "A Quiet Test Book")
        XCTAssertEqual(book.author, "Still Tests")
        XCTAssertEqual(book.rights, "Public domain")
        XCTAssertEqual(book.chapters.map(\.title), ["Chapter One", "Chapter Two"], "Non-linear nav is skipped; %20 paths resolve.")
        XCTAssertEqual(book.chapters[0].paragraphs.first, "It was a small room\u{2014}small enough to feel held. Nothing needed doing.")
        XCTAssertEqual(book.chapters[0].paragraphs.last, "The end of the first part & a quiet close.")
        XCTAssertFalse(book.chapters[0].paragraphs.contains { $0.contains("Chapter") }, "The heading isn't repeated as a paragraph.")
        XCTAssertFalse(book.chapters.flatMap(\.paragraphs).contains { $0.contains("margin") }, "Styles are dropped.")
        XCTAssertEqual(book.chapters[1].paragraphs.count, 6)
    }

    func testRejectsNonBooks() {
        XCTAssertThrowsError(try EPUBParser.parse(data: Data("not a zip".utf8)))
    }

    func testPathResolution() {
        XCTAssertEqual(EPUBParser.resolve("text/chapter%201.xhtml#p2", relativeTo: "OEBPS"), "OEBPS/text/chapter 1.xhtml")
        XCTAssertEqual(EPUBParser.resolve("../images/a.png", relativeTo: "OEBPS/text"), "OEBPS/images/a.png")
        XCTAssertEqual(EPUBParser.resolve("ch.xhtml", relativeTo: ""), "ch.xhtml")
    }

    func testHTMLEntitiesBecomeXMLSafe() {
        XCTAssertEqual(XHTMLText.xmlSafe("a&nbsp;b &amp; c &unknown; d"), "a&#160;b &amp; c   d")
        XCTAssertEqual(XHTMLText.fallbackParagraphs("<p>One &amp; two</p><div>Three<br/>four</div><script>x()</script>"),
                       ["One & two", "Three", "four"])
    }

    func testSittingsSplitLongChaptersAtParagraphs() {
        let paragraph = String(repeating: "word ", count: 100).trimmingCharacters(in: .whitespaces)
        let parts = SittingPlanner.split(Array(repeating: paragraph, count: 17))
        XCTAssertEqual(parts.map(\.count), [7, 7, 3], "About 700 words each; a 300-word tail stands on its own.")
        let tail = SittingPlanner.split(Array(repeating: paragraph, count: 8))
        XCTAssertEqual(tail.map(\.count), [8], "A tail under 250 words joins the part before it.")
        let book = EPUBBook(title: "T", author: "A", rights: nil, chapters: [
            EPUBBook.Chapter(title: "One", paragraphs: Array(repeating: paragraph, count: 17)),
            EPUBBook.Chapter(title: "Two", paragraphs: [paragraph])
        ])
        let sittings = SittingPlanner.sittings(for: book)
        XCTAssertEqual(sittings.map(\.displayTitle), ["One · Part 1 of 3", "One · Part 2 of 3", "One · Part 3 of 3", "Two"])
        XCTAssertEqual(sittings.map(\.index), [0, 1, 2, 3])
    }

    func testImportReadAndBookmarkABook() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("still-books-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("incoming.epub")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(base64Encoded: epubFixture)!.write(to: source)

        let clock = ManualClock(referenceDate)
        let library = FileBookLibrary(directory: directory.appendingPathComponent("Books"), bundledURLs: [], clock: clock)
        let container = DependencyContainer.inMemory(clock: clock, calendar: testCalendar, bookLibrary: library)
        let state = AppState(container: container)
        state.importBook(from: source)
        let book = try XCTUnwrap(state.books.first)
        XCTAssertEqual(book.title, "A Quiet Test Book")
        XCTAssertEqual(book.origin, .imported)
        XCTAssertEqual(book.license, .userProvided)
        XCTAssertEqual(book.sittingCount, 2)

        XCTAssertEqual(state.nextSitting(bookID: book.id)?.chapterTitle, "Chapter One")
        state.finishSitting(bookID: book.id, index: 0)
        XCTAssertEqual(state.nextSitting(bookID: book.id)?.chapterTitle, "Chapter Two")
        state.finishSitting(bookID: book.id, index: 0)
        XCTAssertEqual(state.readingProgress(bookID: book.id).finishedSittings, 1, "Re-finishing an earlier sitting doesn't move the bookmark.")
        state.finishSitting(bookID: book.id, index: 1)
        XCTAssertNil(state.nextSitting(bookID: book.id), "Finished.")
        state.restartBook(book.id)
        XCTAssertEqual(state.nextSitting(bookID: book.id)?.index, 0)

        // A fresh library reads the saved index from disk.
        let reopened = FileBookLibrary(directory: directory.appendingPathComponent("Books"), bundledURLs: [], clock: clock)
        XCTAssertEqual(reopened.books().map(\.title), ["A Quiet Test Book"])
        XCTAssertEqual(try reopened.sittings(bookID: book.id).count, 2)

        let item = BookReadingController.readingItem(try reopened.sittings(bookID: book.id)[1], book: book)
        XCTAssertEqual(item.format, .epub)
        XCTAssertEqual(item.source, "A Quiet Test Book")

        state.removeBook(book.id)
        XCTAssertTrue(state.books.isEmpty)
    }

    func testImportingSomethingElseFailsCalmly() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("still-books-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bogus = directory.appendingPathComponent("notes.epub")
        try Data("hello".utf8).write(to: bogus)
        let library = FileBookLibrary(directory: directory.appendingPathComponent("Books"), bundledURLs: [], clock: ManualClock(referenceDate))
        XCTAssertThrowsError(try library.importBook(from: bogus)) { error in
            XCTAssertEqual(error as? BookLibraryError, .unreadable)
        }
        XCTAssertTrue(library.books().isEmpty)
    }

    func testBundledBooksAreListedAsPublicDomain() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("still-bundle-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("A Quiet Book.epub")
        try Data(base64Encoded: epubFixture)!.write(to: url)
        let library = FileBookLibrary(directory: directory.appendingPathComponent("Books"), bundledURLs: [url], clock: ManualClock(referenceDate))
        let book = try XCTUnwrap(library.books().first)
        XCTAssertEqual(book.id, "bundled-a-quiet-book")
        XCTAssertEqual(book.license, .publicDomain)
        XCTAssertThrowsError(try library.removeBook(id: book.id), "Bundled books can't be removed.")
    }
}

final class MorningStartAndWidgetTests: XCTestCase {
    func testPlanSummaryAndValidation() {
        var plan = MorningStartPlan.standard
        XCTAssertEqual(plan.summary, "Weekdays at 8:00 AM")
        plan.weekdays = [1, 7]
        plan.hour = 21
        plan.minute = 5
        XCTAssertEqual(plan.summary, "Weekends at 9:05 PM")
        plan.weekdays = [2, 4]
        XCTAssertEqual(plan.summary, "Mon, Wed at 9:05 PM")
        plan.weekdays = []
        XCTAssertEqual(plan.summary, "No days chosen")
        let wild = MorningStartPlan(isEnabled: true, hour: 40, minute: -3, weekdays: [0, 3, 9], presetID: .study).validated()
        XCTAssertEqual(wild.hour, 23)
        XCTAssertEqual(wild.minute, 0)
        XCTAssertEqual(wild.weekdays, [3])
    }

    func testRecordingSchedulerOnlyKeepsEnabledPlans() {
        let scheduler = RecordingMorningStartScheduler()
        scheduler.scheduleMorningStart(MorningStartPlan.standard)
        XCTAssertNil(scheduler.scheduledPlan, "Disabled plans aren't scheduled.")
        var plan = MorningStartPlan.standard
        plan.isEnabled = true
        scheduler.scheduleMorningStart(plan)
        XCTAssertEqual(scheduler.scheduledPlan, plan)
        scheduler.cancelMorningStart()
        XCTAssertNil(scheduler.scheduledPlan)
    }

    func testWakeUpPreviewWaitsForCardWithoutClaimingAlarmControl() {
        let fallback = RecordingMorningStartScheduler()
        let scheduler = PreviewWakeUpScheduler(fallback: fallback)
        var schedule = MorningStartPlan.standard
        schedule.isEnabled = true
        let plan = WakeUpPlan(schedule: schedule, stopWith: .focusCard)
        scheduler.schedule(plan)
        XCTAssertEqual(fallback.scheduledPlan, schedule)
        XCTAssertTrue(scheduler.simulateOpening())
        XCTAssertTrue(scheduler.isWaitingForFocusCard)
        XCTAssertTrue(scheduler.simulateFocusCardTap())
        XCTAssertFalse(scheduler.isWaitingForFocusCard)
        XCTAssertFalse(scheduler.simulateFocusCardTap())
    }

    func testPreferencesWithoutNewKeysStillDecode() throws {
        let old = #"{"hasCompletedOnboarding":true,"defaultPresetID":"study"}"#
        let prefs = try RecordCoding.decoder().decode(UserPreferences.self, from: Data(old.utf8))
        XCTAssertEqual(prefs.morningStart, .standard)
        XCTAssertEqual(prefs.wakeUpStopMethod, .button)
        XCTAssertFalse(prefs.showsCalendarEvents)
        XCTAssertFalse(prefs.showsGoogleCalendarEvents)
        XCTAssertEqual(prefs.defaultPresetID, .study)
    }

    func testGoogleStandInOnlyReturnsGrantedOverlappingSampleEvents() async {
        let adapter = SampleGoogleCalendarAdapter(now: referenceDate, calendar: testCalendar)
        XCTAssertTrue(adapter.events(from: referenceDate, to: referenceDate.addingTimeInterval(86_400)).isEmpty)
        let access = await adapter.requestAccess()
        XCTAssertEqual(access, .granted)
        let dayStart = testCalendar.startOfDay(for: referenceDate)
        let events = adapter.events(from: dayStart, to: dayStart.addingTimeInterval(86_400))
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.sourceIdentifier == "google-preview" && $0.title.contains("Sample") })
        adapter.disconnect()
        XCTAssertEqual(adapter.access, .notDetermined)
    }

    func testSeasonalScenesAreCosmeticAndEarnedScenesRemainFree() async {
        XCTAssertTrue(SceneCatalog.all.allSatisfy { $0.entitlementKey == nil })
        XCTAssertEqual(SceneCatalog.seasonal.count, 3)
        XCTAssertTrue(SceneCatalog.seasonal.allSatisfy { $0.entitlementKey == PurchaseProductCatalog.stillPlusMonthly })

        let purchases = LocalPurchaseService()
        XCTAssertTrue(purchases.purchasedProductIDs.isEmpty)
        let purchase = await purchases.purchase(productID: PurchaseProductCatalog.stillPlusMonthly)
        XCTAssertEqual(purchase, .purchased)
        XCTAssertTrue(purchases.purchasedProductIDs.contains(PurchaseProductCatalog.stillPlusMonthly))
        let restore = await purchases.restorePurchases()
        XCTAssertEqual(restore, .purchased)
    }

    func testEitherStillPlusPlanGrantsTheSameLocalEntitlement() async {
        let purchases = LocalPurchaseService()
        XCTAssertFalse(purchases.hasStillPlus)
        let outcome = await purchases.purchase(productID: PurchaseProductCatalog.stillPlusYearly)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertTrue(purchases.hasStillPlus)
        XCTAssertEqual(PurchaseProductCatalog.productIDs, [
            PurchaseProductCatalog.stillPlusMonthly,
            PurchaseProductCatalog.stillPlusYearly
        ])
    }

    func testAppPublishesAWidgetSnapshot() throws {
        let container = makeContainer()
        PreviewFixtures.populate(container)
        let state = AppState(container: container)
        let writer = try XCTUnwrap(container.widgetSnapshots as? RecordingWidgetSnapshotWriter)
        let snapshot = try XCTUnwrap(writer.lastSnapshot)
        XCTAssertEqual(snapshot.completedSessions, state.stats.completedSessions)
        XCTAssertEqual(snapshot.defaultPresetName, "Default")
        XCTAssertEqual(snapshot.defaultPresetMinutes, 25)
        XCTAssertEqual(snapshot.lastSevenDays.count, 7)
        XCTAssertEqual(snapshot.focus(on: referenceDate, calendar: testCalendar), state.stats.todayFocus)
        XCTAssertEqual(snapshot.focus(on: referenceDate.addingTimeInterval(86_400), calendar: testCalendar), 0, "Yesterday's number isn't shown tomorrow.")
    }

    func testWidgetSnapshotRoundTripsThroughDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "still-tests-\(UUID().uuidString)"))
        WidgetSnapshotStore.save(.placeholder, to: defaults)
        XCTAssertEqual(WidgetSnapshotStore.load(from: defaults), .placeholder)
    }
}

final class PlantGrowthTests: XCTestCase {
    func testPlantGrowsWithSessionsAndOnlyForward() {
        let fresh = AppState(container: makeContainer())
        XCTAssertEqual(fresh.plantStage, .sprout)
        XCTAssertEqual(fresh.sessionsToNextPlantStage, 3)

        let container = makeContainer()
        PreviewFixtures.populate(container, completedSessions: 9)
        let grown = AppState(container: container)
        XCTAssertEqual(grown.plantStage, .leafy)
        XCTAssertEqual(grown.sessionsToNextPlantStage, 1)

        let v1 = AppState(container: DependencyContainer.inMemory(clock: ManualClock(referenceDate), calendar: testCalendar, flags: .v1))
        XCTAssertEqual(v1.plantStage, .full, "With growth off, the plant is always full.")
        XCTAssertNil(v1.sessionsToNextPlantStage)
    }
}

final class BlockingBoundaryTests: XCTestCase {
    func testMockNeverClaimsShieldingAndOverrideIsSafe() {
        let state = AppState(container: makeContainer())
        XCTAssertFalse(state.isShieldingApps)
        XCTAssertEqual(state.blockingCapability, .simulationOnly)
        state.endBlockingNow()
        XCTAssertFalse(state.isShieldingApps)
        XCTAssertEqual(state.container.events.recentEvents.last?.name, .blockingOverride)
    }

    func testSelectionsAreStoredPerPreset() {
        let store = KeyValueBlockingSelectionStore(store: InMemoryKeyValueStore())
        store.setSelectionData(Data([1, 2]), for: .study)
        XCTAssertEqual(store.selectionData(for: .study), Data([1, 2]))
        XCTAssertNil(store.selectionData(for: .defaultPreset))
        store.setSelectionData(nil, for: .study)
        XCTAssertNil(store.selectionData(for: .study))
    }
}

// MARK: - Onboarding P2

final class OnboardingPreferenceTests: XCTestCase {
    func testVersionOnePreferencesMigrateWithSafeDefaults() throws {
        let data = Data(#"{"hasCompletedOnboarding":true,"onboardingGoal":"scrollLess","schemaVersion":1}"#.utf8)
        let preferences = try RecordCoding.decoder().decode(UserPreferences.self, from: data)

        XCTAssertEqual(preferences.schemaVersion, UserPreferences.currentSchemaVersion)
        XCTAssertEqual(preferences.onboardingGoal, .scrollLess)
        XCTAssertNil(preferences.breakAppeal)
        XCTAssertEqual(preferences.appAccentPalette, .mint)
    }

    func testNewPreferencesHaveLocalNonDestructiveDefaults() {
        let preferences = UserPreferences()
        XCTAssertFalse(preferences.hasCompletedOnboarding)
        XCTAssertNil(preferences.onboardingGoal)
        XCTAssertNil(preferences.breakAppeal)
        XCTAssertEqual(preferences.appAccentPalette, .mint)
        XCTAssertEqual(preferences.schemaVersion, UserPreferences.currentSchemaVersion)
    }

    func testBreakAppealOverridesGoalOnlyForCategorySeed() {
        let personalized = Personalization(goal: .calmerPhone, breakAppeal: .puzzles)
        XCTAssertEqual(personalized.categoryOrder, [.puzzle, .reset, .quiet])
        XCTAssertEqual(personalized.preferredRenderMode, .calm)
        XCTAssertFalse(personalized.startsWithSound)
    }

    func testOnboardingCanCompleteWithEveryQuestionSkipped() {
        let container = makeContainer()
        container.preferences.completeOnboarding(OnboardingAnswers())
        let preferences = container.preferencesStore.load()

        XCTAssertTrue(preferences.hasCompletedOnboarding)
        XCTAssertNil(preferences.onboardingGoal)
        XCTAssertNil(preferences.breakAppeal)
        XCTAssertEqual(preferences.appAccentPalette, .mint)
        XCTAssertEqual(container.preferences.preset(.defaultPreset).timer.focusDuration, minutes(25))
    }

    func testTargetedPreferenceChangesPreserveOtherAnswersAndData() {
        let container = makeContainer()
        container.preferences.completeOnboarding(OnboardingAnswers(
            goal: .focusBetter,
            breakAppeal: .quiet,
            appAccentPalette: .peach
        ))
        let task = container.taskController.create(title: "Keep this task")

        container.preferences.setBreakAppeal(.move)
        var preferences = container.preferencesStore.load()
        XCTAssertEqual(preferences.onboardingGoal, .focusBetter)
        XCTAssertEqual(preferences.breakAppeal, .move)
        XCTAssertEqual(preferences.appAccentPalette, .peach)
        XCTAssertTrue(preferences.hasCompletedOnboarding)
        XCTAssertNotNil(task.flatMap { container.tasks.task(id: $0.id) })

        container.preferences.setOnboardingGoal(nil)
        preferences = container.preferencesStore.load()
        XCTAssertNil(preferences.onboardingGoal)
        XCTAssertEqual(preferences.breakAppeal, .move)
        XCTAssertEqual(preferences.appAccentPalette, .peach)
        XCTAssertTrue(preferences.hasCompletedOnboarding)
    }

    func testShelfRankingUsesOnboardingSeedBeforeUsage() {
        let ranked = BreakShelfRanking().ranked(
            catalog: ActivityCatalog.available,
            usages: [],
            personalization: Personalization(goal: nil, breakAppeal: .quiet)
        )
        XCTAssertEqual(ranked.first?.category, .quiet)
        XCTAssertEqual(Array(ranked.prefix(3).map(\.id)), [.shortRead, .creativePrompt, .pixelDoodle])
    }

    func testShelfRankingLetsRealUsageTakeOver() {
        func usage(_ activity: BreakActivityID, at offset: TimeInterval) -> ActivityUsage {
            ActivityUsage(
                id: UUID(), activityID: activity,
                startedAt: referenceDate.addingTimeInterval(offset), endedAt: nil,
                outcome: .completed, context: .shelf
            )
        }
        let usages = [
            usage(.boxBreathing, at: 10),
            usage(.boxBreathing, at: 20),
            usage(.sudoku, at: 30)
        ]
        let ranked = BreakShelfRanking().ranked(
            catalog: ActivityCatalog.available,
            usages: usages,
            personalization: Personalization(goal: nil, breakAppeal: .quiet)
        )
        XCTAssertEqual(ranked.first?.id, .boxBreathing)
        XCTAssertEqual(ranked.dropFirst().first?.id, .sudoku)
    }

    func testCompletionSuggestionsRemainDiverseWithBreakPreference() {
        let request = BreakSuggestionRequest(
            availableBreak: minutes(6), catalog: ActivityCatalog.available,
            usedToday: [], lastUsedAt: [:],
            categoryOrder: Personalization(goal: .focusBetter, breakAppeal: .quiet).categoryOrder,
            daySeed: 12
        )
        let suggestions = BreakSuggestionEngine().suggestions(for: request).activities
        XCTAssertEqual(suggestions.count, 3)
        XCTAssertEqual(Set(suggestions.map(\.category)), Set(ActivityCategory.allCases))
    }
}

final class AlternateAppIconTests: XCTestCase {
    func testPaletteIconNameContract() {
        XCTAssertNil(AppAccentPalette.mint.alternateIconName)
        XCTAssertEqual(AppAccentPalette.peach.alternateIconName, "AppIconPeach")
        XCTAssertEqual(AppAccentPalette.sky.alternateIconName, "AppIconSky")
    }

    func testControllerRoutesPaletteChangesThroughIconAbstraction() {
        let keyValues = InMemoryKeyValueStore()
        let preferencesStore = CodablePreferencesStore(store: keyValues)
        let icons = RecordingAlternateAppIconChanger()
        let controller = PreferencesController(
            preferences: preferencesStore,
            presets: StoredPresetRepository(store: keyValues),
            recordStore: InMemoryRecordStore(),
            events: LocalEventTracker(clock: ManualClock(referenceDate)),
            notifications: RecordingNotificationScheduler(),
            audio: SilentAmbientAudioPlayer(),
            alternateAppIcons: icons
        )

        controller.setAppAccentPalette(.sky)
        controller.setAppAccentPalette(.mint)

        XCTAssertEqual(icons.requestedNames.count, 2)
        XCTAssertEqual(icons.requestedNames[0], "AppIconSky")
        XCTAssertNil(icons.requestedNames[1])
        XCTAssertEqual(preferencesStore.load().appAccentPalette, .mint)
    }

    func testUnavailableIconChangerReportsHonestStatus() {
        let icons = UnavailableAlternateAppIconChanger()
        var result: Result<AppIconChangeOutcome, Error>?
        icons.setAlternateIconName("AppIconSky") { result = $0 }
        XCTAssertFalse(icons.supportsAlternateIcons)
        XCTAssertEqual(try? result?.get(), .unavailable)
    }
}
