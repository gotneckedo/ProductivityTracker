#!/usr/bin/env bash
# Full Still visual-regression gallery. This deliberately remains broader than
# the push-time P0 proof matrix: it catches regressions outside the current
# ticket, including safe-area, scene-grid, room, and dark-mode issues.
#
# Required environment:
#   UDID       booted iPhone simulator identifier
#   BUNDLE_ID  Still bundle identifier
#   GITHUB_WORKSPACE  artifact workspace
set -euo pipefail

: "${UDID:?UDID is required}"
: "${BUNDLE_ID:?BUNDLE_ID is required}"
: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"

OUT="$GITHUB_WORKSPACE/full-gallery"
mkdir -p "$OUT"

shoot() {
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -still-demo "$1" > /dev/null
  sleep 10
  xcrun simctl io "$UDID" screenshot "$OUT/$2.png"
  echo "Captured $2"
}

shoot_bottom() {
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -still-demo "$1" -still-scroll-bottom "$1" > /dev/null
  sleep 10
  xcrun simctl io "$UDID" screenshot "$OUT/$2.png"
  echo "Captured $2"
}

shoot_midpoint() {
  xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" -still-demo "$1" -still-scroll-midpoint "$1" > /dev/null
  sleep 10
  xcrun simctl io "$UDID" screenshot "$OUT/$2.png"
  echo "Captured $2"
}

xcrun simctl ui "$UDID" appearance light
n=1
for screen in \
  onboarding today setup mixer mixer-top home focus-room sprite-contact-sheet calm active active-autumn complete \
  break sudoku wordsearch picross picross-320 breathing read doodle journal habits tasks timeline presets \
  gallery gallery-empty gallery-one gallery-several gallery-error morning me scenes card get-card; do
  shoot "$screen" "$(printf '%02d' "$n")-$screen"
  n=$((n + 1))
done

for screen in today home break journal me tasks sprite-contact-sheet; do
  shoot_bottom "$screen" "$(printf '%02d' "$n")-$screen-bottom"
  n=$((n + 1))
done

# Named visual-regression proofs are retained as stable references across
# broader visual changes, even when the compact P0 job is the normal gate.
shoot "focus-room" "proof-focus-helper-clean"
shoot "focus-room" "proof-room-art-unoccluded"
shoot "room-collectibles" "proof-room-collectible-anchors"
shoot "break" "proof-break-all-top"
shoot_bottom "break" "proof-break-all-bottom"
shoot "journal" "proof-journal-navigation"
shoot "habits" "proof-habits-navigation"
shoot_bottom "today" "proof-today-reflection-link"
shoot "read" "proof-short-read-top"
shoot_bottom "read" "proof-short-read-bottom"
shoot "mixer-available" "proof-ambient-available"
shoot "mixer" "proof-ambient-unavailable"
shoot "today-light" "proof-light-theme"
shoot_bottom "today" "proof-today-bottom-clear"
shoot_bottom "tasks" "proof-tasks-bottom-clear"
shoot_bottom "sudoku" "proof-sudoku-bottom-clear"
shoot_bottom "me" "proof-me-bottom-clear"
# Item 38: a short three-screen entry, its furnished one-tap starter room,
# and the only optional personalization invitation after a first completion.
# These stay in the broad gallery because the compact proof job must preserve
# enough runner time for all Release truth captures.
shoot "onboarding" "proof-first-run-welcome"
shoot "onboarding-privacy" "proof-first-run-privacy"
shoot "onboarding-room" "proof-first-run-room"
shoot "onboarding-starter" "proof-first-run-starter"
shoot "complete-first-run" "proof-first-run-personalize"

# Item 39: one starter room at four clock-derived phases. These named frames
# verify distinct light, window treatment, and a small environmental detail
# without adding room-art work to the compact push-time matrix.
shoot "room-phase-morning" "proof-room-phase-morning"
shoot "room-phase-afternoon" "proof-room-phase-afternoon"
shoot "room-phase-dusk" "proof-room-phase-dusk"
shoot "room-phase-night" "proof-room-phase-night"

# Item 40: the same shared room on real local timer routes. The live break
# fixture advances a Pomodoro through its focus boundary before capture; it is
# not a standalone decorative break mock.
shoot "room-session-idle" "proof-room-session-idle"
shoot "room-session-focus" "proof-room-session-focus"
shoot "room-session-break" "proof-room-session-break"
shoot "room-session-finished" "proof-room-session-finished"

# Item 42: a real first completed local session evaluates the catalog and
# exposes the original Pencil cup in the completion acknowledgement before the
# normal "Choose where it goes" collection destination. The collection route
# shows the same earned object without an entitlement or inventory stand-in.
shoot "complete-unlock" "proof-progression-completion-unlock"
shoot "room-collection-unlock" "proof-progression-collection-unlock"

# Item 43: the DEBUG catalogue renders the exact local facts supplied to the
# long-press preview of each named room object. It proves the second layer
# without trying to automate a system context-menu gesture in CI.
shoot "context-previews" "proof-room-second-layer"

for screen in break journal me scenes; do
  shoot_midpoint "$screen" "$(printf '%02d' "$n")-$screen-midpoint"
  n=$((n + 1))
done

shoot "scenes-all" "$(printf '%02d' "$n")-scenes-all"
n=$((n + 1))
shoot "scenes-extra" "$(printf '%02d' "$n")-scenes-extra"
n=$((n + 1))
shoot_bottom "scenes-all" "$(printf '%02d' "$n")-scenes-all-bottom"
n=$((n + 1))
shoot_bottom "read" "$(printf '%02d' "$n")-read-bottom"
n=$((n + 1))
shoot_bottom "sudoku" "$(printf '%02d' "$n")-sudoku-bottom"
n=$((n + 1))
shoot_bottom "card" "$(printf '%02d' "$n")-card-bottom"
n=$((n + 1))

xcrun simctl ui "$UDID" appearance dark
for screen in home active complete journal me tasks sudoku wordsearch picross; do
  shoot "$screen" "$(printf '%02d' "$n")-$screen-dark"
  n=$((n + 1))
done

xcrun simctl ui "$UDID" appearance light
for screen in cat-morning cat-away cat-room-change cat-night cat-focus cat-asleep cat-final-minute cat-complete cat-reaction; do
  shoot "$screen" "$(printf '%02d' "$n")-$screen"
  n=$((n + 1))
done

# Item 41: These deterministic visual states correspond to the local cat
# state machine. They stay in the broad gallery because the compact P0 matrix
# cannot prove a transient room pose or a timed companion reaction.
shoot "cat-away" "proof-cat-away"
shoot "cat-room-change" "proof-cat-room-change"
shoot "cat-night" "proof-cat-night"
shoot "cat-final-minute" "proof-cat-final-minute"
shoot "cat-reaction" "proof-cat-rare-reaction"

for screen in room-library room-train room-city room-autumn room-snow room-spring room-sleep; do
  shoot "$screen" "$(printf '%02d' "$n")-$screen"
  n=$((n + 1))
done

printf 'Full gallery capture complete: %s PNGs\n' "$(find "$OUT" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
