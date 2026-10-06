import AppKit
import Combine

/// Native toolbar keeps window controls and overflow behavior owned by macOS.
@MainActor final class WindowChrome: NSObject, NSToolbarDelegate, NSToolbarItemValidation {
    private weak var splitController: MainSidebarController?
    private let model: AppModel
    private var observation: AnyCancellable?
    let toolbar = NSToolbar(identifier: "NameFix.MainToolbar")
    private let identifiers = ["rescan", "history", "settings"].map { NSToolbarItem.Identifier("NameFix." + $0) }
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
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [NSToolbarItem.Identifier("NameFix.sidebar"), NSToolbarItem.Identifier("NameFix.separator"), .flexibleSpace] + identifiers }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { toolbarDefaultItemIdentifiers(toolbar) }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if identifier.rawValue == "NameFix.separator", let splitController {
            return NSTrackingSeparatorToolbarItem(identifier: identifier, splitView: splitController.splitView, dividerIndex: 0)
        }
        if identifier.rawValue == "NameFix.sidebar" {
            let item = NSToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: model.t("ToggleSidebar"))
            item.label = model.t("ToggleSidebar"); item.toolTip = item.label
            item.target = self; item.action = #selector(toggleSidebar)
            return item
        }
        guard let index = identifiers.firstIndex(of: identifier) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        let button = NSButton(image: NSImage(systemSymbolName: ["arrow.clockwise", "clock.arrow.circlepath", "gearshape"][index], accessibilityDescription: nil) ?? NSImage(size: NSSize(width: 17, height: 17)), target: self, action: [#selector(rescan), #selector(history), #selector(settings)][index])
        button.bezelStyle = .texturedRounded; button.imagePosition = .imageOnly
        button.image = button.image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 17, weight: .regular))
        button.frame = NSRect(x: 0, y: 0, width: 40, height: 36)
        button.setAccessibilityIdentifier(["rescan", "history", "settings"][index])
        item.view = button; item.target = self; item.action = button.action
        configure(item, index: index)
        return item
    }
    private func configure(_ item: NSToolbarItem, index: Int) {
        let title = model.t(["Rescan", "HistoryShort", "Settings"][index])
        item.label = title; item.paletteLabel = title; item.toolTip = title
        item.isEnabled = enabled(index)
        if let button = item.view as? NSButton {
            button.toolTip = title; button.setAccessibilityLabel(title); button.isEnabled = item.isEnabled
        }
    }
    private func enabled(_ index: Int) -> Bool {
        model.plan == nil && model.result == nil && (index != 0 || (model.canInput && !model.busy && !model.roots.isEmpty))
    }
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        guard let index = identifiers.firstIndex(of: item.itemIdentifier) else { return true }
        return enabled(index)
    }
    func refresh() { for item in toolbar.items { if item.itemIdentifier.rawValue == "NameFix.sidebar" { item.label = model.t("ToggleSidebar"); item.toolTip = item.label }; if let index = identifiers.firstIndex(of: item.itemIdentifier) { configure(item, index: index) } } }
    @objc private func toggleSidebar() { splitController?.toggleSidebar(nil) }
    @objc private func rescan() { guard model.canInput, !model.busy, !model.roots.isEmpty else { return }; model.scan() }
    @objc private func history() { guard model.plan == nil, model.result == nil else { return }; model.sheet = "history"; Task { await model.reloadHistory() } }
    @objc private func settings() { guard model.plan == nil, model.result == nil else { return }; model.sheet = "settings" }
}
