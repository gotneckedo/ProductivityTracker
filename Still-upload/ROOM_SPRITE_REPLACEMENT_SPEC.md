# Still room sprite replacement contract

**Status:** Room art is frozen pending external replacement PNGs. The app already
uses a sprite-first renderer, so a conforming file swap requires **no SwiftUI
layout, anchor, navigation, or scene-model changes**.

> Do not run `Tools/generate_still_sprites.py` after placing replacement room
> art. That historical generator recreates the current room PNGs and would
> overwrite the replacements. It is retained only as provenance for the old
> temporary art.

## 1. Delivery format

| Requirement | Exact contract |
|---|---|
| File type | PNG with alpha (`RGBA`) |
| Canvas | **160 × 132 px** exactly |
| Scale | Native **1×** pixel-art canvas; no @2×/@3× files are needed |
| Origin | `(0, 0)` is the top-left pixel of the exported PNG |
| Alpha | Keep the exterior/background transparent. The app supplies the halo, room shadow, page background, cat, and optional collectible overlays. |
| Resampling | Nearest-neighbor only. No antialiasing, blur, JPEG compression, or semi-transparent anti-aliased edge fringe. |
| Text | Do not bake labels, UI, room names, arrows, pagination dots, or instructions into the art. Those are native accessible controls. |
| Palette | The replacement can use the approved original Still palette or a newly commissioned original palette. It must not trace, sample, copy, or derive pixels from another app, game, illustration, or sprite sheet. |

The runtime loads the room from the asset catalog with `Image(...).resizable()
.interpolation(.none).scaledToFit()`, inside a fixed **160:132** aspect-ratio
box. A PNG at the exact canvas size therefore lands pixel-for-pixel at the
existing layout scale.

## 2. Architectural anchor map

All coordinates below are in the 160 × 132 source-pixel canvas. The current
renderer places the room at its existing SwiftUI frame; do **not** add a solid
full-canvas background.

| Anchor | Coordinate | Purpose |
|---|---:|---|
| Back-wall top-left | `(10, 10)` | Start of the visible architectural shell |
| Back/right wall top corner | `(108, 10)` | Top vertical room corner |
| **Primary floor-corner anchor** | **`(108, 76)`** | The rear/right floor corner where the back wall, right wall, and floor meet. Keep this exact point so furniture and scene perspective remain aligned. |
| Floor left/back corner | `(10, 76)` | Left edge of the floor along the back wall |
| Floor right/front edge | `(153, 98)` | Outer right floor corner |
| Floor front apex | `(52, 128)` | Nearest floor point; leave at least 3 px transparent canvas margin beneath it |

The current room floor is the quadrilateral:

```text
(10,76) ── (108,76)
   ╲           ╲
    ╲           (153,98)
     ╲         ╱
       (52,128)
```

The back wall occupies `(10,10) → (108,10) → (108,76) → (10,76)`.
The right wall occupies `(108,10) → (153,31) → (153,98) → (108,76)`.
The replacement may improve the perspective, furniture, and lighting, but it
must preserve these plane boundaries and the primary floor-corner anchor.

## 3. Live overlay avoidance map

The room base includes starter furniture, but Still may place a cat and earned
collectibles on top. Leave visual breathing room around these centers so the
interior reads clearly instead of becoming a collision of sprites.

| Overlay | Source-pixel center / zone | Notes |
|---|---:|---|
| Cat — idle/morning | `(53, 82)` | Default cat resting position |
| Cat — active focus/sleep/complete | `(85, 90)` | Cat sits here during focus and completion states |
| Cat — break | `(123, 62)` | Cat’s break-state position |
| Collectible — shelf | `(131, 32)` | Optional earned object overlay |
| Collectible — floor corner | `(37, 103)` | Optional earned object overlay |
| Collectible — wall | `(80, 40)` | Optional earned object overlay |
| Collectible — windowsill | `(42, 59)` | Optional earned object overlay |
| Collectible — desk | `(104, 77)` | Optional earned object overlay |

Five invisible, VoiceOver-labeled 44 pt room targets are also retained in the
native UI. Their visual labels are intentionally **not** shown over the art.
Please keep the illustrated object recognizable at each center:

| Native target | Center | Expected illustrated object |
|---|---:|---|
| Desk | `(102, 81)` | Desk/work surface |
| Bookshelf | `(128, 45)` | Shelf/books |
| Calendar | `(69, 41)` | Wall calendar or timeline object |
| Plant | `(142, 65)` | Plant |
| Window | `(37, 53)` | Window/exterior view |

## 4. Exact filenames and catalog keys

Deliver each PNG using the **source filename** below. The integration copies it
into the paired asset-catalog image set using the **catalog filename** and
existing image-set metadata. The `SceneCatalog` model already points at the
catalog key; do not rename that key.

| Scene | Source PNG path and filename | Xcode image-set path | Catalog filename | Runtime key |
|---|---|---|---|---|
| Rainy Bedroom | `Still/Resources/Sprites/still-room-rainybedroom.png` | `Still/Assets.xcassets/StillRoomRainyBedroom.imageset/` | `StillRoomRainyBedroom.png` | `StillRoomRainyBedroom` |
| Library Light | `Still/Resources/Sprites/still-room-librarylight.png` | `Still/Assets.xcassets/StillRoomLibraryLight.imageset/` | `StillRoomLibraryLight.png` | `StillRoomLibraryLight` |
| Train Window | `Still/Resources/Sprites/still-room-trainwindow.png` | `Still/Assets.xcassets/StillRoomTrainWindow.imageset/` | `StillRoomTrainWindow.png` | `StillRoomTrainWindow` |
| Night City | `Still/Resources/Sprites/still-room-nightcity.png` | `Still/Assets.xcassets/StillRoomNightCity.imageset/` | `StillRoomNightCity.png` | `StillRoomNightCity` |
| Autumn Window (Still+) | `Still/Resources/Sprites/still-room-autumnwindow.png` | `Still/Assets.xcassets/StillRoomAutumnWindow.imageset/` | `StillRoomAutumnWindow.png` | `StillRoomAutumnWindow` |
| Snow Day (Still+) | `Still/Resources/Sprites/still-room-snowday.png` | `Still/Assets.xcassets/StillRoomSnowDay.imageset/` | `StillRoomSnowDay.png` | `StillRoomSnowDay` |
| Spring Rain (Still+) | `Still/Resources/Sprites/still-room-springrain.png` | `Still/Assets.xcassets/StillRoomSpringRain.imageset/` | `StillRoomSpringRain.png` | `StillRoomSpringRain` |
| Alarm Sleep (reserved; not currently user-facing) | `Still/Resources/Sprites/still-room-alarmsleep.png` | `Still/Assets.xcassets/StillRoomAlarmSleep.imageset/` | `StillRoomAlarmSleep.png` | `StillRoomAlarmSleep` |

## 5. Room-specific content direction

The four earned rooms are free and remain available permanently as people
complete focus sessions. The three Still+ rooms are permanent additional rooms;
there is no “seasonal,” rotation, countdown, or expiry framing.

| Room | Required visual identity |
|---|---|
| Rainy Bedroom | Readable bedroom: rain window, bed with a real mattress/front face, desk, lamp with architectural bounce, shelf, plant. |
| Library Light | Tall shelves, sunlit window, reading chair, compact writing desk; visibly different floor plan from bedroom. |
| Train Window | Rail-car seat/back, wide landscape window, compact table; must not read as a bedroom re-color. |
| Night City | Skyline window, desk facing city, foreground chair; must not read as a bedroom re-color. |
| Autumn Window | Warm study with a distinct autumn exterior; permanent Still+ room. |
| Snow Day | Blue snowlight and warm lamp; permanent Still+ room. |
| Spring Rain | Green post-rain study with a distinct library-like layout; permanent Still+ room. |
| Alarm Sleep | Dark sleep room reserved for a later, DEBUG-only alarm-preview state. Do not imply a shippable alarm in the art. |

## 6. Integration acceptance checklist

Before an external room PNG is accepted, Still will verify:

1. Exactly 160 × 132 px, RGBA PNG, with transparent exterior pixels.
2. The back-wall/right-wall/floor shell aligns to the anchor map, especially
   **the `(108,76)` floor corner** and `(52,128)` front apex.
3. No text, controls, trademarks, copied assets, or reference-app pixels.
4. The cat positions, optional object-overlay zones, desk/shelf/calendar/plant/
   window target centers remain unobstructed.
5. The `StillRoom…` image-set key and `SceneCatalog.spriteAssetName` are
   unchanged.
6. A simulator CI screenshot is captured at full room size for every changed
   room and manually reviewed before any note calls the replacement complete.
7. `ASSET_AND_CONTENT_POLICY.md` receives the commissioned/source provenance,
   license/assignment, date, and reviewer before release.

## 7. Copy command pattern for integrators

For each delivered room, replace the source PNG and its asset-catalog PNG with
identical image bytes, preserving the existing `Contents.json`:

```bash
# Example: Rainy Bedroom
cp /path/to/still-room-rainybedroom.png \
  Still/Resources/Sprites/still-room-rainybedroom.png
cp /path/to/still-room-rainybedroom.png \
  Still/Assets.xcassets/StillRoomRainyBedroom.imageset/StillRoomRainyBedroom.png
```

Then run the iOS screenshot workflow. No Swift code change is expected for a
conforming replacement.
