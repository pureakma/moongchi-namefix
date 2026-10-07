import SwiftUI
import AppKit
import NameFixCore
import NameFixRuntime

/// Pipeline-level options that are not rules. Each opens in its own sheet from the Add Rule menu.
enum AdvancedOption: String, Identifiable, CaseIterable {
    case form = "AdvForm", targets = "AdvTargets", order = "AdvOrder", csv = "AdvCSV", pairs = "AdvPairs", presets = "AdvPresets"
    var id: String { rawValue }
    var icon: String { ["AdvForm": "doc.text", "AdvTargets": "scope", "AdvOrder": "list.number", "AdvCSV": "tablecells", "AdvPairs": "square.on.square", "AdvPresets": "square.stack"][rawValue] ?? "gearshape" }
}

/// A row whose whole width toggles its content; the chevron is only a hint.
struct Expander<Content: View>: View {
    let title: String
    let palette: Palette
    @State private var open = false
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.control) {
            Button { open.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).rotationEffect(.degrees(open ? 90 : 0)).foregroundStyle(palette.secondary).accessibilityHidden(true)
                    Text(title); Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 22, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(open ? "1" : "0")
            if open { content() }
        }
    }
}

/// Left pane of Batch Rename: a header with Add Rule, then a compact list of what will be applied.
/// Only the selected rule shows its fields; everything else stays one summary line.
struct RuleEditor: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    private var draft: RulePipeline {
        get { model.workbenchDraft }
        nonmutating set { model.workbenchDraft = newValue }
    }
    /// Embedded in a scrolling parent (narrow windows): lay out inline instead of nesting a scroll view.
    private let embedded: Bool
    @State private var adding = false
    @State private var selected: UUID?
    @State private var option: AdvancedOption?
    /// The example is the first added name the rules actually change; `nil` when none does.
    @State private var example: (before: String, after: String)?
    @State private var exampleChecked = false
    @State private var sampleError: String?
    @State private var samples = ["photo  001.jpg"]
    @State private var samplesFromList = false
    init(model: AppModel, palette: Palette, embedded: Bool = false, selecting: UUID? = nil) {
        self.model = model; self.palette = palette; self.embedded = embedded
        _selected = State(initialValue: selecting)
    }
    private var configured: [AdvancedOption] {
        var result: [AdvancedOption] = []
        if draft.target != .nfc { result.append(.form) }
        if draft.includeFolders == true || draft.includeHidden == true { result.append(.targets) }
        if let order = draft.order, order != .path { result.append(.order) }
        if draft.mapping != nil { result.append(.csv) }
        if !(draft.pairExtensions ?? []).isEmpty { result.append(.pairs) }
        return result
    }
    var body: some View {
        Group { if embedded { content } else { ScrollView { content } } }
        .disabled(model.busy || model.plan != nil).task(id: SampleRequest(target: draft.target, rules: draft.rules, names: samples)) {
            let snapshot = AppModel.applicable(RulePipeline(target: draft.target, rules: draft.rules)), names = samples.map { String($0.prefix(1024)) }, token = CancellationToken()
            let active = snapshot.rules.contains(where: \.enabled)
            // A name the rules leave as it is shows nothing, so look for one they change.
            let work = Task.detached { () throws -> (before: String, after: String)? in
                guard active else { return nil }
                for name in names {
                    let steps = try snapshot.evaluate(name, access: .pro, cancelled: { token.cancelled })
                    if let first = steps.first, let last = steps.last, last.after != first.after { return (first.after, last.after) }
                }
                return nil
            }
            do {
                let found = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { token.cancel(); work.cancel() })
                if !Task.isCancelled { example = found; exampleChecked = active; sampleError = nil }
            } catch { if !Task.isCancelled { example = nil; exampleChecked = false; sampleError = (error as? RuleFailure)?.rawValue ?? "RuleInvalid" } }
        }
        .onChange(of: model.entries.count) { _, _ in loadSamples() }
        .onAppear {
            loadSamples()
            // Start with Replace Text open, so the first thing to do is visible.
            // (A resized window builds this pane again; the rule is then already there, still unfilled.)
            if selected == nil {
                selected = model.addStarterRule() ?? (draft.rules.count == 1 && draft.rules[0].kind == .replace && draft.rules[0].text.isEmpty ? draft.rules[0].id : nil)
            }
        }
        .sheet(item: $option) { AdvancedRuleSheet(model: model, palette: palette, option: $0) { option = nil } }
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            header
            if draft.rules.isEmpty && configured.isEmpty {
                Text(model.t("RulesEmpty")).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(draft.rules.enumerated()), id: \.element.id) { index, rule in
                    if index < draft.rules.count { ruleRow(index, rule) }
                }
                ForEach(configured) { optionRow($0) }
            }
            if !draft.rules.isEmpty || !configured.isEmpty { sampleLine }
        }.textFieldStyle(.roundedBorder).frame(maxWidth: .infinity, alignment: .leading)
    }
    private var header: some View {
        HStack(spacing: Metrics.control) {
            Text(model.t("RulesPane")).font(.headline).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Metrics.control)
            if !draft.rules.isEmpty || !configured.isEmpty {
                Button { draft = RulePipeline(); selected = nil } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless).hoverTip(model.t("ResetRules")).accessibilityLabel(model.t("ResetRules"))
            }
            Button { adding = true } label: { Label(model.t("AddRule"), systemImage: "plus") }
                .controlSize(.small).accessibilityIdentifier("addRule")
                .popover(isPresented: $adding, arrowEdge: .bottom) {
                    AddRuleMenu(model: model, palette: palette) { kind in adding = false; add(kind) } advanced: { choice in adding = false; option = choice }
                }
        }.frame(height: Metrics.paneHeader)
    }
    private func add(_ kind: RuleKind) {
        var rule = RenameRule(kind)
        if kind == .numbering { rule.text = "_" }
        draft.rules.append(rule); selected = rule.id
    }

    // MARK: Rule list

    private func ruleRow(_ index: Int, _ rule: RenameRule) -> some View {
        let open = selected == rule.id
        return VStack(alignment: .leading, spacing: Metrics.control) {
            HStack(alignment: .top, spacing: Metrics.control) {
                Toggle(model.t(RuleSummary.title(rule.kind)), isOn: $model.workbenchDraft.rules[index].enabled).labelsHidden().padding(.top, 1)
                Button { selected = open ? nil : rule.id } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.t(RuleSummary.title(rule.kind))).fontWeight(.medium)
                        Text(RuleSummary.text(rule, model: model)).font(.caption).foregroundStyle(palette.secondary).lineLimit(1).truncationMode(.middle)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityHint(model.t("EditRule")).accessibilityAddTraits(open ? .isSelected : [])
                Menu { ruleActions(index) } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().accessibilityLabel(model.t("RuleMore")).hoverTip(model.t("RuleMore"))
            }
            if open {
                VStack(alignment: .leading, spacing: Metrics.control) {
                    RuleFields(model: model, rule: $model.workbenchDraft.rules[index], palette: palette)
                    if rule.kind == .metadata {
                        TextField(model.t("DateFormat"), text: Binding(get: { draft.dateFormat ?? "yyyy-MM-dd" }, set: { draft.dateFormat = $0 }))
                        TextField(model.t("TimeZone"), text: Binding(get: { draft.timeZone ?? "UTC" }, set: { draft.timeZone = $0 }))
                        Text(model.t("MetadataHelp")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(.leading, 26)
            }
        }
        .padding(8).background(open ? palette.surface : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(open ? palette.border : .clear, lineWidth: 1))
        .contextMenu { ruleActions(index) }
    }
    @ViewBuilder private func ruleActions(_ index: Int) -> some View {
        Button(model.t("MoveUp")) { if index > 0, index < draft.rules.count { draft.rules.swapAt(index, index - 1) } }.disabled(index == 0)
        Button(model.t("MoveDown")) { if index + 1 < draft.rules.count { draft.rules.swapAt(index, index + 1) } }.disabled(index + 1 >= draft.rules.count)
        Divider()
        Button(model.t("RemoveRule")) { if index < draft.rules.count { draft.rules.remove(at: index) } }
    }
    /// An active pipeline option, shown like a rule so nothing configured is hidden.
    private func optionRow(_ choice: AdvancedOption) -> some View {
        HStack(alignment: .top, spacing: Metrics.control) {
            Image(systemName: choice.icon).frame(width: 18).foregroundStyle(palette.secondary).padding(.top, 2).accessibilityHidden(true)
            Button { option = choice } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.t(choice.rawValue)).fontWeight(.medium)
                    Text(optionSummary(choice)).font(.caption).foregroundStyle(palette.secondary).lineLimit(1).truncationMode(.middle)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityHint(model.t("EditRule"))
            Button { clear(choice) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless).hoverTip(model.t("Remove")).accessibilityLabel(model.t("Remove"))
        }.padding(8)
    }
    private func optionSummary(_ choice: AdvancedOption) -> String {
        switch choice {
        case .form: return model.t(draft.target.rawValue)
        case .targets: return [draft.includeFolders == true ? model.t("IncludeFolders") : nil, draft.includeHidden == true ? model.t("IncludeHidden") : nil].compactMap { $0 }.joined(separator: " · ")
        case .order: return model.t((draft.order ?? .path).rawValue)
        case .csv: return model.t("MappingCount", model.n(draft.mapping?.rows.count ?? 0))
        case .pairs: return model.t("SumPairs", (draft.pairExtensions ?? []).joined(separator: ", "))
        case .presets: return ""
        }
    }
    private func clear(_ choice: AdvancedOption) {
        switch choice {
        case .form: draft.target = .nfc
        case .targets: draft.includeFolders = nil; draft.includeHidden = nil
        case .order: draft.order = nil; draft.manualPaths = nil
        case .csv: draft.mapping = nil
        case .pairs: draft.pairExtensions = nil
        case .presets: break
        }
    }
    /// What the rules do to one real name, before the list preview is refreshed.
    @ViewBuilder private var sampleLine: some View {
        if let sampleError { Text(model.t(sampleError)).font(.caption).foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true) }
        else if let example {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.t("SampleLabel")).font(.caption).foregroundStyle(palette.secondary)
                Text(example.before).font(.caption).lineLimit(1).truncationMode(.middle)
                Label(example.after, systemImage: "arrow.turn.down.right").font(.callout).foregroundStyle(palette.preview).lineLimit(2).textSelection(.enabled)
            }.padding(.horizontal, 8).accessibilityElement(children: .combine)
        } else if exampleChecked, samplesFromList {
            // Rules that change none of the added names: say so instead of showing a name unchanged.
            VStack(alignment: .leading, spacing: 6) {
                Text(model.t("SampleUnchanged")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                // Folders are left out unless asked for. When there are folders, say so here and offer the switch.
                if draft.includeFolders != true, model.entries.contains(where: { $0.isDirectory && $0.reason == "FolderExcluded" }) {
                    Text(model.t("FolderExcluded")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    Button(model.t("IncludeFolders")) { draft.includeFolders = true; model.usePipeline(model.workbenchDraft) }.controlSize(.small).accessibilityIdentifier("includeFoldersHint")
                }
            }.padding(.horizontal, 8)
        }
    }
    private func loadSamples() {
        let names = model.entries.lazy.filter { !$0.isDirectory && !$0.status.isError }.prefix(200).map(\.name)
        samplesFromList = !names.isEmpty
        samples = names.isEmpty ? ["photo  001.jpg"] : Array(names)
    }
    private struct SampleRequest: Equatable {
        var target: NormalizationTarget; var rules: [RenameRule]; var names: [String]
        static func == (a: Self, b: Self) -> Bool { a.target == b.target && a.rules == b.rules && a.names.map { Data($0.utf8) } == b.names.map { Data($0.utf8) } }
    }
}

/// One-line description of a rule for the compact list.
@MainActor enum RuleSummary {
    static func title(_ kind: RuleKind) -> String { [.uppercase, .lowercase, .titlecase].contains(kind) ? "ActionCase" : kind.rawValue }
    static func text(_ rule: RenameRule, model: AppModel) -> String {
        func needs(_ value: String, _ make: () -> String) -> String { value.isEmpty ? model.t("SumNeedsValue") : make() }
        switch rule.kind {
        case .replace, .regex, .wildcard: return needs(rule.text) { model.t("SumReplace", rule.text, rule.replacement) }
        case .prefix: return needs(rule.text) { model.t("SumPrefix", rule.text) }
        case .suffix: return needs(rule.text) { model.t("SumSuffix", rule.text) }
        case .insert: return needs(rule.text) { model.t("SumInsert", model.n(rule.position), rule.text) }
        case .removeFirst, .removeLast, .keepFirst, .keepLast: return model.t("SumCount", model.n(rule.position))
        case .setName: return needs(rule.text) { rule.text }
        case .numbering: return model.t("SumNumber", String(rule.start), model.n(rule.digits))
        case .metadata: return rule.text.isEmpty ? model.t("ChooseField") : model.t(rule.text)
        case .spaces: return model.t("SumSpaces")
        case .uppercase, .lowercase, .titlecase: return model.t(rule.kind.rawValue)
        default: return ""
        }
    }
}

/// Add Rule popover. Every row is a full-width target; nothing depends on hitting a small arrow.
struct AddRuleMenu: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var startExpanded = false
    let rule: (RuleKind) -> Void
    let advanced: (AdvancedOption) -> Void
    @State private var more = false
    @State private var hovered: String?
    private let basic: [(RuleKind, String, String)] = [
        (.replace, "RuleReplace", "arrow.left.arrow.right"), (.prefix, "RulePrefix", "text.insert"), (.suffix, "RuleSuffix", "text.append"),
        (.numbering, "RuleNumbering", "number"), (.spaces, "RuleSpaces", "space"), (.uppercase, "ActionCase", "textformat")
    ]
    private let other: [RuleKind] = [.insert, .removeFirst, .removeLast, .keepFirst, .keepLast, .setName, .accents, .wildcard]
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            section("SectionBasic")
            ForEach(basic, id: \.1) { kind, title, icon in row(title, icon: icon) { rule(kind) } }
            Divider().padding(.vertical, 5)
            section("SectionAdvanced")
            row("AdvPattern", icon: "asterisk") { rule(.regex) }
            row("AdvFileInfo", icon: "info.circle") { rule(.metadata) }
            ForEach(AdvancedOption.allCases) { choice in row(choice.rawValue, icon: choice.icon) { advanced(choice) } }
            Divider().padding(.vertical, 5)
            row("SectionMore", icon: more || startExpanded ? "chevron.down" : "chevron.right") { more.toggle() }
            if more || startExpanded { ForEach(other, id: \.self) { kind in row(kind.rawValue, icon: "plus") { rule(kind) } } }
        }
        .padding(8).frame(width: 250)
        .foregroundStyle(palette.text).font(L10n.font(model.settings.language)).tint(palette.accent)
    }
    private func section(_ key: String) -> some View {
        Text(model.t(key)).font(.caption).foregroundStyle(palette.secondary).padding(.horizontal, 8).padding(.vertical, 3).accessibilityAddTraits(.isHeader)
    }
    private func row(_ key: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).frame(width: 18).foregroundStyle(palette.accent).accessibilityHidden(true)
                Text(model.t(key)); Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
            .background(hovered == key ? palette.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 6)).contentShape(Rectangle())
        }.buttonStyle(.plain).onHover { hovered = $0 ? key : (hovered == key ? nil : hovered) }.accessibilityIdentifier("add-" + key)
    }
}

/// One advanced option in its own sheet, so the main screen never shows every advanced field at once.
struct AdvancedRuleSheet: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    let option: AdvancedOption
    let close: () -> Void
    @State private var recipeName = ""
    @State private var manualRows: [RawPath] = []
    private var draft: RulePipeline {
        get { model.workbenchDraft }
        nonmutating set { model.workbenchDraft = newValue }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(model.t(option.rawValue), systemImage: option.icon).font(.title3).fontWeight(.semibold)
                Spacer()
                Button(model.t("Done"), action: close).keyboardShortcut(.defaultAction)
            }.padding(Metrics.page)
            Divider()
            ScrollView { detail.padding(Metrics.page).frame(maxWidth: .infinity, alignment: .leading) }
        }
        .frame(width: 480).frame(minHeight: 300, maxHeight: 560)
        .background(palette.dialog).foregroundStyle(palette.text).font(L10n.font(model.settings.language)).tint(palette.accent).textFieldStyle(.roundedBorder)
        .onAppear { manualRows = model.entries.map(\.path) }
    }
    @ViewBuilder private var detail: some View {
        switch option {
        case .form:
            VStack(alignment: .leading, spacing: Metrics.gap) {
                ForEach(NormalizationTarget.allCases, id: \.self) { target in
                    Button { draft.target = target } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: draft.target == target ? "largecircle.fill.circle" : "circle").foregroundStyle(palette.accent).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.t(target.rawValue)).fontWeight(.medium)
                                Text(model.t(target == .nfc ? "ComposeHelp" : target == .nfd ? "DecomposeHelp" : "KeepFormHelp")).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityAddTraits(draft.target == target ? .isSelected : [])
                }
            }
        case .targets:
            VStack(alignment: .leading, spacing: Metrics.gap) {
                Text(model.t("TargetsHelp")).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle(model.t("IncludeFolders"), isOn: Binding(get: { draft.includeFolders == true }, set: { draft.includeFolders = $0 ? true : nil })).accessibilityIdentifier("includeFolders")
                Text(model.t("IncludeFoldersHelp")).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle(model.t("IncludeHidden"), isOn: Binding(get: { draft.includeHidden == true }, set: { draft.includeHidden = $0 ? true : nil })).accessibilityIdentifier("includeHidden")
                Text(model.t("IncludeHiddenHelp")).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
        case .order:
            VStack(alignment: .leading, spacing: Metrics.gap) {
                Picker(model.t("SequenceOrder"), selection: Binding(get: { draft.order ?? .path }, set: { draft.order = $0 })) {
                    ForEach(SequenceOrder.allCases, id: \.self) { Text(model.t($0.rawValue)).tag($0) }
                }.pickerStyle(.radioGroup)
                if draft.order == .manual {
                    Text(model.t("ManualOrderHelp")).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    List {
                        ForEach(manualRows, id: \.self) { row in
                            HStack {
                                Text(row.display).lineLimit(1).truncationMode(.middle).help(row.display)
                                Spacer()
                                Button { moveManual(row, delta: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel(model.t("MoveUp")).disabled(manualRows.first == row)
                                Button { moveManual(row, delta: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel(model.t("MoveDown")).disabled(manualRows.last == row)
                            }
                        }
                        .onMove { source, destination in manualRows.move(fromOffsets: source, toOffset: destination); draft.manualPaths = manualRows.map(\.bytes) }
                    }.frame(height: 220)
                }
            }
        case .csv: MappingView(model: model, pipeline: $model.workbenchDraft)
        case .pairs:
            VStack(alignment: .leading, spacing: Metrics.gap) {
                TextField(model.t("PairExtensions"), text: Binding(get: { (draft.pairExtensions ?? []).joined(separator: ",") }, set: { draft.pairExtensions = $0.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                Text(model.t("PairHelp")).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
            }
        case .presets: presets
        }
    }
    private var presets: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            HStack {
                Button(model.t("BasicExample")) {
                    var prefix = RenameRule(.prefix); prefix.text = "Project_"
                    var number = RenameRule(.numbering); number.text = "_"
                    draft = RulePipeline(rules: [RenameRule(.spaces), prefix, number]); close()
                }
                Menu(model.t("ProExamples")) {
                    Button(model.t("PhotoExample")) {
                        var name = RenameRule(.setName); name.text = ""
                        var date = RenameRule(.metadata); date.text = "photo.date"
                        var number = RenameRule(.numbering); number.text = "_"
                        draft = RulePipeline(rules: [name, date, number]); close()
                    }
                    Button(model.t("RegexExample")) {
                        var rule = RenameRule(.regex); rule.text = "(?i)^(?:IMG|DSC)[_-]?"; rule.replacement = "Photo_"
                        draft = RulePipeline(rules: [rule]); close()
                    }
                }.fixedSize()
            }
            Divider()
            HStack {
                TextField(model.t("RecipeName"), text: $recipeName)
                Button(model.t("SaveRecipe")) { model.saveRecipe(name: recipeName, pipeline: draft) }
            }
            Button(model.t("ImportRecipe")) { importRecipe() }
            ForEach(model.recipes.recipes) { recipe in
                HStack {
                    TextField(model.t("RecipeName"), text: Binding(get: { recipe.name }, set: { model.editRecipe(recipe.id, name: $0) })).lineLimit(2)
                    Button(model.t("LoadRecipe")) { draft = recipe.pipeline; close() }
                    Menu(model.t("RecipeActions")) {
                        Button(model.t("Export")) { export(recipe) }
                        Button(model.t("Duplicate")) { model.editRecipe(recipe.id, duplicate: true) }
                        Button(model.t("Remove")) { model.editRecipe(recipe.id, remove: true) }
                    }.fixedSize()
                }
            }
            if let message = model.message { Text(model.t(message)).font(.callout).foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true) }
        }
    }
    private func moveManual(_ row: RawPath, delta: Int) {
        guard let index = manualRows.firstIndex(of: row), manualRows.indices.contains(index + delta) else { return }
        manualRows.swapAt(index, index + delta); draft.manualPaths = manualRows.map(\.bytes)
    }
    private func importRecipe() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                let recipe = try await Task.detached {
                    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 8_000_000 else { throw RuleFailure.budget }
                    let recipe = try JSONDecoder().decode(Recipe.self, from: Data(contentsOf: url))
                    try recipe.pipeline.validate(access: .pro); return recipe
                }.value
                model.saveRecipe(name: recipe.name, pipeline: recipe.pipeline)
            } catch { model.message = (error as? RuleFailure)?.rawValue ?? "RuleInvalid" }
        }
    }
    private func export(_ recipe: Recipe) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "NameFix-Recipe.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { do { try await Task.detached { try JSONEncoder().encode(recipe).write(to: url, options: .atomic) }.value } catch { model.message = "ExportFailed" } }
    }
}

/// The value fields of one rule. Only what the action needs is visible; scope,
/// conditions and advanced numbering sit under More options.
struct RuleFields: View {
    @ObservedObject var model: AppModel
    @Binding var rule: RenameRule
    let palette: Palette
    @FocusState private var focus: String?
    // RuleScope.name shares its raw value with the "Current name" column title.
    private func scopeKey(_ scope: RuleScope) -> String { scope == .name ? "ScopeFullName" : scope.rawValue }
    private func field(_ key: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.t(key)).font(.caption).foregroundStyle(palette.secondary)
            TextField("", text: text).accessibilityLabel(model.t(key))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.control) {
            switch rule.kind {
            case .replace:
                // Tab goes from what to find straight to what to put there, and Shift-Tab back.
                field("FieldFind", $rule.text).focused($focus, equals: "find")
                    .onKeyPress(.tab, phases: .down) { press in if press.modifiers.contains(.shift) { return .ignored }; focus = "replace"; return .handled }
                field("FieldReplaceWith", $rule.replacement).focused($focus, equals: "replace")
                    .onKeyPress(.tab, phases: .down) { press in guard press.modifiers.contains(.shift) else { return .ignored }; focus = "find"; return .handled }
            case .prefix, .suffix: field("FieldAddText", $rule.text)
            case .insert:
                field("FieldAddText", $rule.text)
                Stepper(model.t("InsertOffset", String(rule.position)), value: $rule.position, in: 0...4096)
            case .removeFirst, .removeLast, .keepFirst, .keepLast:
                Stepper(model.t("CharacterCount", String(rule.position)), value: $rule.position, in: 0...4096)
            case .setName: field("FieldNewName", $rule.text)
            case .numbering:
                LabeledContent(model.t("NumberStart")) { TextField("", value: $rule.start, format: .number).frame(maxWidth: 110).accessibilityLabel(model.t("NumberStart")) }
                Stepper(model.t("NumberDigits", String(rule.digits)), value: $rule.digits, in: 0...18)
                field("FieldSeparator", $rule.text)
            case .regex, .wildcard: field("FieldPattern", $rule.text); field("FieldReplaceWith", $rule.replacement)
            case .metadata:
                Picker(model.t("MetadataKey"), selection: $rule.text) { Text(model.t("ChooseField")).tag(""); ForEach(MetadataReader.fields, id: \.self) { Text(model.t($0)).tag($0) } }
                field("FieldJoin", $rule.replacement)
                field("MetadataFallback", Binding(get: { rule.metadataFallback ?? "" }, set: { rule.metadataFallback = $0.isEmpty ? nil : $0 }))
            case .uppercase, .lowercase, .titlecase:
                Picker(model.t("ActionCase"), selection: $rule.kind) {
                    ForEach([RuleKind.uppercase, .lowercase, .titlecase], id: \.self) { Text(model.t($0.rawValue)).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            default: EmptyView()
            }
            Expander(title: model.t("RuleOptions"), palette: palette) {
                VStack(alignment: .leading, spacing: Metrics.control) {
                    LabeledContent(model.t("RuleScope")) {
                        Picker(model.t("RuleScope"), selection: $rule.scope) { ForEach(RuleScope.allCases, id: \.self) { Text(model.t(scopeKey($0))).tag($0) } }.labelsHidden().fixedSize()
                    }
                    if rule.kind == .numbering {
                        LabeledContent(model.t("NumberStep")) { TextField("", value: $rule.step, format: .number).frame(maxWidth: 110).accessibilityLabel(model.t("NumberStep")) }
                        Text(model.t("ProNumbering")).font(.caption).foregroundStyle(palette.secondary)
                        Toggle(model.t("PerFolder"), isOn: $rule.perFolder)
                        Stepper(model.t("NumberRepeat", String(rule.repeatCount)), value: $rule.repeatCount, in: 1...10000)
                        Stepper(model.t("NumberRestart", String(rule.restartCount)), value: $rule.restartCount, in: 0...10000)
                    }
                    Text(model.t("RuleCondition")).font(.caption).foregroundStyle(palette.secondary)
                    TextField(model.t("ExtensionCondition"), text: $rule.conditionExtension)
                }
            }.font(.callout)
        }
    }
}
struct TextToolView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    @State private var input = ""
    @State private var truncated = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.t("TextToolHelp")).font(.caption)
                ToolSection(title: model.t("TextInput"), icon: "text.cursor", palette: palette) {
                TextEditor(text: $input).font(L10n.font(model.settings.language)).scrollContentBackground(.hidden).frame(minHeight: 110).accessibilityLabel(model.t("TextInput")).overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border))
                    .onChange(of: input) { _, new in let limited = NormalizationAnalysis.clipboard(new); if limited.1 { input = limited.0; truncated = true } }
                if truncated { Text(model.t("ClipboardTruncated")).foregroundStyle(palette.warning) }
                Button(model.t("PasteText")) {
                    guard let value = NSPasteboard.general.string(forType: .string) else { model.message = "NoClipboardText"; return }
                    let limited = NormalizationAnalysis.clipboard(value); input = limited.0; truncated = limited.1
                }
                }
                ForEach([NormalizationTarget.nfc, .nfd], id: \.self) { target in
                    ToolSection(title: model.t(target.rawValue), icon: "textformat", palette: palette) {
                    HStack { Spacer(); Button(model.t("CopyForm", target.rawValue)) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(target.apply(input), forType: .string) } }
                    Text(target.apply(input)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                DisclosureGroup(model.t("Advanced")) { UnicodeView(model: model, text: input, palette: palette).content }
            }
        }.onAppear { input = model.clipboard ?? ""; truncated = model.clipboardTruncated }
    }
}
