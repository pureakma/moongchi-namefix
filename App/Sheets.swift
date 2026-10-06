import SwiftUI
import AppKit
import UniformTypeIdentifiers
import NameFixCore
import NameFixRuntime

struct ConfirmationView: View {
    @ObservedObject var model: AppModel
    let plan: RenamePlan
    let palette: Palette
    var availableSize = CGSize(width: 1180, height: 780)
    var body: some View {
        FlexibleSheet(preferred: CGSize(width: 650, height: 640), available: availableSize) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(model.t(plan.mode == "rename" ? "Confirm" : plan.mode == "undo" ? "Undo" : "Recovery")).font(.title2).fontWeight(.semibold)
                        Text(model.t(plan.mode == "rename" ? "ConfirmBody" : plan.mode == "recovery" ? "ConfirmRecovery" : "UndoConfirm", model.n(plan.operations.count), model.n(plan.excluded)))
                        if plan.mode == "rename" { Label(model.t("UndoAvailable"), systemImage: "arrow.uturn.backward.circle").foregroundStyle(palette.secondary) }
                        if plan.mode == "rename", model.hiddenSelected > 0 { Text(model.t("HiddenSelectionConfirm", model.n(model.hiddenSelected))).foregroundStyle(palette.warning) }
                        Text(model.t("OutputForm") + ": " + model.t(model.pipeline.target.rawValue)).font(.caption).foregroundStyle(palette.secondary)
                        Text(model.t("CloudWarning")).foregroundStyle(palette.secondary)
                        Text(model.t("FilesystemHelp")).font(.caption).foregroundStyle(palette.secondary)
                        Text(model.t("ConcurrentChangeHelp")).font(.caption).foregroundStyle(palette.secondary)
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(plan.operations) { operation in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(String(decoding: operation.source.leaf, as: UTF8.self)).textSelection(.enabled)
                                    Label(String(decoding: operation.destination, as: UTF8.self), systemImage: "arrow.right").foregroundStyle(palette.preview).textSelection(.enabled)
                                    Text(operation.source.display).font(.caption).foregroundStyle(palette.secondary).textSelection(.enabled)
                                    Divider()
                                }.fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Text(model.t("PlanExcluded", model.n(plan.excluded))).font(.caption)
                    }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                ViewThatFits(in: .horizontal) {
                    HStack { Spacer(); cancel; confirm }
                    VStack(alignment: .trailing, spacing: 8) { confirm; cancel }.frame(maxWidth: .infinity, alignment: .trailing)
                }.padding(14)
            }
        }.background(palette.dialog).foregroundStyle(palette.text).font(L10n.font(model.settings.language)).tint(palette.accent)
    }
    private var confirm: some View {
        Button(model.t(plan.mode == "rename" ? "Rename" : plan.mode == "recovery" ? "RestoreOriginal" : "Undo")) { model.execute() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).accessibilityIdentifier("confirmRename")
    }
    private var cancel: some View { Button(model.t("Cancel")) { model.cancelPreview() }.keyboardShortcut(.cancelAction) }
}
struct SheetRouter: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(model.settings.theme, systemDark: scheme == .dark) }
    var availableSize = CGSize(width: 1180, height: 780)
    /// The sheet keeps showing what it had while it closes: `model.sheet` is already nil then,
    /// and falling back to another screen would flash that screen during the closing animation.
    @State private var last: String?
    /// Where the introduction was opened from, so closing it returns there instead of closing everything.
    @State private var origin: String?
    private var name: String { model.sheet ?? last ?? "help" }
    var body: some View {
        Group {
            // The introduction brings its own frame and light colours.
            if name == "onboarding" {
                FlexibleSheet(preferred: CGSize(width: 620, height: 560), available: availableSize) { OnboardingView(model: model, returnTo: origin) }
            } else { standard }
        }
        .onAppear { last = model.sheet }
        .onChange(of: model.sheet) { old, new in
            guard let new else { return }
            if new == "onboarding" { origin = old }
            last = new
        }
    }
    private var standard: some View {
        FlexibleSheet(preferred: CGSize(width: name == "history" ? 840 : 680, height: name == "history" ? 580 : 560), available: availableSize) {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2).fontWeight(.semibold)
                Spacer()
                Button(model.t("Close")) { model.sheet = nil; model.flushQueued() }.keyboardShortcut(.cancelAction)
            }.padding(.horizontal, 24).padding(.vertical, 18)
            Divider()
            Group {
                switch name {
                case "formatHelp": CharacterFormatView(model: model, palette: palette)
                case "tools": AdditionalToolsView(model: model, palette: palette)
                case "settings": SettingsView(model: model, palette: palette)
                case "history": HistoryView(model: model, palette: palette)
                case "inspector": inspector
                case "clipboard": TextToolView(model: model, palette: palette)
                case "watch": WatchView(model: model, palette: palette)
                case "diagnostics": diagnostics
                case "about": about
                default: HelpView(model: model, palette: palette)
                }
            }.padding(22)
        }
        }.background(palette.dialog).foregroundStyle(palette.text).font(L10n.font(model.settings.language)).tint(palette.accent)
    }
    private var title: String {
        let keys = ["formatHelp":"FormatGuide", "tools":"ExportReport", "watch":"FolderWatch", "settings":"Settings", "history":"History", "inspector":"Inspector", "clipboard":"TextTool", "diagnostics":"DiagnosticsPreview", "about":"About", "help":"HelpTitle"]
        return model.t(keys[name] ?? "HelpTitle")
    }
    @ViewBuilder private var inspector: some View {
        if let entry = model.entries.first(where: { $0.id == model.focused }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent(model.t("Name"), value: entry.name)
                    LabeledContent(model.t("Preview"), value: entry.preview)
                    Text(model.t(entry.reason)).foregroundStyle(palette.secondary)
                    if entry.status.fixable && entry.reason != "RuleChangeHelp" { Text(model.t("SameAppearanceDifferentUnicode")).font(.caption) }
                    HStack { Text(entry.path.display).textSelection(.enabled); Spacer(); Button(model.t("CopyPath")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.path.display, forType: .string) } }
                    Divider()
                    CharacterComparison(model: model, text: entry.name, palette: palette)
                    DisclosureGroup(model.t("Advanced")) {
                        UnicodeView(model: model, text: entry.name, palette: palette).content
                    }
                }.textSelection(.enabled)
            }
        } else { Text(model.t("InspectorHint")).frame(maxHeight: .infinity) }
    }
    private var about: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Moongchi NameFix").font(.largeTitle)
                Text("\(AppInfo.version) (\(AppInfo.build)) · Apple Silicon · macOS 14+")
                Text(model.t("LocalOnly"))
                Text(model.t("License")).font(.headline)
                Text(licenseText).font(.system(size: 11)).textSelection(.enabled)
            }
        }
    }
    private var licenseText: String {
        ["PretendardVariable-LICENSE", "PretendardJPVariable-LICENSE"].compactMap { name in Bundle.main.url(forResource: name, withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } }.joined(separator: "\n\n")
    }
    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(model.t("MaskPaths"), isOn: $model.maskPaths).onChange(of: model.maskPaths) { _, _ in model.diagnostics() }
            ScrollView { Text(model.diagnosticsPreview).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            HStack { Spacer(); Button(model.t("Export")) { export() } }
        }
    }
    private func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "NameFix-Diagnostics.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let text = model.diagnosticsPreview
        Task {
            do { try await Task.detached { try Data(text.utf8).write(to: url, options: .atomic) }.value; model.message = "Exported" }
            catch { model.message = "DiagnosticsError" }
        }
    }
}
struct UnicodeView: View {
    @ObservedObject var model: AppModel
    let text: String
    let palette: Palette
    var truncated = false
    var body: some View { ScrollView { content } }
    @ViewBuilder var content: some View {
        let analysis = NormalizationAnalysis(raw: Data(text.utf8))
            VStack(alignment: .leading, spacing: 14) {
                if truncated { Text(model.t("ClipboardTruncated")).foregroundStyle(palette.warning) }
                Text(text).textSelection(.enabled)
                Text(model.t("Graphemes", model.n(text.count), model.n(text.unicodeScalars.count), model.n(text.utf16.count))).font(.caption).foregroundStyle(palette.secondary)
                ForEach(analysis.forms, id: \.0) { name, value in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).fontWeight(.semibold)
                        Text(value).textSelection(.enabled)
                    }
                }
                DisclosureGroup(model.t("Advanced")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(analysis.scalars)
                        Text(model.t("UTF16Units") + "\n" + analysis.utf16)
                    }.font(.system(size: 12, design: .monospaced)).textSelection(.enabled).padding(.top, 8)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 18) {
            if let message = model.message, ["SettingsSaveFailed", "SettingsWarning", "NewerSchema"].contains(message) {
                Label(model.t(message), systemImage: "exclamationmark.triangle").foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true)
            } else {
                Label(model.t("SettingsAutomatic"), systemImage: "checkmark.circle").font(.caption).foregroundStyle(palette.secondary)
            }
            settingsSection(nil, icon: "") {
                Text(model.t("Theme")).fontWeight(.medium)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                    ForEach(AppTheme.allCases, id: \.rawValue) { theme in themeChoice(theme) }
                }.accessibilityIdentifier("themePicker")
                Divider()
                settingToggle("CompactRows", \.compactRows)
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t("ColumnWidth") + " · " + model.n(Int(model.settings.nameColumnRatio)) + "%")
                    Slider(value: binding(\.nameColumnRatio), in: 25...75, step: 1) { Text(model.t("ColumnWidth")) }.labelsHidden().accessibilityValue(model.n(Int(model.settings.nameColumnRatio)) + "%")
                    Text(model.t("ColumnWidthHelp")).font(.caption).foregroundStyle(palette.secondary)
                }
            }
            settingsSection("General", icon: "slider.horizontal.3") {
                HStack {
                    Text(model.t("Language")); Spacer(minLength: 10)
                    Picker(model.t("Language"), selection: binding(\.language)) {
                        Text(model.t("System")).tag("system"); Text("한국어").tag("ko-KR"); Text("English").tag("en-US"); Text("日本語").tag("ja-JP")
                    }.labelsHidden().fixedSize()
                }
                settingToggle("Recursive", \.recursive).disabled(model.busy || model.plan != nil)
                settingToggle("ClearAfterRun", \.clearSelectionAfterRun)
            }
            settingsSection("MacIntegration", icon: "menubar.rectangle") { IntegrationSettingsView(model: model) }
            settingsSection("Privacy", icon: "hand.raised") {
                settingToggle("RememberFolders", \.rememberRecentFolders)
                Text(model.t("RecentPrivacy")).font(.caption).foregroundStyle(palette.secondary)
                Button(model.t("ClearRecentFolders")) { model.changeSettings { $0.recentFolders = [] } }.disabled(model.settings.recentFolders.isEmpty)
                Stepper(model.t("HistoryLimit") + ": " + model.n(model.settings.historyLimit), value: binding(\.historyLimit), in: 1...1000)
                Text(model.t("HistoryRetentionHelp")).font(.caption).foregroundStyle(palette.secondary)
                settingToggle("Diagnostics", \.diagnostics)
            }
            DeveloperCard(model: model, palette: palette)
          }.padding(2).frame(maxWidth: .infinity, alignment: .leading)
        }.toggleStyle(.switch)
    }
    private func settingToggle(_ key: String, _ path: WritableKeyPath<AppSettings, Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(model.t(key)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Toggle(model.t(key), isOn: binding(path)).labelsHidden().fixedSize()
        }
    }
    private func settingsSection<Content: View>(_ title: String?, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        ToolSection(title: title.map { model.t($0) }, icon: icon, palette: palette, content: content)
    }

    private func themeChoice(_ theme: AppTheme) -> some View {
        let colors = Palette(theme.rawValue, systemDark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let selected = model.settings.theme == theme.rawValue
        return Button { model.changeSettings { $0.theme = theme.rawValue } } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in RoundedRectangle(cornerRadius: 4).fill([colors.canvas, colors.surface, colors.accent][index]).frame(width: 18, height: 18).overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border, lineWidth: 0.5)) }
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle").foregroundStyle(selected ? palette.accent : palette.secondary)
                }
                Text(model.t(theme.titleKey)).font(.caption).fixedSize(horizontal: false, vertical: true)
            }.padding(10).frame(maxWidth: .infinity, minHeight: 65, alignment: .topLeading)
                .background(selected ? palette.accent.opacity(0.10) : palette.control, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? palette.accent : palette.border, lineWidth: selected ? 2 : 1))
        }.buttonStyle(.plain).accessibilityLabel(model.t(theme.titleKey))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("theme-" + theme.rawValue)
    }
    private func binding<T>(_ key: WritableKeyPath<AppSettings, T>) -> Binding<T> { Binding(get: { model.settings[keyPath: key] }, set: { value in model.changeSettings { $0[keyPath: key] = value } }) }
}
struct HistoryView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 620 || proxy.size.height < 300 {
                ScrollView { VStack(spacing: 18) { historyList.frame(height: 150); details(compact: true) } }
            } else {
                HStack(spacing: 18) { historyList.frame(width: 230); details(compact: false) }
            }
        }
    }
    private var historyList: some View {
            List(selection: $model.historyID) {
                ForEach(model.history) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.date == .distantPast ? model.t("RecoveryNeedsReview") : model.d(item.date))
                        Text(model.outcome(item.status)).font(.caption).foregroundStyle(palette.secondary)
                        Text(model.t("ResultSummary", model.n(item.succeeded), model.n(max(0, item.total-item.succeeded-item.failed)), model.n(item.failed))).font(.caption)
                    }.tag(item.id).padding(.vertical, 6)
                }
            }.scrollContentBackground(.hidden).overlay { if model.history.isEmpty { Text(model.t("NoHistory")) } }
            .onChange(of: model.historyID) { _, id in if let id { model.loadDetails(id) } }
    }
    private func details(compact: Bool) -> some View {
            VStack(alignment: .leading, spacing: 12) {
                if model.historyLoading { ProgressView(model.t("Loading")) }
                List(model.historyDetails) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.operation.source.display).lineLimit(2).help(row.operation.source.display)
                        Text("→ " + String(decoding: row.operation.destination, as: UTF8.self)).foregroundStyle(palette.preview)
                        Text(model.outcome(row.error ?? row.state)).font(.caption).foregroundStyle(row.error == nil ? palette.secondary : palette.warning)
                    }.textSelection(.enabled).padding(.vertical, 3)
                }.scrollContentBackground(.hidden).frame(minHeight: 160, maxHeight: compact ? 180 : .infinity)
                if !model.recoveryDetails.isEmpty {
                    if compact { recoveryLocations }
                    else { ScrollView { recoveryLocations }.frame(maxHeight: 220) }
                }
                ViewThatFits(in: .horizontal) {
                    HStack { historyActions }.fixedSize(horizontal: true, vertical: false)
                    VStack(alignment: .leading, spacing: 8) { historyActions }
                }
            }
    }
    private var recoveryLocations: some View {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            Text(model.t("RecoveryStatus")).font(.headline)
                            ForEach(model.recoveryDetails) { row in
                                Text(model.t(row.status)).foregroundStyle(palette.warning)
                                Text(row.current?.display ?? row.operation.source.display).font(.caption).textSelection(.enabled)
                                if let path = row.current {
                                    Button(model.t("ShowInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([FileCoordination.url(path)]) }
                                }
                                if row.current == nil, !row.observedLocations.isEmpty {
                                    Text(model.t("RecoveryObservedPaths")).font(.caption)
                                    ForEach(row.observedLocations, id: \.self) { path in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(path.display).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                            ViewThatFits(in: .horizontal) {
                                                HStack { locationActions(path) }.fixedSize(horizontal: true, vertical: false)
                                                VStack(alignment: .leading, spacing: 6) { locationActions(path) }
                                            }
                                        }
                                    }
                                }
                            }
                        }.fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private func locationActions(_ path: RawPath) -> some View {
        Button(model.t("CopyPath")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(path.display, forType: .string) }.fixedSize(horizontal: false, vertical: true)
        Button(model.t("ShowInFinder")) { NSWorkspace.shared.activateFileViewerSelecting([FileCoordination.url(path)]) }.fixedSize(horizontal: false, vertical: true)
    }
    @ViewBuilder private var historyActions: some View {
        Button(model.t("Undo")) { if let id = model.historyID { model.prepare(mode: "undo", historyID: id) } }.disabled(model.historyID == nil || model.historyLoading || model.busy).fixedSize(horizontal: false, vertical: true)
        if !model.recoveryDetails.isEmpty { Button(model.t("Recovery")) { if let id = model.historyID { model.prepare(mode: "recovery", historyID: id) } }.disabled(model.busy || model.historyLoading).fixedSize(horizontal: false, vertical: true) }
    }
}
