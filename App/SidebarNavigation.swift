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
        container.addSubview(sidebar)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sidebar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sidebar.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        navigationItem = NSSplitViewItem(sidebarWithViewController: navigation)
        super.init(nibName: nil, bundle: nil)
        navigationItem.minimumThickness = 200; navigationItem.maximumThickness = 280
        navigationItem.canCollapse = true
        navigationItem.allowsFullHeightLayout = true
        let detail = NSViewController()
        let host = DropHostingView(rootView: MainView(model: model, startAdvanced: startAdvanced)); host.model = model; host.sizingOptions = []
        detail.view = host
        addSplitViewItem(navigationItem); addSplitViewItem(NSSplitViewItem(viewController: detail))
        splitView.autosaveName = "NameFix.NavigationSidebar"
    }
    required init?(coder: NSCoder) { nil }
    func fit(width: CGFloat) { if width < 760 { navigationItem.isCollapsed = true } }
}

struct SidebarNavigation: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            section("FileTasks") {
                navigation("RestoreNames", tip: "RestoreNamesDetail", icon: "character.cursor.ibeam", selected: !model.isWorkbench) { model.openQuickCleanup() }
                navigation("BatchWorkspace", tip: "BatchWorkspaceDetail", icon: "pencil.line", selected: model.isWorkbench) { model.openWorkbench() }
            }
            section("Utilities") {
                navigation("TextTool", tip: "TextToolDetail", icon: "text.cursor") { model.clipboard = ""; model.clipboardTruncated = false; model.sheet = "clipboard" }
                navigation("FolderWatch", tip: "WatchToolDetail", icon: "folder.badge.gearshape", pro: true) { model.sheet = "watch" }
                navigation("ExportShort", tip: "ExportToolDetail", icon: "square.and.arrow.up") { model.sheet = "tools" }
            }
            Divider().padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 2) {
                navigation("HistoryShort", tip: "HistoryDetail", icon: "clock.arrow.circlepath", identifier: "history") { model.sheet = "history"; Task { await model.reloadHistory() } }
                navigation("Settings", icon: "gearshape", identifier: "settings") { model.sheet = "settings" }
                navigation("HelpMenu", icon: "questionmark.circle", identifier: "help") { model.sheet = "help" }
            }
          }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.sidebar.ignoresSafeArea()).foregroundStyle(palette.text)
            .font(L10n.font(model.settings.language)).tint(palette.accent)
    }
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.t(title)).font(.caption).foregroundStyle(palette.secondary).padding(.horizontal, 8).padding(.bottom, 2).accessibilityAddTraits(.isHeader)
            content()
        }
    }
    /// One line per destination. Explanations live in the tooltip and on the screen itself.
    private func navigation(_ title: String, tip: String? = nil, icon: String, selected: Bool = false, pro: Bool = false, identifier: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 18).foregroundStyle(selected ? palette.accent : palette.secondary).accessibilityHidden(true)
                Text(model.t(title)).fontWeight(selected ? .semibold : .regular).lineLimit(1)
                if pro { ProBadge(palette: palette) }
                Spacer(minLength: 0)
            }.padding(.horizontal, 8).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? palette.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
        }.buttonStyle(.plain).help(model.t(tip ?? title)).accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier(identifier ?? title)
            .disabled(model.busy || model.plan != nil || model.result != nil)
    }
}

private struct SidebarBackdrop: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    var body: some View { Palette(model.settings.theme, systemDark: scheme == .dark).sidebar.ignoresSafeArea() }
}
