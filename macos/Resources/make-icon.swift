// Draws the Buuz menu bar glyph and writes buuzTemplate.tiff (16pt @1x + @2x).
//
//   swift make-icon.swift
//
// Menu bar icons must be template images: black artwork whose alpha defines the
// shape, so macOS can tint it for light, dark, and highlighted menus.

import AppKit

func drawGlyph(size: CGFloat, scale: CGFloat) -> NSBitmapImageRep {
    let px = Int(size * scale)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    ctx.setAllowsAntialiasing(true)

    let s = size
    // Stroke stays on whole pixels at 1x so the glyph does not blur.
    let line = (s / 16.0) * 1.35
    ctx.setStrokeColor(NSColor.black.cgColor)
    ctx.setLineWidth(line)
    ctx.setLineCap(.round)

    // A bun is wider than it is tall; a circular dome reads as a wheel.
    let margin = s * 0.055 + line / 2
    let width = s - margin * 2
    let height = width * 0.84
    let twistRadius = s * 0.105
    // Solved so the dome plus the twist above it leaves equal top and bottom
    // margins, keeping the glyph centered against the system menu bar icons.
    let bottom = (s - height - twistRadius * 0.55) / 2
    let body = CGRect(x: margin, y: bottom, width: width, height: height)
    let twist = CGPoint(x: body.midX, y: body.maxY - twistRadius * 0.45)

    // Pleats bow outwards from the twist so they read as folds, not spokes.
    let radiusX = body.width / 2
    let radiusY = body.height / 2
    for degrees in [201.0, 236.0, 304.0, 339.0] {
        let radians = degrees * .pi / 180
        let end = CGPoint(x: body.midX + cos(radians) * radiusX,
                          y: body.midY + sin(radians) * radiusY)
        let spread = (end.x - twist.x) * 0.45
        ctx.move(to: twist)
        ctx.addQuadCurve(
            to: end,
            control: CGPoint(x: twist.x + spread,
                             y: twist.y + (end.y - twist.y) * 0.55))
    }
    ctx.strokePath()

    ctx.strokeEllipse(in: body)

    // Punch the twist out so the pleats do not read as a starburst.
    let twistRect = CGRect(x: twist.x - twistRadius, y: twist.y - twistRadius,
                           width: twistRadius * 2, height: twistRadius * 2)
    ctx.setBlendMode(.destinationOut)
    ctx.fillEllipse(in: twistRect.insetBy(dx: -line * 0.45, dy: -line * 0.45))
    ctx.setBlendMode(.normal)
    ctx.strokeEllipse(in: twistRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let tmp = URL(fileURLWithPath: NSTemporaryDirectory())

var stages: [String] = []
for scale in [CGFloat(1), CGFloat(2)] {
    let rep = drawGlyph(size: 16, scale: scale)
    let url = tmp.appendingPathComponent("buuz@\(Int(scale))x.tiff")
    try rep.representation(using: .tiff, properties: [:])!.write(to: url)
    stages.append(url.path)
}

// tiffutil marks the second image as the @2x representation of the first.
let out = dir.appendingPathComponent("buuzTemplate.tiff")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
task.arguments = ["-cathidpicheck"] + stages + ["-out", out.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { exit(task.terminationStatus) }
print("wrote \(out.lastPathComponent) (16px + 32px @2x, template)")
