import AppKit
import Foundation

enum IconDrawing {
    static func makeIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let canvas = NSRect(x: 0, y: 0, width: size, height: size)
        NSColor(calibratedRed: 0.96, green: 0.91, blue: 0.78, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: canvas, xRadius: size * 0.22, yRadius: size * 0.22).fill()

        let pageRect = canvas.insetBy(dx: size * 0.12, dy: size * 0.1)
        let pageShadow = NSShadow()
        pageShadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
        pageShadow.shadowBlurRadius = size * 0.03
        pageShadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
        pageShadow.set()

        NSColor(calibratedWhite: 0.99, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: pageRect, xRadius: size * 0.065, yRadius: size * 0.065).fill()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: pageRect, xRadius: size * 0.065, yRadius: size * 0.065).addClip()

        let foldSize = size * 0.13
        let foldPath = NSBezierPath()
        foldPath.move(to: NSPoint(x: pageRect.maxX - foldSize, y: pageRect.maxY))
        foldPath.line(to: NSPoint(x: pageRect.maxX, y: pageRect.maxY - foldSize))
        foldPath.line(to: NSPoint(x: pageRect.maxX, y: pageRect.maxY))
        foldPath.close()
        NSColor(calibratedWhite: 0.92, alpha: 1.0).setFill()
        foldPath.fill()

        let marginX = pageRect.minX + size * 0.11
        let marginPath = NSBezierPath()
        marginPath.move(to: NSPoint(x: marginX, y: pageRect.minY + size * 0.05))
        marginPath.line(to: NSPoint(x: marginX, y: pageRect.maxY - size * 0.05))
        marginPath.lineWidth = max(2, size * 0.006)
        NSColor(calibratedRed: 0.88, green: 0.48, blue: 0.43, alpha: 0.85).setStroke()
        marginPath.stroke()

        let lineColor = NSColor(calibratedRed: 0.62, green: 0.77, blue: 0.95, alpha: 0.62)
        for index in 0..<7 {
            let y = pageRect.maxY - size * (0.19 + CGFloat(index) * 0.096)
            let ruledLine = NSBezierPath()
            ruledLine.move(to: NSPoint(x: pageRect.minX + size * 0.06, y: y))
            ruledLine.line(to: NSPoint(x: pageRect.maxX - size * 0.06, y: y))
            ruledLine.lineWidth = max(1.5, size * 0.004)
            lineColor.setStroke()
            ruledLine.stroke()
        }

        let scribbleColor = NSColor(calibratedRed: 0.13, green: 0.29, blue: 0.62, alpha: 0.98)
        let scribbleRows: [(CGFloat, [CGFloat])] = [
            (0.27, [0.15, 0.23, 0.34, 0.46, 0.60, 0.73, 0.85]),
            (0.38, [0.17, 0.29, 0.41, 0.53, 0.65, 0.76, 0.87]),
            (0.49, [0.16, 0.27, 0.39, 0.50, 0.62, 0.74, 0.85]),
            (0.60, [0.18, 0.30, 0.43, 0.55, 0.68, 0.80])
        ]
        for (row, points) in scribbleRows {
            let baseline = pageRect.maxY - size * row
            let scribble = NSBezierPath()
            scribble.move(to: NSPoint(x: pageRect.minX + size * points[0], y: baseline))
            for (index, point) in points.dropFirst().enumerated() {
                let previous = points[index]
                let x = pageRect.minX + size * point
                let previousX = pageRect.minX + size * previous
                let midX = (previousX + x) / 2
                let amplitude = size * (index.isMultiple(of: 2) ? 0.02 : -0.018)
                scribble.curve(
                    to: NSPoint(x: x, y: baseline + amplitude * 0.35),
                    controlPoint1: NSPoint(x: midX - size * 0.03, y: baseline + amplitude),
                    controlPoint2: NSPoint(x: midX + size * 0.02, y: baseline - amplitude * 0.7)
                )
            }
            scribble.lineWidth = max(7, size * 0.018)
            scribble.lineCapStyle = .round
            scribble.lineJoinStyle = .round
            scribbleColor.setStroke()
            scribble.stroke()
        }

        let underline = NSBezierPath()
        underline.move(to: NSPoint(x: pageRect.minX + size * 0.19, y: pageRect.minY + size * 0.19))
        underline.curve(
            to: NSPoint(x: pageRect.minX + size * 0.56, y: pageRect.minY + size * 0.17),
            controlPoint1: NSPoint(x: pageRect.minX + size * 0.28, y: pageRect.minY + size * 0.14),
            controlPoint2: NSPoint(x: pageRect.minX + size * 0.45, y: pageRect.minY + size * 0.21)
        )
        underline.lineWidth = max(7, size * 0.017)
        underline.lineCapStyle = .round
        NSColor(calibratedRed: 0.95, green: 0.68, blue: 0.22, alpha: 0.92).setStroke()
        underline.stroke()

        NSGraphicsContext.current?.restoreGraphicsState()
        image.unlockFocus()
        return image
    }
}

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let brandingDir = cwd.appendingPathComponent("Sources/Manuscript/Resources/Branding", isDirectory: true)
let iconsetDir = brandingDir.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = brandingDir.appendingPathComponent("Scribbles-N-Scripts.icns")
let sourcePNG = brandingDir.appendingPathComponent("AppIconSource1024.png")
let sourceTIFF = brandingDir.appendingPathComponent("AppIconSource1024.tiff")

try? fm.removeItem(at: iconsetDir)
try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let sourceImage = IconDrawing.makeIcon(size: 1024)
guard let tiff = sourceImage.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode source icon"])
}
try png.write(to: sourcePNG)
try tiff.write(to: sourceTIFF)

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (size, name) in variants {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = [
        "-z", "\(size)", "\(size)",
        sourcePNG.path,
        "--out", iconsetDir.appendingPathComponent(name).path
    ]
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        throw NSError(domain: "IconGen", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "sips failed for \(name)"])
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/tiff2icns")
process.arguments = [sourceTIFF.path, icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "IconGen", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "tiff2icns failed"])
}

print("Generated \(icnsURL.path)")
