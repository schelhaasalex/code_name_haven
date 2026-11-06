#!/usr/bin/env bash
# A new box's links, under one fresh secret: the four slot tags, and the code
# printed on the outside — as a link, and as box-code.png, in the directory
# it's run from, to print.
#
#   scripts/dock-tags.sh
#
# Write each slot link onto its slot's tag as a URL record — NFC Tools, free
# on the App Store, does it. One secret per box, never reused: it is the box's
# join credential, and the first phone to read any of them makes its place
# (`dock_place`, migrations 0013 and 0017). A tag starts the evening; the code
# only pairs a phone with the box.
#
# Never lock the tags. The domain is a testing address until there is a real
# one, and a locked tag can't be told where it moved.
set -euo pipefail
here=$PWD
cd "$(dirname "$0")/.."

domain=$(sed -n 's/^[[:space:]]*LINK_DOMAIN:[[:space:]]*\([^[:space:]#]*\).*/\1/p' project.yml | head -1)
[ -n "$domain" ] || { echo "No LINK_DOMAIN in project.yml" >&2; exit 1; }

# 32 random bytes, URL-safe — the same shape as `Handle.newSecret()`.
secret=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n')

for slot in 1 2 3 4; do
  echo "slot $slot  https://$domain/p/$secret/$slot"
done

# The code: the box with no slot. The camera opens it like a tag, and the app
# pairs with the box and starts nothing (`Dock.link`). Drawn by Core Image, so
# nothing needs installing on a Mac.
code="https://$domain/p/$secret"
echo "code    $code"
swift - "$code" "$here/box-code.png" <<'SWIFT' && echo "        $here/box-code.png"
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
