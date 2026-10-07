import Foundation
import SwiftUI
import AppKit
import Darwin
import NameFixCore
import NameFixRuntime
import NameFixApplication

@MainActor final class AppModel: ObservableObject {
    @Published var settings = AppSettings()
    @Published var watches = WatchLibrary()
    @Published var watchPending: Set<UUID> = []
    @Published var watchErrors: [UUID: String] = [:]
    private var watchers: [UUID: FolderWatcher] = [:]
    private var watchLeases: [UUID: AccessLease] = [:]
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
    @Published var visible: [FileEntry] = []
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
        do { settings = try await settingsStore.load() } catch { message = (error as? FSError)?.code ?? "SettingsWarning" }
        // The app always opens on the repair screen, whichever screen was showing when it quit.
        settings.workbenchEnabled = false
        do {
            let root = dataRoot.appendingPathComponent("History")
            let store = try await Task.detached { try JournalStore(root: root) }.value
            self.store = store; coordinator = TransactionCoordinator(store: store)
            await reloadHistory()
        } catch { message = "JournalWriteFailed" }
        let recipeStore = RecipeStore(url: dataRoot.appendingPathComponent("recipes.json"))
        self.recipeStore = recipeStore
        do { recipes = try await recipeStore.load(); workbenchDraft = recipes.lastFree; pipeline = isWorkbench ? recipes.lastFree : RulePipeline(); if isWorkbench { markWorkbenchPreviewApplied() } else { appliedDraftRevision = nil } }
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
        if !settings.rememberRecentFolders { settings.recentFolders = [] }
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
    nonisolated static func resolve(_ favorite: FavoriteFolder) -> URL? {
        var url = URL(fileURLWithPath: favorite.path)
        if let bookmark = favorite.bookmark {
            var stale = false
            if let found = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) { url = found }
        }
        return usableFolder(url) ? url : nil
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
        guard let url = Self.resolve(favorite) else { favoriteProblems.insert(favorite.id); message = "FavoriteUnavailable"; return }
        favoriteProblems.remove(favorite.id)
        if url.path != favorite.path { changeSettings { settings in if let index = settings.favoriteFolders?.firstIndex(where: { $0.id == favorite.id }) { settings.favoriteFolders?[index].path = url.path } } }
        add([url])
    }
    func openRecent(_ path: String) {
        let url = URL(fileURLWithPath: path)
        guard Self.usableFolder(url) else {
            message = "RecentUnavailable"
            changeSettings { $0.recentFolders.removeAll { Data($0.utf8) == Data(path.utf8) } }
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
        for url in local { let path = RawPath(url.path); if seen.insert(path).inserted { roots.append(path) } }
        scan()
    }
    /// Menu and menu-bar commands must not stack a sheet on a confirmation, result or running rename.
    func present(_ name: String) { guard plan == nil, result == nil, !mutating else { return }; sheet = name }
    func dismissResult() { result = nil; flushQueued() }
    func cancelPreview() { plan = nil; flushQueued() }
    func flushQueued() {
        guard canInput, !queuedURLs.isEmpty else { return }
        let urls = queuedURLs; queuedURLs = []; add(urls)
    }
    func remove(_ path: RawPath?) {
        guard !busy, plan == nil else { return }
        activeWatchID = nil
        if let path { roots.removeAll { $0 == path } } else { roots = []; leases = [] }
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
            if scan.limited { message = "ScanLimit" } else if scan.cancelled { message = "Cancelled" }
            // Say once, in the status line, why a whole location is left alone. Nothing is shown for supported places.
            else if let place = scan.entries.first(where: { VolumeSupport.locationReasons.contains($0.reason) })?.reason { message = place }
            else if let shown = message, VolumeSupport.locationReasons.contains(shown) { message = nil }
            if settings.rememberRecentFolders {
                let directories = scan.entries.filter { $0.isDirectory && scan.roots.contains($0.path) }.map { $0.path.display }
                var list = directories + settings.recentFolders
                var unique = Set<Data>(); list = list.filter { unique.insert(Data($0.utf8)).inserted }
                settings.recentFolders = Array(list.prefix(10)); persist()
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
        worker = Task { [weak self] in
            do {
                let fresh = try await Task.detached {
                    if let historyID { return try mode == "recovery" ? History.recovery(store: store, id: historyID, generation: gen) : History.undo(store: store, id: historyID, generation: gen) }
                    return try Planning.make(entries: items, selected: selection, generation: gen)
                }.value
                guard let self else { return }
                phase = ""; sheet = nil
                if fresh.operations.isEmpty { message = fresh.excluded > 0 ? "NoChangesExcluded" : "NoChanges" } else { plan = fresh }
            } catch { self?.phase = ""; self?.message = (error as? FSError)?.code ?? "OperationError" }
        }
    }
    func execute() {
        guard let plan, let coordinator, plan.generation == generation, !busy else { return }
        if plan.mode == "rename", pipeline.requiresPro && entitlement.access() != .pro { self.plan = nil; message = "ProRequired"; return }
        self.plan = nil; phase = plan.mode == "rename" ? "ActivityRename" : plan.mode == "undo" ? "ActivityUndo" : "Recovery"
        completed = 0; total = plan.operations.count; started = Date(); cancelled = false
        transactionToken = CancellationToken(); let token = transactionToken
        let recipient = self
        worker = Task { [weak self] in
            do {
                let summary = try await coordinator.execute(plan, token: token) { progress in
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
                phase = ""; result = summary; transactionFinished?(summary)
                if settings.diagnostics { do { try await diagnosticLog.record(code: summary.status, transaction: summary.id, count: summary.succeeded) } catch { message = "DiagnosticsError" } }
                await reloadHistory()
                scan(clearSelection: settings.clearSelectionAfterRun)
            } catch { self?.phase = ""; self?.message = (error as? FSError)?.code ?? "OperationError"; await self?.reloadHistory() }
        }
    }
    func cancel() { cancelled = true; scanToken.cancel(); transactionToken.cancel() }
    func shutdown() async { shuttingDown = true; ready = false; watchers.values.forEach { $0.stop() }; watchers = [:]; cancel(); searchTask?.cancel(); filterWorker?.cancel(); await worker?.value; await settingsTask?.value; await recipeTask?.value; await watchTask?.value }
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
            if history.contains(where: { !["Completed", "CompletedWithErrors", "Cancelled"].contains($0.status) }) { message = "RecoveryNeedsReview" }
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
        watchers.values.forEach { $0.stop() }; watchers = [:]; watchLeases = [:]; watchErrors = [:]
        guard productAccess == .pro else { return }
        for folder in watches.folders where folder.enabled {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: folder.bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
                guard !stale, url.path == folder.path else { throw FSError("WatchReauthorize") }
                let lease = AccessLease(url)
                let fd = try FS.openDirectory(RawPath(url.path)); close(fd)
                let watcher = FolderWatcher(), id = folder.id
                try watcher.start(path: url.path) { [weak self] rescan in
                    Task { @MainActor [weak self] in
                        guard let self, self.watchers[id] != nil else { return }
                        self.watchPending.insert(id)
                        if rescan { self.watchErrors[id] = "WatchRescan" }
                    }
                }
                watchers[id] = watcher; watchLeases[id] = lease; watchPending.insert(id)
            } catch { watchErrors[folder.id] = (error as? FSError)?.code ?? "WatchReauthorize" }
        }
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
        watchPending.remove(id); activeWatchID = id; pipeline = folder.pipeline; workbenchDraft = folder.pipeline; markWorkbenchPreviewApplied(); changeSettings { $0.workbenchEnabled = true }; roots = [RawPath(folder.path)]; sheet = nil; scan()
    }
    func diagnostics() {
        var report: [String: Any] = ["version": AppInfo.version, "build": AppInfo.build, "architecture": "arm64", "os": ProcessInfo.processInfo.operatingSystemVersionString, "counts": counts, "history": history.map { ["id": $0.id.uuidString, "status": $0.status, "succeeded": String($0.succeeded), "failed": String($0.failed)] }, "theme": settings.theme, "language": settings.language, "masked": maskPaths]
        if !maskPaths { report["inputPaths"] = roots.map(\.display) }
        do { diagnosticsPreview = String(decoding: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self) }
        catch { message = "DiagnosticsError" }
    }
}
