#!/usr/bin/env swift
import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Sources/DingdangPetApp/Resources/DefaultCatalog/pets/dingdang/spritesheet.png"
let cell = 64
let columns = 8
let rows = 7
let width = cell * columns
let height = cell * rows

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fatalError("Cannot create bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

func cellOrigin(row: Int, column: Int) -> NSPoint {
    NSPoint(x: column * cell, y: height - (row + 1) * cell)
}

func ellipse(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func path(_ points: [NSPoint], color: NSColor) {
    guard let first = points.first else { return }
    let p = NSBezierPath()
    p.move(to: first)
    for point in points.dropFirst() { p.line(to: point) }
    p.close()
    color.setFill()
    p.fill()
}

func drawPet(row: Int, column: Int, bob: CGFloat = 0, lean: CGFloat = 0, paw: CGFloat = 0, gaze: NSPoint = .zero, squash: CGFloat = 0) {
    let o = cellOrigin(row: row, column: column)
    let purple = NSColor(calibratedRed: 0.38, green: 0.24, blue: 0.78, alpha: 1)
    let light = NSColor(calibratedRed: 0.75, green: 0.66, blue: 1, alpha: 1)
    let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
    let bodyHeight = 30 - squash
    let bodyY = o.y + 9 + bob
    ellipse(NSRect(x: o.x + 17 + lean, y: bodyY, width: 30, height: bodyHeight), color: purple)
    path([
        NSPoint(x: o.x + 20 + lean, y: bodyY + bodyHeight - 2),
        NSPoint(x: o.x + 24 + lean, y: bodyY + bodyHeight + 12),
        NSPoint(x: o.x + 31 + lean, y: bodyY + bodyHeight + 2)
    ], color: purple)
    path([
        NSPoint(x: o.x + 35 + lean, y: bodyY + bodyHeight + 2),
        NSPoint(x: o.x + 42 + lean, y: bodyY + bodyHeight + 12),
        NSPoint(x: o.x + 45 + lean, y: bodyY + bodyHeight - 2)
    ], color: purple)
    ellipse(NSRect(x: o.x + 19 + lean, y: bodyY + bodyHeight - 8, width: 26, height: 21), color: purple)
    ellipse(NSRect(x: o.x + 24 + lean, y: bodyY + bodyHeight + 1, width: 7, height: 8), color: light)
    ellipse(NSRect(x: o.x + 35 + lean, y: bodyY + bodyHeight + 1, width: 7, height: 8), color: light)
    ellipse(NSRect(x: o.x + 27 + lean + gaze.x, y: bodyY + bodyHeight + 3 + gaze.y, width: 3, height: 4), color: ink)
    ellipse(NSRect(x: o.x + 38 + lean + gaze.x, y: bodyY + bodyHeight + 3 + gaze.y, width: 3, height: 4), color: ink)
    ellipse(NSRect(x: o.x + 30 + lean, y: bodyY + bodyHeight - 2, width: 6, height: 4), color: light)
    ellipse(NSRect(x: o.x + 10 + lean, y: bodyY + 11 + paw, width: 12, height: 10), color: purple)
    ellipse(NSRect(x: o.x + 42 + lean, y: bodyY + 11 - paw, width: 12, height: 10), color: purple)
    ellipse(NSRect(x: o.x + 20 + lean, y: bodyY - 3, width: 11, height: 8), color: purple)
    ellipse(NSRect(x: o.x + 35 + lean, y: bodyY - 3, width: 11, height: 8), color: purple)
}

for c in 0..<4 { drawPet(row: 0, column: c, bob: c % 2 == 0 ? 0 : 1, squash: c % 2 == 0 ? 0 : 1) }
for c in 0..<6 { drawPet(row: 1, column: c, bob: c % 2 == 0 ? 0 : 2, lean: 2, paw: c % 2 == 0 ? 2 : -2) }
for c in 0..<6 { drawPet(row: 2, column: c, bob: c % 2 == 0 ? 0 : 2, lean: -2, paw: c % 2 == 0 ? -2 : 2) }
for c in 0..<5 { drawPet(row: 3, column: c, paw: CGFloat([0, 8, 13, 8, 0][c])) }
for c in 0..<6 { drawPet(row: 4, column: c, bob: CGFloat([0, 4, 9, 11, 5, 0][c]), squash: CGFloat([2, 0, 0, 0, 0, 3][c])) }
for c in 0..<4 { drawPet(row: 5, column: c, bob: -3, lean: CGFloat(c - 2), squash: 7) }

let directions: [NSPoint] = [
    NSPoint(x: 0, y: 2), NSPoint(x: 1.5, y: 1.5), NSPoint(x: 2, y: 0), NSPoint(x: 1.5, y: -1.5),
    NSPoint(x: 0, y: -2), NSPoint(x: -1.5, y: -1.5), NSPoint(x: -2, y: 0), NSPoint(x: -1.5, y: 1.5)
]
for c in 0..<8 { drawPet(row: 6, column: c, lean: directions[c].x, gaze: directions[c]) }

NSGraphicsContext.restoreGraphicsState()
let destination = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode PNG") }
try png.write(to: destination)
print(destination.path)
