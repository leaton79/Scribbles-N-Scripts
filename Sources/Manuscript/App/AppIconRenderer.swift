import AppKit

enum AppIconRenderer {
    static func brandImage(size: CGFloat = 128) -> NSImage {
        makeAppIcon(size: size)
    }

    static func makeAppIcon(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let canvas = NSRect(x: 0, y: 0, width: size, height: size)
        let background = NSColor(calibratedRed: 0.96, green: 0.91, blue: 0.78, alpha: 1.0)
        background.setFill()
        NSBezierPath(roundedRect: canvas, xRadius: size * 0.22, yRadius: size * 0.22).fill()

        let pageRect = canvas.insetBy(dx: size * 0.12, dy: size * 0.1)
        let pageShadow = NSShadow()
        pageShadow.shadowColor = NSColor.black.withAlphaComponent(0.16)
        pageShadow.shadowBlurRadius = size * 0.03
        pageShadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
        pageShadow.set()

        let pagePath = NSBezierPath(roundedRect: pageRect, xRadius: size * 0.065, yRadius: size * 0.065)
        NSColor(calibratedWhite: 0.99, alpha: 1.0).setFill()
        pagePath.fill()

        NSGraphicsContext.current?.saveGraphicsState()
        let clipPath = NSBezierPath(roundedRect: pageRect, xRadius: size * 0.06, yRadius: size * 0.06)
        clipPath.addClip()

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
        image.isTemplate = false
        return image
    }

    static func applyToApplication() {
        if let bundled = bundledIcon() {
            NSApplication.shared.applicationIconImage = bundled
        } else {
            NSApplication.shared.applicationIconImage = makeAppIcon()
        }
    }

    private static func bundledIcon() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "Scribbles-N-Scripts", withExtension: "icns", subdirectory: "Branding"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }
}
