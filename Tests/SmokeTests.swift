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
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No bitmap") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("No PNG") }
            rendered.insert(png)
        }
        precondition(rendered.count == 4, "Built-in styles did not render differently")

        print("PASS: layout bounds, unique icon positions, crowded desktop guard, snapshot round trip, Finder script compilation, four distinct rug renders")
    }
}
