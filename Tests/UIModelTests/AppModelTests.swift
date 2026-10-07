import XCTest
import Combine
import Foundation
import NameFixCore
import NameFixRuntime
@testable import NameFixUIModel

@MainActor final class AppModelTests: XCTestCase {
    func fixture() throws -> URL { let url = URL(fileURLWithPath: "/private/tmp/namefix-ui-model-\(UUID())"); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
    func settled(_ model: AppModel, condition: @MainActor () -> Bool = { true }) async throws {
        for _ in 0..<500 { if !model.busy && condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Timed out waiting for application state")
    }
    func testFreshSettingsDefaultToOliveWithoutOverwritingSavedTheme() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(url: root.appendingPathComponent("settings.json"))
        let fresh = try await store.load()
        XCTAssertEqual(fresh.theme, "olive")
        var saved = fresh; saved.theme = "dark"
        try await store.save(saved)
        let restored = try await store.load()
        XCTAssertEqual(restored.theme, "dark")
        XCTAssertEqual(AppModel(dataRoot: root).settings.theme, "olive")
    }
    func testSettingsSaveFailurePreservesExistingDataAndReportsFailure() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let blocked = root.appendingPathComponent("not-a-directory")
        try Data("preserved".utf8).write(to: blocked)
        let model = AppModel(dataRoot: blocked)
        model.changeSettings { $0.theme = "dark" }
        await model.shutdown()
        XCTAssertEqual(model.message, "SettingsSaveFailed")
        XCTAssertEqual(try Data(contentsOf: blocked), Data("preserved".utf8))
    }
    /// The rule of a sandboxed app, switched on here: the model asks for a folder when it needs one,
    /// keeps the way back to a folder an operation ran in, and uses it after a restart.
    func testRestrictedAppAsksForAFolderAndUndoesAfterARestart() async throws {
        AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(true)
        defer { AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(false) }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("inputs"), support = root.appendingPathComponent("support")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        let file = input.appendingPathComponent("e\u{301}.txt"); try Data("contents".utf8).write(to: file)
        func stored() throws -> [String] { try FileManager.default.contentsOfDirectory(atPath: input.path).map { $0.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " ") } }
        let decomposed = try stored()
        let model = AppModel(dataRoot: support); await model.start()
        // A file on its own: the model asks for exactly its folder and changes nothing meanwhile.
        model.add([file]); try await settled(model, condition: { model.entries.count == 1 })
        XCTAssertEqual(model.folderRequest?.folder.path, input.path); XCTAssertEqual(model.folderRequest?.purpose, .input)
        XCTAssertEqual(model.entries[0].reason, "FolderAccessNeeded"); XCTAssertEqual(model.message, "FolderAccessNeeded")
        model.declineFolder(); XCTAssertNil(model.folderRequest); XCTAssertEqual(try stored(), decomposed)
        model.requestFolderForLooseItems(); XCTAssertNotNil(model.folderRequest)
        model.allowFolder(input); try await settled(model, condition: { model.entries.first?.status == .needsNormalization })
        XCTAssertNil(model.folderRequest); XCTAssertNil(model.message)
        model.prepare(); try await settled(model, condition: { model.plan != nil })
        model.execute(); try await settled(model, condition: { model.result != nil })
        XCTAssertEqual(model.result?.succeeded, 1); XCTAssertNotEqual(try stored(), decomposed)
        model.dismissResult(); try await settled(model)
        let kept = support.appendingPathComponent("access.json")
        for _ in 0..<200 where !FileManager.default.fileExists(atPath: kept.path) { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: kept.path), "The way back to the folder is kept with the record")
        await model.shutdown()
        // A new launch: nothing is allowed until the kept bookmark is used.
        AccessRoots.shared.releaseAll()
        let again = AppModel(dataRoot: support); await again.start()
        XCTAssertEqual(again.history.count, 1)
        again.prepare(mode: "undo", historyID: again.history[0].id); try await settled(again, condition: { again.plan != nil || again.message != nil })
        XCTAssertNil(again.folderRequest); XCTAssertEqual(again.plan?.operations.count, 1)
        again.execute(); try await settled(again, condition: { again.result != nil })
        XCTAssertEqual(try stored(), decomposed, "Undo after a restart is exact")
        again.dismissResult(); try await settled(again)
        await again.shutdown()
        // The kept access is lost: the next launch asks for the folder instead of guessing.
        AccessRoots.shared.releaseAll(); try FileManager.default.removeItem(at: kept)
        let third = AppModel(dataRoot: support); await third.start()
        let undo = try XCTUnwrap(third.history.first { $0.mode == "undo" })
        third.prepare(mode: "undo", historyID: undo.id); try await settled(third, condition: { third.folderRequest != nil || third.plan != nil })
        XCTAssertEqual(third.folderRequest?.folder.path, input.path); XCTAssertEqual(third.folderRequest?.purpose, .history(mode: "undo", id: undo.id))
        XCTAssertEqual(third.message, "UndoNeedsFolder"); XCTAssertNil(third.plan); XCTAssertEqual(try stored(), decomposed)
        third.allowFolder(input); try await settled(third, condition: { third.plan != nil })
        XCTAssertEqual(third.plan?.operations.count, 1)
        third.cancelPreview(); await third.shutdown()
    }
    func testCloudFolderIsListedWithANoticeAndLeftAlone() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        // A cloud provider's folder is recognized by where it is.
        let cloud = root.appendingPathComponent("Library/CloudStorage/Provider/Documents"); try FileManager.default.createDirectory(at: cloud, withIntermediateDirectories: true)
        let file = cloud.appendingPathComponent("e\u{301}.txt"); try Data("contents".utf8).write(to: file)
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        // The folder is listed and explained; its contents are not read, so nothing is fetched from the cloud.
        model.add([cloud]); try await settled(model, condition: { model.entries.count == 1 })
        XCTAssertTrue(model.entries.allSatisfy { $0.status == .unsupported && $0.reason == "CloudLocationExcluded" })
        XCTAssertEqual(model.message, "CloudLocationExcluded"); XCTAssertTrue(model.selected.isEmpty)
        model.prepare(); try await settled(model)
        XCTAssertNil(model.plan); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: cloud.path), ["e\u{301}.txt"])
        model.message = nil
        // The notice goes away with the location; a supported folder shows none.
        let local = root.appendingPathComponent("local"); try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
        try Data("contents".utf8).write(to: local.appendingPathComponent("e\u{301}.txt"))
        model.remove(nil); try await settled(model, condition: { model.roots.isEmpty })
        model.add([local]); try await settled(model, condition: { model.entries.count == 2 })
        XCTAssertNil(model.message); XCTAssertEqual(model.counts["NeededCaption"], 1)
        await model.shutdown()
    }
    func testReadOnlyPreviewConfirmationRenameAndUndo() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("inputs"); try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        let path = input.appendingPathComponent("e\u{301}.txt"); try Data("contents".utf8).write(to: path)
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([input]); try await settled(model, condition: { model.entries.count == 2 })
        XCTAssertEqual(model.selected.count, 1)
        model.prepare(); try await settled(model, condition: { model.plan != nil })
        let before = try FileManager.default.contentsOfDirectory(atPath: input.path).map { Data($0.utf8) }
        XCTAssertTrue(before.contains(Data("e\u{301}.txt".utf8)), "Preview must not mutate")
        model.execute(); try await settled(model, condition: { model.result != nil })
        XCTAssertEqual(model.result?.succeeded, 1)
        let id = try XCTUnwrap(model.result?.id)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: input.path).map { Data($0.utf8) }.contains(Data("é.txt".utf8)))
        model.result = nil; model.prepare(mode: "undo", historyID: id); try await settled(model, condition: { model.plan != nil })
        model.execute(); try await settled(model, condition: { model.result != nil })
        XCTAssertEqual(model.result?.succeeded, 1)
        XCTAssertEqual(try Data(contentsOf: path), Data("contents".utf8))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: input.path).map { Data($0.utf8) }.contains(Data("e\u{301}.txt".utf8)))
        await model.shutdown()
    }
    func testSearchSelectionAndLanguageThemePreserveState() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        let a = FileEntry(path: RawPath("/fixture/e\u{301}.txt"), status: .needsNormalization, reason: "ChangeHelp", proposed: Data("é.txt".utf8))
        let b = FileEntry(path: RawPath("/fixture/normal.txt"), status: .normal, reason: "NormalHelp", proposed: Data("normal.txt".utf8))
        model.entries = [a,b]; model.selected = [a.id]; model.query = "normal"
        try await settled(model, condition: { model.visible.count == 1 })
        XCTAssertEqual(model.hiddenSelected, 1)
        model.changeSettings { $0.theme = "olive"; $0.language = "ja-JP" }
        XCTAssertEqual(model.selected, [a.id]); XCTAssertEqual(model.entries.count, 2)
        model.query = ""; model.filter = "SelectedOnly"; try await settled(model, condition: { model.visible.first?.id == a.id })
        XCTAssertEqual(model.hiddenSelected, 0)
        await model.shutdown()
    }
    func testGenerationDropsStaleScanAndSerialSettingsKeepLatest() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let old = root.appendingPathComponent("old"), new = root.appendingPathComponent("new")
        try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true); try FileManager.default.createDirectory(at: new, withIntermediateDirectories: true)
        for i in 0..<100 { try Data().write(to: old.appendingPathComponent("old-\(i)")) }
        try Data().write(to: new.appendingPathComponent("new-item"))
        let support = root.appendingPathComponent("support"), model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.roots = [RawPath(old.path)]; model.scan()
        model.roots = [RawPath(new.path)]; model.scan()
        try await settled(model, condition: { model.entries.count == 2 })
        XCTAssertTrue(model.entries.allSatisfy { $0.path.display.hasPrefix(new.path) })
        for i in 0..<20 { model.changeSettings { $0.nameColumnRatio = Double(25 + i) } }
        model.changeSettings { $0.rememberRecentFolders = true; $0.recentFolders = [old.path] }
        model.changeSettings { $0.rememberRecentFolders = false; $0.theme = "light" }
        await model.shutdown()
        let restored = try await SettingsStore(url: support.appendingPathComponent("settings.json")).load()
        XCTAssertEqual(restored.nameColumnRatio, 44); XCTAssertEqual(restored.theme, "light"); XCTAssertTrue(restored.recentFolders.isEmpty)
    }
    func testRescanPreservesDeselectionAndAddsOnlyNewCandidates() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("inputs")
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try Data().write(to: input.appendingPathComponent("e\u{301}.txt"))
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([input]); try await settled(model, condition: { model.visible.count == 2 })
        let row = try XCTUnwrap(model.entries.first(where: { $0.status.fixable }))
        model.toggle(row); XCTAssertTrue(model.selected.isEmpty)
        try Data().write(to: input.appendingPathComponent("a\u{301}.txt"))
        model.scan(); try await settled(model, condition: { model.visible.count == 3 })
        XCTAssertEqual(model.entries.first(where: { $0.path == row.path })?.id, row.id)
        XCTAssertFalse(model.selected.contains(row.id)); XCTAssertEqual(model.selected.count, 1)
        await model.shutdown()
    }
    func testNumberProposalSelectsResolvedConflictWithoutChangingOtherSelections() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("e\u{301}.txt"); try Data().write(to: input)
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([input]); try await settled(model, condition: { model.entries.count == 1 })
        model.entries[0].status = .conflict; model.entries[0].proposed = Data("shared.txt".utf8); model.selected = []
        let id = model.entries[0].id
        model.numberConflicts(); try await settled(model, condition: { model.selected.contains(id) })
        XCTAssertEqual(model.entries[0].preview, "shared (1).txt")
        model.prepare(); try await settled(model, condition: { model.plan != nil })
        XCTAssertEqual(model.plan?.operations.count, 1)
        let recursive = model.settings.recursive
        model.changeSettings { $0.recursive.toggle(); $0.theme = "olive" }
        XCTAssertEqual(model.settings.recursive, recursive); XCTAssertEqual(model.settings.theme, "olive")
        model.cancelPreview(); await model.shutdown()
    }
    func testClosingResultAcceptsQueuedFinderInput() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("e\u{301}.txt"), b = root.appendingPathComponent("next.txt")
        try Data().write(to: a); try Data().write(to: b)
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([a]); try await settled(model, condition: { model.entries.count == 1 })
        model.prepare(); try await settled(model, condition: { model.plan != nil })
        model.execute(); try await settled(model, condition: { model.result != nil })
        model.add([b], fromOS: true); XCTAssertFalse(model.roots.contains(RawPath(b.path)))
        model.dismissResult(); try await settled(model, condition: { model.roots.contains(RawPath(b.path)) && model.entries.count == 2 })
        await model.shutdown()
    }
    func testAllThemesPersistAndSelectionDoesNotRerunLargeSort() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let support = root.appendingPathComponent("support"), model = AppModel(dataRoot: root.appendingPathComponent("support"))
        await model.start()
        for theme in AppTheme.allCases {
            model.changeSettings { $0.theme = theme.rawValue }
            await model.shutdown()
            let saved = try await SettingsStore(url: support.appendingPathComponent("settings.json")).load()
            XCTAssertEqual(saved.theme, theme.rawValue)
        }
        let rows = await Task.detached { (0..<100_000).map { FileEntry(path: RawPath("/fixture/\($0)-e\u{301}.txt"), status: .needsNormalization, reason: "ChangeHelp", proposed: Data("é.txt".utf8)) } }.value
        model.entries = rows; model.refreshVisible()
        try await settled(model, condition: { model.visible.count == rows.count })
        let computations = model.viewComputationCount, start = Date()
        for row in rows.prefix(100) { model.toggle(row) }
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertEqual(model.viewComputationCount, computations)
        XCTAssertEqual(model.selected.count, 100)
        XCTAssertEqual(model.hiddenSelected, 0)
        print("SELECTION_100_OF_100K seconds=\(elapsed) filterComputations=\(model.viewComputationCount - computations)")
        model.query = "not-present"; model.query = "99999-"
        try await settled(model, condition: { model.visible.count == 1 })
        XCTAssertTrue(model.visible[0].name.hasPrefix("99999-")); XCTAssertEqual(model.hiddenSelected, 100)
        await model.shutdown()
    }
    /// Timing profile of the list operations a large result set goes through. Opt-in: NAMEFIX_UI_PERF=1.
    func testLargeListInteractionProfile() async throws {
        guard ProcessInfo.processInfo.environment["NAMEFIX_UI_PERF"] == "1" else { throw XCTSkip("UI performance profile only") }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start()
        let rows = await Task.detached { (0..<100_000).map { i -> FileEntry in
            let folder = "/fixture/folder-\(i % 200)"
            return FileEntry(path: RawPath("\(folder)/\(String(i, radix: 7))-보고서 e\u{301}-\(i).txt"), status: i % 3 == 0 ? .normal : .needsNormalization, reason: "ChangeHelp", proposed: Data("\(i)-é.txt".utf8))
        } }.value
        model.entries = rows
        // Each step ends when the model publishes the recomputed list.
        func timed(_ label: String, _ action: @MainActor @escaping () -> Void) async {
            let start = Date()
            var waiting: AnyCancellable?
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                var resumed = false
                waiting = model.$visible.dropFirst().sink { _ in if !resumed { resumed = true; continuation.resume() } }
                action()
            }
            waiting?.cancel(); await Task.yield()
            print(String(format: "UI_PERF %@ total=%.3f visible=%d", label, Date().timeIntervalSince(start), model.visible.count))
        }
        await timed("sort-name") { model.refreshVisible() }
        await timed("sort-path") { model.sort = "Path" }
        await timed("sort-status") { model.sort = "Status" }
        await timed("sort-name-again") { model.sort = "Name" }
        await timed("filter-needed") { model.filter = "NeedsNormalization" }
        await timed("filter-all") { model.filter = "All" }
        await timed("search(+0.18s debounce)") { model.query = "66" }
        await timed("search-clear(+0.18s debounce)") { model.query = "" }
        await timed("folder-filter") { model.folderFilter = RawPath("/fixture/folder-7") }
        await timed("folder-clear") { model.folderFilter = nil }
        var start = Date(); model.select("all"); print(String(format: "UI_PERF select-all call=%.4f selected=%d", Date().timeIntervalSince(start), model.selected.count))
        start = Date(); model.select("none"); print(String(format: "UI_PERF select-none call=%.4f", Date().timeIntervalSince(start)))
        start = Date(); for row in rows.prefix(300) where row.status.fixable { model.toggle(row) }; print(String(format: "UI_PERF toggle-x200 call=%.4f", Date().timeIntervalSince(start)))
        start = Date(); model.select("invert"); print(String(format: "UI_PERF select-invert call=%.4f", Date().timeIntervalSince(start)))
        await model.shutdown()
    }
    func testFreePipelineRestoresWithoutPersistingInputPathsAndProRejects() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        // The shipped app grants everything; this exercises the access checks that remain underneath.
        let model = AppModel(dataRoot: root, entitlementProvider: UnconfiguredEntitlementProvider()); await model.start()
        var prefix = RenameRule(.prefix); prefix.text = "Free_"
        var pipeline = RulePipeline(target: .nfd, rules: [prefix]); pipeline.order = .manual; pipeline.manualPaths = [Data("/private/user/secret.txt".utf8)]
        model.usePipeline(pipeline); try await settled(model)
        await model.shutdown()
        let restored = AppModel(dataRoot: root, entitlementProvider: UnconfiguredEntitlementProvider()); await restored.start()
        // The app reopens on the repair screen with no rules: last time's rules are not brought back.
        XCTAssertFalse(restored.isWorkbench); XCTAssertEqual(restored.pipeline, RulePipeline())
        XCTAssertEqual(restored.workbenchDraft, RulePipeline())
        // What was stored never held the input paths.
        XCTAssertNil(restored.recipes.lastFree.manualPaths); XCTAssertEqual(restored.recipes.lastFree.order, .path)
        var pro = RenameRule(.regex); pro.text = "."; pro.replacement = "x"
        restored.usePipeline(RulePipeline(rules: [pro])); XCTAssertEqual(restored.message, "ProRequired")
        XCTAssertTrue(restored.workbenchDraft.rules.isEmpty); XCTAssertTrue(restored.pipeline.rules.isEmpty)
        restored.saveRecipe(name: "denied", pipeline: pipeline); XCTAssertTrue(restored.recipes.recipes.isEmpty)
        await restored.shutdown()
    }
    func testProRecipeManagementAndDowngradePreserveUndoAccess() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start(); model.changeAccess(.pro); try await settled(model)
        var rule = RenameRule(.regex); rule.text = "a"; rule.replacement = "b"
        let pipeline = RulePipeline(rules: [rule]); model.saveRecipe(name: "Recipe", pipeline: pipeline)
        try await settled(model, condition: { !model.recipes.recipes.isEmpty })
        let id = try XCTUnwrap(model.recipes.recipes.first?.id)
        model.editRecipe(id, duplicate: true); model.editRecipe(id, name: "Renamed"); XCTAssertEqual(model.recipes.recipes.count, 2)
        model.editRecipe(id, remove: true); XCTAssertEqual(model.recipes.recipes.count, 1)
        model.usePipeline(pipeline); try await settled(model); model.changeAccess(.free); try await settled(model)
        XCTAssertEqual(model.productAccess, .free); XCTAssertFalse(model.pipeline.requiresPro)
        XCTAssertNotNil(model.store); XCTAssertEqual(model.recipes.recipes.count, 1)
        await model.shutdown()
    }
    func testWatchFreeBoundaryAndApprovalSnapshot() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let input = root.appendingPathComponent("inputs"); try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        let model = AppModel(dataRoot: root.appendingPathComponent("support"), entitlementProvider: UnconfiguredEntitlementProvider()); await model.start()
        model.addWatch(input); XCTAssertEqual(model.message, "ProRequired"); XCTAssertTrue(model.watches.folders.isEmpty)
        model.changeAccess(.pro); try await settled(model)
        // Test queue/approval state without starting OS watches in this model fixture.
        var prefix = RenameRule(.prefix); prefix.text = "renamed_"
        let watch = WatchedFolder(bookmark: Data(), path: input.path, pipeline: RulePipeline(rules: [prefix]))
        model.watches.folders = [watch]; model.watchPending.insert(watch.id)
        let file = input.appendingPathComponent("a.txt"); try Data("a".utf8).write(to: file)
        model.reviewWatch(watch.id); try await settled(model)
        model.prepare(); try await settled(model, condition: { model.plan != nil })
        let original = try XCTUnwrap(model.plan)
        try Data("b".utf8).write(to: input.appendingPathComponent("b.txt")); model.watchPending.insert(watch.id)
        XCTAssertEqual(model.plan?.id, original.id); XCTAssertFalse(model.plan!.operations.contains { $0.source.leaf == Data("b.txt".utf8) })
        model.cancelPreview(); await model.shutdown()
    }
    func testShippedAppGrantsEveryCapabilityWithoutAPaidTier() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root)
        XCTAssertEqual(model.productAccess, .pro)
        await model.start(); XCTAssertEqual(model.productAccess, .pro)
        var rule = RenameRule(.regex); rule.text = "a"; rule.replacement = "b"
        model.usePipeline(RulePipeline(rules: [rule])); try await settled(model)
        XCTAssertNil(model.message); XCTAssertEqual(model.pipeline.rules.first?.kind, .regex)
        model.saveRecipe(name: "Everyone", pipeline: model.pipeline)
        try await settled(model, condition: { !model.recipes.recipes.isEmpty })
        await model.shutdown()
    }
}
