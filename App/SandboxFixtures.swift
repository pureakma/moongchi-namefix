#if DEBUG
import AppKit
import NameFixCore
import NameFixRuntime
import NameFixApplication

/// Checks run inside the real App Sandbox by eng/test-sandbox.py, which builds this Debug app
/// with the store entitlements and hands it a folder the way Finder does (Open With).
/// Nothing is clicked and no user folder is used; every file is made by the test tool.
@MainActor enum SandboxFixtures {
    /// Tab presses in the rule fields that were left to an input method. Counted for the "typing" phase.
    static var tabsLeftToInputMethod = 0
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
    /// Folders handed over with `--probe-hold <path>` are not added. macOS has allowed them to this
    /// process, so the probe can answer a folder request with them, the way the folder panel would.
    static var held: [URL] = []
    static func keepBack(_ urls: [URL]) -> [URL] {
        var wanted: [String] = []
        for (index, argument) in CommandLine.arguments.enumerated() where argument == "--probe-hold" && index + 1 < CommandLine.arguments.count { wanted.append(URL(fileURLWithPath: CommandLine.arguments[index + 1]).standardizedFileURL.path) }
        guard phase != nil, !wanted.isEmpty else { return urls }
        let kept = urls.filter { wanted.contains($0.standardizedFileURL.path) }
        held += kept
        return urls.filter { !wanted.contains($0.standardizedFileURL.path) }
    }
    private static func chosen(for request: AppModel.FolderRequest) -> URL? {
        held.first { $0.standardizedFileURL.path == request.folder.standardizedFileURL.path } ?? held.first { $0.lastPathComponent == request.folder.lastPathComponent }
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
        case "window-reopen":
            // Exercise the real retained main window and the production menu action. No user files
            // or input events: the caller provides isolated support and sample folders.
            guard let window = NSApp.windows.first(where: { $0.contentViewController is MainSidebarController }),
                  let delegate = NSApp.delegate as? AppDelegate else {
                facts["error"] = "main window or delegate missing"; finish(facts)
            }
            // Populate presentation state directly: filesystem traversal is outside this gate.
            let sampleRoot = RawPath(model.dataRoot.deletingLastPathComponent().appendingPathComponent("samples").path)
            model.roots = [sampleRoot]
            model.entries = [FileEntry(path: sampleRoot.appending(Data("example.txt".utf8)), status: .normal, reason: "Normal", proposed: Data("example.txt".utf8))]
            let roots = model.roots, entries = model.entries.map(\.id)
            model.query = "retained window state"
            var checks: [[String: Any]] = []
            for language in ["ko-KR", "en-US", "ja-JP"] {
                // Menu localization is exercised without a settings write to the Desktop fixture.
                model.settings.language = language
                let ready = await settle(model) {
                    NSApp.windowsMenu?.items.contains(where: { $0.identifier?.rawValue == "showMainWindow" && $0.title == model.t("MenuShowMainWindow") }) == true
                }
                guard ready, let menu = NSApp.windowsMenu,
                      let item = menu.items.first(where: { $0.identifier?.rawValue == "showMainWindow" }),
                      let action = item.action else {
                    facts["error"] = "localized menu missing"; finish(facts)
                }
                var check: [String: Any] = ["language": language, "title": item.title,
                                           "shortcut": item.keyEquivalent == "0" && item.keyEquivalentModifierMask == .command]
                var reopened = true
                for _ in 0..<2 {
                    window.performClose(nil)
                    let closed = !window.isVisible
                    menu.update()
                    let sent = NSApp.sendAction(action, to: item.target, from: item)
                    let visible = await settle(model) { window.isVisible }
                    reopened = reopened && closed && item.isEnabled && sent && visible
                }
                check["closedWindowReopensTwice"] = reopened
                window.miniaturize(nil)
                let minimized = await settle(model) { window.isMiniaturized }
                let sent = NSApp.sendAction(action, to: item.target, from: item)
                let restored = await settle(model) { !window.isMiniaturized && window.isVisible }
                check["minimizedWindowRestored"] = minimized && sent && restored
                window.performClose(nil)
                let dockClosed = !window.isVisible
                let handled = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
                let dockVisible = await settle(model) { window.isVisible }
                check["dockReopens"] = dockClosed && handled && dockVisible
                check["sameWindow"] = NSApp.windows.contains(where: { $0 === window })
                check["statePreserved"] = !roots.isEmpty && model.roots == roots && model.entries.map(\.id) == entries && model.query == "retained window state"
                check["keepsRunningAfterClose"] = !delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp)
                checks.append(check)
            }
            facts["checks"] = checks
            await model.shutdown()
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
            // A very long list is sampled: 1,500 steps down from the top and 1,500 up from the bottom.
            let limit = CommandLine.arguments.contains("--probe-large") ? 1_500 : Int.max
            if limit != Int.max {
                // How long the list takes to follow the model: search, filter, sort, and back.
                let all = model.visible.count
                facts["search"] = await timed(model, { model.query = "0999" }, until: { model.visible.count != all })
                facts["searchRows"] = model.visible.count
                facts["clear"] = await timed(model, { model.query = "" }, until: { model.visible.count == all })
                facts["filter"] = await timed(model, { model.filter = "Normal" }, until: { model.visible.count != all })
                facts["filterRows"] = model.visible.count
                facts["unfilter"] = await timed(model, { model.filter = "All" }, until: { model.visible.count == all })
                let began = CFAbsoluteTimeGetCurrent(); (document as? NSTableView)?.reloadData(); window.displayIfNeeded()
                facts["reload"] = ((CFAbsoluteTimeGetCurrent() - began) * 1000).rounded() / 1000
            }
            for pass in 0..<2 {
                let bottom = max(0, document.frame.height - scroll.contentView.bounds.height)
                var y: CGFloat = pass == 0 ? 0 : bottom, taken = 0
                while (pass == 0 ? y < bottom : y > 0), taken < limit {
                    taken += 1
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
        case "parent":
            // An added folder whose own name needs fixing. In the sandbox: the items inside are ready at once,
            // nothing is asked until the folder's name is wanted, cancelling changes nothing, and choosing
            // the folder above makes the folder a row like any other. Outside the sandbox it is one from the start.
            _ = await settle(model) { !model.entries.isEmpty }
            let folder = model.roots.first
            func row() -> FileEntry? { model.entries.first { $0.path == model.roots.first } }
            facts["askedAtOnce"] = model.folderRequest != nil
            facts["rowReason"] = row()?.reason ?? ""; facts["rowLabel"] = row().map { CharacterPresentation.statusKey($0.status, name: $0.name, reason: $0.reason) } ?? ""
            facts["message"] = model.message ?? ""; facts["fixableBefore"] = model.entries.filter { $0.status.fixable }.count
            model.requestParentFolder()
            facts["askedFor"] = model.folderRequest?.folder.lastPathComponent ?? ""; facts["askedPurposeParent"] = model.folderRequest?.purpose == .parent
            if let request = model.folderRequest {
                model.declineFolder(); _ = await settle(model)
                // Read with what macOS gave this process, not through the app's own rule, which still refuses the folder above.
                facts["afterCancel"] = folder.map { ((try? FileManager.default.contentsOfDirectory(atPath: $0.parent.display)) ?? ["<cannot read>"]).map { Data($0.utf8).map { String(format: "%02x", $0) }.joined() }.sorted() } ?? []; facts["messageAfterCancel"] = model.message ?? ""; facts["entriesAfterCancel"] = model.entries.count
                model.requestParentFolder(); facts["askedAgain"] = model.folderRequest != nil
                if let url = chosen(for: request) { model.allowFolder(url) } else { facts["noHeldFolder"] = true }
                _ = await settle(model) { row()?.status.fixable == true || model.message != nil }
            }
            facts["rowFixable"] = row()?.status.fixable ?? false; facts["fixableAfter"] = model.entries.filter { $0.status.fixable }.count; facts["messageAfter"] = model.message ?? ""
            model.prepare(); _ = await settle(model) { model.plan != nil || model.message != nil }
            facts["planned"] = model.plan?.operations.count ?? 0
            model.execute(); _ = await settle(model) { model.result != nil }
            facts["renamed"] = model.result?.succeeded ?? 0; facts["status"] = model.result?.status ?? ""
            model.dismissResult(); _ = await settle(model)
            try? await Task.sleep(for: .seconds(1))
            await model.shutdown()
        case "files":
            // Files handed over on their own. Each folder that is needed is asked for once, in turn.
            _ = await settle(model) { !model.entries.isEmpty }
            var asked: [[String: Any]] = []
            // How the handed-over path spells the item's folder, against how the system spells it once it can be read.
            facts["arrivedParent"] = opened.first.map { Data($0.deletingLastPathComponent().lastPathComponent.utf8).map { String(format: "%02x", $0) }.joined() } ?? ""
            if CommandLine.arguments.contains("--probe-decline-first"), model.folderRequest != nil {
                model.declineFolder(); _ = await settle(model)
                facts["messageAfterCancel"] = model.message ?? ""; facts["fixableAfterCancel"] = model.entries.filter { $0.status.fixable }.count; facts["entriesAfterCancel"] = model.entries.count
                model.requestFolderForLooseItems(); facts["askedAgain"] = model.folderRequest != nil
            }
            while let request = model.folderRequest, asked.count < 10 {
                asked.append(["folder": request.folder.lastPathComponent, "remaining": request.remaining])
                guard let url = chosen(for: request) else { model.declineFolder(); break }
                model.allowFolder(url)
            }
            _ = await settle(model)
            facts["asked"] = asked; facts["message"] = model.message ?? ""
            facts["knownParent"] = model.roots.first.map { $0.parent.leaf.map { String(format: "%02x", $0) }.joined() } ?? ""
            facts["fixable"] = model.entries.filter { $0.status.fixable }.count; facts["waiting"] = model.entries.filter { $0.reason == "FolderAccessNeeded" }.count
            model.prepare(); _ = await settle(model) { model.plan != nil || model.message != nil }
            facts["planned"] = model.plan?.operations.count ?? 0
            model.execute(); _ = await settle(model) { model.result != nil }
            facts["renamed"] = model.result?.succeeded ?? 0
            model.dismissResult(); _ = await settle(model)
            try? await Task.sleep(for: .seconds(1))
            await model.shutdown()
        case "panel":
            // The real folder panel, as the app shows it: what it says, where it opens, and that Cancel
            // goes through the panel's own handler and changes nothing. Nothing in it is clicked; choosing
            // a folder in it is the one step only a person can do.
            _ = await settle(model) { !model.entries.isEmpty }
            let window = NSApp.windows.first { $0.contentViewController is MainSidebarController }
            if model.folderRequest == nil { model.requestParentFolder() }
            facts["purpose"] = model.folderRequest.map { $0.purpose == .parent ? "parent" : $0.purpose == .input ? "input" : "history" } ?? ""
            var panel: NSOpenPanel?
            for _ in 0..<60 { panel = window?.attachedSheet as? NSOpenPanel; if panel != nil { break }; try? await Task.sleep(for: .milliseconds(100)) }
            facts["panelShown"] = panel != nil
            if let panel {
                try? await Task.sleep(for: .milliseconds(800))
                facts["panelMessage"] = panel.message ?? ""; facts["panelPrompt"] = panel.prompt ?? ""
                facts["panelFolder"] = panel.directoryURL?.lastPathComponent ?? ""
                facts["panelChoosesFoldersOnly"] = panel.canChooseDirectories && !panel.canChooseFiles && !panel.allowsMultipleSelection
                panel.cancel(nil)
                for _ in 0..<40 { if window?.attachedSheet == nil { break }; try? await Task.sleep(for: .milliseconds(100)) }
                facts["closedByCancel"] = window?.attachedSheet == nil
            }
            _ = await settle(model)
            facts["requestAfterCancel"] = model.folderRequest != nil; facts["needAfterCancel"] = model.accessNeed ?? ""; facts["entriesAfterCancel"] = model.entries.count
            facts["fixableAfterCancel"] = model.entries.filter { $0.status.fixable }.count
            await model.shutdown()
        case "look":
            // A folder on a drive the app does not rename on: it is listed, explained, and nothing is offered.
            _ = await settle(model) { !model.entries.isEmpty }
            facts["entries"] = model.entries.count; facts["fixable"] = model.entries.filter { $0.status.fixable }.count
            facts["reasons"] = Array(Set(model.entries.map(\.reason))).sorted(); facts["message"] = model.message ?? ""
            facts["labels"] = Array(Set(model.entries.filter { !$0.isDirectory }.map { CharacterPresentation.statusKey($0.status, name: $0.name, reason: $0.reason) })).sorted()
            facts["rootReason"] = model.entries.first { $0.path == model.roots.first }?.reason ?? ""; facts["accessNeed"] = model.accessNeed ?? ""
            model.prepare(); try? await Task.sleep(for: .seconds(2))
            facts["planned"] = model.plan?.operations.count ?? 0
            await model.shutdown()
        case "typing":
            // The rule editor's two fields, reached the way the keyboard reaches them: text goes in through
            // the field's own editor, and Tab is handed to the window as a key press.
            _ = await settle(model) { !model.entries.isEmpty }
            let window = NSApp.windows.first { $0.contentViewController is MainSidebarController }
            model.openWorkbench(); _ = await settle(model) { model.isWorkbench }
            try? await Task.sleep(for: .milliseconds(1500))
            func fields(_ view: NSView) -> [NSTextField] { ((view as? NSTextField).map { $0.isEditable ? [$0] : [] } ?? []) + view.subviews.flatMap(fields) }
            let all = window?.contentView.map(fields) ?? []
            facts["textFields"] = all.count; facts["rules"] = model.workbenchDraft.rules.map(\.kind.rawValue)
            func editor() -> NSTextView? { window?.firstResponder as? NSTextView }
            func pause(_ ms: Int = 300) async { try? await Task.sleep(for: .milliseconds(ms)) }
            func type(_ text: String) async { editor()?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0)); await pause() }
            func erase() async { editor()?.deleteBackward(nil); await pause() }
            func rule() -> RenameRule? { model.workbenchDraft.rules.first }
            /// Which of the two fields has the keyboard: what is typed now lands in it.
            func place() async -> String {
                let before = rule(), search = model.query; await type("q"); let after = rule(), found = model.query
                await erase()
                return after?.text != before?.text ? "find" : after?.replacement != before?.replacement ? "replace" : found != search ? "search" : "elsewhere"
            }
            var find: NSTextField?, replace: NSTextField?
            for field in all {
                window?.makeFirstResponder(field); await pause()
                let name = await place()
                if name == "find" { find = field } else if name == "replace" { replace = field }
            }
            facts["foundFields"] = find != nil && replace != nil
            func tab(shift: Bool = false) async {
                if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: shift ? [.shift] : [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window?.windowNumber ?? 0, context: nil, characters: shift ? "\u{19}" : "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48) { window?.sendEvent(event) }
                await pause(500)
            }
            func mark(_ text: String) async {
                editor()?.setMarkedText(text, selectedRange: NSRange(location: (text as NSString).length, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0)); await pause()
            }
            if let find, let replace {
                window?.makeFirstResponder(find); await pause(); await type("\u{AC00}")
                await tab(); facts["tabGoesTo"] = await place()
                await tab(shift: true); facts["shiftTabGoesTo"] = await place()
                // A Hangul syllable still being typed: Tab ends it and goes on to the other field.
                window?.makeFirstResponder(find); await pause(); await mark("\u{D55C}")
                facts["hangulMarked"] = editor()?.hasMarkedText() ?? false
                await tab(); facts["tabWhileTypingHangulGoesTo"] = await place(); facts["findAfterHangul"] = rule()?.text ?? ""; facts["leftAloneAfterHangul"] = tabsLeftToInputMethod
                // Where Tab goes when the app does not take it: from the second field nothing of the app's is in the way.
                window?.makeFirstResponder(replace); await pause(); await tab(); facts["plainTabFromReplaceGoesTo"] = await place()
                // Kana an input method is still choosing for: Tab is not taken by the app.
                window?.makeFirstResponder(find); await pause(); await mark("\u{306B}\u{307B}")
                facts["kanaMarked"] = editor()?.hasMarkedText() ?? false
                await tab(); facts["leftAloneAfterKana"] = tabsLeftToInputMethod; facts["kanaStillMarked"] = editor()?.hasMarkedText() ?? false; facts["focusAfterKanaTab"] = window?.firstResponder === replace.currentEditor() ? "replace" : window?.firstResponder === find.currentEditor() ? "find" : "elsewhere"
            }
        case "gui":
            // The real window, its sheets and its menus, with a folder handed over. Nothing is clicked:
            // the same actions the controls call are called, and the window is asked what it shows.
            _ = await settle(model) { !model.entries.isEmpty }
            let window = NSApp.windows.first { $0.contentViewController is MainSidebarController }
            facts["hasWindow"] = window != nil; facts["windowTitle"] = window?.title ?? ""
            facts["entries"] = model.entries.count; facts["fixable"] = model.entries.filter { $0.status.fixable }.count
            facts["toolbarItems"] = window?.toolbar?.items.count ?? 0
            // The list shows what the model selected: ticked boxes on screen against the selection.
            func boxes(_ view: NSView) -> [CheckCell] { (view as? CheckCell).map { [$0] } ?? view.subviews.flatMap(boxes) }
            try? await Task.sleep(for: .milliseconds(600))
            let shown = window?.contentView.map(boxes) ?? []
            facts["selected"] = model.selected.count; facts["ticked"] = shown.filter { $0.box.state == .on }.count; facts["boxes"] = shown.count
            // The list's own commands, called the way the menu and the keyboard reach them.
            func list(_ view: NSView) -> KeyTable? { (view as? KeyTable) ?? view.subviews.lazy.compactMap(list).first }
            if let table = window?.contentView.flatMap(list) {
                facts["selectAllOffered"] = table.validateUserInterfaceItem(NSMenuItem(title: "", action: #selector(NSResponder.selectAll(_:)), keyEquivalent: "a"))
                model.select("none"); try? await Task.sleep(for: .milliseconds(300))
                table.selectAll(nil); try? await Task.sleep(for: .milliseconds(300))
                facts["selectAllTicks"] = model.selected.count
                if let row = model.visible.firstIndex(where: { $0.status.fixable }) {
                    table.selectRowIndexes([row], byExtendingSelection: false); try? await Task.sleep(for: .milliseconds(300))
                    facts["returnOpens"] = table.open(); try? await Task.sleep(for: .milliseconds(900))
                    facts["detailsSheet"] = model.sheet == "inspector" && window?.attachedSheet != nil
                    model.sheet = nil; try? await Task.sleep(for: .milliseconds(700))
                }
                // The keys themselves, handed to the list's own key handler: Down moves, Space ticks, Return opens.
                func key(_ code: UInt16, _ characters: String, held: Bool = false) {
                    if let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window?.windowNumber ?? 0, context: nil, characters: characters, charactersIgnoringModifiers: characters, isARepeat: held, keyCode: code) { table.keyDown(with: event) }
                }
                if let row = model.visible.firstIndex(where: { $0.status.fixable }) {
                    table.selectRowIndexes([row], byExtendingSelection: false); try? await Task.sleep(for: .milliseconds(300))
                    let ticked = model.selected.count
                    key(49, " "); try? await Task.sleep(for: .milliseconds(300)); facts["spaceUnticks"] = model.selected.count == ticked - 1
                    key(49, " "); try? await Task.sleep(for: .milliseconds(300)); facts["spaceTicksAgain"] = model.selected.count == ticked
                    let at = table.selectedRow
                    key(125, "\u{F701}"); try? await Task.sleep(for: .milliseconds(300)); facts["downMoves"] = table.selectedRow == min(at + 1, table.numberOfRows - 1) && model.focused == model.visible[table.selectedRow].id
                    key(36, "\r"); try? await Task.sleep(for: .milliseconds(900)); facts["returnKeyOpens"] = model.sheet == "inspector"
                    model.sheet = nil; try? await Task.sleep(for: .milliseconds(700))
                    // What assistive apps are told about the list: a table of rows, a named cell under each column, a named tick box.
                    let name = table.view(atColumn: 1, row: row, makeIfNecessary: true) as? NameCell, tick = table.view(atColumn: 0, row: row, makeIfNecessary: true) as? CheckCell
                    facts["axTable"] = table.accessibilityRole()?.rawValue ?? ""; facts["axRows"] = table.accessibilityRows()?.count ?? -1
                    facts["axColumns"] = table.tableColumns.map(\.title)
                    facts["axCellRole"] = name?.accessibilityRole()?.rawValue ?? ""; facts["axCellLabel"] = name?.accessibilityLabel() ?? ""; facts["axCellValue"] = (name?.accessibilityValue() as? String) ?? ""
                    facts["axTickLabel"] = tick?.box.accessibilityLabel() ?? ""; facts["axTickRole"] = (tick?.box.cell as? NSButtonCell)?.accessibilityRole()?.rawValue ?? ""
                    facts["axRowRoles"] = (table.rowView(atRow: row, makeIfNecessary: true)?.accessibilityChildren() ?? []).map { ($0 as? NSAccessibilityProtocol)?.accessibilityRole()?.rawValue ?? "" }
                    facts["listFontName"] = name.map { _ in ResultList.Look(Palette("olive", systemDark: false), compact: false, language: model.settings.language).body.fontName } ?? ""
                    // A held Space ticks once: the repeats of the key do nothing.
                    let before = model.selected.count
                    key(49, " ", held: true); try? await Task.sleep(for: .milliseconds(300)); facts["heldSpaceDoesNothing"] = model.selected.count == before
                    // Among ticked rows only: unticking the focused row keeps the keyboard at its place, on the row that moved up.
                    model.filter = "SelectedOnly"; try? await Task.sleep(for: .milliseconds(600))
                    if model.visible.count > 2 {
                        table.selectRowIndexes([0], byExtendingSelection: false); try? await Task.sleep(for: .milliseconds(300))
                        let first = model.visible[0].id
                        key(49, " "); try? await Task.sleep(for: .milliseconds(600))
                        facts["staysAfterUntick"] = table.selectedRow == 0 && !model.visible.contains { $0.id == first } && model.focused == model.visible.first?.id
                        // Switching that filter on while the focused row is not ticked moves nothing and keeps the focus.
                        model.filter = "All"; try? await Task.sleep(for: .milliseconds(600))
                        if let index = model.visible.firstIndex(where: { $0.id == first }) {
                            table.selectRowIndexes([index], byExtendingSelection: false); try? await Task.sleep(for: .milliseconds(300))
                            model.filter = "SelectedOnly"; try? await Task.sleep(for: .milliseconds(600))
                            facts["filterMovesNothing"] = table.selectedRow == -1 && model.focused == first
                            model.filter = "All"; try? await Task.sleep(for: .milliseconds(600))
                            facts["focusBackWithAll"] = table.selectedRow == index
                        }
                        table.selectAll(nil); try? await Task.sleep(for: .milliseconds(300))
                    }
                    // The menu opened from the keyboard is for the focused row; with no row there is nothing to offer.
                    if let menu = table.menu {
                        table.selectRowIndexes([row], byExtendingSelection: false); try? await Task.sleep(for: .milliseconds(200))
                        menu.delegate?.menuNeedsUpdate?(menu); facts["menuForFocusedRow"] = menu.items.count
                        table.deselectAll(nil); try? await Task.sleep(for: .milliseconds(200))
                        menu.delegate?.menuNeedsUpdate?(menu); facts["menuWithoutRow"] = menu.items.count
                    }
                }
            }
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
            facts["selectedAfterRename"] = model.selected.count
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
                try? await Task.sleep(for: .seconds(1.5))
                let after = window?.contentView.map(boxes) ?? []
                facts["fixableAfterUndo"] = model.entries.filter { $0.status.fixable }.count
                facts["selectedAfterUndo"] = model.selected.count; facts["tickedAfterUndo"] = after.filter { $0.box.state == .on }.count; facts["enabledAfterUndo"] = after.filter { $0.box.isEnabled }.count
            }
            // What the menus offer in this edition.
            let menus = NSApp.mainMenu?.items ?? []
            let appMenu = menus.first?.submenu?.items.map(\.title).filter { !$0.isEmpty } ?? []
            facts["appMenu"] = appMenu
            facts["menuTitles"] = menus.compactMap { $0.submenu?.title }
            facts["supportAddress"] = AppInfo.support?.absoluteString ?? ""
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
            if CommandLine.arguments.contains("--probe-fast") { model.changeSettings { $0.renamesFast = true }; _ = await settle(model) }
            facts["fastSetting"] = model.settings.renamesFast
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
