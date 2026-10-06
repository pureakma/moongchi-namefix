import AppKit
import SwiftUI
import NameFixCore
import NameFixRuntime

/// Representative first-use screens in the real window composition (sidebar + content).
/// Unshown fixture windows only; no user window, file or setting is touched.
@MainActor enum UXFixtures {
    static func run(output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let identity = FileIdentity(device: 1, inode: 1, birthSeconds: 1, birthNanoseconds: 0)
        func rows(conflict: Bool) -> [FileEntry] {
            var result = ["한글 보고서.txt".decomposedStringWithCanonicalMapping, "cafe\u{301}.txt", "長い名前の報告書 か\u{3099}.txt", "normal.txt"].map { name -> FileEntry in
                let analysis = NormalizationAnalysis(raw: Data(name.utf8))
                return FileEntry(path: RawPath("/Users/me/Documents/Trip/" + name), identity: identity, parentIdentity: identity, status: analysis.status, reason: analysis.status == .normal ? "NormalHelp" : "ChangeHelp", proposed: analysis.nfc)
            }
            if conflict { result[1].status = .conflict; result[1].reason = "ConflictHelp" }
            // The added folder and one subfolder, as a real scan reports them.
            let extra = FileEntry(path: RawPath("/Users/me/Documents/Trip/Day 2/" + "저녁 식사.jpg".decomposedStringWithCanonicalMapping), identity: identity, parentIdentity: identity, status: .needsNormalization, reason: "ChangeHelp", proposed: Data("저녁 식사.jpg".utf8))
            let folders = ["/Users/me/Documents/Trip", "/Users/me/Documents/Trip/Day 1", "/Users/me/Documents/Trip/Day 2"].map { FileEntry(path: RawPath($0), identity: identity, parentIdentity: identity, isDirectory: true, status: .normal, reason: "NormalHelp", proposed: RawPath($0).leaf) }
            result = folders + result + [extra]
            return result
        }
        var count = 0
        func render(_ name: String, language: String, theme: String, size: CGSize, workbench: Bool = false, entries: [FileEntry] = [], rules: [RenameRule] = [], applied: Bool = true, advanced: Bool = false) throws {
            let model = AppModel(dataRoot: output.appendingPathComponent("isolated")); model.ready = true
            model.settings.language = language; model.settings.theme = theme; model.settings.workbenchEnabled = workbench
            model.entries = entries; model.visible = entries; model.selected = Set(entries.filter { $0.status.fixable }.map(\.id)); model.focused = nil
            model.counts = ["TotalCaption": entries.count, "NeededCaption": entries.filter { $0.status.fixable }.count, "ConflictCaption": entries.filter { $0.status == .conflict }.count]
            if !entries.isEmpty { model.roots = [RawPath("/Users/me/Documents/Trip")]; model.rebuildFolderTree() }
            model.workbenchDraft = RulePipeline(rules: rules)
            if applied { model.pipeline = model.workbenchDraft; model.markWorkbenchPreviewApplied() }
            let dark = theme == "dark"
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let controller = MainSidebarController(model: model, startAdvanced: advanced)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = NSApp.appearance; window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Palette(theme, systemDark: dark).canvas)
            window.contentViewController = controller
            let chrome = WindowChrome(model: model); chrome.install(on: window, split: controller)
            window.setContentSize(size)
            controller.fit(width: size.width)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            let view = window.contentView!.superview!
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw FSError("RenderFailed") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw FSError("RenderFailed") }
            try png.write(to: output.appendingPathComponent(name + ".png")); count += 1
            window.close(); withExtendedLifetime(chrome) {}
        }
        let wide = CGSize(width: 1180, height: 780), narrow = CGSize(width: 440, height: 680)
        var prefix = RenameRule(.prefix); prefix.text = "Trip_"
        var number = RenameRule(.numbering); number.text = "_"
        func renamed(_ source: [FileEntry]) -> [FileEntry] {
            source.map { entry in guard !entry.isDirectory else { return entry }; var e = entry; e.proposed = Data(("Trip_" + entry.name).precomposedStringWithCanonicalMapping.utf8); e.status = .needsNormalization; e.reason = "RuleChangeHelp"; return e }
        }
        for language in ["ko-KR", "en-US", "ja-JP"] {
            try render("A-quick-empty-\(language)", language: language, theme: "olive", size: wide)
            try render("B-quick-results-\(language)", language: language, theme: "olive", size: wide, entries: rows(conflict: false))
            try render("D-batch-empty-\(language)", language: language, theme: "olive", size: wide, workbench: true)
            try render("D2-batch-choose-\(language)", language: language, theme: "olive", size: wide, workbench: true, entries: rows(conflict: false))
            try render("E-batch-basic-\(language)", language: language, theme: "olive", size: wide, workbench: true, entries: renamed(rows(conflict: false)), rules: [prefix])
        }
        try render("C-quick-conflict-ko-KR", language: "ko-KR", theme: "olive", size: wide, entries: rows(conflict: true))
        try render("E2-batch-unapplied-ko-KR", language: "ko-KR", theme: "olive", size: wide, workbench: true, entries: rows(conflict: false), rules: [prefix, number], applied: false)
        try render("F-batch-advanced-ko-KR", language: "ko-KR", theme: "olive", size: wide, workbench: true, entries: renamed(rows(conflict: false)), rules: [prefix], advanced: true)
        try render("G-narrow-quick-empty-ko-KR", language: "ko-KR", theme: "olive", size: narrow)
        try render("G-narrow-quick-results-ko-KR", language: "ko-KR", theme: "olive", size: narrow, entries: rows(conflict: true))
        try render("G-narrow-batch-choose-ja-JP", language: "ja-JP", theme: "olive", size: narrow, workbench: true, entries: rows(conflict: false))
        try render("I-dark-quick-empty", language: "ko-KR", theme: "dark", size: wide)
        try render("I-dark-quick-results", language: "en-US", theme: "dark", size: wide, entries: rows(conflict: true))
        try render("I-dark-batch-basic", language: "ko-KR", theme: "dark", size: wide, workbench: true, entries: renamed(rows(conflict: false)), rules: [prefix])
        try render("I-light-batch-choose", language: "en-US", theme: "light", size: wide, workbench: true, entries: rows(conflict: false))
        print("PASS: \(count) representative first-use screens; no user window controlled")
    }

    /// Window behaviour that a still image cannot show: the sidebar must stay visible after
    /// something is added, and the title bar band must drag the window wherever it has no control.
    static func diagnose(output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let folder = output.appendingPathComponent("fixture/Trip/Day 1")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: folder.appendingPathComponent("cafe\u{301}.txt"))
        try Data("b".utf8).write(to: folder.deletingLastPathComponent().appendingPathComponent("normal.txt"))
        let model = AppModel(dataRoot: output.appendingPathComponent("isolated")); model.ready = true
        let controller = MainSidebarController(model: model)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 800), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.titlebarAppearsTransparent = true
        window.contentViewController = controller
        let chrome = WindowChrome(model: model); chrome.install(on: window, split: controller)
        window.setContentSize(NSSize(width: 1400, height: 800)); controller.fit(width: 1400)
        func settle(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        func report(_ label: String) {
            let side = controller.navigationItem.viewController.view
            print("\(label): collapsed=\(controller.navigationItem.isCollapsed) sidebarWidth=\(Int(side.frame.width)) hidden=\(side.isHidden) toolbarItems=\(chrome.toolbar.items.map { $0.itemIdentifier.rawValue.replacingOccurrences(of: "NameFix.", with: "") })")
        }
        settle(0.4); report("empty")
        guard !controller.navigationItem.isCollapsed else { throw NSError(domain: "SidebarContract", code: 1) }
        model.add([folder.deletingLastPathComponent()])
        for _ in 0..<60 { settle(0.1); if !model.busy && !model.entries.isEmpty { break } }
        settle(0.5); report("after add (\(model.entries.count) entries, tree \(model.folderTree.count))")
        guard !controller.navigationItem.isCollapsed, controller.navigationItem.viewController.view.frame.width >= 200 else { throw NSError(domain: "SidebarContract", code: 2) }
        model.folderFilter = model.folderTree.first?.children?.first?.id
        settle(0.5); report("after choosing a tree folder")
        guard !controller.navigationItem.isCollapsed else { throw NSError(domain: "SidebarContract", code: 3) }
        // Title bar band: every point without a control must move the window. Over the sidebar that
        // means the drag strip, because a SwiftUI hosting view there would swallow the click.
        guard let frame = window.contentView?.superview else { throw NSError(domain: "DragContract", code: 1) }
        let bandY = frame.bounds.height - 26, sidebarWidth = Int(controller.navigationItem.viewController.view.frame.width)
        var blocked: [Int] = []
        for x in stride(from: 100, through: 1100, by: 20) {
            let hit = frame.hitTest(NSPoint(x: CGFloat(x), y: bandY))
            let hosting = hit.map { String(describing: type(of: $0)).contains("HostingView") } ?? false
            if x < sidebarWidth - 8 ? !(hit is WindowDragView) : (hosting || (hit != nil && !(hit is NSControl) && hit?.mouseDownCanMoveWindow == false)) { blocked.append(x) }
        }
        print("band points that would not drag the window: \(blocked)")
        guard blocked.isEmpty else { throw NSError(domain: "DragContract", code: 2) }
        // Dragging the divider must not be able to collapse a sidebar that has no toggle.
        guard !controller.navigationItem.canCollapse else { throw NSError(domain: "SidebarContract", code: 4) }
        window.setContentSize(NSSize(width: 600, height: 800)); controller.fit(width: 600); settle(0.3); report("narrow window")
        guard controller.navigationItem.isCollapsed, model.sidebarCollapsed else { throw NSError(domain: "SidebarContract", code: 5) }
        window.setContentSize(NSSize(width: 1400, height: 800)); controller.fit(width: 1400); settle(0.3); report("wide again")
        guard !controller.navigationItem.isCollapsed, !model.sidebarCollapsed, !controller.navigationItem.canCollapse else { throw NSError(domain: "SidebarContract", code: 6) }
        window.close(); withExtendedLifetime(chrome) {}
        print("PASS: sidebar stays visible after adding and filtering, cannot be collapsed by the divider, returns after a narrow window; title bar band drags the window")
    }
}
