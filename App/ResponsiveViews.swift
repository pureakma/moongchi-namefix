import SwiftUI
import AppKit
import NameFixCore

struct FlexibleSheet<Content: View>: View {
    var preferred: CGSize
    var available: CGSize
    let content: Content
    init(preferred: CGSize, available: CGSize, @ViewBuilder content: () -> Content) {
        self.preferred = preferred; self.available = available; self.content = content()
    }
    var body: some View {
        let size = WindowLayout.sheet(preferred: preferred, available: available)
        ScrollView(.horizontal) {
            content.frame(width: max(280, size.width), height: size.height)
        }.frame(width: size.width, height: size.height)
    }
}

struct CompactResultRow: View {
    @ObservedObject var model: AppModel
    @FocusState private var keyboardFocused: Bool
    let entry: FileEntry
    let palette: Palette
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle(model.t("SelectedCaption"), isOn: Binding(get: { model.selected.contains(entry.id) }, set: { _ in model.focused = entry.id; model.toggle(entry) }))
                .labelsHidden().disabled(!entry.status.fixable || model.busy)
                .accessibilityLabel(model.t("SelectedCaption") + " " + entry.name)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: entry.isDirectory ? "folder" : "doc").foregroundStyle(palette.secondary).frame(width: 16).accessibilityLabel(model.t(entry.isDirectory ? "Directory" : "File"))
                    name(preview: false)
                }
                if entry.status.fixable || entry.status == .conflict {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.turn.down.right").foregroundStyle(palette.secondary).frame(width: 16).accessibilityLabel(model.t("Preview"))
                        name(preview: true)
                    }
                }
                Text(model.t(CharacterPresentation.statusKey(entry.status, name: entry.name, reason: entry.reason))).font(.caption)
                    .foregroundStyle(entry.status.isError || entry.status == .conflict ? palette.warning : palette.secondary)
                    .fixedSize(horizontal: false, vertical: true).help(model.t(entry.reason))
            }
            Spacer(minLength: 0)
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(model.focused == entry.id ? palette.accent : palette.border, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { model.focused = entry.id; model.sheet = "inspector" }
            .onTapGesture { model.focused = entry.id; keyboardFocused = true }
            .contextMenu {
                Button(model.t("InspectShort")) { model.focused = entry.id; model.sheet = "inspector" }
                Button(model.t("CopyPath")) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.path.display, forType: .string) }
            }
            .focusable().focused($keyboardFocused)
            .onChange(of: keyboardFocused) { _, focused in if focused { model.focused = entry.id } }
            .onKeyPress(keys: [.space]) { _ in
                guard entry.status.fixable, !model.busy else { return .ignored }
                model.toggle(entry); return .handled
            }
            .onKeyPress(keys: [.return]) { _ in model.focused = entry.id; model.sheet = "inspector"; return .handled }
            .onKeyPress(keys: ["a"]) { event in
                guard event.modifiers.contains(.command) else { return .ignored }
                model.select("visible"); return .handled
            }
            .onKeyPress(keys: ["z"]) { event in
                guard event.modifiers.contains(.command), let history = model.history.first(where: { $0.mode == "rename" && $0.succeeded > 0 }) else { return .ignored }
                model.prepare(mode: "undo", historyID: history.id); return .handled
            }
            .accessibilityIdentifier("compactResultRow")
    }
    private func name(preview: Bool) -> some View {
        NameCompositionCell(entry: entry, preview: preview, compact: true, palette: palette, language: model.settings.language, wrapName: true)
    }
}
