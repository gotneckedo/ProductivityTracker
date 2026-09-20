# Asset and content policy

Still is private, calm, and original. Everything that ships must be something
we made, something in the public domain that we verified, or something we
licensed for app distribution, and each item needs a written provenance record.

The products in the build brief (Lofi Girl, Stardew Valley, A Short Hike,
Unpacking, Endel, Cat On Chair, Focus Friend, Forest, NYT Games, Good Sudoku,
Particle, Headspace, Calm, Opal, Brick, one sec, Structured, Tiimo, Finch,
Gentler Streak, (Not Boring)) are references for **principles only**. Never
copy their art, pixel sprites, palettes lifted wholesale, audio, copy, UI
layouts, puzzles, or branding.

## Current inventory (V1)

| Asset | Where | Provenance | License |
|---|---|---|---|
| Pixel scenes (Rainy Bedroom, Library Light, Train Window, Night City) | `DesignSystem/Scenes/SceneArtwork.swift` | Drawn in code for Still | Original |
| Calm plant nook | `DesignSystem/Scenes/SceneArtwork.swift` | Drawn in code for Still | Original |
| App icon (pixel sprout) | `Assets.xcassets/AppIcon.appiconset` | Generated for Still from a 16×16 pixel design | Original |
| Ambient loops (rain, café, fireplace, waves) | `Resources/AmbientAudio/*.m4a` | Procedurally generated (NumPy/SciPy, ffmpeg) | Original |
| Short reads (4 micro-essays) | `Data/SeedData/ReadingLibrary.swift` | Written for Still | Original, owned by the publisher |
| Creative prompts | `Data/SeedData/ReadingLibrary.swift` | Written for Still | Original |
| Sudoku, Picross, Word Search puzzles | `Data/SeedData/PuzzleLibrary.swift` | Generated for Still; uniqueness verified in `PuzzleTests` | Original |
| Stretch steps and safety note | `Domain/Activities/GuidedRoutines.swift` | Written for Still, deliberately conservative | Original |
| Font | System (SF Pro Rounded / New York) | Apple system fonts | Apple platform license |
| Icons | SF Symbols | Apple | SF Symbols license (use as UI icons only) |

## Rules by asset type

### Visual art (scenes, sprites, icons)

- Original work, commissioned work with a written assignment or license, or
  packs licensed for commercial app use (for example, itch.io packs with an
  explicit commercial license). Save the license file in the repository.
- Scenes are defined as data (`SceneDefinition`). New art should keep the
  existing contract: renderer kind, palette, unlock rule, sound affinity, and an
  accessibility description written for VoiceOver.
- No emoji as primary imagery. SF Symbols are fine for controls.
- V3 cosmetics may add `entitlementKey` values. Do not add purchasable or locked
  paid content until StoreKit work is designed and reviewed.

### Ambient audio

See the appendix at the end of this file. Record source, author, license,
date acquired, and license URL for every file. No NC licenses.

### Reading content

- Each `ReadingItem` must have title, author, source, license, and a license
  note shown in the reader.
- Public domain: include only texts whose status you can verify for the
  countries you ship in (for example, author died more than 70 years ago **and**
  published before 1930 in the US). Record the edition and translation. Modern
  translations of old works are usually still under copyright.
- If status can't be verified, write original text and label it
  `.originalForStill`.
- No news, no feeds, no endless readers. Every item has a stated duration and
  an end.

### Fonts

The typography tokens in `StillTypography.swift` are the only place fonts are
set. A custom font needs a license that allows app embedding. Add the file,
register it in Info.plist (`UIAppFonts`), and switch tokens to
`Font.custom(_:size:relativeTo:)` so Dynamic Type keeps working.

### Wellness content

Breathing and stretching language stays gentle and non-medical. Stretches must
keep the note "Move only within your comfort. Stop if anything hurts." Do not
make health claims.

## Credits

If any CC-BY material is added, list it here and in an in-app Credits row in
Me → Privacy.

---

## Appendix: ambient audio files

`AVAmbientAudioPlayer` looks for one looping file per source in the app
bundle, trying `.m4a`, then `.caf`, `.wav`, `.mp3`:

| Source    | Expected base name  | Bundled in V1                         |
|-----------|---------------------|---------------------------------------|
| Rain      | `ambient_rain`      | `ambient_rain.m4a` (generated)        |
| Café      | `ambient_cafe`      | `ambient_cafe.m4a` (generated)        |
| Fireplace | `ambient_fireplace` | `ambient_fireplace.m4a` (generated)   |
| Waves     | `ambient_waves`     | `ambient_waves.m4a` (generated)       |

### What ships today

The four V1 files are **original, procedurally generated placeholders**:
filtered noise, synthetic droplets, crackles, and soft tones made with
NumPy/SciPy and encoded with ffmpeg (AAC, mono, 80 kbps, 40-second loops with a
3-second crossfade at the seam). No recordings or third-party audio were used,
so there is nothing to license or credit. They are serviceable, not beautiful.
The café loop in particular is an abstract "room murmur" rather than a real
café. Replacing them with better loops is a good early polish task.

### Replacing a loop

1. Keep the exact base name (e.g. `ambient_rain.m4a`) and drop the file into
   `Still/Resources/AmbientAudio/`. The Xcode project uses a synchronized folder, so it is added to
   the app target automatically.
2. Aim for 30–90 seconds, mono or stereo, seamless loop points, peaks near
   −6 dBFS, and no sudden events in the first or last second.
3. `.caf` with linear PCM loops with no gap at all. AAC `.m4a` is smaller and
   loops cleanly on device in practice, but check the seam by ear.

### Licensing rules

- Use only audio you recorded, generated, commissioned, or licensed for app
  distribution. CC0 is ideal. CC-BY is fine if the credit goes in the app and in
  `ASSET_AND_CONTENT_POLICY.md`. Do not use CC-NC or "personal use" loops.
- Never download loops from the reference apps (Endel, lofi streams, etc.).
- Record provenance for each file in `ASSET_AND_CONTENT_POLICY.md`: source,
  author, license, date, and a link to the license text.

### If files are missing

Nothing breaks. A missing source stays silent; if every file is missing, the UI
shows "Ambient audio is ready when sound files are added." and the mix controls
still save. No broken player or fake meters appear.


## Things people make or bring

- **Imported books.** EPUBs a person imports from Files are copied into the
  app's private storage on their device, labeled "From your files," and never
  uploaded, shared, or redistributed. Still doesn't bundle any imported book.
  DRM-protected files can't be read and aren't worked around.
- **Bundled books.** Only verified public-domain EPUBs may be added to
  `Still/Resources/`. Record the source URL, edition, and public-domain
  reasoning for each file in this document before shipping it. Modern
  editions can carry new copyrighted material (introductions, notes, cover
  art); strip or avoid those.
- **Doodles, journal lines, habits, notes.** Created by the person, stored
  only on their device, never sent to analytics (tests enforce this for
  journal text), and deleted by Reset local data.
