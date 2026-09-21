import Foundation

/// Student-facing language lives here so tone can be reviewed without hunting through views.
/// Keep it plain, warm, specific to study life, and free of judgment.
enum Copy {
    enum Home {
        static let morningGreeting = "Good morning."
        static let readyGreeting = "Ready when you are."
        static func roomDetail(_ sceneName: String) -> String {
            "\(sceneName) is here for homework, revision, or one clear thing."
        }
        static let addHomework = "Add homework or something to study"
        static let chooseTask = "Choose what to work on"
        static let optionalTask = "A task is optional. Adding one can make the session feel clear."
        static let taskReady = "Ready for this study session"
        static let yourThings = "Your things"
        static let yourThingsHint = "Place things you've earned in this room."
        static func startFocus(_ duration: String) -> String { "Start focus · \(duration)" }
    }

    enum Focus {
        static let untitledTask = "One clear thing"
        static let plan = "Study plan"
        static let endEarlyTitle = "End this session early?"
        static let endEarlyAction = "End early"
        static let keepGoing = "Keep going"
        static let endEarlyMessage = "It won't count toward your study history or room unlocks."
        static let addFiveHint = "Adds five minutes to this study session."
    }

    enum BreakShelf {
        static let eyebrow = "Break"
        static let title = "Pick a small thing."
        static let detail = "Choose something finite between classes, after homework, or before bed."
        static let wholeShelf = "That's the whole shelf. Every activity has an ending."
        static let recent = "Recently opened"
        static let all = "All"
        static let pickedForYou = "Picked for you"
        static let allActivities = "Everything else"
    }

    enum Completion {
        static let title = "Nice work."
        static func focused(_ amount: String) -> String { "You gave \(amount) to your studying." }
        static let next = "What would feel good next?"
        static let browseShelf = "Browse shelf"
        static let backToRoom = "Back to room"
        static let firstUsual = "One finished study session is a good place to begin."
        static func usual(_ amount: String) -> String { "Your usual study session is about \(amount)." }
        static func todayCompared(today: String, usual: String) -> String {
            "You've focused \(today) today, compared with your usual \(usual) focus day."
        }
        static let newRoomThing = "Something new for your room"
        static let placeNewThing = "Choose where it goes"
    }

    enum Collection {
        static let title = "Your things"
        static let detail = "Everything here is earned from your own focus and break activity. Nothing is sold, and an earned thing stays yours."
        static let placed = "Placed"
        static let place = "Place"
        static let remove = "Remove"
        static let locked = "Locked"
        static let emptySlot = "Empty"
        static func slot(_ name: String) -> String { "\(name) slot" }
        static func placedNotice(_ object: String, _ slot: String) -> String { "\(object) is now in the \(slot.lowercased())." }
        static func removedNotice(_ slot: String) -> String { "The \(slot.lowercased()) is clear." }
    }

    enum Notices {
        static let persistenceFailure = "Couldn't save that change. Your focus session is still running."
        static let fallbackPreset = "That preset isn't on this phone, so your usual study session started."
        static let alreadyRunning = "A focus session is already running."
        static let shortSession = "Sessions under 5 minutes aren't added to your study history. That's okay."
        static let doodleSaveFailed = "Couldn't save the doodle."
        static let calendarDenied = "Calendar access is off. You can turn it on in Settings."
        static let notificationDenied = "Notifications are off, so your before-school reminder can't appear. You can turn them on in Settings."
        static let blockingEnded = "Blocking is off for this session. The timer is still running."
        static func importedBook(_ title: String) -> String { "\(title) is on your reading shelf." }
        static let bookTooLarge = "That book is too large to import."
        static let bookUnreadable = "Still couldn't read that file. Try a DRM-free EPUB."
    }

    enum Notifications {
        static let categoryIdentifier = "still.phase-end"
        static let morningIdentifierPrefix = "still.morning."
        static let morningTitle = "Ready for the school day?"
        static let morningBody = "Choose one homework or study task. Your focus setup is ready."

        static func phaseContent(for boundary: PhaseBoundary) -> (title: String, body: String) {
            switch (boundary.endingKind, boundary.nextKind, boundary.requiresUserToContinue) {
            case (_, nil, _):
                return ("Study session complete", "Choose a short break, or head back when you're ready.")
            case (.focus, _, false):
                return ("Focus block done", "Your break has started. Step away for a few minutes.")
            case (.focus, _, true):
                return ("Focus block done", "Your break is ready when you are.")
            case (_, _, false):
                return ("Back to studying", "Your next focus block has started.")
            case (_, _, true):
                return ("Break's over", "Come back when you're ready for the next study block.")
            }
        }
    }
}

/// Compatibility names keep notification services small while all wording remains centralized.
enum NotificationCopy {
    static let categoryIdentifier = Copy.Notifications.categoryIdentifier
    static func content(for boundary: PhaseBoundary) -> (title: String, body: String) {
        Copy.Notifications.phaseContent(for: boundary)
    }
    static func identifier(sessionID: UUID, phaseIndex: Int) -> String {
        "still.session.\(sessionID.uuidString).phase.\(phaseIndex)"
    }
}

enum MorningStartCopy {
    static let title = Copy.Notifications.morningTitle
    static let body = Copy.Notifications.morningBody
    static let identifierPrefix = Copy.Notifications.morningIdentifierPrefix
}
