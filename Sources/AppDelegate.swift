import AppKit
import UniformTypeIdentifiers

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var rugWindow: RugWindow!
    private var showItem: NSMenuItem!
    private var restoreItem: NSMenuItem!
    private var shadowItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let screen = NSScreen.screens.first else { return }
        let defaultFrame = NSRect(x: screen.frame.midX - 270, y: screen.frame.midY - 180, width: 540, height: 360)
        let stored = Preferences.shared.rugFrame ?? defaultFrame
        rugWindow = RugWindow(frame: clamp(stored, to: screen.visibleFrame))
        rugWindow.rugView.onGeometryChange = { [weak self] in
            guard let self else { return }
            Preferences.shared.rugFrame = self.rugWindow.frame
        }
        rugWindow.orderFrontRegardless()
        setupMenu()
        showWelcomeIfNeeded()
    }

    private func clamp(_ rect: NSRect, to screen: NSRect) -> NSRect {
        let width = min(max(280, rect.width), screen.width - 20)
        let height = min(max(200, rect.height), screen.height - 20)
        let x = min(max(rect.minX, screen.minX + 10), screen.maxX - width - 10)
        let y = min(max(rect.minY, screen.minY + 10), screen.maxY - height - 10)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.on.rectangle.angled", accessibilityDescription: "Carpet Studio")
        if statusItem.button?.image == nil { statusItem.button?.title = "▧" }
        let menu = NSMenu()
        menu.delegate = self
        let title = NSMenuItem(title: "Carpet Studio", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        showItem = add(menu, "Hide Carpet", #selector(toggleCarpet), "h")
        _ = add(menu, "Reset Position & Size", #selector(resetFrame), "")
        menu.addItem(.separator())

        let styleParent = NSMenuItem(title: "Carpet Style", action: nil, keyEquivalent: "")
        let styleMenu = NSMenu()
        for style in RugStyle.allCases where style != .custom {
            let item = NSMenuItem(title: style.title, action: #selector(selectStyle(_:)), keyEquivalent: "")
            item.target = self
            item.tag = style.rawValue
            styleMenu.addItem(item)
        }
        styleMenu.addItem(.separator())
        let importItem = NSMenuItem(title: "Import Image…", action: #selector(importImage), keyEquivalent: "")
        importItem.target = self
        styleMenu.addItem(importItem)
        styleParent.submenu = styleMenu
        menu.addItem(styleParent)

        let opacityParent = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let opacityMenu = NSMenu()
        for percent in [40, 60, 80, 100] {
            let item = NSMenuItem(title: "\(percent)%", action: #selector(selectOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.tag = percent
            opacityMenu.addItem(item)
        }
        opacityParent.submenu = opacityMenu
        menu.addItem(opacityParent)
        shadowItem = add(menu, "Show Shadow", #selector(toggleShadow), "")
        menu.addItem(.separator())

        _ = add(menu, "Gather Icons Under Carpet…", #selector(gatherIcons), "")
        restoreItem = add(menu, "Restore Icon Positions", #selector(restoreIcons), "")
        menu.addItem(.separator())
        _ = add(menu, "Open Desktop Folder", #selector(openDesktop), "")
        _ = add(menu, "Permissions & Privacy", #selector(showPermissions), "")
        _ = add(menu, "How to Use", #selector(showHelp), "")
        _ = add(menu, "Quit Carpet Studio", #selector(quit), "q")
        statusItem.menu = menu
    }

    private func add(_ menu: NSMenu, _ title: String, _ selector: Selector, _ key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        showItem.title = rugWindow.isVisible ? "Hide Carpet" : "Show Carpet"
        restoreItem.isEnabled = FinderLayout.shared.hasBackup
        shadowItem.state = Preferences.shared.showsShadow ? .on : .off
        if let styleMenu = menu.items.first(where: { $0.title == "Carpet Style" })?.submenu {
            for item in styleMenu.items { item.state = item.tag == Preferences.shared.style.rawValue && item.action == #selector(selectStyle(_:)) ? .on : .off }
        }
        if let opacityMenu = menu.items.first(where: { $0.title == "Opacity" })?.submenu {
            for item in opacityMenu.items { item.state = item.tag == Int((Preferences.shared.opacity * 100).rounded()) ? .on : .off }
        }
    }

    @objc private func toggleCarpet() {
        if rugWindow.isVisible { rugWindow.orderOut(nil) } else { rugWindow.orderFrontRegardless() }
    }

    @objc private func resetFrame() {
        guard let screen = NSScreen.screens.first else { return }
        let frame = NSRect(x: screen.frame.midX - 270, y: screen.frame.midY - 180, width: 540, height: 360)
        rugWindow.setFrame(clamp(frame, to: screen.visibleFrame), display: true)
        Preferences.shared.rugFrame = rugWindow.frame
        rugWindow.orderFrontRegardless()
    }

    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard let style = RugStyle(rawValue: sender.tag) else { return }
        Preferences.shared.style = style
        rugWindow.rugView.needsDisplay = true
    }

    @objc private func selectOpacity(_ sender: NSMenuItem) {
        Preferences.shared.opacity = CGFloat(sender.tag) / 100
        rugWindow.rugView.needsDisplay = true
    }

    @objc private func toggleShadow() {
        Preferences.shared.showsShadow.toggle()
        rugWindow.rugView.needsDisplay = true
    }

    @objc private func importImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let source = panel.url else { return }
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Carpet Studio", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent("custom-rug.\(source.pathExtension.lowercased())")
            if source.standardizedFileURL != destination.standardizedFileURL {
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.copyItem(at: source, to: destination)
            }
            Preferences.shared.customImagePath = destination.path
            Preferences.shared.style = .custom
            rugWindow.rugView.needsDisplay = true
        } catch { alert("Could not import image", error.localizedDescription) }
    }

    @objc private func gatherIcons() {
        let confirm = NSAlert()
        confirm.messageText = "Gather desktop icons under the carpet?"
        confirm.informativeText = "Carpet Studio will save every icon's current position, then arrange the icons beneath the carpet. Files stay in place on disk. In Finder, turn off Use Stacks and set Sort By to None before continuing. macOS may ask for permission to control Finder."
        confirm.addButton(withTitle: "Gather Icons")
        confirm.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }
        do {
            try FinderLayout.shared.gather(under: rugWindow)
            rugWindow.orderFrontRegardless()
        } catch { alert("Could not gather icons", error.localizedDescription) }
    }

    @objc private func restoreIcons() {
        do { try FinderLayout.shared.restore() }
        catch { alert("Could not restore icons", error.localizedDescription) }
    }

    @objc private func showHelp() {
        alert("How to use Carpet Studio", "Drag the carpet to move it. Drag the small marks at its lower-right corner to resize it. Drag the upper-right corner inward to lift it and peek at your desktop. Use the menu bar icon to choose a style, import an image, or gather and restore desktop icons.")
    }

    @objc private func openDesktop() {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true))
    }

    @objc private func showPermissions() {
        let message = "Covering icons needs no special permission. Gather and Restore use macOS Automation to read and set Finder desktop icon positions. Files are never moved or uploaded. If you denied access, open System Settings → Privacy & Security → Automation and allow Carpet Studio to control Finder."
        alert("Permissions & Privacy", message)
    }

    private func showWelcomeIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "didShowWelcome") else { return }
        NSApp.activate(ignoringOtherApps: true)
        let welcome = NSAlert()
        welcome.messageText = "Welcome to Carpet Studio"
        welcome.informativeText = "The carpet lives on your desktop; its controls live in the menu bar. Drag it to move, drag the lower-right corner to resize, and pull the upper-right corner to peek. Covering icons needs no permission. Gather Icons asks for Finder Automation only when you choose it, and saves your icon layout for Restore."
        welcome.addButton(withTitle: "Start Using Carpet Studio")
        welcome.runModal()
        defaults.set(true, forKey: "didShowWelcome")
    }

    @objc private func quit() {
        if FinderLayout.shared.hasBackup {
            do { try FinderLayout.shared.restore() }
            catch {
                alert("Icons still need restoring", "Carpet Studio could not restore the saved layout: \(error.localizedDescription) The backup remains saved. Reopen Carpet Studio and choose Restore Icon Positions.")
            }
        }
        NSApp.terminate(nil)
    }

    private func alert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
