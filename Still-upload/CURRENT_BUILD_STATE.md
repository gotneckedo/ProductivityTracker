# Still — Current Build State

**Repository:** `gotneckedo/ProductivityTracker`
**Branch:** `redesign`
**Application implementation snapshot:** `7308673` (`P0-43 Fix room preview contrast and proof scroll`)
**PR:** [#1 — Redesign Still with a room-first focus flow](https://github.com/gotneckedo/ProductivityTracker/pull/1) — **open, not merged**
**Report date:** 29 September 2026
**Closeout rule:** this report separates implemented code, accepted named visual evidence, and successful-but-unreviewed CI artifacts. A green run alone is not visual acceptance.

> **Headline:** Still is a local-first SwiftUI focus app with a four-tab shell, local tasks/routines/history, focus timers, a finite Break shelf, on-device reading/puzzles/doodles, a sprite-first room, room progression, and a non-punitive cat companion. The implementation is substantially advanced, but this is **not a final shipping claim**: the latest Item 43 visual proof has not been manually accepted, items 37 and 38 are recorded as implemented-but-visually-unproven for closeout, and several platform capabilities still require Apple approval or real-device validation.

---

## 1. How to read this report

### 1.1 Status terms

| Term | Meaning in this report |
|---|---|
| **Implemented** | Production-connected local source behavior exists. It is not automatically a visual or shipping claim. |
| **Accepted proof** | A named CI screenshot artifact was manually reviewed and recorded in `REDESIGN_NOTES.md`. |
| **Implemented, visually unproven** | Code and/or a green run exist, but this closeout does not accept a named final frame as proof. |
| **Partial / deferred** | Useful code or a deliberate boundary exists, but a material part of the requested behavior is not closed. |
| **Stub / preview** | DEBUG, CI, in-memory, StoreKit-local, or otherwise explicitly non-production surface. |
| **Externally blocked** | Requires a paid Apple account, entitlement, App Store Connect, domain, hardware, or other work outside this repository. |

### 1.2 Evidence actually checked

| Evidence | Current result | Scope / limit |
|---|---|---|
| Local Swift package suite | **268 passed, 0 failures** on Swift 6.1 / Ubuntu 24.04 before the final documentation-only closeout. | Covers domain/controller/service logic; it does not compile or render the entire iOS app. |
| Latest CI workflow | [Run 36644288375](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36644288375) on `7308673` completed successfully: `ios` and **Full visual regression gallery**. | The artifact has not been manually reviewed after the final Item 43 contrast/scroll correction, so it is not accepted visual evidence. |
| Accepted room/progression evidence | Runs `36535295607` (ambient), `36552080760` (session state), `36566042242` (cat), and `36599341478` (progression) were manually reviewed and recorded. | These establish only the named frames and states in the ledger. |
| Items 37–38 proof candidates | [36517157860](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36517157860), [36513443531](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36513443531), and [36513475265](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36513475265) passed. | Per closeout instruction, items 37 and 38 are **implemented-but-visually-unproven** until their designated frames are re-reviewed and explicitly accepted. |
| Current source/configuration | `redesign` at `7308673`, workflow scripts, feature flags, demo routes, and local data model. | Source cannot prove Apple frameworks, purchases, hardware NFC, notifications, haptics, or spoken VoiceOver output. |

### 1.3 Screenshot-proof rule: final status

The compact Release/P0 matrix remains on push/PR and the broad gallery remains scheduled/manual. The following artifacts are **not** accepted merely because their CI run succeeded:

- Item 37 — `still-screenshots` artifact **11012104970** in run `36517157860`.
- Item 38 — compact run `36513443531` and broad-gallery artifact **11010818054** in run `36513475265`.
- Item 43 — compact artifact **11068714952** and broad-gallery artifact **11069215931** in run `36644288375`.

---

## 2. Current architecture and data ownership

Still is a native SwiftUI iOS app with no backend or account requirement. `StillApp` creates observable `AppState` from `DependencyContainer.live(flags: .current)`; `RootView` selects onboarding or the four-tab shell; `AppRouter` owns navigation, sheets, and completion presentation.

```text
StillApp
  └─ AppState(DependencyContainer.live)
       ├─ AppRouter → tabs, stacks, sheets, completion cover
       ├─ local display mirrors → SwiftUI feature views
       └─ controller/service actions → local repositories → reload

RootView
  ├─ First-run onboarding when needed
  └─ Today · Focus · Break · Me
       ├─ independent NavigationStacks
       ├─ floating tab navigation
       └─ local completion/notice presentation
```

### 2.1 Persistence and privacy boundaries

| Data | Local boundary | Current behavior |
|---|---|---|
| Tasks, sessions, activities, journal, habits, doodles, puzzle state, reading, room collection | SwiftData-backed local records with JSON payloads | On-device persistence; in-memory degradation path shows a notice rather than crashing. |
| Preferences, focus presets, Break/scene/routine ordering, cat presence | `UserDefaults` JSON | Tolerant migrations and local-only personalization. |
| Imported EPUBs | App Support `Books/` plus local library index | Remains on device; bundled public-domain books are local resources. |
| Soundscape data | Bundled/local AVFoundation assets and local levels/mixes | Four authored loops are represented; unavailable layers are explicitly unavailable. |
| Event logging | Bounded local tracker | No analytics or backend destination is configured. |

**Architecture strengths:** local-first ownership, feature flags, deterministic demo fixtures, explicit preview boundaries, and source-connected recovery notices.

**Architecture risks:** broad `AppState.reload()` coupling, several independent local stores with no cross-store transaction, missing per-object sprite fallback, and configuration/asset claims that still need device and release review.

---

## 3. Screen, route, sheet, and activity inventory

### 3.1 App shell and primary tabs

| Surface | Status | Current state / boundary |
|---|---|---|
| Onboarding / first-run gate | **Implemented** | Three required privacy-first screens; furnished starter room and one-tap session surface; optional preferences move after first completion. Item 38 visual proof remains unaccepted for closeout. |
| Floating tab shell | **Implemented** | Exactly four tabs: Today, Focus, Break, Me; shared safe-area viewport reserves the floating navigation area. |
| Today | **Implemented** | Local tasks, focus start, timeline, reflection/mood, routines, local refresh, and room moment. Morning/evening modes remain a later item. |
| Focus home / active focus | **Implemented** | Room, task/preset selection, countdown/count-up/Pomodoro, sound controls, notes, breaks, completion flow, and local room state. |
| Break | **Implemented** | Finite, free activity shelf with ordering/hide/edit controls, refresh rotation, and local activity routes. |
| Me | **Implemented** | Personal summary, History, scenes, presets, accessibility preferences, capability setup/information surfaces, and reset. |

### 3.2 Sheets, pushed routes, and review surfaces

| Surface | Status | Current state / boundary |
|---|---|---|
| Tasks / task detail / timeline | **Implemented** | Local tasks, subjects, recurrence, steps, undoable deletion, and time-grouped timeline. |
| History | **Implemented** | Local calendar/list/search surface, 30-day fixture, empty route, and on-device query scope. |
| Journal / Habits | **Implemented** | Local one-line reflection, moods, habits, and discoverable routes. |
| Room collection | **Implemented** | Local object ownership, acknowledgement, placement/removal, and 20-object catalog. |
| Scene collection | **Implemented / partial entitlement** | Four earned core rooms work. Extra-room presentation remains informational until release purchases are real. |
| Short Read / imported EPUBs | **Implemented** | Four public-domain bundled books plus local import/progress; no network retrieval. |
| Focus Card / blocking / Morning Start | **Partial / bounded** | Informational/setup behavior remains honest; no real NFC writing, app shielding, or alarm claim in release. |
| Context preview catalogue | **DEBUG/CI review-only** | Mirrors local long-press facts for room objects. Item 43’s final artifact is currently unreviewed. |

### 3.3 Break activities

| Activity group | Status | Boundary |
|---|---|---|
| Sudoku, Picross, Word Search | **Implemented** | Persisted local puzzles; 44pt geometry and accessible labels/hints in code. |
| Short Read, Pixel Doodle, Creative Prompt, Brain Dump | **Implemented** | Local/offline reading and creation; no cloud sharing. |
| Guided Stretch, Box Breathing, Do Nothing | **Implemented** | Finite, calm activities with no streak or score pressure. |
| Shelf access | **Implemented** | All Break activities remain free; ordering/hide preference lives locally. |

### 3.4 DEBUG/CI fixtures

`DemoLaunch` provides deterministic routes for Release-truth captures, AX3, history, contrast, first-run, capability errors, room phases/session states, cat states, progression, and room interaction previews. These routes exist solely for review and do not grant unavailable production capabilities.

---

## 4. Feature-by-feature current state

### 4.1 Today, tasks, routines, history, and personal data

| Area | Status | Current behavior / remaining boundary |
|---|---|---|
| Tasks and subjects | **Implemented** | Local tasks with eight curated subject colors, due/schedule, recurrence, steps, and undoable destructive actions. |
| Reflection and Journal | **Implemented** | One local entry per day plus mood and history; no account or upload. |
| Habits | **Implemented** | Local check-ins, archive/restore, and no guilt-oriented missed-day mechanics. |
| Today routines | **Implemented** | Local reorder/add/remove; free capacity remains intentionally bounded. |
| History | **Implemented** | Local sessions/journal search, calendar/list, lifetime data retention, and dense fixture. |
| Morning/evening layout distinction | **Not complete** | Item 46 remains in the queue. |

### 4.2 Focus, completion, and sound

| Area | Status | Current behavior / remaining boundary |
|---|---|---|
| Countdown, count-up, Pomodoro | **Implemented** | Local timer engine, pause/resume, phase actions, recovery, and completion state. |
| Completion | **Implemented** | Calm completion language, break suggestions, optional personalization invitation, and earned-object acknowledgement. |
| Soundscapes | **Partial but truthful** | Four authored loops plus Silence are usable; unavailable layers cannot be selected. |
| Focus Rescue | **Partial** | A guidance surface exists; Item 48 must make it a real two-minute flow or remove timer-like copy. |
| Haptics / interaction sound | **Implemented, hardware-unverified** | Local preference toggles and UIKit feedback policy exist; actual tactile/audio behavior requires an iPhone. |

### 4.3 Rooms, progression, and cat

| Area | Status | Current behavior / proof state |
|---|---|---|
| Sprite-first room renderer | **Implemented** | Original/supplied art, pixel interpolation, shared scene thumbnail treatment, phase-aware surfaces, and local fallback seam. |
| Ambient room phases | **Accepted proof** | Morning/afternoon/dusk/night accepted in run `36535295607`. |
| Session room states | **Accepted proof** | Idle/focus/break/finished accepted in run `36552080760`. |
| Cat state machine | **Accepted proof** | Away, scene-change, night, final-minute, and rare reaction accepted in run `36566042242`; no care/streak pressure. |
| Progression acknowledgement | **Accepted proof** | Earned Pencil cup acknowledgement and collection handoff accepted in run `36599341478`. |
| Room object second layer | **Implemented, visually unproven** | Desk/books/plant/window/lamp/clock/calendar local facts and long-press previews exist. Final contrast/scroll revision is in `7308673`; run `36644288375` remains unreviewed. |

### 4.4 Accessibility and visual policy

| Area | Status | Current behavior / boundary |
|---|---|---|
| AX3, contrast, 44pt, Bold Text/Increase Contrast | **Accepted prior proof** | Code and named proof routes cover these mechanics, with the limits recorded in `REDESIGN_NOTES.md`. |
| Reduce Motion | **Implemented** | System authority plus CI override; static screenshots cannot validate temporal quality. |
| VoiceOver | **Partial / real-device required** | Timer avoids continuous announcements; many custom controls have labels/hints. Spoken output, order, traits, and real interaction remain unverified. |
| Haptics / interaction sound | **Implemented / real-device required** | Static CI cannot establish tactile feedback or device audio policy behavior. |

---

## 5. Capability truth table — release versus DEBUG/CI

| Capability | Release/current code | DEBUG/CI / local fixture | External requirement |
|---|---|---|---|
| Still+ purchase | Informational only; release uses `NoPurchaseService`. | In-memory/StoreKit-local preview can show entitlement. | App Store Connect, products, signing, sandbox/device validation. |
| Extra rooms / cat coats | Locked/informational in release. | Entitlement fixture can review art. | Real StoreKit and entitlement/catalog propagation. |
| Focus Card / NFC | App-side deep-link parser exists; no claimed tag writing. | CI can simulate parser path. | Real tag/device testing; capability/signing if writing is pursued. |
| Morning Start / alarm | Local notification planning only; no armable/ringing alarm. | DEBUG/CI mock may demonstrate visual flow. | Supported Apple capability, device/system-stop validation. |
| App limits / shielding | Release flag off; no apps are shielded. | Non-shielding/unauthorized fixture proves copy boundary. | Family Controls Distribution approval, DeviceActivity, hardware. |
| Widgets / Live Activity | Source boundary exists. | Preview/local state only. | App Group/extension provisioning and device validation. |
| Apple Calendar | Conditional/read-only adapter. | Preview where available. | Permission and device validation. |

---

## 6. Customer-facing capability copy and product truth

The governing copy principle remains: **never represent an unavailable Apple or commercial capability as functioning.** Current release-facing behavior is therefore constrained as follows:

| Topic | Current truthful statement |
|---|---|
| Still+ | Extra rooms/coats are informationally locked; there is no live purchase, restore, price, or entitlement claim in the release path. |
| Focus Card | A compatible tag can route into the app-side URL parser, but Still does not claim to write a tag or unlock digital entitlement from a physical card. |
| Morning Start | It is a local-notification plan, not an alarm. iOS/system controls remain authoritative. |
| App blocking | It is unavailable in the current release configuration; nothing is shielded. |
| Audio layers | Missing/unauthored layers are unavailable, not advertised as playable. |
| History / Breaks | Local history is not deleted/gated; all Break activities remain free. |

Full literal-copy audit history, release-proof files, and deliberate boundaries remain in `REDESIGN_NOTES.md` and the capability source files named in §11.

---

## 7. Visual, UX, proof, and product work still open

### P0 — proof and validation boundaries

1. **Items 37 and 38 are implemented-but-visually-unproven for this closeout.** Re-review their named artifact frames and update the ledger only after acceptance.
2. **Item 43 is implemented but unproven at final code head `7308673`.** Run `36644288375` succeeded, but its final broad-gallery and compact artifacts are not manually accepted.
3. **VoiceOver spoken output, haptics, and temporal Reduced Motion are not screenshot-provable.** They need Xcode Accessibility Inspector/UI tests and a real iPhone.
4. **No commercial/platform feature should be marketed as live.** StoreKit, Family Controls, NFC writing, alarm behavior, Universal Links, widgets/Live Activity provisioning, and physical-card fulfillment remain outside this closeout.

### P1 — product and release work

5. Implement or remove the Focus Rescue timer-like promise (item 48).
6. Add a browsable local reader for saved session notes (item 49).
7. Resolve or document the untargeted `StillLiveActivity/` folder (item 50).
8. Improve persistence recovery and cross-store consistency (item 51).
9. Add a verified launch screen and all app-icon variants (item 52).

### P2 — intentional later work

10. Discovery details, Low Stimulation mode, genuinely distinct Today morning/evening layouts, and need-based Break shelf organization remain in the queue before the P1 closeout items above.
11. Any StoreKit, Family Controls, alarm, NFC, Universal Link, widget, or Live Activity work must wait for the required Apple/dev-account/hardware authority.

---

## 8. External readiness / approval checklist

| Item | Current state | Outside-repository action |
|---|---|---|
| Apple Developer membership / signing | Not proven in this repository. | Paid membership, signing ownership, agreements. |
| App Store Connect / Still+ | Not configured for a live transaction. | Create products, prices, legal copy, metadata, sandbox/device test, review. |
| Family Controls | Release off. | Distribution entitlement, DeviceActivity extension, device validation. |
| NFC writing | Not claimed operational. | Capability/signing, writable tag, real iPhone testing. |
| Alarm | Not implemented in user-installable builds. | Apple-supported framework/capability and system-control/device validation. |
| Universal Links / branded card | Placeholder only. | Owned domain, AASA, Associated Domains, fulfillment decision. |
| Widgets / Live Activity | Source boundary only. | App Group provisioning and target/hardware validation. |
| Books, audio, art provenance | Local assets exist. | Maintain territorial rights, original-content, and attribution/provenance release records. |

---

## 9. Test and CI truth

| Check | Result | Limit |
|---|---|---|
| Swift package suite | **268 passed, 0 failures** before documentation-only closeout. | Does not compile every SwiftUI/root/framework integration on Linux. |
| Latest CI | [36644288375](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36644288375) **success** for simulator build/tests, compact screenshots, and broad gallery. | Successful jobs and uploaded artifacts are not visual acceptance until manually inspected. |
| Accepted broad gallery evidence | Runs `36535295607`, `36552080760`, `36566042242`, `36599341478`. | Establish only their named room/progression frames. |

**Important test limitations:** CI uses a simulator and static screenshots. It cannot prove haptic feel, spoken VoiceOver output, Switch Control/Voice Control behavior, notifications/alarm delivery, background audio, StoreKit transactions, app shielding, NFC hardware, Universal Links, widget provisioning, or a complete device-size/locale matrix.

---

## 10. Recommended next build sequence

1. **Accept or reject outstanding evidence first:** manually review the item 37, 38, and 43 artifacts and update `REDESIGN_NOTES.md` truthfully.
2. **Complete the remaining queue in order:** start with discovery details (item 44), then Low Stimulation, distinct Today layouts, Break reorganization, Focus Rescue, session-note reader, Live Activity folder decision, storage recovery, and launch/icon work.
3. **Use real-device validation for the non-static accessibility/interaction claims:** VoiceOver, haptics, audio, motion, notification response, NFC, and hardware-only capabilities.
4. **Only after Apple readiness is available:** consider production StoreKit, Family Controls, alarm, NFC writing, Universal Links, and widget/Live Activity provisioning.

### Picking this up

#### Remaining 14 queue items, in order

1. **22** — Short recordings/real-device validation for start focus, completion, room-object tap, and task swipe. Deferred because this repository has no UI gesture/video harness.
2. **36** — Bounded empty/sparse/full/error matrix. Deferred because a literal every-screen × four-state matrix would create invented states and exceed capture capacity.
3. **37** — Honest audio/NFC/Family Controls/storage error states. **Implemented, visually unproven** for closeout; candidate proof run `36517157860`.
4. **38** — Three-screen first run and post-first-session personalization. **Implemented, visually unproven** for closeout; candidate runs `36513443531` and `36513475265`.
5. **43** — Object long-press second layer. **Implemented, visually unproven** at `7308673`; candidate run `36644288375`.
6. **44** — Discovery set: random book passage, lamp dim-until-relaunch, wall clock, rain volume intensity, empty mug, seventh-day bird; document only, no surfaced UI.
7. **45** — Low Stimulation Appearance toggle.
8. **46** — Genuinely distinct Today morning/evening layouts.
9. **47** — Reorganize Break shelf by present need.
10. **48** — Real two-minute Focus Rescue flow or remove timer-like label.
11. **49** — Browsable saved-session note reader.
12. **50** — Remove or document `StillLiveActivity/`.
13. **51** — Cross-store consistency, storage-degraded retry/export path.
14. **52** — Launch screen and complete app/alternate icon set.

#### CI artifact credential and evidence recovery

- The sandbox GitHub CLI credential previously expired while resolving Actions artifact redirect URLs. The user reauthenticated, after which `gh` artifact access worked again. If a future sandbox cannot obtain a signed artifact URL, restore GitHub authentication/connector access first; do not infer visual acceptance from workflow success.
- Use the existing `/tmp/extract_remote_ci_artifact.py` range extractor with a signed artifact URL and archive size when `gh run download` stalls. Do not delete the compact matrix or scheduled/manual full gallery.
- Current unreviewed candidate artifacts: item 37 run `36517157860` / artifact `11012104970`; item 38 compact run `36513443531` and full gallery run `36513475265` / artifact `11010818054`; item 43 final run `36644288375` / compact artifact `11068714952` and full gallery artifact `11069215931`.

#### Real-device boundary

Haptics, motion quality, and **VoiceOver spoken output** remain unverified by design. They require a real iPhone plus Accessibility Inspector/UI-test/manual validation; static simulator screenshots are not evidence for those behaviors.

---

## 11. Source index for an independent reviewer

All paths are relative to `Still-upload/` at implementation snapshot `7308673`.

| Subject | Primary sources |
|---|---|
| App/router/state | `Still/App/StillApp.swift`, `Still/App/RootView.swift`, `Still/App/AppState.swift`, `Still/App/AppRouter.swift`, `Still/App/DependencyContainer*.swift` |
| Today/Focus/Break/Me | `Still/Features/Today/`, `Still/Features/Focus/`, `Still/Features/Break/`, `Still/Features/Me/` |
| Rooms/cat/progression | `Still/DesignSystem/RoomHeroView.swift`, `Still/Domain/RoomAmbientState.swift`, `RoomSessionState.swift`, `RoomSecondLayer.swift`, `CatCompanion.swift`, `RoomObject.swift` |
| Accessibility | `Still/DesignSystem/StillMotion.swift`, `StillAccessibilityVisuals.swift`, `StillComponents.swift`, `StillTests/` accessibility/room suites |
| Capability boundaries | `Still/Features/Me/FocusCardView.swift`, `BlockingSetupView.swift`, `MorningStartView.swift`, `Still/Services/Purchases/`, `ScreenTime/`, `NFC/`, `WakeUp/` |
| Proof configuration | `.github/workflows/ios.yml`, `.github/scripts/capture-full-gallery.sh`, `Still/App/DemoLaunch.swift`, `REDESIGN_NOTES.md` |
| Sprint requirements | `/home/ubuntu/upload/STILL_SPRINT_QUEUE.md`, `/home/ubuntu/upload/Pasted_content_05.txt`, `/home/ubuntu/upload/STILL_P0_TRUTH_PASS(1).md` |

> **Final assessment:** The implementation branch is safely preserved on GitHub and contains a substantial local-first application. It must not be described as fully visually accepted or commercially ready until the named artifact frames above are reviewed and the external Apple/device work is completed.
