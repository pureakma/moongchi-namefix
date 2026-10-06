import SwiftUI
import AppKit
import NameFixCore

struct MappingView: View {
    @ObservedObject var model: AppModel
    @Binding var pipeline: RulePipeline
    let palette: Palette
    @State private var rows: [[String]] = []
    @State private var sourceColumn = 0
    @State private var destinationColumn = 1
    @State private var header = true
    @State private var tabSeparated = false
    @State private var working = false
    @State private var problem: String?
    @State private var loadTask: Task<Void, Never>?
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.t("MappingHelp")).font(.caption)
                Toggle(model.t("TabSeparated"), isOn: $tabSeparated).disabled(working || !rows.isEmpty)
                Button(model.t("ImportCSV")) { pick() }.disabled(working)
                if !rows.isEmpty {
                    Toggle(model.t("HeaderRow"), isOn: $header).disabled(working)
                    Picker(model.t("SourceColumn"), selection: $sourceColumn) { ForEach(0..<(rows.first?.count ?? 0), id: \.self) { Text(String($0 + 1)).tag($0) } }
                    Picker(model.t("DestinationColumn"), selection: $destinationColumn) { ForEach(0..<(rows.first?.count ?? 0), id: \.self) { Text(String($0 + 1)).tag($0) } }
                    ForEach(Array(rows.prefix(5).enumerated()), id: \.offset) { _, row in Text(row.joined(separator: " → ")).font(.caption).textSelection(.enabled) }
                    Button(model.t("UseMapping")) { apply() }.disabled(working)
                    Button(model.t("ClearMapping")) { rows = []; pipeline.mapping = nil; problem = nil }
                }
                if let mapping = pipeline.mapping { Text(model.t("MappingCount", String(mapping.rows.count))); if rows.isEmpty { Button(model.t("ClearMapping")) { pipeline.mapping = nil } } }
                if let problem { Text(model.t(problem)).foregroundStyle(.red) }
            }
        } label: { HStack(spacing: 6) { Text(model.t("CSVMapping")); ProBadge(palette: palette) } }.onDisappear { loadTask?.cancel() }
    }
    private func describe(_ error: Error) -> String {
        if let error = error as? DelimitedTextError { return model.t("MappingRowError", String(error.row), model.t(error.reason.rawValue)) }
        if error is CancellationError { return "Cancelled" }
        return (error as? RuleFailure)?.rawValue ?? "MappingReadFailed"
    }
    private func pick() {
        guard model.productAccess == .pro else { problem = "ProRequired"; return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        working = true; problem = nil; let tab = tabSeparated
        loadTask?.cancel()
        loadTask = Task {
            do {
                let work = Task.detached {
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 32_000_000 else { throw RuleFailure.budget }
                    return try DelimitedText.parse(Data(contentsOf: url), separator: tab ? "\t" : ",", cancelled: { Task.isCancelled })
                }
                rows = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
                sourceColumn = 0; destinationColumn = (rows.first?.count ?? 0) > 1 ? 1 : 0
            } catch { problem = describe(error) }
            working = false
        }
    }
    private func apply() {
        let input = rows, skipHeader = header, source = sourceColumn, destination = destinationColumn
        working = true
        loadTask?.cancel()
        loadTask = Task {
            do {
                let work = Task.detached {
                    let sourceRows = skipHeader ? Array(input.dropFirst()) : input
                    guard !sourceRows.isEmpty, source != destination else { throw RuleFailure.invalid }
                    let mapping = try NameMapping(rows: sourceRows.enumerated().map { index, row in
                        try Task.checkCancellation()
                        guard row.indices.contains(source), row.indices.contains(destination) else { throw DelimitedTextError(row: index + (skipHeader ? 2 : 1), reason: .invalid) }
                        return NameMapping.Row(source: row[source], destination: row[destination])
                    })
                    _ = try mapping.index(); return mapping
                }
                let mapping = try await withTaskCancellationHandler(operation: { try await work.value }, onCancel: { work.cancel() })
                try Task.checkCancellation()
                pipeline.mapping = mapping; problem = nil
            } catch { problem = describe(error) }
            working = false
        }
    }
}
