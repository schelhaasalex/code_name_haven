// A placeholder app icon: the app's own mark — the clay ring and dot from
// Reclaim/Components/Brand.swift — on the paper ground. No name in it, because
// the name isn't settled; replace it wholesale when there's a designed icon.
//
//   swift scripts/placeholder-icon.swift
//
// Writes Reclaim/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png:
// 1024 × 1024, opaque (Apple rejects an app icon with an alpha channel).
//
// The colours are Palette.bone and Palette.clay written out a second time —
// a script can't import ReclaimKit. If the palette changes, change them here.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let bone = CGColor(srgbRed: 0xF7 / 255, green: 0xF4 / 255, blue: 0xEE / 255, alpha: 1)
let clay = CGColor(srgbRed: 0xB4 / 255, green: 0x51 / 255, blue: 0x2C / 255, alpha: 1)

// Brand draws the ring at 84% of its size with a 6.8% line, and the dot at
// 30%. The mark here is 60% of the icon, leaving the corners the system
// rounds off well clear of it.
let mark = CGFloat(side) * 0.60
let centre = CGPoint(x: CGFloat(side) / 2, y: CGFloat(side) / 2)
let ringLine = mark * 0.068
let ringDiameter = mark * 0.84 - ringLine   // stroke is centred on the path
let dotDiameter = mark * 0.30

guard let context = CGContext(
    data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fatalError("couldn't make a drawing context") }

context.setFillColor(bone)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

context.setStrokeColor(clay)
context.setLineWidth(ringLine)
context.strokeEllipse(in: CGRect(x: centre.x - ringDiameter / 2, y: centre.y - ringDiameter / 2,
                                 width: ringDiameter, height: ringDiameter))

context.setFillColor(clay)
context.fillEllipse(in: CGRect(x: centre.x - dotDiameter / 2, y: centre.y - dotDiameter / 2,
                               width: dotDiameter, height: dotDiameter))

let out = URL(fileURLWithPath: "Reclaim/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fatalError("couldn't make the image") }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("couldn't write \(out.path)") }
print("Wrote \(out.path)")
