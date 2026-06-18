// Génère AppIcon.icns pour Mousy.
// Usage : swift make-icon.swift
import AppKit

func whiteSymbol(_ name: String, pointSize: CGFloat) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
    let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        .withSymbolConfiguration(cfg)!
    let size = base.size
    let out = NSImage(size: size)
    out.lockFocus()
    base.draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

func renderIcon(pixelSize: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Squircle macOS : marge transparente + coins arrondis continus.
    let margin = size * 0.10
    let rect = NSRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
    let radius = rect.width * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Léger dégradé bleu -> indigo, du haut vers le bas.
    let top = NSColor(calibratedRed: 0.30, green: 0.56, blue: 0.98, alpha: 1)     // bleu
    let bottom = NSColor(calibratedRed: 0.36, green: 0.34, blue: 0.86, alpha: 1)  // indigo
    let gradient = NSGradient(starting: top, ending: bottom)!
    gradient.draw(in: path, angle: -90)

    // Glyphe souris centré, ~52 % de la largeur.
    let glyph = whiteSymbol("computermouse.fill", pointSize: size * 0.52)
    let gs = glyph.size
    let scale = (size * 0.52) / max(gs.width, gs.height)
    let gw = gs.width * scale
    let gh = gs.height * scale
    let gRect = NSRect(x: (size - gw) / 2, y: (size - gh) / 2, width: gw, height: gh)
    glyph.draw(in: gRect, from: NSRect(origin: .zero, size: gs), operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let iconset = "Mousy.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let variants: [(name: String, px: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x", 1024),
]

for v in variants {
    let rep = renderIcon(pixelSize: v.px)
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(v.name).png"))
}

print("iconset généré : \(iconset)")
