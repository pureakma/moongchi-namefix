#if DEBUG
import AppKit
import SwiftUI
import NameFixCore
import NameFixRuntime

/// Store screenshots. Every scene is the real window on sample files that this
/// fixture creates inside the output folder: the app scans, previews and renames them itself.
/// Unshown windows only; no user window, file or setting is touched.
@MainActor enum MarketingFixtures {
    struct Sample {
        let folder: String, broken: [String], whole: [String], days: [(String, [String])], favorites: [String], find: String, replace: String
    }
    static let sets: [String: Sample] = [
        "ko-KR": Sample(folder: "여행 사진", broken: ["제주도 여행 계획.txt", "보고서 초안.docx", "회의자료 초안.pdf", "프로젝트 초안.key"], whole: ["일정표.xlsx"],
                        days: [("첫째 날", ["해변 산책.jpg", "저녁 식사.jpg"]), ("둘째 날", ["한라산 일출.jpg"])], favorites: ["회의자료", "프로젝트_최종"], find: "초안", replace: "최종"),
        "en-US": Sample(folder: "Trip Photos", broken: ["Café menu.pdf", "Résumé draft.docx", "Zürich plan draft.txt", "Señor López draft.key"], whole: ["Itinerary.xlsx"],
                        days: [("Day 1", ["Crème brûlée.jpg", "Château garden.jpg"]), ("Day 2", ["São Paulo skyline.jpg"])], favorites: ["Meeting Notes", "Project_Final"], find: "draft", replace: "final"),
        "ja-JP": Sample(folder: "旅行の写真", broken: ["旅行プラン.txt", "レポート 下書き.docx", "会議メモ 下書き.pdf", "プロジェクト 下書き.key"], whole: ["日程表.xlsx"],
                        days: [("1日目", ["ビーチの散歩.jpg", "ディナー.jpg"]), ("2日目", ["富士山の日の出.jpg"])], favorites: ["会議資料", "プロジェクト_最終"], find: "下書き", replace: "最終")
    ]
    /// An unshown window is drawn as inactive. The captures show the window as it looks in use.
    final class ActiveWindow: NSWindow {
        override var isKeyWindow: Bool { true }
        override var isMainWindow: Bool { true }
    }
    /// `samples` is where the sample files are made. Its path is shown by the confirmation and the
    /// history, so the caller passes a neutral folder of its own instead of a personal one.
    static func run(output: URL, samples: URL? = nil) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .aqua)
        let size = CGSize(width: 1180, height: 720), available = CGSize(width: 900, height: 660)
        var scenes: [[String: Any]] = []
        func settle(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func wait(_ label: String, _ done: () -> Bool) throws {
            for _ in 0..<300 { settle(0.05); if done() { settle(0.45); return } }
            throw NSError(domain: "MarketingRender", code: 1, userInfo: [NSLocalizedDescriptionKey: label])
        }
        func png(_ view: NSView, _ name: String) throws {
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw FSError("RenderFailed") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw FSError("RenderFailed") }
            try data.write(to: output.appendingPathComponent(name + ".png"))
        }
        /// Sheets are separate windows, so their content is captured on its own at the size the app gives it.
        func sheet<V: View>(_ view: V, _ name: String, preferred: CGSize) throws {
            let fitted = WindowLayout.sheet(preferred: preferred, available: available)
            let host = NSHostingView(rootView: view.frame(width: fitted.width, height: fitted.height).environment(\.colorScheme, .light).environment(\.controlActiveState, .key)); host.sizingOptions = []
            let window = ActiveWindow(contentRect: NSRect(origin: .zero, size: fitted), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host; window.setContentSize(fitted); host.frame = NSRect(origin: .zero, size: fitted)
            settle(0.4); try png(host, name); window.close()
        }
        /// Names are written byte for byte: decomposed for the names to repair, composed for the rest.
        func make(_ parent: URL, _ name: String, decomposed: Bool, folder: Bool = false) throws -> URL {
            let leaf = decomposed ? name.decomposedStringWithCanonicalMapping : name.precomposedStringWithCanonicalMapping
            let path = parent.withUnsafeFileSystemRepresentation { String(cString: $0!) } + "/" + leaf
            let status: Int32 = path.withCString { raw in
                if folder { return mkdir(raw, 0o755) }
                let descriptor = open(raw, O_CREAT | O_EXCL | O_WRONLY, 0o644)
                return descriptor < 0 ? -1 : close(descriptor)
            }
            guard status == 0 else { throw FSError("RenderFailed") }
            return URL(fileURLWithPath: path, isDirectory: folder)
        }
        for language in ["ko-KR", "en-US", "ja-JP"] {
            guard let sample = sets[language] else { continue }
            let home = samples ?? output.appendingPathComponent("files/\(language)")
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            let folder = try make(home, sample.folder, decomposed: false, folder: true)
            for name in sample.broken { _ = try make(folder, name, decomposed: true) }
            for name in sample.whole { _ = try make(folder, name, decomposed: false) }
            for (day, names) in sample.days {
                let inner = try make(folder, day, decomposed: false, folder: true)
                for name in names { _ = try make(inner, name, decomposed: true) }
            }
            let pinned = try sample.favorites.map { try make(home, $0, decomposed: false, folder: true) }

            let model = AppModel(dataRoot: output.appendingPathComponent("isolated/\(language)"))
            var started = false
            Task { @MainActor in await model.start(); started = true }
            try wait("start") { started }
            model.settings.language = language; model.settings.theme = "olive"
            let controller = MainSidebarController(model: model)
            let window = ActiveWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = NSApp.appearance; window.title = model.t("AppName"); window.titlebarAppearsTransparent = true
            let palette = Palette("olive", systemDark: false)
            window.backgroundColor = NSColor(palette.sidebar)
            window.contentViewController = controller
            let chrome = WindowChrome(model: model); chrome.install(on: window, split: controller)
            window.setContentSize(size); controller.fit(width: size.width)
            func shot(_ scene: String, purpose: String, sheet: String? = nil) throws {
                chrome.refresh(); settle(0.35)
                let name = "\(scene)-\(language)"
                try png(window.contentView!.superview!, name)
                var record: [String: Any] = ["scene": scene, "language": language, "purpose": purpose, "window": name + ".png", "points": [Int(size.width), Int(size.height)]]
                if let sheet { record["sheet"] = sheet + ".png" }
                scenes.append(record)
            }
            // 1. The repair screen after a real scan of the sample folder.
            model.add([folder])
            try wait("scan") { !model.busy && !model.entries.isEmpty }
            try shot("1-repair", purpose: "Repair screen listing the names to fix")
            // 2. The confirmation the app shows before anything is renamed.
            model.prepare()
            try wait("plan") { model.plan != nil }
            if let plan = model.plan {
                try sheet(ConfirmationView(model: model, plan: plan, palette: palette, availableSize: available), "2-preview-sheet-\(language)", preferred: CGSize(width: 650, height: 640))
            }
            try shot("2-preview", purpose: "Confirmation of every change before renaming", sheet: "2-preview-sheet-\(language)")
            model.cancelPreview(); settle(0.3)
            // 3. Batch rename with a text rule and a numbering rule, previewed by the app.
            model.openWorkbench()
            try wait("batch scan") { !model.busy }
            var replace = RenameRule(.replace); replace.text = sample.find; replace.replacement = sample.replace
            var number = RenameRule(.numbering); number.text = "_"
            model.workbenchDraft = RulePipeline(rules: [replace, number])
            model.usePipeline(model.workbenchDraft)
            try wait("batch preview") { !model.busy && !model.hasUnappliedRules }
            try shot("3-batch", purpose: "Batch rename with text and numbering rules")
            // 5. A real repair run on the samples, then the history that can undo it.
            model.openQuickCleanup()
            try wait("repair scan") { !model.busy && !model.entries.isEmpty }
            model.prepare()
            try wait("repair plan") { model.plan != nil }
            model.execute()
            try wait("repair run") { model.result != nil }
            model.dismissResult()
            try wait("rescan") { !model.busy }
            guard let latest = model.history.first else { throw FSError("RenderFailed") }
            model.sheet = "history"; model.loadDetails(latest.id)
            try wait("history") { !model.historyLoading && !model.historyDetails.isEmpty }
            try sheet(SheetRouter(model: model, availableSize: available), "5-history-sheet-\(language)", preferred: CGSize(width: 840, height: 580))
            model.sheet = nil; settle(0.3)
            try shot("5-history", purpose: "History of a finished run, with Undo", sheet: "5-history-sheet-\(language)")
            // 4. The first screen with favourite folders.
            model.remove(nil)
            try wait("close all") { !model.busy && model.roots.isEmpty }
            model.settings.recentFolders = []
            model.settings.favoriteFolders = ([folder] + pinned).map { FavoriteFolder(path: $0.withUnsafeFileSystemRepresentation { String(cString: $0!) }, bookmark: nil) }
            model.checkFavorites()
            try shot("4-favorites", purpose: "First screen with favourite folders")
            window.close(); withExtendedLifetime(chrome) {}
            var stopped = false
            Task { @MainActor in await model.shutdown(); stopped = true }
            try wait("shutdown") { stopped }
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "", build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let manifest: [String: Any] = ["app": "Moongchi NameFix", "version": version, "build": build, "configuration": "Debug", "scale": Int(NSScreen.main?.backingScaleFactor ?? 2), "scenes": scenes]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("captures.json"))
        print("PASS: \(scenes.count) marketing scenes on app-made sample files; no user window controlled")
    }
}
#endif
