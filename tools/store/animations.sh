#!/usr/bin/env bash
# Makes the animated pictures in store/, in English, on the background of a Plasma theme:
# - for the README, as WebP at one and a half times the size: the Flow tab as it moves, and a tour of the tabs;
# - for the KDE Store, which takes five pictures at most and shows no WebP: five smaller GIFs.
#
# The flow by day and by night, the light theme and the periods of History and Balance; and the
# product picture, animated.
#
# Needs the environment of the viewer (PY, QT_QPA_PLATFORM, see the README), with Pillow importable
# by PY, and gifski (https://gif.ski) on the PATH or named in GIFSKI. The fonts come from fonts/ next
# to this script; NOTO may name another folder.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: "${PY:?the python of the viewer}"
NOTO="${NOTO:-$HERE/fonts}"
sed "s|@FONTS@|$NOTO|g" "$HERE/fonts.conf.in" > "$WORK/fonts.conf"
export FONTCONFIG_FILE="$WORK/fonts.conf" QT_SCALE_FACTOR=1.5

# The flow at 14:30 of the recorded day, the moment of its peak production.
MOMENT='{"generation":4635,"consumption":537,"feedIn":null,"purchase":7,"wire":7,"charge":-3943,"discharge":null,"battery":-3943,"soc":59,"updatedAt":1791891000}'
COMMON=(--lang en --station-name Home --size 520x520 --real --background theme)
PRICES=(--price-buy 0.25 --price-sell 0.08 --currency EUR)

cd "$ROOT/tests/qml"
# About the time a dot takes along its line: 68 frames, 66 ms apart.
"$PY" viewer.py stage "$WORK/flow.png" "${COMMON[@]}" --latest "$MOMENT" --animations full --wait 1500 --frames 68 > /dev/null

for tab in 1 2 3 5; do
    "$PY" viewer.py stage "$WORK/tab-$tab.png" "${COMMON[@]}" --tab "$tab" "${PRICES[@]}" > /dev/null
done

# The viewer leaves 10 px of desktop around the widget and the Plasma frame has 6 px corners, both times 1.5.
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-flow.webp" 15 9 "$WORK/flow"
TOUR=("$WORK/flow" "$WORK/tab-1.png:2500" "$WORK/tab-2.png:2500" "$WORK/tab-3.png:2500" "$WORK/tab-5.png:2500")
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-tour.webp" 15 9 "${TOUR[@]}"

# The evening the answers were recorded at: the battery runs the house.
"$PY" viewer.py stage "$WORK/night.png" "${COMMON[@]}" --animations full --wait 1500 --frames 68 > /dev/null
"$PY" viewer.py stage "$WORK/light.png" "${COMMON[@]}" --light --latest "$MOMENT" --animations full --wait 1500 --frames 68 > /dev/null

for period in month year total; do
    "$PY" viewer.py stage "$WORK/history-$period.png" "${COMMON[@]}" --tab 2 --scale "$period" "${PRICES[@]}" > /dev/null
    "$PY" viewer.py stage "$WORK/balance-$period.png" "${COMMON[@]}" --tab 3 --scale "$period" "${PRICES[@]}" > /dev/null
done

GIF=(15 9 --scale 0.8)
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-store-1-day.gif" "${GIF[@]}" "$WORK/flow"
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-store-2-night.gif" "${GIF[@]}" "$WORK/night"
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-store-3-history.gif" "${GIF[@]}" "$WORK/tab-1.png:2500" "$WORK/history-month.png:2500" "$WORK/history-year.png:2500" "$WORK/history-total.png:2500"
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-store-4-balance.gif" "${GIF[@]}" "$WORK/balance-month.png:2500" "$WORK/balance-year.png:2500" "$WORK/balance-total.png:2500"
# The light frame of the viewer has the same 6 px corners.
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-store-5-light.gif" "${GIF[@]}" "$WORK/light"

# The product picture, animated: 60 steps of its `phase`, 24 a second. Its corners are already round.
unset QT_SCALE_FACTOR
"$PY" "$HERE/render.py" "$HERE/logo.qml" "$WORK/logo.png" --frames 60 --fps 24 > /dev/null
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-logo.gif" 0 0 "$WORK/logo"
