# Future capabilities

This document records the boundary between what Still genuinely does today and what is visible only in **DEBUG/CI previews**. Preview UI must carry a **Preview** tag and must not claim a network request, alarm, purchase, shipment, or system restriction happened when it did not.

## Release rule

`FeatureFlags.v1`, `FeatureFlags.current`, and `FeatureFlags.release` keep every P9 stand-in flag off. `FeatureFlags.preview` turns them on only when compiled with `DEBUG`; in Release it resolves to `current`. Unit tests pin this contract. Live dependency wiring also places sample Google data, the Wake up simulator, local purchase testing, and placeholder card offering behind `#if DEBUG`.

| P9 capability | Real now | Preview stand-in | Production swap needed |
|---|---|---|---|
| **a. Room collection** | `RoomCollectionController` evaluates 20 original, code-drawn room objects from local focus, reading, doodle, and break history; it persists earned ownership and per-room placement. | None. All collection behavior is on-device and released. | No service swap is planned. Optional hand-drawn sprite assets can use each object's `spriteAssetName` seam without changing the collection model. |
| **b. Wake up** | `NotificationWakeUpScheduler` uses the existing repeating local-notification path on iOS 17+. | `PreviewWakeUpScheduler` demonstrates Still opening and waiting for a simulated Focus Card tap. | Implement `AlarmKitWakeUpScheduler` at `WakeUpSchedulerFactory` behind `#available(iOS 26, *)`; add Apple's required usage description/capability; verify scheduling, authorization, recurrence, and system-owned stop UI on physical hardware. Keep notifications for iOS 17–25. The UI must continue to say that a card can gate Still's queued session, not prevent dismissal of the system alarm. |
| **c. Bundled public-domain books** | Four Standard Ebooks compatible EPUB editions are bundled and parsed entirely on-device; each has a parser and provenance regression test. | None. The shipped files are the real reading content. | Review territorial copyright status for every country before a worldwide release, re-check each edition on updates, and add only editions with a completed provenance row in `ASSET_AND_CONTENT_POLICY.md`. |
| **d. Still+ subscription** | `StillPlusView` and `StoreKitPurchaseService` load, purchase, verify, restore, and check the current StoreKit entitlement for `com.cocomedia.still.plus.monthly`. Still+ covers Focus Card access and optional seasonal rooms; regular focus, tasks, private data, and every session-earned room remain free. `StillProducts.storekit` supplies local Xcode transactions. | Linux/previews use `LocalPurchaseService`, which records a memory-only test entitlement and says so clearly. No payment, fulfilment, or server occurs in a preview. | Create and submit the `com.cocomedia.still.plus.monthly` auto-renewable subscription in App Store Connect, finalize price/localizations/subscription disclosures, test sandbox purchase/restore on physical hardware, and complete App Review subscription metadata. Keep no urgency, limited offers, or paid versions of session-earned rooms. |
| **e. Student-focused wording** | `Copy.swift` centralizes the new study, homework, class, and quiet-break wording used across Home, Focus, completion, Break, notifications, and room collection. | None. The wording ships in the app. | Add localization resources when Still gains another supported language; keep `Copy` as the source of truth while doing so. |
| **f. Google Calendar** | Apple Calendar via EventKit already reads calendars installed on the iPhone, including Google accounts added in iOS Settings. | `SampleGoogleCalendarAdapter` returns two clearly named sample events and performs no login or network call. | Register a Google Cloud project, configure OAuth consent and iOS redirect details, publish a privacy policy, request the narrow read-only calendar scope, pass Google's verification where required, store tokens securely in Keychain, implement refresh/revocation in a real `GoogleCalendarAdapter`, and add deletion/disconnect behavior. Still currently has no backend or account system. |
| **g. Branded Focus Card** | Existing `still://` links, `DeepLinkParser`, the NFC simulator, and optional CoreNFC writer boundary are real. | Code-drawn branded card and “Get a card” explanation use `PlaceholderFocusCardOffering`; there is intentionally no cart, price, payment, or fulfillment API. | Replace `StillLinks.universalHost` (`links.still.example`) once with a real owned HTTPS host; serve `/.well-known/apple-app-site-association` for app ID `<TEAM_ID>.com.cocomedia.still`; add `applinks:<host>` under Associated Domains; keep `/start-focus?preset=…`; validate Universal Links on device; replace the placeholder setup page. Add the entitlement only after the domain exists because adding it now would break signing. Card printing/fulfillment stays outside the app unless separately designed and reviewed. |
| **h. TestFlight** | A root-level, manual-only GitHub workflow validates secrets, installs signing assets, archives, exports, and uploads with an App Store Connect API key. | None; it is intentionally inactive until a human triggers it and secrets exist. | Complete the adult/company-owned Apple Developer membership and App Store Connect record, provide all seven documented repository secrets, keep profiles current for the app and widget, increment the build number, then run the workflow manually. See `TESTFLIGHT_SETUP.md`. |

## Existing real capabilities

| Capability | Boundary and status |
|---|---|
| One-line journal and habits | Device-local repositories and controllers; shipped. |
| Plant stages | Derived from completed sessions and never regress; shipped. |
| Custom presets | Device-local and shipped. |
| Tasks, homework details, due dates, day view | Device-local and shipped. |
| Apple Calendar | `EventKitCalendarAdapter`, read-only and requested in context. |
| Voice task capture | On-device Speech framework where available; user confirms before saving. |
| Pixel doodle and EPUB reader | Device-local; imported books stay on device. |
| Morning Start notification | Real `UserNotifications` fallback; distinct identifiers from focus phase reminders. |
| Widget and Live Activity | Built; real shared values need the paid-account App Group provisioning to be verified. |

## Other approval or hardware boundaries

### Blocking entitlement

`FamilyControlsBlockingService` exists behind `FeatureFlags.appBlocking`; current and release keep it off. Production needs the Family Controls (Distribution) entitlement, matching entitlements for the app and a DeviceActivity monitor extension, and physical-device verification. Selection tokens stay on-device. “End blocking now” must remain available.

### NFC writing

`CoreNFCTagWriter` is compiled only with `-DSTILL_CORENFC`. Production needs the NFC Tag Reading capability, the NDEF entitlement, a paid signing team, and physical iPhone tests. A tag written by another NFC app with a `still://` URL works without the in-app writer.

### App/category blocking

- **Done:** `FamilyControlsBlockingService` (authorization, per-preset
  `FamilyActivitySelection` stored via `BlockingSelectionStore`,
  `ManagedSettingsStore` shields on session start, cleared on end),
  `BlockingSetupView` with `FamilyActivityPicker`, a Blocking section in Session
  options, and "End blocking now" on the running session (logs
  `blocking_override`, no app names). The setup also has a persisted start-time
  schedule whose state ends only on a Focus Card tap or the always-available
  "End blocking now" override, plus an honest Preview label whenever the mock
  service is in use. All behind `FeatureFlags.appBlocking`.
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
- **Scheduled start boundary:** the persisted state machine and foreground start
  path are complete. Starting at the exact time while Still is closed requires
  the same DeviceActivity extension to register the repeating start interval;
  the app does not claim background shielding before that extension and
  entitlement are installed. Card-tap and manual ending clear the shared
  `ManagedSettingsStore` immediately whenever real shielding is active.
- **Privacy:** selections are opaque tokens that stay on the device.
- **Next safe step:** apply for the entitlement now; the wait is the long pole.

### Analytics destination

Typed, sanitized events remain in a bounded local log. No network destination is registered. Any future export must be opt-in, reviewable, aggregate-only, and reflected in privacy copy before release.

## Explicitly out of scope

Android, a launcher/dumbphone mode, chess engines, weather, news, licensed modern books, urgency mechanics, and paid versions of anything currently earned through use remain out of scope. Still+ is the explicitly scoped optional subscription described above; the original room cat is ambient art, not a gamified companion.
