#if DEBUG
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
        func capture(_ view: NSView, _ name: String) throws {
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw FSError("RenderFailed") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw FSError("RenderFailed") }
            try png.write(to: output.appendingPathComponent(name + ".png")); count += 1
        }
        func makeModel(language: String, theme: String, workbench: Bool, entries: [FileEntry], rules: [RenameRule], applied: Bool) -> AppModel {
            let model = AppModel(dataRoot: output.appendingPathComponent("isolated")); model.ready = true
            model.settings.language = language; model.settings.theme = theme; model.settings.workbenchEnabled = workbench
            model.entries = entries; model.visible = entries; model.selected = Set(entries.filter { $0.status.fixable }.map(\.id)); model.focused = nil
            model.counts = ["TotalCaption": entries.count, "NeededCaption": entries.filter { $0.status.fixable }.count, "ConflictCaption": entries.filter { $0.status == .conflict }.count]
            if !entries.isEmpty { model.roots = [RawPath("/Users/me/Documents/Trip")]; model.rebuildFolderTree() }
            model.workbenchDraft = RulePipeline(rules: rules)
            if applied { model.pipeline = model.workbenchDraft; model.markWorkbenchPreviewApplied() }
            NSApp.appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
            return model
        }
        /// The real window composition: title bar band, sidebar in its current mode, content.
        func render(_ name: String, language: String, theme: String, size: CGSize, workbench: Bool = false, entries: [FileEntry] = [], rules: [RenameRule] = [], applied: Bool = true, rulesFirst: Bool = false, configure: ((AppModel) -> Void)? = nil) throws {
            let model = makeModel(language: language, theme: theme, workbench: workbench, entries: entries, rules: rules, applied: applied)
            configure?(model)
            let controller = MainSidebarController(model: model, rulesFirst: rulesFirst)
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = NSApp.appearance; window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Palette(theme, systemDark: theme == "dark").sidebar)
            window.contentViewController = controller
            let chrome = WindowChrome(model: model); chrome.install(on: window, split: controller)
            window.setContentSize(size)
            controller.fit(width: size.width)
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            try capture(window.contentView!.superview!, name)
            window.close(); withExtendedLifetime(chrome) {}
        }
        /// Popovers and sheets are separate windows, so their content is captured on its own.
        func renderPart<V: View>(_ name: String, theme: String, size: CGSize, _ view: V) throws {
            let palette = Palette(theme, systemDark: theme == "dark")
            let host = NSHostingView(rootView: view.frame(width: size.width, alignment: .top).background(palette.dialog)); host.sizingOptions = []
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host; window.setContentSize(size); host.frame = NSRect(origin: .zero, size: size)
            RunLoop.main.run(until: Date().addingTimeInterval(0.25))
            try capture(host, name); window.close()
        }
        let wide = CGSize(width: 1180, height: 780), narrow = CGSize(width: 440, height: 680)
        var prefix = RenameRule(.prefix); prefix.text = "Trip_"
        var number = RenameRule(.numbering); number.text = "_"
        var replace = RenameRule(.replace); replace.text = "초안"; replace.replacement = "최종"
        func renamed(_ source: [FileEntry]) -> [FileEntry] {
            source.map { entry in guard !entry.isDirectory else { return entry }; var e = entry; e.proposed = Data(("Trip_" + entry.name).precomposedStringWithCanonicalMapping.utf8); e.status = .needsNormalization; e.reason = "RuleChangeHelp"; return e }
        }
        for language in ["ko-KR", "en-US", "ja-JP"] {
            try render("A-quick-empty-\(language)", language: language, theme: "olive", size: wide)
            try render("B-quick-results-\(language)", language: language, theme: "olive", size: wide, entries: rows(conflict: false))
            try render("D-batch-no-rules-\(language)", language: language, theme: "olive", size: wide, workbench: true, entries: rows(conflict: false))
            try render("F-batch-one-rule-\(language)", language: language, theme: "olive", size: wide, workbench: true, entries: renamed(rows(conflict: false)), rules: [prefix])
            let model = makeModel(language: language, theme: "olive", workbench: true, entries: [], rules: [], applied: true)
            try renderPart("E-add-rule-popover-\(language)", theme: "olive", size: CGSize(width: 266, height: 560), AddRuleMenu(model: model, palette: Palette("olive", systemDark: false), startExpanded: false, rule: { _ in }, advanced: { _ in }))
        }
        do {
            let model = makeModel(language: "ko-KR", theme: "olive", workbench: true, entries: rows(conflict: false), rules: [replace, number], applied: true)
            try renderPart("F2-rule-editing-ko-KR", theme: "olive", size: CGSize(width: 360, height: 430), RuleEditor(model: model, palette: Palette("olive", systemDark: false), selecting: replace.id).padding(Metrics.page))
        }
        try render("C-quick-conflict-ko-KR", language: "ko-KR", theme: "olive", size: wide, entries: rows(conflict: true))
        try render("D0-batch-empty-ko-KR", language: "ko-KR", theme: "olive", size: wide, workbench: true)
        try render("D1-batch-rules-first-ko-KR", language: "ko-KR", theme: "olive", size: wide, workbench: true, rulesFirst: true)
        try render("G-batch-stale-ko-KR", language: "ko-KR", theme: "olive", size: wide, workbench: true, entries: rows(conflict: false), rules: [replace, number], applied: false)
        do {
            let model = makeModel(language: "ko-KR", theme: "olive", workbench: true, entries: rows(conflict: false), rules: [prefix], applied: true)
            let palette = Palette("olive", systemDark: false)
            try renderPart("H-advanced-form-ko-KR", theme: "olive", size: CGSize(width: 480, height: 420), AdvancedRuleSheet(model: model, palette: palette, option: .form) {})
            try renderPart("H-advanced-presets-ko-KR", theme: "olive", size: CGSize(width: 480, height: 360), AdvancedRuleSheet(model: model, palette: palette, option: .presets) {})
            try renderPart("H-advanced-csv-ko-KR", theme: "olive", size: CGSize(width: 480, height: 320), AdvancedRuleSheet(model: model, palette: palette, option: .csv) {})
            try renderPart("E-add-rule-popover-expanded-ko-KR", theme: "olive", size: CGSize(width: 266, height: 760), AddRuleMenu(model: model, palette: palette, startExpanded: true, rule: { _ in }, advanced: { _ in }))
        }
        // Introduction (always light), help, and settings with the developer card.
        for (language, pages) in [("ko-KR", [0, 1, 2, 3]), ("en-US", [0, 3]), ("ja-JP", [0, 2])] {
            let model = makeModel(language: language, theme: "dark", workbench: false, entries: [], rules: [], applied: true)
            for page in pages { try renderPart("L-intro-\(page + 1)-\(language)", theme: "dark", size: CGSize(width: 620, height: 560), OnboardingView(model: model, page: page).frame(height: 560)) }
        }
        for (language, theme) in [("ko-KR", "olive"), ("en-US", "dark")] {
            let model = makeModel(language: language, theme: theme, workbench: false, entries: [], rules: [], applied: true)
            let palette = Palette(theme, systemDark: theme == "dark")
            let dressed = { (view: AnyView) in AnyView(view.padding(22).foregroundStyle(palette.text).font(L10n.font(language)).tint(palette.accent).environment(\.colorScheme, theme == "dark" ? .dark : .light)) }
            try renderPart("M-help-\(language)", theme: theme, size: CGSize(width: 680, height: 1180), dressed(AnyView(HelpView(model: model, palette: palette).frame(height: 1136))))
            try renderPart("N-settings-\(language)", theme: theme, size: CGSize(width: 680, height: 1620), dressed(AnyView(SettingsView(model: model, palette: palette).frame(height: 1576))))
            try renderPart("N-settings-narrow-\(language)", theme: theme, size: CGSize(width: 320, height: 2300), dressed(AnyView(SettingsView(model: model, palette: palette).frame(height: 2256))))
        }
        // The rail with the pointer on an icon, and the rule pane's example states.
        for (language, theme) in [("ko-KR", "olive"), ("en-US", "dark")] {
            let model = makeModel(language: language, theme: theme, workbench: true, entries: rows(conflict: false), rules: [], applied: true)
            let palette = Palette(theme, systemDark: theme == "dark")
            try renderPart("O-rail-hover-\(language)", theme: theme, size: CGSize(width: 300, height: 360), SidebarNavigation(model: model, hovering: "BatchWorkspace").frame(height: 360).background(palette.sidebar).environment(\.colorScheme, theme == "dark" ? .dark : .light))
        }
        do {
            var missing = RenameRule(.replace); missing.text = "없는 글자"; missing.replacement = "x"
            for (name, rules) in [("P-example-changes", [prefix]), ("P-example-none", [missing])] {
                let model = makeModel(language: "ko-KR", theme: "olive", workbench: true, entries: rows(conflict: false), rules: rules, applied: true)
                try renderPart(name + "-ko-KR", theme: "olive", size: CGSize(width: 360, height: 300), RuleEditor(model: model, palette: Palette("olive", systemDark: false)).padding(Metrics.page))
            }
        }
        // Favourites on the first screen (one that cannot be opened), the batch rename target options,
        // and a list in which folders and hidden items are left alone.
        for language in ["ko-KR", "en-US"] {
            try render("R-favorites-\(language)", language: language, theme: "olive", size: wide) { model in
                model.settings.favoriteFolders = [FavoriteFolder(path: "/Users/Shared", bookmark: nil), FavoriteFolder(path: "/private/tmp", bookmark: nil), FavoriteFolder(path: "/Volumes/Gone/Project Photos", bookmark: nil)]
                model.checkFavorites()
            }
        }
        do {
            let model = makeModel(language: "ko-KR", theme: "olive", workbench: true, entries: rows(conflict: false), rules: [prefix], applied: true)
            model.workbenchDraft.includeFolders = true
            try renderPart("S-targets-sheet-ko-KR", theme: "olive", size: CGSize(width: 480, height: 330), AdvancedRuleSheet(model: model, palette: Palette("olive", systemDark: false), option: .targets) {})
            try renderPart("S-targets-row-ko-KR", theme: "olive", size: CGSize(width: 360, height: 300), RuleEditor(model: model, palette: Palette("olive", systemDark: false)).padding(Metrics.page))
            let excluded = rows(conflict: false).map { entry -> FileEntry in
                var e = entry
                if e.isDirectory { e.proposed = e.path.leaf; e.status = .normal; e.reason = "FolderExcluded" }
                else { e.proposed = Data(("Trip_" + entry.name).precomposedStringWithCanonicalMapping.utf8); e.status = .needsNormalization; e.reason = "RuleChangeHelp" }
                return e
            }
            try render("S-targets-list-ko-KR", language: "ko-KR", theme: "olive", size: wide, workbench: true, entries: excluded, rules: [prefix])
        }
        try render("I-narrow-quick-empty-ko-KR", language: "ko-KR", theme: "olive", size: narrow)
        try render("I-narrow-quick-results-ko-KR", language: "ko-KR", theme: "olive", size: narrow, entries: rows(conflict: true))
        try render("I-narrow-batch-ja-JP", language: "ja-JP", theme: "olive", size: narrow, workbench: true, entries: renamed(rows(conflict: false)), rules: [prefix])
        try render("K-dark-quick-empty", language: "ko-KR", theme: "dark", size: wide)
        try render("K-dark-quick-results", language: "en-US", theme: "dark", size: wide, entries: rows(conflict: true))
        try render("K-dark-batch-stale", language: "ko-KR", theme: "dark", size: wide, workbench: true, entries: rows(conflict: false), rules: [replace], applied: false)
        try render("K-light-batch-one-rule", language: "en-US", theme: "light", size: wide, workbench: true, entries: renamed(rows(conflict: false)), rules: [prefix])
        print("PASS: \(count) representative screens; no user window controlled")
    }

    /// Window behaviour that a still image cannot show: the sidebar follows the input state without
    /// a toggle, and the whole title bar band — left, middle and right — moves the window.
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
        func sidebarWidth() -> CGFloat { controller.navigationItem.viewController.view.frame.width }
        func report(_ label: String) {
            print("\(label): mode=\(controller.mode) collapsed=\(controller.navigationItem.isCollapsed) sidebarWidth=\(Int(sidebarWidth())) tree=\(model.folderTree.count) toolbarItems=\(chrome.toolbar.items.map { $0.itemIdentifier.rawValue.replacingOccurrences(of: "NameFix.", with: "") })")
        }
        func expect(_ condition: Bool, _ code: Int) throws { if !condition { throw NSError(domain: "WindowContract", code: code) } }
        settle(0.4); report("A nothing added")
        try expect(controller.mode == .navigation && abs(sidebarWidth() - WindowLayout.navigationWidth) < 1 && !controller.navigationItem.canCollapse, 1)
        try bandDrags(window, "A")
        model.add([folder.deletingLastPathComponent()])
        for _ in 0..<60 { settle(0.1); if !model.busy && !model.entries.isEmpty { break } }
        settle(0.5); report("B folder added")
        try expect(controller.mode == .railWithTree && abs(sidebarWidth() - (WindowLayout.railWidth + WindowLayout.defaultTreeWidth)) < 1 && !model.folderTree.isEmpty, 2)
        try bandDrags(window, "B")
        // The result list never shows a horizontal scroller, whatever the system scroll bar setting is.
        func tables(_ view: NSView) -> [NSTableView] { (view as? NSTableView).map { [$0] } ?? view.subviews.flatMap(tables) }
        let lists = window.contentView.map(tables) ?? []
        for table in lists {
            let scroll = table.enclosingScrollView
            print("result list: columns=\(table.tableColumns.map { Int($0.width) }) table=\(Int(table.frame.width)) clip=\(Int(scroll?.contentSize.width ?? -1)) horizontalScroller=\(scroll?.hasHorizontalScroller ?? false) vertical=\(scroll?.hasVerticalScroller ?? false)")
        }
        try expect(!lists.isEmpty && lists.allSatisfy { $0.enclosingScrollView?.hasHorizontalScroller == false }, 7)
        model.folderFilter = model.folderTree.first?.children?.first?.id
        settle(0.4); try expect(controller.mode == .railWithTree && !controller.navigationItem.isCollapsed, 3)
        model.remove(nil)
        for _ in 0..<60 { settle(0.1); if !model.busy { break } }
        settle(0.5); report("C everything removed")
        try expect(controller.mode == .navigation && abs(sidebarWidth() - WindowLayout.navigationWidth) < 1 && model.folderTree.isEmpty && model.folderFilter == nil, 4)
        window.setContentSize(NSSize(width: 600, height: 800)); controller.fit(width: 600); settle(0.3); report("narrow window")
        try expect(controller.mode == .hidden && controller.navigationItem.isCollapsed && model.sidebarCollapsed, 5)
        try bandDrags(window, "narrow")
        window.setContentSize(NSSize(width: 1400, height: 800)); controller.fit(width: 1400); settle(0.3); report("wide again")
        try expect(controller.mode == .navigation && !controller.navigationItem.isCollapsed && !model.sidebarCollapsed, 6)
        window.close(); withExtendedLifetime(chrome) {}
        print("PASS: sidebar follows input and width without a toggle; left, middle and right of the title bar band move the window")
    }
    /// Every point of the band must go to a drag strip, a system title bar view or a control —
    /// never to a SwiftUI hosting view, which would swallow the click.
    static func bandDrags(_ window: NSWindow, _ label: String) throws {
        guard let frame = window.contentView?.superview else { throw NSError(domain: "DragContract", code: 1) }
        let width = frame.bounds.width
        var blocked: [String] = [], thirds = [0, 0, 0]
        for depth in [8, 26, 44] {
            for x in stride(from: 90, to: Int(width) - 6, by: 12) {
                let hit = frame.hitTest(NSPoint(x: CGFloat(x), y: frame.bounds.height - CGFloat(depth)))
                let name = hit.map { String(describing: type(of: $0)) } ?? "nil"
                let control = hit is NSControl || name.contains("ToolbarItemViewer") || name.contains("ToolbarButton")
                let drags = hit is WindowDragView || (!name.contains("HostingView") && hit?.mouseDownCanMoveWindow == true)
                if control { continue }
                if drags { thirds[min(2, x * 3 / Int(width))] += 1 } else { blocked.append("\(x),-\(depth):\(name.prefix(24))") }
            }
        }
        print("band \(label): draggable samples left/middle/right = \(thirds), blocked = \(blocked.prefix(6))")
        // AppKit counts a SwiftUI hosting view's whole frame as blocking window moves. One under the
        // band empties the window's drag region, and then only parts of the band move the window.
        let band = NSRect(x: 0, y: frame.bounds.height - 30, width: width, height: 30)
        var under: [String] = []
        func walk(_ view: NSView) {
            let name = String(describing: type(of: view))
            if name.contains("HostingView<"), !name.hasPrefix("_NS"), !view.isHidden, view.convert(view.bounds, to: frame).intersects(band) { under.append(String(name.prefix(40))) }
            view.subviews.forEach(walk)
        }
        window.contentView.map(walk)
        #if DEBUG
        let region = window.perform(NSSelectorFromString("_lastDragRegionData"))?.takeUnretainedValue() as? Data
        print("band \(label): hosting views under the band = \(under), system drag region = \(region.map { $0.count > 12 ? "set" : "EMPTY" } ?? "not computed")")
        if let region, region.count <= 12 { throw NSError(domain: "DragContract", code: 4) }
        #endif
        guard under.isEmpty else { throw NSError(domain: "DragContract", code: 3) }
        guard blocked.isEmpty, thirds.allSatisfy({ $0 > 0 }) else { throw NSError(domain: "DragContract", code: 2) }
    }
}
#endif
