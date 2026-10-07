import SwiftUI
import AppKit
import NameFixCore
import NameFixRuntime

/// One screen, three states: an input-only empty state, a scan in progress, and results.
/// Result controls exist only once something has been added.
struct MainView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var searchFocused: Bool
    @State private var locationsExpanded = false
    @State private var rulesFirst: Bool
    init(model: AppModel, rulesFirst: Bool = false) {
        self.model = model
        _rulesFirst = State(initialValue: rulesFirst)
    }
    var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    private var awaitingInput: Bool { model.roots.isEmpty && model.entries.isEmpty }
    private var inputOnly: Bool { awaitingInput && !(model.isWorkbench && rulesFirst) }
    private var conflicts: Int { model.counts["ConflictCaption"] ?? 0 }
    private var filtering: Bool { !model.query.isEmpty || model.filter != "All" || model.settings.hideNormal }
    /// Where the panel meets the left side: a rounded turn beside the navigation, a straight
    /// divider beside the folder tree, nothing when the sidebar is hidden.
    private var panelEdge: ChromePanel.Leading { model.sidebarCollapsed ? .none : model.roots.isEmpty ? .rounded : .squared }
    var body: some View {
        GeometryReader { proxy in
            let width = max(280, proxy.size.width)
            ScrollView(.horizontal) {
                Group {
                    if model.isWorkbench { workbench(width: width, height: proxy.size.height) }
                    else { quick(width: width, height: proxy.size.height) }
                }.frame(width: width).frame(maxHeight: .infinity)
            }
            .scrollIndicators(.hidden, axes: .horizontal)
            // The panel starts below the title bar band; the band itself keeps the window chrome colour.
            .background { ChromePanel(palette: palette, leading: panelEdge) }
            .foregroundStyle(contrast == .increased ? Color.primary : palette.text)
            .font(L10n.font(model.settings.language)).tint(palette.accent)
            .overlay { if model.dragActive { RoundedRectangle(cornerRadius: Metrics.corner).stroke(palette.accent, lineWidth: 3).padding(4).allowsHitTesting(false) } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // The input-only screen has no footer; a notice or progress still needs a place there.
                if inputOnly, model.busy || model.message != nil {
                    StatusLine(model: model, palette: palette, showsCounts: false)
                        .padding(.horizontal, Metrics.page).padding(.bottom, Metrics.gap).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .sheet(isPresented: Binding(get: { model.plan != nil }, set: { if !$0 { model.cancelPreview() } })) {
                if let plan = model.plan { ConfirmationView(model: model, plan: plan, palette: palette, availableSize: proxy.size) }
            }
            .sheet(isPresented: Binding(get: { model.sheet != nil }, set: { if !$0 { model.sheet = nil; model.flushQueued() } })) {
                SheetRouter(model: model, availableSize: proxy.size)
            }
            .sheet(isPresented: Binding(get: { model.result != nil }, set: { if !$0 { model.dismissResult() } })) {
                if let result = model.result { resultView(result, available: proxy.size) }
            }
        }
        .background(palette.sidebar.ignoresSafeArea())
        .onChange(of: model.searchFocus) { _, value in if value { searchFocused = true; model.searchFocus = false } }
    }

    // MARK: Screens

    @ViewBuilder private func quick(width: CGFloat, height: CGFloat) -> some View {
        if inputOnly { inputState(title: "EmptyTitle", icon: "character.cursor.ibeam", height: height) }
        else if WindowLayout.wide(width: width) && height >= 420 { resultPane.padding(Metrics.page) }
        else { compactResults(height: height) { EmptyView() } }
    }
    /// Two panes that start on the same line: rules on the left, their preview on the right.
    @ViewBuilder private func workbench(width: CGFloat, height: CGFloat) -> some View {
        if inputOnly { inputState(title: "BatchEmptyTitle", icon: "pencil.line", height: height) }
        else if width >= 820 && height >= 480 {
            HStack(alignment: .top, spacing: 0) {
                RuleEditor(model: model, palette: palette).padding(Metrics.page).frame(width: min(360, width * 0.38))
                Rectangle().fill(palette.border).frame(width: 1).accessibilityHidden(true)
                resultPane.padding(Metrics.page)
            }
        } else {
            compactResults(height: height) { RuleEditor(model: model, palette: palette, embedded: true) }
        }
    }
    private var resultPane: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            controlRow
            overview
            results
            footer
        }
    }
    @ViewBuilder private func compactResults<Rules: View>(height: CGFloat, @ViewBuilder rules: () -> Rules) -> some View {
        let sections = LazyVStack(alignment: .leading, spacing: Metrics.gap) {
            rules()
            controlRow
            overview
            if model.visible.isEmpty { noResults.frame(minHeight: 150) }
            else { ForEach(model.visible) { entry in CompactResultRow(model: model, entry: entry, palette: palette).id(entry.id) } }
        }.padding(Metrics.gap)
        if height < 300 {
            ScrollView { sections; footer.padding(Metrics.gap) }
        } else {
            ScrollView { sections }.safeAreaInset(edge: .bottom, spacing: 0) { footer.padding(Metrics.gap).background(palette.canvas) }
        }
    }

    // MARK: Empty state — the only input surface until something is added

    private func inputState(title: String, icon: String, height: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(palette.accent).accessibilityHidden(true)
                Text(model.t(title)).font(L10n.font(model.settings.language, size: 20, weight: .semibold)).accessibilityAddTraits(.isHeader)
                Text(model.t("EmptyDrop"))
                Text(model.t("EmptySafety")).font(.callout).foregroundStyle(palette.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { chooseFiles; chooseFolders }
                    VStack(spacing: 8) { chooseFiles; chooseFolders }
                }.controlSize(.large).padding(.top, 8)
                recursiveToggle.padding(.top, 2)
                // The sidebar lists the favourites; while it is hidden they are offered here.
                if model.sidebarCollapsed, !model.favorites.isEmpty {
                    Menu(model.t("Favorites")) {
                        ForEach(model.favorites) { favorite in Button(URL(fileURLWithPath: favorite.path).lastPathComponent) { model.openFavorite(favorite) }.help(favorite.path) }
                    }.menuStyle(.borderlessButton).fixedSize()
                }
                if !model.recentShortcuts.isEmpty {
                    Menu(model.t("RecentFolders")) { recentFolderItems }.menuStyle(.borderlessButton).fixedSize()
                }
                if model.isWorkbench { Button(model.t("RulesFirst")) { rulesFirst = true }.buttonStyle(.link) }
            }
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28).padding(.vertical, 32).frame(maxWidth: 480)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .padding(Metrics.page).frame(maxWidth: .infinity, minHeight: max(220, height))
        }
        .disabled(model.busy || model.plan != nil).accessibilityIdentifier("emptyState")
    }
    private var chooseFiles: some View {
        Button { pick(folders: false) } label: { Label(model.t("ChooseFiles"), systemImage: "doc.badge.plus") }.accessibilityIdentifier("addFiles")
    }
    private var chooseFolders: some View {
        Button { pick(folders: true) } label: { Label(model.t("ChooseFolders"), systemImage: "folder.badge.plus") }.accessibilityIdentifier("addFolders")
    }
    private var recursiveToggle: some View {
        Toggle(model.t("Recursive"), isOn: Binding(get: { model.settings.recursive }, set: { value in model.changeSettings { $0.recursive = value } })).disabled(model.busy)
    }
    @ViewBuilder private var recentFolderItems: some View {
        ForEach(model.recentShortcuts, id: \.self) { path in
            Button(URL(fileURLWithPath: path).lastPathComponent) { model.openRecent(path) }.help(path)
        }
    }

    // MARK: Result state

    /// One line above the list: what needs attention (also the filters), then search and list menus.
    /// It starts on the same line as the rules pane's header and keeps its height in every state.
    private var controlRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.control) { chips; searchField; viewOptions; selectionMenu }
            // Tighter panes keep the single line by showing the two menus as icons.
            HStack(spacing: Metrics.control) { chips; searchField; viewOptions.labelStyle(.iconOnly).hoverTip(model.t("ViewOptions")); selectionMenu.labelStyle(.iconOnly).hoverTip(model.t("SelectMenu")) }
            VStack(alignment: .leading, spacing: Metrics.control) {
                HStack(spacing: Metrics.control) { chips; Spacer(minLength: 0) }
                HStack(spacing: Metrics.control) { searchField; viewOptions; selectionMenu }
            }
            VStack(alignment: .leading, spacing: Metrics.control) {
                chips
                searchField
                HStack(spacing: Metrics.gap) { viewOptions; selectionMenu }
            }
        }.frame(minHeight: Metrics.paneHeader).disabled(model.plan != nil)
    }
    @ViewBuilder private var chips: some View { staleChip; summaryItems; conflictAction }
    /// Rules changed since the list was computed. The chip says so and is the button that updates it.
    @ViewBuilder private var staleChip: some View {
        if model.hasUnappliedRules {
            Button { model.usePipeline(model.workbenchDraft) } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.caption).accessibilityHidden(true)
                    Text(model.t("PreviewStale")).fontWeight(.semibold)
                }.foregroundStyle(palette.warning).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 7).fill(palette.warning.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(palette.warning, lineWidth: 1))
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).fixedSize().disabled(model.busy || model.plan != nil)
                .hoverTip(model.t("StaleTip")).accessibilityLabel(model.t("PreviewStale")).accessibilityHint(model.t("StaleHelp")).accessibilityIdentifier("updatePreview")
        }
    }
    /// Stand-ins for the sidebar tree while it is hidden (narrow window): the added locations and,
    /// if a folder is still selected, what the list is narrowed to. With the tree in view they are not shown.
    @ViewBuilder private var overview: some View {
        if model.sidebarCollapsed {
            VStack(alignment: .leading, spacing: Metrics.control) {
                locationsToggle; if locationsExpanded { locations }
                if let folder = model.folderFilter {
                    HStack(spacing: 6) {
                        Image(systemName: "folder").foregroundStyle(palette.secondary).accessibilityHidden(true)
                        Text(model.t("TreeFiltered", String(data: folder.leaf, encoding: .utf8) ?? folder.display)).lineLimit(1).truncationMode(.middle)
                        Button(model.t("TreeAll")) { model.folderFilter = nil }.buttonStyle(.link)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).disabled(model.plan != nil)
        }
    }
    private var locationsToggle: some View {
        Button { locationsExpanded.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right").font(.caption).rotationEffect(.degrees(locationsExpanded ? 90 : 0)).accessibilityHidden(true)
                Text(model.t("InputSummary", model.n(model.roots.count)))
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).fixedSize().accessibilityAddTraits(locationsExpanded ? .isSelected : []).accessibilityIdentifier("locations").disabled(model.busy)
    }
    /// Appears only when there is a conflict to resolve.
    @ViewBuilder private var conflictAction: some View {
        if conflicts > 0 { Button(model.t("NumberConflicts")) { model.numberConflicts() }.buttonStyle(.borderless).fixedSize().disabled(model.busy) }
    }
    private var locations: some View {
        VStack(alignment: .leading, spacing: Metrics.control) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(model.roots, id: \.self) { root in
                        HStack {
                            Image(systemName: "folder").foregroundStyle(palette.secondary).accessibilityHidden(true)
                            Text(String(data: root.leaf, encoding: .utf8) ?? root.display).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading).help(root.display)
                            Button { model.remove(root) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).hoverTip(model.t("RemoveInput")).accessibilityLabel(model.t("RemoveInput"))
                        }.padding(.vertical, 3)
                    }
                }
            }.frame(maxHeight: 110)
            ViewThatFits(in: .horizontal) {
                HStack { recursiveToggle; Spacer(); resetInputs }
                VStack(alignment: .leading, spacing: 6) { recursiveToggle; resetInputs }
            }
        }.padding(10).background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
    }
    private var resetInputs: some View {
        Button(model.t("ResetInputs")) { model.remove(nil); locationsExpanded = false }.disabled(model.roots.isEmpty)
    }
    @ViewBuilder private var summaryItems: some View {
        summaryItem(model.isWorkbench ? "NeededBatch" : "NeededCaption", model.counts["NeededCaption"] ?? 0, "NeedsNormalization", palette.preview)
        if conflicts > 0 { summaryItem("ConflictCaption", conflicts, "Conflict", palette.warning) }
        summaryItem("SummarySelected", model.selected.count, "SelectedOnly", palette.text)
    }
    private func summaryItem(_ key: String, _ count: Int, _ filter: String, _ color: Color) -> some View {
        let active = model.filter == filter
        return Button { model.filter = active ? "All" : filter } label: {
            HStack(spacing: 5) {
                Text(model.t(key)).foregroundStyle(palette.secondary)
                Text(model.n(count)).fontWeight(.semibold).monospacedDigit().foregroundStyle(color)
            }.padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7).fill(active ? palette.accent.opacity(0.16) : palette.control))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(active ? palette.accent : palette.border, lineWidth: 1))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).fixedSize().accessibilityLabel(model.t(key) + " " + model.n(count)).accessibilityAddTraits(active ? .isSelected : [])
            // With nothing to show, narrowing the list would only empty it; a chip that is on can always be turned off.
            .disabled(count == 0 && !active)
            .hoverTip(model.t(active ? "SummaryFilterOn" : "SummaryFilterHelp"))
            .accessibilityHint(model.t(active ? "SummaryFilterOn" : "SummaryFilterHelp"))
    }
    private var searchField: some View {
        TextField(model.t("Search"), text: $model.query).textFieldStyle(.roundedBorder).focused($searchFocused).frame(minWidth: 120).accessibilityIdentifier("search")
    }
    private var viewOptions: some View {
        Menu {
            Picker(model.t("Filter"), selection: $model.filter) {
                ForEach(["All", "NeedsNormalization", "Normal", "Conflict", "Errors", "SelectedOnly", "WindowsNames"], id: \.self) {
                    Text(model.t($0 == "NeedsNormalization" ? (model.isWorkbench ? "NeededBatch" : "NeededCaption") : $0)).tag($0)
                }
            }.pickerStyle(.inline)
            Picker(model.t("Sort"), selection: $model.sort) { ForEach(["Name", "Status", "Path"], id: \.self) { Text(model.t($0)).tag($0) } }.pickerStyle(.inline)
            Divider()
            Toggle(model.t("HideNormal"), isOn: Binding(get: { model.settings.hideNormal }, set: { value in model.changeSettings { $0.hideNormal = value } }))
            Button(model.t("ResetFilters")) { model.query = ""; model.filter = "All"; model.changeSettings { $0.hideNormal = false } }.disabled(!filtering)
        } label: {
            Label(model.t("ViewOptions"), systemImage: filtering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }.menuStyle(.borderlessButton).fixedSize().accessibilityIdentifier("viewOptions")
    }
    /// Selection commands live beside the list controls, not in the footer.
    private var selectionMenu: some View {
        Menu {
            Button(model.t("SelectVisible")) { model.select("visible") }
            Button(model.t("ClearVisible")) { model.select("clearVisible") }
            Divider()
            Button(model.t("SelectAllSafe")) { model.select("all") }
            Button(model.t("ClearAll")) { model.select("none") }
            Button(model.t("InvertVisible")) { model.select("invert") }
        } label: { Label(model.t("SelectMenu"), systemImage: "checklist") }
            .menuStyle(.borderlessButton).fixedSize().disabled(model.busy).accessibilityIdentifier("selectMenu")
    }
    private var results: some View {
        // Progress and notices live on the footer line, so nothing here ever pushes the table down.
        Group { if model.visible.isEmpty { noResults } else { ResultTable(model: model, palette: palette) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border, lineWidth: 1))
    }
    /// Shown inside the result area only: nothing matched, or rules were opened before any file.
    @ViewBuilder private var noResults: some View {
        if !model.busy {
            VStack(spacing: 8) {
                if model.entries.isEmpty {
                    Text(model.t("NoFilesYet")).foregroundStyle(palette.secondary)
                    if model.roots.isEmpty { HStack(spacing: 10) { chooseFiles; chooseFolders }.padding(.top, 4) }
                } else {
                    Text(model.t("NoResultsTitle")).fontWeight(.medium)
                    Text(model.t("NoResultsDescription")).font(.callout).foregroundStyle(palette.secondary)
                }
            }.multilineTextAlignment(.center).padding(20).frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("noResults")
        } else {
            // Nothing to show yet: say what is happening where the list will appear.
            VStack(spacing: 8) { ProgressView().controlSize(.small); Text(model.phaseLabel).foregroundStyle(palette.secondary) }
                .frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityElement(children: .combine)
        }
    }
    /// Bottom line of the pane: status on the left, the one primary action on the right.
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.gap) { StatusLine(model: model, palette: palette); Spacer(minLength: Metrics.control); primaryAction.fixedSize() }
            VStack(alignment: .leading, spacing: Metrics.control) { StatusLine(model: model, palette: palette); HStack { Spacer(minLength: 0); primaryAction } }
        }
    }
    private var primaryAction: some View {
        Button { model.prepare() } label: { Text(model.t(model.isWorkbench ? "RenameCount" : "CombineCount", model.n(model.selected.count))).fontWeight(.semibold).padding(.horizontal, 12).padding(.vertical, 6) }
            .buttonStyle(PrimaryButtonStyle(palette: palette)).disabled(model.selected.isEmpty || model.busy || !model.ready || model.hasUnappliedRules)
            .help(model.hasUnappliedRules ? model.t("StaleHelp") : "").accessibilityHint(model.hasUnappliedRules ? model.t("StaleHelp") : "")
            .accessibilityIdentifier("rename")
    }
    private func pick(folders: Bool) { AppDelegate.shared?.pick(folders: folders) }
    func resultView(_ result: TransactionSummary, available: CGSize) -> some View {
        FlexibleSheet(preferred: CGSize(width: 550, height: 260), available: available) {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text(model.t(result.status == "Cancelled" ? "ResultCancelled" : result.status)).font(.title2)
            Text(model.t("ResultSummary", model.n(result.succeeded), model.n(max(0, result.total - result.succeeded - result.failed)), model.n(result.failed)))
            ViewThatFits(in: .horizontal) {
                HStack { resultActions(result); Spacer(); resultClose }
                VStack(alignment: .leading, spacing: 12) { resultActions(result); resultClose }
            }
        }.padding(24) }
        }.background(palette.dialog).foregroundStyle(palette.text).font(L10n.font(model.settings.language)).tint(palette.accent)
    }
}

extension MainView {
    @ViewBuilder fileprivate func resultActions(_ result: TransactionSummary) -> some View {
        Button(model.t("HistoryShort")) { model.result = nil; model.sheet = "history"; model.loadDetails(result.id) }
        if result.mode == "rename" { Button(model.t("UndoNow")) { model.result = nil; model.prepare(mode: "undo", historyID: result.id) }.disabled(model.busy || result.succeeded == 0) }
    }
    fileprivate var resultClose: some View {
        Button(model.t("Close")) { model.dismissResult() }.keyboardShortcut(.cancelAction)
    }
}

/// Item counts, what the app is doing now, and notices, on the same line as the primary action.
/// Progress and notices appear here instead of above the list, so they never move it.
struct StatusLine: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var showsCounts = true
    @State private var showsNotice = false
    private static let informational: Set<String> = Set(["Exported", "RecipeSaved", "QueuedInputs", "CancelBeforeClose", "FolderAccessNeeded", "ParentFolderNeeded", "UndoNeedsFolder", "FastRenameTip"]).union(VolumeSupport.locationReasons)
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Metrics.gap) { parts }
            VStack(alignment: .leading, spacing: 4) { parts }
        }.font(.callout).accessibilityElement(children: .contain).accessibilityIdentifier("statusLine")
    }
    @ViewBuilder private var parts: some View {
        if showsCounts { counts }
        activity
        notice
    }
    private var counts: some View {
        let shown = model.t("ShownCount", model.n(model.visible.count), model.n(model.entries.count))
        return Text(model.hiddenSelected > 0 ? shown + " · " + model.t("HiddenSelected", model.n(model.hiddenSelected)) : shown)
            .foregroundStyle(model.hiddenSelected > 0 ? palette.warning : palette.secondary).lineLimit(1)
    }
    @ViewBuilder private var notice: some View {
        if let message = model.message {
            let info = Self.informational.contains(message)
            HStack(spacing: 6) {
                Image(systemName: info ? "info.circle" : "exclamationmark.triangle.fill").foregroundStyle(info ? palette.secondary : palette.warning).accessibilityHidden(true)
                // A short form here; the whole text, selectable, on click.
                Button { showsNotice = true } label: { Text(model.notice(message)).lineLimit(1).truncationMode(.tail).contentShape(Rectangle()) }
                    .buttonStyle(.plain).help(model.t(message)).accessibilityLabel(model.t(message))
                    .popover(isPresented: $showsNotice, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(model.t(message)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            if message == "FolderAccessNeeded" { Button(model.t("ChooseFolderToAllow")) { showsNotice = false; model.requestFolderForLooseItems() } }
                            if message == "ParentFolderNeeded" { Button(model.t("ChooseParentFolder")) { showsNotice = false; model.requestParentFolder() } }
                        }.padding(14).frame(width: 340, alignment: .leading)
                    }
                // What to do about it is one click away, not behind the text.
                if message == "FolderAccessNeeded" || message == "WrongFolderChosen" && model.entries.contains(where: { $0.reason == "FolderAccessNeeded" }) {
                    Button(model.t("ChooseFolderToAllow")) { model.requestFolderForLooseItems() }.controlSize(.small).fixedSize().disabled(model.busy).accessibilityIdentifier("chooseFolder")
                } else if message == "ParentFolderNeeded" || message == "WrongFolderChosen" && model.entries.contains(where: { $0.reason == "ParentFolderNeeded" }) {
                    Button(model.t("ChooseParentFolder")) { model.requestParentFolder() }.controlSize(.small).fixedSize().disabled(model.busy).accessibilityIdentifier("chooseParentFolder")
                }
                Button { model.message = nil } label: { Image(systemName: "xmark").font(.caption) }.buttonStyle(.plain).foregroundStyle(palette.secondary)
                    .hoverTip(model.t("Close"), below: false).accessibilityLabel(model.t("Close"))
            }
        }
    }
    @ViewBuilder private var activity: some View {
        if model.busy {
            HStack(spacing: Metrics.control) {
                if model.mutating { ProgressView(value: Double(model.completed), total: Double(max(1, model.total))).frame(width: 90).help(model.current) }
                else { ProgressView().controlSize(.small) }
                Text(activityText).lineLimit(1).foregroundStyle(palette.text)
                TimelineView(.periodic(from: model.started, by: 1)) { context in
                    Text(model.t("Elapsed", model.n(Int(context.date.timeIntervalSince(model.started))))).foregroundStyle(palette.secondary).monospacedDigit().lineLimit(1)
                }
                Button(model.t("Cancel")) { model.cancel() }.controlSize(.small).disabled(model.cancelled || model.phase == "ActivityPreview")
            }.accessibilityIdentifier("activity")
        }
    }
    private var activityText: String {
        if model.cancelled { return model.t("ActivityCancel") }
        if model.mutating { return model.phaseLabel + " · " + model.t("ActivityCount", model.n(model.completed), model.n(model.total), model.n(model.total == 0 ? 0 : model.completed * 100 / model.total)) }
        return model.phase == "ActivityScan" ? model.t("Scanning", model.n(model.scanned)) : model.phaseLabel
    }
}

/// The result list. An AppKit table with cells that draw themselves: a row costs a few
/// drawing calls, so a long list scrolls without building a view tree for every row.
struct ResultTable: NSViewRepresentable {
    @ObservedObject var model: AppModel
    let palette: Palette
    func makeCoordinator() -> ResultList { ResultList(model: model) }
    // The scroll view sits in a plain container and takes the size it is offered, so nothing the
    // table does while scrolling asks SwiftUI to lay the window out again.
    func makeNSView(context: Context) -> NSView {
        let box = NSView(), scroll = context.coordinator.build(palette)
        scroll.frame = box.bounds; scroll.autoresizingMask = [.width, .height]; box.addSubview(scroll)
        return box
    }
    func updateNSView(_ view: NSView, context: Context) { context.coordinator.update(palette) }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSView, context: Context) -> CGSize? { proposal.replacingUnspecifiedDimensions(by: CGSize(width: 600, height: 400)) }
}

@MainActor final class ResultList: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    /// Colours and fonts of one theme, resolved once for all cells.
    struct Look {
        let text, secondary, preview, warning, control, border: NSColor
        let compact: Bool
        let body = NSFont.systemFont(ofSize: NSFont.systemFontSize), caption = NSFont.systemFont(ofSize: 10), chip = NSFont.systemFont(ofSize: 12, weight: .medium)
        init(_ palette: Palette, compact: Bool) {
            text = NSColor(palette.text); secondary = NSColor(palette.secondary); preview = NSColor(palette.preview); warning = NSColor(palette.warning)
            control = NSColor(palette.control); border = NSColor(palette.border); self.compact = compact
        }
        var padding: CGFloat { compact ? 3 : 7 }
    }
    private let model: AppModel
    private let table = KeyTable()
    private var rows: [FileEntry] = []
    private var look = Look(Palette("light", systemDark: false), compact: false)
    private var state: [String] = []
    private var revision: UInt64 = .max, selected: Set<UUID> = [], busy = false, ratio = -1.0, syncing = false
    init(model: AppModel) { self.model = model }

    func build(_ palette: Palette) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = false; scroll.horizontalScrollElasticity = .none; scroll.autohidesScrollers = true
        for (id, width, low, high) in [("check", 28, 28, 28), ("name", 300, 110, 10_000), ("preview", 300, 110, 10_000), ("status", 125, 90, 170)] as [(String, CGFloat, CGFloat, CGFloat)] {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            column.width = width; column.minWidth = low; column.maxWidth = high
            column.resizingMask = id == "check" ? [] : id == "status" ? .userResizingMask : [.autoresizingMask, .userResizingMask]
            table.addTableColumn(column)
        }
        table.style = .inset; table.backgroundColor = .clear; table.usesAlternatingRowBackgroundColors = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle; table.allowsColumnReordering = false
        table.allowsMultipleSelection = false; table.allowsEmptySelection = true; table.gridStyleMask = .solidHorizontalGridLineMask
        table.dataSource = self; table.delegate = self; table.target = self; table.doubleAction = #selector(inspect)
        table.setAccessibilityIdentifier("resultsTable")
        let menu = NSMenu(); menu.delegate = self; table.menu = menu
        table.space = { [weak self] in self?.toggleFocused() ?? false }
        table.all = { [weak self] in self?.model.select("visible") }
        table.undo = { [weak self] in
            guard let model = self?.model, let record = model.history.first(where: { $0.mode == "rename" && $0.succeeded > 0 }) else { return false }
            model.prepare(mode: "undo", historyID: record.id); return true
        }
        scroll.documentView = table
        update(palette)
        return scroll
    }

    func update(_ palette: Palette) {
        let settings = model.settings
        let now = [settings.language, palette.dark ? "d" : "l", palette.olive ? "o" : "", settings.compactRows ? "c" : ""]
        let restyled = now != state
        if restyled {
            state = now; look = Look(palette, compact: settings.compactRows); table.gridColor = look.border.withAlphaComponent(0.6)
            for (column, key) in zip(table.tableColumns, ["", "Name", "Preview", "Status"]) { column.title = key.isEmpty ? "" : model.t(key) }
            table.headerView?.needsDisplay = true
        }
        if model.visibleRevision != revision || restyled {
            revision = model.visibleRevision; rows = model.visible; selected = model.selected; busy = model.busy
            syncing = true; table.reloadData(); syncing = false
        } else if selected != model.selected || busy != model.busy {
            selected = model.selected; busy = model.busy
            table.enumerateAvailableRowViews { view, row in
                guard row < self.rows.count, let cell = view.view(atColumn: 0) as? CheckCell else { return }
                self.fill(cell, self.rows[row])
            }
        }
        if settings.nameColumnRatio != ratio, table.enclosingScrollView.map({ $0.contentSize.width > 200 }) == true { ratio = settings.nameColumnRatio; share() }
        else if ratio < 0 { DispatchQueue.main.async { [weak self] in guard let self, self.ratio < 0, let scroll = self.table.enclosingScrollView, scroll.contentSize.width > 200 else { return }; self.ratio = self.model.settings.nameColumnRatio; self.share() } }
        // The focused row follows the model (the inspector and the keyboard both read it).
        let current = table.selectedRow >= 0 && table.selectedRow < rows.count ? rows[table.selectedRow].id : nil
        if current != model.focused {
            syncing = true
            if let id = model.focused, let index = rows.firstIndex(where: { $0.id == id }) { table.selectRowIndexes([index], byExtendingSelection: false) } else { table.deselectAll(nil) }
            syncing = false
        }
    }
    /// Name and New name share the width left by the other two columns, by the ratio in Settings.
    private func share() {
        guard let scroll = table.enclosingScrollView, table.tableColumns.count == 4 else { return }
        let free = scroll.contentSize.width - table.tableColumns[0].width - table.tableColumns[3].width - table.intercellSpacing.width * 4 - 32
        guard free > 220 else { return }
        let name = max(110, min(free - 110, free * ratio / 100))
        table.tableColumns[1].width = name; table.tableColumns[2].width = free - name
    }

    private func changes(_ entry: FileEntry) -> Bool { entry.path.leaf != entry.proposed && entry.name == entry.preview }
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let entry = rows[row]
        return 20 + look.padding * 2 + (changes(entry) ? 24 : 0) + (entry.groupID != nil ? 17 : 0)
    }
    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let id = column?.identifier, row < rows.count else { return nil }
        let entry = rows[row]
        if id.rawValue == "check" {
            let cell = tableView.makeView(withIdentifier: id, owner: nil) as? CheckCell ?? CheckCell(id) { [weak self] cell in
                guard let self else { return }
                let row = self.table.row(for: cell)
                if row >= 0, row < self.rows.count { self.model.toggle(self.rows[row]) }
            }
            fill(cell, entry); return cell
        }
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NameCell ?? NameCell(id)
        let language = model.settings.language
        switch id.rawValue {
        case "status":
            cell.show(.init(text: model.t(CharacterPresentation.statusKey(entry.status, name: entry.name, reason: entry.reason)), color: entry.status.isError || entry.status == .conflict ? look.warning : look.secondary, small: true, tip: model.t(entry.reason)), look)
        default:
            let preview = id.rawValue == "preview", unit = changes(entry) ? CharacterPresentation.comparison(original: entry.name, proposed: entry.preview) : []
            let tokens = unit.first.map { preview ? $0.after : $0.before } ?? []
            cell.show(.init(text: preview ? entry.preview : entry.name, color: preview ? (entry.status.fixable ? look.preview : look.secondary) : look.text,
                            icon: preview ? nil : (entry.isDirectory ? "folder" : "doc"), iconLabel: preview ? "" : model.t(entry.isDirectory ? "Directory" : "File"),
                            pair: entry.groupID != nil && !preview ? L10n.text("PairMember", language: language) : nil,
                            chips: tokens, more: max(0, unit.count - 1), tip: preview ? entry.preview : entry.path.display,
                            chipTip: L10n.text("CompositionLegend", language: language), moreTip: unit.count > 1 ? L10n.text("MoreCharacterChanges", language: language, [String(unit.count - 1)]) : ""), look)
        }
        return cell
    }
    private func fill(_ cell: CheckCell, _ entry: FileEntry) {
        cell.box.state = selected.contains(entry.id) ? .on : .off
        cell.box.isEnabled = entry.status.fixable && !busy
        cell.box.setAccessibilityLabel(model.t("SelectedCaption") + " " + entry.name)
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !syncing else { return }
        let id = table.selectedRow >= 0 && table.selectedRow < rows.count ? rows[table.selectedRow].id : nil
        if model.focused != id { model.focused = id }
    }
    private func toggleFocused() -> Bool {
        guard table.selectedRow >= 0, table.selectedRow < rows.count, rows[table.selectedRow].status.fixable, !model.busy else { return false }
        model.toggle(rows[table.selectedRow]); return true
    }
    @objc private func inspect() {
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard row >= 0, row < rows.count else { return }
        model.focused = rows[row].id; model.sheet = "inspector"
    }
    @objc private func copyPath() {
        guard table.clickedRow >= 0, table.clickedRow < rows.count else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(rows[table.clickedRow].path.display, forType: .string)
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard table.clickedRow >= 0 else { return }
        menu.addItem(withTitle: model.t("InspectShort"), action: #selector(inspect), keyEquivalent: "").target = self
        menu.addItem(withTitle: model.t("CopyPath"), action: #selector(copyPath), keyEquivalent: "").target = self
    }
}

/// The table's own keys: Space ticks the focused row, ⌘A selects what is listed, ⌘Z offers the last rename for undo.
final class KeyTable: NSTableView {
    var space: () -> Bool = { false }, undo: () -> Bool = { false }, all: () -> Void = {}
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " ", event.modifierFlags.intersection([.command, .option, .control]).isEmpty, space() { return }
        super.keyDown(with: event)
    }
    override func selectAll(_ sender: Any?) { all() }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self, event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command, event.charactersIgnoringModifiers == "z", undo() { return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class CheckCell: NSTableCellView {
    let box = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let toggled: (CheckCell) -> Void
    init(_ id: NSUserInterfaceItemIdentifier, toggled: @escaping (CheckCell) -> Void) {
        self.toggled = toggled; super.init(frame: .zero); identifier = id
        box.target = self; box.action = #selector(pressed); box.refusesFirstResponder = true; box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)
        NSLayoutConstraint.activate([box.centerXAnchor.constraint(equalTo: centerXAnchor), box.centerYAnchor.constraint(equalTo: centerYAnchor)])
    }
    required init?(coder: NSCoder) { nil }
    // The model decides; the box shows what the model says after the list is refreshed.
    @objc private func pressed() { box.state = box.state == .on ? .off : .on; toggled(self) }
}

/// A name with the pieces of its first changed character under it, or a status word. Drawn directly.
final class NameCell: NSTableCellView, NSViewToolTipOwner {
    struct Content {
        var text = "", color = NSColor.labelColor, small = false
        var icon: String? = nil, iconLabel = "", pair: String? = nil
        var chips: [CharacterToken] = [], more = 0
        var tip = "", chipTip = "", moreTip = ""
    }
    private var content = Content()
    private var look: ResultList.Look?
    private var chipArea = NSRect.zero, moreArea = NSRect.zero, chipRects: [NSRect] = []
    init(_ id: NSUserInterfaceItemIdentifier) { super.init(frame: .zero); identifier = id; setAccessibilityElement(true); setAccessibilityRole(.staticText) }
    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var backgroundStyle: NSView.BackgroundStyle { didSet { needsDisplay = true } }
    func show(_ content: Content, _ look: ResultList.Look) {
        self.content = content; self.look = look; needsDisplay = true
        let shown = content.chips.prefix(3).map { $0.glyph + " " + $0.code }.joined(separator: ", ")
        setAccessibilityLabel(content.iconLabel.isEmpty ? content.text : content.iconLabel + ", " + content.text)
        setAccessibilityValue(shown.isEmpty ? nil : shown); setAccessibilityHelp(content.small ? content.tip : nil)
        removeAllToolTips(); addToolTip(NSRect(x: 0, y: 0, width: 10_000, height: 10_000), owner: self, userData: nil)
    }
    func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        if let index = chipRects.firstIndex(where: { $0.contains(point) }), index < content.chips.count { return content.chips[index].code }
        if moreArea.contains(point) { return content.moreTip }
        if chipArea.contains(point) { return content.chipTip }
        return content.tip
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let look else { return }
        let lit = backgroundStyle == .emphasized
        let color = lit ? NSColor.alternateSelectedControlTextColor : content.color, quiet = lit ? NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.8) : look.secondary
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byTruncatingTail
        chipRects = []; chipArea = .zero; moreArea = .zero
        if content.small {
            let text = NSAttributedString(string: content.text, attributes: [.font: look.caption, .foregroundColor: color, .paragraphStyle: style])
            let height = ceil(text.size().height)
            text.draw(with: NSRect(x: 0, y: floor((bounds.height - height) / 2), width: bounds.width, height: height), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            return
        }
        var y = look.padding + 2, x: CGFloat = 0
        let line = ceil(look.body.ascender - look.body.descender + look.body.leading)
        if let icon = content.icon, let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: 13, weight: .regular).applying(.init(paletteColors: [quiet]))) {
            let size = image.size
            image.draw(in: NSRect(x: (16 - size.width) / 2, y: y + (line - size.height) / 2, width: size.width, height: size.height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            x = 22
        }
        NSAttributedString(string: content.text, attributes: [.font: look.body, .foregroundColor: color, .paragraphStyle: style])
            .draw(with: NSRect(x: x, y: y, width: max(0, bounds.width - x), height: line), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        y += line + 4
        if let pair = content.pair {
            NSAttributedString(string: "🔗 " + pair, attributes: [.font: look.caption, .foregroundColor: quiet, .paragraphStyle: style])
                .draw(with: NSRect(x: x, y: y, width: max(0, bounds.width - x), height: 13), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            y += 17
        }
        guard !content.chips.isEmpty else { return }
        var left = x
        for token in content.chips.prefix(3) {
            let glyph = NSAttributedString(string: token.glyph, attributes: [.font: look.chip, .foregroundColor: lit ? NSColor.alternateSelectedControlTextColor : content.color])
            let size = glyph.size(), box = NSRect(x: left, y: y, width: ceil(max(size.width, 8)) + 8, height: 20)
            let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5), xRadius: 4, yRadius: 4)
            (lit ? NSColor.white.withAlphaComponent(0.18) : look.control).setFill(); path.fill()
            (lit ? NSColor.white.withAlphaComponent(0.5) : look.border).setStroke(); path.lineWidth = 1; path.stroke()
            glyph.draw(at: NSPoint(x: box.minX + (box.width - size.width) / 2, y: box.minY + (box.height - size.height) / 2))
            chipRects.append(box); left = box.maxX + 3
        }
        if content.chips.count > 3 { let dots = NSAttributedString(string: "…", attributes: [.font: look.body, .foregroundColor: color]); dots.draw(at: NSPoint(x: left, y: y + 1)); left += dots.size().width + 3 }
        chipArea = NSRect(x: x, y: y, width: left - x, height: 20)
        if content.more > 0 {
            let more = NSAttributedString(string: "+\(content.more)", attributes: [.font: look.caption, .foregroundColor: quiet])
            more.draw(at: NSPoint(x: left + 1, y: y + (20 - more.size().height) / 2))
            moreArea = NSRect(x: left, y: y, width: more.size().width + 4, height: 20)
        }
    }
}
