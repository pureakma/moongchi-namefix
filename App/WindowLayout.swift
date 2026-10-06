import Foundation

struct ScreenArea: Sendable {
    var id: String
    var visibleFrame: CGRect
}
struct WindowPlacement: Codable, Sendable {
    var version = 1
    var frame: CGRect
    var screenID: String
    var screenFrame: CGRect
    var valid: Bool { version == 1 && Self.valid(frame) && Self.valid(screenFrame) }
    private static func valid(_ rect: CGRect) -> Bool {
        [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) && rect.width > 0 && rect.height > 0
    }
}
enum WindowLayout {
    static func initial(on screen: CGRect) -> CGRect {
        let size = CGSize(width: min(1180, screen.width * 0.85), height: min(808, screen.height * 0.85))
        return CGRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height)
    }
    static func restored(_ saved: WindowPlacement?, screens: [ScreenArea], preferredID: String?) -> CGRect? {
        guard let fallback = screens.first(where: { $0.id == preferredID }) ?? screens.first else { return nil }
        guard let saved, saved.valid else { return initial(on: fallback.visibleFrame) }
        let target = screens.first(where: { $0.id == saved.screenID }) ?? fallback
        var frame = saved.frame
        if target.id != saved.screenID {
            frame.origin = CGPoint(x: target.visibleFrame.midX - frame.width / 2, y: target.visibleFrame.midY - frame.height / 2)
        } else if saved.screenFrame != target.visibleFrame {
            // Preserve relative position when the same display moves or changes scale.
            let x = (frame.midX - saved.screenFrame.minX) / saved.screenFrame.width
            let y = (frame.midY - saved.screenFrame.minY) / saved.screenFrame.height
            frame.origin = CGPoint(x: target.visibleFrame.minX + target.visibleFrame.width * x - frame.width / 2,
                                   y: target.visibleFrame.minY + target.visibleFrame.height * y - frame.height / 2)
        }
        return constrained(frame, to: target.visibleFrame)
    }
    static func constrained(_ frame: CGRect, to area: CGRect) -> CGRect {
        let width = min(frame.width, area.width), height = min(frame.height, area.height)
        return CGRect(x: max(area.minX, min(frame.minX, area.maxX - width)),
                      y: max(area.minY, min(frame.minY, area.maxY - height)), width: width, height: height)
    }
    static func sheet(preferred: CGSize, available: CGSize) -> CGSize {
        CGSize(width: max(160, min(preferred.width, available.width - 24)), height: max(120, min(preferred.height, available.height - 24)))
    }
    static func cardColumns(width: CGFloat) -> Int { width >= 600 ? 4 : width >= 360 ? 2 : 1 }
    static func wide(width: CGFloat) -> Bool { width >= 900 }
}
/// What the left side of the window shows. It follows the input state; the user never toggles it.
enum SidebarMode: Equatable, Sendable {
    /// Nothing added yet: icon + name navigation, no folder tree.
    case navigation
    /// Something added: icon rail with the folder tree beside it.
    case railWithTree
    /// Narrow window: content first.
    case hidden
}
extension WindowLayout {
    static let navigationWidth: CGFloat = 208
    static let railWidth: CGFloat = 48
    /// Leading edge of the app icon and name: the window buttons end at 79pt.
    static let brandLeading: CGFloat = 96
    static let treeWidthRange: ClosedRange<CGFloat> = 170...380
    static let defaultTreeWidth: CGFloat = 220
    static let sidebarHiddenBelow: CGFloat = 760
    static func sidebarMode(windowWidth: CGFloat, hasInput: Bool) -> SidebarMode {
        windowWidth < sidebarHiddenBelow ? .hidden : hasInput ? .railWithTree : .navigation
    }
    static func treeWidth(_ stored: CGFloat?) -> CGFloat {
        guard let stored, stored.isFinite else { return defaultTreeWidth }
        return min(max(stored, treeWidthRange.lowerBound), treeWidthRange.upperBound)
    }
    /// Sidebar thickness limits for a mode. Navigation is fixed; only the tree part is resizable.
    static func sidebarWidths(_ mode: SidebarMode, treeWidth stored: CGFloat?) -> (minimum: CGFloat, preferred: CGFloat, maximum: CGFloat) {
        switch mode {
        case .navigation, .hidden: return (navigationWidth, navigationWidth, navigationWidth)
        case .railWithTree: return (railWidth + treeWidthRange.lowerBound, railWidth + treeWidth(stored), railWidth + treeWidthRange.upperBound)
        }
    }
}
/// Shared spacing so panes that sit side by side start on the same lines.
enum Metrics {
    static let page: CGFloat = 16
    static let paneHeader: CGFloat = 28
    static let gap: CGFloat = 12
    static let control: CGFloat = 8
    static let corner: CGFloat = 10
    static let statusBar: CGFloat = 28
}
@MainActor final class WindowPlacementStore {
    private let defaults: UserDefaults
    private let key = "NameFix.windowPlacement.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func load() -> WindowPlacement? {
        guard let data = defaults.data(forKey: key), let value = try? JSONDecoder().decode(WindowPlacement.self, from: data), value.valid else { return nil }
        return value
    }
    func save(_ value: WindowPlacement) {
        guard value.valid, let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
