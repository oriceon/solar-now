#!/usr/bin/env bash
# Makes the pictures for the KDE Store page in store/: five screenshots in English, at twice the
# size, in Noto Sans, from the recorded answers of a real station, and the product picture.
#
# Needs the environment of the viewer (PY, QT_QPA_PLATFORM, see the README). The fonts come from
# fonts/ next to this script; NOTO may name another folder with NotoSans-{Regular,Medium,SemiBold,Bold}.ttf.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

: "${PY:?the python of the viewer}"
NOTO="${NOTO:-$HERE/fonts}"
sed "s|@FONTS@|$NOTO|g" "$HERE/fonts.conf.in" > "$WORK/fonts.conf"
export FONTCONFIG_FILE="$WORK/fonts.conf" QT_SCALE_FACTOR=2

# The flow at 14:30 of the recorded day, the moment of its peak production.
MOMENT='{"generation":4635,"consumption":537,"feedIn":null,"purchase":7,"wire":7,"charge":-3943,"discharge":null,"battery":-3943,"soc":59,"updatedAt":1791891000}'
COMMON=(--lang en --station-name Home --size 520x520 --real)
PRICES=(--price-buy 0.25 --price-sell 0.08 --currency EUR)

cd "$ROOT/tests/qml"
"$PY" viewer.py stage "$WORK/1-flow.png" "${COMMON[@]}" --latest "$MOMENT"
"$PY" viewer.py stage "$WORK/2-day.png" "${COMMON[@]}" --tab 1
"$PY" viewer.py stage "$WORK/3-history.png" "${COMMON[@]}" --tab 2 "${PRICES[@]}"
"$PY" viewer.py stage "$WORK/4-balance.png" "${COMMON[@]}" --tab 3 "${PRICES[@]}"
"$PY" viewer.py stage "$WORK/5-inverter.png" "${COMMON[@]}" --tab 5

mkdir -p "$ROOT/store"
for name in 1-flow 2-day 3-history 4-balance 5-inverter; do
    # The viewer leaves 10 px of desktop around the widget, 20 at twice the size; the widget's corners are as round.
    "$PY" "$HERE/finish.py" "$WORK/$name.png" "$ROOT/store/solar-now-$name.png" 20 20
done

unset QT_SCALE_FACTOR
"$PY" "$HERE/render.py" "$HERE/logo.qml" "$ROOT/store/solar-now-logo.png"
