#!/usr/bin/env bash
# The factory station: a finished box in, its card out.
#
#   scripts/dock-tags.sh --flash /dev/cu.usbmodem101   flash it, ask who it is, make its card
#   scripts/dock-tags.sh /dev/cu.usbmodem101           a box already flashed: ask, make its card
#   scripts/dock-tags.sh 0A1B2C3D 44556677             a card per box id, no box needed
#   scripts/dock-tags.sh --reprint 0A1B2C3D            that box's card again, same key
#   scripts/dock-tags.sh                               a prototype card naming no box
#
#   --print <printer>   also send each card to that printer (lp), two-sided
#
# For each box: a fresh secret, its code (https://<LINK_DOMAIN>/p/<secret>?b=<id>),
# a row in boxes.csv, the code drawn as box-<id>.png, and its card as
# card-<id>.pdf — the postcard in scripts/card/, A6, front and back — all in
# the directory this is run from. docs/DOCK.md, "At the factory", has the
# station's one-time setup.
#
# Each box knows its identity — `Portside-` and the last four bytes of its
# radio's address — and says it over USB at power-on, or when sent `i`
# (firmware/box/box.ino). The card carries it (`?b=<id>`), so a phone pairs
# with that box and no other. A card made from the box that's plugged in can
# only belong to that box.
#
# One secret per box, never reused: it is the box's join credential, and the
# first phone to read it makes its place (`dock_place`, migrations 0013 and
# 0017). boxes.csv keeps every one — the card is the box's key, and
# `--reprint` makes it again from there when it's lost — so keep that file
# private, and out of git (.gitignore does).
#
# Mac only: the QR is drawn by Core Image and the card printed by Chrome.
# The domain is read from project.yml; cards carry the testing address until
# the real one is set there.
set -euo pipefail
here=$PWD
cd "$(dirname "$0")/.."
repo=$PWD

domain=$(sed -n 's/^[[:space:]]*LINK_DOMAIN:[[:space:]]*\([^[:space:]#]*\).*/\1/p' project.yml | head -1)
[ -n "$domain" ] || { echo "No LINK_DOMAIN in project.yml" >&2; exit 1; }
csv="$here/boxes.csv"
# The desk's board until the production one is chosen; set BOX_FQBN for another.
fqbn=${BOX_FQBN:-esp32:esp32:esp32s3:CDCOnBoot=cdc}
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

die() { echo "$*" >&2; exit 1; }

flash=false printer="" reprint=false args=()
while [ $# -gt 0 ]; do
  case $1 in
    --flash)   flash=true ;;
    --reprint) reprint=true ;;
    --print)   [ $# -ge 2 ] || die "--print needs a printer (lpstat -p lists them)"; printer=$2; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    -*)        die "Unknown option $1" ;;
    *)         args+=("$1") ;;
  esac
  shift
done

# ---------------------------------------------------------------- flashing

cli() {
  if command -v arduino-cli >/dev/null; then arduino-cli "$@"
  else "/Applications/Arduino IDE.app/Contents/Resources/app/lib/backend/resources/arduino-cli" "$@"; fi
}

# Once per run. Into a scratch folder: firmware/box/build/ is the IDE's, and a
# station run mustn't change anything in the repo.
built=false
build() {
  $built && return
  echo "Building firmware/box for ${fqbn}…"
  local log=$work/compile.log
  cli compile --fqbn "$fqbn" --build-path "$work/build" firmware/box >"$log" 2>&1 \
    || { cat "$log" >&2; die "The firmware didn't compile. No card made."; }
  grep 'Sketch uses' "$log" || true
  built=true
}

flash_box() { # port
  build
  echo "Flashing ${1}…"
  local log=$work/upload.log
  if ! cli upload --fqbn "$fqbn" --input-dir "$work/build" -p "$1" firmware/box >"$log" 2>&1; then
    cat "$log" >&2
    grep -q 'This chip is' "$log" && echo "Set BOX_FQBN to this board (it's $fqbn now)." >&2
    die "The upload failed. No card made."
  fi
  # It restarts, and may come back as a new port for a moment.
  local until=$((SECONDS + 10))
  while [ ! -e "$1" ] && [ "$SECONDS" -lt "$until" ]; do sleep 0.5; done
}

# The id of the box on a serial port: it says `Portside-XXXXXXXX` when it
# starts and when sent `i`. Opening the port restarts some boards, so it keeps
# asking, and takes whichever line comes first.
ask() { # port
  local port=$1 line id=""
  [ -e "$port" ] || die "No box at $port"
  stty -f "$port" 115200 raw -echo 2>/dev/null || stty -F "$port" 115200 raw -echo
  exec 3<>"$port"
  local until=$((SECONDS + 15))
  while [ -z "$id" ] && [ "$SECONDS" -lt "$until" ]; do
    printf 'i' >&3
    if IFS= read -r -t 1 line <&3 && [[ $line =~ Portside-([0-9A-Fa-f]{8}) ]]; then
      id=${BASH_REMATCH[1]}
    fi
  done
  exec 3<&-
  [ -n "$id" ] || die "No box answered on $port. Is it flashed with firmware 0.6 or later?"
  echo "$id" | tr 'a-f' 'A-F'
}

# ---------------------------------------------------------------- the card

# The box's code as a QR: error correction M, a quiet margin of four modules.
draw() { # link, file
  [ "$(uname)" = Darwin ] && command -v swift >/dev/null || die "Drawing the code needs a Mac."
  swift - "$1" "$2" <<'SWIFT'
import CoreImage
import Foundation
let args = CommandLine.arguments
let qr = CIFilter(name: "CIQRCodeGenerator")!
qr.setValue(Data(args[1].utf8), forKey: "inputMessage")
qr.setValue("M", forKey: "inputCorrectionLevel")
// A white margin: a camera finds a code by its quiet edge.
let code = qr.outputImage!.transformed(by: CGAffineTransform(scaleX: 16, y: 16))
let image = code.composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -48, dy: -48)))
try! CIContext().writePNGRepresentation(of: image, to: URL(fileURLWithPath: args[2]),
                                        format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
SWIFT
}

# "No app yet? …" only once the page that scan opens can send someone to the
# app (STORE_URL in links/index.html). Until then it would be untrue.
store_line() {
  local url
  url=$(sed -n 's/.*var STORE_URL = "\([^"]*\)".*/\1/p' links/index.html | head -1)
  [ -n "$url" ] && echo "No app yet? The same scan takes you to it." || true
}

card() { # code link, box id or empty, pdf
  local code=$1 id=$2 pdf=$3 png html=$work/card.html
  [ -x "$chrome" ] || die "No Chrome at $chrome (set CHROME). The card is printed by it."
  png=$here/box-${id:-code}.png
  draw "$code" "$png"
  python3 - "$repo/scripts/card" "$png" "${id:+Box $id}" "$(store_line)" "$html" <<'PY'
import base64, sys
card, png, box, store, out = sys.argv[1:]
def uri(path, kind):
    return "data:%s;base64,%s" % (kind, base64.b64encode(open(path, "rb").read()).decode())
html = open(card + "/postcard.html").read()
for key, value in {
    "{{FRAUNCES}}": uri(card + "/fonts/Fraunces.ttf", "font/ttf"),
    "{{WORKSANS}}": uri(card + "/fonts/WorkSans.ttf", "font/ttf"),
    "{{QR}}": uri(png, "image/png"),
    "{{BOX}}": box,
    "{{STORE}}": store,
}.items():
    assert key in html, key
    html = html.replace(key, value)
open(out, "w").write(html)
PY
  "$chrome" --headless --disable-gpu --no-pdf-header-footer --virtual-time-budget=5000 \
    --print-to-pdf="$pdf" "file://$html" >/dev/null 2>&1 \
    || die "Chrome couldn't print the card."
  # A card in a fallback font is one nobody notices until a thousand are made.
  for font in Fraunces WorkSans; do
    LC_ALL=C grep -aq "$font" "$pdf" || die "$pdf isn't in $font — check scripts/card/fonts."
  done
  echo "card    $pdf"
  if [ -n "$printer" ]; then
    lp -d "$printer" -o media=A6 -o sides=two-sided-long-edge "$pdf" >/dev/null \
      || die "Couldn't send $pdf to $printer (lpstat -p lists printers)."
    echo "        sent to $printer"
  fi
}

# ---------------------------------------------------------------- a box

one() { # id, or empty for a card that names no box
  local id=$1 query="" secret code
  [ -n "$id" ] && query="?b=$id"
  # 32 random bytes, URL-safe — the same shape as the server's codes (0025).
  secret=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n')
  code="https://$domain/p/$secret$query"
  [ -n "$id" ] && echo "box     Portside-$id"
  echo "code    $code"
  if [ -n "$id" ]; then
    # Written before the card, so a card that fails to print still leaves
    # the box's key kept: --reprint makes the card from it.
    [ -f "$csv" ] || echo "box,code" > "$csv"
    echo "Portside-$id,$code" >> "$csv"
    card "$code" "$id" "$here/card-$id.pdf"
  else
    card "$code" "" "$here/card-prototype.pdf"
  fi
  echo
}

again() { # id: its card from boxes.csv, the same key, no new row
  local id=$1 code
  [ -f "$csv" ] || die "No boxes.csv here: run this where the boxes were made."
  code=$(grep "^Portside-$id," "$csv" | head -1 | cut -d, -f2 || true)
  [ -n "$code" ] || die "Portside-$id isn't in boxes.csv."
  echo "box     Portside-$id (again)"
  echo "code    $code"
  card "$code" "$id" "$here/card-$id.pdf"
  echo
}

# Everything a card needs, before any box gets a key: a row in boxes.csv for
# a card that can't be made is a box to remember to come back to.
[ "$(uname)" = Darwin ] && command -v swift >/dev/null || die "The station is a Mac: the code is drawn by Core Image."
[ -x "$chrome" ] || die "No Chrome at $chrome (set CHROME). The card is printed by it."
command -v python3 >/dev/null || die "No python3: install the Xcode command-line tools."
if [ -n "$printer" ]; then
  lpstat -p "$printer" >/dev/null 2>&1 || die "No printer called $printer (lpstat -p lists them)."
fi

[ ${#args[@]} -gt 0 ] || { $flash || $reprint && die "Which box? Give a port or an id."; one ""; exit 0; }

for arg in "${args[@]}"; do
  if [ -e "$arg" ]; then
    $flash && flash_box "$arg"
    id=$(ask "$arg")
  else
    $flash && die "$arg isn't a port, and only a box plugged in can be flashed"
    id=$(echo "$arg" | tr 'a-f' 'A-F')
  fi
  [[ $id =~ ^[0-9A-F]{8}$ ]] || die "$arg isn't a box id (eight hex digits) or a serial port"
  if $reprint; then again "$id"; continue; fi
  # A box already in boxes.csv has its secret; a second would be a second box.
  if [ -f "$csv" ] && grep -q "^Portside-$id," "$csv"; then
    echo "Portside-$id is already in boxes.csv; skipped (--reprint makes its card again)" >&2; continue
  fi
  one "$id"
done
[ -f "$csv" ] && echo "boxes.csv: $(($(wc -l < "$csv") - 1)) boxes" || true
