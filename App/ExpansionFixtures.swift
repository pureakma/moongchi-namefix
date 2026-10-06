import AppKit
import SwiftUI
import NameFixCore
import NameFixRuntime

@MainActor enum ExpansionFixtures {
    static func run(output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        if CommandLine.arguments.contains("--native-sidebar") {
            var total = 0
            for language in ["ko-KR", "en-US", "ja-JP"] {
                for theme in ["olive", "dark", "light", "system"] {
                    let model = AppModel(dataRoot: output.appendingPathComponent("isolated"))
                    model.ready = true; model.settings.language = language; model.settings.theme = theme
                    let appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
                    NSApp.appearance = appearance
                    for mode in ["quick", "batch", "collapsed"] {
                        model.settings.workbenchEnabled = mode == "batch"
                        let controller = MainSidebarController(model: model)
                        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: mode == "collapsed" ? 600 : 1180, height: 850), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
                        window.isReleasedWhenClosed = false; window.appearance = appearance; window.titlebarAppearsTransparent = true
                        window.contentViewController = controller
                        let chrome = WindowChrome(model: model); chrome.install(on: window, split: controller)
                        window.setContentSize(NSSize(width: mode == "collapsed" ? 600 : 1180, height: 850))
                        controller.navigationItem.isCollapsed = mode == "collapsed"
                        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
                        let sidebarView = controller.navigationItem.viewController.view
                        sidebarView.layoutSubtreeIfNeeded(); sidebarView.displayIfNeeded()
                        if mode != "collapsed" {
                            print("sidebar \(language) \(mode) frame=\(sidebarView.frame) bounds=\(sidebarView.bounds) hidden=\(sidebarView.isHidden)")
                            guard let sideBitmap = sidebarView.bitmapImageRepForCachingDisplay(in: sidebarView.bounds) else { throw FSError("RenderFailed") }
                            sidebarView.cacheDisplay(in: sidebarView.bounds, to: sideBitmap)
                            try sideBitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(language)-\(theme)-\(mode)-sidebar.png"))
                        }
                        let view = window.contentView!.superview!
                        view.layoutSubtreeIfNeeded()
                        precondition(view.bounds.width >= 600 && view.bounds.height >= 800, "Invalid native render dimensions")
                        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw FSError("RenderFailed") }
                        view.cacheDisplay(in: view.bounds, to: bitmap)
                        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw FSError("RenderFailed") }
                        try png.write(to: output.appendingPathComponent("\(language)-\(theme)-\(mode).png"))
                        precondition(controller.navigationItem.isCollapsed == (mode == "collapsed"))
                        total += 1; window.close()
                        withExtendedLifetime(chrome) {}
                    }
                }
            }
            print("PASS: \(total) native sidebar/window renders; collapse state verified; no user window controlled")
            return
        }
        var count = 0
        for language in ["ko-KR", "en-US", "ja-JP"] {
            for theme in ["olive", "dark", "light", "system"] {
                let model = AppModel(dataRoot: output.appendingPathComponent("isolated")); model.ready = true
                model.settings.language = language; model.settings.theme = theme
                var prefix = RenameRule(.prefix); prefix.text = "Project_"
                model.pipeline = RulePipeline(rules: [prefix, RenameRule(.numbering)])
                model.workbenchDraft = model.pipeline
                model.recipes.recipes = [Recipe(name: "Photo work / 사진 작업 / 写真の作業", pipeline: model.pipeline)]
                model.watches.folders = [WatchedFolder(bookmark: Data(), path: "/Example/Photos/검토할 사진과 동영상", pipeline: model.pipeline)]
                model.watchPending = Set(model.watches.folders.map(\.id))
                let raw = "한글é_보고서_ファイル.txt".decomposedStringWithCanonicalMapping
                let entry = FileEntry(path: RawPath("/Example/" + raw), status: .needsNormalization, reason: "ChangeHelp", proposed: Data(raw.precomposedStringWithCanonicalMapping.utf8))
                model.entries = [entry]; model.visible = [entry]; model.selected = [entry.id]; model.counts = ["TotalCaption": 1, "NeededCaption": 1, "ConflictCaption": 0]
                let dark = theme == "dark" || theme == "system"
                NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                let workspaceOnly = CommandLine.arguments.contains("--workspace-only")
                let cases: [(String?, CGFloat)] = workspaceOnly ? [("quick",1180),("quick",320),("workbench",1180),("workbench",320),("dirty",1180),("dirty",320)] : theme == "olive" ? [(nil,1180),(nil,320),("rules",680),("rules",320),("watch",320)] : [(nil,1180),("rules",680)]
                for (sheet, width) in cases {
                    model.sheet = workspaceOnly ? nil : sheet
                    if workspaceOnly {
                        model.settings.workbenchEnabled = sheet != "quick"
                        model.pipeline = sheet == "quick" ? RulePipeline() : model.recipes.recipes[0].pipeline
                        model.workbenchDraft = model.pipeline; model.markWorkbenchPreviewApplied()
                        if sheet == "dirty" { model.workbenchDraft.rules.append(RenameRule(.uppercase)) }
                    }
                    if workspaceOnly {
                        let proposed = try model.pipeline.evaluate(raw, access: .pro).last?.after ?? raw
                        var displayed = entry; displayed.proposed = Data(proposed.utf8)
                        displayed.reason = sheet == "quick" ? "ChangeHelp" : "RuleChangeHelp"
                        model.entries = [displayed]; model.visible = [displayed]
                    }
                    let size = CGSize(width: width, height: 640)
                    let root = (sheet == nil || workspaceOnly) ? AnyView(MainView(model: model).environment(\.colorScheme, dark ? .dark : .light)) : AnyView(SheetRouter(model: model, availableSize: CGSize(width: width + 24, height: 664)).environment(\.colorScheme, dark ? .dark : .light))
                    let host = NSHostingView(rootView: root); host.sizingOptions = []
                    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false); window.isReleasedWhenClosed = false
                    window.contentView = host; window.setContentSize(size)
                    RunLoop.main.run(until: Date().addingTimeInterval(0.1)); host.layoutSubtreeIfNeeded()
                    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw FSError("RenderFailed") }
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw FSError("RenderFailed") }
                    try data.write(to: output.appendingPathComponent("\(language)-\(theme)-\(sheet ?? "main")-\(Int(width)).png")); count += 1
                    window.close()
                }
            }
        }
        print("PASS: \(count) expansion view renders; ko/en/ja, 4 themes, narrow and wide windows; no user window controlled")
    }
}
