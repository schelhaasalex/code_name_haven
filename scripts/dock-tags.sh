#!/usr/bin/env bash
# A box's links: the four slot tags and the code printed on its card, under one
# fresh secret per box.
#
#   scripts/dock-tags.sh                     one box, its card naming no radio
#   scripts/dock-tags.sh 0A1B2C3D 44556677   a box per id, each card naming its radio
#   scripts/dock-tags.sh /dev/cu.usbmodem101 asks the box plugged in there who it is
#
# The factory way is the last two. Each box knows its identity — `Portside-`
# and the last four bytes of its radio's address — and prints it over USB at
# power-on, or when sent `i` (firmware/box/box.ino). A card that carries it
# (`?b=<id>`) pairs a phone with that box and no other, so two boxes side by
# side on a line, a shelf or in one house can't be mixed up. A card without it
# pairs with the closest box, as the first ones did.
#
# For each box: its links on screen, a row in boxes.csv (box, code, slot 1–4 —
# the file a tag encoder or card printer asks for), and its code drawn as
# box-<id>.png, in the directory this is run from. One box with no id writes
# box-code.png and no row, as before.
#
# One secret per box, never reused: it is the box's join credential, and the
# first phone to read any of its links makes its place (`dock_place`,
# migrations 0013 and 0017). A tag starts the evening; the code only pairs.
#
# Never lock the tags while LINK_DOMAIN is a testing address: a locked tag
# can't be told where the links moved. The domain is read from project.yml,
# so a production run made after the real one is set carries it.
set -euo pipefail
here=$PWD
cd "$(dirname "$0")/.."

domain=$(sed -n 's/^[[:space:]]*LINK_DOMAIN:[[:space:]]*\([^[:space:]#]*\).*/\1/p' project.yml | head -1)
[ -n "$domain" ] || { echo "No LINK_DOMAIN in project.yml" >&2; exit 1; }
csv="$here/boxes.csv"

# The box's code as a QR image. Drawn by Core Image, so nothing needs
# installing on a Mac; anywhere else the links are still printed and written to
# boxes.csv, which a card printer can draw codes from.
draw() { # link, file
  if ! command -v swift >/dev/null || [ "$(uname)" != Darwin ]; then
    echo "        (no QR image: draw it on a Mac, or from boxes.csv)"; return
  fi
  swift - "$1" "$2" <<'SWIFT' && echo "        $2"
import CoreImage
import Foundation
let args = CommandLine.arguments
let qr = CIFilter(name: "CIQRCodeGenerator")!
qr.setValue(Data(args[1].utf8), forKey: "inputMessage")
qr.setValue("M", forKey: "inputCorrectionLevel")
// A white margin four modules wide: a camera finds a code by its quiet edge.
let code = qr.outputImage!.transformed(by: CGAffineTransform(scaleX: 16, y: 16))
let image = code.composited(over: CIImage(color: .white).cropped(to: code.extent.insetBy(dx: -64, dy: -64)))
let context = CIContext()
try! context.writePNGRepresentation(of: image, to: URL(fileURLWithPath: args[2]),
                                    format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
SWIFT
}

# The id of the box on a serial port: it says `Portside-XXXXXXXX` when it
# starts and when sent `i`. Opening the port restarts some boards, so it keeps
# asking, and takes whichever line comes first.
ask() { # port
  local port=$1 line id=""
  stty -f "$port" 115200 raw -echo 2>/dev/null || stty -F "$port" 115200 raw -echo
  exec 3<>"$port"
  local until=$((SECONDS + 8))
  while [ -z "$id" ] && [ "$SECONDS" -lt "$until" ]; do
    printf 'i' >&3
    if IFS= read -r -t 1 line <&3 && [[ $line =~ Portside-([0-9A-Fa-f]{8}) ]]; then
      id=${BASH_REMATCH[1]}
    fi
  done
  exec 3<&-
  [ -n "$id" ] || { echo "No box answered on $port. Is it flashed with firmware 0.6 or later?" >&2; exit 1; }
  echo "$id" | tr 'a-f' 'A-F'
}

one() { # id, or empty for a card that names no radio
  local id=$1 query="" secret code slot links=()
  [ -n "$id" ] && query="?b=$id"
  # 32 random bytes, URL-safe — the same shape as `Handle.newSecret()`.
  secret=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n')
  [ -n "$id" ] && echo "box     Portside-$id"
  for slot in 1 2 3 4; do
    links+=("https://$domain/p/$secret/$slot$query")
    echo "slot $slot  ${links[$((slot - 1))]}"
  done
  code="https://$domain/p/$secret$query"
  echo "code    $code"
  if [ -n "$id" ]; then
    [ -f "$csv" ] || echo "box,code,slot1,slot2,slot3,slot4" > "$csv"
    echo "Portside-$id,$code,${links[0]},${links[1]},${links[2]},${links[3]}" >> "$csv"
    draw "$code" "$here/box-$id.png"
  else
    draw "$code" "$here/box-code.png"
  fi
  echo
}

[ $# -gt 0 ] || { one ""; exit 0; }

for arg in "$@"; do
  if [ -e "$arg" ]; then id=$(ask "$arg"); else id=$(echo "$arg" | tr 'a-f' 'A-F'); fi
  [[ $id =~ ^[0-9A-F]{8}$ ]] || { echo "$arg isn't a box id (eight hex digits) or a serial port" >&2; exit 1; }
  # A box already in boxes.csv has its secret; a second would be a second box.
  if [ -f "$csv" ] && grep -q "^Portside-$id," "$csv"; then
    echo "Portside-$id is already in boxes.csv; skipped" >&2; continue
  fi
  one "$id"
done
[ -f "$csv" ] && echo "boxes.csv: $(($(wc -l < "$csv") - 1)) boxes"
