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
    @State private var workbenchRulesExpanded = true
    @State private var rulesFirst: Bool
    private let startAdvanced: Bool
    init(model: AppModel, rulesFirst: Bool = false, startAdvanced: Bool = false) {
        self.model = model; self.startAdvanced = startAdvanced
        _rulesFirst = State(initialValue: rulesFirst)
    }
    var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    private var awaitingInput: Bool { model.roots.isEmpty && model.entries.isEmpty }
    private var conflicts: Int { model.counts["ConflictCaption"] ?? 0 }
    private var filtering: Bool { !model.query.isEmpty || model.filter != "All" || model.settings.hideNormal }
    var body: some View {
        GeometryReader { proxy in
            let width = max(280, proxy.size.width)
            ScrollView(.horizontal) {
                Group {
                    if model.isWorkbench { workbench(width: width, height: proxy.size.height) }
                    else { quick(width: width, height: proxy.size.height) }
                }.frame(width: width).frame(maxHeight: .infinity)
            }
            .background(palette.canvas).foregroundStyle(contrast == .increased ? Color.primary : palette.text)
            .font(L10n.font(model.settings.language)).tint(palette.accent)
            .overlay { if model.dragActive { RoundedRectangle(cornerRadius: 12).stroke(palette.accent, lineWidth: 3).padding(4).allowsHitTesting(false) } }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let message = model.message {
                    ScrollView {
                        HStack(alignment: .top) {
                            let notice = ["Exported", "RecipeSaved", "QueuedInputs", "CancelBeforeClose"].contains(message)
                            Image(systemName: notice ? "info.circle" : "exclamationmark.circle").foregroundStyle(notice ? palette.secondary : palette.warning).accessibilityHidden(true)
                            Text(model.t(message)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 4)
                            Button { model.message = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help(model.t("Close")).accessibilityLabel(model.t("Close"))
                        }.padding(12)
                    }.frame(maxHeight: min(90, proxy.size.height * 0.3)).background(palette.surface)
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
        .onChange(of: model.searchFocus) { _, value in if value { searchFocused = true; model.searchFocus = false } }
    }

    // MARK: Screens

    @ViewBuilder private func quick(width: CGFloat, height: CGFloat) -> some View {
        if awaitingInput { inputState(title: "EmptyTitle", icon: "character.cursor.ibeam", height: height) }
        else if WindowLayout.wide(width: width) && height >= 420 { resultColumn.padding(16) }
        else { compactResults(height: height) { EmptyView() } }
    }
    @ViewBuilder private func workbench(width: CGFloat, height: CGFloat) -> some View {
        if awaitingInput && !rulesFirst { inputState(title: "BatchEmptyTitle", icon: "pencil.line", height: height) }
        else if WindowLayout.wide(width: width) && height >= 520 {
            HSplitView {
                RuleEditor(model: model, palette: palette, startAdvanced: startAdvanced).padding(16).frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
                resultColumn.padding(16).frame(minWidth: 440)
            }
        } else {
            compactResults(height: height) {
                DisclosureGroup(model.t("Rules"), isExpanded: $workbenchRulesExpanded) {
                    RuleEditor(model: model, palette: palette, startAdvanced: startAdvanced, embedded: true).padding(.top, 8)
                }
            }
        }
    }
    private var resultColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            overview
            unappliedNotice
            filterRow
            results
            footer
        }
    }
    @ViewBuilder private func compactResults<Rules: View>(height: CGFloat, @ViewBuilder rules: () -> Rules) -> some View {
        let sections = LazyVStack(alignment: .leading, spacing: 14) {
            overview
            rules()
            unappliedNotice
            filterRow
            if model.busy { activity }
            if model.visible.isEmpty { noResults.frame(minHeight: 150) }
            else { ForEach(model.visible) { entry in CompactResultRow(model: model, entry: entry, palette: palette).id(entry.id) } }
        }.padding(12)
        if height < 300 {
            ScrollView { sections; footer.padding(12) }
        } else {
            ScrollView { sections }.safeAreaInset(edge: .bottom, spacing: 0) { footer.padding(12).background(palette.canvas) }
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
                if model.settings.rememberRecentFolders, !model.settings.recentFolders.isEmpty {
                    Menu(model.t("RecentFolders")) { recentFolderItems }.menuStyle(.borderlessButton).fixedSize()
                }
                if model.isWorkbench { Button(model.t("RulesFirst")) { rulesFirst = true }.buttonStyle(.link) }
            }
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 28).padding(.vertical, 32).frame(maxWidth: 480)
            .background(RoundedRectangle(cornerRadius: 14).strokeBorder(palette.border, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .padding(16).frame(maxWidth: .infinity, minHeight: max(220, height))
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
        ForEach(model.settings.recentFolders, id: \.self) { path in
            Button(URL(fileURLWithPath: path).lastPathComponent) { model.add([URL(fileURLWithPath: path)]) }.help(path)
        }
    }

    // MARK: Result state

    /// One row: what was added (expandable), the summary that doubles as filters, and how much is shown.
    private var overview: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { if model.sidebarCollapsed { locationsToggle }; summaryItems; conflictAction; Spacer(minLength: 8); scopeCaption }
                VStack(alignment: .leading, spacing: 8) { if model.sidebarCollapsed { locationsToggle }; HStack(spacing: 8) { summaryItems; conflictAction }; scopeCaption }
            }
            // The sidebar tree owns the added locations; this fallback exists only while the sidebar is hidden.
            if model.sidebarCollapsed, locationsExpanded { locations }
            if let folder = model.folderFilter {
                HStack(spacing: 6) {
                    Image(systemName: "folder").foregroundStyle(palette.secondary).accessibilityHidden(true)
                    Text(model.t("TreeFiltered", String(data: folder.leaf, encoding: .utf8) ?? folder.display)).font(.callout).lineLimit(1).truncationMode(.middle)
                    Button(model.t("TreeAll")) { model.folderFilter = nil }.buttonStyle(.link)
                }
            }
        }.disabled(model.plan != nil)
    }
    private var locationsToggle: some View {
        Button { locationsExpanded.toggle() } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right").font(.caption).rotationEffect(.degrees(locationsExpanded ? 90 : 0)).accessibilityHidden(true)
                Text(model.t("InputSummary", model.n(model.roots.count))).fontWeight(.medium)
            }.contentShape(Rectangle())
        }.buttonStyle(.plain).fixedSize().accessibilityAddTraits(locationsExpanded ? .isSelected : []).accessibilityIdentifier("locations").disabled(model.busy)
    }
    /// Appears only when there is a conflict to resolve.
    @ViewBuilder private var conflictAction: some View {
        if conflicts > 0 { Button(model.t("NumberConflicts")) { model.numberConflicts() }.buttonStyle(.borderless).fixedSize().disabled(model.busy) }
    }
    private var locations: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(model.roots, id: \.self) { root in
                        HStack {
                            Image(systemName: "folder").foregroundStyle(palette.secondary).accessibilityHidden(true)
                            Text(String(data: root.leaf, encoding: .utf8) ?? root.display).lineLimit(1).truncationMode(.middle).frame(maxWidth: .infinity, alignment: .leading).help(root.display)
                            Button { model.remove(root) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).help(model.t("RemoveInput")).accessibilityLabel(model.t("RemoveInput"))
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
    @ViewBuilder private var unappliedNotice: some View {
        if model.hasUnappliedRules {
            Label(model.t("UnappliedRules"), systemImage: "arrow.triangle.2.circlepath").font(.callout).foregroundStyle(palette.warning)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    /// Flat summary: each item is also the filter for that group.
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
    private var scopeCaption: some View {
        let shown = model.t("ShownCount", model.n(model.visible.count), model.n(model.entries.count))
        return Text(model.hiddenSelected > 0 ? shown + " · " + model.t("HiddenSelected", model.n(model.hiddenSelected)) : shown)
            .font(.caption).foregroundStyle(model.hiddenSelected > 0 ? palette.warning : palette.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private var filterRow: some View {
        HStack(spacing: 8) {
            TextField(model.t("Search"), text: $model.query).textFieldStyle(.roundedBorder).focused($searchFocused).accessibilityIdentifier("search")
            Menu {
                Picker(model.t("Filter"), selection: $model.filter) {
                    ForEach(["All", "NeedsNormalization", "Normal", "Conflict", "Errors", "SelectedOnly"], id: \.self) {
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
    }
    private var results: some View {
        VStack(spacing: 0) {
            if model.busy { activity; Divider() }
            if model.visible.isEmpty { noResults } else { ResultTable(model: model, palette: palette) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.border, lineWidth: 1))
    }
    private var activity: some View {
        ScrollView(.horizontal) {
            HStack {
                if model.mutating { ProgressView(value: Double(model.completed), total: Double(max(1, model.total))).frame(width: 100) } else { ProgressView().controlSize(.small) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.cancelled ? model.t("ActivityCancel") : model.phaseLabel)
                    if model.mutating { Text(model.t("ActivityCount", model.n(model.completed), model.n(model.total), model.n(model.total == 0 ? 0 : model.completed * 100 / model.total))).font(.caption); Text(model.current).font(.caption).lineLimit(1).truncationMode(.middle).help(model.current) }
                    else if model.phase == "ActivityScan" { Text(model.t("Scanning", model.n(model.scanned))).font(.caption) }
                }
                Spacer()
                TimelineView(.periodic(from: model.started, by: 1)) { context in Text(model.t("Elapsed", model.n(Int(context.date.timeIntervalSince(model.started))))).font(.caption) }
                Button(model.t("Cancel")) { model.cancel() }.disabled(model.cancelled || model.phase == "ActivityPreview")
            }.padding(12)
        }.frame(height: model.mutating ? 90 : 64)
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
        } else { Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity) }
    }
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { selectionMenu; Spacer(); primaryAction }
            VStack(alignment: .leading, spacing: 10) { selectionMenu; HStack { Spacer(); primaryAction } }
        }.disabled(model.busy)
    }
    private var selectionMenu: some View {
        Menu(model.t("SelectMenu")) {
            Button(model.t("SelectVisible")) { model.select("visible") }
            Button(model.t("ClearVisible")) { model.select("clearVisible") }
            Divider()
            Button(model.t("SelectAllSafe")) { model.select("all") }
            Button(model.t("ClearAll")) { model.select("none") }
            Button(model.t("InvertVisible")) { model.select("invert") }
        }.menuStyle(.borderlessButton).fixedSize().accessibilityIdentifier("selectMenu")
    }
    /// The single primary action of the screen.
    private var primaryAction: some View {
        Button { model.prepare() } label: { Text(model.t(model.isWorkbench ? "RenameCount" : "CombineCount", model.n(model.selected.count))).fontWeight(.semibold).padding(.horizontal, 12).padding(.vertical, 6) }
            .buttonStyle(PrimaryButtonStyle(palette: palette)).disabled(model.selected.isEmpty || model.busy || !model.ready || model.hasUnappliedRules).accessibilityIdentifier("rename")
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
