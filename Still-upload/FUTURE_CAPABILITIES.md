# Future capabilities

How V1.1, V2, and V3 plug into what exists today. Every item lists what V1
already provides, the missing platform or entitlement work, recommended model
and service changes, navigation impact, privacy considerations, and the next
safe step. Nothing below is exposed in the V1 UI.

Quick map of the extension points:

| Boundary | File |
|---|---|
| Feature flags | `Domain/Navigation/AppRoute.swift` → `FeatureFlags` |
| Routes and tabs | `AppRoute`, `AppTab.visibleTabs`, `RouteResolver` |
| Service protocols | `Services/**` (`FocusBlockingService`, `NFCFocusPresetRouting`, `LiveActivityUpdating`, `EventTracking`, `ReadingContentProviding`, `PuzzleProviding`) |
| Future-only protocols | `Services/Future/FutureBoundaries.swift` |
| Persistence | `RecordStore` + repositories in `Data/` |
| Dependency wiring | `App/DependencyContainer.swift`, `DependencyContainer+Live.swift` |

---

## V1.1

### Full EPUB reader

- **In V1:** `ReadingItem` with `format` (`.shortText` / `.epub`), license
  metadata, `ReadingContentProviding`, the `breakActivity(.shortRead, …)` route.
- **Missing:** an EPUB parser (Apple frameworks only: unzip with
  `Compression`/`FileManager`, parse OPF/XHTML with `XMLParser`, render with
  `AttributedString` or a `WKWebView`). No third-party packages.
- **Model/service changes:** add `EPUBReadingProvider: ReadingContentProviding`;
  add `ReadingProgress` (itemID, chapter, offset) stored via `RecordStore`
  (new `RecordKind.readingProgress`).
- **Navigation:** Short Read list gains longer items that push a reader view
  inside the same activity container. Keep a visible end per sitting (chapter
  end = activity end).
- **Privacy:** reading progress stays local; never send titles to analytics
  (activity ID only).
- **Next safe step:** write the provider against one bundled public-domain EPUB
  whose status is verified per `ASSET_AND_CONTENT_POLICY.md`.

### Pixel doodle pad + gallery

- **In V1:** activity modules are keyed by `BreakActivityID`; the catalog has an
  `implementationState` so planned activities never show; `ActivityNote` shows
  the saved-artifact pattern.
- **Missing:** a drawing canvas (`Canvas` + gesture, 16×16 grid).
- **Model/service changes:** add `ActivityArtifact` (id, activityID, createdAt,
  kind `.doodle`, `pixels: [UInt8]` palette indices) as a new record kind rather
  than overloading `ActivityNote`. Add `ArtifactRepository`.
- **Navigation:** new `.doodle` case in the activity switch in
  `ActivityContainerView`; gallery as a pushed route from Me.
- **Privacy:** local only; exclude from any future export unless the user opts in.
- **Next safe step:** add the catalog entry as `.planned`, build the canvas in a
  preview, then flip to `.available`.

### One-line journal

- **In V1:** `JournalEntry` (day, text, mood), `JournalRepository` with a
  tested stored implementation, `AppRoute.journal`, `AppTab.journal`, and
  `FeatureFlags.journalTab` (off). `RouteResolver` already falls back to Me when
  the flag is off. `StreakCalculator` works on any set of days.
- **Missing:** the Journal screen only.
- **Model/service changes:** add `JournalController` (create/edit today's entry,
  list recent) mirroring `TaskController`.
- **Navigation:** set `FeatureFlags.journalTab = true` and add `JournalView` in
  `MainTabView.tabContent(.journal)`. No other navigation change.
- **Privacy:** journal text is never tracked. Add `journal_entry_saved` with no
  properties if the funnel needs it.
- **Next safe step:** build `JournalView` behind the flag with previews; flip the
  flag when it's complete (no hollow placeholder).

### Plant growth stages

- **In V1:** `PlantGrowthStage`, `ProgressionEvaluator.plantStage(...)`, and
  `CalmPlantRenderer(plantStage:)`; the calm artwork already draws `.sprout`,
  `.leafy`, `.full`. `FeatureFlags.plantGrowthStages` is off, so V1 passes `.full`.
- **Missing:** pass the evaluated stage from `AppState` into `PixelSceneView`.
- **Rules:** growth only moves forward; nothing wilts, no pet or pressure loop.
- **Next safe step:** turn the flag on in a debug build and review each stage.

---

## V2

### App/category blocking with emergency override

- **In V1:** `FocusBlockingService` protocol, `MockFocusBlockingService`
  (labeled SIMULATION ONLY; `isShielding` is always false), `BlockerIntent` on
  every `FocusPreset`, `BlockingCopy` for honest UI text, and
  `FamilyControlsBlockingService` scaffold behind
  `#if canImport(FamilyControls) && os(iOS)` with TODOs.
- **Missing platform work:**
  1. Request the **Family Controls (Distribution)** entitlement from Apple
     (`com.apple.developer.family-controls`). Development builds can use the
     development entitlement; App Store needs Apple's approval.
  2. Add a **DeviceActivity monitor extension** so shields lift when a session
     ends even if the app is killed.
  3. Authorization via `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
- **Model changes:** per-preset `FamilyActivitySelection` (Codable) stored in
  a new record kind. Design this only after entitlement review; the selection
  tokens are opaque and device-specific.
- **Service changes:** complete `FamilyControlsBlockingService` (apply
  `ManagedSettingsStore(named:)` shields in `sessionDidStart`, clear in
  `sessionDidEnd`); swap it into `DependencyContainer.live()` when
  `flags.appBlocking` is on.
- **Emergency override:** a clearly labeled "End blocking now" that ends
  shielding and records a local `blocking_override` event (no app names).
- **Navigation:** a Blocking setup screen pushed from Me and from Session
  options. Setup is a calm ritual, never punishment.
- **Privacy:** Screen Time data never leaves the device; tokens are not logged.
- **Next safe step:** apply for the entitlement now (the wait is the long pole).

### NFC tap-to-block and multiple NFC presets

- **In V1:** `FocusPreset` (timer, scene, mix, task behavior, blocker intent),
  `still://start-focus?preset=<id>` parsing (`DeepLinkParser`),
  `DeepLinkPresetRouter`, the Focus Card screen with an in-app simulator, and
  `CoreNFCTagReader` scaffold (compiled only with `-DSTILL_CORENFC`).
- **How real tags work:** an iPhone does not react to a blank tag. Write an
  **NDEF URI record** with the preset link. iOS reads URL records in the
  background and shows a banner that opens Still. A Universal Link
  (`https://<your-domain>/start-focus?preset=study`) opens the app directly once
  an associated domain is configured: add the Associated Domains capability,
  host `apple-app-site-association`, and add the host to
  `DeepLinkParser.universalLinkHosts`. Test on hardware; background reading
  requires iPhone XS or later and the screen on.
- **Missing:** preset editor UI (create/rename/delete), tag writing in-app
  (Near Field Communication Tag Reading capability +
  `NFCReaderUsageDescription`), Deep Work and Quick Focus presets.
- **Next safe step:** ship custom presets (IDs as UUID strings, analytics
  reports them as `custom`), then tag writing.

### AlarmKit wake-up to tasks and a first session

- **In V1:** `WakeUpPlan` and `WakeUpScheduling` in `FutureBoundaries.swift`;
  `TimerConfiguration.routineID` reserved.
- **Missing:** verify the current AlarmKit API (iOS 26+) and any entitlement
  before implementing. The system owns the stop button, so "can't dismiss until
  you do X" is not enforceable. Design the morning around pull: the alarm opens
  Still to today's tasks and a queued session.
- **Navigation:** a routine editor under Me; the alarm deep-links to Focus.
- **Next safe step:** a spike app confirming AlarmKit behavior on device.

### Habit tracking

- **In V1:** `HabitDefinition` and `HabitRepository` are reserved separately on
  purpose. Do not overload `TaskItem`.
- **Next safe step:** `StoredHabitRepository` over `RecordStore` with tests,
  then a small Me section. Reuse `StreakCalculator` with the same non-shaming copy.

---

## V3

### Voice task capture

- **In V1:** `TaskItem.captureSource` (`.voice` reserved), `TaskCaptureService`
  protocol, `CapturedTaskDraft`.
- **Missing:** Speech framework + microphone permissions
  (`NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`); prefer
  on-device recognition. Parsing dates can start with `NSDataDetector`.
- **Privacy:** audio and transcripts stay on device; never tracked.
- **Next safe step:** a capture sheet that fills the existing task text field.

### Google Calendar sync

- **In V1:** `CalendarAdapter` and `ExternalCalendarEvent`;
  `TaskItem.calendarEventID`, `scheduledAt`.
- **Missing:** EventKit adapter first (no backend needed). Google requires OAuth
  and a privacy review; V1 has no backend by design.
- **Next safe step:** read-only EventKit adapter behind a flag.

### Homework tracking and timeline/day view

- **In V1:** `TaskItem.homework`, `dueAt`, `scheduledAt` (all nil today).
- **Missing:** a schedule route (`AppRoute` case) and a day view. Keep V1 task
  capture as fast as it is now; scheduling stays optional.

### Home-screen widget grid

- **In V1:** `FocusSummarySnapshot` and `FocusSummaryProviding`.
- **Missing:** a WidgetKit extension plus an App Group so the widget can read a
  summary the app writes. Widgets deep-link with `still://start-focus`.

### Branded physical NFC card

- **In V1:** the preset URL scheme and Focus Card guide. Cards should carry a
  Universal Link, not a custom-scheme URL, once a domain exists.

### Cosmetics, seasonal scenes, IAP

- **In V1:** `SceneDefinition.entitlementKey` (nil) and scenes-as-data.
- **Missing:** StoreKit 2 design. Do not add locked paid content until then;
  keep progression unlocks free and non-punitive.

---

## Analytics destination (any release)

- **In V1:** `EventTracking` with a bounded local log, typed `AppEventName`,
  properties that can only come from typed values (`EventProperties`), a token
  sanitizer (`SafeToken`), anonymized preset/activity IDs, and duration buckets.
  `EventDestination` exists; none is registered.
- **Next safe step:** an opt-in, user-reviewable export (e.g. aggregate weekly
  counts), added as an `EventDestination`. Update the privacy copy in Me first.

## Explicitly cut

Android, a launcher/dumbphone mode, animal companions, chess vs Stockfish, a
multi-source book library, weather, news, and licensed modern books. Do not add
placeholder UI for any of them.
