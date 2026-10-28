import AppKit

final class RugView: NSView {
    enum DragMode { case move, resize, lift }
    private var dragMode: DragMode = .move
    private var lastScreenPoint = NSPoint.zero
    private(set) var liftAmount: CGFloat = 0
    var onGeometryChange: (() -> Void)?

    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let inset: CGFloat = 13
        let rug = bounds.insetBy(dx: inset, dy: inset)
        let fold = min(liftAmount, min(rug.width, rug.height) * 0.58)
        let corners = NSBezierPath(roundedRect: rug, xRadius: 8, yRadius: 8)

        context.saveGState()
        let shadow = Preferences.shared.showsShadow
        if shadow { context.setShadow(offset: CGSize(width: 5, height: -7), blur: 11, color: NSColor.black.withAlphaComponent(0.42).cgColor) }
        let base = baseColor.cgColor
        context.setFillColor(base)
        context.addPath(corners.cgPath)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(corners.cgPath)
        context.clip()
        drawPattern(in: rug, context: context)
        drawBorder(in: rug, context: context)
        if fold > 2 {
            // Clear the lifted corner so Finder icons remain visible underneath.
            context.setBlendMode(.clear)
            context.beginPath()
            context.move(to: CGPoint(x: rug.maxX - fold, y: rug.maxY))
            context.addLine(to: CGPoint(x: rug.maxX, y: rug.maxY - fold))
            context.addLine(to: CGPoint(x: rug.maxX, y: rug.maxY))
            context.closePath()
            context.fillPath()
            context.setBlendMode(.normal)
        }
        context.restoreGState()

        if fold > 2 { drawFold(in: rug, amount: fold, context: context) }
        drawFringe(in: rug, context: context)
        drawHandles(in: rug, context: context)
    }

    private var baseColor: NSColor {
        switch Preferences.shared.style {
        case .persian: return NSColor(calibratedRed: 0.50, green: 0.13, blue: 0.16, alpha: Preferences.shared.opacity)
        case .kilim: return NSColor(calibratedRed: 0.71, green: 0.38, blue: 0.24, alpha: Preferences.shared.opacity)
        case .grid: return NSColor(calibratedRed: 0.22, green: 0.43, blue: 0.39, alpha: Preferences.shared.opacity)
        case .midnight: return NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.27, alpha: Preferences.shared.opacity)
        case .custom: return NSColor(calibratedWhite: 0.2, alpha: Preferences.shared.opacity)
        }
    }

    private func drawPattern(in rect: NSRect, context: CGContext) {
        if Preferences.shared.style == .custom, let path = Preferences.shared.customImagePath,
           let image = NSImage(contentsOfFile: path) {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: Preferences.shared.opacity)
            return
        }
        let gold = NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.48, alpha: Preferences.shared.opacity * 0.78).cgColor
        let cream = NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.68, alpha: Preferences.shared.opacity * 0.62).cgColor
        context.setLineWidth(2)
        switch Preferences.shared.style {
        case .persian:
            let center = CGPoint(x: rect.midX, y: rect.midY)
            for scale in [0.35, 0.25, 0.14] {
                drawDiamond(center: center, radiusX: rect.width * scale, radiusY: rect.height * scale, color: gold, context: context)
            }
            for x in stride(from: rect.minX + 34, through: rect.maxX - 20, by: 44) {
                for y in stride(from: rect.minY + 33, through: rect.maxY - 20, by: 44) {
                    let dx = abs(x - center.x) / rect.width
                    let dy = abs(y - center.y) / rect.height
                    if dx + dy > 0.43 { drawDiamond(center: CGPoint(x: x, y: y), radiusX: 8, radiusY: 11, color: cream, context: context) }
                }
            }
        case .kilim:
            for x in stride(from: rect.minX + 28, through: rect.maxX + 10, by: 54) {
                for y in stride(from: rect.minY + 25, through: rect.maxY + 10, by: 54) {
                    drawDiamond(center: CGPoint(x: x, y: y), radiusX: 19, radiusY: 25, color: gold, context: context)
                    drawDiamond(center: CGPoint(x: x, y: y), radiusX: 8, radiusY: 11, color: cream, context: context)
                }
            }
        case .grid:
            context.setStrokeColor(cream)
            context.setLineWidth(1)
            for x in stride(from: rect.minX, through: rect.maxX, by: 17) {
                context.move(to: CGPoint(x: x, y: rect.minY)); context.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            for y in stride(from: rect.minY, through: rect.maxY, by: 17) {
                context.move(to: CGPoint(x: rect.minX, y: y)); context.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            context.strokePath()
        case .midnight:
            for x in stride(from: rect.minX + 33, through: rect.maxX, by: 62) {
                for y in stride(from: rect.minY + 29, through: rect.maxY, by: 58) {
                    let size: CGFloat = 4
                    context.setFillColor(gold)
                    context.fillEllipse(in: CGRect(x: x - size, y: y - size, width: size * 2, height: size * 2))
                }
            }
        case .custom: break
        }
    }

    private func drawDiamond(center: CGPoint, radiusX: CGFloat, radiusY: CGFloat, color: CGColor, context: CGContext) {
        context.setStrokeColor(color)
        context.beginPath()
        context.move(to: CGPoint(x: center.x, y: center.y + radiusY))
        context.addLine(to: CGPoint(x: center.x + radiusX, y: center.y))
        context.addLine(to: CGPoint(x: center.x, y: center.y - radiusY))
        context.addLine(to: CGPoint(x: center.x - radiusX, y: center.y))
        context.closePath()
        context.strokePath()
    }

    private func drawBorder(in rect: NSRect, context: CGContext) {
        let alpha = Preferences.shared.opacity
        context.setStrokeColor(NSColor(calibratedRed: 0.98, green: 0.85, blue: 0.58, alpha: alpha).cgColor)
        context.setLineWidth(4)
        context.stroke(rect.insetBy(dx: 10, dy: 10))
        context.setLineWidth(1.5)
        context.stroke(rect.insetBy(dx: 18, dy: 18))
    }

    private func drawFold(in rect: NSRect, amount: CGFloat, context: CGContext) {
        let a = CGPoint(x: rect.maxX - amount, y: rect.maxY)
        let b = CGPoint(x: rect.maxX, y: rect.maxY - amount)
        let c = CGPoint(x: rect.maxX - amount * 0.43, y: rect.maxY - amount * 0.43)
        context.saveGState()
        context.setShadow(offset: CGSize(width: -3, height: -5), blur: 8, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        context.setFillColor(NSColor(calibratedRed: 0.78, green: 0.69, blue: 0.56, alpha: Preferences.shared.opacity).cgColor)
        context.beginPath(); context.move(to: a); context.addLine(to: b); context.addLine(to: c); context.closePath(); context.fillPath()
        context.restoreGState()
    }

    private func drawFringe(in rect: NSRect, context: CGContext) {
        context.setStrokeColor(NSColor(calibratedRed: 0.91, green: 0.83, blue: 0.68, alpha: Preferences.shared.opacity).cgColor)
        context.setLineWidth(1.3)
        for x in stride(from: rect.minX + 7, through: rect.maxX - 6, by: 7) {
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.minY - 7))
            context.move(to: CGPoint(x: x, y: rect.maxY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY + 7))
        }
        context.strokePath()
    }

    private func drawHandles(in rect: NSRect, context: CGContext) {
        let dot = NSColor.white.withAlphaComponent(0.82).cgColor
        context.setFillColor(dot)
        context.fillEllipse(in: CGRect(x: rect.maxX - 17, y: rect.minY + 8, width: 5, height: 5))
        context.fillEllipse(in: CGRect(x: rect.maxX - 9, y: rect.minY + 8, width: 5, height: 5))
        context.fillEllipse(in: CGRect(x: rect.maxX - 9, y: rect.minY + 16, width: 5, height: 5))
        context.fillEllipse(in: CGRect(x: rect.maxX - 17, y: rect.maxY - 15, width: 6, height: 6))
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        lastScreenPoint = NSEvent.mouseLocation
        if p.x > bounds.maxX - 45 && p.y < 45 { dragMode = .resize }
        else if p.x > bounds.maxX - 67 && p.y > bounds.maxY - 67 { dragMode = .lift }
        else { dragMode = .move }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - lastScreenPoint.x
        let dy = now.y - lastScreenPoint.y
        switch dragMode {
        case .move:
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x + dx, y: window.frame.origin.y + dy))
            onGeometryChange?()
        case .resize:
            let current = window.frame
            let width = max(280, current.width + dx)
            let height = max(200, current.height - dy)
            window.setFrame(NSRect(x: current.minX, y: current.maxY - height, width: width, height: height), display: true)
            onGeometryChange?()
        case .lift:
            liftAmount = max(0, min(bounds.width * 0.5, bounds.height * 0.5, liftAmount + (dx - dy) * 0.6))
            needsDisplay = true
        }
        lastScreenPoint = now
    }

    override func mouseUp(with event: NSEvent) {
        liftAmount = 0
        needsDisplay = true
        onGeometryChange?()
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            switch element(at: i, associatedPoints: &points) {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}
