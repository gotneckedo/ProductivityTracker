# Design direction (redesign, September 2026)

The V1 UI works but reads as a settings app. This is the direction for the
redesign, drawn from 18 references the owner collected. References are for
**principles only** (see `ASSET_AND_CONTENT_POLICY.md`): no copied art, sprites,
palettes, copy, layouts, puzzles or characters.

The one-line version: **an isometric pixel room on a soft backdrop that fills up
with the things you did, lit warm against cool, with a few tiny loops, calm flat
backgrounds and detailed little objects, around a Tiimo-style focus screen,
NYT-style break cards, subjects in color, and stats compared only to your own
usual.**

---

## Look

| Element | Rule | From |
|---|---|---|
| Palette | Mint, peach, sky, sage, cream. One warm + one cool per scene. No pure black. | Forest, Focus Friend, A Short Hike |
| Outlines | Dark warm maroon/brown, a shade darker than the object. Never black. | Focus Friend, Stardew |
| Type | Big confident serif (New York) for titles and timer digits; clean sans for everything else. Small-caps overlines ("4 MIN READ · ESSAY"). | Tiimo, Folderly, Structured, Particle |
| Pixel art | One pixel grid, whole-number scaling. Flat calm shapes for backgrounds (walls, floor, sky, water); outlined, detailed small objects. Shade by shifting hue (shadows toward blue/purple, highlights toward yellow). | A Short Hike, Stardew |
| Light | Warm light inside, cool outside. Lamps glow with halos. Scenes lit by the clock: morning, afternoon, dusk, night. | Lofi Girl, Stardew, Endel |
| Motion | 3–4 tiny loops per scene (steam, rain, lamp flicker, leaves). Visuals follow the sound (rain heavier as volume rises). Small confetti burst on check-off. | Lofi Girl, Endel, Tiimo |
| Cards | Soft, rounded, generous; one solid color per activity. | NYT Games, Opal |

## Screens

**Home — the room.** An isometric cutaway room (two walls and a floor) floating
on a soft patterned backdrop whose color is the user's palette. Buttons are
objects in the room: lamp, shelf, window, a wooden FOCUS sign. The room fills up
with things from what you actually did: books from reading breaks, your pixel
doodles framed on the wall, plants from sessions. Swipe between rooms (scenes).
A camera button saves a picture of the room. *(Focus Friend, Unpacking, Forest)*

**Focus — running.** Task name in large serif, time range under it, progress ring
around a small pixel object, big serif digits, "+5" beside a pill pause button, a
sound chip at the top with moving bars, the task's steps checkable underneath.
The room dims while you work. Controls as one row of pills (Sound, Blocking,
Timer). No "Give up" — "End early". *(Tiimo, Focus Friend, Opal, Endel)*

**Session complete.** A word, a sentence, then four small numbers. Three break
suggestions stay diverse (reset / puzzle / quiet). *(Gentler Streak)*

**Break.** One big colored card per activity: name, one line, line icon, and a
status line that knows where you left off ("4 cells left", "Today's read: …").
Favorites (from onboarding, then from use) float to the top here; the three
finish-screen suggestions stay diverse. *(NYT Games)*

**Activities.** Sudoku: boxes separated by gaps, your numbers in color, same-number
highlight, used-up digits fade, Undo / Notes / Clear row, soft coral for
conflicts, no visible clock. Word search: letter circles joined by thick colored
paths. Short Read: overline + colored key words in the title; "Full" and
"3 key ideas" versions written by hand. *(Not Evil Sudoku, NYT Strands, Particle)*

**Day.** Week strip with colored dots under each day. Habits as round bubbles at
the top. Timed items as capsules on a vertical line (height = length, colored by
subject, matching check circle). Untimed items grouped Anytime / Morning /
Afternoon / Evening. Repeat picker: Once/Daily/Weekly/Monthly pill, − + stepper,
round day buttons. *(Structured, Tiimo)*

**Subjects.** A subject is a first-class object with one color, used everywhere:
timer chip, timeline capsule, folder, chart. Eight curated soft colors, not a
rainbow picker. *(Study Bunny, Folderly, Structured)*

**Tasks.** Capture stays one line. Detail is optional and looks like notebook
paper (ruled lines, margin line, highlighter labels) with optional steps.
"Past due", never "Missed". *(Folderly)*

**Me.** A personal card at the top (name, color, pixel sticker; no birthday or
school). Stats compared to your own usual ("About your usual Tuesday"), a soft
glowing orb behind the hero number, a "your usual" band or dashed AVG line on
charts, Day/Week/Month/Year switcher, and a month calendar with a small icon per
day (never a red X). Grouped settings with colored rounded-square icons.
*(Folderly, Gentler Streak, Brick, Forest, NYT Games, Not Evil Sudoku)*

**Onboarding.** Three skippable questions (goal, kind of break, palette/app icon),
each with a "Data not shared" chip, plus a privacy screen: processed on-device,
no accounts, no servers. "Set up now (takes 1 min)" / "Later". Every answer
changeable in Me. *(one sec, Gentler Streak, Not Evil Sudoku)*

**Blocking and the Focus Card.** The card drawn in pixel art on screen, preset
name, "Blocks 3 apps", "Hold your card to the top of your phone". Setup shows a
small preview diagram of what will happen. Option: a schedule that starts at a
time and **ends on card tap**. "End blocking now" always stays. Shield copy is
kind ("Focus on your task, or take a little break."). *(Brick, one sec)*

**Widgets.** Next thing, big and plain ("in 15 min · Math"); a Start button
(interactive widgets, iOS 17). *(Structured, Tiimo)*

## Never

- Guilt or loss: withering, losing coins, "Give up", zero streaks, "Missed".
- Scores that grade the person, comparison to other people, leaderboards.
- Currencies, shops, food economies.
- AI features that send tasks or text off the phone.
- Health or science claims ("852 Hz", "backed by science", "saves 2 hours").
- Clinical-style questionnaires.
- News, bias meters, social feeds, friends.
- A person-at-a-desk-with-headphones-and-cat composition (Lofi Girl trade dress).
- All-black minimalism as the default look.

## Art production

The prototype draws simplified isometric rooms in code so the layout can be
judged. Detailed objects are meant to become hand-drawn sprites (Aseprite) later,
dropped into the same room system without other changes.
