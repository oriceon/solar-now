#!/usr/bin/env bash
# Makes the animated pictures of the README in store/: the Flow tab as it moves, and a tour of the
# tabs, in English, at one and a half times the size, on the background of a dark Plasma theme.
#
# Needs the environment of the viewer (PY, QT_QPA_PLATFORM, see the README), with Pillow importable
# by PY. The fonts come from fonts/ next to this script; NOTO may name another folder.
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
"$PY" "$HERE/animate.py" "$ROOT/store/solar-now-tour.webp" 15 9 "$WORK/flow" "$WORK/tab-1.png:2500" "$WORK/tab-2.png:2500" "$WORK/tab-3.png:2500" "$WORK/tab-5.png:2500"
