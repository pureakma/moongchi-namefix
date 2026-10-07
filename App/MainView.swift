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
                .help(model.t("StaleHelp")).accessibilityLabel(model.t("PreviewStale")).accessibilityHint(model.t("StaleHelp")).accessibilityIdentifier("updatePreview")
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
    private static let informational: Set<String> = Set(["Exported", "RecipeSaved", "QueuedInputs", "CancelBeforeClose"]).union(VolumeSupport.locationReasons)
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
                        Text(model.t(message)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).padding(14).frame(width: 340, alignment: .leading)
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

struct ResultTable: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var body: some View {
        Table(model.visible, selection: $model.focused) {
            TableColumn("") { entry in
                Toggle(model.t("SelectedCaption"), isOn: Binding(get: { model.selected.contains(entry.id) }, set: { _ in model.toggle(entry) })).labelsHidden().disabled(!entry.status.fixable || model.busy).accessibilityLabel(model.t("SelectedCaption") + " " + entry.name)
            }.width(28)
            TableColumn(model.t("Name")) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: entry.isDirectory ? "folder" : "doc").foregroundStyle(palette.secondary).frame(width: 16).help(model.t(entry.isDirectory ? "Directory" : "File")).accessibilityLabel(model.t(entry.isDirectory ? "Directory" : "File"))
                    NameCompositionCell(entry: entry, preview: false, compact: model.settings.compactRows, palette: palette, language: model.settings.language)
                }
            }.width(min: 110, ideal: CGFloat(model.settings.nameColumnRatio * 3), max: .infinity)
            TableColumn(model.t("Preview")) { entry in NameCompositionCell(entry: entry, preview: true, compact: model.settings.compactRows, palette: palette, language: model.settings.language) }.width(min: 110, ideal: CGFloat((100 - model.settings.nameColumnRatio) * 3), max: .infinity)
            TableColumn(model.t("Status")) { entry in Text(model.t(CharacterPresentation.statusKey(entry.status, name: entry.name, reason: entry.reason))).font(.caption).foregroundStyle(entry.status.isError || entry.status == .conflict ? palette.warning : palette.secondary).help(model.t(entry.reason)) }.width(min: 90, ideal: 125, max: 170)
        }
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        // Columns share the available width; a horizontal scroller would only add a bar under the list.
        .background(NoHorizontalScroller())
        .background(palette.surface)
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button(model.t("InspectShort")) { model.focused = ids.first; model.sheet = "inspector" }
            Button(model.t("CopyPath")) { if let e = model.entries.first(where: { $0.id == ids.first }) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(e.path.display, forType: .string) } }
        } primaryAction: { ids in model.focused = ids.first; model.sheet = "inspector" }
        .onKeyPress(keys: [.space]) { _ in
            guard let entry = model.visible.first(where: { $0.id == model.focused }), entry.status.fixable, !model.busy else { return .ignored }
            model.toggle(entry); return .handled
        }
        .onKeyPress(keys: ["a"]) { event in if event.modifiers.contains(.command) { model.select("visible"); return .handled }; return .ignored }
        .onKeyPress(keys: ["z"]) { event in if event.modifiers.contains(.command), let h = model.history.first(where: { $0.mode == "rename" && $0.succeeded > 0 }) { model.prepare(mode: "undo", historyID: h.id); return .handled }; return .ignored }
        .accessibilityIdentifier("resultsTable")
    }
}

/// Table keeps its AppKit horizontal scroller whatever `scrollIndicators` says, and with
/// "always show scroll bars" that is a permanent bar under the list. This turns it off.
private struct NoHorizontalScroller: NSViewRepresentable {
    final class Probe: NSView {
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); DispatchQueue.main.async { [weak self] in self?.apply() } }
        override func layout() { super.layout(); apply() }
        func apply() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = Self.listScroll(in: view) {
                    if scroll.hasHorizontalScroller { scroll.hasHorizontalScroller = false; scroll.horizontalScrollElasticity = .none }
                    return
                }
                ancestor = view.superview
            }
        }
        private static func listScroll(in view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, scroll.documentView is NSTableView { return scroll }
            for child in view.subviews { if let found = listScroll(in: child) { return found } }
            return nil
        }
    }
    func makeNSView(context: Context) -> Probe { Probe() }
    func updateNSView(_ view: Probe, context: Context) { view.apply() }
}
