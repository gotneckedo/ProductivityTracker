# Still — Current Build State

**Repository:** `gotneckedo/ProductivityTracker`
**Branch reviewed:** `redesign`
**Application snapshot:** `42ec8df` (the application source snapshot; the report below is an audit artifact)
**PR:** [#1 — Redesign Still with a room-first focus flow](https://github.com/gotneckedo/ProductivityTracker/pull/1) — open, not merged
**Report date:** 27 September 2026
**Evidence standard:** source, checked-in configuration, the named CI run/artifact, and the explicit limitations below. No feature is described as visually accepted merely because code exists.

> **Headline:** Still is a substantial, local-first iPhone focus app with a working four-tab shell, local task/focus/break/room systems, an authored pixel-room renderer, timer modes, a local reading/doodle/puzzle shelf, and extensive configuration. The main present risks are not empty screens: they are **release truthfulness, feature discoverability, visual-proof coverage, and external Apple/App Store readiness**. In particular, release Still+ purchasing is intentionally unavailable, real app blocking is off, Morning Start is a local notification rather than an alarm, and some surfaced controls describe future/DEBUG-only behavior too optimistically.

---

## 1. How to read this report

### 1.1 Status terms

| Term | Meaning used here |
|---|---|
| **Implemented** | A source-connected production surface/behavior exists in the current app code. It is not automatically a shipping or visual-acceptance claim. |
| **Partial** | Useful implementation exists, but a material route, release dependency, complete behavior, or requirement is absent. |
| **Stub / preview** | The UI/model exists only for DEBUG, CI, local StoreKit, in-memory preview, or an explicitly non-production boundary. |
| **Not proved** | No named/reviewed screenshot, recording, or targeted UI evidence establishes the stated visual/interaction claim. |
| **Externally blocked** | Code alone cannot finish it; it requires Apple approval, paid signing, App Store Connect, hardware, a real domain, content review, or other outside work. |

### 1.2 Evidence actually checked

| Evidence | What it establishes | Important limit |
|---|---|---|
| `swift test` on the application snapshot | **222 tests passed, 0 failures** under Swift 6.1 on Ubuntu 24.04. | The Swift package deliberately excludes the SwiftUI app/root/live-service integration and cannot prove iPhone layout or Apple-framework behavior. |
| [CI run 36291223612](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36291223612) | Passed macOS simulator build/tests and produced the `still-screenshots` artifact at UI head `036bfb0`. The workflow is `macos-15`, selects a current non-SE iPhone Pro when available, uses latest stable Xcode (recorded as Xcode 26.3 / arm64 in the run), and captures 72 files. | One simulator size and static captures do not prove all Dynamic Type, VoiceOver, physical-device, entitlement, purchase, notification, or hardware paths. |
| Reviewed named artifact files | The final named room, light-theme, clearance, collectible, focus-helper, scene, cat, active-focus, and completion captures are documented in `REDESIGN_NOTES.md`. | Named evidence is uneven: several screens have a generic CI route but no reviewed/named final proof. |
| Current source and configuration | Current routes, flags, dependency wiring, copy, data model, and release/DEBUG gates. | Source cannot prove that iOS, App Store Connect, signing, StoreKit, notifications, NFC, or Family Controls behaves as intended on an actual phone. |
| User-supplied Focus screenshot in this task | It visibly shows the Focus composition with the room and Start card appearing before the `Good morning.` greeting. | It is useful current visual evidence but is not a versioned CI proof file. Source order independently corroborates the hierarchy issue. |

### 1.3 Screenshot-proof rule: current state

The governing plan requires a **named CI screenshot for each visual claim**. The strongest current evidence is the artifact from run `36291223612`; it is the basis for the named files below. The report therefore distinguishes “implemented” from “visually proved.”

| Evidence area | Named/reviewed proof currently recorded | What it supports | What it does **not** close |
|---|---|---|---|
| Supplied room art | `05-focus-room.png`, `58-room-library.png`, `59-room-train.png`, `60-room-city.png`, `61-room-autumn.png`, `62-room-snow.png`, `63-room-spring.png`, `64-room-sleep.png` | Eight full-size room compositions and the square sprite contract. | Sleep room is art review only, not alarm functionality. |
| Clean room / objects | `proof-room-art-unoccluded.png`, `proof-room-collectible-anchors.png` | No persistent overlay labels obscure art; four early objects have corrected anchors. | Every object/room combination, touch discovery, VoiceOver traversal, and object fallback. |
| Focus / completion | `05-focus-room.png`, `08-active.png`, `09-complete.png`, `proof-focus-helper-clean.png` | Art-first room, active focus, completion, removal of the rejected Focus helper sentence. | Correct Focus greeting placement and every Focus-card state. |
| Light hierarchy | `proof-light-theme.png` | 9 AM light theme field/surface/type hierarchy. | Full dark-mode, large-text, and accessibility visual acceptance. |
| Bottom clearance | `proof-today-bottom-clear.png`, `proof-tasks-bottom-clear.png`, `proof-sudoku-bottom-clear.png`, `proof-me-bottom-clear.png` | Four stated final scroll positions. | Final named proof for Break, Scenes, Focus Card, Short Read, and Short Read top clearance. |
| Catalog / Scenes | `38-scenes-all.png`, `39-scenes-extra.png`, `06-sprite-contact-sheet.png`, `33-sprite-contact-sheet-bottom.png` | Core/extra scene layout and supplied asset review. | Paid-room purchase/unlock in a release build. |
| Timer | `04-active.png` plus timer calculation tests | Deterministic 9:41 fixture shows a 9:59 AM end time for the remaining 18 minutes. | Locale/layout behavior at all Dynamic Type sizes. |

---

## 2. Current architecture and data ownership

Still is a native SwiftUI iOS app with no backend/account requirement in the current source. `StillApp` creates an observable `AppState` from `DependencyContainer.live(flags: .current)`. `RootView` then chooses onboarding or the tab shell; `AppRouter` owns tab stacks, sheets, and the session-completion cover.

```text
StillApp
  └─ AppState(DependencyContainer.live)
       ├─ AppRouter → tab selection, stacks, sheets, completion cover
       ├─ observable display mirrors → SwiftUI feature views
       └─ action forwarding → controller/service → repository → reload

RootView
  ├─ Onboarding (until completed)
  └─ Four fixed tabs: Today · Focus · Break · Me
       ├─ independent NavigationStacks
       ├─ global sheet routing
       └─ session-completion full-screen cover
```

### 2.1 Persistence and privacy boundaries

| Data | Local storage path | Current behavior / boundary |
|---|---|---|
| Sessions, tasks, activity usages/notes, journal, habits, doodles, puzzle state, reading progress, room collection | SwiftData-backed generic `LocalRecord` store, JSON payloads | On-device. Each repository mutation explicitly saves. If SwiftData cannot open, record-backed data falls back to memory and the app shows a notice; `UserDefaults` preferences can still persist. |
| Preferences and focus presets | `UserDefaults` JSON (`still.preferences.v1`, `still.presets.v1`) | Tolerant migrations; preferences schema is version 5. |
| Imported EPUBs | App Support `Books/` directory plus local `library.json` | Imported files remain on the device; parsed-book cache is memory-only. |
| Widget summary | App Group `UserDefaults` | The summary widget/Live Activity boundary needs paid-account App Group provisioning validation. |
| Event logging | Bounded, local-only tracker | No analytics destination is registered. |

**Architecture strengths:** local first, concrete controller boundaries, deterministic preview/demo states, local persistence, and graceful no-op/preview services rather than invented cloud behavior.

**Architecture risks:**

1. `AppState.reload()` fetches/recomputes many domains after most mutations; it will become a broad performance and coupling point as history grows.
2. Core records, settings, books, and widget state are separate stores with no cross-store transaction; multi-step reset/import failures can partially succeed.
3. Decode/open failure tends to display default/empty state rather than offering export/recovery diagnostics.
4. A missing room base sprite falls back to code art, but a missing object sprite on an otherwise valid sprite room is silently omitted.
5. Scene/object anchor/scale data lives in several switch-based maps, so replacing art requires carefully synchronized changes.
6. `StillLiveActivity/` is present in the repository but is not evidenced as an Xcode target; `StillWidgets/` is the embedded extension target. This duplication should be resolved before extension work expands.
7. README/product documentation has drifted from code (for example room unlock thresholds and bundled-book wording); customer-facing docs must be treated as a release artifact and reviewed with code.

**Primary source map:** `Still/App/StillApp.swift`, `Still/App/AppState.swift`, `Still/App/DependencyContainer.swift`, `Still/App/RootView.swift`, `Still/Domain/Navigation/AppRoute.swift`, `Still/Data/Persistence/`, `Still/Services/`, and `Still/DesignSystem/RoomHeroView.swift`.

---

## 3. Screen, route, sheet, and activity inventory

This inventory is intentionally exhaustive at the level of roots, pushed screens, sheets, activity modes, DEBUG demo routes, and preview-only surfaces. A status of **Implemented** means a connected production UI exists in source; it does not override the proof table above.

### 3.1 App shell and primary tabs

| Surface | Entry / route | Source state | Notes and gaps |
|---|---|---|---|
| Launch / onboarding gate | `StillApp` → `RootView` | **Implemented** | Launch bootstraps local state and handles `still://` URLs. Onboarding is shown until completion. |
| Onboarding | first-launch branch | **Implemented** | Privacy, goal, break preference, and look/palette flow; answers persist locally and are editable later. |
| Floating tab shell | `MainTabView` | **Implemented** | Exactly four visible tabs: Today, Focus, Break, Me. Bar hides during an active session. |
| Today | `AppTab.today` | **Implemented** | Greeting, next task/action, focus start, decision aid, selected breaks, timeline, reflection/mood, and room moment. Morning/evening **workflows** remain partial—current code changes greeting/appearance, not planning/shutdown flows. |
| Focus home | `AppTab.focus` | **Implemented** | Room, task/options/rooms routes, Start action, and accessible invisible hotspots. See greeting hierarchy defect in §7. |
| Active Focus | Focus tab when session is active | **Implemented** | Countdown/count-up/Pomodoro state, pause/resume, phase actions, sound mute, +5 where valid, note, early end, Focus Rescue card. |
| Break shelf | `AppTab.breakShelf` | **Implemented / partial catalog** | Finite ranked shelf, category filters, and activity routing. Seven activities are on the first shelf; three catalogued activities are reachable through suggestions/container but not the primary shelf. |
| Me | `AppTab.me` | **Implemented** | Personal summary, stats, scenes, task/focus controls, appearance, Morning Start, Focus Card, Still+, preferences, and reset. |
| Global notice banner | `appState.notice` | **Implemented** | Dismissible, auto-dismisses after four seconds. |

### 3.2 Sheets, full-screen presentation, and pushed screens

| Screen / sheet | Route / trigger | Status | Exact limitation where applicable |
|---|---|---|---|
| Focus configuration | `.focusConfiguration` | **Implemented** | Edits selected preset, timer, scene, sound, and nested destinations. |
| Tasks | `.tasks` | **Implemented** | Type/select/complete/delete tasks; details, day timeline, and voice capture sheet. |
| Task detail | local `navigationDestination` | **Implemented** | Title, subject, due/schedule, duration, day period, repeat, and steps persist locally. |
| Day timeline | `.dayTimeline` / Tasks link | **Implemented** | Week strip, task groups, sessions, habits, and conditional Apple Calendar settings. |
| Next Step guide | `.nextStep` | **Implemented** | Local decision aid routes toward focus, shelf, stretch, or do-nothing. |
| Session complete | `.sessionComplete(UUID)` full-screen cover | **Implemented** | Persisted completion return path, break suggestions, optional task completion, return to Focus. |
| Active-session note | local sheet | **Partial** | Capture/persistence works with a 500-character limit; no dedicated later reader/history for saved session notes was found. |
| Voice task capture | Tasks sheet | **Implemented / conditional** | Uses Speech only where available/authorized; typed capture remains fallback. |
| Journal | `.journal` sheet | **Partial / disconnected** | Full journal/habits UI exists, but no normal production in-app call to `.journal` was found; direct audited route use is DEBUG launcher. |
| Habits standalone | `.habits` intended route | **Partial / routing defect** | `HabitsScreen` exists, but resolver returns Today with an empty stack; current flag also hides the Me link. |
| Presets | `.presets` | **Implemented** | Built-in selection and custom duplicate/create/rename/delete locally. Initial cap is 10 total presets (six built-ins leaves four custom slots), not unlimited. |
| Room collection / “Your things” | `.roomCollection` | **Implemented** | Unlock acknowledgement, placement/removal, and slot validation for 20 objects. |
| Scene collection | `.sceneCollection` | **Partial** | Four earned free scene choices work. Three extra rooms display as Still+ locked; release cannot acquire entitlement and Focus session resolution currently receives only free `SceneCatalog.all`, so paid selection falls back to Rainy Bedroom. |
| Focus Card setup | `.nfcSetup` | **Partial** | `still://` routing and simulator are source-connected; UI itself is locked behind Still+, which cannot be purchased in current release; in-app writer is conditional. |
| Still+ | `.stillPlus` | **Stub in release** | UI and StoreKit boundary exist, but current release uses `NoPurchaseService`; products/purchase/restore are unavailable. |
| Get a card | `.getFocusCard` | **DEBUG preview stub** | Design-only; no cart, price, payment, fulfillment, or live storefront. Flag is false in release. |
| Morning Start | `.morningStart` | **Partial** | Persists plan, requests notification permission in context, schedules local notifications. It is not an alarm and release Focus Card stop mode does not execute. |
| Wake-up hand-off | Wake-up preview flag | **DEBUG preview stub** | Simulates opening and card wait without controlling a system alarm. |
| Blocking setup | `.blockingSetup` | **Partial / release hidden** | Conditional real service boundary; release flag is off and live release uses non-shielding mock. |
| Calendar settings | `.calendarSettings` | **Partial / disconnected** | EventKit read-only controls exist, but no normal production entry point was found; direct Google remains sample-only DEBUG data. |
| Doodle gallery | `.doodleGallery` | **Implemented** | Empty and grid/list behavior, detail sheet, and delete action. Visual state coverage is incomplete. |
| Onboarding preference editors | three Me routes | **Implemented** | Goal, break appeal, look/icon preference may be revisited. |
| Sprite contact sheet / Sleep room | `.spriteContactSheet` | **DEBUG review stub** | Asset-review screen only; sleep-room screen explicitly neither arms nor simulates alarm behavior. |

### 3.3 Break shelf and every catalogued activity

| Activity | Primary shelf? | Source status | What currently happens |
|---|---:|---|---|
| Activity shell / finish panel | n/a | **Implemented** | Starts/finishes local activity usage; return choices do not shame unfinished puzzles. |
| Sudoku | Yes | **Implemented** | 6×6 board, six 2×3 boxes, conflict feedback, undo/erase/reset, persisted moves, solves only when valid. |
| Picross | Yes | **Implemented** | Responsive 5×5 fill/cross board, save/reset/solved detection. |
| Word Search | No | **Partial discovery** | Fully implemented container/path and persisted selection, but not on primary shelf. |
| Short Read | Yes | **Implemented functionally / visual rule open** | Bundled reading, imported EPUBs, saved sitting progress, restart/end. Selection still uses one card per item rather than the proposed shared inset-row treatment. |
| Creative Prompt | No | **Partial discovery** | Daily prompt and bounded local autosave; not on primary shelf. |
| Pixel Doodle | Yes | **Implemented** | 16×16 pen/fill/eraser canvas, local autosave/gallery/delete. |
| Brain Dump | No | **Partial discovery** | Local autosaving note and recent-note disclosure; not on primary shelf. |
| Guided Stretch | Yes | **Implemented** | Four-step bounded routine with per-step timer. |
| Box Breathing | Yes | **Implemented** | Two-minute pattern, reduced-motion alternative, accessible state, automatic finish. |
| Do Nothing | Yes | **Implemented** | One-minute fixed rest with automatic finish. |

### 3.4 DEBUG demo and Xcode-preview surfaces

The `-still-demo` launcher is compiled only under `#if DEBUG`; it is a deterministic CI/review tool, never a release entry point. Current demo tokens cover onboarding, Today/light Today, setup, populated home, Focus room, seven room variants, placed collectibles, five cat states, contact sheet, calm, active/complete focus, Break, Sudoku/Word Search/Picross/narrow Picross/breathing/read/doodle/gallery, Journal, tasks/timeline/presets, Me/Scenes, Focus Card, Morning Start, Calendar Settings, and Get a Card.

There are also 26 Xcode `#Preview` blocks, including Today, Tasks, Task Detail, Day Timeline, Onboarding, Box Breathing, Short Read, Your Things, Sudoku, Picross, Session Complete, Focus Home, Large Text Focus Home, Presets, Active Focus, Break Shelf, Pixel Doodle, Journal, Wake Up, Still+, empty/populated Me, Get a Card, Focus Card, Calendar Settings, and Scenes. **All are preview stubs as launch surfaces** even when their underlying production view is implemented.

---

## 4. Feature-by-feature current state

### 4.1 Today, tasks, routines, and personal data

| Area | Status | Current behavior | Missing / conflicting requirement |
|---|---|---|---|
| Today action-first start | **Implemented** | Time-aware greeting, next focus task, Just Start/Next Step, break links, timeline, reflection, room link. | The Focus screenshot/source show greeting placed below room/Start rather than acting as a leading hierarchy; Today has no separate morning plan/evening shutdown flow. |
| Tasks | **Implemented** | Local typed tasks; selection, completion, delete, steps, subjects, due/scheduled date/time, planned duration, recurrence, timeline. | No global task-count limit was found. |
| Subjects | **Implemented** | First-class subjects with curated colors flow to task/timeline/focus/stat presentation. | None found in static route audit. |
| One-line reflection / mood | **Implemented** | Today saves current day’s local journal line and mood. | It does not replace a discoverable full Journal surface. |
| Full Journal / habits | **Partial** | Full one-line journal, moods, earlier entries, habits, rename/archive/actions, local persistence. | Main Journal/creation interface is effectively disconnected; habits route is mis-resolved. |
| History / statistics | **Partial** | Me has range metrics, chart, month calendar, activity counts, timeline session context. | No dedicated browsable per-session history/note reader. The agreed free “full History list and lifetime totals” is therefore not yet shown as a complete user-facing flow. |
| Routines / reminders / phone-free workflow | **Partial / not established** | Morning Start plan and focus setup exist. | The full Phase-2 routine-template/reminder/phone-free data/workflow scope is not evidenced as complete. |

### 4.2 Focus timers, completion, rescue, and sound

| Area | Status | Current behavior | Boundary |
|---|---|---|---|
| Countdown / count-up / Pomodoro | **Implemented** | 5–180 minute countdown, open count-up, Pomodoro focus/break cycles; pause/resume/skip/start-next; date-based recovery. | Count-up under five minutes is abandoned rather than completed; +5 only affects countdown focus. |
| Active Focus controls | **Implemented** | Time/progress, subject-or-Focus overline, mute, notes, pause/resume, early end confirmation, phase actions. | UI proof has not covered every size/locale. |
| Completion | **Implemented** | Persists completed session, task session count, transition ritual, finite break suggestions, return paths. | No full historical session note reader. |
| Focus Rescue | **Partial** | Paused session shows a `FOCUS RESCUE · 2 MINUTES` guidance card with Resume. | “2 minutes” is prose; no separate rescue timer, state machine, tracking, or automatic end action. |
| Soundscapes / saved mixes | **Partial** | 12 modelled sources, independent levels, master volume, local custom mix storage, fade-capable AVFoundation player. | Only **four** bundled original procedural placeholder loops exist: rain, café, fireplace, waves. Eight displayed layers lack files; no source-level Still+ gate was found despite product wording promising additional layers. |

### 4.3 Rooms, collectibles, and cat

| Area | Status | Current behavior | Boundary |
|---|---|---|---|
| Room renderer | **Implemented** | Sprite-first 512×512 authored assets with nearest-neighbor scaling; code-drawn fallback if base image missing; per-room hotspot/cat/object anchor data. | Missing object sprite on a valid base room silently omits the object rather than falling back. |
| Core free rooms | **Implemented** | Rainy Bedroom immediately; Library Light after 2 completed sessions; Train Window after 6; Night City after 12. | README threshold wording is stale and should be reconciled. |
| Extra rooms | **Partial** | Autumn Window, Snow Day, Spring Rain are permanent Still+ UI records; no seasonal/expiry framing. | Current release cannot acquire Still+; Focus flow/catalog injection excludes extras, so selection cannot complete an active-session room path. |
| Collection | **Implemented** | 20 permanent local unlockable objects based on focus, activity, reading, doodle, and history; owned items place/remove per scene/slot. | Provenance/release asset checks remain ownership/release tasks. |
| Cat | **Implemented** | Idle/morning/focus/sleeping/break/complete sprite states, tap reaction, optional 18-character local name, ginger free, three cosmetic alternate coats gated by Still+. | Paid coat gate is unfulfillable in current release because no real purchase service is wired. It remains ambient—not a care/streak mechanic. |

### 4.4 Onboarding, appearance, widgets, calendar, and accessibility

| Area | Status | Current behavior | Boundary |
|---|---|---|---|
| Onboarding | **Implemented** | Privacy-first, locally stored answers for goal/break/look; alternate-icon requests have fallback. | Product privacy claim is source-supported, not an independent network audit. |
| Appearance | **Implemented** | Mint/Peach/Sky palette, icon-request boundary, Scene/Calm rendering, animation intensity, cat/sound defaults. | No manual light/dark selector; system color scheme is used. |
| Apple Calendar | **Implemented / conditional** | Read-only EventKit adapter for phone-configured calendars, consent in context. | Calendar Settings lacks a discovered normal entry route; direct Google is not real OAuth. |
| Google Calendar | **DEBUG sample stub** | Sample adapter has no login/network call. | Needs Cloud/OAuth/privacy/Keychain/revocation work if ever adopted. |
| Widgets / Live Activity | **Implemented boundary / external validation** | Widget extension reads App Group snapshot; ActivityKit updater is conditional. | Needs paid signing/App Group provisioning and real Dynamic Island-capable hardware test. Separate root `StillLiveActivity/` folder is not target-proven. |
| Voice capture | **Implemented / conditional** | Speech framework path with confirmation before saving. | Permission/device testing needed; simulator is not sufficient. |
| Accessibility | **Partial evidence** | Labels, selected traits, 44pt targets, Reduced Motion branches, Dynamic Type scene layout, timer/puzzle/habit/chart values appear extensively in source. | No comprehensive VoiceOver, Switch Control, Voice Control, largest Dynamic Type/Bold Text, contrast, or hardware validation. |

---

## 5. Capability truth table — shipping configuration versus DEBUG/CI

| Capability | Release/current code path | DEBUG/CI / local-test path | What must happen before any “shipping” claim |
|---|---|---|---|
| Still+ subscription | `NoPurchaseService`; no products, no purchase, no restore, no entitlement. | Local `StoreKitPurchaseService` and memory test service can show products/entitlement under DEBUG preview. | Wire reviewed release StoreKit 2 service; create App Store Connect products; configure subscriptions, legal copy, prices/localizations; sandbox + physical-device purchase/restore; App Review metadata. |
| Extra rooms / alternate coats | UI locks are visible but cannot be unlocked in release. Extra scene flow also falls back to free catalog in Focus service. | In-memory entitlement can demonstrate art in CI. | Finish entitlement/catalog propagation and real purchase setup; keep four earned core rooms free. |
| Focus Card deep link | `still://start-focus?preset=…` parser/on-open-URL route exists. | Simulator exercises app-side route. | Test real tags on phone; clarify premium framing versus compatible own tags; do not promise fulfillment. |
| In-app NFC writing | Not established in checked-in build. | Conditional source only with `canImport(CoreNFC) && os(iOS) && STILL_CORENFC`. | Paid signing, NFC Tag Reading/NDEF capability, correct build flag, compatible writable tag, physical iPhone tests. |
| Physical/branded card | No release shop or ordering/fulfillment. | Preview-only artwork and `.example` URL. | Separate reviewed fulfillment/storefront plan; real owned universal-link domain; AASA/Associated Domains; device validation. |
| Morning Start | Repeating local notifications after permission. | DEBUG state can simulate opening/card wait. | Preserve notification honesty; add actual response handling if session hand-off is promised. |
| Alarm / card alarm | **Not implemented.** No release armable alarm/ringing flow. | Preview simulation explicitly does not control system alarm; sleep room is art review only. | If adopted: real supported Apple framework/capability, hardware test, system-owned stop controls, and product-safe text. User-installable/TestFlight builds must remain information/setup only per product decision. |
| App limits / shielding | Release flag false; `MockFocusBlockingService` never shields. | Real Family Controls service exists behind flag/platform capability but preview does not enable it by default. | Apple Family Controls Distribution entitlement; app/extension capability; DeviceActivity monitor extension; real selection/authorization/hardware validation. |
| Scheduled blocking | No release entry; background start is not supported. | State machine can refresh only on app bootstrap/foreground. | DeviceActivity schedule/monitor extension before claiming start/stop behavior when app is closed. |
| Apple Calendar | Conditional read-only EventKit. | Same where framework/permission is available. | Normal entry routing, permission/device review. |
| Google Calendar | No production OAuth. | DEBUG sample only. | Entire OAuth/privacy/Keychain lifecycle if product scope expands. |

---

## 6. Exact customer-facing capability copy and its current meaning

This ledger deliberately quotes all capability-related rendered literals found in the current audit scope. It is intended to prevent an implementation or marketing claim from outrunning the effective release dependency.

### 6.1 Blocking, shielding, and limits

| Exact on-screen copy | Current meaning / action | Truthfulness assessment |
|---|---|---|
| `Blocking` / `No blocking` | Focus-home pill reflects a preset’s blocker **intent**; tapping opens Session Options. Active Focus shows `No blocking` when service says it is not shielding. | `Blocking` can overstate release state: release mock never shields anything. |
| `Blocking setup is ready` | Status title for mock/simulation capability. | Needs the adjacent detail to be understood; alone can sound operational. |
| `Presets remember what you'd like to block. App shielding arrives in a later version, after Apple approves Screen Time access. Nothing is blocked today.` | Informational detail in Me/Focus Card/setup mock state. | Accurate release disclosure. |
| `Blocking is off for this session. The timer is still running.` | Notice after an end-blocking action. | Accurate timer claim; release mock did not actually lift a shield. |
| `Blocking and schedule` | Flag-gated Me entry. | Not normally release-visible because `appBlocking` is false. |
| `Off`, `Chosen apps`, `Apps + sites`, `Choose apps` | Flag-gated Session Options selection labels. | Desired policy only; actual shielding additionally requires entitlement, authorization, and selection. |
| `End blocking` | Visible only when `isShieldingApps` is true. | Conditional; not normal release state. |
| `End blocking for this session?` / `End blocking now` / `Keep blocking` / `Your apps open again right away. The session keeps going.` | Confirmation action clears real Managed Settings only when real service is active. | Reasonable conditional UI; not proof that a mock ended anything. |
| `App blocking` | Blocking Setup title. | Flag-gated/non-release normal path. |
| `Choose a few apps that can wait. The shield stays kind: focus on your task, or take a little break.` | Setup explanation. | Overstates behavior if shown with mock; later mock detail corrects it. |
| `What happens` / `Start time` / `Your schedule begins` / `Gentle shield` / `Chosen apps can wait` / `Card tap` / `Blocking ends` / `Focus on your task, or take a little break. Still never locks you in.` | Diagram describing planned schedule/card behavior. | Conditional/incomplete: current schedule refreshes only foreground/bootstrap; card end does not necessarily start a preset. |
| `This button always works. It does not end a focus timer.` | Manual override caption. | Timer portion is source-supported; “always” cannot guarantee OS/service success. |
| `Start at a time` / `Start` / `Preset` | Persisted schedule controls. | State can be stored, but it is not a closed-app scheduler. |
| `Optional. When it is off, nothing starts in the background.` | Disabled schedule detail. | Accurate. |
| `At that time, iOS shields the apps in this preset. Blocking continues until you tap your Focus Card or choose End blocking now.` | Authorized schedule detail. | Material overstatement today: no DeviceActivity extension; app-closed scheduled start is not implemented. |
| `The time and preset are saved, but this build cannot shield apps. Nothing is blocked until Screen Time access is available.` | Mock/non-authorized schedule detail. | Accurate. |
| `The schedule is active. Tap your Focus Card to end it, or use End blocking now below.` | Active real-shield schedule detail. | Conditional; card ends scheduled blocking then returns before starting preset. |
| `The schedule is in preview. A card tap ends the preview; no apps are actually shielded in this build.` | Active mock schedule detail. | Accurate preview disclosure. |
| `Preview` / VoiceOver `Preview feature` | Shared preview badge. | Correct marker; it does not itself make unavailable capability shippable. |
| `Screen Time permission` / `iOS asks once. Still never sees which apps you use; the choices stay on this device.` / `Asking…` / `Allow Screen Time access` | Conditional Family Controls setup. | Conditional source path; privacy statement matches local token storage but requires framework/OS validation. |
| `Screen Time permission needed` / `Still needs Screen Time permission before it can shield apps.` | Conditional non-authorized real-service status. | Accurate conditional wording. |
| `Apps are shielded` / `Blocking is available` / `Shielding follows your preset while a session runs.` | Conditional authorized real-service status. | Must not be used as a release proof. |

### 6.2 Morning Start, wake-up, and alarm language

| Exact on-screen / local-notification copy | Current meaning / action | Truthfulness assessment |
|---|---|---|
| `Morning Start` | Me row and setup title. | Release feature is notification planning, not an alarm. |
| `A quiet nudge at the start of the day: pick one task, and a session is ready when you are.` | Header. | “Session is ready” hand-off is not proven: notification URL is placed in `userInfo`, but no response delegate was found. |
| `Time`, `Days`, `Preset to queue` | Plan fields. | Persisted and notification scheduling is source-connected. |
| `Stop with` / `Button` / `Focus Card` | Choice shown in release UI. | Material mismatch: release only stores/schedules notification plan; Focus Card wait behavior is DEBUG preview only. |
| `When Still opens, the queued session is ready right away.` | Button stop-method explanation. | Informational only; notification-to-app hand-off is not source-proven. |
| `After Still opens, the queued session and morning checklist wait for a card tap. The system alarm can still be dismissed with its own controls.` | Focus Card stop-method explanation. | Material release overstatement: card wait is preview-only, no morning checklist was found, and no release alarm exists. |
| `Weekdays at <time>` / `Weekends at <time>` / `Every day at <time>` / `<days> at <time>` / `No days chosen` | Summary of stored plan. | Accurate representation of saved fields, not delivery confirmation. |
| `On iOS 17–25, this is a local notification. It follows silent mode and Focus and can be dismissed normally. AlarmKit is the planned real-alarm backend.` | Current delivery note. | Accurate: live factory returns notification fallback. |
| `The system owns the alarm controls. Focus Card mode can make Still wait after opening, but it cannot prevent the system alarm from being dismissed.` | Future AlarmKit branch. | Cautious but currently unreachable through live factory. |
| `Notifications are off, so your before-school reminder can't appear. You can turn them on in Settings.` | Notification-permission notice. | Accurate for notification delivery. |
| Notification: `Ready for the school day?` / `Choose one homework or study task. Your focus setup is ready.` | Repeating local notification per selected weekday. | Notification is scheduled with default sound; app-side tap hand-off is not proved. |
| DEBUG: `Wake up`, `Wake up plan`, `Try the hand-off`, `Local simulation only; it does not start or dismiss a system alarm.`, `Simulate Still opening`, `Simulate Focus Card tap` | Preview simulation controls. | Correctly DEBUG/Preview only. |
| DEBUG notices: `Preview: Still opened. The queued session is waiting for a simulated card tap.`, `Preview: Still opened with the queued session ready.`, `Preview card accepted. The queued session is ready; no system alarm was controlled.` | In-memory preview notices. | Correctly disclaims system-alarm control. |
| Sleep-room review: `Sleep room` / `Reserved art for the later DEBUG-only alarm-preview state. This screen does not arm or simulate an alarm.` | DEBUG asset review screen. | Accurate; art is not an alarm feature. |

### 6.3 Focus Card / NFC language

| Exact on-screen copy | Current meaning / action | Truthfulness assessment |
|---|---|---|
| `Set up a Focus Card` / `NFC` | Me row opens card setup. | Release-accessible route. |
| `Focus Card` | Screen heading. | Release-accessible heading, but main setup content is gated by Still+. |
| `A Focus Card is any writable NFC tag programmed with a Still link. Tap it with your iPhone to start a preset.` | Guide summary. | App-side `still://` route is real; physical tag/iOS delivery needs real-phone validation. |
| `Focus Card is a Still+ perk` | Non-entitled card screen. | Product-positioning conflict: own compatible tag is otherwise described as usable; current release cannot buy entitlement. |
| `Still+ supports optional physical card access and permanent extra rooms. Your regular focus timer and every session-earned room stay free.` | Locked-state explanation. | Free-core statement is good; Still+ purchase is not available in release. |
| `Explore Still+` | Routes to Still+ screen. | Opens a screen that truthfully reports products unavailable. |
| `Links and simulator` / `Write a link to a tag, or tap Simulate to run the same route here.` | Entitled/test-only setup header. | Simulator proves app parser routing, not hardware scan. |
| `still://start-focus?preset=<preset-id>` / `Copy link` / `Copied` | Copyable tag URL. | Source route is declared and handled. Copying does not write a tag. |
| `Simulate tap` / VoiceOver `Starts <preset name> exactly as a tag with this link would.` | Routes URL through local parser. | Accurate for app-side route; cannot prove OS NFC behavior. It can end scheduled blocking before starting focus in enabled blocking configuration. |
| `Get a writable NFC tag (NTAG213 or similar). A blank tag does nothing on its own.` / `Use an NFC writing app to add a URL record with the link below.` | External-tag setup guide. | Cautious: acknowledges a separate writing app. |
| `Hold the top of your iPhone near the tag. iOS shows a banner; tap it to open Still.` | Physical usage guide. | Hardware/model/settings dependent; guide also tells user to test own device. |
| `Still starts the preset. If a session is already running, it leaves that session alone.` | Route guide. | Supported by app behavior subject to onboarding and URL delivery. |
| `Tag reading depends on your iPhone model and iOS settings, so test your card on your own device. The simulator below runs the same route without a tag.` | Hardware caveat. | Appropriate qualification. |
| `Finish setting up Still, then tap your card again.` / `That link isn't a Still focus link.` / `That preset isn't on this phone, so your usual study session started.` | Runtime notices. | Source-supported fallback/guard behavior. |
| Conditional writer: `Write to a tag`, `<preset> is on your Focus Card.`, `The tag wasn't written. Try holding it still near the top of your iPhone.` | CoreNFC writer branch. | Not established in checked-in release build; requires `STILL_CORENFC` plus capability/device. |
| Conditional reader/session messages: `Hold your iPhone near your Focus Card.`, `Hold your iPhone near the tag to write your Focus Card.`, `More than one tag found. Hold just one tag near your iPhone.`, `Couldn't connect to the tag.`, `Couldn't read the tag.`, `This tag can't store a link.`, `This tag is locked and can't be changed.`, `This tag is too small for the link.`, `Couldn't prepare the link.`, `Writing didn't finish. Try again.`, `Your Focus Card is ready.`, `This tag isn't supported.` | CoreNFC source messages. | Conditional source only; no reviewed release UI call for reader was found. |
| DEBUG branded path: `Get a card`, `Design preview only. There is no ordering or payment in Still.`, `Simulate future universal link` | Preview card artwork/path. | Correctly not a storefront; `.example` host is not a production Universal Link. |
| `A Focus Card is a reusable NFC tag containing one Still link. Tapping it can open a preset; it does not contain your tasks or study history.` | Get-a-Card explanation. | Consistent local-data framing, subject to hardware routing. |
| `This screen is a design preview, not a shop. Still cannot take payment or ship a card. You can set up any compatible writable NFC tag from the Focus Card screen today.` | Preview disclaimer. | Correct. Built-in writing itself remains conditional. |
| `Open placeholder setup page` / `https://links.still.example/focus-card` / `The reserved .example address is intentionally not a live storefront.` | Preview placeholder link. | Correct non-storefront disclosure. |

### 6.4 Still+ and purchase language

| Exact on-screen / local StoreKit copy | Current meaning / action | Truthfulness assessment |
|---|---|---|
| `Still+` / `Optional subscription` | Me row. | Opens subscription UI even though release cannot sell/restore. |
| `STILL+` / `A little more Still` / `Still+ is active` / `Focus, tasks, local data, and every room earned by using Still stay free.` | Still+ header and free-core statement. | Free-core statement is accurate and should remain. |
| `Focus Card access` / `Set up a physical NFC card for a favorite focus preset.` | Benefit description. | Unavailable in release purchase-wise; physical-tag framing needs reconciliation. |
| `More rooms` / `Three permanent original room variations.` | Benefit description. | Permanent wording matches product decision; UI gate exists. |
| `Future subscriber tools` / `New optional tools, without ads, streak pressure, or a feed.` | Benefit description. | Future-facing promise; no concrete extra tools beyond current gates. |
| `Still+ products are not available yet. Add the subscription in App Store Connect before offering it outside the local StoreKit test configuration.` | No-products release branch. | Accurate and important disclosure. |
| `Restore purchases` / `Purchases are not available in this build.` | Release action/error. | Accurate result but avoid presenting a dead-end restoration control without an explanatory disabled state. |
| `You can manage or cancel a subscription in Apple Account settings. No cancellation penalty, no lost focus history.` | Informational. | “No lost focus history” aligns with local data; Apple-account management is hypothetical until live subscription exists. |
| `Still+ room` / `More rooms` / `Still+` / `Still+ is active on this device.` | Extra-room labels. | Locked UI is real; active state only possible in injected/local entitlement today. |
| `Company only — no needs, scores, or streaks. Ginger is free; other coats are Still+.` / VoiceOver `Still+ required` / `Opens Still+ details.` | Cat appearance copy. | Entitlement rule matches source but cannot be fulfilled in release. |
| `Still+ adds the additional cat coats. Ginger stays free.` | Locked-coat notice. | Accurate gate statement; not purchase path. |
| DEBUG/local: `Start Still+ · <display price>` / `Renews monthly unless cancelled in your Apple Account. StoreKit handles payment; Still does not see your payment details.` | Local StoreKit product button/disclosure. | Not a release offer. Copy always says monthly even though yearly product exists; must be plan-specific. |
| DEBUG/local: `Your Still+ StoreKit entitlement is active on this device.`, `Local StoreKit test entitlement is active. No production payment was made.`, `Still+ is active for this preview.`, `Purchase pending.`, `StoreKit says this subscription is pending.` | Local/test outcome messages. | Good local/preview qualification. |
| Local errors: `The local StoreKit product is not loaded.`, `StoreKit could not verify this transaction.`, `StoreKit returned an unknown result.`, `The StoreKit test purchase did not finish.`, `No StoreKit test purchase was found.`, `StoreKit could not restore purchases.`, `That test product is not in the local catalog.`, `No local test purchase is recorded in this preview.` | Test-service outcomes. | Conditional, clearly test/local. |
| Test product metadata: `Still+ Monthly` / `Permanent extra rooms, alternate cat coats, and future subscriber tools. Focus tools stay free.` / `2.99`; `Still+ Yearly` / same benefit text / `24.99` | Local `.storekit` product configuration. | Test configuration only; product review/App Store Connect still needed. |
| Preview catalog: `$2.99/month`, `$24.99/year`, `additional sound layers` | In-memory local catalog. | Pricing is planning direction; `additional sound layers` is not currently entitlement-enforced and should not be marketed until implemented. |

---

## 7. Visual, UX, proof, and product defects that remain open

### P0 — correct before describing this build as visually complete

1. **Focus greeting hierarchy is wrong/unproven.** Source puts the room and overlapping Start card before `Good morning.` / `Ready when you are.`; the supplied screenshot visibly confirms this. Focus also reads wall-clock `.now` rather than the injected demo clock, so the CI greeting is not deterministic. Decide whether Focus should have no greeting (preferred given Today owns day context) or place a deterministic compact greeting above the room; then add a named proof.
2. **Short Read violates the agreed repeated-row surface rule.** `QuietActivityViews.swift` wraps each short item and book in an individual `StillCard`; convert selection/book lists to one inset list with dividers if the Master Plan rule remains binding. Add a named full-shelf screenshot.
3. **Remove or first-play-gate explanatory copy on activities.** The live source still shows `Pick one. Each is a few minutes long, and each one ends.`, `Draw anything. It saves to your gallery in Me as you go.`, gallery explanatory text on non-empty state, and Sudoku instructions. The plan permitted explanatory text only on Today/empty state; current code is not a completed global removal pass.
4. **Proof ledger is incomplete.** Add/review named final screenshots for Break, Scenes, Focus Card, and Short Read bottom clearance, plus Short Read top clearance. Existing shared safe-area code is not enough under the governing proof rule.
5. **Release Still+ locks lead to an unavailable purchase path.** Either hide/disable release monetization surfaces until real StoreKit is configured, or complete release StoreKit/App Store work. Do not call Still+ purchasable in the current build.
6. **Release Morning Start should not offer a functional-looking Focus Card stop method.** Relabel/gate it as unavailable outside DEBUG, or complete a real safe post-notification app hand-off. It is not a system alarm.

### P1 — high-value product and evidence work

7. **Reconnect Journal and Habits.** The data/UI is present but no normal journal route is discovered and `.habits` resolves incorrectly. Decide a quiet secondary entry—likely Today overflow or Me—and fix route resolution.
8. **Complete free History floor.** Product direction says full History list and lifetime totals remain free/non-deletable. Current stats/calendar exist but no discoverable per-session reader (including note) exists.
9. **Make all 10 break activities discoverable.** Word Search, Creative Prompt, and Brain Dump work but are omitted from the first shelf. Either add them, provide an honest `More quiet things` grouping, or record a specific product decision; no activities should be paywalled.
10. **Add Doodle state matrix.** Current CI gallery is one-doodle sparse only. Add deterministic empty, sparse, full/multi-doodle, and error/failure state captures; name retained proofs.
11. **Capture Get a Card.** `DemoLaunch` supports it but CI omits it. Prove secondary emphasis and Preview/no-commerce truthfulness.
12. **Resolve extra-room entitlement end-to-end.** Once StoreKit is real, inject complete scene catalog into Focus/session options; today it falls back to Rainy Bedroom.
13. **Finish soundscape integrity.** Provide original/cleared audio for each displayed active layer or make unavailable layers unselectable/explicitly unavailable. Gate subscriber-only additional layers only if actual entitlement logic exists.
14. **Reconcile copy/documentation.** `FUTURE_CAPABILITIES.md` says StoreKit is “Real now” and refers to seasonal rooms, while release code uses `NoPurchaseService` and product decision says permanent rooms. README also has stale scene thresholds/bundled-book claims. Correct docs before release.
15. **Audit object asset packaging.** Add a build/preflight validation for every scene/object/cat asset and a per-object fallback, not just base-room fallback.

### P2 — after P0/P1

16. **True morning/evening Today modes.** Build persisted morning intention/routine and evening good-thing/shutdown flows before claiming them. Respect the free limit of three routine items and local-only reminders.
17. **Real Focus Rescue or truthful copy.** Either make the two-minute rescue a timed mini-flow or remove the timer-like label.
18. **Accessibility validation.** Test smallest/largest iPhone, largest Dynamic Type/Bold Text, VoiceOver focus order, Switch Control, Voice Control, color contrast, Reduced Motion, and haptics on hardware.
19. **Blocking only after entitlement readiness.** Add Family Controls Distribution approval, DeviceActivity extension, correct app/extension entitlement, closed-app schedule behavior, and physical-device tests before making any shield timing promise.
20. **Alarm only after supported framework/approval/device evidence.** Preserve current rule: user-installable/TestFlight builds never arm/ring an unproven alarm; DEBUG mock state may support visual review only.
21. **NFC actual-device validation.** Separate app-side URL simulation from tag-reading/writing/Universal-Link proof; add capabilities/real domain only when configured.
22. **Release reliability and recovery.** Surface persistent storage-degraded state, offer retry/export path, and design a cross-store consistency plan before sync or major schema change.
23. **Remove/document untargeted Live Activity folder.** Avoid future divergence between `StillLiveActivity/` and embedded `StillWidgets` extension.

---

## 8. External readiness / approval checklist

| Item | Current build state | Owner/action required outside this repository |
|---|---|---|
| Apple Developer membership | Not evidenced as ready. | Adult/company-controlled paid membership; agreements and signing ownership. |
| App Store Connect application | Not evidenced as ready. | Create app record for `com.cocomedia.still`, metadata/privacy/age/export compliance, build records. |
| Still+ live subscription | Local config only; release purchase service is no-op. | Create monthly/yearly products, final pricing/localizations/disclosures, Small Business Program decision, sandbox/physical purchase/restore, App Review subscription metadata. |
| Family Controls | Release off; no entitlement in checked-in file. | Request Distribution entitlement; configure app + DeviceActivity extension; test real shield/schedule/manual exit. |
| App Group / widgets / Live Activity | Code has group IDs and extension. | Paid provisioning and real-device/Dynamic Island test. |
| NFC writing | Conditional source. | NFC Tag Reading/NDEF capability, signing, build flag, writable tag, physical iPhone validation. |
| Universal Links / branded card | `.example` placeholder only. | Own domain, AASA file, Associated Domains entitlement, device test; a separate physical-card fulfillment decision. |
| Alarm | Not implemented. | Only pursue if Apple-supported framework/capability is available; device/system-stop validation; preserve notification fallback. |
| Apple Calendar | Source conditional. | Permission/device acceptance and normal route review. |
| Direct Google Calendar | Sample-only. | Cloud project/OAuth/privacy/Keychain/revocation lifecycle, if it becomes product scope. |
| Ambient audio | Four original procedural placeholder loops. | Author/clear remaining layers or remove/unavailable them; iPhone background-audio test. |
| Books | Four bundled public-domain editions. | Territorial copyright review for every target country and update cycle. |
| Room/object provenance | Policy records user-supplied AI-generated originals. | Keep prompt/source/right records accessible for release audit; verify all assets are cleared/original. |

---

## 9. Test and CI truth

### Current reported validation

| Check | Result | Scope |
|---|---|---|
| Swift package test suite | **222 passed, 0 failures** | Platform-neutral domain/controllers/services test target. |
| GitHub Actions run | **Passed:** [36291223612](https://github.com/gotneckedo/ProductivityTracker/actions/runs/36291223612) | macOS simulator Xcode build/test/capture at UI source head `036bfb0`; 72 screenshots uploaded as `still-screenshots`. |
| Static/report audit | Completed for this report at app snapshot `42ec8df`. | Routes, flags, dependency selection, source copy, docs, project configuration, and evidence record. |

### Important test limitations

- `Package.swift` excludes the SwiftUI app/root/live wiring/resources; passing `swift test` does **not** mean every UI screen compiled/rendered on iPhone.
- The CI simulator is a single current non-SE iPhone selection, not smallest/largest device matrix or assistive-technology validation.
- CI screenshot capture is static and does not prove haptics, motion correctness, background audio, system notifications, StoreKit/App Store transactions, Family Controls shields, NFC behavior, Universal Links, or alarm delivery.
- `REDESIGN_NOTES.md` contains an older **214** test count in historical material and a current **222** top-level count. Use **222** for the current stated local validation; do not cite historical 214 as a current result.

---

## 10. Recommended next build sequence

1. **Truth and navigation repair:** Fix Focus greeting hierarchy/determinism; reconnect Journal/Habits; implement free History reader; remove/gate activity explanatory copy; resolve short-read shared-list treatment.
2. **Complete evidence discipline:** Add stable `proof-…` screenshots for every still-open safe-area/copy/card/doodle state; retain a manifest containing run, SHA, device, appearance, and review result.
3. **Complete the free product floor:** Put all break activities behind an honest discovery path; keep four earned rooms, all basic breaks, four loops + silence, and local history un-gated.
4. **Correct monetization architecture before surface expansion:** Either make Still+ unavailable/hidden in release until App Store work is ready or wire a genuine release StoreKit service and complete room/sound/cat entitlement propagation.
5. **Then build guarded platform features:** morning/routine model, alarm mock state in DEBUG only, Family Controls/DeviceActivity only after entitlement approval, and NFC/Universal Links only with real signing/domain/hardware.
6. **Run a release-validation pass:** iPhone hardware, supported OS range, notification response, audio background behavior, VoiceOver/Dynamic Type/Bold Text, widget/Live Activity provisioning, and content/provenance review.

---

## 11. Source index for an independent reviewer

All paths below are relative to `Still-upload/` at the reviewed snapshot.

| Subject | Primary sources |
|---|---|
| App/router/sheets | `Still/App/StillApp.swift`, `Still/App/RootView.swift`, `Still/App/AppRouter.swift`, `Still/Domain/Navigation/AppRoute.swift` |
| State/dependencies | `Still/App/AppState.swift`, `Still/App/AppState+Features.swift`, `Still/App/DependencyContainer.swift`, `Still/App/DependencyContainer+Live.swift` |
| Today/Focus/Break/Me | `Still/Features/Today/TodayView.swift`, `Still/Features/Focus/FocusHomeView.swift`, `ActiveFocusView.swift`, `SessionCompleteView.swift`, `SessionOptionsView.swift`, `Still/Features/Break/`, `Still/Features/Me/MeView.swift` |
| Tasks/Journal | `Still/Features/Tasks/TasksSheet.swift`, `TaskDetailView.swift`, `DayTimelineView.swift`, `Still/Features/Journal/JournalView.swift` |
| Rooms/cat | `Still/DesignSystem/RoomHeroView.swift`, `Still/Domain/RoomObject.swift`, `CatCompanion.swift`, `Still/Data/SeedData/SceneCatalog.swift`, `Still/Features/Focus/RoomCollectionView.swift`, `Still/Features/Me/SceneCollectionView.swift` |
| Purchase/card/alarm/blocking | `Still/Services/Purchases/`, `Still/Features/Me/StillPlusView.swift`, `FocusCardView.swift`, `MorningStartView.swift`, `BlockingSetupView.swift`, `Still/Services/WakeUp/`, `Still/Services/ScreenTime/`, `Still/Services/NFC/` |
| Evidence | `REDESIGN_NOTES.md`, `.github/workflows/ios.yml`, `Still/App/DemoLaunch.swift`, `StillTests/StillTests.swift` |
| Policy/release boundaries | `FUTURE_CAPABILITIES.md`, `ASSET_AND_CONTENT_POLICY.md`, `ROOM_SPRITE_REPLACEMENT_SPEC.md`, `TESTFLIGHT_SETUP.md`, `README.md` |

### Direct capability citations

- **Still+ release/no-op split:** `Still/App/DependencyContainer+Live.swift:69–74`, `Still/Services/Purchases/PurchaseService.swift:40–93`, `Still/Services/Purchases/StoreKitPurchaseService.swift:1–84`, and `Still/Features/Me/StillPlusView.swift:13–108`.
- **Focus Card and NFC:** `Still/Features/Me/FocusCardView.swift:4–176`, `Still/Services/NFC/NFCFocusPresetRouting.swift:3–202`, `Still/App/StillApp.swift:14–22`, `Still/App/AppState.swift:488–534`, and `Still/Info.plist:22–32,49–57`.
- **Morning Start / wake-up boundary:** `Still/Features/Me/MorningStartView.swift:5–179`, `Still/Services/WakeUp/WakeUpScheduling.swift:3–127`, `Still/Services/Notifications/UserNotificationScheduler.swift:100–126`, and `Still/App/AppState+Features.swift:391–463`.
- **Blocking / shielding boundary:** `Still/Features/Me/BlockingSetupView.swift:6–297`, `Still/Services/ScreenTime/FocusBlockingService.swift:35–214`, `Still/Services/ScreenTime/BlockingSchedule.swift:125–147`, `Still/App/DependencyContainer+Live.swift:29–36`, and `Still/Still.entitlements:1–11`.
- **Proof configuration:** `.github/workflows/ios.yml:50–229`, `Still/App/DemoLaunch.swift:1–255`, and `REDESIGN_NOTES.md:1–59`.

> **Final assessment:** The app is far beyond a prototype in local focus, task, break, and room behavior. It is **not ready to be represented as a fully finished or commercially shippable app** because the release configuration deliberately keeps key platform/commercial capabilities unavailable, several discovery and proof gaps remain, and external Apple/App Store/device validation is pending. The correct next move is to close the P0 truth/discovery/proof defects before adding more visible scope.
