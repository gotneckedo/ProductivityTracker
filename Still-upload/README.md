# Still

A cozy focus, screen-time, and self-care app for iPhone, built around one
question: **What do I do instead?**

The loop: **Tap → Focus → Finish → choose a finite activity → Reflect → Repeat.**
The heart of the product is the session-complete moment, where a finished
focus session is followed by three appealing, finite alternatives to scrolling.

V1 is native SwiftUI, iOS 17+, Apple frameworks only, fully offline and
local-first. Data stays on the device.

---

## Quick start

Requirements: macOS with **Xcode 16 or later** (the project uses Xcode 16's
synchronized folders), iOS 17+ simulator or device.

1. Open `Still.xcodeproj`.
2. Select the **Still** scheme and an iPhone simulator.
3. Press **⌘R**.

To run on a physical iPhone, select the **Still** target → Signing &
Capabilities → choose your Team. The bundle ID is `com.cocomedia.still`;
change it if it collides with one you already use.

### Tests

- In Xcode: **⌘U** (runs `StillTests` hosted in the app).
- From Terminal, no simulator needed (runs the same test files against the
  platform-neutral core):

  ```bash
  swift test
  ```

- From Terminal, on a simulator:

  ```bash
  xcodebuild test -project Still.xcodeproj -scheme Still \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```

The suite has 120 tests covering timer math (countdown, count-up, Pomodoro,
pause/resume, backgrounding, relaunch), completion vs. abandonment, streaks,
scene unlocks, the three-suggestion engine, task/session association, deep
links, event redaction, puzzle validity and uniqueness, persistence, and the
end-to-end Focus → Break → Focus loop at the app-state level.

### See it without a Mac (GitHub Actions)

`.github/workflows/ios.yml` builds the app on a GitHub-hosted Mac, runs every
test in an iPhone simulator, and uploads screenshots of 17 screens (light and
dark) as an artifact named **still-screenshots**. It runs on every push to
`main`, or from the Actions tab → **iOS build, tests & screenshots** → Run
workflow. Public repos run free; private repos use your included minutes (macOS
minutes count 10×; one run takes roughly 10–20 minutes).

Screenshots use a Debug-only launch argument that opens a screen with sample
data (`DemoLaunch.swift`), e.g.
`xcrun simctl launch booted com.cocomedia.still -still-demo complete`.


---

## Try the primary loop

1. Launch → answer **"What would you like help with?"** → Continue. You land on
   Focus with a 25-minute session ready.
2. Tap the **Task** row → type "Biology homework" → return. It's selected.
3. **Session options** → Timer → Countdown → set Focus to **5 min** (the minimum)
   so you don't wait 25 minutes. Or pick **Count up**.
4. **Start Focus.** Allow or deny notifications; either is fine.
5. Lock the phone or background the app; come back. Time is derived from saved
   dates, so it stays accurate.
6. When the session ends you see **"5 minutes focused · Biology homework ·
   What do you want to do instead?"** with exactly three suggestions.
7. Pick one → it opens inside the Break tab → finish it (Done, solve the puzzle,
   or let the timer end) → **Return to Focus**.
8. Open **Me** to see stats, streak, break usage, and scene unlock progress.

Faster testing tips: set Countdown to 5 minutes, or use Count up and tap
Finish after 5 minutes (shorter count-up sessions are recorded as abandoned by
design). Unit tests cover long sessions with a controllable clock.

### Deep links and the Focus Card simulator

- Me → **Set up a Focus Card** → **Simulate tap** runs the same route a real
  NFC tag would.
- Simulator Terminal:

  ```bash
  xcrun simctl openurl booted "still://start-focus?preset=default"
  xcrun simctl openurl booted "still://start-focus?preset=study"
  ```

- Links wait until onboarding is finished, and never interrupt a session that
  is already running (a calm notice says so). Unknown presets fall back to
  Default.

---

## Architecture

```
Still/
  App/            StillApp, AppState (observable store), AppRouter,
                  DependencyContainer (+Live), RootView, PreviewSupport
  Domain/         Typed models: FocusSession, TimerConfiguration, TaskItem,
                  FocusPreset, BreakActivity, ActivityUsage, AmbientMix,
                  SceneDefinition, SceneUnlockRule (+ProgressionEvaluator),
                  AppEvent, UserPreferences (+Personalization), JournalEntry,
                  Navigation/ (AppRoute, RouteResolver, DeepLink, FeatureFlags),
                  Activities/ (Sudoku, Picross, Word Search, breathing, stretch,
                  reading models)
  Data/           Persistence/ (RecordStore, SwiftData store),
                  Repositories/, SeedData/ (scenes, activities, presets,
                  puzzles, readings, preview fixtures)
  Services/       Timer/, Notifications/, Audio/, Analytics/, ScreenTime/, NFC/,
                  LiveActivity/, Suggestions/, Stats/, Flow/ (controllers),
                  Future/ (V2–V3 protocols only)
  DesignSystem/   StillTheme, StillTypography, StillMotion, StillComponents,
                  PixelSceneView (+ Scenes/ artwork)
  Features/       Onboarding/, Focus/, Break/ (+ Activities/), Tasks/, Me/
  Resources/      AmbientAudio/ (4 generated loops + README)
StillTests/       Unit tests (run in Xcode and with `swift test`)
StillLiveActivity/  Optional widget extension source (not in the project)
Package.swift     StillCore package for fast, simulator-free tests
```

### Layers

1. **Domain** — plain `Codable` value types with typed fields (dates, enums,
   IDs). No formatted strings are stored; display text is derived in the UI.
2. **Engines** (pure, deterministic) — `FocusTimerEngine`,
   `BreakSuggestionEngine`, `StatsCalculator`/`StreakCalculator`,
   `ProgressionEvaluator`, `DeepLinkParser`, `RouteResolver`,
   `LiveActivityMapper`.
3. **Controllers** (`Services/Flow`) — `FocusFlowController`,
   `BreakFlowController`, `TaskController`, `PreferencesController`. They
   orchestrate repositories and services, and they're where the business rules
   live. Everything above this line is platform-neutral and unit-tested.
4. **AppState / AppRouter** (`@Observable`) — mirror controller results for
   SwiftUI and own navigation. `RouteResolver` decides tab, stack, sheet, and
   full-screen presentation for every `AppRoute`, so leaf views never make
   modal decisions.
5. **Views** — compose design-system primitives only (`StillScreen`,
   `QuietPrimaryButtonStyle`, `QuietSecondaryButtonStyle`, `SectionHeader`,
   `SessionTimerFace`, `ActivityTile`, `SubtleMetric`, `SelectionPill`,
   `EmptyState`, `SettingRow`, `PixelSceneView`, …). No magic numbers or colors
   in feature views.

### Dependency injection

`DependencyContainer` builds every repository, service, and controller.
`DependencyContainer.live()` wires SwiftData, UserNotifications, AVFoundation,
the honest blocking mock, and (optionally) ActivityKit.
`DependencyContainer.inMemory(...)` wires in-memory stores, a `ManualClock`, and
recording or no-op services for tests and previews.

### Focus environment

One visual slot, two interchangeable renderers behind
`FocusEnvironmentRendering`:

- **Calm** (`CalmPlantRenderer`) — a static pixel plant nook; the timer leads.
- **Scene** (`SceneLoopRenderer`) — original animated pixel loops drawn with
  `Canvas`: Rainy Bedroom (rain, lamp glow), Library Light (dust in a light
  shaft), Train Window (parallax hills and poles), Night City (windows slowly
  lighting).

Scenes are data (`SceneCatalog`): name, palette, renderer kind, unlock rule,
sound affinity, motion metadata, accessibility description, and a reserved
entitlement key. Unlocks: Rainy Bedroom at start, Library Light at 7, Train
Window at 15, Night City at 25 completed sessions. Animation intensity is Full
(12 fps), Gentle (6 fps), or Still; Reduce Motion always renders a still frame.

---

## Rules worth knowing

**Timer.** Time is always derived from stored dates: `phaseStartedAt`,
`phaseAccumulated`, and `pausedAt`. `FocusTimerEngine.advance` walks every phase
boundary that passed while the app was away and records exact end dates.

**Relaunch.** A running session is restored on launch. Overdue phases complete
with their true end times; a session that finished while the app was closed
goes straight to its completion screen. Paused sessions restore paused. The
pending "What instead?" screen (`pendingCompletionSessionID`) survives relaunch
until the user chooses something. There is no known limitation here.

**Completion.** Only `completed` sessions count toward stats, streaks, task
session counts, and unlocks. Ending early (behind a confirmation) records
`abandoned`. Count-up sessions complete when the user taps Finish after at
least 5 minutes (`TimerConfiguration.minimumCountUpCompletion`); shorter ones
are abandoned.

**Streaks.** A focus day is a calendar day, in the current time zone, with at
least one completed session, counted on the day the session ended. The current
streak counts back from today, or from yesterday if nothing is completed yet
today. Missing a whole day resets it to zero, with no shaming copy.

**Suggestions.** `BreakSuggestionEngine` returns exactly three: activities that
fit the break come first, activities not used today are preferred (a slightly
longer fresh activity beats a repeat), categories are mixed in the onboarding
answer's order, and the choice rotates daily. When everything has been used
today, the least recently used are offered as revisits.

**Activities.** Each has a consistent header (Back to Break, name, remaining
time, Done), a finite endpoint, and usage tracking. Text autosaves (debounced)
and puzzle progress saves after every move, so leaving never loses work. Puzzles
count as completed only when solved. Usages left open by a force-quit are closed
as abandoned at next launch.

---

## Local storage

- **SwiftData** backs a small document store (`LocalRecord`: kind, id, dates,
  schema version, JSON payload) behind the `RecordStore` protocol.
  Repositories encode domain types into records. Migrations happen in `Codable`
  decoding (new fields are optional or have defaults), and records that fail to
  decode are skipped, never fatal. If SwiftData can't open, the app falls back
  to memory and says so.
- **UserDefaults** (via `KeyValueStore`) holds preferences and presets.
  Decoding tolerates missing keys.
- **Events** are an in-memory, bounded local log. Nothing is transmitted.
  Debug builds show it at the bottom of Me.
- **Reset:** Me → Reset local data (asks first) deletes everything and returns
  to onboarding. Me → Replay onboarding keeps your data.

## Notifications

Permission is requested contextually the first time a session starts, and only
once. If granted, a local notification is scheduled for each upcoming phase end
that will happen on its own (auto-start rules are followed; scheduling stops at
a phase that waits for the user). Pausing cancels them; resuming reschedules.
If denied, nothing changes: the in-app completion path never depends on
notifications. Reminders don't show while the app is open.

## Ambient audio

`AVAmbientAudioPlayer` loops one `AVAudioPlayer` per source (rain, café,
fireplace, waves), mixed by per-source level × master volume with short fades.
The four bundled loops are original, procedurally generated placeholders (see
the ambient audio appendix in `ASSET_AND_CONTENT_POLICY.md` for file names, format tips, and
licensing rules). If files are missing, controls still work and save, and the UI
says "Ambient audio is ready when sound files are added." `UIBackgroundModes`
includes `audio`, so sound continues when the screen locks during a session.
Mute on the active screen is temporary; the preset mix is unchanged.

## Privacy and analytics

`EventTracking` records a typed, local event vocabulary for the funnel:
`onboarding_completed`, `focus_started`, `focus_paused`, `focus_resumed`,
`focus_completed`, `focus_abandoned`, `break_suggestions_presented`,
`break_activity_started`, `break_activity_completed`,
`break_activity_abandoned`, `returned_to_focus`, `nfc_preset_routed`,
`notification_permission_result`.

Properties can only be built from typed values (`EventProperties`): timer mode,
preset ID (user-made presets become `custom`), activity ID, duration bucket,
entry point, and booleans. There is no API that accepts free text, and a
sanitizer (`SafeToken`) redacts anything that isn't identifier-shaped. Task
titles, notes, Brain Dump text, and journal text cannot reach the log; tests
check this. No SDKs, no network.

---

## Hardware and entitlement caveats

| Capability | V1 status | What's needed for the real thing |
|---|---|---|
| **App shielding** (Screen Time) | `MockFocusBlockingService`: records the preset's blocker intent, never shields. UI says "Blocking setup is ready… Nothing is blocked today." | Apple's **Family Controls** entitlement (`com.apple.developer.family-controls`, Distribution approval for the App Store), user authorization, a persisted `FamilyActivitySelection`, `ManagedSettingsStore` shielding, and a DeviceActivity monitor extension. Scaffold: `FamilyControlsBlockingService.swift`. |
| **NFC tags** | URL routing (`still://start-focus?preset=…`) and an in-app simulator. | A writable tag (e.g. NTAG213) with an **NDEF URI record** containing the preset link. Blank tags do nothing. iPhone XS+ reads URL tags in the background and shows a banner to open Still; test on your device. For direct launch without the banner, use a Universal Link (Associated Domains + `apple-app-site-association`). In-app scanning/writing needs the NFC Tag Reading capability, `NFCReaderUsageDescription`, and a physical device (scaffold: `CoreNFCTagReader.swift`, compiled with `-DSTILL_CORENFC`). |
| **Live Activities / Dynamic Island** | Mapping (`LiveActivityMapper`) and `LiveActivityUpdating` boundary; app uses `NoopLiveActivityUpdater`. | Add the widget extension (below) and set `FeatureFlags.v1.liveActivities = true`. Lock Screen content deliberately omits task titles. Test on a device with Dynamic Island. |
| **Notifications** | Fully working. | Nothing. Time-sensitive delivery would need the Time Sensitive Notifications capability (not used). |

### Enabling Live Activities

1. File → New → Target → **Widget Extension**, name it `StillLiveActivity`,
   check "Include Live Activity", uncheck "Include Configuration App Intent".
2. Replace the generated Swift files with
   `StillLiveActivity/StillLiveActivityWidget.swift`.
3. Add `Still/Services/LiveActivity/LiveActivityShared.swift` to the extension
   target too (File Inspector → Target Membership).
4. Set the extension's iOS deployment target to 17.0.
5. In `Domain/Navigation/AppRoute.swift`, set `liveActivities: true` in
   `FeatureFlags.v1`. `Info.plist` already has `NSSupportsLiveActivities`.

---

## Accessibility

Every control has a VoiceOver label; the timer announces remaining or elapsed
time and paused state and is marked as frequently updating. Scenes describe
themselves. Text uses Dynamic Type text styles (the timer size scales with
`@ScaledMetric`), and screens scroll at large sizes. Reduce Motion stops scene
loops, removes entrance offsets, and switches box breathing to a static square
with text. Colors are warm paper and navy-charcoal with dark-mode variants.

## Previews

SwiftUI previews exist for: Onboarding; Focus home in Scene and Calm mode and
at an accessibility text size; Active focus (Scene and Calm); Session complete
with three suggestions; Break shelf; Sudoku unfinished; Picross finished; Short
Read; Box Breathing; Tasks; Session options; Me empty and with history; Scenes;
Focus Card. All use in-memory data via `PreviewSupport`.

---

## How this was verified

Built in a Linux environment without Xcode:

- The platform-neutral core (domain, data, services, controllers, app state,
  router) compiles with Swift 5.10 with zero warnings, and all 120 tests pass
  via `swift test`.
- Every SwiftUI file was syntax-checked with the Swift parser, then
  type-checked against a stand-in SwiftUI/UIKit interface. That catches
  mistakes in this code's own types, labels, and view builders, but not
  differences from Apple's real SDK signatures.
- The Xcode project file was parsed with the `pbxproj` library, and every
  object reference resolves.

**The first build in Xcode is the real SDK check.** If Xcode reports an error,
it will most likely be a single SwiftUI API signature; they're isolated to the
views, and the logic underneath is tested.

## Next steps

See `FUTURE_CAPABILITIES.md`. The two recommended next steps:

1. **Apply for the Family Controls entitlement now.** Approval is the long pole
   for real blocking (V2), and the protocol, mock, copy, and scaffold are ready.
2. **Put V1 on a device and measure the loop.** Check the funnel in the debug
   event log (focus completed → suggestion opened → activity completed →
   returned to focus), then replace the generated audio with recorded or
   licensed loops.

See also `ASSET_AND_CONTENT_POLICY.md` for provenance rules.
