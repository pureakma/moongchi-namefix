import XCTest
import Foundation
import Darwin
import NameFixCore
import NameFixRuntime
import NameFixApplication

final class CoordinatedTransactionTests: XCTestCase, @unchecked Sendable {
    func fixture() throws -> URL {
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NAMEFIX_FIXTURE_ROOT"] ?? "/private/tmp").appendingPathComponent("namefix-coordination-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    func plan(_ root: URL, swap: Bool = false) throws -> RenamePlan {
        var entries = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken()).entries.filter { !$0.isDirectory }
        if swap {
            for i in entries.indices { entries[i].status = .needsNormalization; entries[i].proposed = Data((entries[i].name == "a.txt" ? "b.txt" : "a.txt").utf8) }
        }
        return try Planning.make(entries: entries, selected: Set(entries.filter { $0.status.fixable }.map(\.id)), generation: UUID())
    }

    #if DEBUG
    func testActualTransactionStopsOnReplacementAtBothMovesIncludingUndoAndGraph() async throws {
        for graph in [false, true] {
            for undo in [false, true] {
                for finalMove in [false, true] {
                    let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
                    let names = graph ? ["a.txt", "b.txt"] : ["e\u{301}.txt"]
                    for name in names { try Data("original-\(name)".utf8).write(to: root.appendingPathComponent(name)) }
                    let store = try JournalStore(root: root.appendingPathComponent("journal"))
                    var approved = try plan(root, swap: graph)
                    if undo {
                        let initial = try await TransactionCoordinator(store: store).execute(approved, token: CancellationToken())
                        XCTAssertEqual(initial.succeeded, names.count)
                        approved = try History.undo(store: store, id: approved.id, generation: UUID())
                    }
                    let target = try XCTUnwrap(approved.operations.first)
                    let competitor = root.appendingPathComponent("competing-file")
                    try Data("external replacement".utf8).write(to: competitor)
                    let held = Data("original-retained".utf8)
                    let executor = TransactionCoordinator(store: store) { fd, op, from, _ in
                        guard op.id == target.id, (from == op.temporary) == finalMove else { return }
                        try FS.noReplace(fd, from: from, to: held)
                        try FS.noReplace(fd, from: Data("competing-file".utf8), to: from)
                    }
                    let result = try await executor.execute(approved, token: CancellationToken())
                    XCTAssertEqual(result.status, "RecoveryNeedsReview", "graph=\(graph) undo=\(undo) final=\(finalMove)")
                    XCTAssertEqual(result.succeeded, 0)
                    let moved = finalMove ? target.destination : target.temporary
                    XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(String(decoding: moved, as: UTF8.self))), Data("external replacement".utf8))
                    XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("original-retained").path))
                    let details = try History.details(store: store, id: approved.id)
                    XCTAssertEqual(details.first { $0.id == target.id }?.error, "SourceChangedAfterMove")
                    let review = try History.inspect(store: store, id: approved.id)
                    XCTAssertNil(review.first { $0.id == target.id }?.current)
                    XCTAssertTrue(review.first { $0.id == target.id }?.observedLocations.contains(target.source.parent.appending(moved)) == true)
                    let recovery = try History.recovery(store: store, id: approved.id, generation: UUID())
                    XCTAssertFalse(recovery.operations.contains { $0.undoOf == target.id })
                }
            }
        }
    }

    func testActualTransactionNeverOverwritesCompetingDestinationAtEitherMove() async throws {
        for finalMove in [false, true] {
            let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
            try Data("original".utf8).write(to: root.appendingPathComponent("e\u{301}.txt"))
            let approved = try plan(root), op = try XCTUnwrap(approved.operations.first)
            let store = try JournalStore(root: root.appendingPathComponent("journal"))
            let executor = TransactionCoordinator(store: store) { fd, operation, from, to in
                guard (from == operation.temporary) == finalMove else { return }
                let file = FS.cPath(to) { openat(fd, $0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }
                guard file >= 0 else { throw FSError("FixtureFailure") }; defer { close(file) }
                try Durable.writeAll(file, Data("competing destination".utf8))
            }
            let result = try await executor.execute(approved, token: CancellationToken())
            XCTAssertEqual(result.succeeded, 0)
            let source = finalMove ? op.temporary : op.source.leaf, destination = finalMove ? op.destination : op.temporary
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(String(decoding: source, as: UTF8.self))), Data("original".utf8))
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(String(decoding: destination, as: UTF8.self))), Data("competing destination".utf8))
        }
    }
    #endif

    func testInPlaceEditAfterScanAndAfterConfirmationRequiresFreshPreview() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("e\u{301}.txt")
        try Data("before".utf8).write(to: source)
        let scan = Scanner.scan(roots: [RawPath(source.path)], recursive: false, token: CancellationToken()).entries
        XCTAssertNotNil(scan.first?.contentVersion)
        try Data("modified during preview".utf8).write(to: source)
        let stale = try Planning.make(entries: scan, selected: Set(scan.map(\.id)), generation: UUID())
        XCTAssertTrue(stale.operations.isEmpty); XCTAssertEqual(stale.excluded, 1)
        let fresh = try plan(root)
        XCTAssertEqual(fresh.operations.count, 1)
        try Data("modified after confirmation".utf8).write(to: source)
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let result = try await TransactionCoordinator(store: store).execute(fresh, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 0); XCTAssertEqual(result.status, "RecoveryNeedsReview")
        XCTAssertEqual(try Data(contentsOf: source), Data("modified after confirmation".utf8))
    }

    func testCancelledCoordinationNeverRunsAccessor() throws {
        let token = CancellationToken(); token.cancel()
        XCTAssertThrowsError(try FileCoordination.move(from: RawPath("/private/tmp/source"), to: RawPath("/private/tmp/dest"), token: token) { _ in
            XCTFail("Cancelled operation must not access files")
        }) { XCTAssertEqual(($0 as? FSError)?.code, "Cancelled") }
    }

    func testCooperatingWriterBlocksRenameAndWaitCanBeCancelledOrTimeOut() throws {
        for cancel in [false, true] {
            let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
            let source = root.appendingPathComponent("source.txt"), destination = root.appendingPathComponent("dest.txt")
            try Data("preserved".utf8).write(to: source)
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0), finished = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                var error: NSError?
                NSFileCoordinator().coordinate(writingItemAt: source, options: [], error: &error) { _ in
                    entered.signal(); _ = release.wait(timeout: .now() + 5)
                }
                finished.signal()
            }
            XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
            defer { release.signal(); _ = finished.wait(timeout: .now() + 5) }
            let token = CancellationToken()
            if cancel { DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { token.cancel() } }
            let start = Date()
            XCTAssertThrowsError(try FileCoordination.move(from: RawPath(source.path), to: RawPath(destination.path), token: token, timeout: cancel ? 3 : 0.15) { _ in
                XCTFail("A competing coordinated writer must block access")
            }) { XCTAssertEqual(($0 as? FSError)?.code, cancel ? "Cancelled" : "FileCoordinationFailed") }
            XCTAssertLessThan(Date().timeIntervalSince(start), 2)
            XCTAssertEqual(try Data(contentsOf: source), Data("preserved".utf8))
        }
    }

    func testThousandCoordinatedRenamesProfile() async throws {
        guard ProcessInfo.processInfo.environment["NAMEFIX_MUTATION_PERF"] == "1" else { throw XCTSkip("Opt-in mutation performance profile") }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for i in 0..<1000 { try Data("original \(i)".utf8).write(to: root.appendingPathComponent("e\u{301}-\(i).txt")) }
        let approved = try plan(root); XCTAssertEqual(approved.operations.count, 1000)
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let start = Date()
        let result = try await TransactionCoordinator(store: store).execute(approved, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 1000); XCTAssertEqual(result.failed, 0)
        print("COORDINATED_MUTATION count=1000 seconds=\(Date().timeIntervalSince(start)) durable_journal=true content_size_mtime_check=true")
        for i in 0..<1000 { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("é-\(i).txt")), Data("original \(i)".utf8)) }
    }
}
