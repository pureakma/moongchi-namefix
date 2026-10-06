import SwiftUI
import NameFixCore

/// Shared hierarchy: a quiet section heading above a bounded group of native controls.
struct ToolSection<Content: View>: View {
    let title: String
    let icon: String
    let palette: Palette
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(palette.secondary)
                .accessibilityAddTraits(.isHeader).padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 14, content: content)
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.border.opacity(0.7), lineWidth: 0.5))
        }
    }
}

struct CharacterFormatView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var guidanceOnly = false
    private func explanation(_ target: NormalizationTarget) -> String {
        target == .nfc ? "ComposeHelp" : target == .nfd ? "DecomposeHelp" : "KeepFormHelp"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.t("FormatIntro")).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                ForEach(NormalizationTarget.allCases, id: \.self) { target in
                    ToolSection(title: model.t(target.rawValue), icon: target == .nfc ? "textformat.abc" : "textformat", palette: palette) {
                        if !guidanceOnly {
                            Button {
                                var pipeline = model.pipeline; pipeline.target = target; model.usePipeline(pipeline)
                            } label: {
                                HStack(alignment: .top) {
                                    Text(model.t(target.rawValue)).frame(maxWidth: .infinity, alignment: .leading)
                                    Image(systemName: model.pipeline.target == target ? "checkmark.circle.fill" : "circle")
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).foregroundStyle(palette.accent)
                                .accessibilityAddTraits(model.pipeline.target == target ? .isSelected : [])
                                .disabled(model.busy || model.plan != nil)
                        }
                        Text(model.t(explanation(target))).font(.callout).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(model.t("RulesPreviewOnly")).font(.caption).foregroundStyle(palette.secondary)
            }.padding(2)
        }
    }
}

struct AdditionalToolsView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.t("ExportToolHelp")).foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
                ToolSection(title: model.t("Export"), icon: "square.and.arrow.up", palette: palette) {
                    Button { ResultExport.save(model: model, raw: false) } label: { Label(model.t("ExportReport"), systemImage: "tablecells") }
                    Divider()
                    Button { ResultExport.save(model: model, raw: true) } label: { Label(model.t("ExportRaw"), systemImage: "doc.text") }
                }.disabled(model.entries.isEmpty)
            }.padding(2)
        }.disabled(model.busy || model.plan != nil)
    }
}
