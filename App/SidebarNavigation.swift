import AppKit
import SwiftUI

@MainActor final class MainSidebarController: NSSplitViewController {
    let navigationItem: NSSplitViewItem
    init(model: AppModel) {
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
        let host = DropHostingView(rootView: MainView(model: model)); host.model = model; host.sizingOptions = []
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
          VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.t("FileTasks")).font(.caption).foregroundStyle(palette.secondary).padding(.horizontal, 8)
                navigation("RestoreNames", detail: "RestoreNamesDetail", icon: "character.cursor.ibeam", selected: !model.isWorkbench) { model.openQuickCleanup() }
                navigation("BatchWorkspace", detail: "BatchWorkspaceDetail", icon: "pencil.line", selected: model.isWorkbench) { model.openWorkbench() }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(model.t("Utilities")).font(.caption).foregroundStyle(palette.secondary).padding(.horizontal, 8)
                navigation("TextTool", detail: "TextToolDetail", icon: "text.cursor") { model.clipboard = ""; model.clipboardTruncated = false; model.sheet = "clipboard" }
                navigation("FolderWatch", detail: "WatchToolDetail", icon: "folder.badge.gearshape") { model.sheet = "watch" }
                navigation("ExportReport", detail: "ExportToolDetail", icon: "square.and.arrow.up") { model.sheet = "tools" }
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                navigation("HistoryShort", icon: "clock.arrow.circlepath") { model.sheet = "history"; Task { await model.reloadHistory() } }
                navigation("Settings", icon: "gearshape") { model.sheet = "settings" }
                navigation("HelpTitle", icon: "questionmark.circle") { model.sheet = "help" }
            }
          }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.sidebar.ignoresSafeArea()).foregroundStyle(palette.text)
            .font(L10n.font(model.settings.language)).tint(palette.accent)
    }
    private func navigation(_ title: String, detail: String? = nil, icon: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon).frame(width: 18).padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t(title)).fontWeight(selected ? .semibold : .regular)
                    if let detail { Text(model.t(detail)).font(.caption).foregroundStyle(palette.secondary) }
                }
                Spacer(minLength: 0)
            }.fixedSize(horizontal: false, vertical: true).padding(8).frame(maxWidth: .infinity, alignment: .leading)
                .background(selected ? palette.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7)).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
            .disabled(model.busy || model.plan != nil || model.result != nil)
    }
}

private struct SidebarBackdrop: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    var body: some View { Palette(model.settings.theme, systemDark: scheme == .dark).sidebar.ignoresSafeArea() }
}
