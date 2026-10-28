import AppKit

@main
struct GenerateIcon {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass an output PNG path") }
        let size = 1024
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                                            bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Could not create bitmap") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.setAllowsAntialiasing(true)

        let background = NSBezierPath(roundedRect: NSRect(x: 20, y: 20, width: 984, height: 984), xRadius: 220, yRadius: 220)
        NSColor(calibratedRed: 0.13, green: 0.17, blue: 0.18, alpha: 1).setFill()
        background.fill()

        context.setShadow(offset: CGSize(width: 12, height: -20), blur: 26, color: NSColor.black.withAlphaComponent(0.55).cgColor)
        let rug = NSBezierPath(roundedRect: NSRect(x: 141, y: 211, width: 742, height: 608), xRadius: 30, yRadius: 30)
        NSColor(calibratedRed: 0.56, green: 0.14, blue: 0.18, alpha: 1).setFill()
        rug.fill()
        context.setShadow(offset: .zero, blur: 0)

        context.setStrokeColor(NSColor(calibratedRed: 0.95, green: 0.78, blue: 0.49, alpha: 1).cgColor)
        context.setLineWidth(18)
        context.stroke(CGRect(x: 178, y: 248, width: 668, height: 534))
        context.setLineWidth(5)
        context.stroke(CGRect(x: 207, y: 277, width: 610, height: 476))

        func diamond(_ center: CGPoint, _ rx: CGFloat, _ ry: CGFloat) {
            context.beginPath()
            context.move(to: CGPoint(x: center.x, y: center.y + ry))
            context.addLine(to: CGPoint(x: center.x + rx, y: center.y))
            context.addLine(to: CGPoint(x: center.x, y: center.y - ry))
            context.addLine(to: CGPoint(x: center.x - rx, y: center.y))
            context.closePath()
            context.strokePath()
        }
        context.setLineWidth(13)
        diamond(CGPoint(x: 512, y: 515), 225, 195)
        diamond(CGPoint(x: 512, y: 515), 134, 119)
        for x in stride(from: 252, through: 770, by: 115) {
            diamond(CGPoint(x: x, y: 313), 20, 25)
            diamond(CGPoint(x: x, y: 716), 20, 25)
        }
        context.setLineWidth(7)
        for x in stride(from: 175, through: 845, by: 23) {
            context.move(to: CGPoint(x: x, y: 211))
            context.addLine(to: CGPoint(x: x, y: 176))
            context.move(to: CGPoint(x: x, y: 819))
            context.addLine(to: CGPoint(x: x, y: 854))
        }
        context.strokePath()

        context.setFillColor(NSColor(calibratedRed: 0.83, green: 0.72, blue: 0.56, alpha: 1).cgColor)
        context.beginPath()
        context.move(to: CGPoint(x: 732, y: 819))
        context.addLine(to: CGPoint(x: 883, y: 668))
        context.addLine(to: CGPoint(x: 775, y: 711))
        context.closePath()
        context.fillPath()

        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode PNG") }
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    }
}
