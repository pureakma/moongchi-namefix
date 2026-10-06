import SwiftUI
import AppKit
import NameFixCore
import NameFixRuntime

struct MainView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @FocusState private var searchFocused: Bool
    @State private var workbenchRulesExpanded = true
    var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    var body: some View {
        GeometryReader { proxy in
            let width = max(280, proxy.size.width)
            ScrollView(.horizontal) {
                Group {
                    if model.isWorkbench {
                        workbenchContent(width: width, height: proxy.size.height)
                    } else if WindowLayout.wide(width: width) {
                        if proxy.size.height >= 620 { wideContent }
                        else { ScrollView { wideContent.frame(height: 740) } }
                    } else {
                        compactContent(width: width, height: proxy.size.height)
                    }
                }.frame(width: width).frame(maxHeight: .infinity)
            }
            .background(palette.canvas).foregroundStyle(contrast == .increased ? Color.primary : palette.text)
            .font(L10n.font(model.settings.language)).tint(palette.accent)
            .overlay { if model.dragActive { RoundedRectangle(cornerRadius: 18).stroke(palette.accent, lineWidth: 3).padding(4).allowsHitTesting(false) } }
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
    @ViewBuilder private func workbenchContent(width: CGFloat, height: CGFloat) -> some View {
        if width >= 900 && height >= 620 {
            VStack(alignment: .leading, spacing: 12) {
                header
                DisclosureGroup(model.t("InputCount", model.n(model.roots.count))) {
                    inputHeading
                    ScrollView { inputLocations }.frame(maxHeight: 120)
                }.disabled(model.busy || model.plan != nil)
                HSplitView {
                    RuleEditor(model: model, palette: palette).padding(12).frame(minWidth: 340, idealWidth: 380, maxWidth: 500)
                    VStack(spacing: 12) {
                        statistics(columns: 4)
                        previewState
                        search
                        results
                        footer
                    }.padding(12).frame(minWidth: 420)
                }
            }.padding(12)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    locationsDisclosure
                    DisclosureGroup(model.t("Rules"), isExpanded: $workbenchRulesExpanded) {
                        RuleEditor(model: model, palette: palette).frame(height: max(280, height * 0.55))
                    }
                    previewState
                    statistics(columns: WindowLayout.cardColumns(width: width - 24))
                    search
                    if model.busy { activity }
                    if model.visible.isEmpty { emptyState.frame(minHeight: 170) }
                    else { LazyVStack { ForEach(model.visible) { entry in CompactResultRow(model: model, entry: entry, palette: palette).id(entry.id) } } }
                    footer
                }.padding(12)
            }
        }
    }
    private var previewState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(model.t(model.hasUnappliedRules ? "UnappliedRules" : "FilePreviewCurrent"), systemImage: model.hasUnappliedRules ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                .font(.caption).foregroundStyle(model.hasUnappliedRules ? palette.warning : palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.hasUnappliedRules {
                Button(model.t("UpdateFilePreview")) { model.usePipeline(model.workbenchDraft) }.disabled(model.busy || model.plan != nil)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var wideContent: some View {
        HStack(spacing: 16) {
            VStack(spacing: 16) {
                header
                locationsDisclosure
                statistics(columns: 4)
                search
                notice
                results
                footer
            }
        }.padding(12)
    }
    @ViewBuilder private func compactContent(width: CGFloat, height: CGFloat) -> some View {
        if height < 300 {
            ScrollView { compactSections(width: width); footer.padding(12) }
        } else {
            ScrollView { compactSections(width: width) }
                .safeAreaInset(edge: .bottom, spacing: 0) { footer.padding(12).background(palette.canvas) }
        }
    }
    private func compactSections(width: CGFloat) -> some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            header
            locationsDisclosure
            statistics(columns: WindowLayout.cardColumns(width: width - 24))
            search
            notice
            if model.busy { activity }
            if model.visible.isEmpty { emptyState.frame(minHeight: 170) }
            else { ForEach(model.visible) { entry in CompactResultRow(model: model, entry: entry, palette: palette).id(entry.id) } }
        }.padding(12)
    }
    private var notice: some View {
        Text(model.t(model.isWorkbench ? "NormalizationNotice" : "QuickCleanupHelp")).font(.caption).foregroundStyle(palette.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
    }
    private var locationsDisclosure: some View {
        DisclosureGroup(model.t("InputCount", model.n(model.roots.count))) {
            inputHeading
            ScrollView { inputLocations }.frame(height: 110)
        }.disabled(model.busy || model.plan != nil)
    }
    private var addFiles: some View {
        Button { pick(folders: false) } label: { Label(model.t("AddFiles"), systemImage: "doc.badge.plus").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5) }.accessibilityIdentifier("addFiles")
    }
    private var addFolders: some View {
        Button { pick(folders: true) } label: { Label(model.t("AddFolders"), systemImage: "folder.badge.plus").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5) }.accessibilityIdentifier("addFolders")
    }
    private var recursiveToggle: some View {
        Toggle(model.t("Recursive"), isOn: Binding(get: { model.settings.recursive }, set: { value in model.changeSettings { $0.recursive = value } })).disabled(model.busy)
    }
    private var inputHeading: some View {
        HStack {
            Text(model.t("InputCount", model.n(model.roots.count))).fontWeight(.semibold)
            Spacer()
            Button(model.t("ResetInputs")) { model.remove(nil) }.disabled(model.busy || model.roots.isEmpty)
        }
    }
    private var inputLocations: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(model.roots, id: \.self) { root in
                HStack {
                    Image(systemName: "folder").accessibilityHidden(true)
                    Text(String(data: root.leaf, encoding: .utf8) ?? root.display).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).help(root.display)
                    Button { model.remove(root) } label: { Image(systemName: "minus.circle") }.buttonStyle(.plain).disabled(model.busy).help(model.t("RemoveInput")).accessibilityLabel(model.t("RemoveInput"))
                }.padding(.vertical, 5)
            }
            if model.settings.rememberRecentFolders {
                Divider()
                Text(model.t("RecentFolders")).fontWeight(.medium)
                ForEach(model.settings.recentFolders, id: \.self) { path in
                    Button { model.add([URL(fileURLWithPath: path)]) } label: { Text(URL(fileURLWithPath: path).lastPathComponent).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).help(path)
                }
                if model.settings.recentFolders.isEmpty { Text(model.t("NoRecentFolders")).foregroundStyle(palette.secondary).font(.caption) }
            }
        }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isWorkbench {
                Text(model.t("BatchWorkspace")).font(.title2).fontWeight(.semibold).accessibilityAddTraits(.isHeader)
                Text(model.t("BatchPurpose")).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack { addFiles; addFolders; recursiveToggle; formatHelp }
                VStack(alignment: .leading, spacing: 8) { addFiles; addFolders; recursiveToggle; formatHelp }
            }.disabled(model.busy || model.plan != nil)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
    }
    private var formatHelp: some View {
        Button { model.sheet = "formatHelp" } label: { Image(systemName: "info.circle") }
            .buttonStyle(.borderless).help(model.t("FormatGuide")).accessibilityLabel(model.t("FormatGuide"))
    }
    private func statistics(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns), alignment: .leading, spacing: 16) {
            statistic("TotalCaption", model.counts["TotalCaption"] ?? 0, "All", palette.heroText)
            statistic("NeededCaption", model.counts["NeededCaption"] ?? 0, "NeedsNormalization", palette.heroPreview)
            statistic("ConflictCaption", model.counts["ConflictCaption"] ?? 0, "Conflict", palette.heroWarning)
            statistic("SelectedCaption", model.selected.count, "SelectedOnly", palette.heroText)
        }
        .padding(.vertical, 17).background(LinearGradient(colors: [palette.heroStart, palette.heroEnd], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
    }
    private func statistic(_ key: String, _ count: Int, _ filter: String, _ color: Color) -> some View {
        Button { model.filter = filter } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.t(key)).font(L10n.font(model.settings.language, size: 11)).foregroundStyle(palette.heroCaption)
                Text(model.n(count)).font(L10n.font(model.settings.language, size: 22, weight: .semibold)).monospacedDigit().foregroundStyle(color)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 22).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(model.t(key) + " " + model.n(count))
    }
    private var search: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack { searchField.frame(minWidth: 160); filters }
                VStack { searchField; filters }
            }
            ViewThatFits(in: .horizontal) {
                HStack { hideNormal; scopeCaption; Spacer(); resetFilters }
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) { HStack { hideNormal; Spacer(); resetFilters }; VStack(alignment: .leading) { hideNormal; resetFilters } }
                    scopeCaption
                }
            }
        }
    }
    private var searchField: some View {
        TextField(model.t("Search"), text: $model.query).textFieldStyle(.roundedBorder).focused($searchFocused).accessibilityIdentifier("search")
    }
    private var filters: some View {
        ViewThatFits(in: .horizontal) { HStack { filterPicker; sortPicker }; VStack(alignment: .leading) { filterPicker; sortPicker } }
    }
    private var filterPicker: some View {
        Picker(model.t("Filter"), selection: $model.filter) { ForEach(["All", "NeedsNormalization", "Normal", "Conflict", "Errors", "SelectedOnly"], id: \.self) { Text(model.t($0 == "NeedsNormalization" ? "NeededCaption" : $0)).tag($0) } }.labelsHidden().frame(minWidth: 145).fixedSize()
    }
    private var sortPicker: some View {
        Picker(model.t("Sort"), selection: $model.sort) { ForEach(["Name", "Status", "Path"], id: \.self) { Text(model.t($0)).tag($0) } }.labelsHidden().frame(minWidth: 145).fixedSize()
    }
    private var hideNormal: some View {
        Toggle(model.t("HideNormal"), isOn: Binding(get: { model.settings.hideNormal }, set: { value in model.changeSettings { $0.hideNormal = value } })).fixedSize()
    }
    private var scopeCaption: some View {
        Text(model.t("SelectionScope", model.n(model.visible.count), model.n(model.entries.count), model.n(model.hiddenSelected))).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
    }
    private var resetFilters: some View {
        Button(model.t("ResetFilters")) { model.query = ""; model.filter = "All"; model.changeSettings { $0.hideNormal = false } }.buttonStyle(.borderless).fixedSize()
    }
    private var results: some View {
        VStack(spacing: 0) {
            if model.busy { activity; Divider() }
            if model.visible.isEmpty {
                emptyState
            } else {
                ResultTable(model: model, palette: palette)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.border, lineWidth: 1))
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
    private var emptyState: some View {
                VStack(spacing: 16) {
                    Image(systemName: model.entries.isEmpty ? "folder" : "magnifyingglass").font(.system(size: 32, weight: .light)).foregroundStyle(palette.accent).frame(width: 76, height: 76).background(palette.control, in: RoundedRectangle(cornerRadius: 24))
                    Text(model.t(model.entries.isEmpty ? (model.isWorkbench ? "BatchEmptyTitle" : "EmptyTitle") : "NoResultsTitle")).font(L10n.font(model.settings.language, size: 18, weight: .semibold))
                    Text(model.t(model.entries.isEmpty ? (model.isWorkbench ? "BatchEmptyDescription" : "EmptyDescription") : "NoResultsDescription")).foregroundStyle(palette.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("emptyState")
    }
    private var footer: some View {
        ViewThatFits(in: .horizontal) {
            HStack { selectionActions; Spacer(); renameButton }
            VStack(alignment: .leading, spacing: 10) { selectionActions; HStack { Spacer(); renameButton } }
        }.buttonStyle(.borderless).disabled(model.busy).padding(.horizontal, 4)
    }
    private var selectionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack { selectionButtons }
            VStack(alignment: .leading, spacing: 8) { selectionButtons }
        }
    }
    @ViewBuilder private var selectionButtons: some View {
            Button(model.t("SelectVisible")) { model.select("visible") }
            Button(model.t("ClearVisible")) { model.select("clearVisible") }
            Button(model.t("InspectShort")) { model.sheet = "inspector" }.disabled(model.focused == nil)
            Menu {
                Button(model.t("SelectAllSafe")) { model.select("all") }
                Button(model.t("ClearAll")) { model.select("none") }
                Button(model.t("InvertVisible")) { model.select("invert") }
                Divider()
                Button(model.t("NumberConflicts")) { model.numberConflicts() }.disabled((model.counts["ConflictCaption"] ?? 0) == 0)
                Button(model.t("ClipboardInspect")) { model.inspectClipboard() }
                Button(model.t("ExportDiagnostics")) { model.diagnostics(); model.sheet = "diagnostics" }
                Button(model.t("UndoLatest")) { if let h = model.history.first(where: { $0.mode == "rename" && $0.succeeded > 0 }) { model.prepare(mode: "undo", historyID: h.id) } }.disabled(model.history.isEmpty)
            } label: { Image(systemName: "ellipsis") }.accessibilityLabel(model.t("MoreActions")).menuStyle(.borderlessButton).frame(width: 24)
    }
    private var renameButton: some View {
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
            TableColumn(model.t("Type")) { entry in Image(systemName: entry.isDirectory ? "folder" : "doc").foregroundStyle(palette.secondary).help(model.t(entry.isDirectory ? "Directory" : "File")).accessibilityLabel(model.t(entry.isDirectory ? "Directory" : "File")) }.width(46)
            TableColumn(model.t("Name")) { entry in NameCompositionCell(entry: entry, preview: false, compact: model.settings.compactRows, palette: palette, language: model.settings.language) }.width(min: 110, ideal: CGFloat(model.settings.nameColumnRatio * 3), max: .infinity)
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
