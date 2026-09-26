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
            icon: "rectangle.split.2x2",
            title: "Steadier Tiling",
            description: "Windows land in their tiles far more reliably. A move between monitors sizes the window first, a window that doesn't fit goes back where it was, and nothing gets shuffled while your Mac is locked or asleep."
        ),
        WhatsNewFeature(
            icon: "keyboard",
            title: "A Searchable Keybind List",
            description: "Hypr+K opens one scrolling list with a search bar. Start typing to find a shortcut, or use the arrow keys to scroll."
        ),
        WhatsNewFeature(
            icon: "arrow.up.right.square.fill",
            title: "Move and Follow",
            description: "Hypr+Ctrl+Shift+N moves the focused window to workspace N and takes you there with it."
        ),
        WhatsNewFeature(
            icon: "square.stack",
            title: "A Scratchpad That Tiles",
            description: "The scratchpad works like its own workspace. Focus, swaps, resizes and drags stay inside it, and the windows behind it can't take focus.",
            tint: .magenta
        ),
        WhatsNewFeature(
            icon: "macwindow.on.rectangle",
            title: "Floaters Stay on Top",
            description: "Floating windows stay above the tile you click, and Quick Look previews float instead of tiling.",
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
