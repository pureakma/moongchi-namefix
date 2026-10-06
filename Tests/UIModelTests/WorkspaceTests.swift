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
        model.openWorkbench(); model.workbenchDraft = RulePipeline(rules: [rule])
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
        object.removeValue(forKey: "workbenchEnabled")
        let settings = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(settings.workbenchEnabled); XCTAssertTrue(settings.valid)
    }
    func testQuickModeRemovesActiveRulesButRetainsDraftAndLastScreen() async throws {
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
        XCTAssertTrue(restored.isWorkbench); XCTAssertEqual(restored.pipeline, value)
        await restored.shutdown()
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
        XCTAssertEqual(restored.workbenchDraft, value)
        await restored.shutdown()
    }
}
