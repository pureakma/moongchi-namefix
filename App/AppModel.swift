import Foundation
import SwiftUI
import AppKit
import Darwin
import NameFixCore
import NameFixRuntime
import NameFixApplication

/// Planning stops here when a sandboxed app has to be let into a folder first.
struct FolderNeeded: Error, Sendable { let folder: RawPath }
@MainActor final class AppModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var watches = WatchLibrary()
    @Published var watchPending: Set<UUID> = []
    @Published var watchErrors: [UUID: String] = [:]
    private var watchers: [UUID: FolderWatcher] = [:]
    /// The allowed folder behind each running watch.
    private var watchGrants: [UUID: RawPath] = [:]
    private var activeWatchID: UUID?
    private var watchBaselines: [UUID: [Data: WatchedFile]] = [:]
    private var watchStore: WatchStore?
    private var watchTask: Task<Void, Never>?
    @Published var pipeline = RulePipeline()
    @Published var workbenchDraft = RulePipeline() { didSet { draftRevision &+= 1 } }
    private var draftRevision: UInt64 = 0
    private var appliedDraftRevision: UInt64? = 0
    func markWorkbenchPreviewApplied() { appliedDraftRevision = draftRevision }
    var isWorkbench: Bool { settings.workbenchEnabled == true }
    var hasUnappliedRules: Bool { isWorkbench && appliedDraftRevision != draftRevision }
    func openWorkbench() {
        guard !busy, plan == nil, result == nil else { return }
        sheet = nil
        changeSettings { $0.workbenchEnabled = true }
        if Self.applicable(workbenchDraft) == pipeline { markWorkbenchPreviewApplied() }
        // The list switches to batch rename's targets: files only, unless the options say otherwise.
        if !roots.isEmpty { scan() }
    }
    /// Batch Rename opens with a Replace Text rule ready to fill in. Returns its id when it was added.
    func addStarterRule() -> UUID? {
        guard isWorkbench, workbenchDraft.rules.isEmpty, workbenchDraft.mapping == nil else { return nil }
        let current = !hasUnappliedRules || Self.applicable(workbenchDraft) == pipeline
        let rule = RenameRule(.replace); workbenchDraft.rules = [rule]
        if current { markWorkbenchPreviewApplied() }
        return rule.id
    }
    /// A rule that still has nothing to search for does nothing. It is left out when rules are
    /// applied or stored, so an unfilled rule in the editor is not an error.
    static func applicable(_ pipeline: RulePipeline) -> RulePipeline {
        var value = pipeline
        value.rules.removeAll { $0.enabled && [.replace, .regex, .wildcard, .metadata].contains($0.kind) && $0.text.isEmpty }
        return value
    }
    func openQuickCleanup() {
        guard !busy, plan == nil, result == nil else { return }
        sheet = nil; activeWatchID = nil
        changeSettings { $0.workbenchEnabled = false }
        pipeline = RulePipeline(); appliedDraftRevision = nil
        scan()
    }
    @Published var recipes = RecipeLibrary()
    @Published private(set) var productAccess: ProductAccess = .free
    private var entitlement = Entitlement(state: .unavailable)
    private let entitlementProvider: any EntitlementProvider
    var transactionFinished: ((TransactionSummary) -> Void)?
    private var recipeStore: RecipeStore?
    private var recipeTask: Task<Void, Never>?
    @Published var roots: [RawPath] = []
    /// Sidebar tree of what was added. `folderFilter` narrows the list to one node; nil shows everything.
    @Published private(set) var folderTree: [FolderNode] = []
    @Published var folderFilter: RawPath? { didSet { if oldValue != folderFilter { refreshVisible() } } }
    @Published var sidebarCollapsed = false
    func rebuildFolderTree() { folderTree = FolderTree.build(roots: roots, entries: entries) }
    @Published var entries: [FileEntry] = [] { didSet { entriesRevision &+= 1; order = nil } }
    /// Display order of `entries` for one sort key. Sorting is the costly part of refreshing a large
    /// list and does not depend on the filter or the search text, so it is kept until either changes.
    private var order: (sort: String, indices: [Int])?
    private var entriesRevision: UInt64 = 0
    @Published var visible: [FileEntry] = [] { didSet { visibleRevision &+= 1 } }
    /// Counts replacements of the visible rows, so the list reloads only when they change.
    private(set) var visibleRevision: UInt64 = 0
    @Published var selected: Set<UUID> = []
    @Published var focused: UUID?
    @Published var query = "" { didSet { refreshVisible(debounce: true) } }
    @Published var filter = "All" { didSet { refreshVisible() } }
    @Published var sort = "Name" { didSet { refreshVisible() } }
    @Published var phase = ""
    @Published var scanned = 0
    @Published var completed = 0
    @Published var total = 0
    @Published var current = ""
    @Published var started = Date()
    @Published var cancelled = false
    @Published var message: String?
    @Published var plan: RenamePlan?
    @Published var result: TransactionSummary?
    @Published var history: [TransactionSummary] = []
    @Published var historyDetails: [HistoryDetail] = []
    @Published var recoveryDetails: [RecoveryInspection] = []
    @Published var historyID: UUID?
    @Published var historyLoading = false
    @Published var sheet: String?
    @Published var clipboard: String?
    @Published var clipboardTruncated = false
    @Published var dragActive = false
    @Published var searchFocus = false
    @Published var counts = ["TotalCaption": 0, "NeededCaption": 0, "ConflictCaption": 0]
    @Published var hiddenSelected = 0
    @Published var diagnosticsPreview = ""
    @Published var maskPaths = true
    @Published var ready = false
    private var shuttingDown = false
    private var generation = UUID()
    private var viewGeneration = UUID()
    private var scanToken = CancellationToken()
    private var transactionToken = CancellationToken()
    private var worker: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var filterWorker: Task<ListView, Error>?
    private var visibleIDs: Set<UUID> = []
    private(set) var viewComputationCount = 0
    private var settingsTask: Task<Void, Never>?
    private var leases: [AccessLease] = []
    /// Folders the user handed over for the current input; given back when the input is closed.
    private var inputGrants: [RawPath] = []
    /// Folders kept across launches because a finished operation there can still be undone.
    private var grantStore: GrantStore?
    private var grantLibrary = GrantLibrary()
    private var grantTask: Task<Void, Never>?
    /// A folder the user has to choose before something can go on. Only a sandboxed app asks:
    /// macOS lets it work in a folder only after the user picked that folder.
    struct FolderRequest: Equatable {
        /// `.parent`: the folder above an added folder, so that the added folder's own name can change.
        enum Purpose: Equatable { case input, parent, history(mode: String, id: UUID) }
        var folder: URL
        var purpose: Purpose
        /// The added folder a `.parent` request is for.
        var item = ""
        /// How many more folders will be asked for after this one.
        var remaining = 0
    }
    @Published var folderRequest: FolderRequest?
    /// What the listed items are waiting for: "FolderAccessNeeded" (an item's folder), "ParentFolderNeeded"
    /// (the folder above an added folder) or nil. The status line offers the choice from this, whatever notice it shows.
    @Published var accessNeed: String?
    /// False until the history has been read: an unread history is not an empty one.
    private var historyLoaded = false
    /// The folder held for each kept record's access, so it is given back when the record goes.
    private var historyGrants: [UUID: RawPath] = [:]
    private var queuedURLs: [URL] = []
    private var settingsStore: SettingsStore
    private(set) var store: JournalStore?
    private var coordinator: TransactionCoordinator?
    private var saveRevision = 0
    private let diagnosticLog: DiagnosticLog
    let dataRoot: URL
    /// The app grants every capability. Tests pass another provider to exercise the access checks.
    init(dataRoot override: URL? = nil, entitlementProvider: any EntitlementProvider = FullAccessEntitlementProvider()) {
        self.entitlementProvider = entitlementProvider
        dataRoot = override ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Moongchi/NameFix", isDirectory: true)
        diagnosticLog = DiagnosticLog(root: override?.appendingPathComponent("Logs") ?? FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Logs/Moongchi/NameFix"))
        settingsStore = SettingsStore(url: dataRoot.appendingPathComponent("settings.json"))
        if entitlementProvider is FullAccessEntitlementProvider { entitlement = Entitlement(state: .active); productAccess = .pro }
    }
    var busy: Bool { !phase.isEmpty }
    /// "Recovery" also names the confirmation step, so the running phase needs its own wording.
    var phaseLabel: String { t(phase == "Recovery" ? "ActivityRecovery" : phase) }
    var mutating: Bool { ["ActivityRename", "ActivityUndo", "Recovery"].contains(phase) }
    var canInput: Bool { result == nil && ready && !mutating && phase != "ActivityPreview" && plan == nil && sheet == nil }
    func t(_ key: String, _ values: String...) -> String { L10n.text(key, language: settings.language, values) }
    /// History reuses journal codes; a stopped rename must not read as a cancelled scan.
    func outcome(_ code: String) -> String { t(code == "Cancelled" ? "ResultCancelled" : code) }
    /// Short form of a notice for the footer line: its own summary when it has one, else its first sentence.
    func notice(_ key: String) -> String {
        let short = t(key + "Short")
        if short != key + "Short" { return short }
        let full = t(key)
        let end = full.firstIndex(where: { ".。!?！？".contains($0) }) ?? full.endIndex
        return String(full[..<end])
    }
    func d(_ date: Date) -> String { date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(Locale(identifier: L10n.language(settings.language)))) }
    func n(_ number: Int) -> String { number.formatted(.number.locale(Locale(identifier: L10n.language(settings.language)))) }
    func start() async {
        do { entitlement = try await entitlementProvider.verifiedEntitlement(); productAccess = entitlement.access() } catch { productAccess = .free; message = "EntitlementUnavailable" }
        // The app's own data folder is always its to use; records and settings are synced through it.
        try? FileManager.default.createDirectory(at: dataRoot, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        _ = try? AccessRoots.shared.grant(dataRoot)
        do { settings = try await settingsStore.load() } catch { message = (error as? FSError)?.code ?? "SettingsWarning" }
        // The app always opens on the repair screen, whichever screen was showing when it quit.
        settings.workbenchEnabled = false
        do {
            let root = dataRoot.appendingPathComponent("History")
            let store = try await Task.detached { try JournalStore(root: root) }.value
            self.store = store; coordinator = TransactionCoordinator(store: store)
            await reloadHistory()
        } catch { message = "JournalWriteFailed" }
        let grantStore = GrantStore(url: dataRoot.appendingPathComponent("access.json")); self.grantStore = grantStore
        do { grantLibrary = try await grantStore.load() } catch { message = "HistoryWarning" }
        restoreGrants(); pruneGrants()
        let recipeStore = RecipeStore(url: dataRoot.appendingPathComponent("recipes.json"))
        self.recipeStore = recipeStore
        do { recipes = try await recipeStore.load()
             // Every launch starts with no rules: rules left from last time could be run again by mistake. Saved presets are the way to keep rules.
             workbenchDraft = RulePipeline(); pipeline = RulePipeline(); if isWorkbench { markWorkbenchPreviewApplied() } else { appliedDraftRevision = nil } }
        catch { message = "RecipeReadOnly" }
        let watchStore = WatchStore(url: dataRoot.appendingPathComponent("watches.json")); self.watchStore = watchStore
        do { watches = try await watchStore.load(); watchBaselines = watches.baselines ?? [:] } catch { message = "WatchReadOnly" }
        restartWatches()
        ready = true; flushQueued(); checkFavorites()
    }
    func changeSettings(_ edit: (inout AppSettings) -> Void) {
        let old = settings
        edit(&settings)
        // A confirmed preview must not silently change its input traversal policy.
        if busy || plan != nil { settings.recursive = old.recursive }
        if !settings.rememberRecentFolders { settings.recentFolders = []; settings.recentAccess = nil }
        persist()
        if old.recursive != settings.recursive { scan() }
        if old.hideNormal != settings.hideNormal || old.language != settings.language { refreshVisible() }
    }
    func persist() {
        let snapshot = settings, previous = settingsTask, store = settingsStore
        saveRevision += 1
        settingsTask = Task { [weak self] in
            await previous?.value
            do { try await store.save(snapshot) } catch { self?.message = (error as? FSError)?.code ?? "SettingsSaveFailed" }
        }
    }
    // MARK: Favourite and recent folders — shortcuts to add a folder; neither one watches anything

    var favorites: [FavoriteFolder] { settings.favoriteFolders ?? [] }
    /// Favourites that could not be opened when last checked: moved away, deleted or unreadable.
    @Published private(set) var favoriteProblems: Set<UUID> = []
    /// Recent folders not already pinned, so a folder is listed once.
    var recentShortcuts: [String] {
        guard settings.rememberRecentFolders else { return [] }
        let pinned = Set(favorites.map { Data($0.path.utf8) })
        return settings.recentFolders.filter { !pinned.contains(Data($0.utf8)) }
    }
    func isFavorite(_ path: RawPath) -> Bool { favorites.contains { Data($0.path.utf8) == path.bytes } }
    /// The folder a favourite points to now, or nil when it cannot be opened.
    nonisolated static func resolve(_ favorite: FavoriteFolder) -> URL? { open(favorite)?.url }
    /// The folder, and whether its saved bookmark should be replaced by a fresh one.
    nonisolated static func open(_ favorite: FavoriteFolder) -> (url: URL, stale: Bool)? {
        var url = URL(fileURLWithPath: favorite.path), stale = false
        if let bookmark = favorite.bookmark, let found = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) { url = found }
        // A bookmarked folder can be looked at only while its access is in use.
        let lease = AccessLease(url); defer { withExtendedLifetime(lease) {} }
        return usableFolder(url) ? (url, stale) : nil
    }
    nonisolated static func usableFolder(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue && FileManager.default.isReadableFile(atPath: url.path)
    }
    func addFavorite(_ url: URL) {
        guard Self.usableFolder(url), !isFavorite(RawPath(url.path)), favorites.count < AppSettings.favoriteLimit else { return }
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        changeSettings { $0.favoriteFolders = ($0.favoriteFolders ?? []) + [FavoriteFolder(path: url.path, bookmark: bookmark)] }
    }
    /// Takes the shortcut away. The folder and its files are not touched.
    func removeFavorite(_ id: UUID) {
        favoriteProblems.remove(id)
        changeSettings { $0.favoriteFolders?.removeAll { $0.id == id } }
    }
    /// Points an unavailable favourite at the folder the user picked again.
    func relinkFavorite(_ id: UUID, to url: URL) {
        guard Self.usableFolder(url) else { return }
        let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        changeSettings { settings in
            guard let index = settings.favoriteFolders?.firstIndex(where: { $0.id == id }) else { return }
            // Picking a folder that is already a favourite keeps one entry for it.
            if settings.favoriteFolders?.contains(where: { $0.id != id && Data($0.path.utf8) == Data(url.path.utf8) }) == true { settings.favoriteFolders?.remove(at: index) }
            else { settings.favoriteFolders?[index].path = url.path; settings.favoriteFolders?[index].bookmark = bookmark }
        }
        favoriteProblems.remove(id)
    }
    /// Adds the favourite to the current input and checks it now. A favourite that cannot be
    /// opened is marked and reported instead of being skipped.
    func openFavorite(_ favorite: FavoriteFolder) {
        guard canInput else { message = "BusyDropRejected"; return }
        guard let (url, stale) = Self.open(favorite) else { favoriteProblems.insert(favorite.id); message = "FavoriteUnavailable"; return }
        favoriteProblems.remove(favorite.id)
        add([url])
        // The folder moved, or the system says the bookmark is getting old: keep the shortcut current.
        let fresh = stale ? AccessRoots.shared.bookmark(for: RawPath(url.path)) : nil
        if url.path != favorite.path || fresh != nil {
            changeSettings { settings in
                guard let index = settings.favoriteFolders?.firstIndex(where: { $0.id == favorite.id }) else { return }
                settings.favoriteFolders?[index].path = url.path
                if let fresh { settings.favoriteFolders?[index].bookmark = fresh }
            }
        }
    }
    func openRecent(_ path: String) {
        var url = URL(fileURLWithPath: path), stale = false
        if let bookmark = settings.recentAccess?[path], let found = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) { url = found }
        let lease = AccessLease(url); defer { withExtendedLifetime(lease) {} }
        guard Self.usableFolder(url) else {
            message = "RecentUnavailable"
            changeSettings { $0.recentFolders.removeAll { Data($0.utf8) == Data(path.utf8) }; $0.recentAccess?[path] = nil }
            return
        }
        add([url])
    }
    /// Refreshes which favourites can be opened, off the main thread.
    func checkFavorites() {
        let list = favorites
        Task { [weak self] in
            let missing = await Task.detached { Set(list.filter { Self.resolve($0) == nil }.map(\.id)) }.value
            guard let self, favorites.map(\.id) == list.map(\.id) else { return }
            favoriteProblems = missing
        }
    }
    func add(_ urls: [URL], fromOS: Bool = false) {
        let local = urls.filter { $0.isFileURL && ($0.host == nil || $0.host == "" || $0.host == "localhost") }
        guard !local.isEmpty else { return }
        guard canInput else {
            if fromOS && queuedURLs.count + local.count <= 1000 { queuedURLs.append(contentsOf: local); message = "QueuedInputs" }
            else { message = "BusyDropRejected" }
            return
        }
        activeWatchID = nil
        leases.append(contentsOf: local.map(AccessLease.init))
        var seen = Set(roots)
        for url in local {
            var path = RawPath(url.path), held: RawPath?
            // A folder the user handed over is a place the app may work in.
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true, let root = try? AccessRoots.shared.grant(url) {
                held = root.path
                if AccessRoots.shared.restricted { path = root.path }
            }
            if seen.insert(path).inserted { roots.append(path); if let held { inputGrants.append(held) } }
            // The same folder again: it is already listed and already held once.
            else if let held { AccessRoots.shared.release(held) }
        }
        respellLooseRoots()
        askForLooseFolders()
        scan()
    }
    /// A sandboxed app can read and rename an item only through a folder the user allowed.
    /// A file handed over on its own needs its folder; the user is asked for exactly that one.
    /// Files in the same folder are asked for once; files from several folders, one folder at a time,
    /// and a folder the app can already reach again (a favourite, a watched or recent folder) is not asked for.
    func requestFolderForLooseItems() {
        guard !busy, plan == nil else { return }
        // Folders reached again through kept access are listed by a new scan; nothing else changes here.
        if askForLooseFolders() { scan() }
    }
    /// Asks for the first folder that is still missing. True when kept access made a folder reachable instead.
    @discardableResult private func askForLooseFolders() -> Bool {
        guard AccessRoots.shared.restricted, folderRequest == nil else { return false }
        func missing() -> [RawPath] {
            var folders: [RawPath] = []
            for root in roots where AccessRoots.shared.root(reaching: root.parent) == nil && !AccessRoots.shared.isRoot(root) && !folders.contains(root.parent) { folders.append(root.parent) }
            return folders
        }
        let before = missing()
        // Kept access may respell the items it reaches, so what is still missing is looked at again afterwards.
        let reused = before.reduce(false) { reuseKeptAccess($1) || $0 }
        let folders = reused ? missing() : before
        guard let first = folders.first else { return reused }
        folderRequest = FolderRequest(folder: URL(fileURLWithPath: first.display, isDirectory: true), purpose: .input, remaining: folders.count - 1)
        return reused
    }
    /// The user wants an added folder's own name changed too: ask for the folder above it.
    /// Nothing is asked while only the items inside are renamed.
    func requestParentFolder() {
        guard AccessRoots.shared.restricted, folderRequest == nil, !busy, plan == nil,
              let folder = entries.first(where: { $0.reason == "ParentFolderNeeded" })?.path else { return }
        if reuseKeptAccess(folder.parent) { if message == "ParentFolderNeeded" { message = nil }; scan(); return }
        folderRequest = FolderRequest(folder: URL(fileURLWithPath: folder.parent.display, isDirectory: true), purpose: .parent, item: String(data: folder.leaf, encoding: .utf8) ?? "")
    }
    /// Reaches `folder` through access the user already gave and asked to keep: a favourite, a watched
    /// folder or a remembered recent folder that is this folder or contains it. The kept bookmark is
    /// used only if the place it leads to now really contains the folder; anything else is given back.
    private func reuseKeptAccess(_ folder: RawPath) -> Bool {
        guard AccessRoots.shared.restricted else { return false }
        // The folder as it was given, or as the system spells it: an item handed over on its own often
        // arrives with its folder's letters spelled apart, and an allowed folder is known by its stored name.
        func reachable() -> Bool {
            let system = Self.systemSpelling(of: URL(fileURLWithPath: folder.display, isDirectory: true)).flatMap { Self.sameSpelling($0, folder) ? $0 : nil }
            for candidate in [folder, system].compactMap({ $0 }) { if let fd = try? FS.openDirectory(candidate) { close(fd); return true } }
            return false
        }
        if reachable() { return true }
        let target = folder.display
        func covers(_ path: String) -> Bool { target == path || target.hasPrefix(path.hasSuffix("/") ? path : path + "/") }
        var kept: [Data] = favorites.compactMap { covers($0.path) ? $0.bookmark : nil }
        kept += watches.folders.compactMap { covers($0.path) ? $0.bookmark : nil }
        kept += (settings.recentAccess ?? [:]).compactMap { covers($0.key) ? $0.value : nil }
        for bookmark in kept {
            var stale = false
            // A bookmark that had to guess is not trusted here, and a folder that does not lead there is not taken.
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale),
                  !stale, let root = try? AccessRoots.shared.grant(url, if: { _ in reachable() }) else { continue }
            inputGrants.append(root.path); respellLooseRoots()
            return true
        }
        return false
    }
    /// The user chose a folder in answer to a request.
    func allowFolder(_ url: URL) {
        // A request withdrawn while the panel was open (its items were removed) keeps nothing.
        guard let request = folderRequest else { return }
        folderRequest = nil
        func reachable(_ path: RawPath) -> Bool { if let fd = try? FS.openDirectory(path) { close(fd); return true }; return false }
        let wanted = RawPath(request.folder.path)
        var recorded = false, renamed = false
        if case .history = request.purpose { recorded = true }
        let taken: AuthorizedRoot?
        do {
            // The folder that was asked for has to be reachable with the chosen one in place. Any other
            // folder helps nothing: it is not taken, and the choice stays open.
            taken = try AccessRoots.shared.grant(url) { _ in
                // With the folder allowed, its items can be known by the path the system reports for it.
                respellLooseRoots()
                let system = Self.systemSpelling(of: request.folder).flatMap { Self.sameSpelling($0, wanted) ? $0 : nil }
                // A history record names its folder byte for byte, and Undo looks for exactly that. A folder
                // whose name was respelled since is not the recorded place: accepting it would only ask again.
                if recorded { renamed = !reachable(wanted) && system.map(reachable) == true; return reachable(wanted) }
                return reachable(system ?? wanted)
            }
        } catch { message = "FolderAccessNeeded"; return }
        guard let root = taken else { message = renamed ? "UnavailableHelp" : "WrongFolderChosen"; return }
        inputGrants.append(root.path)
        if ["FolderAccessNeeded", "UndoNeedsFolder", "ParentFolderNeeded", "WrongFolderChosen"].contains(message) { message = nil }
        if case .history(let mode, let id) = request.purpose { prepare(mode: mode, historyID: id) } else { askForLooseFolders(); scan() }
    }
    /// Items handed over on their own are known by the path the system reports for their folder.
    /// A file URL often spells a folder's letters separately although its name is stored with them
    /// joined, and the allowed folder is compared by its stored name. Only the spelling is taken
    /// over: a path that differs in any other way (through a link, for one) stays as it was given.
    /// The folder is only looked at here; whether it may be worked in is still decided by the rule.
    private func respellLooseRoots() {
        guard AccessRoots.shared.restricted else { return }
        var known: [RawPath: RawPath?] = [:], seen = Set<RawPath>()
        roots = roots.map { root in
            guard !AccessRoots.shared.isRoot(root) else { return root }
            let real: RawPath?
            if let cached = known[root.parent] { real = cached } else {
                real = Self.systemSpelling(of: URL(fileURLWithPath: root.parent.display, isDirectory: true)).flatMap { $0 != root.parent && Self.sameSpelling($0, root.parent) ? $0 : nil }
                known[root.parent] = real
            }
            return real.map { $0.appending(root.leaf) } ?? root
        }.filter { seen.insert($0).inserted }
    }
    /// The path the system itself reports for a folder this process can open, or nil.
    nonisolated static func systemSpelling(of folder: URL) -> RawPath? {
        let fd = Darwin.open(folder.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { return nil }
        defer { Darwin.close(fd) }
        return try? FS.rawDirectoryPath(fd)
    }
    /// The same path apart from letter case and how letters are composed. A path that differs
    /// in any other way (through a link, for one) is another path.
    nonisolated static func sameSpelling(_ a: RawPath, _ b: RawPath) -> Bool {
        a.display.precomposedStringWithCanonicalMapping.lowercased() == b.display.precomposedStringWithCanonicalMapping.lowercased()
    }
    func declineFolder() { folderRequest = nil }
    /// Reaches again the folders that finished operations may still be undone in.
    private func restoreGrants() {
        guard AccessRoots.shared.restricted else { return }
        var changed = false
        for index in grantLibrary.grants.indices {
            let stored = grantLibrary.grants[index]
            // Held already and still leading there: it is taken once, however often Undo is asked for.
            if let held = historyGrants[stored.id], let fd = try? FS.openDirectory(held) { close(fd); continue }
            let (result, renewed) = GrantLibrary.resolve(stored)
            guard case .granted(let root) = result else { continue }
            if let earlier = historyGrants[stored.id] { AccessRoots.shared.release(earlier) }
            historyGrants[stored.id] = root.path
            if let renewed { grantLibrary.grants[index].bookmark = renewed; changed = true }
        }
        if changed { saveGrants() }
    }
    private func saveGrants() {
        guard let grantStore else { return }
        let library = grantLibrary, previous = grantTask
        // Saved in order, and finished before the app quits.
        grantTask = Task { [weak self] in await previous?.value; do { try await grantStore.save(library) } catch { self?.message = "HistoryWarning" } }
    }
    /// Keeps the way back to the folders an operation ran in, for as long as its record is kept.
    private func keepGrants(for transaction: UUID, operations: [RenameOperation]) {
        guard AccessRoots.shared.restricted else { return }
        var seen = Set<RawPath>()
        for operation in operations {
            guard let root = AccessRoots.shared.root(reaching: operation.source.parent), seen.insert(root.path).inserted else { continue }
            if let index = grantLibrary.grants.firstIndex(where: { $0.path == root.path.display && $0.identity == root.identity }) {
                if !grantLibrary.grants[index].transactions.contains(transaction) { grantLibrary.grants[index].transactions.append(transaction) }
            } else if let bookmark = AccessRoots.shared.bookmark(for: root.path) {
                grantLibrary.grants.append(StoredGrant(root: root, bookmark: bookmark, transaction: transaction))
            }
        }
        if !seen.isEmpty { saveGrants() }
    }
    /// Access is kept only while a record that needs it exists.
    private func pruneGrants() {
        guard historyLoaded else { return }
        let kept = Set(history.map(\.id)), before = grantLibrary.grants
        grantLibrary.grants = before.compactMap { grant in var g = grant; g.transactions.removeAll { !kept.contains($0) }; return g.transactions.isEmpty ? nil : g }
        for gone in Set(before.map(\.id)).subtracting(grantLibrary.grants.map(\.id)) { if let held = historyGrants.removeValue(forKey: gone) { AccessRoots.shared.release(held) } }
        if grantLibrary.grants != before { saveGrants() }
    }
    /// Menu and menu-bar commands must not stack a sheet on a confirmation, result or running rename.
    func present(_ name: String) { guard plan == nil, result == nil, !mutating else { return }; sheet = name }
    static let fastTipKey = "NameFix.fastRenameTipShown"
    func dismissResult() { result = nil; flushQueued() }
    func cancelPreview() { plan = nil; flushQueued() }
    /// Gives back what was allowed for items that are no longer listed: a folder, the folder above an
    /// added folder, the folder of a lone file. A hold stays while anything listed lies in it.
    private func releaseUnusedInputGrants() {
        var kept: [RawPath] = []
        for grant in inputGrants {
            let inside = grant.bytes + Data([47])
            if roots.contains(where: { $0 == grant || $0.bytes.starts(with: inside) }) { kept.append(grant) } else { AccessRoots.shared.release(grant) }
        }
        inputGrants = kept
    }
    func flushQueued() {
        guard canInput, !queuedURLs.isEmpty else { return }
        let urls = queuedURLs; queuedURLs = []; add(urls)
    }
    func remove(_ path: RawPath?) {
        guard !busy, plan == nil else { return }
        activeWatchID = nil
        if let path {
            roots.removeAll { $0 == path }
            releaseUnusedInputGrants()
        } else {
            roots = []; leases = []
            inputGrants.forEach(AccessRoots.shared.release); inputGrants = []
        }
        if folderRequest?.purpose == .input { folderRequest = nil }
        scan()
    }
    func scan(clearSelection: Bool = false) {
        guard !shuttingDown, !mutating, phase != "ActivityPreview", plan == nil else { return }
        scanToken.cancel(); scanToken = CancellationToken(); generation = UUID()
        let id = generation, token = scanToken, inputs = roots, recursive = activeWatchID == nil ? settings.recursive : true
        let watchID = activeWatchID, baseline = activeWatchID.flatMap { watchBaselines[$0] } ?? [:]
        let oldEntries = entries, oldSelected = selected, pipeline = pipeline, access = entitlement.access(), batch = isWorkbench
        let recipient = self
        phase = "ActivityScan"; scanned = 0; started = Date(); cancelled = false
        worker = Task { [weak self] in
            let presentation = await Task.detached(priority: .userInitiated) {
                var scan = Scanner.scan(roots: inputs, recursive: recursive, token: token, target: pipeline.target) { count in
                    Task { @MainActor [recipient] in if recipient.generation == id { recipient.scanned = count } }
                }
                if watchID != nil {
                    do { scan.entries = try await WatchSnapshot.candidates(scan.entries, baseline: baseline, token: token, pairExtensions: pipeline.pairExtensions ?? []) }
                    catch { scan.cancelled = token.cancelled; scan.entries = [] }
                }
                if batch || !pipeline.rules.isEmpty || pipeline.mapping != nil || !(pipeline.pairExtensions ?? []).isEmpty {
                    do { scan.entries = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: access, token: token, batch: batch ? true : nil) }
                    catch { if token.cancelled { scan.cancelled = true }; scan.entries = scan.entries.map { item in var e = item; if !e.status.isError { e.status = .unsupported; e.reason = (error as? RuleFailure)?.rawValue ?? (error as? FSError)?.code ?? "OperationError" }; return e } }
                }
                let old = Dictionary(oldEntries.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
                var selection = Set<UUID>(), needed = 0, conflicts = 0
                for i in scan.entries.indices {
                    let previous = old[scan.entries[i].path]
                    let same = previous?.identity == scan.entries[i].identity
                    if same, let previous { scan.entries[i].id = previous.id }
                    if scan.entries[i].status.fixable {
                        needed += 1
                        if !clearSelection && (!same || previous?.status.fixable != true || oldSelected.contains(scan.entries[i].id)) { selection.insert(scan.entries[i].id) }
                    }
                    if scan.entries[i].status == .conflict { conflicts += 1 }
                }
                return (scan, selection, ["TotalCaption": scan.entries.count, "NeededCaption": needed, "ConflictCaption": conflicts], FolderTree.build(roots: scan.roots, entries: scan.entries))
            }.value
            guard let self, generation == id else { return }
            let scan = presentation.0
            entries = scan.entries; roots = scan.roots; selected = presentation.1
            folderTree = presentation.3
            if let folder = folderFilter, !FolderTree.paths(folderTree).contains(folder) { folderFilter = nil }
            if let watchID {
                var updated = false
                for entry in entries where entry.status == .normal { if let identity = entry.identity, let version = entry.contentVersion { watchBaselines[watchID, default: [:]][WatchSnapshot.key(entry.path)] = WatchedFile(identity: identity, version: version); updated = true } }
                if updated { saveWatches() }
            }
            if !entries.contains(where: { $0.id == focused }) { focused = nil }
            counts = presentation.2
            phase = ""; scanned = entries.count
            var need: String?
            for entry in scan.entries { if entry.reason == "FolderAccessNeeded" { need = entry.reason; break }; if entry.reason == "ParentFolderNeeded" { need = entry.reason } }
            accessNeed = need
            if scan.limited { message = "ScanLimit" } else if scan.cancelled { message = "Cancelled" }
            // Say once, in the status line, why a whole location is left alone. Nothing is shown for supported places.
            else if let place = scan.entries.first(where: { VolumeSupport.locationReasons.contains($0.reason) })?.reason { message = place }
            else if accessNeed != nil { message = accessNeed }
            else if let shown = message, VolumeSupport.locationReasons.contains(shown) || shown == "FolderAccessNeeded" || shown == "ParentFolderNeeded" { message = nil }
            if settings.rememberRecentFolders {
                let directories = scan.entries.filter { $0.isDirectory && scan.roots.contains($0.path) }.map { $0.path.display }
                var list = directories + settings.recentFolders
                var unique = Set<Data>(); list = list.filter { unique.insert(Data($0.utf8)).inserted }
                settings.recentFolders = Array(list.prefix(10))
                // A sandboxed app can reopen a remembered folder only with a bookmark; it is kept exactly as long as the entry.
                if AccessRoots.shared.restricted {
                    var access = settings.recentAccess ?? [:]
                    for directory in directories where access[directory] == nil { access[directory] = AccessRoots.shared.bookmark(for: RawPath(directory)) }
                    settings.recentAccess = access.filter { settings.recentFolders.contains($0.key) }
                }
                persist()
            }
            refreshVisible(); flushQueued()
        }
    }
    func refreshVisible(debounce: Bool = false) {
        searchTask?.cancel(); filterWorker?.cancel(); viewGeneration = UUID()
        let id = viewGeneration, items = entries, revision = entriesRevision, selected = selected, query = query, filter = filter, sort = sort, hide = settings.hideNormal, scope = folderFilter.map(FolderTree.Scope.init)
        let known = order?.sort == sort ? order?.indices : nil
        searchTask = Task { [weak self] in
            if debounce { do { try await Task.sleep(for: .milliseconds(180)) } catch { return } }
            guard !Task.isCancelled else { return }
            guard let owner = self else { return }
            owner.viewComputationCount += 1
            let work = Task.detached(priority: .userInitiated) { () throws -> ListView in
                let indices = try known ?? Self.sortedIndices(items, by: sort)
                let rows = try await Self.filtered(items, in: indices, sliced: !query.isEmpty) { e in
                    if let scope, !scope.contains(e.path) { return false }
                    if hide && e.status == .normal { return false }
                    if filter == "NeedsNormalization" && !e.status.fixable { return false }
                    if filter == "Normal" && e.status != .normal { return false }
                    if filter == "Conflict" && e.status != .conflict { return false }
                    if filter == "Errors" && !e.status.isError { return false }
                    if filter == "SelectedOnly" && !selected.contains(e.id) { return false }
                    // The name each item will have, whether or not it changes.
                    if filter == "WindowsNames" && NameRules.windowsIssues(e.proposed).isEmpty { return false }
                    guard !query.isEmpty else { return true }
                    // The path ends with the name, so searching it covers both, unless the path cannot be shown as text.
                    let path = e.path.display
                    return path.localizedStandardContains(query) || e.preview.localizedStandardContains(query) || (!path.hasPrefix("/") && e.name.localizedStandardContains(query))
                }
                return ListView(rows: rows, ids: Set(rows.map(\.id)), indices: indices)
            }
            owner.filterWorker = work
            guard let view = try? await work.value, let self, viewGeneration == id, !Task.isCancelled else { return }
            if revision == entriesRevision { order = (sort, view.indices) }
            visible = view.rows; visibleIDs = view.ids
            hiddenSelected = self.selected.subtracting(visibleIDs).count
            // Selection may have changed while a detached SelectedOnly filter ran.
            if filter == "SelectedOnly", selected != self.selected { refreshVisible() }
        }
    }
    private struct ListView: Sendable { var rows: [FileEntry]; var ids: Set<UUID>; var indices: [Int] }
    /// Positions of `items` in display order. Each sort key is built once, not once per comparison.
    nonisolated private static func sortedIndices(_ items: [FileEntry], by sort: String) throws -> [Int] {
        // Equal keys fall back to the raw path bytes, compared in place.
        func ascending(_ a: Int, _ b: Int, _ result: ComparisonResult) -> Bool {
            guard result == .orderedSame else { return result == .orderedAscending }
            return items[a].path.bytes.withUnsafeBytes { x in
                items[b].path.bytes.withUnsafeBytes { y in
                    let difference = memcmp(x.baseAddress, y.baseAddress, min(x.count, y.count))
                    return difference != 0 ? difference < 0 : x.count < y.count
                }
            }
        }
        if sort == "Status" {
            // A handful of distinct values: rank them once and compare the ranks.
            let names = Set(items.map(\.status.rawValue)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            let rank = Dictionary(uniqueKeysWithValues: names.enumerated().map { ($1, $0) }), keys = items.map { rank[$0.status.rawValue] ?? 0 }
            return try items.indices.sorted { a, b in
                try Task.checkCancellation()
                return ascending(a, b, keys[a] == keys[b] ? .orderedSame : keys[a] < keys[b] ? .orderedAscending : .orderedDescending)
            }
        }
        let keys = items.map { sort == "Path" ? $0.path.display : $0.name }
        return try items.indices.sorted { a, b in
            try Task.checkCancellation()
            return ascending(a, b, keys[a].localizedStandardCompare(keys[b]))
        }
    }
    /// The entries that pass `keep`, in the given order. A text search is the costly check on a
    /// large list, so it runs in parallel slices; the cheap checks are faster in one pass.
    nonisolated private static func filtered(_ items: [FileEntry], in indices: [Int], sliced: Bool, keep: @escaping @Sendable (FileEntry) -> Bool) async throws -> [FileEntry] {
        let size = sliced ? max(4_096, indices.count / (ProcessInfo.processInfo.activeProcessorCount * 2) + 1) : max(1, indices.count)
        return try await withThrowingTaskGroup(of: (Int, [FileEntry]).self) { group in
            for (part, start) in stride(from: 0, to: indices.count, by: size).enumerated() {
                group.addTask {
                    var rows: [FileEntry] = []
                    for index in indices[start..<min(start + size, indices.count)] {
                        try Task.checkCancellation()
                        if keep(items[index]) { rows.append(items[index]) }
                    }
                    return (part, rows)
                }
            }
            var parts = [[FileEntry]](repeating: [], count: (indices.count + size - 1) / size)
            for try await (part, rows) in group { parts[part] = rows }
            return parts.flatMap { $0 }
        }
    }
    func toggle(_ entry: FileEntry) {
        guard entry.status.fixable, !busy, plan == nil else { return }
        let wasSelected = selected.contains(entry.id)
        if wasSelected { selected.remove(entry.id) } else { selected.insert(entry.id) }
        if !visibleIDs.contains(entry.id) { hiddenSelected += wasSelected ? -1 : 1 }
        if filter == "SelectedOnly" { refreshVisible() }
    }
    func select(_ action: String) {
        guard !busy, plan == nil else { return }
        let ids = Set((action == "all" ? entries : visible).filter { $0.status.fixable }.map(\.id))
        if action == "none" { selected = [] }
        else if action == "clearVisible" { selected.subtract(ids) }
        else if action == "invert" { selected.formSymmetricDifference(ids) }
        else { selected.formUnion(ids) }
        hiddenSelected = selected.subtracting(visibleIDs).count
        if filter == "SelectedOnly" { refreshVisible() }
    }
    func prepare(mode: String = "rename", historyID: UUID? = nil) {
        if mode == "rename", hasUnappliedRules { message = "UnappliedRules"; return }
        guard !busy, plan == nil, let store else { return }
        if mode == "rename", pipeline.requiresPro && entitlement.access() != .pro { message = "ProRequired"; return }
        phase = "ActivityPreview"; started = Date()
        let items = entries, selection = selected, gen = generation
        // A volume may have been connected again since the app opened: try the kept folders once more.
        if historyID != nil { restoreGrants() }
        let kept = grantLibrary.grants
        worker = Task { [weak self] in
            do {
                let fresh = try await Task.detached {
                    if let historyID {
                        // A sandboxed app can undo only inside a folder it is allowed in. Ask for that folder instead of calling the items changed.
                        if let folder = try History.folderNeeded(store: store, id: historyID, kept: kept) { throw FolderNeeded(folder: folder) }
                        return try mode == "recovery" ? History.recovery(store: store, id: historyID, generation: gen) : History.undo(store: store, id: historyID, generation: gen)
                    }
                    return try Planning.make(entries: items, selected: selection, generation: gen)
                }.value
                guard let self else { return }
                phase = ""; sheet = nil
                if fresh.operations.isEmpty { message = fresh.excluded > 0 ? "NoChangesExcluded" : "NoChanges" } else { plan = fresh }
            } catch let needed as FolderNeeded {
                guard let self, let historyID else { return }
                phase = ""; sheet = nil; message = "UndoNeedsFolder"
                folderRequest = FolderRequest(folder: URL(fileURLWithPath: needed.folder.display, isDirectory: true), purpose: .history(mode: mode, id: historyID))
            } catch { self?.phase = ""; self?.message = (error as? FSError)?.code ?? "OperationError" }
        }
    }
    func execute() {
        guard let plan, let coordinator, plan.generation == generation, !busy else { return }
        if plan.mode == "rename", pipeline.requiresPro && entitlement.access() != .pro { self.plan = nil; message = "ProRequired"; return }
        self.plan = nil; phase = plan.mode == "rename" ? "ActivityRename" : plan.mode == "undo" ? "ActivityUndo" : "Recovery"
        completed = 0; total = plan.operations.count; started = Date(); cancelled = false
        transactionToken = CancellationToken(); let token = transactionToken
        let recipient = self, fast = settings.renamesFast
        worker = Task { [weak self] in
            do {
                let summary = try await coordinator.execute(plan, token: token, fast: fast) { progress in
                    Task { @MainActor [recipient] in recipient.completed = progress.completed; recipient.total = progress.total; recipient.current = progress.current }
                }
                guard let self else { return }
                // The rename already ran; a bookkeeping failure here must not hide its result.
                if let store {
                    do {
                        if let watchID = activeWatchID {
                            let verified = try await Task.detached { try History.details(store: store, id: summary.id).filter { $0.state == "Verified" }.map(\.operation) }.value
                            for operation in verified {
                                watchBaselines[watchID]?.removeValue(forKey: WatchSnapshot.key(operation.source))
                                if let version = operation.contentVersion { watchBaselines[watchID, default: [:]][WatchSnapshot.key(operation.finalPath)] = WatchedFile(identity: operation.identity, version: version) }
                            }
                            saveWatches()
                        }
                        let oldRoots = roots, oldRecent = settings.recentFolders.map(RawPath.init)
                        let remapped = try await Task.detached { try History.remap(oldRoots + oldRecent, store: store, id: summary.id) }.value
                        roots = Array(remapped.prefix(oldRoots.count))
                        if settings.rememberRecentFolders { settings.recentFolders = remapped.dropFirst(oldRoots.count).map(\.display); persist() }
                    } catch { message = (error as? FSError)?.code ?? "HistoryWarning" }
                }
                keepGrants(for: summary.id, operations: plan.operations)
                // Once, after a long run with the safest record: say that Settings has a faster way.
                // Only where the faster way would really be used: not for an external drive.
                var tip = false
                if !fast, plan.operations.count >= 200, Date().timeIntervalSince(started) >= 5, !UserDefaults.standard.bool(forKey: Self.fastTipKey),
                   let journal = store?.root { tip = TransactionCoordinator.fastAllowed(plan.operations, journal: journal) }
                phase = ""; result = summary; transactionFinished?(summary)
                if settings.diagnostics { do { try await diagnosticLog.record(code: summary.status, transaction: summary.id, count: summary.succeeded) } catch { message = "DiagnosticsError" } }
                await reloadHistory()
                // Shown only if nothing more important took the line, and counted as shown only then.
                if tip, message == nil { message = "FastRenameTip"; UserDefaults.standard.set(true, forKey: Self.fastTipKey) }
                // "Clear selection when done" is about a finished rename. After an undo or a recovery the names
                // need fixing again, and they come back selected, as they were when first scanned.
                scan(clearSelection: settings.clearSelectionAfterRun && plan.mode == "rename")
            } catch {
                // The operation could not be started or its record could not be written. The list is read again
                // so it shows what is on disk; whatever did happen is in History.
                self?.phase = ""; self?.message = (error as? FSError)?.code ?? "OperationError"; await self?.reloadHistory(); self?.scan(clearSelection: false)
            }
        }
    }
    func cancel() { cancelled = true; scanToken.cancel(); transactionToken.cancel() }
    func shutdown() async { shuttingDown = true; ready = false; watchers.values.forEach { $0.stop() }; watchers = [:]; cancel(); searchTask?.cancel(); filterWorker?.cancel(); await worker?.value; await settingsTask?.value; await grantTask?.value; await recipeTask?.value; await watchTask?.value }
    func numberConflicts() {
        guard !busy, plan == nil else { return }; phase = "ActivityPreview"
        let items = entries
        worker = Task { [weak self] in
            do {
                let updated = try await Task.detached { try Planning.numbered(items) }.value
                guard let self else { return }
                let resolved = Set(zip(items, updated).compactMap { old, new in old.status == .conflict && new.status.fixable ? new.id : nil })
                entries = updated; selected.formUnion(resolved); phase = ""; rebuildFolderTree(); refreshVisible()
                counts["NeededCaption"] = updated.filter { $0.status.fixable }.count; counts["ConflictCaption"] = updated.filter { $0.status == .conflict }.count
            } catch { self?.phase = ""; self?.message = (error as? FSError)?.code ?? "OperationError" }
        }
    }
    func reloadHistory() async {
        guard let store else { return }
        do {
            let limit = settings.historyLimit
            history = try await Task.detached { try store.pruneUnneeded(limit: limit); return try store.summaries() }.value
            historyLoaded = true
            if history.contains(where: { !["Completed", "CompletedWithErrors", "Cancelled"].contains($0.status) }) { message = "RecoveryNeedsReview" }
            pruneGrants()
        } catch { message = "HistoryWarning" }
    }
    func loadDetails(_ id: UUID) {
        historyID = id; historyDetails = []; recoveryDetails = []; historyLoading = true
        guard let store else { historyLoading = false; return }
        Task {
            do {
                let rows = try await Task.detached { try History.details(store: store, id: id) }.value
                guard historyID == id else { return }; historyDetails = rows
                let recovery = try await Task.detached { try History.inspect(store: store, id: id) }.value
                if historyID == id { recoveryDetails = recovery }
            } catch { message = (error as? FSError)?.code ?? "HistoryWarning" }
            if historyID == id { historyLoading = false }
        }
    }
    func inspectClipboard() {
        guard plan == nil, result == nil, !mutating else { return }
        guard let text = NSPasteboard.general.string(forType: .string) else { message = "NoClipboardText"; return }
        (clipboard, clipboardTruncated) = NormalizationAnalysis.clipboard(text); sheet = "clipboard"
    }
    func usePipeline(_ draft: RulePipeline) {
        guard !busy, plan == nil else { message = "BusyDropRejected"; return }
        let value = Self.applicable(draft)
        guard !value.requiresPro || productAccess == .pro else { message = "ProRequired"; return }
        let access = productAccess
        phase = "ActivityPreview"
        worker = Task { [weak self] in
            do {
                try await Task.detached { try value.validate(access: access) }.value
                guard let self else { return }
                phase = ""; pipeline = value; activeWatchID = nil
                // The editor keeps what the user sees, unfilled rules included.
                workbenchDraft = draft; markWorkbenchPreviewApplied()
                if value != RulePipeline() { changeSettings { $0.workbenchEnabled = true } }
                if !value.requiresPro {
                    recipes.lastFree = value; recipes.lastFree.manualPaths = nil
                    if recipes.lastFree.order == .manual { recipes.lastFree.order = .path }
                    saveRecipes()
                }
                sheet = nil; scan()
            } catch { self?.phase = ""; self?.message = (error as? RuleFailure)?.rawValue ?? "RuleInvalid" }
        }
    }
    /// A manual order lists this session's absolute paths; it has no meaning in a stored rule set.
    static func reusable(_ pipeline: RulePipeline) -> RulePipeline {
        var value = pipeline; value.manualPaths = nil
        if value.order == .manual { value.order = .path }
        return value
    }
    func saveRecipes() {
        guard let store = recipeStore else { return }
        let snapshot = recipes, previous = recipeTask
        recipeTask = Task { [weak self] in
            await previous?.value
            do { try await store.save(snapshot) } catch { self?.message = "RecipeReadOnly" }
        }
    }
    func saveRecipe(name: String, pipeline draft: RulePipeline) {
        let pipeline = Self.applicable(draft)
        guard !busy else { message = "BusyDropRejected"; return }
        guard productAccess == .pro else { message = "ProRequired"; return }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200 else { message = "RuleInvalid"; return }
        phase = "ActivityPreview"
        worker = Task { [weak self] in
            do {
                try await Task.detached { try pipeline.validate(access: .pro) }.value
                guard let self else { return }
                phase = ""
                guard productAccess == .pro else { message = "ProRequired"; return }
                recipes.recipes.append(Recipe(name: name, pipeline: Self.reusable(pipeline))); saveRecipes(); message = "RecipeSaved"
            } catch { self?.phase = ""; self?.message = (error as? RuleFailure)?.rawValue ?? "RuleInvalid" }
        }
    }
    func editRecipe(_ id: UUID, name: String? = nil, duplicate: Bool = false, remove: Bool = false) {
        guard productAccess == .pro else { message = "ProRequired"; return }
        guard !busy else { return }
        guard let i = recipes.recipes.firstIndex(where: { $0.id == id }) else { return }
        if remove { recipes.recipes.remove(at: i) }
        else if duplicate { recipes.recipes.append(Recipe(name: recipes.recipes[i].name + " (2)", pipeline: recipes.recipes[i].pipeline)) }
        else if let name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 200 else { message = "RuleInvalid"; return }
            recipes.recipes[i].name = trimmed
        }
        saveRecipes()
    }
    func changeAccess(_ access: ProductAccess) {
        guard !busy, plan == nil else { return }
        #if DEBUG
        entitlement = Entitlement(state: access == .pro ? .active : .free)
        productAccess = entitlement.access()
        #else
        productAccess = entitlement.access()
        #endif
        restartWatches()
        if productAccess == .free && pipeline.requiresPro { pipeline = recipes.lastFree; appliedDraftRevision = nil }
        scan()
    }
    func saveWatches() {
        guard let store = watchStore else { return }
        watches.baselines = watchBaselines
        let value = watches, previous = watchTask
        watchTask = Task { [weak self] in await previous?.value; do { try await store.save(value) } catch { self?.message = "WatchReadOnly" } }
    }
    func restartWatches() {
        watchers.values.forEach { $0.stop() }; watchers = [:]; watchErrors = [:]
        // The folders are allowed again before the earlier hold on them is given back, so a review
        // that is running in one of them never finds it closed in between.
        let held = Array(watchGrants.values); watchGrants = [:]
        defer { held.forEach(AccessRoots.shared.release) }
        guard productAccess == .pro else { return }
        var renewed = false
        for index in watches.folders.indices where watches.folders[index].enabled {
            let folder = watches.folders[index]
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: folder.bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
                // A moved folder is not followed silently; the user picks it again.
                guard url.path == folder.path, let root = try? AccessRoots.shared.grant(url) else { throw FSError("WatchReauthorize") }
                watchGrants[folder.id] = root.path
                // The system calls the bookmark stale but it still opened the folder: replace it with a fresh one.
                if stale, let fresh = AccessRoots.shared.bookmark(for: root.path) { watches.folders[index].bookmark = fresh; renewed = true }
                let fd = try FS.openDirectory(root.path); close(fd)
                let watcher = FolderWatcher(), id = folder.id
                try watcher.start(path: url.path) { [weak self] rescan in
                    Task { @MainActor [weak self] in
                        guard let self, self.watchers[id] != nil else { return }
                        self.watchPending.insert(id)
                        if rescan { self.watchErrors[id] = "WatchRescan" }
                    }
                }
                watchers[id] = watcher; watchPending.insert(id)
            } catch { watchErrors[folder.id] = (error as? FSError)?.code ?? "WatchReauthorize" }
        }
        if renewed { saveWatches() }
    }
    func addWatch(_ url: URL) {
        guard productAccess == .pro, !busy, plan == nil else { message = "ProRequired"; return }
        do {
            guard watches.folders.count < 100, !watches.folders.contains(where: { Data($0.path.utf8) == Data(url.path.utf8) }) else { throw RuleFailure.invalid }
            let lease = AccessLease(url); defer { withExtendedLifetime(lease) {} }
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            watches.folders.append(WatchedFolder(bookmark: bookmark, path: url.path, pipeline: Self.reusable(pipeline))); saveWatches(); restartWatches()
        } catch { message = (error as? RuleFailure)?.rawValue ?? "WatchReauthorize" }
    }
    func toggleWatch(_ id: UUID) {
        guard let index = watches.folders.firstIndex(where: { $0.id == id }) else { return }
        if !watches.folders[index].enabled && productAccess != .pro { message = "ProRequired"; return }
        watches.folders[index].enabled.toggle(); saveWatches(); restartWatches()
    }
    func removeWatch(_ id: UUID) { watchBaselines.removeValue(forKey: id); watches.folders.removeAll { $0.id == id }; watchPending.remove(id); saveWatches(); restartWatches() }
    func updateWatch(_ id: UUID) {
        guard productAccess == .pro, let index = watches.folders.firstIndex(where: { $0.id == id }) else { message = "ProRequired"; return }
        guard !busy, plan == nil else { message = "BusyDropRejected"; return }
        watches.folders[index].pipeline = Self.reusable(pipeline); watchBaselines[id] = [:]; saveWatches(); watchPending.insert(id)
    }
    func reviewWatch(_ id: UUID) {
        guard productAccess == .pro, !busy, plan == nil, result == nil, let folder = watches.folders.first(where: { $0.id == id }) else { message = "BusyDropRejected"; return }
        guard watchErrors[id] != "WatchReauthorize" else { message = "WatchReauthorize"; return }
        // Snapshot the folder and rules now; later events only enter the pending set.
        watchPending.remove(id); activeWatchID = id; pipeline = folder.pipeline; workbenchDraft = folder.pipeline; markWorkbenchPreviewApplied(); changeSettings { $0.workbenchEnabled = true }; roots = [watchGrants[id] ?? RawPath(folder.path)]; releaseUnusedInputGrants(); sheet = nil; scan()
    }
    func diagnostics() {
        var report: [String: Any] = ["version": AppInfo.version, "build": AppInfo.build, "architecture": "arm64", "os": ProcessInfo.processInfo.operatingSystemVersionString, "counts": counts, "history": history.map { ["id": $0.id.uuidString, "status": $0.status, "succeeded": String($0.succeeded), "failed": String($0.failed)] }, "theme": settings.theme, "language": settings.language, "masked": maskPaths]
        if !maskPaths { report["inputPaths"] = roots.map(\.display) }
        do { diagnosticsPreview = String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self) }
        catch { message = "DiagnosticsError" }
    }
}
