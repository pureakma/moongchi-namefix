import SwiftUI
import AppKit
import NameFixCore
import NameFixRuntime

struct RuleEditor: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    private var draft: RulePipeline {
        get { model.workbenchDraft }
        nonmutating set { model.workbenchDraft = newValue }
    }
    private var draftBinding: Binding<RulePipeline> { $model.workbenchDraft }
    @State private var kind: RuleKind = .replace
    @State private var recipeName = ""
    @State private var sampleSteps: [RuleStep] = []
    @State private var sampleError: String?
    @State private var manualRows: [RawPath] = []
    @State private var sample = "photo  001.jpg"
    @State private var pairExpanded = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("BatchExamples")).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                Text(model.t("FreeRulesHelp")).font(.caption).foregroundStyle(palette.secondary)
                ToolSection(title: model.t("RuleSetup"), icon: "slider.horizontal.3", palette: palette) {
                DisclosureGroup(model.t("CharacterOptions")) {
                Text(model.t("OutputForm")).font(.caption).foregroundStyle(palette.secondary)
                Picker(model.t("OutputForm"), selection: $model.workbenchDraft.target) {
                    ForEach(NormalizationTarget.allCases, id: \.self) { target in Text(model.t(target.rawValue)).tag(target) }
                }.labelsHidden()
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.t("AddRule")).font(.caption).foregroundStyle(palette.secondary)
                    Picker(model.t("AddRule"), selection: $kind) {
                        ForEach(RuleKind.allCases, id: \.self) { k in Text(model.t(k.rawValue) + (k.pro ? " · Pro" : "")).tag(k) }
                    }.labelsHidden()
                    Button(model.t("AddRule")) { draft.rules.append(RenameRule(kind)) }
                }
                ForEach(Array(draft.rules.enumerated()), id: \.element.id) { index, rule in
                    if index < draft.rules.count {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Toggle(model.t(rule.kind.rawValue), isOn: $model.workbenchDraft.rules[index].enabled)
                                if rule.requiresPro { Text("Pro").font(.caption).foregroundStyle(palette.secondary) }
                                Spacer()
                                Button { if index > 0 { draft.rules.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up") }.disabled(index == 0).accessibilityLabel(model.t("MoveUp"))
                                Button { if index + 1 < draft.rules.count { draft.rules.swapAt(index, index + 1) } } label: { Image(systemName: "arrow.down") }.disabled(index + 1 == draft.rules.count).accessibilityLabel(model.t("MoveDown"))
                                Button { draft.rules.remove(at: index) } label: { Image(systemName: "minus.circle") }.accessibilityLabel(model.t("RemoveRule"))
                            }
                            RuleFields(model: model, rule: $model.workbenchDraft.rules[index])
                        }.padding(12).background(palette.surface, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                if draft.rules.isEmpty { Text(model.t("AddRulePrompt")).foregroundStyle(palette.secondary) }
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
                DisclosureGroup(model.t("PairSection"), isExpanded: $pairExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(model.t("PairExtensions"), text: Binding(get: { (draft.pairExtensions ?? []).joined(separator: ",") }, set: { draft.pairExtensions = $0.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }))
                        Text(model.t("PairHelp")).font(.caption).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                MappingView(model: model, pipeline: draftBinding)
                if draft.rules.contains(where: { $0.kind == .metadata }) {
                    Text(model.t("MetadataHelp")).font(.caption)
                    TextField(model.t("DateFormat"), text: Binding(get: { draft.dateFormat ?? "yyyy-MM-dd" }, set: { draft.dateFormat = $0 }))
                    TextField(model.t("TimeZone"), text: Binding(get: { draft.timeZone ?? "UTC" }, set: { draft.timeZone = $0 }))
                }
                }
                ToolSection(title: model.t("RulePreviewSection"), icon: "eye", palette: palette) {
                TextField(model.t("SampleName"), text: $sample)
                samplePreview
                }
                ToolSection(title: model.t("RecipeSection"), icon: "square.stack", palette: palette) {
                VStack(alignment: .leading, spacing: 8) {
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
                    }
                    Button(model.t("ResetRules")) { draft = RulePipeline() }
                }
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
                        }
                    }
                }
                }
                if let message = model.message { Text(model.t(message)).foregroundStyle(palette.warning).fixedSize(horizontal: false, vertical: true) }
                Button(model.t("UpdateFilePreview")) { model.usePipeline(draft) }.buttonStyle(.borderedProminent).disabled(model.busy || model.plan != nil)
                Text(model.t("RulesPreviewOnly")).font(.caption).foregroundStyle(palette.secondary)
            }.textFieldStyle(.roundedBorder).frame(maxWidth: .infinity, alignment: .leading)
        }.disabled(model.busy || model.plan != nil).task(id: SampleRequest(target: draft.target, rules: draft.rules, name: sample)) {
            let snapshot = RulePipeline(target: draft.target, rules: draft.rules), name = String(sample.prefix(1024)), token = CancellationToken()
            let work = Task.detached { try snapshot.evaluate(name, access: .pro, cancelled: { token.cancelled }) }
            do {
                let steps = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { token.cancel(); work.cancel() })
                if !Task.isCancelled { sampleSteps = steps; sampleError = nil }
            } catch { if !Task.isCancelled { sampleSteps = []; sampleError = (error as? RuleFailure)?.rawValue ?? "RuleInvalid" } }
        }.onAppear { pairExpanded = !(draft.pairExtensions ?? []).isEmpty; manualRows = model.entries.map(\.path); if let name = model.entries.first(where: { !$0.isDirectory && !$0.status.isError })?.name { sample = name } }
    }
    @ViewBuilder private var samplePreview: some View {
        if let sampleError { Text(model.t(sampleError)).foregroundStyle(palette.warning) }
        ForEach(Array(sampleSteps.enumerated()), id: \.offset) { _, step in
            VStack(alignment: .leading) {
                Text(model.t(step.title)).font(.caption).foregroundStyle(palette.secondary)
                Text(step.before).font(.caption).textSelection(.enabled).foregroundStyle(palette.secondary)
                Label(step.after, systemImage: "arrow.right").textSelection(.enabled).foregroundStyle(palette.preview)
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
struct RuleFields: View {
    @ObservedObject var model: AppModel
    @Binding var rule: RenameRule
    // RuleScope.name shares its raw value with the "Current name" column title.
    private func scopeKey(_ scope: RuleScope) -> String { scope == .name ? "ScopeFullName" : scope.rawValue }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.t("RuleScope")).font(.caption)
            Picker(model.t("RuleScope"), selection: $rule.scope) { ForEach(RuleScope.allCases, id: \.self) { Text(model.t(scopeKey($0))).tag($0) } }.labelsHidden().help(model.t(scopeKey(rule.scope)))
            if rule.kind == .metadata { Picker(model.t("MetadataKey"), selection: $rule.text) { Text(model.t("ChooseField")).tag(""); ForEach(MetadataReader.fields, id: \.self) { Text(model.t($0)).tag($0) } } }
            if [.replace, .prefix, .suffix, .insert, .setName, .numbering, .regex, .wildcard].contains(rule.kind) {
                TextField(model.t(rule.kind == .metadata ? "MetadataKey" : "RuleText"), text: $rule.text)
            }
            if rule.kind == .metadata { TextField(model.t("MetadataFallback"), text: Binding(get: { rule.metadataFallback ?? "" }, set: { rule.metadataFallback = $0.isEmpty ? nil : $0 })) }
            if [.replace, .regex, .wildcard, .metadata].contains(rule.kind) { TextField(model.t("ReplacementText"), text: $rule.replacement) }
            if [.insert, .removeFirst, .removeLast, .keepFirst, .keepLast].contains(rule.kind) { Stepper(model.t(rule.kind == .insert ? "InsertOffset" : "CharacterCount", String(rule.position)), value: $rule.position, in: 0...4096) }
            if rule.kind == .numbering {
                LabeledContent(model.t("NumberStart")) { TextField("", value: $rule.start, format: .number).frame(maxWidth: 120) }
                LabeledContent(model.t("NumberStep")) { TextField("", value: $rule.step, format: .number).frame(maxWidth: 120) }
                Stepper(model.t("NumberDigits", String(rule.digits)), value: $rule.digits, in: 0...18)
                DisclosureGroup(model.t("ProNumbering")) {
                    Toggle(model.t("PerFolder"), isOn: $rule.perFolder)
                    Stepper(model.t("NumberRepeat", String(rule.repeatCount)), value: $rule.repeatCount, in: 1...10000)
                    Stepper(model.t("NumberRestart", String(rule.restartCount)), value: $rule.restartCount, in: 0...10000)
                }
            }
            DisclosureGroup(model.t("RuleCondition")) { TextField(model.t("ExtensionCondition"), text: $rule.conditionExtension) }
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
