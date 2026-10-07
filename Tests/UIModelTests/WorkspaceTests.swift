import XCTest
import Foundation
import NameFixCore
import NameFixRuntime
@testable import NameFixUIModel

@MainActor final class WorkspaceTests: XCTestCase {
    private func settle(_ model: AppModel) async throws {
        for _ in 0..<500 { if !model.busy { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Workspace did not settle")
    }
    func testFilePreviewAndPlanUseOnlyTheActiveWorkspaceRules() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-workspace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("invoice.txt")
        try Data("unchanged contents".utf8).write(to: file)
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([file]); try await settle(model)
        var rule = RenameRule(.prefix); rule.text = "Client_"
        // Entering batch rename rescans with its own targets.
        model.openWorkbench(); try await settle(model)
        model.workbenchDraft = RulePipeline(rules: [rule])
        model.usePipeline(model.workbenchDraft); try await settle(model)
        XCTAssertEqual(model.entries.first?.preview, "Client_invoice.txt")
        model.prepare(); try await settle(model)
        let operation = try XCTUnwrap(model.plan?.operations.first)
        XCTAssertEqual(String(decoding: operation.destination, as: UTF8.self), "Client_invoice.txt")
        model.cancelPreview(); model.openQuickCleanup(); try await settle(model)
        XCTAssertEqual(model.entries.first?.preview, "invoice.txt")
        XCTAssertTrue(model.selected.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), Data("unchanged contents".utf8))
        await model.shutdown()
    }
    func testRevokedProDoesNotPresentOldDraftAsApplied() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-workspace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start()
        model.changeAccess(.pro); try await settle(model)
        var rule = RenameRule(.regex); rule.text = "a"; rule.replacement = "b"
        model.usePipeline(RulePipeline(rules: [rule])); try await settle(model)
        XCTAssertFalse(model.hasUnappliedRules)
        model.changeAccess(.free); try await settle(model)
        XCTAssertTrue(model.hasUnappliedRules)
        XCTAssertFalse(model.pipeline.requiresPro)
        model.prepare(); XCTAssertNil(model.plan)
        await model.shutdown()
    }
    func testLegacySettingsDecodeWithoutWorkspaceKey() throws {
        let data = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "workbenchEnabled"); object.removeValue(forKey: "favoriteFolders")
        let settings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(settings.workbenchEnabled); XCTAssertNil(settings.favoriteFolders); XCTAssertTrue(settings.valid)
    }
    func testDamagedFavoritesAreSetAsideAndDefaultsRestored() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-favorites-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings())) as? [String: Any])
        object["favoriteFolders"] = "not a list"
        let url = root.appendingPathComponent("settings.json"), damaged = try JSONSerialization.data(withJSONObject: object)
        try damaged.write(to: url)
        do { _ = try await SettingsStore(url: url).load(); XCTFail("Damaged favourites must not load") }
        catch { XCTAssertEqual((error as? FSError)?.code, "SettingsWarning") }
        // The damaged file is kept beside a fresh default one; nothing is silently dropped.
        let kept = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains("corrupt-") }
        XCTAssertEqual(try kept.first.map { try Data(contentsOf: $0) }, damaged)
        let fresh = try await SettingsStore(url: url).load()
        XCTAssertNil(fresh.favoriteFolders); XCTAssertTrue(fresh.valid)
        // Duplicate ids or an oversized list are not valid settings either.
        var settings = AppSettings(); let one = FavoriteFolder(path: "/a", bookmark: nil)
        settings.favoriteFolders = [one, one]; XCTAssertFalse(settings.valid)
        settings.favoriteFolders = (0...AppSettings.favoriteLimit).map { FavoriteFolder(path: "/\($0)", bookmark: nil) }; XCTAssertFalse(settings.valid)
    }
    func testFavoritesPersistOpenOnDemandNeverWatchAndReportUnavailableFolders() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-favorites-\(UUID())")
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.appendingPathComponent("photos").path); try? FileManager.default.removeItem(at: root) }
        let photos = root.appendingPathComponent("photos"), notes = root.appendingPathComponent("notes"), support = root.appendingPathComponent("support")
        for folder in [photos, notes] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data("kept".utf8).write(to: folder.appendingPathComponent("a.txt"))
        }
        var model = AppModel(dataRoot: support); await model.start()
        // A folder is pinned once; a file is not a favourite; pinning neither adds nor watches.
        model.addFavorite(photos); model.addFavorite(photos); model.addFavorite(photos.appendingPathComponent("a.txt"))
        XCTAssertEqual(model.favorites.map(\.path), [photos.path])
        XCTAssertTrue(model.roots.isEmpty); XCTAssertTrue(model.watches.folders.isEmpty); XCTAssertTrue(model.watchPending.isEmpty)
        await model.shutdown()
        let saved = try await SettingsStore(url: support.appendingPathComponent("settings.json")).load()
        XCTAssertEqual(saved.favoriteFolders?.map(\.path), [photos.path])
        // After a restart the favourite is there, and opening it adds the folder and checks it now.
        model = AppModel(dataRoot: support); await model.start()
        let favorite = try XCTUnwrap(model.favorites.first)
        model.openFavorite(favorite); try await settle(model)
        XCTAssertEqual(model.roots.map(\.display), [photos.path]); XCTAssertTrue(model.entries.contains { $0.name == "a.txt" })
        XCTAssertTrue(model.watches.folders.isEmpty); XCTAssertTrue(model.watchPending.isEmpty)
        model.remove(nil); try await settle(model)
        // No access: reported and marked, not skipped in silence.
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: photos.path)
        model.message = nil; model.openFavorite(favorite)
        XCTAssertEqual(model.message, "FavoriteUnavailable"); XCTAssertTrue(model.favoriteProblems.contains(favorite.id)); XCTAssertTrue(model.roots.isEmpty)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: photos.path)
        // Gone: the same.
        try FileManager.default.removeItem(at: photos)
        model.message = nil; model.openFavorite(favorite)
        XCTAssertEqual(model.message, "FavoriteUnavailable"); XCTAssertTrue(model.favoriteProblems.contains(favorite.id)); XCTAssertTrue(model.roots.isEmpty)
        // Choosing a folder again repairs the favourite in place.
        model.relinkFavorite(favorite.id, to: notes)
        XCTAssertEqual(model.favorites.map(\.path), [notes.path]); XCTAssertEqual(model.favorites.first?.id, favorite.id); XCTAssertFalse(model.favoriteProblems.contains(favorite.id))
        // Removing a favourite removes the shortcut only.
        model.removeFavorite(favorite.id)
        XCTAssertTrue(model.favorites.isEmpty)
        XCTAssertEqual(try Data(contentsOf: notes.appendingPathComponent("a.txt")), Data("kept".utf8))
        await model.shutdown()
    }
    func testQuickModeRemovesActiveRulesButRetainsDraftAndRestartOpensRepairScreen() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-workspace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start()
        XCTAssertFalse(model.isWorkbench)
        var rule = RenameRule(.prefix); rule.text = "Invoice_"
        let value = RulePipeline(rules: [rule])
        model.openWorkbench(); model.workbenchDraft = value
        XCTAssertTrue(model.hasUnappliedRules)
        model.usePipeline(value); try await settle(model)
        XCTAssertFalse(model.hasUnappliedRules)
        model.openQuickCleanup(); try await settle(model)
        XCTAssertFalse(model.isWorkbench); XCTAssertEqual(model.pipeline, RulePipeline())
        XCTAssertEqual(model.workbenchDraft, value)
        model.openWorkbench()
        XCTAssertTrue(model.isWorkbench); XCTAssertTrue(model.hasUnappliedRules)
        await model.shutdown()
        let restored = AppModel(dataRoot: root); await restored.start()
        XCTAssertFalse(restored.isWorkbench); XCTAssertEqual(restored.pipeline, RulePipeline())
        // A new launch starts with no rules; rules are kept only as saved presets.
        XCTAssertEqual(restored.workbenchDraft, RulePipeline())
        await restored.shutdown()
    }
    func testBatchRenameStartsWithAnUnfilledReplaceRuleThatIsNeverApplied() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-workspace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start()
        XCTAssertNil(model.addStarterRule())
        model.openWorkbench()
        let starter = model.addStarterRule()
        XCTAssertEqual(model.workbenchDraft.rules.map(\.id), [starter].compactMap { $0 }); XCTAssertEqual(model.workbenchDraft.rules.first?.kind, .replace)
        XCTAssertFalse(model.hasUnappliedRules); XCTAssertNil(model.addStarterRule())
        var prefix = RenameRule(.prefix); prefix.text = "Trip_"
        model.workbenchDraft.rules.append(prefix)
        XCTAssertTrue(model.hasUnappliedRules)
        model.usePipeline(model.workbenchDraft); try await settle(model)
        XCTAssertNil(model.message); XCTAssertFalse(model.hasUnappliedRules)
        XCTAssertEqual(model.pipeline.rules.map(\.kind), [.prefix]); XCTAssertEqual(model.workbenchDraft.rules.map(\.kind), [.replace, .prefix])
        XCTAssertEqual(model.recipes.lastFree.rules.map(\.kind), [.prefix])
        await model.shutdown()
    }
    func testUnappliedRulesBlockPrepareAndBusyBlocksNavigation() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-workspace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start(); model.openWorkbench()
        model.workbenchDraft = RulePipeline(rules: [RenameRule(.uppercase)])
        model.prepare()
        XCTAssertNil(model.plan); XCTAssertEqual(model.message, "UnappliedRules")
        model.phase = "ActivityRename"; model.openQuickCleanup()
        XCTAssertTrue(model.isWorkbench)
        model.phase = ""; await model.shutdown()
    }
    func testQuickStartupDoesNotApplySavedBatchRules() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-workspace-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); await model.start()
        let value = RulePipeline(rules: [RenameRule(.uppercase)])
        model.usePipeline(value); try await settle(model)
        model.openQuickCleanup(); try await settle(model); await model.shutdown()
        let restored = AppModel(dataRoot: root); await restored.start()
        XCTAssertFalse(restored.isWorkbench); XCTAssertEqual(restored.pipeline, RulePipeline())
        // A new launch starts with no rules; rules are kept only as saved presets.
        XCTAssertEqual(restored.workbenchDraft, RulePipeline())
        await restored.shutdown()
    }
}
