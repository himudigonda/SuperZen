import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "scripts/dmg_assets/background.png"
let outputURL = URL(fileURLWithPath: outputPath)
let size = NSSize(width: 760, height: 420)

let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let base = NSColor(calibratedWhite: 0.93, alpha: 1.0)
base.setFill()
rect.fill()

let topGlow = NSGradient(
  colors: [
    NSColor(calibratedRed: 0.62, green: 0.75, blue: 1.0, alpha: 0.24),
    NSColor(calibratedWhite: 1.0, alpha: 0.0),
  ]
)
topGlow?.draw(in: NSRect(x: 0, y: 250, width: size.width, height: 170), angle: 90)

let arrowPath = NSBezierPath()
arrowPath.lineWidth = 8
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.move(to: NSPoint(x: 320, y: 215))
arrowPath.curve(
  to: NSPoint(x: 462, y: 215),
  controlPoint1: NSPoint(x: 368, y: 245),
  controlPoint2: NSPoint(x: 420, y: 245)
)
NSColor(calibratedWhite: 0.15, alpha: 0.9).setStroke()
arrowPath.stroke()

let head = NSBezierPath()
head.lineWidth = 8
head.lineCapStyle = .round
head.lineJoinStyle = .round
head.move(to: NSPoint(x: 462, y: 215))
head.line(to: NSPoint(x: 444, y: 228))
head.move(to: NSPoint(x: 462, y: 215))
head.line(to: NSPoint(x: 444, y: 202))
head.stroke()

let title = "Drag SuperZen to Applications"
let subtitle = "Install by dropping the app icon on the folder"

let titleAttrs: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
  .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 0.95),
]
let subtitleAttrs: [NSAttributedString.Key: Any] = [
  .font: NSFont.systemFont(ofSize: 14, weight: .medium),
  .foregroundColor: NSColor(calibratedWhite: 0.2, alpha: 0.75),
]

let titleSize = title.size(withAttributes: titleAttrs)
let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)

title.draw(
  at: NSPoint(x: (size.width - titleSize.width) / 2, y: 348),
  withAttributes: titleAttrs
)
subtitle.draw(
  at: NSPoint(x: (size.width - subtitleSize.width) / 2, y: 324),
  withAttributes: subtitleAttrs
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiff),
  let png = bitmap.representation(using: .png, properties: [:])
else {
  fputs("Failed to generate DMG background image.\n", stderr)
  exit(1)
}

try FileManager.default.createDirectory(
  at: outputURL.deletingLastPathComponent(),
  withIntermediateDirectories: true
)
try png.write(to: outputURL)
