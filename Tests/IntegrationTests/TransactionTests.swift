import XCTest
import Foundation
import Darwin
import CryptoKit
import NameFixCore
import NameFixRuntime
import NameFixApplication

final class TransactionTests: XCTestCase, @unchecked Sendable {
    func fixture() throws -> URL {
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NAMEFIX_FIXTURE_ROOT"] ?? "/private/tmp").appendingPathComponent("namefix-fixture-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    func create(_ root: URL, _ name: String, content: String = "unchanged payload") throws -> RawPath {
        let path = RawPath(root.path).appending(Data(name.utf8))
        try Data(content.utf8).write(to: URL(fileURLWithPath: path.display))
        return path
    }
    func scan(_ root: URL, recursive: Bool = true) -> [FileEntry] { Scanner.scan(roots: [RawPath(root.path)], recursive: recursive, token: CancellationToken()).entries }
    func plan(_ entries: [FileEntry]) throws -> RenamePlan { try Planning.make(entries: entries, selected: Set(entries.filter { $0.status.fixable }.map(\.id)), generation: UUID()) }
    func fixtureCommand(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = output; process.standardError = output
        try process.run(); process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else { print("Fixture metadata command failed:", executable, text); throw FSError("FixtureMetadata", process.terminationStatus) }
        return text
    }
    func aclLines(_ path: String) throws -> [String] {
        try fixtureCommand("/bin/ls", ["-le", path]).split(separator: "\n").map(String.init).filter { $0.trimmingCharacters(in: .whitespaces).range(of: "^[0-9]+:", options: .regularExpression) != nil }
    }
    func testScanRenameUndoHashAndMetadata() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let path = try create(root, "e\u{301}.txt")
        let bytes = try Data(contentsOf: URL(fileURLWithPath: path.display)), hash = SHA256.hash(data: bytes)
        let attr = Data("finder-metadata".utf8)
        let attrResult = attr.withUnsafeBytes { setxattr(path.display, "com.moongchi.namefix.fixture", $0.baseAddress, $0.count, 0, 0) }
        XCTAssertEqual(attrResult, 0)
        let extraAttributes = ["com.apple.ResourceFork": Data("resource fork contents".utf8), "com.apple.metadata:_kMDItemUserTags": try PropertyListSerialization.data(fromPropertyList: ["QA\n6"], format: .binary, options: 0)]
        for (key, value) in extraAttributes { XCTAssertEqual(value.withUnsafeBytes { setxattr(path.display, key, $0.baseAddress, $0.count, 0, 0) }, 0) }
        _ = try fixtureCommand("/bin/chmod", ["+a", "user:\(NSUserName()) allow read", path.display])
        let beforeACL = try aclLines(path.display); XCTAssertFalse(beforeACL.isEmpty)
        let permissions = try FileManager.default.attributesOfItem(atPath: path.display)[.posixPermissions] as? NSNumber
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let entries = scan(root), plan = try plan(entries)
        XCTAssertEqual(plan.operations.count, 1)
        let summary = try await coordinator.execute(plan, token: CancellationToken())
        XCTAssertEqual(summary.succeeded, 1); XCTAssertEqual(summary.failed, 0)
        let final = root.appendingPathComponent("é.txt")
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: final)), hash)
        for (key, expected) in extraAttributes.merging(["com.moongchi.namefix.fixture": attr], uniquingKeysWith: { a,_ in a }) {
            var actual = Data(count: expected.count)
            let size = actual.withUnsafeMutableBytes { getxattr(final.path, key, $0.baseAddress, $0.count, 0, 0) }
            XCTAssertEqual(size, expected.count); XCTAssertEqual(actual, expected)
        }
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: final.path)[.posixPermissions] as? NSNumber, permissions)
        XCTAssertEqual(try aclLines(final.path), beforeACL)
        XCTAssertEqual(scan(root).filter { $0.status.fixable }.count, 0)
        let undo = try History.undo(store: store, id: plan.id, generation: UUID())
        XCTAssertEqual(undo.operations.count, 1)
        let undone = try await coordinator.execute(undo, token: CancellationToken())
        XCTAssertEqual(undone.succeeded, 1)
        XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: URL(fileURLWithPath: path.display))), hash)
        XCTAssertEqual(try aclLines(path.display), beforeACL)
        XCTAssertEqual(try History.undo(store: store, id: plan.id, generation: UUID()).operations.count, 0)
        let replay = try store.replay(plan.id)
        XCTAssertTrue(replay.valid)
        XCTAssertEqual(replay.events.map(\.state), ["TransactionPrepared", "Prepared", "TemporaryRenamed", "FinalIntent", "FinalRenamed", "Verified", "Completed"])
    }
    func testNestedFiveLevelsAndOverlappingRoots() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        var current = root
        for i in 0..<5 { current = current.appendingPathComponent("e\u{301}\(i)"); try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true) }
        let leaf = try create(current, "か\u{3099}.txt")
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let scan = Scanner.scan(roots: [RawPath(root.path), leaf, RawPath(current.path)], recursive: true, token: CancellationToken())
        XCTAssertEqual(Set(scan.entries.map(\.path)).count, scan.entries.count)
        let plan = try plan(scan.entries)
        XCTAssertEqual(plan.operations.count, 6)
        let result = try await coordinator.execute(plan, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 6)
        let moved = try History.remap([leaf], store: store, id: plan.id)[0]
        XCTAssertEqual(Data(moved.display.utf8), Data(moved.display.precomposedStringWithCanonicalMapping.utf8))
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.display))
        let undo = try History.undo(store: store, id: plan.id, generation: UUID())
        XCTAssertEqual(undo.operations.count, 6)
        let undone = try await coordinator.execute(undo, token: CancellationToken())
        XCTAssertEqual(undone.succeeded, 6)
        let fd = try FS.openDirectory(RawPath(current.path)); defer { close(fd) }
        XCTAssertTrue(try FS.names(fd).contains(leaf.leaf))
    }
    func testNormalizedParentAliasesDeduplicateRawEntries() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("e\u{301}")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let leaf = try create(folder, "child-e\u{301}.txt")
        let alternate = RawPath(root.path + "/é/child-é.txt")
        let result = Scanner.scan(roots: [RawPath(folder.path), alternate], recursive: true, token: CancellationToken())
        XCTAssertEqual(result.entries.count, 2)
        XCTAssertEqual(result.entries.filter { $0.path == leaf }.count, 1)
    }
    func testHardlinkPartialUndoDoesNotMergeEntries() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let a = try create(root, "a\u{301}.txt"), b = RawPath(root.path).appending(Data("e\u{301}.txt".utf8))
        XCTAssertEqual(link(a.display, b.display), 0)
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let plan = try plan(scan(root)); XCTAssertEqual(plan.operations.count, 2)
        let summary = try await coordinator.execute(plan, token: CancellationToken()); XCTAssertEqual(summary.succeeded, 2)
        var undo = try History.undo(store: store, id: plan.id, generation: UUID()); XCTAssertEqual(undo.operations.count, 2)
        undo.operations = [undo.operations[0]]
        let first = try await coordinator.execute(undo, token: CancellationToken()); XCTAssertEqual(first.succeeded, 1)
        let remaining = try History.undo(store: store, id: plan.id, generation: UUID()); XCTAssertEqual(remaining.operations.count, 1)
        XCTAssertNotEqual(remaining.operations[0].undoOf, undo.operations[0].undoOf)
        let second = try await coordinator.execute(remaining, token: CancellationToken()); XCTAssertEqual(second.succeeded, 1)
        XCTAssertEqual(try History.undo(store: store, id: plan.id, generation: UUID()).operations.count, 0)
    }
    func testSourceReplacedAfterPreviewStopsSafely() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let source = try create(root, "e\u{301}.txt")
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let plan = try plan(scan(root))
        try FileManager.default.moveItem(atPath: source.display, toPath: root.appendingPathComponent("original-retained").path)
        _ = try create(root, "e\u{301}.txt", content: "replacement")
        let result = try await coordinator.execute(plan, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 0); XCTAssertEqual(result.status, "RecoveryNeedsReview")
        XCTAssertEqual(try String(contentsOfFile: source.display, encoding: .utf8), "replacement")
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        XCTAssertTrue(try FS.names(fd).contains(source.leaf))
    }
    func testDestinationInsertedAfterPreviewNeverOverwritten() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try create(root, "e\u{301}.txt")
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        var entry = try XCTUnwrap(scan(root).first { $0.status.fixable }); entry.proposed = Data("reserved.txt".utf8)
        let plan = try self.plan([entry])
        _ = try create(root, "reserved.txt", content: "do not overwrite")
        let result = try await coordinator.execute(plan, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 0); XCTAssertEqual(result.failed, 1)
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("reserved.txt"), encoding: .utf8), "do not overwrite")
    }
    func testRecoveryFromEveryMoveGap() async throws {
        for stage in ["prepared", "temporary", "final"] {
            let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
            _ = try create(root, "e\u{301}.txt")
            let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
            let plan = try plan(scan(root)), op = try XCTUnwrap(plan.operations.first)
            do {
                let journal = try JournalWriter(url: store.journalURL(plan.id))
                try journal.append("Prepared", operation: op)
                let fd = try FS.openDirectory(op.source.parent); defer { close(fd) }
                if stage != "prepared" { try FS.noReplace(fd, from: op.source.leaf, to: op.temporary) }
                if stage == "final" { try journal.append("FinalIntent", operation: op); try FS.noReplace(fd, from: op.temporary, to: op.destination) }
            }
            let inspection = try History.inspect(store: store, id: plan.id)
            XCTAssertEqual(inspection.count, 1); XCTAssertNotNil(inspection[0].current)
            let recovery = try History.recovery(store: store, id: plan.id, generation: UUID())
            if stage == "prepared" { XCTAssertTrue(recovery.operations.isEmpty) }
            else { XCTAssertEqual(recovery.operations.count, 1); let result = try await coordinator.execute(recovery, token: CancellationToken()); XCTAssertEqual(result.succeeded, 1) }
            let fd = try FS.openDirectory(op.source.parent); defer { close(fd) }
            try FS.verify(fd, raw: op.source.leaf, identity: op.identity)
        }
    }
    /// The faster record (D-036): same events, same result, and a record that lost its tail to a
    /// power cut is still a valid record that says where the unfinished item is.
    func testFastRecordIsTheSameRecordAndSurvivesALostTail() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for name in ["a\u{301}.txt", "e\u{301}.txt", "o\u{301}.txt"] { _ = try create(root, name) }
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let plan = try plan(scan(root))
        XCTAssertEqual(plan.operations.count, 3)
        let result = try await coordinator.execute(plan, token: CancellationToken(), fast: true)
        XCTAssertEqual(result.succeeded, 3); XCTAssertEqual(result.status, "Completed")
        let replay = try store.replay(plan.id)
        XCTAssertTrue(replay.valid)
        let item = ["Prepared", "TemporaryRenamed", "FinalIntent", "FinalRenamed", "Verified"]
        XCTAssertEqual(replay.events.map(\.state), ["TransactionPrepared"] + item + item + item + ["Completed"])
        XCTAssertEqual(scan(root).filter { $0.status.fixable }.count, 0)
        // A power cut: everything after the second item's FinalIntent never reached the disk.
        let url = store.journalURL(plan.id), lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        try (lines.prefix(1 + 5 + 3).joined(separator: "\n") + "\n").write(to: url, atomically: false, encoding: .utf8)
        let cut = try store.replay(plan.id)
        XCTAssertTrue(cut.valid); XCTAssertEqual(cut.events.last?.state, "FinalIntent")
        let inspection = try History.inspect(store: store, id: plan.id)
        XCTAssertEqual(inspection.count, 2); XCTAssertTrue(inspection.allSatisfy { $0.current != nil }, "Every recorded item is found where it is now")
        let recovery = try History.recovery(store: store, id: plan.id, generation: UUID())
        XCTAssertFalse(recovery.operations.isEmpty)
        let restored = try await coordinator.execute(recovery, token: CancellationToken())
        XCTAssertEqual(restored.failed, 0)
        // The faster record is refused where a drive can be unplugged: a disk image is not a built-in drive.
        XCTAssertTrue(TransactionCoordinator.builtIn(plan.operations))
    }
    func testTornJournalPreservedAndBlocksUndo() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(root: root.appendingPathComponent("journal")), id = UUID()
        do { let writer = try JournalWriter(url: store.journalURL(id)); try writer.append("Prepared") }
        let handle = try FileHandle(forWritingTo: store.journalURL(id)); try handle.seekToEnd(); try handle.write(contentsOf: Data("torn".utf8)); try handle.close()
        let before = try Data(contentsOf: store.journalURL(id))
        XCTAssertFalse(try store.replay(id).valid)
        XCTAssertThrowsError(try History.undo(store: store, id: id, generation: UUID()))
        XCTAssertEqual(try Data(contentsOf: store.journalURL(id)), before)
        XCTAssertEqual(try store.summaries().first?.status, "RecoveryNeedsReview")
    }
    func testCancelAndProcessLock() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try create(root, "e\u{301}.txt")
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let plan = try plan(scan(root)), token = CancellationToken(); token.cancel()
        let summary = try await coordinator.execute(plan, token: token); XCTAssertEqual(summary.succeeded, 0); XCTAssertEqual(summary.status, "Cancelled")
        let lock = open(store.root.appendingPathComponent("transaction.lock").path, O_RDWR); defer { close(lock) }
        XCTAssertEqual(flock(lock, LOCK_EX | LOCK_NB), 0)
        do { _ = try await coordinator.execute(try self.plan(scan(root)), token: CancellationToken()); XCTFail("must refuse concurrent instance") } catch { XCTAssertEqual((error as? FSError)?.code, "BusyDropRejected") }
    }
    func testLinksPackagesRecursionInvalidUTF8AndLimit() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let child = root.appendingPathComponent("child"), bundle = root.appendingPathComponent("Protected.app")
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true); try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        _ = try create(child, "e\u{301}.txt"); _ = try create(bundle, "e\u{301}.txt")
        XCTAssertEqual(symlink(child.path, root.appendingPathComponent("linked").path), 0)
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let invalid = Data([0xff, 0x2e, 0x74]); let rawFD = FS.cPath(invalid) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }; let creationErrno = errno; if rawFD >= 0 { close(rawFD) } else { XCTAssertTrue([EILSEQ, EINVAL].contains(creationErrno), "APFS invalid UTF-8 errno \(creationErrno)") }
        let direct = scan(root, recursive: false), recursive = scan(root)
        XCTAssertEqual(direct.filter { $0.status.fixable }.count, 0)
        XCTAssertEqual(recursive.filter { $0.status.fixable }.count, 1)
        if rawFD >= 0 { XCTAssertTrue(recursive.contains { $0.status == .invalidUnicode && $0.path.leaf == invalid }) } else { XCTAssertEqual(NormalizationAnalysis(raw: invalid).status, .invalidUnicode); print("APFS rejected invalid UTF-8 fixture, errno", creationErrno) }
        XCTAssertEqual(recursive.filter { $0.reason == "LinkedPathHelp" }.count, 1)
        XCTAssertFalse(recursive.contains { $0.path.display.hasPrefix(bundle.path + "/") })
        XCTAssertThrowsError(try FS.openDirectory(RawPath(root.appendingPathComponent("linked").path)))
        XCTAssertTrue(Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken(), limit: 2).limited)
    }
    func testSettingsNewSchemaCorruptionAndPersistence() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("settings.json"), store = SettingsStore(url: root.appendingPathComponent("settings.json"))
        var settings = AppSettings(); settings.theme = "olive"; settings.language = "ja-JP"
        try await store.save(settings); let loaded = try await store.load(); XCTAssertEqual(loaded, settings)
        for bad in [Data("{broken".utf8), Data("{\"schemaVersion\":999}".utf8)] {
            try bad.write(to: url); let reader = SettingsStore(url: url)
            do { _ = try await reader.load(); XCTFail("must report preserved invalid settings") } catch { }
            if bad == Data("{broken".utf8) {
                try await reader.save(AppSettings())
                let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.lastPathComponent.contains("corrupt-") }
                XCTAssertEqual(backups.count, 1); XCTAssertEqual(try Data(contentsOf: backups[0]), bad)
            } else {
                do { try await reader.save(AppSettings()); XCTFail("must not overwrite newer schema") } catch { }
                XCTAssertEqual(try Data(contentsOf: url), bad)
            }
        }
    }

    func testScanLimitReportsTheOneItemBeyondIt() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try create(root, "a.txt"); _ = try create(root, "b.txt")
        let exact = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken(), limit: 3)
        XCTAssertEqual(exact.entries.count, 3); XCTAssertFalse(exact.limited)
        let over = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken(), limit: 2)
        XCTAssertEqual(over.entries.count, 2); XCTAssertTrue(over.limited)
    }
}
