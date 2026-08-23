import Foundation

/// Identifiers shared by the app and the widget extension.
///
/// The App Group is what lets the widget read the board you drew in the app.
/// If you change `identifier` here you must change it in **both**
/// `.entitlements` files as well (Blackboard.entitlements and
/// BlackboardWidget.entitlements).
enum AppGroup {

    static let identifier = "group.com.example.blackboard"

    /// Must match the `kind` string used by `BlackboardWidget`.
    static let widgetKind = "BlackboardWidget"

    /// Shared defaults used for tiny bits of state (the widget's wipe arming).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// Shared on-disk container. `nil` when the App Group is not configured,
    /// which is the one setup mistake that silently breaks the widget, so the
    /// app surfaces it instead of hiding it.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var isConfigured: Bool { containerURL != nil }
}

/// Deep links the widget uses to drop you exactly where you want to be.
enum DeepLink {
    static let scheme = "blackboard"

    /// Tap the widget body: open the board ready to draw.
    static let draw = URL(string: "\(scheme)://draw")!
    /// Tap the note button: open the board with the bullet field focused.
    static let note = URL(string: "\(scheme)://note")!

    enum Destination {
        case draw
        case note
    }

    static func destination(for url: URL) -> Destination? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "note": return .note
        case "draw": return .draw
        default: return nil
        }
    }
}
