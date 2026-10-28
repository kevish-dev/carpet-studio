import AppKit
import SceneKit
import simd

/// A lightweight, inextensible cylindrical bend. Material coordinates stay on the
/// same arc length as the flat rug, so the pattern bends instead of stretching.
struct RugCloth {
    static let columns = 48
    static let rows = 32
    static let thickness: Float = 1.7
    var size: SIMD2<Float>
    var lift: Float
    var ripple: Float
    var time: Float
    var sway: SIMD2<Float> = .zero

    func point(_ u: Float, _ v: Float) -> SIMD3<Float> {
        let x = u * size.x
        let y = v * size.y
        let diagonal: Float = 0.70710678
        let reach = min(size.x, size.y) * 0.81
        let distance = ((size.x - x) + (size.y - y)) * diagonal
        let extent = reach
        let bent = max(0, extent - distance)
        var p = SIMD3<Float>(x, y, 2.5)
        if bent > 0 && lift > 0.00001 {
            // Curl grows continuously, passes vertical, and shows the woven back.
            let maxAngle = 2.72 * min(1, lift)
            let radius = extent / max(maxAngle, 0.001)
            let angle = bent / radius
            let retreat = bent - radius * sin(angle)
            p.x -= retreat * diagonal
            p.y -= retreat * diagonal
            p.z += radius * (1 - cos(angle))
        }
        let cornerWeight = pow(max(0, 1 - distance / max(reach, 1)), 2)
        let wave = sin(distance * 0.048 - time * 13) * exp(-distance / max(reach, 1))
        p.z += max(-1.3, ripple * wave * cornerWeight)
        let edgeWeight = sin(u * .pi) * sin(v * .pi)
        p.z += (abs(sway.x) + abs(sway.y)) * edgeWeight * 0.065
        p.x += sway.x * edgeWeight * 0.06
        p.y += sway.y * edgeWeight * 0.06
        // A very slight oblique view makes height readable against the desktop.
        p.x += (p.z - 2.5) * 0.08
        p.y += (p.z - 2.5) * 0.14
        return p
    }

    func normal(_ u: Float, _ v: Float) -> SIMD3<Float> {
        let e: Float = 0.001
        let a = point(u + e, v) - point(u - e, v)
        let b = point(u, v + e) - point(u, v - e)
        return simd_normalize(simd_cross(a, b))
    }

    static func spring(value: inout Float, velocity: inout Float, target: Float,
                       dt: Float, stiffness: Float = 195, damping: Float = 22) {
        // Fixed substeps keep release stable when a display frame is delayed.
        var remaining = min(max(dt, 0), 0.05)
        while remaining > 0 {
            let step = min(remaining, 1 / 240)
            velocity += ((target - value) * stiffness - velocity * damping) * step
            value += velocity * step
            remaining -= step
        }
    }
}

/// Cached, opaque material maps. The face is painted once per style/size change,
/// never from the mouse-drag or animation callbacks.
enum RugTexture {
    static func image(style: RugStyle, customPath: String?, aspect: CGFloat, back: Bool = false) -> NSImage {
        let width = 1200
        let height = max(400, min(1200, Int(CGFloat(width) / max(0.5, aspect))))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        let base: NSColor
        if back { base = NSColor(calibratedRed: 0.66, green: 0.55, blue: 0.41, alpha: 1) }
        else {
            switch style {
            case .persian: base = NSColor(calibratedRed: 0.50, green: 0.13, blue: 0.16, alpha: 1)
            case .kilim: base = NSColor(calibratedRed: 0.71, green: 0.38, blue: 0.24, alpha: 1)
            case .grid: base = NSColor(calibratedRed: 0.22, green: 0.43, blue: 0.39, alpha: 1)
            case .midnight: base = NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.27, alpha: 1)
            case .custom: base = NSColor(calibratedWhite: 0.2, alpha: 1)
            }
        }
        context.setFillColor(base.cgColor); context.fill(rect)
        if !back, style == .custom, let path = customPath, let image = NSImage(contentsOfFile: path) {
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        } else if !back {
            // Paint in logical points so existing patterns keep their proportions.
            context.saveGState()
            context.scaleBy(x: CGFloat(width) / 570, y: CGFloat(height) / (570 / aspect))
            let r = CGRect(x: 0, y: 0, width: 570, height: 570 / aspect)
            let gold = NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.48, alpha: 0.78).cgColor
            let cream = NSColor(calibratedRed: 0.98, green: 0.88, blue: 0.68, alpha: 0.62).cgColor
            func diamond(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ color: CGColor) {
                context.setStrokeColor(color); context.setLineWidth(1.7)
                context.beginPath(); context.move(to: CGPoint(x: x, y: y + ry))
                context.addLine(to: CGPoint(x: x + rx, y: y)); context.addLine(to: CGPoint(x: x, y: y - ry))
                context.addLine(to: CGPoint(x: x - rx, y: y)); context.closePath(); context.strokePath()
            }
            switch style {
            case .persian:
                for s in [0.35, 0.25, 0.14] { diamond(r.midX, r.midY, r.width * s, r.height * s, gold) }
                for x in stride(from: CGFloat(34), through: r.maxX - 20, by: 44) {
                    for y in stride(from: CGFloat(33), through: r.maxY - 20, by: 44) {
                        if abs(x - r.midX) / r.width + abs(y - r.midY) / r.height > 0.43 { diamond(x, y, 8, 11, cream) }
                    }
                }
            case .kilim:
                for x in stride(from: CGFloat(28), through: r.maxX + 10, by: 54) {
                    for y in stride(from: CGFloat(25), through: r.maxY + 10, by: 54) {
                        diamond(x, y, 19, 25, gold); diamond(x, y, 8, 11, cream)
                    }
                }
            case .grid:
                context.setStrokeColor(cream); context.setLineWidth(1)
                for x in stride(from: CGFloat(0), through: r.maxX, by: 17) { context.move(to: CGPoint(x: x, y: 0)); context.addLine(to: CGPoint(x: x, y: r.maxY)) }
                for y in stride(from: CGFloat(0), through: r.maxY, by: 17) { context.move(to: CGPoint(x: 0, y: y)); context.addLine(to: CGPoint(x: r.maxX, y: y)) }
                context.strokePath()
            case .midnight:
                context.setFillColor(gold)
                for x in stride(from: CGFloat(33), through: r.maxX, by: 62) {
                    for y in stride(from: CGFloat(29), through: r.maxY, by: 58) { context.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)) }
                }
            case .custom: break
            }
            context.setStrokeColor(gold); context.setLineWidth(4); context.stroke(r.insetBy(dx: 10, dy: 10))
            context.setLineWidth(1.5); context.stroke(r.insetBy(dx: 18, dy: 18))
            context.restoreGState()
        }
        // Alternating warp/weft strands remain visible in highlights and at rest.
        context.setLineWidth(0.7)
        for x in stride(from: 0, to: width, by: 3) {
            context.setStrokeColor(NSColor.white.withAlphaComponent(back ? 0.13 : 0.08).cgColor)
            context.move(to: CGPoint(x: x, y: 0)); context.addLine(to: CGPoint(x: x, y: height)); context.strokePath()
        }
        for y in stride(from: 0, to: height, by: 3) {
            context.setStrokeColor(NSColor.black.withAlphaComponent(back ? 0.14 : 0.09).cgColor)
            context.move(to: CGPoint(x: 0, y: y)); context.addLine(to: CGPoint(x: width, y: y)); context.strokePath()
        }
        // Deterministic short fibers prevent a perfectly printed/vector surface.
        for i in 0..<6000 {
            let x = (i * 7919) % width, y = (i * 104729) % height
            context.setFillColor(NSColor(white: i % 2 == 0 ? 1 : 0, alpha: 0.08).cgColor)
            context.fill(CGRect(x: x, y: y, width: 1, height: 2))
        }
        return NSImage(cgImage: context.makeImage()!, size: rect.size)
    }
}
