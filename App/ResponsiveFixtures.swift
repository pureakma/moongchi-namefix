import AppKit
import SwiftUI
import NameFixCore
import NameFixRuntime
import NameFixApplication

@MainActor enum ResponsiveFixtures {
    static func run(output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        var count = 0
        func snapshot<V: View>(_ view: V, name: String, size: CGSize, dark: Bool, bottom: Bool = false) throws {
            if CommandLine.arguments.contains("--history-only"), !name.contains("-history-") { return }
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua); NSApp.appearance = appearance
            let rect = CGRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = appearance
            let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height)); host.sizingOptions = []
            window.contentView = host; host.frame = rect
            host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            if bottom {
                // Scroll only this unshown fixture's view, never a user window.
                func scrolls(_ view: NSView) -> [NSScrollView] { ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrolls) }
                if let scroll = scrolls(host).filter({ $0.hasVerticalScroller && ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height + 100 }).max(by: { ($0.documentView?.bounds.height ?? 0) < ($1.documentView?.bounds.height ?? 0) }), let document = scroll.documentView {
                    // Lazy rows can expand the document after the first scroll.
                    // Settle only this hidden fixture before capturing its end.
                    for _ in 0..<4 {
                        scroll.contentView.scroll(to: CGPoint(x: 0, y: max(0, document.bounds.height - scroll.contentView.bounds.height)))
                        scroll.reflectScrolledClipView(scroll.contentView)
                        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                        host.layoutSubtreeIfNeeded()
                    }
                }
            }
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "ResponsiveRender", code: 1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let bytes = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "ResponsiveRender", code: 2) }
            try bytes.write(to: output.appendingPathComponent(name + ".png")); count += 1; window.close()
        }
        if CommandLine.arguments.contains("--tools-only") {
            for language in ["ko-KR", "en-US", "ja-JP"] {
                let model = AppModel(dataRoot: output.appendingPathComponent("isolated-" + language))
                model.settings.language = language
                for theme in ["olive", "dark", "light", "system"] {
                    model.settings.theme = theme
                    for sheet in ["settings", "format", "formatHelp", "rules", "clipboard", "tools"] {
                        model.sheet = sheet
                        for size in [CGSize(width: 680, height: 650), CGSize(width: 360, height: 500)] {
                            try snapshot(SheetRouter(model: model, availableSize: size), name: "\(language)-\(theme)-\(sheet)-\(Int(size.width))", size: size, dark: theme == "dark")
                        }
                    }
                }
            }
            print("Rendered \(count) tool layouts")
            return
        }
        let sizes = [CGSize(width: 320, height: 600), CGSize(width: 600, height: 720), CGSize(width: 899, height: 500), CGSize(width: 900, height: 640), CGSize(width: 1180, height: 780), CGSize(width: 1600, height: 1000), CGSize(width: 1180, height: 320), CGSize(width: 240, height: 200)]
        for (languageIndex, language) in ["ko-KR", "en-US", "ja-JP"].enumerated() {
            let model = AppModel(); model.ready = true; model.settings.language = language
            let identity = FileIdentity(device: 1, inode: 1, birthSeconds: 1, birthNanoseconds: 0)
            let rows = ["한글 보고서.txt".decomposedStringWithCanonicalMapping, "cafe\u{301}.txt", "長い名前の報告書 か\u{3099}.txt", "normal.txt"].map { name in
                let analysis = NormalizationAnalysis(raw: Data(name.utf8))
                return FileEntry(path: RawPath("/fixture/" + name), identity: identity, parentIdentity: identity, status: analysis.status, reason: "ChangeHelp", proposed: analysis.nfc)
            }
            model.entries = rows; model.visible = rows; model.selected = Set(rows.filter { $0.status.fixable }.map(\.id)); model.focused = rows.first?.id
            model.counts = ["TotalCaption": 4, "NeededCaption": 3, "ConflictCaption": 0]
            model.roots = [RawPath("/fixture")]; model.settings.rememberRecentFolders = true; model.settings.recentFolders = ["/fixture/Recently checked"]
            let selected = model.selected, ids = model.entries.map(\.id), focus = model.focused
            for (i, size) in sizes.enumerated() {
                let theme = ["olive", "dark", "light", "system"][(i + languageIndex) % 4]; model.settings.theme = theme
                let name = "\(language)-\(Int(size.width))x\(Int(size.height))-\(theme)"
                try snapshot(MainView(model: model), name: name, size: size, dark: theme == "dark")
                if size.width < 900 || size.height < 400 { try snapshot(MainView(model: model), name: name + "-bottom", size: size, dark: theme == "dark", bottom: true) }
                guard model.selected == selected, model.entries.map(\.id) == ids, model.focused == focus else { throw NSError(domain: "ResponsiveState", code: 1) }
            }
            model.settings.theme = "olive"
            model.phase = "ActivityScan"; model.scanned = 1234; model.message = "BusyDropRejected"
            try snapshot(MainView(model: model), name: "\(language)-activity-error-small", size: CGSize(width: 320, height: 360), dark: false, bottom: true)
            model.phase = ""; model.message = nil
            let plan = RenamePlan(generation: UUID(), operations: try rows.filter { $0.status.fixable }.map { try RenameOperation(entry: $0) })
            let summary = try JSONDecoder().decode(TransactionSummary.self, from: Data(#"{"schemaVersion":1,"id":"00000000-0000-0000-0000-000000000001","date":0,"mode":"rename","total":4,"succeeded":2,"failed":1,"status":"CompletedWithErrors"}"#.utf8))
            // Synthetic app-owned journal only; no source file is opened or renamed.
            let store = try JournalStore(root: output.appendingPathComponent("fixture-history/\(UUID())"))
            let writer = try JournalWriter(url: store.journalURL(summary.id))
            for (index, operation) in plan.operations.enumerated() { try writer.append(index == 2 ? "Failed" : "Verified", operation: operation, error: index == 2 ? "SourceChanged" : nil) }
            model.history = [summary]; model.historyID = summary.id; model.historyDetails = try History.details(store: store, id: summary.id)
            model.recoveryDetails = [RecoveryInspection(operation: plan.operations[0], current: nil, status: "Ambiguous", observedLocations: [plan.operations[0].source.parent.appending(plan.operations[0].temporary)])]
            let available = CGSize(width: 344, height: 284), palette = Palette("olive", systemDark: false)
            for sheet in ["settings", "history", "inspector", "clipboard", "help", "about", "diagnostics"] {
                model.sheet = sheet; model.clipboard = "e\u{301}"; model.diagnostics()
                let preferred = CGSize(width: sheet == "history" ? 840 : 680, height: sheet == "history" ? 580 : 560)
                let size = WindowLayout.sheet(preferred: preferred, available: available)
                try snapshot(SheetRouter(model: model, availableSize: available), name: "\(language)-\(sheet)-small", size: size, dark: false)
                if sheet == "history" { try snapshot(SheetRouter(model: model, availableSize: available), name: "\(language)-history-small-bottom", size: size, dark: false, bottom: true) }
            }
            model.sheet = nil
            let size = WindowLayout.sheet(preferred: CGSize(width: 650, height: 640), available: available)
            try snapshot(ConfirmationView(model: model, plan: plan, palette: palette, availableSize: available), name: "\(language)-confirm-small", size: size, dark: false)
            try snapshot(ConfirmationView(model: model, plan: plan, palette: palette, availableSize: available), name: "\(language)-confirm-small-bottom", size: size, dark: false, bottom: true)
            try snapshot(MainView(model: model).resultView(summary, available: available), name: "\(language)-result-small", size: WindowLayout.sheet(preferred: CGSize(width: 550, height: 260), available: available), dark: false)
        }
        print("Rendered \(count) responsive layouts; selection/row identity/focus preserved across all sizes")
    }
}
