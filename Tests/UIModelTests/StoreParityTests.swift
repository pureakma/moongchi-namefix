import XCTest
import NameFixCore
import NameFixRuntime
@testable import NameFixUIModel

/// What the Mac App Store edition does where the app outside the sandbox needs no permission:
/// it asks for the one folder that is missing, at the moment it is needed, and then does the same work.
/// The sandbox rule is switched on here; the real sandbox is exercised by eng/test-sandbox.py.
@MainActor final class StoreParityTests: XCTestCase {
    private let composed = "Albu\u{308}m".precomposedStringWithCanonicalMapping, decomposed = "Albu\u{308}m"
    private func fixture() throws -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/namefix-parity-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    private func settled(_ model: AppModel, _ condition: @MainActor () -> Bool = { true }) async throws {
        for _ in 0..<600 { if !model.busy && condition() { return }; try await Task.sleep(for: .milliseconds(10)) }
        XCTFail("Timed out waiting for application state")
    }
    private func names(_ folder: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).map { $0.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: " ") }.sorted()
    }
    private func write(_ folder: URL, _ name: String) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent(name); try Data("contents".utf8).write(to: file); return file
    }
    private func restricted() { AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(true) }
    override func tearDown() async throws { AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(false) }

    func testAddedFolderIsRenamedOnceTheFolderAboveIsChosenAndUndoneAfterARestart() async throws {
        restricted()
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let above = root.appendingPathComponent("above"), album = above.appendingPathComponent(decomposed), support = root.appendingPathComponent("support")
        _ = try write(album, "e\u{301}.txt"); _ = try write(album, "plain.txt")
        let other = root.appendingPathComponent("other"); try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let before = try names(above), inside = try names(album)
        let model = AppModel(dataRoot: support); await model.start()
        model.add([album]); try await settled(model) { model.entries.count == 3 }
        // Nothing is asked for up front: the items inside can be renamed with what was given.
        XCTAssertNil(model.folderRequest)
        let row = try XCTUnwrap(model.entries.first { $0.isDirectory })
        XCTAssertEqual(row.status, .accessDenied); XCTAssertEqual(row.reason, "ParentFolderNeeded"); XCTAssertEqual(row.preview, composed)
        XCTAssertEqual(CharacterPresentation.statusKey(row.status, name: row.name, reason: row.reason), "StatusParentNeeded")
        XCTAssertEqual(model.message, "ParentFolderNeeded")
        XCTAssertEqual(model.entries.filter { $0.status.fixable }.map(\.name), ["e\u{301}.txt"])
        // The user asks for the folder's own name too: exactly the folder above is asked for.
        model.requestParentFolder()
        XCTAssertEqual(model.folderRequest?.purpose, .parent); XCTAssertEqual(model.folderRequest?.folder.path, above.path); XCTAssertEqual(model.folderRequest?.item, decomposed)
        // Cancel: nothing changes, what was added stays, and the choice is still there.
        model.declineFolder()
        XCTAssertNil(model.folderRequest); XCTAssertEqual(model.entries.count, 3); XCTAssertEqual(try names(above), before); XCTAssertEqual(model.message, "ParentFolderNeeded")
        // A folder that does not contain it is not kept.
        model.requestParentFolder(); model.allowFolder(other)
        XCTAssertEqual(model.message, "WrongFolderChosen"); XCTAssertNil(AccessRoots.shared.root(containing: RawPath(other.path)))
        XCTAssertEqual(try names(above), before)
        // The right folder: the list is scanned again and the folder is a row like any other.
        model.requestParentFolder(); XCTAssertNotNil(model.folderRequest)
        model.allowFolder(above); try await settled(model) { model.entries.first { $0.isDirectory }?.status.fixable == true }
        XCTAssertNil(model.folderRequest); XCTAssertNil(model.message)
        model.prepare(); try await settled(model) { model.plan != nil }
        XCTAssertEqual(model.plan?.operations.count, 2)
        model.execute(); try await settled(model) { model.result != nil }
        XCTAssertEqual(model.result?.succeeded, 2); XCTAssertEqual(model.result?.status, "Completed")
        XCTAssertNotEqual(try names(above), before)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: above.path).map { Array($0.unicodeScalars) }, [Array(composed.unicodeScalars)])
        model.dismissResult(); try await settled(model)
        let kept = support.appendingPathComponent("access.json")
        for _ in 0..<200 where !FileManager.default.fileExists(atPath: kept.path) { try await Task.sleep(for: .milliseconds(10)) }
        await model.shutdown()
        // A new launch, nothing handed over: the kept way back leads to the folder above and the undo is exact.
        AccessRoots.shared.releaseAll()
        let again = AppModel(dataRoot: support); await again.start()
        again.prepare(mode: "undo", historyID: try XCTUnwrap(again.history.first).id); try await settled(again) { again.plan != nil || again.message != nil }
        XCTAssertNil(again.folderRequest); XCTAssertEqual(again.plan?.operations.count, 2)
        again.execute(); try await settled(again) { again.result != nil }
        XCTAssertEqual(again.result?.succeeded, 2)
        XCTAssertEqual(try names(above), before); XCTAssertEqual(try names(album), inside)
        again.dismissResult(); try await settled(again); await again.shutdown()
    }

    func testAddedFolderWhoseNameStaysIsAnOrdinaryRowAndNothingIsAsked() async throws {
        restricted()
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let trip = root.appendingPathComponent("Trip"); _ = try write(trip, "e\u{301}.txt")
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([trip]); try await settled(model) { model.entries.count == 2 }
        let row = try XCTUnwrap(model.entries.first { $0.isDirectory })
        XCTAssertEqual(row.status, .normal); XCTAssertEqual(row.reason, "NormalHelp")
        XCTAssertNil(model.message); XCTAssertNil(model.folderRequest)
        model.requestParentFolder(); XCTAssertNil(model.folderRequest, "No name to change, nothing to ask for")
        // Renaming what is inside needs no more than the folder that was given.
        model.prepare(); try await settled(model) { model.plan != nil }
        model.execute(); try await settled(model) { model.result != nil }
        XCTAssertEqual(model.result?.succeeded, 1); XCTAssertNil(model.folderRequest)
        model.dismissResult(); try await settled(model)
        // Batch rules: the folder joins in only when folder names are asked for, and then needs the folder above.
        model.openWorkbench(); try await settled(model)
        var rule = RenameRule(.replace); rule.text = "Trip"; rule.replacement = "Tour"
        var pipeline = RulePipeline(rules: [rule])
        model.usePipeline(pipeline); try await settled(model) { model.entries.first { $0.isDirectory }?.reason == "FolderExcluded" }
        XCTAssertNil(model.message)
        pipeline.includeFolders = true
        model.usePipeline(pipeline); try await settled(model) { model.entries.first { $0.isDirectory }?.reason == "ParentFolderNeeded" }
        let batch = try XCTUnwrap(model.entries.first { $0.isDirectory })
        XCTAssertEqual(batch.preview, "Tour"); XCTAssertEqual(batch.status, .accessDenied); XCTAssertEqual(model.message, "ParentFolderNeeded")
        model.requestParentFolder(); XCTAssertEqual(model.folderRequest?.folder.path, root.path)
        model.allowFolder(root); try await settled(model) { model.entries.first { $0.isDirectory }?.status.fixable == true }
        model.prepare(); try await settled(model) { model.plan != nil }
        model.execute(); try await settled(model) { model.result != nil }
        XCTAssertEqual(model.result?.succeeded, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("Tour").path)); XCTAssertFalse(FileManager.default.fileExists(atPath: trip.path))
        model.dismissResult(); try await settled(model); await model.shutdown()
    }

    func testFilesOfOneFolderAskOnceAndFilesOfTwoFoldersAskForEachInTurn() async throws {
        restricted()
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("A"), b = root.appendingPathComponent("B")
        let a1 = try write(a, "a\u{301}.txt"), a2 = try write(a, "e\u{301}.txt"), b1 = try write(b, "o\u{301}.txt")
        let before = try names(b)
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([a1, a2]); try await settled(model) { model.entries.count == 2 }
        XCTAssertEqual(model.folderRequest?.folder.path, a.path); XCTAssertEqual(model.folderRequest?.remaining, 0)
        model.allowFolder(a); try await settled(model) { model.entries.allSatisfy { $0.status.fixable } }
        XCTAssertNil(model.folderRequest, "One folder, one request")
        // A file from another folder: only that folder is asked for, the first is not asked again.
        model.add([b1]); try await settled(model) { model.entries.count == 3 }
        XCTAssertEqual(model.folderRequest?.folder.path, b.path); XCTAssertEqual(model.folderRequest?.remaining, 0)
        model.declineFolder(); try await settled(model)
        // Declined: its file is shown as waiting for its folder, nothing of it is renamed, and it can be chosen later.
        XCTAssertEqual(model.entries.filter { $0.reason == "FolderAccessNeeded" }.map(\.name), ["o\u{301}.txt"]); XCTAssertEqual(model.message, "FolderAccessNeeded")
        model.prepare(); try await settled(model) { model.plan != nil }
        XCTAssertEqual(model.plan?.operations.count, 2); model.cancelPreview()
        XCTAssertEqual(try names(b), before)
        model.requestFolderForLooseItems(); XCTAssertEqual(model.folderRequest?.folder.path, b.path)
        model.allowFolder(b); try await settled(model) { model.entries.allSatisfy { $0.status.fixable } }
        XCTAssertNil(model.message); await model.shutdown()
        // Both at once in a new session: two folders, asked for in turn, and the first request says one more follows.
        AccessRoots.shared.releaseAll()
        let both = AppModel(dataRoot: root.appendingPathComponent("support2")); await both.start()
        both.add([a1, b1]); try await settled(both) { both.entries.count == 2 }
        XCTAssertEqual(both.folderRequest?.folder.path, a.path); XCTAssertEqual(both.folderRequest?.remaining, 1)
        both.allowFolder(a); XCTAssertEqual(both.folderRequest?.folder.path, b.path); XCTAssertEqual(both.folderRequest?.remaining, 0)
        both.allowFolder(b); try await settled(both) { both.entries.allSatisfy { $0.status.fixable } }
        XCTAssertNil(both.folderRequest); await both.shutdown()
    }

    func testAFolderTheAppCanAlreadyReachIsNotAskedForAndAMovedOneIsNotTrusted() async throws {
        restricted()
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let docs = root.appendingPathComponent("docs"), support = root.appendingPathComponent("support")
        let file = try write(docs, "e\u{301}.txt")
        let model = AppModel(dataRoot: support); await model.start()
        _ = try AccessRoots.shared.grant(docs)
        model.addFavorite(docs); try await settled(model)
        XCTAssertNotNil(model.favorites.first?.bookmark)
        await model.shutdown()
        // A new launch: the favourite's kept access is used, and the file's folder is not asked for.
        AccessRoots.shared.releaseAll()
        let again = AppModel(dataRoot: support); await again.start()
        again.add([file]); try await settled(again) { again.entries.first?.status.fixable == true }
        XCTAssertNil(again.folderRequest); XCTAssertNil(again.message)
        await again.shutdown()
        // The favourite's folder was moved away and another folder now has its place: the kept access
        // leads to the moved folder, which does not contain the file, so it is not used.
        AccessRoots.shared.releaseAll()
        try FileManager.default.moveItem(at: docs, to: root.appendingPathComponent("moved"))
        let replaced = try write(docs, "o\u{301}.txt")
        let third = AppModel(dataRoot: support); await third.start()
        third.add([replaced]); try await settled(third) { third.entries.count == 1 }
        XCTAssertEqual(third.folderRequest?.folder.path, docs.path); XCTAssertEqual(third.entries.first?.reason, "FolderAccessNeeded")
        XCTAssertNil(AccessRoots.shared.root(containing: RawPath(root.appendingPathComponent("moved").path)), "Access that did not help is given back")
        await third.shutdown()
    }

    func testOutsideTheSandboxNothingIsAskedAndTheAddedFolderIsRenamedAtOnce() async throws {
        AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(false)
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let above = root.appendingPathComponent("above"), album = above.appendingPathComponent(decomposed)
        let file = try write(album, "e\u{301}.txt")
        let model = AppModel(dataRoot: root.appendingPathComponent("support")); await model.start()
        model.add([album]); try await settled(model) { model.entries.count == 2 }
        XCTAssertTrue(model.entries.allSatisfy { $0.status.fixable }); XCTAssertNil(model.folderRequest); XCTAssertNil(model.message)
        model.requestParentFolder(); model.requestFolderForLooseItems(); XCTAssertNil(model.folderRequest)
        model.prepare(); try await settled(model) { model.plan != nil }
        model.execute(); try await settled(model) { model.result != nil }
        XCTAssertEqual(model.result?.succeeded, 2)
        model.dismissResult(); try await settled(model)
        model.remove(nil); try await settled(model) { model.roots.isEmpty }
        model.add([above.appendingPathComponent(composed).appendingPathComponent(file.lastPathComponent.precomposedStringWithCanonicalMapping)]); try await settled(model) { model.entries.count == 1 }
        XCTAssertNil(model.folderRequest); XCTAssertNotEqual(model.entries.first?.reason, "FolderAccessNeeded")
        await model.shutdown()
    }
}
