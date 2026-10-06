import SwiftUI
import AppKit
import NameFixCore
import NameFixRuntime

/// Task-first rule editor: choose one everyday action, fill in its value, preview.
/// Everything beyond that lives under Advanced rules and appears only on request.
struct RuleEditor: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    private var draft: RulePipeline {
        get { model.workbenchDraft }
        nonmutating set { model.workbenchDraft = newValue }
    }
    private var draftBinding: Binding<RulePipeline> { $model.workbenchDraft }
    @State private var advanced: Bool
    @State private var recipeName = ""
    @State private var sampleSteps: [RuleStep] = []
    @State private var sampleError: String?
    @State private var manualRows: [RawPath] = []
    @State private var sample = "photo  001.jpg"
    @State private var pairExpanded = false
    /// Embedded in a scrolling parent (narrow windows): lay out inline instead of nesting a scroll view.
    private let embedded: Bool
    init(model: AppModel, palette: Palette, startAdvanced: Bool = false, embedded: Bool = false) {
        self.model = model; self.palette = palette; self.embedded = embedded
        _advanced = State(initialValue: startAdvanced)
    }
    private struct BasicAction: Identifiable { let kind: RuleKind; let title: String; let example: String; let icon: String; var id: String { title } }
    private let basicActions = [
        BasicAction(kind: .replace, title: "RuleReplace", example: "ExampleReplace", icon: "arrow.left.arrow.right"),
        BasicAction(kind: .prefix, title: "RulePrefix", example: "ExamplePrefix", icon: "text.insert"),
        BasicAction(kind: .suffix, title: "RuleSuffix", example: "ExampleSuffix", icon: "text.append"),
        BasicAction(kind: .numbering, title: "RuleNumbering", example: "ExampleNumber", icon: "number"),
        BasicAction(kind: .spaces, title: "RuleSpaces", example: "ExampleSpaces", icon: "space"),
        BasicAction(kind: .uppercase, title: "ActionCase", example: "ExampleCase", icon: "textformat")
    ]
    private func add(_ kind: RuleKind) {
        var rule = RenameRule(kind)
        if kind == .numbering { rule.text = "_" }
        draft.rules.append(rule)
    }
    var body: some View {
        Group { if embedded { content } else { ScrollView { content } } }
        .disabled(model.busy || model.plan != nil).task(id: SampleRequest(target: draft.target, rules: draft.rules, name: sample)) {
            let snapshot = RulePipeline(target: draft.target, rules: draft.rules), name = String(sample.prefix(1024)), token = CancellationToken()
            let work = Task.detached { try snapshot.evaluate(name, access: .pro, cancelled: { token.cancelled }) }
            do {
                let steps = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { token.cancel(); work.cancel() })
                if !Task.isCancelled { sampleSteps = steps; sampleError = nil }
            } catch { if !Task.isCancelled { sampleSteps = []; sampleError = (error as? RuleFailure)?.rawValue ?? "RuleInvalid" } }
        }.onAppear { pairExpanded = !(draft.pairExtensions ?? []).isEmpty; manualRows = model.entries.map(\.path); if let name = model.entries.first(where: { !$0.isDirectory && !$0.status.isError })?.name { sample = name } }
    }
    private var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                if draft.rules.isEmpty { chooser } else { steps }
                DisclosureGroup(isExpanded: $advanced) { advancedContent.padding(.top, 10) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.t("AdvancedRules")).fontWeight(.medium)
                        if !advanced { Text(model.t("AdvancedHint")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true) }
                    }
                }.accessibilityIdentifier("advancedRules")
                if let message = model.message { Text(model.t(message)).foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true) }
            }.textFieldStyle(.roundedBorder).frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Step 1 — what do you want to do?

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t("ChooseAction")).font(L10n.font(model.settings.language, size: 17, weight: .semibold)).accessibilityAddTraits(.isHeader).padding(.bottom, 2)
            ForEach(basicActions) { action in
                Button { add(action.kind) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: action.icon).frame(width: 22).foregroundStyle(palette.accent).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.t(action.title))
                            Text(model.t(action.example)).font(.caption).foregroundStyle(palette.secondary)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(palette.secondary).accessibilityHidden(true)
                    }.padding(.vertical, 8).padding(.horizontal, 12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("action-" + action.kind.rawValue)
            }
        }
    }

    // MARK: Step 2 — fill in the value, then preview

    private var steps: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(draft.rules.enumerated()), id: \.element.id) { index, rule in
                if index < draft.rules.count {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Toggle(isOn: $model.workbenchDraft.rules[index].enabled) { Text(model.t(title(rule.kind))).fontWeight(.medium) }
                            Spacer(minLength: 4)
                            if draft.rules.count > 1 {
                                Button { if index > 0 { draft.rules.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up") }.disabled(index == 0).accessibilityLabel(model.t("MoveUp")).help(model.t("MoveUp"))
                                Button { if index + 1 < draft.rules.count { draft.rules.swapAt(index, index + 1) } } label: { Image(systemName: "arrow.down") }.disabled(index + 1 == draft.rules.count).accessibilityLabel(model.t("MoveDown")).help(model.t("MoveDown"))
                            }
                            Button { draft.rules.remove(at: index) } label: { Image(systemName: "minus.circle") }.accessibilityLabel(model.t("RemoveRule")).help(model.t("RemoveRule"))
                        }.buttonStyle(.borderless)
                        RuleFields(model: model, rule: $model.workbenchDraft.rules[index], palette: palette)
                    }.padding(12).background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(model.t("RulePreviewSection")).font(.caption).foregroundStyle(palette.secondary)
                TextField(model.t("SampleName"), text: $sample).accessibilityLabel(model.t("SampleName"))
                sampleResult
            }
            ViewThatFits(in: .horizontal) {
                HStack { addMenu; Spacer(minLength: 8); resetButton; updateButton }
                VStack(alignment: .leading, spacing: 8) { HStack { addMenu; resetButton }; updateButton }
            }
        }
    }
    private func title(_ kind: RuleKind) -> String { [.uppercase, .lowercase, .titlecase].contains(kind) ? "ActionCase" : kind.rawValue }
    @ViewBuilder private var sampleResult: some View {
        if let sampleError { Text(model.t(sampleError)).foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true) }
        else if let last = sampleSteps.last {
            Label(last.after, systemImage: "arrow.right").textSelection(.enabled).foregroundStyle(palette.preview)
                .accessibilityLabel(model.t("SampleResult") + " " + last.after)
        }
    }
    private var addMenu: some View {
        Menu {
            ForEach(basicActions) { action in Button(model.t(action.title)) { add(action.kind) } }
            Divider()
            Menu(model.t("OtherRules")) {
                ForEach(RuleKind.allCases.filter { kind in !basicActions.contains { $0.kind == kind } && ![.lowercase, .titlecase].contains(kind) }, id: \.self) { kind in Button(model.t(kind.rawValue)) { add(kind) } }
            }
        } label: { Label(model.t("AddAction"), systemImage: "plus") }.menuStyle(.borderlessButton).fixedSize().accessibilityIdentifier("addAction")
    }
    private var resetButton: some View { Button(model.t("ResetRules")) { draft = RulePipeline() }.buttonStyle(.borderless) }
    private var updateButton: some View {
        Button(model.t("UpdateFilePreview")) { model.usePipeline(draft) }.buttonStyle(.borderedProminent)
            .disabled(model.busy || model.plan != nil || !model.hasUnappliedRules).accessibilityIdentifier("updatePreview")
    }

    // MARK: Advanced — only when opened

    @ViewBuilder private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if draft.rules.isEmpty { addMenu }
            VStack(alignment: .leading, spacing: 4) {
                Text(model.t("OutputForm")).font(.caption).foregroundStyle(palette.secondary)
                Picker(model.t("OutputForm"), selection: $model.workbenchDraft.target) {
                    ForEach(NormalizationTarget.allCases, id: \.self) { target in Text(model.t(target.rawValue)).tag(target) }
                }.labelsHidden()
            }
            if draft.rules.contains(where: { $0.kind == .numbering }) || draft.order == .manual {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.t("SequenceOrder")).font(.caption).foregroundStyle(palette.secondary)
                    Picker(model.t("SequenceOrder"), selection: Binding(get: { draft.order ?? .path }, set: { draft.order = $0 })) {
                        ForEach(SequenceOrder.allCases, id: \.self) { Text(model.t($0.rawValue)).tag($0) }
                    }.labelsHidden()
                    if draft.order == .manual {
                        Text(model.t("ManualOrderHelp")).font(.caption)
                        List {
                            ForEach(manualRows, id: \.self) { row in
                                HStack {
                                    Text(row.display).lineLimit(1).help(row.display)
                                    Spacer()
                                    Button { moveManual(row, delta: -1) } label: { Image(systemName: "arrow.up") }.accessibilityLabel(model.t("MoveUp")).disabled(manualRows.first == row)
                                    Button { moveManual(row, delta: 1) } label: { Image(systemName: "arrow.down") }.accessibilityLabel(model.t("MoveDown")).disabled(manualRows.last == row)
                                }
                            }
                            .onMove { source, destination in manualRows.move(fromOffsets: source, toOffset: destination); draft.manualPaths = manualRows.map(\.bytes) }
                        }.frame(height: 160)
                    }
                }
            }
            if draft.rules.contains(where: { $0.kind == .metadata }) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.t("MetadataHelp")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    TextField(model.t("DateFormat"), text: Binding(get: { draft.dateFormat ?? "yyyy-MM-dd" }, set: { draft.dateFormat = $0 }))
                    TextField(model.t("TimeZone"), text: Binding(get: { draft.timeZone ?? "UTC" }, set: { draft.timeZone = $0 }))
                }
            }
            DisclosureGroup(isExpanded: $pairExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(model.t("PairExtensions"), text: Binding(get: { (draft.pairExtensions ?? []).joined(separator: ",") }, set: { draft.pairExtensions = $0.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                    Text(model.t("PairHelp")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                }.padding(.top, 6)
            } label: { Text(model.t("PairSection")) }
            MappingView(model: model, pipeline: draftBinding)
            DisclosureGroup(model.t("RecipeSection")) { presets.padding(.top, 6) }
        }
    }
    private var presets: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(model.t("BasicExample")) {
                var prefix = RenameRule(.prefix); prefix.text = "Project_"
                var number = RenameRule(.numbering); number.text = "_"
                draft = RulePipeline(rules: [RenameRule(.spaces), prefix, number])
            }
            Menu(model.t("ProExamples")) {
                Button(model.t("PhotoExample")) {
                    var name = RenameRule(.setName); name.text = ""
                    var date = RenameRule(.metadata); date.text = "photo.date"
                    var number = RenameRule(.numbering); number.text = "_"
                    draft = RulePipeline(rules: [name, date, number])
                }
                Button(model.t("RegexExample")) {
                    var rule = RenameRule(.regex); rule.text = "(?i)^(?:IMG|DSC)[_-]?"; rule.replacement = "Photo_"
                    draft = RulePipeline(rules: [rule])
                }
            }.fixedSize()
            Divider()
            HStack {
                TextField(model.t("RecipeName"), text: $recipeName)
                Button(model.t("SaveRecipe")) { model.saveRecipe(name: recipeName, pipeline: draft) }
            }
            Button(model.t("ImportRecipe")) { importRecipe() }
            ForEach(model.recipes.recipes) { recipe in
                HStack {
                    TextField(model.t("RecipeName"), text: Binding(get: { recipe.name }, set: { model.editRecipe(recipe.id, name: $0) })).lineLimit(2)
                    Button(model.t("LoadRecipe")) { if model.productAccess == .pro { draft = recipe.pipeline } else { model.message = "ProRequired" } }
                    Menu(model.t("RecipeActions")) {
                        Button(model.t("Export")) { export(recipe) }
                        Button(model.t("Duplicate")) { model.editRecipe(recipe.id, duplicate: true) }
                        Button(model.t("Remove")) { model.editRecipe(recipe.id, remove: true) }
                    }.fixedSize()
                }
            }
        }
    }
    private struct SampleRequest: Equatable {
        var target: NormalizationTarget; var rules: [RenameRule]; var name: String
        static func == (a: Self, b: Self) -> Bool { a.target == b.target && a.rules == b.rules && Data(a.name.utf8) == Data(b.name.utf8) }
    }
    private func moveManual(_ row: RawPath, delta: Int) {
        guard let index = manualRows.firstIndex(of: row), manualRows.indices.contains(index + delta) else { return }
        manualRows.swapAt(index, index + delta); draft.manualPaths = manualRows.map(\.bytes)
    }
    private func importRecipe() {
        guard model.productAccess == .pro else { model.message = "ProRequired"; return }
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
        Task { do { try await Task.detached { try JSONEncoder().encode(recipe).write(to: url, options: .atomic) }.value } catch { model.message = "SettingsSaveFailed" } }
    }
}

/// The value fields of one step. Only what the action needs is visible; scope,
/// conditions and advanced numbering sit under More options.
struct RuleFields: View {
    @ObservedObject var model: AppModel
    @Binding var rule: RenameRule
    let palette: Palette
    // RuleScope.name shares its raw value with the "Current name" column title.
    private func scopeKey(_ scope: RuleScope) -> String { scope == .name ? "ScopeFullName" : scope.rawValue }
    private func field(_ key: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(model.t(key)).font(.caption).foregroundStyle(palette.secondary)
            TextField("", text: text).accessibilityLabel(model.t(key))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch rule.kind {
            case .replace: field("FieldFind", $rule.text); field("FieldReplaceWith", $rule.replacement)
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
            DisclosureGroup(model.t("RuleOptions")) {
                VStack(alignment: .leading, spacing: 8) {
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
                }.padding(.top, 6)
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
