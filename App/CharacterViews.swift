import SwiftUI
import NameFixCore

struct CharacterChips: View {
    let tokens: [CharacterToken]
    let palette: Palette
    var limit: Int? = nil
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(tokens.prefix(limit ?? tokens.count).enumerated()), id: \.offset) { _, token in
                Text(token.glyph).font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(palette.control, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border, lineWidth: 1))
                    .help(token.code).accessibilityLabel(token.glyph + " " + token.code)
            }
            if let limit, tokens.count > limit { Text("…") }
        }.fixedSize(horizontal: true, vertical: false)
    }
}

struct NameCompositionCell: View {
    let entry: FileEntry
    let preview: Bool
    let compact: Bool
    let palette: Palette
    let language: String
    var wrapName = false
    var body: some View {
        let changes = CharacterPresentation.comparison(original: entry.name, proposed: entry.preview)
        VStack(alignment: .leading, spacing: 4) {
            Text(preview ? entry.preview : entry.name).lineLimit(wrapName ? nil : 1)
                .help(preview ? entry.preview : entry.path.display)
            if entry.groupID != nil, !preview { Label(L10n.text("PairMember", language: language), systemImage: "link").font(.caption).foregroundStyle(palette.secondary) }
            if let first = changes.first {
                HStack(spacing: 4) {
                    CharacterChips(tokens: preview ? first.after : first.before, palette: palette, limit: 3)
                    if changes.count > 1 {
                        Text("+\(changes.count - 1)").font(.system(size: 10)).foregroundStyle(palette.secondary)
                            .help(L10n.text("MoreCharacterChanges", language: language, [String(changes.count - 1)]))
                    }
                }
                .help(L10n.text("CompositionLegend", language: language))
            }
        }.padding(.vertical, compact ? 3 : 7)
            .foregroundStyle(preview ? (entry.status.fixable ? palette.preview : palette.secondary) : palette.text)
    }
}

struct CharacterComparison: View {
    @ObservedObject var model: AppModel
    let text: String
    let palette: Palette
    var body: some View {
        let presentation = CharacterPresentation(text)
        VStack(alignment: .leading, spacing: 12) {
            Text(model.t("CompositionTitle")).font(.headline)
            Text(model.t("CompositionLegend")).font(.caption).foregroundStyle(palette.secondary)
            Text(model.t("CompositionScalarLegend")).font(.caption).foregroundStyle(palette.secondary)
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(presentation.units) { unit in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(model.t("CharacterPosition", model.n(unit.id + 1)))
                            Text(model.t(unit.changed ? "CompositionChanges" : "CompositionUnchanged")).foregroundStyle(unit.changed ? palette.preview : palette.secondary)
                        }.font(.caption)
                        HStack(alignment: .top, spacing: 12) {
                            tokens(unit.before, title: model.t("OriginalComposition"))
                            Image(systemName: "arrow.right").foregroundStyle(palette.secondary).padding(.top, 18)
                            tokens(unit.after, title: model.t("NFCComposition"))
                        }
                        Divider()
                    }
                }
            }
        }
    }
    private func tokens(_ values: [CharacterToken], title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(palette.secondary)
            // Adaptive grid keeps even unusually long combining sequences readable.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), alignment: .leading)], alignment: .leading, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, token in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(token.glyph).font(.system(size: 15))
                        Text(token.code).font(.system(size: 10, design: .monospaced)).foregroundStyle(palette.secondary)
                    }.padding(5).frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.control, in: RoundedRectangle(cornerRadius: 5))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
