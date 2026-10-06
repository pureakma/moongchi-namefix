import XCTest
import Foundation
import Darwin
import NameFixCore
import NameFixRuntime
import NameFixApplication

final class SafetyTests: XCTestCase, @unchecked Sendable {
    func fixture() throws -> URL {
        let base = ProcessInfo.processInfo.environment["NAMEFIX_FIXTURE_ROOT"] ?? "/private/tmp"
        let url = URL(fileURLWithPath: base).appendingPathComponent("namefix-fixture-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    func testExclusiveRenameAgainstCompetingDestinationCreation() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        for i in 0..<100 {
            let src = Data("source\(i)".utf8), dest = Data("dest\(i)".utf8)
            let f = FS.cPath(src) { openat(fd, $0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }; XCTAssertGreaterThanOrEqual(f, 0); close(f)
            let expected = try FS.identity(FS.metadata(fd, src))
            XCTAssertTrue(try FS.destinationAvailable(fd, source: src, dest: dest, expected: expected, names: Set(FS.names(fd))))
            // A foreign writer wins between destination inspection and rename.
            let g = FS.cPath(dest) { openat(fd, $0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }; XCTAssertGreaterThanOrEqual(g, 0); close(g)
            let other = try FS.identity(FS.metadata(fd, dest))
            XCTAssertThrowsError(try FS.noReplace(fd, from: src, to: dest))
            try FS.verify(fd, raw: src, identity: expected); try FS.verify(fd, raw: dest, identity: other)
        }
    }
    func testSourceRaceCannotBeAtomicExpectedInodeRename() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let src = Data("source".utf8), replacement = Data("replacement".utf8), preserved = Data("preserved".utf8), temp = Data("temp".utf8)
        for name in [src, replacement] { let f = FS.cPath(name) { openat(fd, $0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }; XCTAssertGreaterThanOrEqual(f, 0); close(f) }
        let expected = try FS.identity(FS.metadata(fd, src))
        try FS.verify(fd, raw: src, identity: expected)
        // Deterministic adversarial interleaving proves the platform limitation.
        try FS.noReplace(fd, from: src, to: preserved); try FS.noReplace(fd, from: replacement, to: src)
        try FS.noReplace(fd, from: src, to: temp)
        XCTAssertThrowsError(try FS.verify(fd, raw: temp, identity: expected))
        try FS.verify(fd, raw: preserved, identity: expected)
        print("SOURCE_RACE_LIMITATION: no-replace does not condition rename on expected inode; post-check detects it")
    }
    func testTemporaryCollisionAndJournalWriteFailureDoNotMoveSource() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("e\u{301}.txt"); try Data("original".utf8).write(to: source)
        let entries = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken()).entries
        var plan = try Planning.make(entries: entries, selected: Set(entries.filter { $0.status.fixable }.map(\.id)), generation: UUID())
        plan.operations[0].temporary = Data("occupied".utf8)
        try Data("occupied".utf8).write(to: root.appendingPathComponent("occupied"))
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let result = try await coordinator.execute(plan, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(result.status, "CompletedWithErrors")
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
        XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("occupied"), encoding: .utf8), "occupied")
        let otherStore = try JournalStore(root: root.appendingPathComponent("read-only"))
        XCTAssertEqual(chmod(otherStore.root.path, 0o500), 0); defer { chmod(otherStore.root.path, 0o700) }
        do { _ = try await TransactionCoordinator(store: otherStore).execute(plan, token: CancellationToken()); XCTFail("journal write must fail") }
        catch { XCTAssertEqual((error as? FSError)?.code, "JournalWriteFailed") }
        XCTAssertEqual(try String(contentsOf: source, encoding: .utf8), "original")
    }
    func testNumberProposalsReserveDestinationsAndPreserveExtension() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for name in ["a\u{301}.txt", "e\u{301}.txt", "shared (1).txt"] { try Data().write(to: root.appendingPathComponent(name)) }
        var entries = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken()).entries.filter { $0.status.fixable }
        for i in entries.indices { entries[i].status = .conflict; entries[i].proposed = Data("shared.txt".utf8) }
        let numbered = try Planning.numbered(entries)
        XCTAssertEqual(Set(numbered.map(\.proposed)), Set([Data("shared (2).txt".utf8), Data("shared (3).txt".utf8)]))
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        XCTAssertFalse(try FS.names(fd).contains(Data("shared (2).txt".utf8)))
    }
    func testFinderAliasMetadataDoesNotTraverseTarget() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target.txt"), alias = root.appendingPathComponent("alias-e\u{301}")
        try Data("target contents".utf8).write(to: target)
        let bookmark = try target.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
        try URL.writeBookmarkData(bookmark, to: alias)
        XCTAssertEqual(try alias.resourceValues(forKeys: [.isAliasFileKey]).isAliasFile, true)
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        XCTAssertTrue(try FS.isFinderAlias(fd, name: Data(alias.lastPathComponent.utf8)))
        XCTAssertFalse(try FS.isFinderAlias(fd, name: Data(target.lastPathComponent.utf8)))
        let rows = Scanner.scan(roots: [RawPath(alias.path)], recursive: true, token: CancellationToken()).entries
        XCTAssertEqual(rows.count, 1); XCTAssertEqual(rows.first?.status, .unsupported); XCTAssertEqual(rows.first?.reason, "LinkedPathHelp")
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "target contents")
    }
    func testUnreadableDirectoryIsOneBlockedRow() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("e\u{301}")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        XCTAssertEqual(chmod(folder.path, 0), 0); defer { chmod(folder.path, 0o700) }
        let rows = Scanner.scan(roots: [RawPath(folder.path)], recursive: true, token: CancellationToken()).entries
        XCTAssertEqual(rows.count, 1); XCTAssertTrue(try XCTUnwrap(rows.first).status.isError)
        XCTAssertTrue(try Planning.make(entries: rows, selected: Set(rows.map(\.id)), generation: UUID()).operations.isEmpty)
    }
    func testUnexpectedTemporaryIdentityRemainsVisibleButCannotBeRecovered() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("e\u{301}.txt")
        try Data("original".utf8).write(to: source)
        let rows = Scanner.scan(roots: [RawPath(source.path)], recursive: false, token: CancellationToken()).entries
        let plan = try Planning.make(entries: rows, selected: Set(rows.map(\.id)), generation: UUID())
        let op = try XCTUnwrap(plan.operations.first)
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let writer = try JournalWriter(url: store.journalURL(plan.id))
        try writer.append("Prepared", operation: op)
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        try FS.noReplace(fd, from: op.source.leaf, to: Data("preserved".utf8))
        let temporaryURL = root.appendingPathComponent(String(decoding: op.temporary, as: UTF8.self))
        try Data("replacement".utf8).write(to: temporaryURL)
        try writer.append("Failed", operation: op, error: "SourceChangedAfterMove")
        let inspections = try History.inspect(store: store, id: plan.id)
        XCTAssertEqual(inspections.count, 1); XCTAssertNil(inspections[0].current)
        XCTAssertEqual(inspections[0].observedLocations, [RawPath(temporaryURL.path)])
        XCTAssertTrue(try History.recovery(store: store, id: plan.id, generation: UUID()).operations.isEmpty)
        XCTAssertEqual(try Data(contentsOf: temporaryURL), Data("replacement".utf8))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("preserved")), Data("original".utf8))
    }
    func testScanPerformanceProfile() throws {
        guard ProcessInfo.processInfo.environment["NAMEFIX_PERFORMANCE"] == "1" else { throw XCTSkip("Full QA performance profile only") }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        var created = 0
        for count in [1, 100, 10_000, 100_000] {
            while created < count {
                let f = FS.cPath(Data("file-\(created).txt".utf8)) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }
                guard f >= 0 else { throw FSError("FixtureCreate") }; close(f); created += 1
            }
            let start = Date()
            var beforeCPU = rusage(); getrusage(RUSAGE_SELF, &beforeCPU)
            let result = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken())
            XCTAssertEqual(result.entries.count, count + 1)
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            let userCPU = Double(usage.ru_utime.tv_sec - beforeCPU.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec - beforeCPU.ru_utime.tv_usec) / 1_000_000
            let systemCPU = Double(usage.ru_stime.tv_sec - beforeCPU.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec - beforeCPU.ru_stime.tv_usec) / 1_000_000
            print("PERFORMANCE count=\(count) seconds=\(Date().timeIntervalSince(start)) peakBytes=\(usage.ru_maxrss) userCPU=\(userCPU) systemCPU=\(systemCPU) errors=\(result.entries.filter { $0.status.isError }.count)")
        }
        let token = CancellationToken(), start = Date()
        let cancelled = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: token) { count in if count > 0 { token.cancel() } }
        XCTAssertTrue(cancelled.cancelled)
        print("CANCEL seconds=\(Date().timeIntervalSince(start)) entries=\(cancelled.entries.count)")
    }
}
