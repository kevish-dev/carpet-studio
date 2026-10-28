import AppKit

enum RugStyle: Int, CaseIterable {
    case persian, kilim, grid, midnight, custom

    var title: String {
        switch self {
        case .persian: return "Persian"
        case .kilim: return "Kilim"
        case .grid: return "Woven Grid"
        case .midnight: return "Midnight"
        case .custom: return "Custom Image"
        }
    }
}

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    var style: RugStyle {
        get { RugStyle(rawValue: defaults.integer(forKey: "style")) ?? .persian }
        set { defaults.set(newValue.rawValue, forKey: "style") }
    }

    var opacity: CGFloat {
        get {
            let value = defaults.object(forKey: "opacity") as? Double ?? 1
            return CGFloat(min(1, max(0.35, value)))
        }
        set { defaults.set(Double(newValue), forKey: "opacity") }
    }

    var showsShadow: Bool {
        get { defaults.object(forKey: "shadow") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "shadow") }
    }

    var customImagePath: String? {
        get { defaults.string(forKey: "customImagePath") }
        set { defaults.set(newValue, forKey: "customImagePath") }
    }

    var rugFrame: NSRect? {
        get {
            guard let value = defaults.string(forKey: "rugFrame") else { return nil }
            return NSRectFromString(value)
        }
        set {
            if let frame = newValue { defaults.set(NSStringFromRect(frame), forKey: "rugFrame") }
            else { defaults.removeObject(forKey: "rugFrame") }
        }
    }
}
