# Future capabilities

This document records the boundary between what Still genuinely does today and what is visible only in **DEBUG/CI previews**. Preview UI must carry a **Preview** tag and must not claim a network request, alarm, purchase, shipment, or system restriction happened when it did not.

## Release rule

`FeatureFlags.v1`, `FeatureFlags.current`, and `FeatureFlags.release` keep every P9 stand-in flag off. `FeatureFlags.preview` turns them on only when compiled with `DEBUG`; in Release it resolves to `current`. Unit tests pin this contract. Live dependency wiring also places sample Google data, the Wake up simulator, local purchase testing, and placeholder card offering behind `#if DEBUG`.

| P9 capability | Real now | Preview stand-in | Production swap needed |
|---|---|---|---|
| **b. Wake up** | `NotificationWakeUpScheduler` uses the existing repeating local-notification path on iOS 17+. | `PreviewWakeUpScheduler` demonstrates Still opening and waiting for a simulated Focus Card tap. | Implement `AlarmKitWakeUpScheduler` at `WakeUpSchedulerFactory` behind `#available(iOS 26, *)`; add Apple's required usage description/capability; verify scheduling, authorization, recurrence, and system-owned stop UI on physical hardware. Keep notifications for iOS 17–25. The UI must continue to say that a card can gate Still's queued session, not prevent dismissal of the system alarm. |
| **d. Seasonal scenes + Supporter** | Three seasonal `SceneDefinition`s use existing renderers and `entitlementKey`. A real StoreKit 2 implementation loads, purchases, verifies, and restores the non-consumable product. `StillProducts.storekit` supplies local Xcode transactions. | The checked-in product and StoreKit environment are test-only; Linux/previews use `LocalPurchaseService`, which only records memory state. | Create `com.cocomedia.still.supporter` as a non-consumable in App Store Connect, localize/review metadata and pricing, test sandbox purchase/restore on device, and decide whether entitlement state needs cross-device handling beyond StoreKit current entitlements. Keep all four session-earned scenes free and keep subscriptions, urgency, and timers out. Add final alternate-icon assets before advertising icons. |
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

### App/category blocking

`FamilyControlsBlockingService` exists behind `FeatureFlags.appBlocking`; current and release keep it off. Production needs the Family Controls (Distribution) entitlement, matching entitlements for the app and a DeviceActivity monitor extension, and physical-device verification. Selection tokens stay on-device. “End blocking now” must remain available.

### NFC writing

`CoreNFCTagWriter` is compiled only with `-DSTILL_CORENFC`. Production needs the NFC Tag Reading capability, the NDEF entitlement, a paid signing team, and physical iPhone tests. A tag written by another NFC app with a `still://` URL works without the in-app writer.

### Analytics destination

Typed, sanitized events remain in a bounded local log. No network destination is registered. Any future export must be opt-in, reviewable, aggregate-only, and reflected in privacy copy before release.

## Explicitly out of scope

Android, a launcher/dumbphone mode, animal companions, chess engines, weather, news, licensed modern books, subscriptions, urgency mechanics, and paid versions of anything currently earned through use remain out of scope.
