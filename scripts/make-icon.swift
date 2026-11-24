// Renders Doppio's app icon to a 1024×1024 PNG.
//
// Usage: swift scripts/make-icon.swift <output.png>
//
// `scripts/make-icon.sh` runs this, then turns the PNG into AppIcon.icns.
// The artwork is a warm coffee gradient squircle with the SF Symbol
// "cup.and.heat.waves.fill" on top, which is the menu bar's "awake" icon.

import AppKit

/// The output canvas size in pixels; the largest size macOS asks for.
let canvas = 1024

// `CommandLine.arguments[0]` is the script itself, so the path is at index 1.
guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.png>\n".utf8))
    exit(1)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

// Draw into a bitmap of exactly `canvas` pixels. Drawing into an `NSImage`
// would follow the screen's scale factor and could produce 2048 px on Retina.
// `!` force-unwrap: these initialisers only fail for impossible arguments.
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// Apple's macOS icon grid: an 824 pt rounded square centred on a 1024 canvas,
// leaving room for the system drop shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

// A soft shadow under the tile, so it sits on the Dock like system icons do.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

// Crema at the top to espresso at the bottom. Angle -90° runs top to bottom.
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.33, alpha: 1),
    NSColor(calibratedRed: 0.42, green: 0.22, blue: 0.11, alpha: 1),
])!
gradient.draw(in: squircle, angle: -90)

// The cup symbol, tinted cream. A palette configuration sets the symbol's colour.
let symbolConfig = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [NSColor(calibratedWhite: 0.99, alpha: 1)]))
let symbol = NSImage(systemSymbolName: "cup.and.heat.waves.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(symbolConfig)!
let size = symbol.size
let symbolRect = NSRect(
    x: (CGFloat(canvas) - size.width) / 2,
    y: (CGFloat(canvas) - size.height) / 2 - 10,
    width: size.width,
    height: size.height
)
symbol.draw(in: symbolRect)

NSGraphicsContext.restoreGraphicsState()

// `try` without `do`/`catch` at top level: an error ends the script with a
// message, which is what we want for a build tool.
try bitmap.representation(using: .png, properties: [:])!.write(to: outputURL)
print("Wrote \(outputURL.path)")
