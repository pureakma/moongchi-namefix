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
        // The buttons are the app's own views so that they can name themselves on hover.
        let button = ToolbarIconButton(symbol: ["square.and.arrow.up", "arrow.clockwise", "plus"][index])
        if index == 2 { button.pullDown = addMenu; button.target = button; button.action = #selector(ToolbarIconButton.openMenu) }
        else { button.target = self; button.action = index == 0 ? #selector(export) : #selector(rescan) }
        let item = NSToolbarItem(itemIdentifier: identifier); item.view = button; item.autovalidates = false
        configure(item, index: index)
        return item
    }
    private func configure(_ item: NSToolbarItem, index: Int) {
        let title = model.t(["ExportShort", "Rescan", "AddMore"][index])
        item.label = title; item.paletteLabel = title
        (item.view as? ToolbarIconButton)?.name = title
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
        func section(_ title: String) { menu.addItem(.separator()); let header = NSMenuItem(title: model.t(title), action: nil, keyEquivalent: ""); header.isEnabled = false; menu.addItem(header) }
        if !model.favorites.isEmpty {
            section("Favorites")
            for favorite in model.favorites {
                let missing = model.favoriteProblems.contains(favorite.id)
                let item = ActionItem(URL(fileURLWithPath: favorite.path).lastPathComponent) { [weak self] in
                    if missing { AppDelegate.shared?.pickFavorite(replacing: favorite.id) } else { self?.model.openFavorite(favorite) }
                }
                item.image = NSImage(systemSymbolName: missing ? "exclamationmark.triangle" : "star", accessibilityDescription: nil); item.toolTip = favorite.path
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        menu.addItem(ActionItem(model.t("AddFavorite") + "…") { AppDelegate.shared?.pickFavorite() })
        let recent = model.recentShortcuts
        guard !recent.isEmpty else { return }
        section("RecentFolders")
        for path in recent { menu.addItem(ActionItem(URL(fileURLWithPath: path).lastPathComponent) { [weak self] in self?.model.openRecent(path) }) }
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

/// The name of an icon-only control, shown beside it while the pointer is on it. System tooltips
/// did not appear for users, and an icon alone should never have to be guessed, so these controls
/// name themselves. The label is a click-through child window: it moves nothing and takes no input.
@MainActor final class HoverTip {
    static let shared = HoverTip()
    var fill = NSColor.labelColor, ink = NSColor.windowBackgroundColor
    private weak var owner: NSView?
    private var panel: NSPanel?
    private var monitor: Any?
    func show(_ text: String, beside view: NSView, below: Bool) {
        hide()
        guard !text.isEmpty, let window = view.window, window.isVisible else { return }
        let label = NSTextField(labelWithString: text); label.font = .systemFont(ofSize: 12, weight: .medium); label.textColor = ink
        let size = label.fittingSize, box = NSSize(width: ceil(size.width) + 18, height: ceil(size.height) + 10)
        let content = NSView(frame: NSRect(origin: .zero, size: box)); content.wantsLayer = true
        content.layer?.backgroundColor = fill.withAlphaComponent(0.94).cgColor; content.layer?.cornerRadius = 7; content.layer?.cornerCurve = .continuous
        label.frame = NSRect(x: 9, y: 5, width: ceil(size.width), height: ceil(size.height)); content.addSubview(label)
        content.setAccessibilityElement(false)
        let anchor = window.convertToScreen(view.convert(view.bounds, to: nil))
        var origin = NSPoint(x: anchor.midX - box.width / 2, y: below ? anchor.minY - box.height - 5 : anchor.maxY + 5)
        if let screen = window.screen?.visibleFrame {
            origin.x = min(max(origin.x, screen.minX + 4), screen.maxX - box.width - 4)
            if origin.y < screen.minY + 4 { origin.y = anchor.maxY + 5 }
        }
        let panel = NSPanel(contentRect: NSRect(origin: origin, size: box), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false; panel.contentView = content
        window.addChildWindow(panel, ordered: .above)
        self.panel = panel; owner = view
        // Acting on the control, typing or scrolling puts the label away.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in self?.hide(); return event }
    }
    func hide(from view: NSView? = nil) {
        guard view == nil || view === owner else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let panel { panel.parent?.removeChildWindow(panel); panel.orderOut(nil) }
        monitor = nil; panel = nil; owner = nil
    }
}

/// Tracks the pointer over a control and shows its name. It never takes a click.
final class HoverTipView: NSView {
    var text = ""
    var below = true
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { HoverTip.shared.show(text, beside: self, below: below) }
    override func mouseExited(with event: NSEvent) { HoverTip.shared.hide(from: self) }
    override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { HoverTip.shared.hide(from: self) }; super.viewWillMove(toWindow: newWindow) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct HoverTipAnchor: NSViewRepresentable {
    let text: String
    let below: Bool
    func makeNSView(context: Context) -> HoverTipView { HoverTipView() }
    func updateNSView(_ view: HoverTipView, context: Context) { view.text = text; view.below = below }
}
extension View {
    /// Names an icon-only control on hover. Controls that show their own text do not need it.
    func hoverTip(_ text: String, below: Bool = true) -> some View { background(HoverTipAnchor(text: text, below: below)) }
}

/// Icon button for the title bar band that names itself on hover like every other icon-only control.
final class ToolbarIconButton: NSButton {
    private let tip = HoverTipView()
    var pullDown: NSMenu?
    init(symbol: String) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil); imagePosition = .imageOnly; bezelStyle = .toolbar
        tip.autoresizingMask = [.width, .height]; tip.frame = bounds; addSubview(tip)
    }
    required init?(coder: NSCoder) { nil }
    var name: String = "" { didSet { tip.text = name; setAccessibilityLabel(name) } }
    /// A button with a menu opens it under itself.
    @objc func openMenu() { pullDown?.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 4), in: self) }
}
