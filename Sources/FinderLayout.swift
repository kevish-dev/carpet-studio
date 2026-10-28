import AppKit

struct IconPosition: Codable {
    let path: String
    let x: Int
    let y: Int
}

struct LayoutSnapshot: Codable {
    let savedAt: Date
    let icons: [IconPosition]
}

enum LayoutError: LocalizedError {
    case script(String)
    case noIcons
    case alreadyGathered
    case noBackup
    case tooManyIcons
    case partial(Int)

    var errorDescription: String? {
        switch self {
        case .script(let detail): return "Finder could not update the desktop. \(detail)"
        case .noIcons: return "Finder returned no desktop icons to gather."
        case .alreadyGathered: return "An icon layout is already saved. Restore it before gathering again."
        case .noBackup: return "There is no saved icon layout to restore."
        case .tooManyIcons: return "There are too many icons to fit beneath this carpet on the main display."
        case .partial(let count): return "Finder could not reposition \(count) icon(s). The saved layout is still available for Restore."
        }
    }
}

final class FinderLayout {
    static let shared = FinderLayout()

    private var backupURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Carpet Studio", isDirectory: true).appendingPathComponent("desktop-layout-backup.json")
    }

    var hasBackup: Bool { FileManager.default.fileExists(atPath: backupURL.path) }

    func gather(under window: RugWindow) throws {
        guard !hasBackup else { throw LayoutError.alreadyGathered }
        let original = try readPositions()
        guard !original.isEmpty else { throw LayoutError.noIcons }
        guard let screen = NSScreen.screens.first else { throw LayoutError.script("No display found.") }
        let layout = try targetLayout(count: original.count, currentFrame: window.frame,
                                      screenFrame: screen.visibleFrame, screenTop: screen.frame.maxY)
        let snapshot = LayoutSnapshot(savedAt: Date(), icons: original)
        try FileManager.default.createDirectory(at: backupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: backupURL, options: .atomic)

        // The backup is on disk before the first icon position changes.
        window.setFrame(layout.frame, display: true)
        Preferences.shared.rugFrame = layout.frame
        let targets = zip(original, layout.points).map { IconPosition(path: $0.0.path, x: $0.1.x, y: $0.1.y) }
        do {
            let failures = try setPositions(targets)
            if !failures.isEmpty { throw LayoutError.partial(failures.count) }
        } catch {
            // Try to leave the desktop as it was. Keep the backup if restoration fails.
            let failures = (try? setPositions(original)) ?? original.map(\.path)
            if failures.isEmpty { try? FileManager.default.removeItem(at: backupURL) }
            throw error
        }
    }

    func restore() throws {
        guard hasBackup else { throw LayoutError.noBackup }
        let snapshot = try JSONDecoder().decode(LayoutSnapshot.self, from: Data(contentsOf: backupURL))
        let failures = try setPositions(snapshot.icons)
        if !failures.isEmpty { throw LayoutError.partial(failures.count) }
        try FileManager.default.removeItem(at: backupURL)
    }

    private func readPositions() throws -> [IconPosition] {
        let source = """
        set gatheredItems to {}
        tell application "Finder"
            repeat with desktopItem in (every item of desktop)
                try
                    set itemURL to URL of desktopItem
                    set itemPoint to desktop position of desktopItem
                    set end of gatheredItems to {itemURL, item 1 of itemPoint, item 2 of itemPoint}
                end try
            end repeat
        end tell
        return gatheredItems
        """
        let result = try run(source)
        var icons: [IconPosition] = []
        guard result.numberOfItems > 0 else { return [] }
        for index in 1...result.numberOfItems {
            guard let row = result.atIndex(index),
                  let urlText = row.atIndex(1)?.stringValue,
                  let url = URL(string: urlText), url.isFileURL,
                  let x = row.atIndex(2)?.int32Value,
                  let y = row.atIndex(3)?.int32Value else { continue }
            icons.append(IconPosition(path: url.path, x: Int(x), y: Int(y)))
        }
        return icons
    }

    private func setPositions(_ icons: [IconPosition]) throws -> [String] {
        let result = try run(positionScript(icons))
        guard result.numberOfItems > 0 else { return [] }
        return (1...result.numberOfItems).compactMap { result.atIndex($0)?.stringValue }
    }

    func positionScript(_ icons: [IconPosition]) -> String {
        var lines = ["set failedItems to {}", "tell application \"Finder\""]
        for icon in icons {
            let path = appleScriptQuoted(icon.path)
            lines.append("try")
            lines.append("set desktop position of ((POSIX file \(path)) as alias) to {\(icon.x), \(icon.y)}")
            lines.append("on error")
            lines.append("set end of failedItems to \(path)")
            lines.append("end try")
        }
        lines += ["end tell", "return failedItems"]
        return lines.joined(separator: "\n")
    }

    private func run(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else { throw LayoutError.script("Could not compile the Finder command.") }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            if (error[NSAppleScript.errorNumber] as? Int) == -1743 {
                throw LayoutError.script("Allow Carpet Studio to control Finder in System Settings → Privacy & Security → Automation, then try again.")
            }
            let message = error[NSAppleScript.errorMessage] as? String ?? error.description
            throw LayoutError.script(message)
        }
        return result
    }

    private func appleScriptQuoted(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    func targetLayout(count: Int, currentFrame: NSRect, screenFrame: NSRect, screenTop: CGFloat) throws -> (frame: NSRect, points: [(x: Int, y: Int)]) {
        guard count > 0 else { throw LayoutError.noIcons }
        let columns = max(1, Int(ceil(sqrt(Double(count) * Double(screenFrame.width / screenFrame.height)))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let neededWidth = CGFloat(columns - 1) * 82 + 110
        let neededHeight = CGFloat(rows - 1) * 90 + 110
        guard neededWidth <= screenFrame.width - 30, neededHeight <= screenFrame.height - 30 else { throw LayoutError.tooManyIcons }
        let width = max(min(currentFrame.width, screenFrame.width - 30), neededWidth)
        let height = max(min(currentFrame.height, screenFrame.height - 30), neededHeight)
        let x = min(max(currentFrame.midX - width / 2, screenFrame.minX + 15), screenFrame.maxX - width - 15)
        let y = min(max(currentFrame.midY - height / 2, screenFrame.minY + 15), screenFrame.maxY - height - 15)
        let frame = NSRect(x: x, y: y, width: width, height: height)
        let startX = frame.midX - CGFloat(columns - 1) * 82 / 2
        let startY = frame.midY + CGFloat(rows - 1) * 90 / 2
        let points = (0..<count).map { index in
            (x: Int((startX + CGFloat(index % columns) * 82).rounded()),
             y: Int((screenTop - (startY - CGFloat(index / columns) * 90)).rounded()))
        }
        return (frame, points)
    }
}
