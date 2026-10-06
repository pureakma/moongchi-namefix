import AppKit
import SwiftUI

@MainActor final class MainSidebarController: NSSplitViewController {
    let navigationItem: NSSplitViewItem
    init(model: AppModel, startAdvanced: Bool = false) {
        let navigation = NSViewController()
        let sidebar = DropHostingView(rootView: SidebarNavigation(model: model)); sidebar.model = model; sidebar.sizingOptions = []
        let container = NSView()
        navigation.view = container
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        let backdrop = NSHostingView(rootView: SidebarBackdrop(model: model))
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: container.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        // App name beside the window controls, centred in the title bar band.
        let title = NSHostingView(rootView: SidebarTitle(model: model)); title.translatesAutoresizingMaskIntoConstraints = false
        title.safeAreaRegions = []  // it sits inside the title bar band; do not push the text below it
        let band = NSLayoutGuide(); container.addLayoutGuide(band)
        container.addSubview(title)
        NSLayoutConstraint.activate([
            band.topAnchor.constraint(equalTo: container.topAnchor),
            band.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            title.centerYAnchor.constraint(equalTo: band.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 92)
        ])
        container.addSubview(sidebar)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        navigationItem = NSSplitViewItem(sidebarWithViewController: navigation)
        self.model = model
        super.init(nibName: nil, bundle: nil)
        navigationItem.minimumThickness = 220; navigationItem.maximumThickness = 380
        navigationItem.canCollapse = true
        navigationItem.allowsFullHeightLayout = true
        let detail = NSViewController()
        let host = DropHostingView(rootView: MainView(model: model, startAdvanced: startAdvanced)); host.model = model; host.sizingOptions = []
        detail.view = host
        addSplitViewItem(navigationItem); addSplitViewItem(NSSplitViewItem(viewController: detail))
        // A new autosave name so earlier wide defaults do not carry over.
        splitView.autosaveName = "NameFix.Sidebar.v3"
    }
    required init?(coder: NSCoder) { nil }
    private var placedDivider = false
    override func viewDidAppear() {
        super.viewDidAppear()
        // First run starts at the compact width; later runs restore what the user dragged to.
        guard !placedDivider else { return }; placedDivider = true
        if UserDefaults.standard.object(forKey: "NSSplitView Subview Frames NameFix.Sidebar.v3") == nil { splitView.setPosition(240, ofDividerAt: 0) }
    }
    /// The sidebar has no toggle button: it yields to the content in narrow windows and returns when there is room.
    func fit(width: CGFloat) {
        let collapse = width < 760
        if navigationItem.isCollapsed != collapse { navigationItem.isCollapsed = collapse }
        if model.sidebarCollapsed != collapse { model.sidebarCollapsed = collapse }
    }
    private let model: AppModel
}

/// Sidebar = a narrow icon rail for navigation plus the tree of what was added.
struct SidebarNavigation: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    private var locked: Bool { model.busy || model.plan != nil || model.result != nil }
    var body: some View {
        HStack(spacing: 0) {
            rail
            Divider()
            tree
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.sidebar.ignoresSafeArea()).foregroundStyle(palette.text)
            .font(L10n.font(model.settings.language)).tint(palette.accent)
    }

    // MARK: Icon rail — every destination is one icon with a tooltip

    private var rail: some View {
        VStack(spacing: 4) {
            destination("RestoreNames", tip: "RestoreNamesDetail", icon: "character.cursor.ibeam", selected: !model.isWorkbench) { model.openQuickCleanup() }
            destination("BatchWorkspace", tip: "BatchWorkspaceDetail", icon: "pencil.line", selected: model.isWorkbench) { model.openWorkbench() }
            destination("FolderWatch", tip: "WatchToolDetail", icon: "folder.badge.gearshape") { model.sheet = "watch" }
            destination("TextTool", tip: "TextToolDetail", icon: "doc.on.clipboard") { model.clipboard = ""; model.clipboardTruncated = false; model.sheet = "clipboard" }
            Spacer(minLength: 8)
            destination("HistoryShort", tip: "HistoryDetail", icon: "clock.arrow.circlepath", identifier: "history") { model.sheet = "history"; Task { await model.reloadHistory() } }
            destination("Settings", icon: "gearshape", identifier: "settings") { model.sheet = "settings" }
            destination("HelpMenu", icon: "questionmark.circle", identifier: "help") { model.sheet = "help" }
        }.padding(.vertical, 8).frame(width: 46).disabled(locked)
    }
    private func destination(_ title: String, tip: String? = nil, icon: String, selected: Bool = false, identifier: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 15)).frame(width: 34, height: 30)
                .foregroundStyle(selected ? palette.accent : palette.secondary)
                .background(selected ? palette.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .help(tip.map { model.t(title) + " — " + model.t($0) } ?? model.t(title))
            .accessibilityLabel(model.t(title)).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(identifier ?? title)
    }

    // MARK: Tree of added files and folders

    private var tree: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(model.t("TreeTitle")).font(.caption).foregroundStyle(palette.secondary).lineLimit(1).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                if !model.roots.isEmpty {
                    Menu {
                        Toggle(model.t("Recursive"), isOn: Binding(get: { model.settings.recursive }, set: { value in model.changeSettings { $0.recursive = value } }))
                        Divider()
                        Button(model.t("ResetInputs")) { model.remove(nil) }
                    } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        .help(model.t("TreeOptions")).accessibilityLabel(model.t("TreeOptions"))
                }
            }.padding(.horizontal, 10).frame(height: 22)
            if model.folderTree.isEmpty {
                Text(model.t("TreeEmpty")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 10)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        row(icon: "tray.full", name: model.t("TreeAll"), pending: 0, depth: 0, selected: model.folderFilter == nil, expanded: nil) { model.folderFilter = nil }
                        ForEach(model.folderTree) { FolderBranch(model: model, palette: palette, node: $0, depth: 0) }
                    }.padding(.horizontal, 6)
                }
            }
        }.padding(.top, 8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).disabled(locked)
    }
    private func row(icon: String, name: String, pending: Int, depth: Int, selected: Bool, expanded: Binding<Bool>?, action: @escaping () -> Void) -> some View {
        FolderRow(palette: palette, icon: icon, name: name, pending: pending, depth: depth, selected: selected, expanded: expanded, pendingLabel: model.t("TreePending", model.n(pending)), action: action)
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
                      pendingLabel: model.t("TreePending", model.n(node.pending))) {
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
    let action: () -> Void
    var body: some View {
        HStack(spacing: 4) {
            if let expanded {
                Button { expanded.wrappedValue.toggle() } label: {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0)).frame(width: 14, height: 18).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(palette.secondary).accessibilityLabel(name).accessibilityValue(expanded.wrappedValue ? "1" : "0")
            } else { Color.clear.frame(width: 14, height: 18) }
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: icon).frame(width: 16).foregroundStyle(selected ? palette.accent : palette.secondary).accessibilityHidden(true)
                    Text(name).lineLimit(1).truncationMode(.middle).fontWeight(selected ? .semibold : .regular)
                    Spacer(minLength: 2)
                    if pending > 0 { Text(String(pending)).font(.caption).monospacedDigit().foregroundStyle(palette.preview).accessibilityLabel(pendingLabel) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
        }
        .padding(.leading, CGFloat(depth) * 12).padding(.trailing, 6).padding(.vertical, 3)
        .background(selected ? palette.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct SidebarTitle: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text("NameFix").font(L10n.font(model.settings.language, size: 13, weight: .semibold))
            .foregroundStyle(Palette(model.settings.theme, systemDark: scheme == .dark).text).fixedSize().accessibilityAddTraits(.isHeader)
    }
}

private struct SidebarBackdrop: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    var body: some View { Palette(model.settings.theme, systemDark: scheme == .dark).sidebar.ignoresSafeArea() }
}
