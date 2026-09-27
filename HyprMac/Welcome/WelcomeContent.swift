// Data tables for the Welcome / Tour window.

import SwiftUI

// MARK: - what's new feature list
// Update this array before each release with features from git log;
// see docs/release.md for the workflow.

/// Accent used for a changelog row's icon tile.
enum WhatsNewTint {
    case cyan   // default
    case magenta // floating / scratchpad features
}

/// One row in the "What's New" page: icon, title, description, tint.
struct WhatsNewFeature {
    let icon: String
    let title: String
    let description: String
    var tint: WhatsNewTint = .cyan
    /// github handle of an outside contributor, shown under the description
    var credit: String? = nil
}

enum WhatsNewFeatures {
    // update this before each release — see docs/release.md
    static let current: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "pin",
            title: "Pin Apps to Workspaces",
            description: "Settings → General → Pin apps to workspaces sends an app's new windows to the workspace you choose, and takes you there with them."
        ),
        WhatsNewFeature(
            icon: "rectangle.on.rectangle",
            title: "Drag Between Monitors",
            description: "Drop a tiled window on another monitor and it tiles where you let go. A highlight shows where it will land before you drop."
        ),
        WhatsNewFeature(
            icon: "rectangle.3.group",
            title: "Retile All on Hypr+R",
            description: "Hypr+R retiles every workspace and moves pinned apps back to their workspaces."
        ),
        WhatsNewFeature(
            icon: "macwindow.on.rectangle",
            title: "Never Tile Means Never",
            description: "Apps in Never tile stay floating. Hypr+T on one says so instead of tiling it, and a pinned one still floats on its workspace.",
            tint: .magenta
        ),
    ]
}

enum WelcomeContent {
    static let productURL = URL(string: "https://hyprmac.app/")!

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    static func chord(
        in keybinds: [Keybind],
        hyprKey: HyprKey,
        matching predicate: (Action) -> Bool
    ) -> String? {
        guard let bind = keybinds.first(where: { predicate($0.action) }) else { return nil }
        var parts: [String] = []
        if bind.modifiers.contains(.hypr) { parts.append("HYPR") }
        if bind.modifiers.contains(.control) { parts.append("⌃") }
        if bind.modifiers.contains(.option) { parts.append("⌥") }
        if bind.modifiers.contains(.shift) { parts.append("⇧") }
        if bind.modifiers.contains(.command) { parts.append("⌘") }
        parts.append(bind.keyCodeName)
        return parts.joined(separator: " ")
    }
}
