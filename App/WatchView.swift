import SwiftUI
import AppKit
import NameFixCore
import NameFixRuntime

struct WatchView: View {
    @ObservedObject var model: AppModel
    let palette: Palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(model.t("WatchToolDetail")).font(.headline)
                Text(model.t("WatchHelp")).foregroundStyle(palette.secondary)
                Button(model.t("WatchAdd")) { add() }.disabled(model.busy || model.plan != nil)
                ForEach(model.watches.folders) { folder in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(folder.path).textSelection(.enabled).lineLimit(3)
                        Text(model.t(model.watchErrors[folder.id] ?? (model.watchPending.contains(folder.id) ? "WatchPending" : folder.enabled ? "WatchActive" : "WatchPaused"))).font(.caption)
                        ViewThatFits(in: .horizontal) {
                            HStack { actions(folder) }
                            VStack(alignment: .leading) { actions(folder) }
                        }.buttonStyle(.bordered)
                    }.padding(12).background(palette.surface, in: RoundedRectangle(cornerRadius: 10))
                }
                if model.watches.folders.isEmpty { Text(model.t("WatchEmpty")) }
                if let message = model.message { Text(model.t(message)).foregroundStyle(palette.warning) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    @ViewBuilder private func actions(_ folder: WatchedFolder) -> some View {
        Button(model.t(folder.enabled ? "WatchPause" : "WatchResume")) { model.toggleWatch(folder.id) }
        Button(model.t("WatchReview")) { model.reviewWatch(folder.id) }.disabled(model.busy || model.plan != nil)
        Button(model.t("WatchUseRules")) { model.updateWatch(folder.id) }
        Button(model.t("Remove")) { model.removeWatch(folder.id) }
    }
    private func add() {
        guard model.productAccess == .pro else { model.message = "ProRequired"; return }
        let panel = NSOpenPanel(); panel.canChooseFiles = false; panel.canChooseDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.addWatch(url)
    }
}
