import AppKit
import SwiftUI
import Combine

/// Left side of the window. It has no toggle: nothing added → named navigation,
/// something added → icon rail + folder tree, narrow window → hidden.
@MainActor final class MainSidebarController: NSSplitViewController {
    let navigationItem: NSSplitViewItem
    private let model: AppModel
    private var observation: AnyCancellable?
    private var windowWidth: CGFloat = 1180
    private var remembersTreeWidth = false
    private var applying = false
    private(set) var mode: SidebarMode = .navigation
    private let brand = TitleBrandView()
    private let backdrop: TintedView, surface: TintedView
    private var themeObservation: AnyCancellable?
    private static let treeWidthKey = "NameFix.TreeWidth.v1"
    init(model: AppModel, rulesFirst: Bool = false) {
        self.model = model
        let navigation = NSViewController()
        let sidebar = DropHostingView(rootView: SidebarNavigation(model: model)); sidebar.model = model; sidebar.sizingOptions = []
        // No SwiftUI hosting view may lie under the title bar band: AppKit counts a hosting view's
        // whole frame as blocking window moves, which empties the window's drag region and leaves
        // dragging to whichever view happens to get the press. The band is plain AppKit views.
        let container = TintedView(), surface = TintedView(); backdrop = container; self.surface = surface
        navigation.view = container
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        let band = NSLayoutGuide(); container.addLayoutGuide(band)
        let handle = WindowDragView(); handle.translatesAutoresizingMaskIntoConstraints = false
        handle.dropTarget = sidebar
        container.addSubview(handle)
        NSLayoutConstraint.activate([
            band.topAnchor.constraint(equalTo: container.topAnchor),
            band.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            handle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            handle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            handle.topAnchor.constraint(equalTo: band.topAnchor),
            handle.bottomAnchor.constraint(equalTo: band.bottomAnchor)
        ])
        // App icon and name beside the window buttons, on the band's centre line.
        container.addSubview(brand); brand.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            brand.centerYAnchor.constraint(equalTo: band.centerYAnchor),
            brand.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: WindowLayout.brandLeading)
        ])
        container.addSubview(sidebar)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        navigationItem = NSSplitViewItem(sidebarWithViewController: navigation)
        super.init(nibName: nil, bundle: nil)
        // The panel draws its own hairlines; the split view's divider would cut straight through the band.
        splitView = ClearDividerSplitView()
        splitView.isVertical = true; splitView.dividerStyle = .thin
        navigationItem.allowsFullHeightLayout = true
        navigationItem.titlebarSeparatorStyle = .none
        // Hidden only through apply(); neither the divider nor AppKit's resize handling may collapse it.
        navigationItem.canCollapse = false
        navigationItem.canCollapseFromWindowResize = false
        let detail = NSViewController()
        let host = DropHostingView(rootView: MainView(model: model, rulesFirst: rulesFirst)); host.model = model; host.sizingOptions = []
        // The content starts below the band for the same reason; the strip above it still takes
        // presses the system title bar passes through, and file drops.
        let contentHandle = WindowDragView(); contentHandle.dropTarget = host
        host.translatesAutoresizingMaskIntoConstraints = false; contentHandle.translatesAutoresizingMaskIntoConstraints = false
        surface.addSubview(host); surface.addSubview(contentHandle)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: surface.leadingAnchor), host.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            host.topAnchor.constraint(equalTo: surface.safeAreaLayoutGuide.topAnchor), host.bottomAnchor.constraint(equalTo: surface.bottomAnchor),
            contentHandle.leadingAnchor.constraint(equalTo: surface.leadingAnchor), contentHandle.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            contentHandle.topAnchor.constraint(equalTo: surface.topAnchor), contentHandle.bottomAnchor.constraint(equalTo: surface.safeAreaLayoutGuide.topAnchor)
        ])
        detail.view = surface
        let content = NSSplitViewItem(viewController: detail); content.titlebarSeparatorStyle = .none
        addSplitViewItem(navigationItem); addSplitViewItem(content)
        apply(); tint()
        themeObservation = model.objectWillChange.sink { [weak self] _ in Task { @MainActor [weak self] in self?.tint() } }
        // @Published emits before the change lands, so read the model on the next main-actor turn.
        observation = model.$roots.map(\.isEmpty).removeDuplicates().sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.apply() }
        }
    }
    required init?(coder: NSCoder) { nil }
    private func tint() {
        let dark = (view.window?.effectiveAppearance ?? NSApp.effectiveAppearance).bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let palette = Palette(model.settings.theme, systemDark: dark)
        brand.update(text: NSColor(palette.text))
        backdrop.fill = NSColor(palette.sidebar); surface.fill = NSColor(palette.sidebar)
    }
    /// Only the real window remembers the tree width. Render fixtures run the same binary and
    /// must not write their throwaway layouts into the user's saved state.
    func rememberWidth() { remembersTreeWidth = true; apply() }
    func fit(width: CGFloat) { windowWidth = width; apply() }
    override func viewDidAppear() { super.viewDidAppear(); apply(); tint() }
    private var storedTreeWidth: CGFloat? {
        remembersTreeWidth ? (UserDefaults.standard.object(forKey: Self.treeWidthKey) as? Double).map { CGFloat($0) } : nil
    }
    /// Brings the sidebar in line with the input state and window width.
    private func apply() {
        let next = WindowLayout.sidebarMode(windowWidth: windowWidth, hasInput: !model.roots.isEmpty)
        applying = true; defer { applying = false }
        let hidden = next == .hidden
        if navigationItem.isCollapsed != hidden {
            // canCollapse also gates programmatic changes, so it is opened only for this call.
            navigationItem.canCollapse = true
            navigationItem.isCollapsed = hidden
        }
        if navigationItem.canCollapse != hidden { navigationItem.canCollapse = hidden }
        if !hidden {
            let widths = WindowLayout.sidebarWidths(next, treeWidth: storedTreeWidth)
            // Widen the limits before moving the divider, then settle on the mode's own limits.
            navigationItem.minimumThickness = min(navigationItem.minimumThickness, widths.minimum)
            navigationItem.maximumThickness = max(navigationItem.maximumThickness, widths.maximum)
            if isViewLoaded, next != mode || abs(navigationItem.viewController.view.frame.width - widths.preferred) > 0.5 && next == .navigation {
                splitView.setPosition(widths.preferred, ofDividerAt: 0)
            }
            navigationItem.minimumThickness = widths.minimum; navigationItem.maximumThickness = widths.maximum
        }
        mode = next
        if model.sidebarCollapsed != hidden { model.sidebarCollapsed = hidden }
    }
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        guard isViewLoaded, !applying else { return }
        let width = navigationItem.viewController.view.frame.width
        // A drag of the divider is the only way the user changes the tree width.
        if mode == .railWithTree, remembersTreeWidth, NSApp.currentEvent?.type == .leftMouseDragged, width > WindowLayout.railWidth {
            UserDefaults.standard.set(Double(WindowLayout.treeWidth(width - WindowLayout.railWidth)), forKey: Self.treeWidthKey)
        }
        // Whatever else changes the split layout, a wide window always ends up with its sidebar.
        if let window = view.window, window.frame.width >= WindowLayout.sidebarHiddenBelow, navigationItem.isCollapsed {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }
    }
}

/// Canvas-coloured area below the title bar band. Its hairline continues the title bar's bottom
/// edge and, where it meets the navigation, turns down through a rounded corner.
struct ChromePanel: View {
    enum Leading { case rounded, squared, none }
    let palette: Palette
    let leading: Leading
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width, height = proxy.size.height, radius: CGFloat = leading == .rounded ? Metrics.corner : 0
            Path { path in
                path.move(to: CGPoint(x: 0, y: height)); path.addLine(to: CGPoint(x: 0, y: radius))
                if radius > 0 { path.addArc(center: CGPoint(x: radius, y: radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
                path.addLine(to: CGPoint(x: width, y: 0)); path.addLine(to: CGPoint(x: width, y: height)); path.closeSubpath()
            }.fill(palette.canvas)
            Path { path in
                if leading == .none { path.move(to: CGPoint(x: 0, y: 0.5)) } else {
                    path.move(to: CGPoint(x: 0.5, y: height)); path.addLine(to: CGPoint(x: 0.5, y: radius + 0.5))
                    if radius > 0 { path.addArc(center: CGPoint(x: radius + 0.5, y: radius + 0.5), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false) }
                }
                path.addLine(to: CGPoint(x: width, y: 0.5))
            }.stroke(palette.border, lineWidth: 1)
        }.accessibilityHidden(true)
    }
}

struct SidebarNavigation: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    private var locked: Bool { model.busy || model.plan != nil || model.result != nil }
    private struct Destination: Identifiable { let id: String; let tip: String?; let icon: String }
    private let primary = [
        Destination(id: "RestoreNames", tip: "RestoreNamesDetail", icon: "character.cursor.ibeam"),
        Destination(id: "BatchWorkspace", tip: "BatchWorkspaceDetail", icon: "pencil.line"),
        Destination(id: "FolderWatch", tip: "WatchToolDetail", icon: "folder.badge.gearshape"),
        Destination(id: "TextTool", tip: "TextToolDetail", icon: "doc.on.clipboard")
    ]
    private let secondary = [
        Destination(id: "HistoryShort", tip: "HistoryDetail", icon: "clock.arrow.circlepath"),
        Destination(id: "Settings", tip: nil, icon: "gearshape"),
        Destination(id: "HelpMenu", tip: nil, icon: "questionmark.circle")
    ]
    var body: some View {
        Group {
            if model.roots.isEmpty { navigation(expanded: true) }
            else { HStack(spacing: 0) { navigation(expanded: false).frame(width: WindowLayout.railWidth); tree } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(palette.text).font(L10n.font(model.settings.language)).tint(palette.accent)
    }

    // MARK: Navigation — the same rows as names (nothing added) or as an icon rail (something added)

    private func navigation(expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(primary) { destination(for: $0, expanded: expanded) }
            Spacer(minLength: Metrics.gap)
            ForEach(secondary) { destination(for: $0, expanded: expanded) }
        }
        .padding(.horizontal, expanded ? 10 : 7).padding(.vertical, Metrics.gap)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .disabled(locked).accessibilityElement(children: .contain).accessibilityLabel(model.t("NavigationLabel"))
    }
    private func destination(for item: Destination, expanded: Bool) -> some View {
        let selected = item.id == "RestoreNames" ? !model.isWorkbench : item.id == "BatchWorkspace" ? model.isWorkbench : false
        return Button { open(item.id) } label: {
            HStack(spacing: 9) {
                Image(systemName: item.icon).font(.system(size: 14)).frame(width: 20, height: 20)
                    .foregroundStyle(selected ? palette.accent : palette.secondary).accessibilityHidden(true)
                if expanded { Text(model.t(item.id)).fontWeight(selected ? .semibold : .regular).lineLimit(1); Spacer(minLength: 0) }
            }
            .padding(.horizontal, 7).frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
            .background(selected ? palette.accent.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.tip.map { model.t(item.id) + " — " + model.t($0) } ?? model.t(item.id))
        .accessibilityLabel(model.t(item.id)).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(["HistoryShort": "history", "Settings": "settings", "HelpMenu": "help"][item.id] ?? item.id)
    }
    private func open(_ id: String) {
        switch id {
        case "RestoreNames": model.openQuickCleanup()
        case "BatchWorkspace": model.openWorkbench()
        case "FolderWatch": model.sheet = "watch"
        case "TextTool": model.clipboard = ""; model.clipboardTruncated = false; model.sheet = "clipboard"
        case "HistoryShort": model.sheet = "history"; Task { await model.reloadHistory() }
        case "Settings": model.sheet = "settings"
        default: model.sheet = "help"
        }
    }

    // MARK: Tree of added files and folders — exists only while something is added

    private var tree: some View {
        VStack(alignment: .leading, spacing: Metrics.control) {
            HStack(spacing: 4) {
                Text(model.t("TreeTitle")).fontWeight(.medium).lineLimit(1).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Menu {
                    Toggle(model.t("Recursive"), isOn: Binding(get: { model.settings.recursive }, set: { value in model.changeSettings { $0.recursive = value } }))
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .help(model.t("TreeOptions")).accessibilityLabel(model.t("TreeOptions"))
                // The way back to the first screen is always in sight.
                Button { model.remove(nil) } label: { Image(systemName: "xmark.circle") }.buttonStyle(.plain).foregroundStyle(palette.secondary)
                    .help(model.t("ResetInputs") + " — " + model.t("CloseAllHelp")).accessibilityLabel(model.t("ResetInputs")).accessibilityIdentifier("closeAll")
            }.frame(height: Metrics.paneHeader).padding(.horizontal, 6)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    // "Show all" only matters when there is a folder to narrow to.
                    if model.folderTree.contains(where: \.isDirectory) || model.folderTree.count > 1 {
                        FolderRow(palette: palette, icon: "tray.full", name: model.t("TreeAll"), pending: 0, depth: 0, selected: model.folderFilter == nil, expanded: nil, pendingLabel: "") { model.folderFilter = nil }
                    }
                    ForEach(model.folderTree) { FolderBranch(model: model, palette: palette, node: $0, depth: 0) }
                }
            }
        }
        .padding(.horizontal, 6).padding(.top, Metrics.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { ChromePanel(palette: palette, leading: .rounded) }
        .disabled(locked)
    }
}

/// One folder with its subfolders. Added items start expanded; deeper levels open on request.
private struct FolderBranch: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    let node: FolderNode
    let depth: Int
    @State private var expanded: Bool
    init(model: AppModel, palette: Palette, node: FolderNode, depth: Int) {
        self.model = model; self.palette = palette; self.node = node; self.depth = depth
        _expanded = State(initialValue: depth == 0)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            FolderRow(palette: palette, icon: node.isDirectory ? "folder" : "doc", name: node.name, pending: node.pending, depth: depth,
                      selected: model.folderFilter == node.id, expanded: node.children == nil ? nil : $expanded,
                      pendingLabel: model.t("TreePending", model.n(node.pending)),
                      closeLabel: node.isRoot ? model.t("RemoveInput") : nil, close: { model.remove(node.id) }) {
                model.folderFilter = model.folderFilter == node.id ? nil : node.id
            }
            .help(node.id.display)
            .contextMenu {
                if node.isRoot { Button(model.t("RemoveInput")) { model.remove(node.id) } }
                Button(model.t("CopyPath")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(node.id.display, forType: .string) }
            }
            if expanded, let children = node.children {
                ForEach(children) { FolderBranch(model: model, palette: palette, node: $0, depth: depth + 1) }
            }
        }
    }
}

private struct FolderRow: View {
    let palette: Palette
    let icon: String
    let name: String
    let pending: Int
    let depth: Int
    let selected: Bool
    let expanded: Binding<Bool>?
    let pendingLabel: String
    var closeLabel: String? = nil
    var close: () -> Void = {}
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        HStack(spacing: 4) {
            if let expanded {
                Button { expanded.wrappedValue.toggle() } label: {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0)).frame(width: 16, height: 22).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(palette.secondary).accessibilityLabel(name).accessibilityValue(expanded.wrappedValue ? "1" : "0")
            } else { Color.clear.frame(width: 16, height: 22) }
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: icon).frame(width: 16).foregroundStyle(selected ? palette.accent : palette.secondary).accessibilityHidden(true)
                    Text(name).lineLimit(1).truncationMode(.middle).fontWeight(selected ? .semibold : .regular)
                    Spacer(minLength: 2)
                    if pending > 0 { Text(String(pending)).font(.caption).monospacedDigit().foregroundStyle(palette.preview).accessibilityLabel(pendingLabel) }
                }.frame(maxWidth: .infinity, minHeight: 22, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            // Added items can be closed one by one; the button shows while the pointer is on the row.
            if let closeLabel, hovering || selected {
                Button(action: close) { Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).frame(width: 16, height: 22).contentShape(Rectangle()) }
                    .buttonStyle(.plain).foregroundStyle(palette.secondary).help(closeLabel).accessibilityLabel(closeLabel + " " + name)
            }
        }
        .onHover { hovering = $0 }
        .padding(.leading, CGFloat(depth) * 12).padding(.trailing, 6).padding(.vertical, 2)
        .background(selected ? palette.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

final class ClearDividerSplitView: NSSplitView {
    override var dividerColor: NSColor { .clear }
}

/// Transparent strip for a title bar band: drag to move, double-click as the system setting says.
/// Files dropped on it go to the view below the band.
class WindowDragView: NSView {
    weak var dropTarget: NSView? { didSet { registerForDraggedTypes([.fileURL]) } }
    override var mouseDownCanMoveWindow: Bool { true }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { dropTarget?.draggingEntered(sender) ?? [] }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { dropTarget?.draggingUpdated(sender) ?? [] }
    override func draggingExited(_ sender: NSDraggingInfo?) { dropTarget?.draggingExited(sender) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { dropTarget?.prepareForDragOperation(sender) ?? false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool { dropTarget?.performDragOperation(sender) ?? false }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { dropTarget?.concludeDragOperation(sender) }
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        if event.clickCount == 2 {
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize": window.performMiniaturize(nil)
            case "None": break
            default: window.performZoom(nil)
            }
        } else { window.performDrag(with: event) }
    }
}

/// Window chrome colour behind the navigation and the title bar band, drawn without SwiftUI.
final class TintedView: NSView {
    var fill: NSColor = .clear { didSet { wantsLayer = true; layer?.backgroundColor = fill.cgColor } }
    override var mouseDownCanMoveWindow: Bool { true }
}
