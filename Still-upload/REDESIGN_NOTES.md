# Still redesign notes

**Branch:** `redesign`  
**Pull request:** [#1 — Redesign Still with a room-first focus flow](https://github.com/gotneckedo/ProductivityTracker/pull/1)  
**Latest verified UI head:** `8dd3f9d`
**Latest local validation:** `swift test` — **217 tests passed, 0 failures** (Swift 6.1 on Ubuntu 24.04).
**Latest GitHub Actions:** **Passed.** [iOS build, tests & screenshots — run 36242555096](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36242555096) completed successfully on `8dd3f9d`; its `still-screenshots` artifact contains and was visually reviewed across 48 simulator captures.

## Phase 2 — verified sprite-first room checkpoint

This checkpoint is limited to Phase 2’s original pixel package, sprite-first room seam, accessible object targets, and the evidence route. It does **not** claim the later Phase 2 cat behavior, full Today modes, alarm/wake flow, daily limits, or complete Still+ gating; those remain in progress.

The accepted artifact is `still-screenshots` from [run 36242555096](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36242555096) at `8dd3f9d` (**48 PNGs**). The immediately preceding room screenshot was rejected because the Bookshelf target label wrapped. Commit `8dd3f9d` makes all first-three-days labels readable on one line and is the only artifact cited below.

| Requirement | Implementation | Proving capture(s) | Review result |
|---|---|---|---|
| **Original 32-color pixel package** | `Tools/generate_still_sprites.py` deterministically creates eight original room bases, starter furniture, 20 collectible object sprites, break/empty-state/card assets, bird, and four six-frame cat coats. The asset catalog retains transparent PNG backgrounds and the policy records provenance. | `04-sprite-contact-sheet.png`, `29-sprite-contact-sheet-bottom.png` | The first capture shows the eight room bases and object package; the lower capture shows the remaining UI assets plus all four cat coats and their six-frame sets. The visible provenance statement confirms assets are generated locally from Still’s checked-in pixel geometry. |
| **Sprite-first Focus room** | `SceneDefinition.spriteAssetName`, `RoomObject.spriteAssetName`, and `SpriteFirstRoomSurface` select authored PNG rooms and object assets with pixel interpolation, retaining a code-drawn fallback for missing assets. Starter furniture is visible from the first room. | `03-focus-room.png` | Rainy Bedroom renders as a crisp pixel room with starter bed, desk, lamp, shelf, plant, window, and cat—without an empty-room reward state. |
| **Accessible first-three-days object targets** | Desk, Bookshelf, Calendar, Plant, and Window have 44pt targets, VoiceOver labels/hints, app routes, and first-three-days visual labels. `8dd3f9d` constrains the labels to a one-line readable treatment while retaining full accessibility names. | `03-focus-room.png` | All five labels are legible and uncut: **Desk**, **Bookshelf**, **Calendar**, **Plant**, and **Window**. The Bookshelf label no longer wraps into an unreadable fragment. |
| **Core room collection and seasonal seam** | The scene catalog binds the original art to Rainy Bedroom, Library Light, Train Window, Night City, and seasonal rooms; free core rooms remain distinct while seasonal Still+ cosmetics use the honest locked state. | `34-scenes-all.png`, `35-scenes-seasonal.png` | Four core room thumbnails are fully inside the two-column layout with visibly distinct window/light variants. Seasonal cards are visibly locked and described as Still+ cosmetics rather than session-earned digital access. |

**Known Phase 3 difference:** the accepted Phase 2 Focus evidence still uses the existing action card beneath the room. Phase 3 explicitly replaces that composition with a full-bleed room and floating controls; this Phase 2 proof makes no Phase 3 visual claim.

## Visual correction pass

The post-review correction pass explicitly registers the bundled Instrument Serif and Outfit files at launch, retaining the `UIAppFonts` entries as a second registration path. Captures now show Instrument Serif in display headlines, timers, and large statistics rather than a system-sans fallback. Shared glass surfaces clip their material, fill, border, and shadow to one rounded contour; Home, active focus, Journal, Me, and Short Read no longer retain an outer rectangular fill.

The original room renderer now floats over the phase background with a warm halo, lamp bloom, shadow, motes, two wall planes, and reduced-motion-aware motion. It is also the renderer used in Scene thumbnails. All major tab scroll views reserve bottom clearance for the floating tab bar. The active-focus screen now has one subject-or-Focus overline, a thin glowing progress line, one sound-state glyph, and a full-width Study Plan card.

Sudoku presents six separated 2×3 boxes and keeps a keypad number available until all six placements exist. Short Read explicitly lists and opens the four bundled public-domain books. Wake up exposes time, days, preset, and Stop with Button/Focus Card controls without a Calendar settings detour; Box Breathing shows remaining time only once. Me begins with the personal glass card, and preview Focus Card acquisition is secondary glass. Student language is updated to US wording, including **studying**, **sessions**, and **focus days**.

## Verified follow-up visual corrections

The following corrections were accepted only after review of the **final** iPhone Simulator artifact from [run 35946615524](https://github.com/gotneckedo/ProductivityTracker/actions/runs/35946615524). Earlier screenshot runs that still showed overlapping Scene cards were rejected and are not used as evidence here.

| Correction | Implementation | Proving capture(s) | Review result |
|---|---|---|---|
| **Scenes grid stays within the phone** | `SceneCollectionView` uses the required two flexible `GridItem` columns with 12-point gaps. Its vertical scroll content is constrained to the actual viewport less the screen padding, and room thumbnails have no fixed intrinsic shadow width. There is no horizontal scroller or negative padding. | `26-scenes-all.png`, `27-scenes-seasonal.png`, `28-scenes-all-bottom.png` | The four core rooms, the two seasonal columns, and the final Spring Rain row are fully inside their card boundaries; Library Light and Night City are no longer clipped or overlapping. |
| **Room geometry and lamp lighting** | `RoomArtwork` renders opaque back and side walls plus a floor. The lamp is rendered as clipped radial gradients on the floor and the back wall rather than a foreground tan oval. | `04-active.png` | The focus room visibly contains two solid wall planes and a floor; light falls from the lamp through the room and brightens the wall behind it. |
| **Fresh Sudoku keypad** | `SudokuGame.isDigitComplete(_:)` retires a digit only after six placements. The keypad backgrounds now sit behind their labels instead of overlaying them. `PuzzleTests.testSudokuDigitCompletesOnlyAfterSixPlacements` pins both the fresh and completed states. | `07-sudoku.png`, `36-sudoku-dark.png` | All digits 1–6 are at full contrast on a fresh puzzle in both captured appearances; none is prematurely faded. |

**Final screenshot artifact:** `still-screenshots` (artifact ID `10787966480`), **38 PNG files**, archive integrity checked locally before review.

## Verified pre-Phase 2 layout proof

The pre-Phase 2 layout checkpoint was accepted only after review of [iOS build, tests & screenshots — run 35997812807](https://github.com/gotneckedo/ProductivityTracker/actions/runs/35997812807) on `ce6fd8a`. The artifact `still-screenshots` (artifact ID `10807209976`) contains **45 PNG files** and was downloaded and inspected locally. The preceding run `35986265769` and intermediate replacement runs are not cited as final evidence.

| Requirement | Proving capture(s) | Verified result |
|---|---|---|
| **Top material fade and safe status area** | `27-break-midpoint.png`, `28-journal-midpoint.png`, `29-me-midpoint.png`, `30-scenes-midpoint.png` | Break, Journal, Me, and pushed Scenes all keep scrolling content below a single phase-aware status chrome; labels are not readable behind the status clock. |
| **Bottom clearance above the floating tab bar** | `24-break-bottom.png`, `25-journal-bottom.png`, `26-me-bottom.png`, `33-scenes-all-bottom.png`, `34-read-bottom.png`, `35-sudoku-bottom.png`, `36-card-bottom.png` | The final reachable content on Break, Journal, Me, Scenes, Short Read, Sudoku, and Focus Card remains fully visible and tappable above the persistent tab capsule. |
| **Live focus end time** | `04-active.png` | The active 18-minute session visibly reports **Ends 9:59 AM**, matching the deterministic 9:41 AM capture clock and the remaining duration. |
| **Centered, responsive Picross with spaced clues** | `09-picross.png`, `10-picross-320.png`, `45-picross-dark.png` | The standard and narrow layouts keep the complete board and all clues visible, centered in the activity viewport, with readable contrast in dark mode. |

The shared `StillScreen` now owns the status material/fade, `StillScrollViewport` owns only safe-area scroll range, and `ActivityContainerView` supplies Picross a finite header/tab-adjusted viewport. These changes are pre-Phase 2 correction work only; no later Phase 2 feature section has been started.

## Delivery by priority

| Priority | Delivered work |
|---|---|
| **P1 — Preserve and restyle existing capability** | Retained the one-line journal with mood, habits, widgets, and Live Activity; restyled the widget and Live Activity with the room-first palette and typography. The focus widget preserves the intent to show a personal, local summary rather than a productivity score. The Live Activity uses the same calmer focus presentation. |
| **P2 — Onboarding** | Restored all four goals, including **Have a calmer phone**; added the break-preference question and look question, each with a **Data not shared** chip. The privacy-first opening screen describes on-device processing, no accounts, and no servers. Palette selection stores an alternate-icon preference. The three answers remain separately editable from **Me**, and the break answer influences Break shelf ranking. |
| **P3 — Subjects** | Added a first-class `Subject` model with eight curated colors and a tolerant migration from legacy `homework.course`. Subject tint now flows into the active-focus overline, task cards, day dots, timeline capsules, and segmented personal-focus charts. |
| **P4 — Completion** | Completion now compares today’s focus duration with the person’s own usual focus day once there is enough previous local history. It presents exactly three diverse, ranked break suggestions as compact glass cards, alongside an honest all-breaks route. |
| **P5 — Task detail and day** | Reworked task details as notebook paper; date language uses **Past due** and never “Missed.” The day screen now has a week strip with subject dots, habit bubbles, subject-colored duration capsules, grouped Anytime/Morning/Afternoon/Evening tasks, repeat controls, and non-overlapping demo sessions. |
| **P6 — Me** | Added Day/Week/Month/Year range selection, own-usual comparison text, a dashed usual-reference line, a neutral month calendar, and streak copy that never renders a zero streak as a failure. |
| **P7 — Focus Card and blocking** | Added the branded Focus Card setup and explanation route. The app-blocking UI is behind `FeatureFlags.appBlocking`; its persisted start schedule enters blocking at the selected time and ends only on a card tap or the always-available override. The app does not claim shielding when the entitlement/service is unavailable. |
| **P8 — Remaining screens and sheets** | Restyled the remaining Break activity shell, puzzles, Morning Start, Journal, settings, scenes, task sheets, and shared controls into the phase-aware glass/room system; improved focus screen checklist visibility and room variation. |
| **P9a — Room collection** | **Real.** Added a local, code-drawn collection of 20 original room objects, unlock rules, earned ownership, per-scene placement, unlock acknowledgement, and a room collection screen. It uses local focus, reading, doodle, and break history only. |
| **P9b — Wake up** | **Real fallback plus DEBUG preview.** iOS 17+ uses local notifications. The iOS 26 AlarmKit hand-off is represented by a `WakeUpScheduling` protocol boundary and DEBUG-only preview scheduler; production AlarmKit needs Apple’s capability and physical-device validation. |
| **P9c — Public-domain books** | **Real.** Bundled four verified Standard Ebooks-compatible public-domain EPUB editions, with parser and provenance tests. The reader parses them locally and does not contact a service. |
| **P9d — Seasonal scenes and Supporter** | **Real StoreKit boundary with local test configuration.** Three supporter seasonal scenes, StoreKit 2 product/restore wiring, and `StillProducts.storekit` support local Xcode testing. The purchase cannot be live until App Store Connect, signing, product review, and physical-device testing are complete. |
| **P9e — Student wording** | **Real.** Centralized student-facing language in `Copy.swift`; it is used throughout Focus, Tasks, Break, completion, notifications, and room collection. |
| **P9f — Google Calendar** | **Real Apple Calendar path plus DEBUG-only Google sample.** EventKit reads calendars already configured on iPhone. The visible Google sample adapter is clearly tagged **Preview**, makes no network call, and is off in V1/current/release. A production Google OAuth adapter remains intentionally out of scope. |
| **P9g — Branded Focus Card** | **Real deep-link/NFC foundations plus stand-in offering.** `still://` links, parser, NFC simulator, and optional CoreNFC writer boundary remain real. The artwork and “Get a card” route use a `PlaceholderFocusCardOffering` with a **Preview** tag, no price, cart, or fulfillment call; universal-link host is deliberately a placeholder. |
| **P9h — TestFlight pipeline** | **Real manual workflow, intentionally inactive.** Added `.github/workflows/testflight.yml`, manual trigger only, with explicit secret validation, archive, export, and upload steps; `TESTFLIGHT_SETUP.md` explains required adult/company ownership, App Store Connect setup, signing, and seven repository secrets. |

## What is partial or requires later validation

The Swift package suite is green locally, and the final iPhone Simulator build, test target, widget extension build, Live Activity-linked app target, and 38-screen screenshot capture passed in GitHub Actions. Accessibility labels, Dynamic Type-aware SwiftUI layouts, 44pt controls, and Reduce Motion support are implemented in code; however, VoiceOver and visual review on physical iPhone hardware remain release-validation tasks.

Family Controls shielding is deliberately **off** in `FeatureFlags.v1`, `current`, and `release`. The app contains truthful UI, a schedule state machine, and a mock/preview path, but Apple’s Family Controls Distribution entitlement, DeviceActivity monitor extension, and hardware verification are still required before shipping actual blocking. Core NFC writing similarly needs the paid-team capability and hardware test. App Group sharing for the widget and Live Activity needs paid-account provisioning verification. The Supporter product and alternate Home Screen icon assets need final App Store/App Icon review before a public release.

No backend, account, analytics destination, third-party SDK, payment flow, Google OAuth flow, physical card order flow, or network call was introduced. All live data stays on the device.

## Decisions made

- **Own-usual comparison:** the app excludes today from the usual daily-focus baseline, so the completion screen does not compare a partly completed day against itself.
- **Break shelf:** all activities remain finite and visible. Ranking promotes the selected break style and avoids repeatedly surfacing an activity used that day; there is no infinite feed or opaque recommender.
- **Subject migration:** legacy course strings become deterministic `Subject` values while preserving the original optional `homework` payload for compatibility.
- **Room collection art:** all room objects are original SwiftUI/code-drawn art. `spriteAssetName` is an explicit future seam, not a copied sprite dependency.
- **Books:** the four bundled editions are recorded in `ASSET_AND_CONTENT_POLICY.md` with their Standard Ebooks sources and public-domain/CC0 status. Territorial copyright must be re-reviewed before release outside the United States.
- **Preview boundaries:** visible stand-ins use a protocol plus a DEBUG-only flag, carry a **Preview** tag, and default off in `FeatureFlags.v1`, `current`, and `release`. Tests pin the flag contract.
- **CI:** the iOS workflow now runs on `redesign`, `redesign/**`, pull requests, and `main`; its screenshot artifact remains the proof point for the final visual review.

## New files

The following files were added relative to `main`:

```text
.github/workflows/testflight.yml
Still-upload/.gitignore
Still-upload/DESIGN_DIRECTION.md
Still-upload/Still/Assets.xcassets/AppIconPeach.appiconset/AppIcon-1024.png
Still-upload/Still/Assets.xcassets/AppIconPeach.appiconset/Contents.json
Still-upload/Still/Assets.xcassets/AppIconSky.appiconset/AppIcon-1024.png
Still-upload/Still/Assets.xcassets/AppIconSky.appiconset/Contents.json
Still-upload/Still/DesignSystem/PreviewTag.swift
Still-upload/Still/DesignSystem/StillFontRegistration.swift
Still-upload/Still/DesignSystem/RoomHeroView.swift
Still-upload/Still/Domain/ActivityPresentation.swift
Still-upload/Still/Domain/Copy.swift
Still-upload/Still/Domain/RoomObject.swift
Still-upload/Still/Domain/Subject.swift
Still-upload/Still/Domain/TaskRecurrence.swift
Still-upload/Still/Features/Focus/RoomCollectionView.swift
Still-upload/Still/Features/Me/CalendarSettingsView.swift
Still-upload/Still/Features/Me/GetFocusCardView.swift
Still-upload/Still/Resources/Fonts/InstrumentSerif-Italic.ttf
Still-upload/Still/Resources/Fonts/InstrumentSerif-Regular.ttf
Still-upload/Still/Resources/Fonts/OFL-InstrumentSerif.txt
Still-upload/Still/Resources/Fonts/OFL-Outfit.txt
Still-upload/Still/Resources/Fonts/Outfit-Medium.ttf
Still-upload/Still/Resources/Fonts/Outfit-Regular.ttf
Still-upload/Still/Resources/Fonts/Outfit-SemiBold.ttf
Still-upload/Still/Resources/PublicDomainBooks/e-m-forster_short-fiction.epub
Still-upload/Still/Resources/PublicDomainBooks/henry-david-thoreau_essays.epub
Still-upload/Still/Resources/PublicDomainBooks/robert-louis-stevenson_travel-essays.epub
Still-upload/Still/Resources/PublicDomainBooks/saki_short-fiction.epub
Still-upload/Still/Resources/StillProducts.storekit
Still-upload/Still/Services/Appearance/AlternateAppIconChanging.swift
Still-upload/Still/Services/Calendar/GoogleCalendarAdapter.swift
Still-upload/Still/Services/NFC/FocusCardOffering.swift
Still-upload/Still/Services/Purchases/PurchaseService.swift
Still-upload/Still/Services/Purchases/StoreKitPurchaseService.swift
Still-upload/Still/Services/ScreenTime/BlockingSchedule.swift
Still-upload/Still/Services/Suggestions/BreakShelfRanking.swift
Still-upload/Still/Services/WakeUp/WakeUpScheduling.swift
Still-upload/StillTests/Resources/PublicDomainBooks/e-m-forster_short-fiction.epub
Still-upload/StillTests/Resources/PublicDomainBooks/henry-david-thoreau_essays.epub
Still-upload/StillTests/Resources/PublicDomainBooks/robert-louis-stevenson_travel-essays.epub
Still-upload/StillTests/Resources/PublicDomainBooks/saki_short-fiction.epub
Still-upload/TESTFLIGHT_SETUP.md
```

## Model and persistence changes

| Model or store | Change and migration behavior |
|---|---|
| `UserPreferences` | Schema v2 adds the independent onboarding goal, break appeal, and app palette/icon preference. Missing fields decode to calm defaults and migrate idempotently. It also holds local calendar/preview toggles and existing selected-task/completion state. |
| `TaskItem` | Adds `steps`, first-class optional `subject`, planned duration, day period, repeat rule, and completion-day records for repeated occurrences. Legacy `homework.course` decodes into a deterministic `Subject`, while the legacy payload remains readable. |
| `Subject` / `SubjectColor` | New persisted model with eight stable color values; task and timeline presentation consume it directly. |
| `TaskRepeatRule` | New Codable recurrence model for once/daily/weekly/monthly tasks, interval, weekdays, and per-occurrence completion. |
| `RoomCollectionState` | New local record containing earned object IDs, acknowledged unlock IDs, and per-scene slot placements. Decoding accepts missing keys, upgrades schema version, and never revokes already-earned objects. |
| `BlockingSchedule` | New local schedule state tracks enablement, start minute, selected preset, and the `blockingUntilCardTap` phase. It is only reachable when the app-blocking flag is enabled. |
| `FocusRangeData` / `FocusRangePoint` | Stats presentation now carries own-usual reference values and per-subject duration segments so the chart can render subject-colored bars without inventing data. |
| Activity and reading records | Existing activity usage, artifact, puzzle progress, reading progress, and book repositories are reused; new shelf status derives from those local records. Bundled EPUB metadata is parsed into the existing reader model. |
| Preview/service protocols | Added local protocol seams for alternate icons, Google Calendar samples, wake-up scheduling, Supporter purchase, and Focus Card offering. The DEBUG-only implementations have no network or fulfillment side effects. |

## Verification

| Check | Result |
|---|---|
| `swift test` | **214 tests passed, 0 failures**. The suite includes subject segmentation, shelf-state, book provenance/parser, preview-boundary, room collection, onboarding, recurrence, blocking schedule, wording, fresh/complete Sudoku keypad regressions, and deterministic focus end-time coverage. |
| SwiftUI source parse | Updated Focus, Break, Me, Morning Start, shared components, and room views parsed successfully with Swift 6.1. |
| Static checks | `git diff --check` was clean before publishing. |
| iPhone CI/screenshots | **Passed.** [Run 35997812807](https://github.com/gotneckedo/ProductivityTracker/actions/runs/35997812807) built and tested the iPhone simulator app successfully, then uploaded 45 reviewed captures after the final pre-Phase 2 layout correction pass. |

## CI and screenshots

**Run:** [iOS build, tests & screenshots — 35997812807](https://github.com/gotneckedo/ProductivityTracker/actions/runs/35997812807) — **success**.
**Screenshot artifact:** `still-screenshots` (artifact ID `10807209976`), **45 PNG files**. The review covered onboarding, Home, active focus, completion, Break, activities, Journal, Tasks, Day, presets, gallery, Wake up, Me, scenes, Focus Card, dark-mode screens, all core rooms, seasonal rooms, top status-chrome proofs, and tab-bottom proofs. The exact evidence for pre-Phase 2 layout work is listed in the “Verified pre-Phase 2 layout proof” table above.
