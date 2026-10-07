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
