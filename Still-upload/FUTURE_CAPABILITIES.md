# Future capabilities

This document is the release boundary for Still. **A user-installable build must not describe a capability it cannot perform.** Still is Apple-framework-only, local-first, and has no account, backend, analytics SDK, or remote entitlement service.

## Current release truth

| Capability | Release behavior today | Not a release claim | Required before expanding it |
|---|---|---|---|
| Focus sessions, tasks, Today, Break, journal, habits, doodles, books | Local data and local workflows work on-device. Four earned core rooms stay free. | None. | Routine device testing and accessibility review. |
| Ambient sound | Four authored local loops—Rain, Café, Fireplace, Waves—play with independent levels and fades. Silence is a soundscape. Eight modeled layers are visibly unavailable and disabled because no audio is bundled for them. | Extra layers or a paid audio catalog. | Author/clear each layer, add it to the bundle, test background audio on an iPhone, then decide its entitlement. |
| Room collection | Twenty authored object sprites, local unlock history, and per-room placement are real. | A social or network collection. | None; preserve provenance for new art. |
| Extra rooms and cat coats | Their lock state is present. Entitled local/StoreKit test sessions resolve to the selected room rather than falling back. | A purchase path in release. | App Store Connect products, StoreKit product loading, sandbox and restore testing on a physical device, subscription metadata, and App Review approval. |
| Still+ | The information page describes the intended optional benefits and states it is unavailable when StoreKit supplies no product. No price, purchase, or restore control appears in that state. | That someone can subscribe in the current release build. | Create `com.cocomedia.still.plus.monthly` and `com.cocomedia.still.plus.yearly` in App Store Connect; confirm $2.99/month and $24.99/year, disclosures/localizations, transaction verification, restore, and device sandbox behavior. |
| Focus Card setup | Free. A compatible writable NFC tag containing a `still://start-focus?preset=…` link can route to a local preset; links can be copied and simulated. | A card sale, fulfillment, or digital-feature unlock. | NFC capability/physical-device testing for in-app writing; a separate fulfillment design if a branded card is ever offered. The branded physical card—not basic tag setup—may be a future Still+ benefit. |
| Morning Start | A recurring local notification plan. On iOS 17–25 it follows silent mode and Focus and can be dismissed normally. | An alarm, a card-gated wake-up flow, a wake checklist, or an alarm that cannot be stopped. | A separately designed and Apple-approved alarm capability plus real-device testing. Until then, production exposes Button as the only stop method. |
| App limits and scheduled blocking | No active shielding claim in release. Times and presets can be saved, but a saved schedule cannot shield apps while Still is closed. | “iOS shields apps at that time” or card-only schedule dismissal. | Family Controls Distribution entitlement, matching app/extension entitlements, a DeviceActivity monitor extension that starts/ends shielding, selection persistence, physical-device tests, and an explicit release-flag audit. |
| Widgets and Live Activity | Code exists and local snapshots are written. | That App Group provisioning is verified for every signing team. | Paid Apple Developer signing and real-device Lock Screen/Dynamic Island validation. |
| Apple Calendar | Read-only EventKit access is requested in context. | Direct Google OAuth or remote calendar sync. | Google OAuth, privacy policy, consent verification, Keychain lifecycle, disconnect/deletion behavior—if ever deliberately added. |

## Debug and CI only

`FeatureFlags.preview` enables the visual stand-ins below **only in DEBUG builds**. CI can compile a Release configuration with `STILL_PROOF` solely to navigate deterministic screenshots; its feature flags remain `.release` and it does not activate preview products, a mock wake-up flow, or a card offering.

- Local StoreKit entitlement (`LocalPurchaseService`) for entitlement and room-rendering proof
- Wake-up opening/card-tap simulation
- Sample Google Calendar events
- Branded Focus Card artwork and Get a Card design screen
- `DemoLaunch` routes, scroll positions, and screenshot fixtures

## Apple, account, and hardware checklist

1. Join the paid Apple Developer Program before requesting entitlement distribution or App Store/TestFlight upload.
2. Enroll in Apple’s Small Business Program before App Store Connect subscription setup, if eligible.
3. Create the App Store Connect record and both Still+ subscription products before showing a release purchase path.
4. Apply for Family Controls Distribution only when the DeviceActivity extension design is ready to review.
5. Test notifications, background audio, NFC, StoreKit purchases/restores, widgets, Live Activity, and Screen Time behavior on physical iPhones.
6. Do not add an NFC Tag Reading or Associated Domains capability until the signing and hosted-domain requirements are actually available.

## Non-negotiable product boundaries

- All data remains on-device unless the product deliberately changes its privacy model and its copy is updated first.
- The Focus Card never unlocks digital features.
- Break activities are finite and remain free; no feed, urgency, streak pressure, leaderboard, coin economy, or missed-day penalty.
- Earned core rooms and history are never revoked or paywalled.
- Every new visual/audio asset requires original/cleared provenance in `ASSET_AND_CONTENT_POLICY.md`.
