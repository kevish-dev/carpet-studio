import AppKit

@main
struct SmokeTests {
    static func main() throws {
        let planner = FinderLayout.shared
        let screen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let smallRug = NSRect(x: 450, y: 250, width: 540, height: 360)

        for count in [1, 4, 12, 30, 50] {
            let result = try planner.targetLayout(count: count, currentFrame: smallRug,
                                                  screenFrame: screen, screenTop: screen.maxY)
            precondition(result.points.count == count)
            precondition(screen.contains(result.frame))
            let unique = Set(result.points.map { "\($0.x),\($0.y)" })
            precondition(unique.count == count)
            for point in result.points {
                let appKitY = screen.maxY - CGFloat(point.y)
                precondition(result.frame.insetBy(dx: 40, dy: 40).contains(NSPoint(x: CGFloat(point.x), y: appKitY)))
            }
        }

        let oversized = NSRect(x: -500, y: -500, width: 4000, height: 3000)
        let clamped = try planner.targetLayout(count: 5, currentFrame: oversized,
                                               screenFrame: screen, screenTop: screen.maxY)
        precondition(screen.contains(clamped.frame))

        do {
            _ = try planner.targetLayout(count: 0, currentFrame: smallRug,
                                         screenFrame: screen, screenTop: screen.maxY)
            fatalError("Empty icon layout should fail")
        } catch LayoutError.noIcons { }

        do {
            _ = try planner.targetLayout(count: 500, currentFrame: smallRug,
                                         screenFrame: screen, screenTop: screen.maxY)
            fatalError("Overfull icon layout should fail")
        } catch LayoutError.tooManyIcons { }

        let snapshot = LayoutSnapshot(savedAt: Date(), icons: [IconPosition(path: "/tmp/a b.txt", x: 17, y: 23)])
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(LayoutSnapshot.self, from: encoded)
        precondition(decoded.icons.first?.path == "/tmp/a b.txt")
        precondition(decoded.icons.first?.x == 17)

        let quotedPath = "/tmp/a \"quoted\" \\ file.txt"
        let source = planner.positionScript([IconPosition(path: quotedPath, x: 11, y: 22)])
        guard let script = NSAppleScript(source: source) else { fatalError("Could not create AppleScript") }
        var scriptError: NSDictionary?
        precondition(script.compileAndReturnError(&scriptError), "Generated Finder script failed to compile: \(String(describing: scriptError))")

        _ = NSApplication.shared
        var rendered = Set<Data>()
        let originalStyle = Preferences.shared.style
        defer { Preferences.shared.style = originalStyle }
        for style in RugStyle.allCases where style != .custom {
            Preferences.shared.style = style
            let view = RugView(frame: NSRect(x: 0, y: 0, width: 540, height: 360))
            let snapshot = view.renderSnapshot(size: NSSize(width: 1080, height: 720))
            guard let tiff = snapshot.tiffRepresentation else { fatalError("No rendered image") }
            rendered.insert(tiff)
        }
        precondition(rendered.count == 4, "Built-in styles did not render differently")

        var value: Float = 1, velocity: Float = 0
        for _ in 0..<240 { RugCloth.spring(value: &value, velocity: &velocity, target: 0, dt: 1 / 120) }
        precondition(abs(value) < 0.0001 && abs(velocity) < 0.001, "Release did not settle")
        for step in 0...20 {
            let cloth = RugCloth(size: SIMD2(514, 334), lift: Float(step) / 20, ripple: 2, time: 0.3)
            for row in 0...RugCloth.rows { for col in 0...RugCloth.columns {
                let u = Float(col) / Float(RugCloth.columns), v = Float(row) / Float(RugCloth.rows)
                let p = cloth.point(u, v), n = cloth.normal(u, v)
                precondition(p.x.isFinite && p.y.isFinite && p.z.isFinite)
                precondition(n.x.isFinite && n.y.isFinite && n.z.isFinite)
                precondition(p.z >= 0, "Fabric passed through the desktop")
            } }
        }
        let flat = RugCloth(size: SIMD2(514, 334), lift: 0, ripple: 0, time: 0)
        let curled = RugCloth(size: SIMD2(514, 334), lift: 1, ripple: 0, time: 0)
        precondition(flat.normal(1, 1).z > 0.99)
        precondition(curled.normal(1, 1).z < -0.8, "Curl must reveal the backing")
        precondition(curled.point(1, 1).x < flat.point(1, 1).x - 100)

        print("PASS: cloth mesh finite at every lift, backing revealed, damped release settles; layout bounds, unique icon positions, crowded desktop guard, snapshot round trip, Finder script compilation, four distinct rug renders")
    }
}
