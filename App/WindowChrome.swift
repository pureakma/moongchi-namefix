import AppKit
import SwiftUI
import Combine

/// Title bar band over the content: the current screen name as the window title and, on the
/// right, the actions that only make sense once something has been added (save results, rescan,
/// add more). The app name sits beside the window buttons, above the navigation.
@MainActor final class WindowChrome: NSObject, NSToolbarDelegate, NSMenuDelegate {
    private weak var window: NSWindow?
    private let model: AppModel
    private var observation: AnyCancellable?
    // Toolbars sharing an identifier mirror each other's item changes; items here follow one window's state.
    let toolbar = NSToolbar(identifier: "NameFix.MainToolbar." + UUID().uuidString)
    private let actions = ["export", "rescan", "add"].map { NSToolbarItem.Identifier("NameFix." + $0) }
    private let addMenu = NSMenu()
    init(model: AppModel) {
        self.model = model
        super.init()
        toolbar.delegate = self; toolbar.displayMode = .iconOnly; toolbar.sizeMode = .regular
        toolbar.allowsUserCustomization = false; toolbar.autosavesConfiguration = false
        toolbar.showsBaselineSeparator = false
        addMenu.delegate = self
        observation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }
    func install(on window: NSWindow, split: MainSidebarController? = nil) {
        self.window = window
        window.titleVisibility = .visible
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .unified
        window.toolbar = toolbar
        refresh()
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.flexibleSpace] + actions }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let index = actions.firstIndex(of: identifier) else { return nil }
        let symbol = ["square.and.arrow.up", "arrow.clockwise", "plus"][index]
        let item: NSToolbarItem
        if index == 2 {
            let menuItem = NSMenuToolbarItem(itemIdentifier: identifier); menuItem.menu = addMenu; menuItem.showsIndicator = true; item = menuItem
        } else {
            item = NSToolbarItem(itemIdentifier: identifier); item.target = self; item.action = index == 0 ? #selector(export) : #selector(rescan)
        }
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); item.isBordered = true; item.autovalidates = false
        configure(item, index: index)
        return item
    }
    private func configure(_ item: NSToolbarItem, index: Int) {
        let title = model.t(["ExportShort", "Rescan", "AddMore"][index])
        item.label = title; item.paletteLabel = title; item.toolTip = title
        item.isEnabled = enabled(index)
    }
    private func enabled(_ index: Int) -> Bool {
        guard model.plan == nil, model.result == nil, !model.busy else { return false }
        return index == 0 ? !model.entries.isEmpty : model.canInput
    }
    /// The action items exist only while there is something to act on.
    func refresh() {
        let screen = model.t(model.isWorkbench ? "BatchWorkspace" : "RestoreNames")
        if window?.title != screen { window?.title = screen }
        let wanted = !model.roots.isEmpty
        let present = toolbar.items.contains { actions.contains($0.itemIdentifier) }
        if wanted && !present { for identifier in actions { toolbar.insertItem(withItemIdentifier: identifier, at: toolbar.items.count) } }
        if !wanted && present { for index in toolbar.items.indices.reversed() where actions.contains(toolbar.items[index].itemIdentifier) { toolbar.removeItem(at: index) } }
        for item in toolbar.items { if let index = actions.firstIndex(of: item.itemIdentifier) { configure(item, index: index) } }
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(ActionItem(model.t("ChooseFiles")) { AppDelegate.shared?.pick(folders: false) })
        menu.addItem(ActionItem(model.t("ChooseFolders")) { AppDelegate.shared?.pick(folders: true) })
        guard model.settings.rememberRecentFolders, !model.settings.recentFolders.isEmpty else { return }
        menu.addItem(.separator())
        let header = NSMenuItem(title: model.t("RecentFolders"), action: nil, keyEquivalent: ""); header.isEnabled = false; menu.addItem(header)
        for path in model.settings.recentFolders {
            menu.addItem(ActionItem(URL(fileURLWithPath: path).lastPathComponent) { [weak self] in self?.model.add([URL(fileURLWithPath: path)]) })
        }
    }
    @objc private func export() { guard !model.entries.isEmpty else { return }; model.present("tools") }
    @objc private func rescan() { guard model.canInput, !model.busy, !model.roots.isEmpty else { return }; model.scan() }
}

/// An image view blocks window moves by default; this one is part of the drag handle.
private final class BrandIcon: NSImageView {
    override var mouseDownCanMoveWindow: Bool { true }
}

/// "[icon] NameFix" beside the window buttons. It is a drag handle like the rest of the band:
/// the icon and label never take the click.
final class TitleBrandView: WindowDragView {
    private let icon = BrandIcon()
    private let name = NSTextField(labelWithString: "NameFix")
    override init(frame: NSRect) {
        super.init(frame: frame)
        icon.image = NSImage(named: NSImage.applicationIconName); icon.imageScaling = .scaleProportionallyUpOrDown
        name.font = .systemFont(ofSize: 15, weight: .semibold)
        let stack = NSStackView(views: [icon, name])
        stack.orientation = .horizontal; stack.alignment = .centerY; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 20), icon.heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        name.setContentCompressionResistancePriority(.required, for: .horizontal)
        setAccessibilityElement(true); setAccessibilityRole(.staticText); setAccessibilityLabel("NameFix")
    }
    required init?(coder: NSCoder) { nil }
    func update(text: NSColor) { name.textColor = text }
    // One drag handle; its label and icon never receive the click.
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
}
