import AppKit
import NameFixCore

@MainActor enum ResultExport {
    static func save(model: AppModel, raw: Bool) {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = raw ? "NameFix-Raw.csv" : "NameFix-Report.csv"
        panel.message = model.t(raw ? "RawExportHelp" : "SafeExportHelp")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let entries = model.entries
        Task {
            do {
                try await Task.detached {
                    let rows = [["source", "destination", "status", "reason", "source_bytes_base64", "destination_bytes_base64"]] + entries.map { [$0.path.display, $0.preview, $0.status.rawValue, $0.reason, $0.path.bytes.base64EncodedString(), $0.proposed.base64EncodedString()] }
                    try DelimitedText.encode(rows, spreadsheetSafe: !raw).write(to: url, options: .atomic)
                }.value
            } catch { model.message = "ExportFailed" }
        }
    }
}
