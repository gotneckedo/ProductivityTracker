# Still room sprite replacement contract

**Status:** The prior temporary 160 × 132 generated-room contract is retired.
The renderer now accepts the **supplied 512 × 512 transparent pixel-art package**
without resizing, redrawing, or regenerating it. The sprite-first seam, scene
keys, navigation, cat behavior, and room interactions remain native SwiftUI.

> Do not run `Tools/generate_still_sprites.py` after placing a replacement. That
> historical utility recreates the old temporary room package and would overwrite
> the supplied images. It is retained only as provenance for the retired art.

## 1. Current delivery contract

| Requirement | Exact contract |
|---|---|
| File type | PNG with alpha (`RGBA`) |
| Canvas | **512 × 512 px** exactly |
| Scale | Native 1× square pixel-art canvas; the app does not downsample it to the old 160 × 132 format |
| Origin | `(0, 0)` is the top-left source pixel |
| Alpha | Preserve the supplied hardened alpha exactly: every pixel is either fully transparent (`0`) or fully opaque (`255`). Do not flatten onto a background. |
| Resampling | Nearest-neighbor only. No JPEG compression, blur, smoothing, or hand repainting during integration. |
| Text | Do not bake labels, room names, controls, arrows, pagination dots, or instructions into the art. Those remain native accessible UI. |
| Runtime treatment | `Image(...).resizable().interpolation(.none).scaledToFit()` inside a **1:1** room frame. |

The square canvas is intentionally adopted as the renderer contract: forcing
these supplied images into the retired landscape canvas would crop or distort
the stronger three-dimensional room composition.

## 2. Authoring and overlay map

The base artwork includes the architectural shell and starter furniture. Still
renders a separate cat and optional collectible objects above it. Keep clear
visual space around these **normalized** (canvas-independent) positions for
future replacements.

| Overlay | Normalized center | 512 × 512 coordinate | Notes |
|---|---:|---:|---|
| Cat — idle/morning | `(0.33, 0.62)` | `(169, 317)` | Default resting position |
| Cat — active focus/sleep/complete | `(0.53, 0.68)` | `(271, 348)` | Focus and completion position |
| Cat — break | `(0.77, 0.47)` | `(394, 241)` | Break-state position |
| Collectible — shelf | `(0.82, 0.24)` | `(420, 123)` | Optional earned object overlay |
| Collectible — floor corner | `(0.23, 0.78)` | `(118, 399)` | Optional earned object overlay |
| Collectible — wall | `(0.50, 0.30)` | `(256, 154)` | Optional earned object overlay |
| Collectible — windowsill | `(0.26, 0.45)` | `(133, 230)` | Optional earned object overlay |
| Collectible — desk | `(0.65, 0.58)` | `(333, 297)` | Optional earned object overlay |

Five invisible, VoiceOver-labeled 44 pt room targets remain native controls.
They intentionally have **no labels over the art**. Future replacement rooms
should keep a recognizable counterpart close to each target.

| Native target | Normalized center | 512 × 512 coordinate | Expected illustrated area |
|---|---:|---:|---|
| Desk | `(0.64, 0.61)` | `(328, 312)` | Desk/work surface |
| Bookshelf | `(0.80, 0.34)` | `(410, 174)` | Shelf/books |
| Calendar / Today | `(0.43, 0.31)` | `(220, 159)` | Wall/planning object |
| Plant / Stats | `(0.89, 0.49)` | `(456, 251)` | Plant area |
| Window / Scenes | `(0.23, 0.40)` | `(118, 205)` | Window/exterior view |

## 3. Exact filenames and catalog keys

Deliver or replace each PNG using the **source filename** below. Integration
copies it to the paired asset catalog image set with the existing catalog
filename and `Contents.json`. `SceneCatalog.spriteAssetName` must not change.

| Scene | Source PNG path and filename | Xcode image-set path | Catalog filename | Runtime key |
|---|---|---|---|---|
| Rainy Bedroom | `Still/Resources/Sprites/still-room-rainybedroom.png` | `Still/Assets.xcassets/StillRoomRainyBedroom.imageset/` | `StillRoomRainyBedroom.png` | `StillRoomRainyBedroom` |
| Library Light | `Still/Resources/Sprites/still-room-librarylight.png` | `Still/Assets.xcassets/StillRoomLibraryLight.imageset/` | `StillRoomLibraryLight.png` | `StillRoomLibraryLight` |
| Train Window | `Still/Resources/Sprites/still-room-trainwindow.png` | `Still/Assets.xcassets/StillRoomTrainWindow.imageset/` | `StillRoomTrainWindow.png` | `StillRoomTrainWindow` |
| Night City | `Still/Resources/Sprites/still-room-nightcity.png` | `Still/Assets.xcassets/StillRoomNightCity.imageset/` | `StillRoomNightCity.png` | `StillRoomNightCity` |
| Autumn Window (Still+) | `Still/Resources/Sprites/still-room-autumnwindow.png` | `Still/Assets.xcassets/StillRoomAutumnWindow.imageset/` | `StillRoomAutumnWindow.png` | `StillRoomAutumnWindow` |
| Snow Day (Still+) | `Still/Resources/Sprites/still-room-snowday.png` | `Still/Assets.xcassets/StillRoomSnowDay.imageset/` | `StillRoomSnowDay.png` | `StillRoomSnowDay` |
| Spring Rain (Still+) | `Still/Resources/Sprites/still-room-springrain.png` | `Still/Assets.xcassets/StillRoomSpringRain.imageset/` | `StillRoomSpringRain.png` | `StillRoomSpringRain` |
| Alarm Sleep (reserved; not user-facing) | `Still/Resources/Sprites/still-room-alarmsleep.png` | `Still/Assets.xcassets/StillRoomAlarmSleep.imageset/` | `StillRoomAlarmSleep.png` | `StillRoomAlarmSleep` |

The supplied sheet also lives at
`Still/Resources/Sprites/still-collectible-sprite-sheet.png` and the asset key
`StillExternalCollectibleSpriteSheet`. Its 5 × 4 row-major cells are integrated
as Still’s 20 named collectible image sets.

## 4. Room-specific visual identity

The four earned rooms stay free and permanent. The three Still+ rooms are
permanent additional rooms: there is no “seasonal,” rotation, countdown, or
expiry framing.

| Room | Visual identity |
|---|---|
| Rainy Bedroom | Night bedroom, rain window, bed, desk, lamp, shelf, and plant. |
| Library Light | Tall library shelving, sunlit window, reading chair, and compact table. |
| Train Window | Rail-car sofa, wide landscape window, and compact table. |
| Night City | City skyline, desk, window, shelf, and rug. |
| Autumn Window | Warm autumn study; permanent Still+ room. |
| Snow Day | Snowy bedroom with warm lamp; permanent Still+ room. |
| Spring Rain | Green post-rain study; permanent Still+ room. |
| Alarm Sleep | Dark sleep room reserved for a later DEBUG-only alarm-preview state. |

## 5. Acceptance and provenance gate

1. Exactly 512 × 512 RGBA PNG, with intentional transparent exterior and only
   0/255 alpha values.
2. The current supplied package is declared as AI-generated original art made
   for Still from written prompts, not derived from a reference product. Any
   future replacement needs the same recorded source declaration and no copied
   app, game, or sprite-pack pixels, trademarks, or reference-image tracing.
3. Cat, collectible, and native target zones remain visually readable.
4. Existing `StillRoom…` keys and image-set metadata remain unchanged.
5. Full-size simulator screenshots for every changed room are captured and
   manually reviewed before any completion claim is made in `REDESIGN_NOTES.md`.
6. `ASSET_AND_CONTENT_POLICY.md` records the creator/source declaration,
   prompt/assignment record, date, and reviewer before release.

## 6. Integration command pattern

```bash
# Example: Rainy Bedroom
cp /path/to/still-room-rainybedroom.png \
  Still/Resources/Sprites/still-room-rainybedroom.png
cp /path/to/still-room-rainybedroom.png \
  Still/Assets.xcassets/StillRoomRainyBedroom.imageset/StillRoomRainyBedroom.png
```

A conforming future 512 × 512 replacement needs no Swift layout change.
