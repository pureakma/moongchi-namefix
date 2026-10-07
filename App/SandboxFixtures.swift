#if DEBUG
import AppKit
import NameFixCore
import NameFixRuntime
import NameFixApplication

/// Checks run inside the real App Sandbox by eng/test-sandbox.py, which builds this Debug app
/// with the store entitlements and hands it a folder the way Finder does (Open With).
/// Nothing is clicked and no user folder is used; every file is made by the test tool.
@MainActor enum SandboxFixtures {
    /// `--sandbox-probe <phase>`; a folder or file arrives through `application(_:open:)`.
    /// The report goes to stdout, which the tool connects to a file from outside the sandbox.
    static var phase: String? {
        guard let flag = CommandLine.arguments.firstIndex(of: "--sandbox-probe"), CommandLine.arguments.count > flag + 1 else { return nil }
        return CommandLine.arguments[flag + 1]
    }
    /// For the comparison run of the app outside the sandbox: its records go to a folder the tool made, never to the user's.
    static var supportOverride: URL? {
        guard let flag = CommandLine.arguments.firstIndex(of: "--probe-support"), CommandLine.arguments.count > flag + 1 else { return nil }
        return URL(fileURLWithPath: CommandLine.arguments[flag + 1], isDirectory: true)
    }
    /// When the model finished loading, for the start-up time.
    static var readyAt: Date?
    private static func processStart() -> Date? {
        var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: Double(info.kp_proc.p_starttime.tv_sec) + Double(info.kp_proc.p_starttime.tv_usec) / 1_000_000)
    }
    private static func timed(_ model: AppModel, _ start: @MainActor () -> Void, until done: @MainActor () -> Bool) async -> Double {
        let began = Date(); start()
        for _ in 0..<60_000 { if !model.busy && done() { break }; try? await Task.sleep(for: .milliseconds(2)) }
        return (Date().timeIntervalSince(began) * 1000).rounded() / 1000
    }
    private static func say(_ line: String) { FileHandle.standardOutput.write(Data((line + "\n").utf8)) }
    /// Phases that change the app's own stored data before it is loaded.
    static func prepare(_ phase: String, dataRoot: URL) {
        if phase == "reset" { try? FileManager.default.removeItem(at: dataRoot) }
        if phase == "forget" { try? FileManager.default.removeItem(at: dataRoot.appendingPathComponent("access.json")) }
    }
    private static func settle(_ model: AppModel, _ done: @MainActor () -> Bool = { true }) async -> Bool {
        for _ in 0..<600 { if !model.busy && done() { return true }; try? await Task.sleep(for: .milliseconds(50)) }
        return false
    }
    private static func names(_ folder: RawPath) -> [String] {
        guard let fd = try? FS.openDirectory(folder) else { return ["<cannot open>"] }
        defer { close(fd) }
        return ((try? FS.names(fd)) ?? []).map { $0.map { String(format: "%02x", $0) }.joined() }.sorted()
    }
    /// Writes what happened, as facts the tool compares, and quits.
    private static func finish(_ facts: [String: Any]) -> Never {
        var all = facts
        if let started = processStart(), let readyAt { all["startup"] = (readyAt.timeIntervalSince(started) * 1000).rounded() / 1000 }
        all["sandboxed"] = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        all["restricted"] = AccessRoots.shared.restricted
        all["edition"] = Bundle.main.object(forInfoDictionaryKey: "NameFixDistribution") as? String ?? ""
        let data = (try? JSONSerialization.data(withJSONObject: all, options: [.sortedKeys])) ?? Data()
        say("REPORT " + String(decoding: data, as: UTF8.self))
        exit(0)
    }
    static func run(_ phase: String, model: AppModel, opened: [URL]) async {
        var facts: [String: Any] = ["phase": phase, "opened": opened.count]
        _ = await settle(model) { model.ready }
        // What the sandbox itself refuses, so the rest of the report means what it says.
        facts["homeIsContainer"] = NSHomeDirectory().contains("/Library/Containers/")
        // A folder beside the one handed over was never allowed: the system itself must refuse it.
        if let beside = opened.first?.deletingLastPathComponent().appendingPathComponent("outside") { facts["systemRefusesNeighbour"] = open(beside.path, O_RDONLY | O_DIRECTORY) < 0 }
        switch phase {
        case "rename":
            // A folder handed over like Finder's Open With: scan, plan, rename, keep the way back.
            _ = await settle(model) { !model.entries.isEmpty }
            let root = model.roots.first
            facts["root"] = root?.display ?? ""; facts["rootIsAllowed"] = root.map(AccessRoots.shared.isRoot) ?? false
            facts["rootRow"] = model.entries.first { $0.path == root }?.reason ?? ""
            facts["fixable"] = model.entries.filter { $0.status.fixable }.count
            facts["reasons"] = Array(Set(model.entries.map(\.reason))).sorted()
            // A link inside the allowed folder that points outside it is never followed.
            facts["linkRows"] = model.entries.filter { $0.reason == "LinkedPathHelp" }.count
            facts["outsideRefused"] = (try? FS.openDirectory(RawPath("/private/tmp"))) == nil
            // Whether the system itself would let the app rename the folder it was handed (it is put back at once if so).
            if let root {
                let moved = root.display + ".probe"
                let allowed = rename(root.display, moved) == 0
                if allowed { _ = rename(moved, root.display) }
                facts["systemRefusesRootRename"] = !allowed
            }
            facts["before"] = root.map(names) ?? []
            model.prepare(); _ = await settle(model) { model.plan != nil || model.message != nil }
            facts["planned"] = model.plan?.operations.count ?? 0
            model.execute(); _ = await settle(model) { model.result != nil }
            facts["renamed"] = model.result?.succeeded ?? 0; facts["status"] = model.result?.status ?? ""
            model.dismissResult(); _ = await settle(model)
            facts["after"] = root.map(names) ?? []
            facts["history"] = model.history.count
            try? await Task.sleep(for: .seconds(1))   // the kept access is saved off the main actor
            await model.shutdown()
        case "undo":
            // A new process and no folder handed over: the kept bookmark has to lead back.
            facts["history"] = model.history.count
            guard let latest = model.history.first else { finish(facts) }
            model.prepare(mode: "undo", historyID: latest.id); _ = await settle(model) { model.plan != nil || model.message != nil || model.folderRequest != nil }
            facts["askedForFolder"] = model.folderRequest != nil; facts["message"] = model.message ?? ""
            facts["planned"] = model.plan?.operations.count ?? 0
            let folder = model.plan?.operations.first?.source.parent
            model.execute(); _ = await settle(model) { model.result != nil || model.plan == nil }
            facts["undone"] = model.result?.succeeded ?? 0
            facts["after"] = folder.map(names) ?? []
            await model.shutdown()
        case "favorite":
            // Pin the handed-over folder, then (next phase) reopen it from the pin alone.
            _ = await settle(model) { !model.entries.isEmpty }
            if let root = model.roots.first { model.addFavorite(URL(fileURLWithPath: root.display, isDirectory: true)) }
            model.changeSettings { $0.rememberRecentFolders = true }
            model.scan(); _ = await settle(model)
            facts["favorites"] = model.favorites.count; facts["hasBookmark"] = model.favorites.first?.bookmark != nil
            facts["recents"] = model.settings.recentFolders.count; facts["recentBookmarks"] = model.settings.recentAccess?.count ?? 0
            await model.shutdown()
        case "reopen":
            facts["favorites"] = model.favorites.count
            if let favorite = model.favorites.first { model.openFavorite(favorite) }
            _ = await settle(model) { !model.entries.isEmpty || model.message != nil }
            facts["favoriteEntries"] = model.entries.count; facts["favoriteProblem"] = model.favoriteProblems.count; facts["message"] = model.message ?? ""
            model.remove(nil); _ = await settle(model) { model.roots.isEmpty }
            if let recent = model.settings.recentFolders.first { model.openRecent(recent) }
            _ = await settle(model) { !model.entries.isEmpty || model.message != nil }
            facts["recentEntries"] = model.entries.count
            await model.shutdown()
        case "watch":
            _ = await settle(model) { !model.entries.isEmpty }
            if let root = model.roots.first { model.addWatch(URL(fileURLWithPath: root.display, isDirectory: true)) }
            try? await Task.sleep(for: .seconds(1))
            facts["watches"] = model.watches.folders.count; facts["watchErrors"] = Array(model.watchErrors.values)
            await model.shutdown()
        case "watching":
            // A new process: the watch starts from its bookmark and notices a file made by the tool.
            facts["watches"] = model.watches.folders.count; facts["watchErrors"] = Array(model.watchErrors.values)
            model.watchPending = []
            say("READY")
            for _ in 0..<200 { if !model.watchPending.isEmpty { break }; try? await Task.sleep(for: .milliseconds(100)) }
            facts["noticed"] = !model.watchPending.isEmpty
            if let id = model.watches.folders.first?.id { model.reviewWatch(id); _ = await settle(model) { !model.entries.isEmpty } }
            facts["reviewEntries"] = model.entries.count; facts["reviewFixable"] = model.entries.filter { $0.status.fixable }.count
            await model.shutdown()
        case "loose":
            // A file handed over on its own: the app asks for its folder instead of failing.
            _ = await settle(model) { !model.entries.isEmpty }
            facts["askedForFolder"] = model.folderRequest != nil; facts["askedFolder"] = model.folderRequest?.folder.lastPathComponent ?? ""
            facts["reasons"] = Array(Set(model.entries.map(\.reason))).sorted(); facts["message"] = model.message ?? ""
            facts["fixable"] = model.entries.filter { $0.status.fixable }.count
            // Whether the system itself would let the app rename a file it was handed without its folder.
            if let file = opened.first {
                let allowed = rename(file.path, file.path + ".probe") == 0
                if allowed { _ = rename(file.path + ".probe", file.path) }
                facts["systemRefusesFileRename"] = !allowed
            }
            // Declining changes nothing and the choice is offered again; allowing the folder lets the file be fixed.
            model.declineFolder(); facts["declinedKeepsNotice"] = model.folderRequest == nil && (model.message == "FolderAccessNeeded" || !AccessRoots.shared.restricted)
            model.requestFolderForLooseItems(); facts["offeredAgain"] = model.folderRequest != nil
            await model.shutdown()
        case "scroll":
            // The list is scrolled from top to bottom and back by the app itself, a row and a half at a
            // time, and the time each step takes to lay out and draw is measured. No events are synthesised.
            _ = await settle(model) { !model.entries.isEmpty && model.visible.count == model.entries.count }
            try? await Task.sleep(for: .seconds(1.5))
            func table(_ view: NSView) -> NSScrollView? {
                if let scroll = view as? NSScrollView, scroll.documentView is NSTableView { return scroll }
                for child in view.subviews { if let found = table(child) { return found } }
                return nil
            }
            guard let window = NSApp.windows.first(where: { $0.contentViewController is MainSidebarController }), let content = window.contentView, let scroll = table(content), let document = scroll.documentView else { finish(facts) }
            facts["rows"] = model.visible.count
            // The window is behind other apps; without this the system slows a background app down and the times mean nothing.
            let awake = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "scroll measurement")
            defer { ProcessInfo.processInfo.endActivity(awake) }
            var draw: [Double] = [], wait: [Double] = []
            let step: CGFloat = 60, pause = 0.008
            for pass in 0..<2 {
                let bottom = max(0, document.frame.height - scroll.contentView.bounds.height)
                var y: CGFloat = pass == 0 ? 0 : bottom
                while pass == 0 ? y < bottom : y > 0 {
                    y = pass == 0 ? min(bottom, y + step) : max(0, y - step)
                    let began = CFAbsoluteTimeGetCurrent()
                    scroll.contentView.scroll(to: NSPoint(x: 0, y: y)); scroll.reflectScrolledClipView(scroll.contentView)
                    window.displayIfNeeded(); CATransaction.flush()
                    let drawn = CFAbsoluteTimeGetCurrent()
                    try? await Task.sleep(for: .seconds(pause))
                    draw.append(drawn - began); wait.append(max(0, CFAbsoluteTimeGetCurrent() - drawn - pause))
                }
            }
            func summary(_ values: [Double]) -> [String: Any] {
                let sorted = values.sorted(), ms = { (v: Double) in (v * 10_000).rounded() / 10 }
                guard !sorted.isEmpty else { return [:] }
                return ["steps": sorted.count, "median": ms(sorted[sorted.count / 2]), "p95": ms(sorted[sorted.count * 95 / 100]), "p99": ms(sorted[sorted.count * 99 / 100]), "max": ms(sorted.last!), "over16": sorted.filter { $0 > 0.0167 }.count, "over33": sorted.filter { $0 > 0.0333 }.count, "total": ms(sorted.reduce(0, +))]
            }
            facts["draw"] = summary(draw); facts["between"] = summary(wait); facts["both"] = summary(zip(draw, wait).map { $0 + $1 })
            facts["height"] = Double(document.frame.height)
            await model.shutdown()
        case "look":
            // A folder on a drive the app does not rename on: it is listed, explained, and nothing is offered.
            _ = await settle(model) { !model.entries.isEmpty }
            facts["entries"] = model.entries.count; facts["fixable"] = model.entries.filter { $0.status.fixable }.count
            facts["reasons"] = Array(Set(model.entries.map(\.reason))).sorted(); facts["message"] = model.message ?? ""
            facts["labels"] = Array(Set(model.entries.filter { !$0.isDirectory }.map { CharacterPresentation.statusKey($0.status, name: $0.name, reason: $0.reason) })).sorted()
            model.prepare(); try? await Task.sleep(for: .seconds(2))
            facts["planned"] = model.plan?.operations.count ?? 0
            await model.shutdown()
        case "gui":
            // The real window, its sheets and its menus, with a folder handed over. Nothing is clicked:
            // the same actions the controls call are called, and the window is asked what it shows.
            _ = await settle(model) { !model.entries.isEmpty }
            let window = NSApp.windows.first { $0.contentViewController is MainSidebarController }
            facts["hasWindow"] = window != nil; facts["windowTitle"] = window?.title ?? ""
            facts["entries"] = model.entries.count; facts["fixable"] = model.entries.filter { $0.status.fixable }.count
            facts["toolbarItems"] = window?.toolbar?.items.count ?? 0
            let all = model.visible.count
            model.filter = "WindowsNames"; _ = await settle(model) { model.visible.count != all }
            facts["windowsFilter"] = model.visible.map(\.name).sorted()
            model.filter = "All"; _ = await settle(model) { model.visible.count == all }
            model.prepare(); _ = await settle(model) { model.plan != nil }
            try? await Task.sleep(for: .milliseconds(900))
            facts["confirmationSheet"] = window?.attachedSheet != nil; facts["planned"] = model.plan?.operations.count ?? 0
            model.execute(); _ = await settle(model) { model.result != nil }
            try? await Task.sleep(for: .milliseconds(900))
            facts["resultSheet"] = window?.attachedSheet != nil; facts["renamed"] = model.result?.succeeded ?? 0
            model.dismissResult(); _ = await settle(model) { !model.history.isEmpty }
            try? await Task.sleep(for: .milliseconds(700))
            model.present("history"); try? await Task.sleep(for: .milliseconds(900))
            facts["historySheet"] = window?.attachedSheet != nil; facts["history"] = model.history.count
            model.sheet = nil; try? await Task.sleep(for: .milliseconds(700))
            var sheets: [String] = []
            for name in ["settings", "help", "onboarding"] {
                model.present(name); try? await Task.sleep(for: .milliseconds(900))
                if window?.attachedSheet != nil { sheets.append(name) }
                model.sheet = nil; try? await Task.sleep(for: .milliseconds(700))
            }
            facts["otherSheets"] = sheets
            if let latest = model.history.first {
                model.prepare(mode: "undo", historyID: latest.id); _ = await settle(model) { model.plan != nil || model.message != nil }
                model.execute(); _ = await settle(model) { model.result != nil }
                facts["undone"] = model.result?.succeeded ?? 0
                model.dismissResult(); _ = await settle(model)
            }
            // What the menus offer in this edition.
            let menus = NSApp.mainMenu?.items ?? []
            let appMenu = menus.first?.submenu?.items.map(\.title).filter { !$0.isEmpty } ?? []
            facts["appMenu"] = appMenu
            facts["hasUpdateCheck"] = appMenu.contains { $0.hasPrefix(model.t("CheckForUpdates")) }
            facts["menuTitles"] = menus.compactMap { $0.submenu?.title }
            facts["updatePage"] = AppInfo.productPage?.absoluteString ?? ""; facts["supportAddress"] = AppInfo.support?.absoluteString ?? ""
            facts["isAppStoreEdition"] = AppInfo.isAppStore
            await model.shutdown()
        case "unicode":
            // Names from many scripts in the real app: what is offered, what is left, rename and undo.
            _ = await settle(model) { !model.entries.isEmpty }
            let root = model.roots.first
            func scalars(_ name: String) -> String { name.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " ") }
            facts["statuses"] = Dictionary(uniqueKeysWithValues: model.entries.filter { !$0.isDirectory }.map { (scalars($0.name), $0.status.rawValue + ">" + scalars($0.preview)) })
            facts["fixable"] = model.entries.filter { $0.status.fixable }.count; facts["conflicts"] = model.entries.filter { $0.status == .conflict }.count
            facts["before"] = root.map(names) ?? []
            model.prepare(); _ = await settle(model) { model.plan != nil || model.message != nil }
            facts["planned"] = model.plan?.operations.count ?? 0
            model.execute(); _ = await settle(model) { model.result != nil }
            facts["renamed"] = model.result?.succeeded ?? 0
            model.dismissResult(); _ = await settle(model) { !model.history.isEmpty }
            facts["after"] = root.map(names) ?? []
            if let latest = model.history.first {
                model.prepare(mode: "undo", historyID: latest.id); _ = await settle(model) { model.plan != nil || model.message != nil }
                model.execute(); _ = await settle(model) { model.result != nil }
                facts["undone"] = model.result?.succeeded ?? 0
                model.dismissResult(); _ = await settle(model)
            }
            facts["restored"] = root.map(names) ?? []
            await model.shutdown()
        case "profile":
            // Two folders handed over: 10,000 names to scan and filter, 1,000 to rename and undo.
            _ = await settle(model) { model.entries.count > 11_000 }
            guard model.roots.count == 2, let big = model.roots.first(where: { $0.display.hasSuffix("big") }), let small = model.roots.first(where: { $0.display.hasSuffix("small") }) else { finish(facts) }
            facts["entries"] = model.entries.count
            facts["scan"] = await timed(model, { model.scan() }, until: { model.entries.count > 11_000 })
            let all = model.visible.count
            facts["filter"] = await timed(model, { model.query = "999" }, until: { model.visible.count != all })
            model.query = ""; _ = await settle(model) { model.visible.count == all }
            model.addFavorite(URL(fileURLWithPath: big.display, isDirectory: true))
            model.remove(big); _ = await settle(model) { model.entries.count < 2_000 }
            facts["plan"] = await timed(model, { model.prepare() }, until: { model.plan != nil })
            facts["planned"] = model.plan?.operations.count ?? 0
            facts["rename"] = await timed(model, { model.execute() }, until: { model.result != nil })
            facts["renamed"] = model.result?.succeeded ?? 0
            model.dismissResult(); _ = await settle(model) { !model.history.isEmpty }   // the record list is reloaded after the result is shown
            if let latest = model.history.first {
                facts["undoPlan"] = await timed(model, { model.prepare(mode: "undo", historyID: latest.id) }, until: { model.plan != nil })
                facts["undo"] = await timed(model, { model.execute() }, until: { model.result != nil })
                facts["undone"] = model.result?.succeeded ?? 0
                model.dismissResult(); _ = await settle(model)
            }
            model.remove(nil); _ = await settle(model) { model.roots.isEmpty }
            if let favorite = model.favorites.first { facts["favoriteReopen"] = await timed(model, { model.openFavorite(favorite) }, until: { model.entries.count > 10_000 }) }
            _ = small
            await model.shutdown()
        default: break
        }
        finish(facts)
    }
}
#endif
