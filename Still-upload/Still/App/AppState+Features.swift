import Foundation

// Actions for the features added after V1: journal, habits, presets, task
// details and the day timeline, doodles, books, Morning Start, widgets, and
// blocking. Same pattern as AppState: forward to a controller, then reload.

// MARK: - Calm plant

extension AppState {
    /// The calm-mode plant grows with completed sessions and never wilts.
    var plantStage: PlantGrowthStage {
        ProgressionEvaluator().plantStage(completedSessions: completedSessionCount,
                                          growthEnabled: container.flags.plantGrowthStages)
    }

    /// Sessions until the plant's next stage, for a quiet hint.
    var sessionsToNextPlantStage: Int? {
        guard container.flags.plantGrowthStages else { return nil }
        switch plantStage {
        case .sprout: return max(0, 3 - completedSessionCount)
        case .leafy: return max(0, 10 - completedSessionCount)
        case .full: return nil
        }
    }
}

// MARK: - Journal

extension AppState {
    func saveJournal(text: String, mood: JournalMood?) {
        container.journalController.saveToday(text: text, mood: mood)
        reload()
    }

    func deleteJournalEntry(_ id: UUID) {
        container.journalController.delete(id: id)
        reload()
    }

    var journalRun: Int { container.journalController.currentRun() }
}

// MARK: - Habits

extension AppState {
    var canAddHabit: Bool { container.habitController.canAddHabit }

    func habits(on day: Date) -> [HabitDay] {
        container.habitController.days(on: day)
    }

    func toggleHabit(_ id: UUID, on day: Date) {
        let done = container.habitController.isDone(habitID: id, on: day)
        container.habitController.setDone(habitID: id, on: day, !done)
        reload()
    }

    @discardableResult
    func addHabit(title: String) -> Bool {
        let created = container.habitController.create(title: title) != nil
        reload()
        return created
    }

    func toggleHabit(_ id: UUID) {
        container.habitController.toggleToday(habitID: id)
        reload()
    }

    func renameHabit(_ id: UUID, to title: String) {
        container.habitController.rename(id: id, to: title)
        reload()
    }

    func archiveHabit(_ id: UUID) {
        container.habitController.archive(id: id)
        reload()
    }
}

// MARK: - Presets

extension AppState {
    var canCreatePreset: Bool { container.preferences.canCreatePreset }

    @discardableResult
    func createPreset(named name: String, basedOn base: FocusPreset) -> FocusPreset? {
        let preset = container.preferences.createPreset(named: name, basedOn: base)
        reload()
        return preset
    }

    func renamePreset(_ id: FocusPresetID, to name: String) {
        container.preferences.renamePreset(id, to: name)
        reload()
    }

    func deletePreset(_ id: FocusPresetID) {
        container.preferences.deletePreset(id)
        reload()
    }
}

// MARK: - Tasks, due dates, and the day timeline

extension AppState {
    func updateTaskDetails(_ id: UUID, dueAt: Date?, scheduledAt: Date?, course: String?) {
        container.taskController.updateDetails(id: id, dueAt: dueAt, scheduledAt: scheduledAt, course: course)
        reload()
    }

    func updateTaskDetails(
        _ id: UUID,
        dueAt: Date?,
        scheduledAt: Date?,
        subject: Subject?,
        plannedDuration: TimeInterval?,
        dayPeriod: TaskDayPeriod,
        repeatRule: TaskRepeatRule
    ) {
        container.taskController.updateDetails(
            id: id, dueAt: dueAt, scheduledAt: scheduledAt, subject: subject,
            plannedDuration: plannedDuration, dayPeriod: dayPeriod, repeatRule: repeatRule
        )
        reload()
    }

    func setTaskCompleted(_ id: UUID, on day: Date, _ completed: Bool) {
        container.taskController.setCompleted(id: id, on: day, completed)
        if completed, preferences.selectedTaskID == id,
           container.tasks.task(id: id)?.repeatRule.isRepeating != true {
            container.preferences.update { $0.selectedTaskID = nil }
        }
        reload()
    }

    @discardableResult
    func addTaskStep(taskID: UUID, title: String) -> Bool {
        let added = container.taskController.addStep(taskID: taskID, title: title)
        reload()
        return added
    }

    func toggleTaskStep(taskID: UUID, stepID: UUID) {
        container.taskController.toggleStep(taskID: taskID, stepID: stepID)
        reload()
    }

    func deleteTaskStep(taskID: UUID, stepID: UUID) {
        container.taskController.deleteStep(taskID: taskID, stepID: stepID)
        reload()
    }

    @discardableResult
    func createTask(from draft: CapturedTaskDraft, source: TaskCaptureSource) -> TaskItem? {
        let task = container.taskController.create(from: draft, source: source)
        if let task {
            container.preferences.update { $0.selectedTaskID = task.id }
        }
        reload()
        return task
    }

    var upcomingTasks: [TaskItem] { container.taskController.upcomingTasks() }

    func dueLine(for task: TaskItem) -> String? {
        guard let due = task.dueAt, !task.isCompleted else { return nil }
        return DueDateDescriber(calendar: container.calendar).describe(due, now: container.clock.now)
    }

    func timeText(_ date: Date) -> String {
        DueDateDescriber(calendar: container.calendar).shortTime(date)
    }

    var showsCalendarEvents: Bool {
        container.flags.calendarEvents && preferences.showsCalendarEvents && calendarAccess == .granted
    }

    var showsGoogleCalendarEvents: Bool {
        container.flags.googleCalendarPreview
            && preferences.showsGoogleCalendarEvents
            && container.googleCalendar.access == .granted
    }

    /// Today's (or another day's) tasks, finished sessions, and calendar events.
    func timeline(for day: Date) -> DayTimeline {
        let calendar = container.calendar
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        var events = showsCalendarEvents ? container.calendarAdapter.events(from: start, to: end) : []
        if showsGoogleCalendarEvents {
            events.append(contentsOf: container.googleCalendar.events(from: start, to: end))
        }
        return DayTimelineBuilder(calendar: calendar).items(
            for: day,
            tasks: container.tasks.allTasks(),
            sessions: sessions,
            events: events
        )
    }

    /// Asks for calendar access from the timeline, never at launch.
    func connectCalendar() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let access = await self.container.calendarAdapter.requestAccess()
            self.container.preferences.update { $0.showsCalendarEvents = access == .granted }
            if access == .denied {
                self.notice = StillNotice(text: Copy.Notices.calendarDenied)
            }
            self.reload()
        }
    }

    func setShowsCalendarEvents(_ shows: Bool) {
        if shows && calendarAccess != .granted {
            connectCalendar()
            return
        }
        container.preferences.update { $0.showsCalendarEvents = shows }
        reload()
    }

    /// DEBUG/CI-demo only: grants access to local sample events. No Google
    /// account, token, or network request is involved.
    func connectGoogleCalendar() {
        guard container.flags.googleCalendarPreview, container.googleCalendar.isStandIn else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let access = await self.container.googleCalendar.requestAccess()
            self.container.preferences.update { $0.showsGoogleCalendarEvents = access == .granted }
            self.notice = StillNotice(text: access == .granted
                ? "Sample Google events are showing. No account was connected."
                : "The Google Calendar preview is unavailable.")
            self.reload()
        }
    }

    func setShowsGoogleCalendarEvents(_ shows: Bool) {
        guard container.flags.googleCalendarPreview else { return }
        if shows && container.googleCalendar.access != .granted {
            connectGoogleCalendar()
            return
        }
        container.preferences.update { $0.showsGoogleCalendarEvents = shows }
        reload()
    }
}

// MARK: - Voice capture

extension AppState {
    var canCaptureByVoice: Bool {
        container.speech?.isAvailable == true
    }

    /// Turns a transcript into a draft; the user confirms before it's saved.
    func draftTask(fromTranscript transcript: String) -> CapturedTaskDraft? {
        SpokenTaskParser(calendar: container.calendar).draft(from: transcript, now: container.clock.now)
    }
}

// MARK: - Doodles

extension AppState {
    /// Autosaves a doodle. A blank canvas removes any saved version.
    func autosaveDoodle(_ doodle: PixelDoodle, existingID: UUID?) -> UUID? {
        let now = container.clock.now
        if doodle.isBlank {
            if let existingID { try? container.artifacts.delete(id: existingID) }
            reload()
            return nil
        }
        let existing = existingID.flatMap { container.artifacts.artifact(id: $0) }
        let artifact = ActivityArtifact(
            id: existing?.id ?? UUID(),
            activityID: .pixelDoodle,
            kind: .doodle,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            doodle: doodle
        )
        do {
            try container.artifacts.save(artifact)
            if existing == nil {
                container.events.track(.doodleSaved, EventProperties())
            }
        } catch {
            notice = StillNotice(text: Copy.Notices.doodleSaveFailed)
        }
        reload()
        return artifact.id
    }

    func deleteDoodle(_ id: UUID) {
        try? container.artifacts.delete(id: id)
        reload()
    }
}

// MARK: - Books

extension AppState {
    func nextSitting(bookID: String) -> BookSitting? {
        container.books.nextSitting(bookID: bookID)
    }

    func readingProgress(bookID: String) -> ReadingProgress {
        container.books.progress(for: bookID)
    }

    func finishSitting(bookID: String, index: Int) {
        container.books.finishSitting(bookID: bookID, index: index)
        reload()
    }

    func restartBook(_ bookID: String) {
        container.books.restart(bookID: bookID)
        reload()
    }

    func importBook(from url: URL) {
        #if canImport(Darwin)
        // Files picked from the Files app are security-scoped.
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        #endif
        do {
            let summary = try container.books.importBook(from: url)
            container.events.track(.bookImported, EventProperties())
            notice = StillNotice(text: Copy.Notices.importedBook(summary.title))
        } catch BookLibraryError.tooLarge {
            notice = StillNotice(text: Copy.Notices.bookTooLarge)
        } catch {
            notice = StillNotice(text: Copy.Notices.bookUnreadable)
        }
        reload()
    }

    func removeBook(_ id: String) {
        container.books.removeBook(id: id)
        reload()
    }
}

// MARK: - Morning Start

extension AppState {
    func setMorningStart(_ plan: MorningStartPlan) {
        let validated = plan.validated()
        container.preferences.update { $0.morningStart = validated }
        if validated.isEnabled && !validated.weekdays.isEmpty {
            Task { @MainActor [weak self] in
                guard let self else { return }
                var allowed = await self.container.focus.requestNotificationPermissionIfNeeded()
                if !allowed {
                    // Permission may have been turned on in Settings since.
                    allowed = await self.container.notifications.authorizationStatus() == .granted
                }
                if allowed {
                    self.container.morningStart.scheduleMorningStart(validated)
                    self.container.events.track(.morningStartScheduled, EventProperties().count(validated.weekdays.count))
                } else {
                    self.notice = StillNotice(text: Copy.Notices.notificationDenied)
                }
                self.reload()
            }
        } else {
            container.morningStart.cancelMorningStart()
        }
        reload()
    }

    func setWakeUp(_ plan: WakeUpPlan) {
        guard container.flags.wakeUpPreview else {
            setMorningStart(plan.schedule)
            return
        }
        let validated = plan.validated()
        container.preferences.update {
            $0.morningStart = validated.schedule
            $0.wakeUpStopMethod = validated.stopWith
        }
        if validated.schedule.isEnabled && !validated.schedule.weekdays.isEmpty {
            Task { @MainActor [weak self] in
                guard let self else { return }
                var allowed = await self.container.focus.requestNotificationPermissionIfNeeded()
                if !allowed {
                    allowed = await self.container.notifications.authorizationStatus() == .granted
                }
                if allowed {
                    self.container.wakeUp.schedule(validated)
                    self.container.events.track(.morningStartScheduled, EventProperties().count(validated.schedule.weekdays.count))
                } else {
                    self.notice = StillNotice(text: "Notifications are off, so the iOS 17 Wake up fallback can't appear. You can turn them on in Settings.")
                }
                self.reload()
            }
        } else {
            container.wakeUp.cancel()
        }
        reload()
    }

    func simulateWakeUpOpening() {
        guard container.flags.wakeUpPreview, container.wakeUp.simulateOpening() else { return }
        notice = StillNotice(text: container.wakeUp.isWaitingForFocusCard
            ? "Preview: Still opened. The queued session is waiting for a simulated card tap."
            : "Preview: Still opened with the queued session ready.")
        reload()
    }

    func simulateWakeUpCardTap() {
        guard container.flags.wakeUpPreview, container.wakeUp.simulateFocusCardTap() else { return }
        notice = StillNotice(text: "Preview card accepted. The queued session is ready; no system alarm was controlled.")
        reload()
    }
}

// MARK: - Widgets

extension AppState {
    func publishWidgetSnapshot() {
        let snapshot = WidgetSnapshotBuilder.snapshot(
            stats: stats,
            preset: currentPreset,
            nextTask: selectedTask,
            now: container.clock.now,
            calendar: container.calendar
        )
        container.widgetSnapshots.write(snapshot)
    }
}

// MARK: - Blocking

extension AppState {
    var blockingCapability: BlockingCapability { container.blocking.capability }
    var isShieldingApps: Bool { container.blocking.isShielding }

    func setBlockingSchedule(isEnabled: Bool, startMinute: Int, presetID: FocusPresetID) {
        guard container.flags.appBlocking else { return }
        container.blockingSchedule.update(
            isEnabled: isEnabled,
            startMinute: startMinute,
            presetID: presetID
        )
        reload()
    }

    /// The emergency override: lifts shields now; the session keeps running.
    func endBlockingNow() {
        if container.blockingSchedule.endNow() == .none {
            container.blocking.endShieldingNow()
        }
        container.events.track(.blockingOverride, EventProperties())
        notice = StillNotice(text: Copy.Notices.blockingEnded)
        reload()
    }
}
