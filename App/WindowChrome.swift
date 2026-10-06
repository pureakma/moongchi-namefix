import AppKit
import Combine

/// Native toolbar keeps window controls and overflow behavior owned by macOS.
/// It holds only the sidebar toggle: History, Settings and Help live in the sidebar
/// and menu bar, and Rescan appears next to the results it refreshes.
@MainActor final class WindowChrome: NSObject, NSToolbarDelegate {
    private weak var splitController: MainSidebarController?
    private let model: AppModel
    private var observation: AnyCancellable?
    private var language = ""
    let toolbar = NSToolbar(identifier: "NameFix.MainToolbar")
    init(model: AppModel) {
        self.model = model
        super.init()
        toolbar.delegate = self; toolbar.displayMode = .iconOnly; toolbar.sizeMode = .regular
        toolbar.allowsUserCustomization = false; toolbar.autosavesConfiguration = false
        toolbar.showsBaselineSeparator = false
        observation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
    func install(on window: NSWindow, split: MainSidebarController? = nil) {
        splitController = split
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.toolbar = toolbar
        refresh()
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [NSToolbarItem.Identifier("NameFix.sidebar"), NSToolbarItem.Identifier("NameFix.separator"), .flexibleSpace] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if identifier.rawValue == "NameFix.separator", let splitController {
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: splitController.splitView, dividerIndex: 0)
        }
        guard identifier.rawValue == "NameFix.sidebar" else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: model.t("ToggleSidebar"))
        item.label = model.t("ToggleSidebar"); item.toolTip = item.label
        item.target = self; item.action = #selector(toggleSidebar)
        return item
    }
    func refresh() {
        guard language != model.settings.language else { return }
        language = model.settings.language
        for item in toolbar.items where item.itemIdentifier.rawValue == "NameFix.sidebar" { item.label = model.t("ToggleSidebar"); item.toolTip = item.label }
    }
    @objc private func toggleSidebar() { splitController?.toggleSidebar(nil) }
}
