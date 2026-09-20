# Future capabilities

Where each roadmap item stands, what's left, and the next safe step. Items are
grouped by what blocks them: nothing (shipped), Apple approval or hardware
(built and gated), or decisions and outside setup (remaining).

Quick map of the extension points:

| Boundary | File |
|---|---|
| Feature flags | `Domain/Navigation/AppRoute.swift` → `FeatureFlags.current` |
| Routes and tabs | `AppRoute`, `AppTab.visibleTabs`, `RouteResolver` |
| Service protocols | `Services/**` (`FocusBlockingService`, `NFCFocusPresetRouting`, `LiveActivityUpdating`, `EventTracking`, `CalendarAdapter`, `SpeechTaskCapturing`, `MorningStartScheduling`, `WidgetSnapshotWriting`, `BookLibrary`) |
| Hardware/approval boundaries | `Services/Future/FutureBoundaries.swift` |
| Persistence | `RecordStore` + repositories in `Data/` |
| Dependency wiring | `App/DependencyContainer.swift`, `DependencyContainer+Live.swift` |

---

## Shipped (on in `FeatureFlags.current`)

| Item | Where | Notes |
|---|---|---|
| One-line journal | `Features/Journal/`, `JournalController` | One entry per day; saving again replaces it. Optional mood. Text never reaches analytics (tested). |
| Habit tracking | `HabitController`, `StoredHabitRepository`, Journal tab | Up to five habits. Check-ins are per day; missing days are never shown as failures. Kept separate from `TaskItem`. |
| Plant growth stages | `ProgressionEvaluator.plantStage`, `CalmPlantArtwork` | Sprout (<3 sessions), leafy (<10), full. Only grows. |
| Custom presets | `PresetsView`, `PreferencesController.createPreset/rename/delete` | Deep Work and Quick Focus built in; up to 10 total. Custom IDs are `custom-xxxxxxxx`; analytics reports them as `custom`. Deleting the default falls back to Default. |
| Homework, due dates, day view | `TaskDetailView`, `DayTimelineView`, `DueDateDescriber`, `DayTimelineBuilder` | Capture stays one line; details are optional. |
| Apple Calendar (read-only) | `EventKitCalendarAdapter` | Asked from the timeline, never at launch. All-day events are skipped. |
| Voice task capture | `SpeechRecognizerCapture`, `SpokenTaskParser`, `VoiceCaptureView` | On-device when available. Understands "…today/tomorrow/by Friday". Nothing is saved until the person taps Add. |
| Pixel doodle + gallery | `PixelDoodleActivityView`, `DoodleGalleryView`, `ActivityArtifact` | 16×16, 8-color palette, pen/fill/eraser, autosaves. |
| EPUB reader | `Services/Reading/` (Inflate, ZipArchive, EPUBParser, FileBookLibrary), Short Read | Pure Swift, no third-party code. Chapters split into ~700-word sittings; a sitting is one activity. Import from Files; no books bundled. |
| Morning Start | `MorningStartView`, `UserNotificationScheduler.scheduleMorningStart` | Repeating local notification. Phase reminders and Morning Start use separate identifiers so one never clears the other. |
| Home-screen widget | `StillWidgets/StillFocusSummaryWidget.swift`, `Shared/WidgetSnapshot.swift` | Small, medium, and Lock Screen sizes. Tap starts the default preset. Needs the App Group (paid account) to show real numbers. |
| Live Activity / Dynamic Island | `StillWidgets/StillLiveActivityWidget.swift` | Now part of the project. No task titles on the Lock Screen. |

---

## Built, waiting on Apple or hardware

### App/category blocking with emergency override

- **Done:** `FamilyControlsBlockingService` (authorization, per-preset
  `FamilyActivitySelection` stored via `BlockingSelectionStore`,
  `ManagedSettingsStore` shields on session start, cleared on end),
  `BlockingSetupView` with `FamilyActivityPicker`, a Blocking section in Session
  options, and "End blocking now" on the running session (logs
  `blocking_override`, no app names). All behind `FeatureFlags.appBlocking`.
- **Needed:**
  1. Request the **Family Controls (Distribution)** entitlement from Apple.
     Development builds can use the development entitlement with a paid account.
  2. Add `com.apple.developer.family-controls` to `Still/Still.entitlements`
     and set `appBlocking: true` in `FeatureFlags.current`.
  3. Add a **DeviceActivity monitor extension** (`StillShieldMonitor`) so
     shields lift when a session's end time passes even if Still was closed:
     when a session starts, `DeviceActivityCenter().startMonitoring(.init("still.session"), during: DeviceActivitySchedule(intervalStart:intervalEnd:repeats: false))`
     with the session's end; in the extension's `intervalDidEnd`, call
     `ManagedSettingsStore(named: .init("still.focus")).clearAllSettings()`.
     The extension needs the same entitlement.
- **Privacy:** selections are opaque tokens that stay on the device.
- **Next safe step:** apply for the entitlement now; the wait is the long pole.

### NFC tag writing in the app

- **Done:** `CoreNFCTagWriter` (checks the tag is writable and big enough,
  writes an NDEF URI record) and a "Write to a tag" button on the Focus Card
  screen, both compiled only with `-DSTILL_CORENFC`.
- **Needed:** a paid account, the NFC Tag Reading capability
  (`com.apple.developer.nfc.readersession.formats = [NDEF]`), the Swift flag,
  and a physical iPhone. `NFCReaderUsageDescription` is already in Info.plist.
- **Next safe step:** write one tag with any NFC app first; that already works
  through the URL scheme.

### Voice capture on hardware

Works in code and is on, but should be checked on a real iPhone (simulator
microphone input is unreliable).

---

## Remaining

### AlarmKit wake-up (a real alarm)

- **Today:** Morning Start is a notification, so it follows silent mode.
- **Needed:** AlarmKit (iOS 26+) and its usage description. The system owns
  the stop button, so "can't dismiss until you do X" isn't possible; the alarm
  should open Still to today's tasks and a queued session. Adopt
  `WakeUpScheduling` with an AlarmKit implementation, gated by
  `#available(iOS 26, *)`, and keep the notification version for iOS 17–25.
- **Next safe step:** a small spike app confirming AlarmKit behavior on device.

### Google Calendar

EventKit covers calendars synced to the iPhone (including Google accounts added
in Settings). A direct Google integration needs OAuth, a privacy policy, and
Google's review; V1 has no backend by design.

### Universal Links and a branded NFC card

Cards should carry `https://<your-domain>/start-focus?preset=…` rather than
`still://`. Needs a domain, an `apple-app-site-association` file, the
Associated Domains capability, and the host added to
`DeepLinkParser.universalLinkHosts`. Card design and printing are separate.

### Bundled public-domain books

The reader is ready; the shelf starts empty. Add verified public-domain EPUBs
to `Still/Resources/` (each with its source and status recorded per
`ASSET_AND_CONTENT_POLICY.md`) and they appear as "Public domain".

### Cosmetics, seasonal scenes, IAP

`SceneDefinition.entitlementKey` exists (nil). Needs StoreKit 2 design and
products in App Store Connect. Keep session-earned unlocks free and
non-punitive; don't add locked paid content before then.

---

## Analytics destination (any release)

- **In place:** `EventTracking` with a bounded local log, typed
  `AppEventName`, properties that can only come from typed values
  (`EventProperties`), a token sanitizer (`SafeToken`), anonymized
  preset/activity IDs, and duration buckets. `EventDestination` exists; none is
  registered.
- **Next safe step:** an opt-in, user-reviewable export (e.g. aggregate weekly
  counts), added as an `EventDestination`. Update the privacy copy in Me first.

## Explicitly cut

Android, a launcher/dumbphone mode, animal companions, chess vs Stockfish, a
multi-source book library, weather, news, and licensed modern books. Do not add
placeholder UI for any of them.
