#!/usr/bin/env swift
// Generates the Prénomme app icon at all required iOS sizes using AppKit/CoreGraphics.
// Usage: swift Scripts/GenerateAppIcon.swift
// Requires macOS (uses NSImage/NSBezierPath).

import AppKit
import Foundation

// MARK: — Colors (terracotta → sage gradient)
let terracotta = CGColor(red: 0.79, green: 0.48, blue: 0.39, alpha: 1)
let sage        = CGColor(red: 0.61, green: 0.69, blue: 0.53, alpha: 1)

// MARK: — Sizes to generate
// (filename, pixels) — all are integer pixel sizes
let sizes: [(name: String, px: Int)] = [
    ("icon-20@1x",   20),
    ("icon-20@2x",   40),
    ("icon-20@3x",   60),
    ("icon-29@1x",   29),
    ("icon-29@2x",   58),
    ("icon-29@3x",   87),
    ("icon-40@1x",   40),
    ("icon-40@2x",   80),
    ("icon-40@3x",   120),
    ("icon-60@2x",   120),
    ("icon-60@3x",   180),
    ("icon-76@1x",   76),
    ("icon-76@2x",   152),
    ("icon-83.5@2x", 167),
    ("icon-1024",    1024),
]

// MARK: — Output directory
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()
    .deletingLastPathComponent()  // from Scripts/ → project root

let logoDir = scriptDir.appendingPathComponent("Resources/Logo")
let assetsDir = scriptDir
    .appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")

let fm = FileManager.default
try! fm.createDirectory(at: logoDir,   withIntermediateDirectories: true)
try! fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)

// MARK: — Drawing (opaque RGB — no alpha, Apple requirement)

func renderIcon(size: Int) -> Data {
    let s = size
    let fSize = CGFloat(s)

    // Create a CGBitmapContext with RGB (no alpha) using noneSkipLast
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
    let ctx = CGContext(
        data: nil,
        width: s, height: s,
        bitsPerComponent: 8,
        bytesPerRow: s * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    )!

    // --- Background gradient (top-left terracotta → bottom-right sage) ---
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [terracotta, sage] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0,     y: fSize),
        end:   CGPoint(x: fSize, y: 0),
        options: []
    )

    // --- Letter "P" — draw via NSGraphicsContext wrapper so NSString works ---
    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.current = nsCtx

    let fontSize = fSize * 0.58
    let font = NSFont(name: "SFProRounded-Bold", size: fontSize)
        ?? NSFont(name: ".AppleSystemUIFontRounded", size: fontSize)
        ?? NSFont.boldSystemFont(ofSize: fontSize)

    let whiteAttrs: [NSAttributedString.Key: Any] = [
        .font:            font,
        .foregroundColor: NSColor.white,
    ]
    let shadowAttrs: [NSAttributedString.Key: Any] = [
        .font:            font,
        .foregroundColor: NSColor.black.withAlphaComponent(0.22),
    ]
    let str = "P" as NSString
    let textSize = str.size(withAttributes: whiteAttrs)
    let tx = (fSize - textSize.width)  / 2
    let ty = (fSize - textSize.height) / 2

    // Shadow offset
    str.draw(
        in: NSRect(x: tx + 1.5, y: ty - 2, width: textSize.width, height: textSize.height),
        withAttributes: shadowAttrs
    )
    // White "P"
    str.draw(
        in: NSRect(x: tx, y: ty, width: textSize.width, height: textSize.height),
        withAttributes: whiteAttrs
    )

    NSGraphicsContext.restoreGraphicsState()

    // Export as PNG via CGImageDestination
    let cgImage = ctx.makeImage()!
    let mutableData = NSMutableData()
    let dest = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, cgImage, nil)
    CGImageDestinationFinalize(dest)
    return mutableData as Data
}

// MARK: — Generate all sizes

print("Generating app icons…")
for (name, px) in sizes {
    let data = renderIcon(size: px)
    let destAssets = assetsDir.appendingPathComponent("\(name).png")
    let destLogo   = logoDir.appendingPathComponent("\(name).png")
    try! data.write(to: destAssets, options: .atomic)
    try! data.write(to: destLogo,   options: .atomic)
    print("  ✓ \(name)  (\(px)×\(px))")
}

// Copy 1024 as AppIcon-1024.png
let src  = logoDir.appendingPathComponent("icon-1024.png")
let dst  = logoDir.appendingPathComponent("AppIcon-1024.png")
if fm.fileExists(atPath: dst.path) { try! fm.removeItem(at: dst) }
try! fm.copyItem(at: src, to: dst)

// MARK: — Write Contents.json

let contentsJSON = """
{
  "images" : [
    { "filename" : "icon-20@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "20x20"   },
    { "filename" : "icon-20@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "20x20"   },
    { "filename" : "icon-29@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "29x29"   },
    { "filename" : "icon-29@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "29x29"   },
    { "filename" : "icon-40@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "40x40"   },
    { "filename" : "icon-40@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "40x40"   },
    { "filename" : "icon-60@2x.png",   "idiom" : "iphone", "scale" : "2x", "size" : "60x60"   },
    { "filename" : "icon-60@3x.png",   "idiom" : "iphone", "scale" : "3x", "size" : "60x60"   },
    { "filename" : "icon-20@1x.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "20x20"   },
    { "filename" : "icon-20@2x.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "20x20"   },
    { "filename" : "icon-29@1x.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "29x29"   },
    { "filename" : "icon-29@2x.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "29x29"   },
    { "filename" : "icon-40@1x.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "40x40"   },
    { "filename" : "icon-40@2x.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "40x40"   },
    { "filename" : "icon-76@1x.png",   "idiom" : "ipad",   "scale" : "1x", "size" : "76x76"   },
    { "filename" : "icon-76@2x.png",   "idiom" : "ipad",   "scale" : "2x", "size" : "76x76"   },
    { "filename" : "icon-83.5@2x.png", "idiom" : "ipad",   "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "icon-1024.png",    "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""

let contentsURL = assetsDir.appendingPathComponent("Contents.json")
try! contentsJSON.write(to: contentsURL, atomically: true, encoding: .utf8)
print("  ✓ Contents.json updated")

// SVG source (for reference / future editing)
let svgSource = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#CA7A64"/>
      <stop offset="100%" style="stop-color:#9CAF88"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>
  <text x="512" y="680"
        font-family="SF Pro Rounded, -apple-system, Helvetica Neue, Helvetica, Arial, sans-serif"
        font-size="590" font-weight="bold"
        text-anchor="middle" fill="white"
        fill-opacity="1">P</text>
</svg>
"""
let svgURL = logoDir.appendingPathComponent("logo-source.svg")
try! svgSource.write(to: svgURL, atomically: true, encoding: .utf8)
print("  ✓ logo-source.svg written")

print("\nDone. All icons saved to Resources/Assets.xcassets/AppIcon.appiconset/")
