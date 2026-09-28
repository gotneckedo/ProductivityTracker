# Still redesign notes

**Branch:** `redesign`  
**Pull request:** [#1 — Redesign Still with a room-first focus flow](https://github.com/gotneckedo/ProductivityTracker/pull/1)  
**Latest verified P0 UI head:** `e3ef5ac`
**Latest local validation:** `swift test` — **244 tests passed, 0 failures** (Swift 6.1 on Ubuntu 24.04).
**Latest compact P0 CI:** **Passed.** [Run 36449310075](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36449310075) on `e3ef5ac` built/tests the simulator app and produced the manually reviewed named item-34 captures below.
**Latest full visual gallery:** **Passed.** [Run 36420510435](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36420510435) on `9500345` produced and uploaded the retained broad gallery. It predates the later Block F contrast/touch-target corrections; those changes use the compact visual proof cited below rather than being represented as full-gallery evidence.

## P0 truth pass — accepted evidence (27 September 2026)

The P0 release-truth and visual-P0 changes are accepted only to the scope proved below. Release claims are backed by a Release configuration compiled with `STILL_PROOF` solely to expose deterministic internal routes; `FeatureFlags.release` remains active, so the captures do **not** rely on DEBUG stand-ins.

| P0 item | Result | Proving capture(s) | Review result / boundary |
|---|---|---|---|
| 1. Scheduled-blocking claim | **Done** | `proof-release-blocking.png` | Release says the time/preset can be saved but this build cannot shield apps; no simulated schedule can be started. |
| 2. Focus blocking chip | **Done** | `proof-release-focus-home.png` | No blocking-status chip appears on Focus in release. |
| 3. Morning Start | **Done** | `proof-release-morning.png`, `proof-release-morning-delivery-note.png` | Release shows **Button** as the only stop method and the local-notification/silent-mode delivery note; no card wait, checklist, or alarm claim remains. |
| 4. Capability-copy audit | **Done** | All eight `proof-release-*.png` captures | Blocking, Morning Start, Still+, Focus Card, locked-room, and Your days release copy were reviewed against their actual release boundaries. |
| 5. Still+ CTA removal | **Done** | `proof-release-still-plus.png`, `proof-release-locked-room.png`, `proof-release-me-your-days.png` | Informational Still+ and locked-room surfaces have no price, buy, or restore control while release uses `NoPurchaseService`. |
| 6. Free Focus Card setup | **Done** | `proof-release-focus-card.png` | The writable-tag/link guide is release-accessible and contains no Still+ gate; physical hardware still needs iPhone/NFC validation. |
| 7. Journal reconnect | **Done** | `proof-journal-navigation.png`, `proof-today-reflection-link.png` | Me → Your days opens Journal, and Today’s reflection links through. |
| 8. Habits reconnect | **Done** | `proof-habits-navigation.png` | Me → Your days opens the standalone Habits screen. |
| 9. All break activities | **Done** | `proof-break-all-top.png`, `proof-break-all-bottom.png` | The first and last shelf positions show the complete finite ten-activity catalog; none is paywalled. |
| 10. Entitled extra-room session | **Done (DEBUG evidence)** | `11-active-autumn.png` from full gallery run `36356954441` | An injected entitlement resolves a live Focus session in Autumn Window. Release remains locked because purchase is intentionally unavailable. |
| 11. Ambient availability | **Done** | `proof-ambient-available.png`, `proof-ambient-unavailable.png` | Four authored layers are selectable; the other eight explicitly render unavailable and cannot be selected. |
| 12. Documentation drift | **Done (source/doc audit)** | No screenshot required | `README.md`, `FUTURE_CAPABILITIES.md`, product copy, and preview terminology now state that release StoreKit is unavailable and extra rooms are permanent. |
| 13. Focus greeting removal | **Done** | `proof-release-focus-home.png`, `07-focus-room.png` from full gallery | Focus is room/action led; the day greeting remains solely on Today. |
| 14. Short Read inset list | **Done** | `proof-short-read-top.png`, `proof-short-read-bottom.png` | Books use one divided inset list, including the full lower clearance. |
| 15. First-play explanatory copy | **Done to the reviewed screens** | `14-sudoku.png`, `15-wordsearch.png`, `16-picross.png`, `18-breathing.png`, `20-doodle.png`, `proof-short-read-top.png` from full gallery | Activity surfaces are immediately usable; explanatory text remains only in empty/error states. |
| 16. Named visual ledger | **Done** | `proof-break-all-top.png`, `proof-scenes-locked-core.png`, `proof-release-focus-card.png`, `proof-short-read-top.png`, `proof-short-read-bottom.png` | Stable proof names exist for the disputed surfaces. `proof-scenes-locked-core.png` shows static “Opens after 12 sessions,” not a remaining-work countdown. |
| 17. Doodle states | **Done** | `15-gallery-empty.png`, `16-gallery-one.png`, `17-gallery-several.png`, `18-gallery-error.png` | Empty, one, several, and honest storage-error states are all captured. |
| 18. Get a Card | **Done (DEBUG review surface)** | `22-get-card.png` | The secondary setup control and explicit no-commerce disclosure are visible. It remains preview-only, with no order or payment flow. |

**Decision recorded:** room unlocks communicate one fixed milestone (“Opens after 12 sessions”) rather than a changing “sessions to go” counter. This preserves the earned-room model without importing countdown pressure.

## Blocks C–D — touch response and affordances (implementation awaiting CI evidence)

**Decision recorded:** the shared press response supplies the light touch-down cue for ordinary rows; semantic actions fire their own one-shot feedback after a state transition so starting focus or finishing a break never double-pulses. Haptics default on, interface sounds default off, and both remain local device preferences.

Item 19 is implemented locally but remains **unproven** until the next compact CI artifact is reviewed. The static proof routes are deliberately named `proof-interaction-final-minute.png`, `proof-interaction-complete.png`, `proof-interaction-room.png`, `proof-interaction-task.png`, and `proof-interaction-invalid-entry.png`; temporal animation and physical haptics require item 22’s simulator recordings and real-device validation.

Item 20 uses iOS **Reduce Motion** as the production authority. `proof-reduce-motion-focus.png` is a CI-only environment override exercising the same branch: room/cat movement is static, task and habit state changes cross-fade instead of bouncing or lifting, the final-minute timer cross-fades rather than animating its line, and haptic calls remain enabled. The screenshot establishes the reduced state; a temporal recording remains part of item 22.

**Decision recorded — item 21:** Still uses two local switches in **Me → Accessibility**: haptics defaults on and interface sounds defaults off. Ambient soundscapes are intentionally unaffected, and iOS controls Reduce Motion independently. `proof-accessibility-feedback.png` is required before this item is marked complete.

**Decision recorded — item 22:** automated simulator video is not available in this repository’s Linux/Actions toolchain because no UI gesture driver or UI-test target is configured. Static end-state frames remain CI-proven; the four requested touch recordings are deferred to a Mac/Xcode UI-test or physical-device pass rather than fabricated from stitched screenshots.

**Item 23 scope:** Tasks, habits, journal lines, and custom presets now use local destructive swipes with a five-second undo toast. The current data model has no user-reminder or Later-item entity, so no destructive action exists to add there; that is recorded as an absent-model boundary, not treated as covered.

**Item 24 scope:** task rows, room targets, Break activities, Scene cards, soundscape layers, and statistic tiles now expose native long-press context menus with an object-specific preview. `proof-long-press-previews.png` is the required CI review catalogue for the six preview treatments; the actual native press menu remains an iOS system interaction, not a custom simulated sheet.

**Decision recorded — item 25:** scene order/default, Break shelf order/hidden state, and Today routine prompts live only in `UserPreferences`; no behavioral record or streak is created. Hidden Break activities remain in edit mode with an explicit restore action. Free builds hold up to three Today prompts, and the UI does not present an in-product purchase CTA when the additional-capacity entitlement is unavailable.

**Decision recorded — item 26:** search is deliberately scoped to the current surface: History searches completed focus sessions and one-line journal records held on device; Short Read searches bundled reading titles, sources, authors, and imported-book metadata. It never opens a device-wide or network search.

**Decision recorded — item 27:** pull-to-refresh never fetches network data. Today reloads local records and recalculates its time phase; Break rotates only automatically ranked suggestions, while a person’s saved shelf order stays fixed.

**Decision recorded — items 28–30:** History is calendar-led but non-judgmental: dots mean a saved local record, never a streak or a score. The CI default fixture contains 30 completed sessions spread across recent days; the dedicated `history-empty` route remains deliberately unseeded.

**Item 31 — accepted AX3 layout proof (28 September 2026):** [run 36404640211](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36404640211) on `56b58b0` passed its simulator build/tests and produced the manually reviewed `still-screenshots` artifact (**ID `10962279914`**). Default-size evidence is `01-today.png`, `04-active-autumn.png`, `05-break.png`, and `19-me.png`; AX3 evidence is `proof-ax3-today.png`, `proof-ax3-focus.png`, `proof-ax3-break.png`, and `proof-ax3-me.png`. At AX3, Today keeps its primary Start control clear and moves alternatives into a 44pt menu; Focus uses the readable “Choose a task” visual label while VoiceOver retains the complete picker label; Break category and Me range controls each collapse to one-line menus; and floating navigation becomes a labeled icon rail rather than wrapping. Serif display type and the large statistic remain legible. The task-picker correction is `56b58b0`.

**Adjacent History visual recheck:** the same reviewed artifact includes `proof-history-full.png`, `proof-history-empty.png`, and `proof-search-history.png`. The seeded local calendar/list, empty state, and search state retain phase-correct readable status/navigation chrome; these captures do not replace the required full-gallery run for the sprint block.

**Item 32 — partial / deferred:** the timer is no longer marked as continuously updating for VoiceOver; it announces its value when focused. Room objects, cat, and Sudoku controls have explicit labels and hints. An exhaustive VoiceOver audit cannot be credibly closed from this repository’s static screenshot runner: it has no UI-test target or accessibility-tree assertion harness, and a screenshot cannot verify spoken output, focus order, or a custom control’s actual trait. The full audit is deferred to an Xcode Accessibility Inspector/UI-test or physical-iPhone pass. This sprint therefore makes no blanket “every custom control” claim.

**Item 33 — accepted contrast audit (28 September 2026):** [run 36442882753](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36442882753) on `a4d4d05` passed package and simulator tests and produced the manually reviewed `still-screenshots` artifact (**ID `10980629769`**). `proof-scenes-locked-core.png` proves the actual no-session state with readable Library Light, Train Window, and Night City unlock copy; `proof-contrast-me-preferences.png` proves both actionable **Not set** values on their glass rows; `06-sudoku.png` proves every fresh keypad digit remains full-strength; and `01-today.png` proves the small Biology subject overline remains readable. The numeric AA regression coverage lives in `AccessibilityContrastTests`: 241 local tests passed, including documented light, dark/focus, locked-room, preference, keypad, semantic-label, and all eight subject-text pairs. Decorative pastel fills remain fill-only; semantic text/symbol tokens are now opaque paired colors. The final locked card is a noninteractive static surface rather than a disabled SwiftUI Button, avoiding system opacity reduction of its mandatory unlock requirement.

**Item 34 — accepted 44pt touch-target audit (28 September 2026):** [run 36449310075](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36449310075) on `e3ef5ac` passed package and simulator tests and produced the manually reviewed `still-screenshots` artifact (**ID `10984142906`**). `proof-touch-targets-room.png` proves the existing RoomHero previous/next arrows at their 44pt geometry without covering the room; `06-sudoku.png` proves the fresh six-digit keypad and the six 2×3 groups; `07-wordsearch.png` and `08-picross.png` prove that direct puzzle cells retain their fixed 44pt minimum rather than shrinking to a narrow layout. Puzzle boards now use horizontal access when a container becomes smaller than their fixed geometry. `AccessibilityTouchTargetTests` pins the 44pt contract and Sudoku, Word Search, and Picross span calculations; the shared segmented control, Today mood choices, and Task-detail step toggle also now use the shared minimum target token. This proof is limited to visual target geometry; it does not claim a completed VoiceOver audit (item 32 remains deferred).

**Block F gallery check:** [run 36420510435](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36420510435) successfully ran the retained manual/scheduled full visual gallery (**artifact `10971345094`**). Representative manually reviewed captures `40-me-bottom.png`, `47-scenes-all.png`, `51-sudoku-bottom.png`, `54-active-dark.png`, `57-me-dark.png`, `proof-room-art-unoccluded.png`, and `proof-tasks-bottom-clear.png` found no new broad regression in bottom clearance, room presentation, Scene grid, Sudoku, or dark semantic contrast.

## Master Plan decisions — product direction, not implementation proof

These decisions were supplied by CoCo on 26 September 2026 in response to
Section 7 of the Master Plan. They are binding for later implementation; they
do **not** claim that the corresponding feature has shipped or passed CI.

| Decision | Direction |
|---|---|
| **Free floor** | All four earned core rooms; three saved presets; three routine items; every break activity; Silence plus the four original bundled loops; the complete History list and lifetime totals. Local history is never deleted or gated. |
| **Still+ scope** | Extra permanent rooms; unlimited presets and routine items; additional genuinely authored sound layers and locally saved custom mixes; History analysis (month/year views, subject breakdown, personal-usual comparison, filled calendar); alternate cat coats; Card alarm features; daily app limits and morning lock only when Apple permits them. Basic breaks are never gated. |
| **Cat coats** | Ginger is free. Tabby, Cream, and Midnight are Still+ cosmetics only, with no behavioral difference. |
| **Extra rooms** | Keep the three existing extra rooms permanently available through Still+. There is no rotation, expiration, countdown, or limited-time framing. |
| **Card alarm boundary** | User-installable builds, including TestFlight, show setup and information only: no armable alarm and no simulated ringing. DEBUG/CI builds may show the complete mock ring/card-tap flow for design evidence. A Preview tag never turns an alarm that cannot fire into a shippable capability. |
| **Planning price** | Plan for **$2.99/month** and **$24.99/year**, subject to final physical-card economics. Enroll in Apple’s Small Business Program before App Store Connect setup. |
| **Light theme hierarchy** | Light gradients are materially quieter than the saturated predecessor; page field, raised glass controls, inset lists, and matte activity canvases are distinct values. The final `proof-light-theme.png` capture was reviewed on 27 September 2026. |

### Master Plan debate calls

- **A13 — study anchor:** accepted for Wave 3 as one optional pinned study anchor. It will remain silent when unmet, create no streak, and never produce a catch-up prompt; this preserves the useful “return point” without turning it into a daily obligation.
- **F9 — settle-in fade:** accepted with the Master Plan condition: any 30-second sound fade happens **during the first 30 seconds of a started session**, never before Start, so Still never delays the first action.

## Master Plan Wave 1 — final visual verification

The implementation and proof point for this checkpoint is the `still-screenshots`
artifact from [run 36291223612](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36291223612)
at `036bfb0`. Its ZIP was integrity-checked locally and all named captures below
were manually reviewed. Earlier generated-room proofs remain historical only.

On 26 September 2026, the user supplied eight transparent **512×512** room
PNGs plus one 5×4 collectible sheet, declared as AI-generated originals made
for Still from written prompts and not reference-product derivatives. The
renderer uses those assets unchanged on a square, nearest-neighbor sprite seam;
the code renderer remains only as a missing-asset fallback. The supplied
collectible sheet is sliced by opaque alpha-bounded component rather than a
fixed-cell crop. Cat, hotspot, lamp, floor, and collectible anchors are now
per-room data, not coordinates inherited from the temporary 160×132 artwork.

| Wave 1 requirement | Proving capture(s) | Reviewed result |
|---|---|---|
| **All eight full-size supplied rooms** | `05-focus-room.png`, `58-room-library.png`, `59-room-train.png`, `60-room-city.png`, `61-room-autumn.png`, `62-room-snow.png`, `63-room-spring.png`, `64-room-sleep.png` | Rainy Bedroom, Library Light, Train Window, Night City, Autumn Window, Snow Day, Spring Rain, and the reserved Sleep room all show readable two-wall/floor perspective, coherent furniture planes, and distinct palette/composition. The three extra rooms are shown with DEBUG-only in-memory Still+ entitlement for review; this is not a production-purchase claim. |
| **Clean room surface and accessible targets** | `proof-room-art-unoccluded.png` | Persistent visual object labels are absent, preserving the room art. Desk, Bookshelf, Wall calendar, Plant, and Window retain native 44pt VoiceOver-labeled targets in code; the screenshot intentionally proves the unoccluded visual layer rather than replacing accessibility validation. |
| **Placed collectible anchors and scale** | `proof-room-collectible-anchors.png` | The pencil cup sits on the desk, radio on the shelf, trailing plant at the window, and rug on the floor plane. The initial oversized pencil cup/rug arrangement was rejected; this final capture reflects the corrective commit `036bfb0`. |
| **Focus idle, active, and transition composition** | `05-focus-room.png`, `08-active.png`, `09-complete.png` | The idle room, running Focus surface, and calm completion screen each retain an art-first hierarchy without copy overlapping the room. |
| **Supplied collectible review sheet** | `06-sprite-contact-sheet.png`, `33-sprite-contact-sheet-bottom.png` | The authored room, object, cat, and utility asset review surfaces are present from top to bottom. |
| **Focus helper-copy removal** | `proof-focus-helper-clean.png` | The rejected explanatory sentence “A task is optional. Adding one can make the session feel clear.” is absent from Focus. |
| **Bottom clearance above floating navigation** | `proof-today-bottom-clear.png`, `proof-tasks-bottom-clear.png`, `proof-sudoku-bottom-clear.png`, `proof-me-bottom-clear.png` | Each requested final scroll state leaves its last content visible above navigation or, for Tasks, inside its modal’s own safe viewport. |
| **Light theme value hierarchy** | `proof-light-theme.png` | A deterministic 9 AM fixture now resolves to a warm off-white page with visibly raised surfaces and darker readable type; it no longer accidentally captures the night phase. |

**Accepted Wave 1 boundary:** `64-room-sleep.png` is an art-review screen only. It explicitly does not arm or simulate an alarm. A later DEBUG-only alarm mock needs a separate state machine and proof; no release alarm behavior is implied here.

**Next checkpoint:** Wave 2 begins with touch responsiveness, the affordance layer, and undo for destructive actions. It is not implemented or claimed verified in this note yet.

## Phase 2 — verified sprite-first room checkpoint (historical generated-art evidence)

This checkpoint is limited to Phase 2’s original pixel package, sprite-first room seam, accessible object targets, and the evidence route. It does **not** claim the later Phase 2 cat behavior, full Today modes, alarm/wake flow, daily limits, or complete Still+ gating; those remain in progress.

The accepted artifact is `still-screenshots` from [run 36242555096](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36242555096) at `8dd3f9d` (**48 PNGs**). The immediately preceding room screenshot was rejected because the Bookshelf target label wrapped. Commit `8dd3f9d` makes all first-three-days labels readable on one line and is the only artifact cited below.

| Requirement | Implementation | Proving capture(s) | Review result |
|---|---|---|---|
| **Historical generated 32-color package** | `Tools/generate_still_sprites.py` deterministically created the temporary room bases and objects at this checkpoint, alongside break/empty-state/card assets, bird, and four six-frame cat coats. | `04-sprite-contact-sheet.png`, `29-sprite-contact-sheet-bottom.png` | **Historical only.** The room and collectible portion was superseded on 26 September 2026 by the supplied 512px package recorded above. The fallback seam, cat art, and non-room utility sprites remain relevant. |
| **Sprite-first Focus room** | `SceneDefinition.spriteAssetName`, `RoomObject.spriteAssetName`, and `SpriteFirstRoomSurface` select authored PNG rooms and object assets with pixel interpolation, retaining a code-drawn fallback for missing assets. Starter furniture is visible from the first room. | `03-focus-room.png` | Rainy Bedroom renders as a crisp pixel room with starter bed, desk, lamp, shelf, plant, window, and cat—without an empty-room reward state. |
| **Accessible room object targets** | Desk, Bookshelf, Calendar, Plant, and Window retain 44pt targets, VoiceOver labels/hints, and app routes. Persistent visual labels are removed because they obscured the authored room art. | `proof-room-art-unoccluded.png` from run `36291223612` | **Superseded by the final Wave 1 proof.** The visual layer is clean while the native accessibility targets remain in code. |
| **Core room collection and extra-room seam** | The scene catalog binds the original art to Rainy Bedroom, Library Light, Train Window, Night City, and permanent extra rooms; free core rooms remain distinct while Still+ rooms use the honest locked state. | `38-scenes-all.png`, `39-scenes-extra.png` from run `36291223612` | Four core room thumbnails are fully inside the two-column layout, and the permanent extra-room cards carry no rotation or expiry framing. |

**Known Phase 3 difference:** the accepted Phase 2 Focus evidence still uses the existing action card beneath the room. Phase 3 explicitly replaces that composition with a full-bleed room and floating controls; this Phase 2 proof makes no Phase 3 visual claim.

## Visual correction pass

The post-review correction pass explicitly registers the bundled Instrument Serif and Outfit files at launch, retaining the `UIAppFonts` entries as a second registration path. Captures now show Instrument Serif in display headlines, timers, and large statistics rather than a system-sans fallback. Shared glass surfaces clip their material, fill, border, and shadow to one rounded contour; Home, active focus, Journal, Me, and Short Read no longer retain an outer rectangular fill.

The original room renderer now floats over the phase background with a warm halo, lamp bloom, shadow, motes, two wall planes, and reduced-motion-aware motion. It is also the renderer used in Scene thumbnails. The final Wave 1 captures prove clearance for Today, Tasks, Me, and Sudoku in `proof-today-bottom-clear.png`, `proof-tasks-bottom-clear.png`, `proof-me-bottom-clear.png`, and `proof-sudoku-bottom-clear.png`. The active-focus screen now has one subject-or-Focus overline, a thin glowing progress line, one sound-state glyph, and a full-width Study Plan card.

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
| **Bottom clearance above the floating tab bar** | Final Wave 1 proof: `proof-today-bottom-clear.png`, `proof-tasks-bottom-clear.png`, `proof-me-bottom-clear.png`, `proof-sudoku-bottom-clear.png` from run `36291223612` | **Verified.** The previously rejected historical set is retained only as historical context; all four disputed screens now show the final content above navigation or their modal safe viewport. |
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
| **P9d — Extra rooms and Supporter** | **Real StoreKit boundary with local test configuration.** Three permanent extra rooms, StoreKit 2 product/restore wiring, and `StillProducts.storekit` support local Xcode testing. The purchase cannot be live until App Store Connect, signing, product review, and physical-device testing are complete. |
| **P9e — Student wording** | **Real.** Centralized student-facing language in `Copy.swift`; it is used throughout Focus, Tasks, Break, completion, notifications, and room collection. |
| **P9f — Google Calendar** | **Real Apple Calendar path plus DEBUG-only Google sample.** EventKit reads calendars already configured on iPhone. The visible Google sample adapter is clearly tagged **Preview**, makes no network call, and is off in V1/current/release. A production Google OAuth adapter remains intentionally out of scope. |
| **P9g — Branded Focus Card** | **Real deep-link/NFC foundations plus stand-in offering.** `still://` links, parser, NFC simulator, and optional CoreNFC writer boundary remain real. The artwork and “Get a card” route use a `PlaceholderFocusCardOffering` with a **Preview** tag, no price, cart, or fulfillment call; universal-link host is deliberately a placeholder. |
| **P9h — TestFlight pipeline** | **Real manual workflow, intentionally inactive.** Added `.github/workflows/testflight.yml`, manual trigger only, with explicit secret validation, archive, export, and upload steps; `TESTFLIGHT_SETUP.md` explains required adult/company ownership, App Store Connect setup, signing, and seven repository secrets. |

## What is partial or requires later validation

The Swift package suite is green locally, and the final iPhone Simulator build, test target, widget extension build, Live Activity-linked app target, and 72-screen screenshot capture passed in GitHub Actions. Accessibility labels, Dynamic Type-aware SwiftUI layouts, 44pt controls, and Reduce Motion support are implemented in code; however, VoiceOver and visual review on physical iPhone hardware remain release-validation tasks.

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
