import AppKit
import CoreGraphics

final class RugWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isReleasedWhenClosed = false
        ignoresMouseEvents = false
        let view = RugView(frame: NSRect(origin: .zero, size: frame.size))
        contentView = view
    }

    var rugView: RugView { contentView as! RugView }
}
