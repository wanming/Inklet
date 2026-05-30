#!/usr/bin/env swift

import AppKit
import Foundation

struct IconOutput {
    let filename: String
    let size: Int
}

let fileManager = FileManager.default
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let repositoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let assetsURL = repositoryURL.appendingPathComponent("Assets", isDirectory: true)
let sourceURL = assetsURL.appendingPathComponent("PenNib.svg")
let iconsetURL = assetsURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let previewURL = assetsURL.appendingPathComponent("AppIcon-preview.png")
let icnsURL = assetsURL.appendingPathComponent("AppIcon.icns")
let outputs = [
    IconOutput(filename: "icon_16x16.png", size: 16),
    IconOutput(filename: "icon_16x16@2x.png", size: 32),
    IconOutput(filename: "icon_32x32.png", size: 32),
    IconOutput(filename: "icon_32x32@2x.png", size: 64),
    IconOutput(filename: "icon_128x128.png", size: 128),
    IconOutput(filename: "icon_128x128@2x.png", size: 256),
    IconOutput(filename: "icon_256x256.png", size: 256),
    IconOutput(filename: "icon_256x256@2x.png", size: 512),
    IconOutput(filename: "icon_512x512.png", size: 512),
    IconOutput(filename: "icon_512x512@2x.png", size: 1024)
]

func strokeWidth(for size: Int) -> String {
    switch size {
    case ...32:
        return "2.2"
    case ...64:
        return "1.95"
    default:
        return "1.7"
    }
}

func renderIcon(svg: String, size: Int, outputURL: URL) throws {
    let adjustedSVG = svg.replacingOccurrences(
        of: #"stroke-width="1.7""#,
        with: #"stroke-width="\#(strokeWidth(for: size))""#
    )
    guard let sourceImage = NSImage(data: Data(adjustedSVG.utf8)) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    guard let representation = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    representation.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let inset = CGFloat(size) * 0.11
    sourceImage.draw(
        in: NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2),
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )

    guard let pngData = representation.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try pngData.write(to: outputURL)
}

let svg = try String(contentsOf: sourceURL, encoding: .utf8)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for output in outputs {
    try renderIcon(
        svg: svg,
        size: output.size,
        outputURL: iconsetURL.appendingPathComponent(output.filename)
    )
}
try renderIcon(svg: svg, size: 2048, outputURL: previewURL)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try iconutil.run()
iconutil.waitUntilExit()

guard iconutil.terminationStatus == 0 else {
    throw CocoaError(.fileWriteUnknown)
}

print("Generated \(outputs.count) iconset PNGs, AppIcon-preview.png, and AppIcon.icns")
