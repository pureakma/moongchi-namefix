import Foundation
import Darwin
import NameFixCore

public struct TransactionProgress: Sendable { public var completed: Int; public var total: Int; public var current: String }
public actor TransactionCoordinator {
    public let store: JournalStore
    public init(store: JournalStore) { self.store = store }
    #if DEBUG
    // Deterministic competing-writer injection at the real syscall boundary.
    // This initializer and hook do not exist in Release builds.
    private var beforeMove: (@Sendable (Int32, RenameOperation, Data, Data) throws -> Void)?
    public init(store: JournalStore, beforeMove: @escaping @Sendable (Int32, RenameOperation, Data, Data) throws -> Void) {
        self.store = store; self.beforeMove = beforeMove
    }
    #endif
    func move(_ fd: Int32, operation op: RenameOperation, from: Data, to: Data,
              token: CancellationToken, didMove: () -> Void) throws {
        let source = op.source.parent.appending(from), destination = op.source.parent.appending(to)
        try FileCoordination.move(from: source, to: destination, token: token) { coordination in
            guard try FS.directoryIdentity(fd) == op.parentIdentity,
                  try FS.rawDirectoryPath(fd) == op.source.parent else { throw FSError("SourceChanged") }
            try FS.verify(fd, raw: from, identity: op.identity)
            try FS.verifyVersion(fd, raw: from, expected: op.contentVersion)
            guard !token.cancelled else { throw FSError("Cancelled") }
            coordination.item(at: FileCoordination.url(source), willMoveTo: FileCoordination.url(destination))
            #if DEBUG
            try beforeMove?(fd, op, from, to)
            #endif
            try FS.noReplace(fd, from: from, to: to)
            didMove()
            coordination.item(at: FileCoordination.url(source), didMoveTo: FileCoordination.url(destination))
            try FS.verify(fd, raw: to, identity: op.identity)
            try FS.verifyVersion(fd, raw: to, expected: op.contentVersion)
            guard try FS.rawDirectoryPath(fd) == op.source.parent else { throw FSError("SourceChanged") }
        }
    }
    public func execute(_ plan: RenamePlan, token: CancellationToken, progress: @Sendable (TransactionProgress) -> Void = { _ in }) throws -> TransactionSummary {
        let lockFD = open(store.root.appendingPathComponent("transaction.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0 else { throw FSError("JournalWriteFailed") }
        defer { close(lockFD) }
        guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw FSError("BusyDropRejected") }
        defer { flock(lockFD, LOCK_UN) }
        if Self.needsGraph(plan.operations) { return try executeGraph(plan, token: token, progress: progress) }
        let journal = try JournalWriter(url: store.journalURL(plan.id))
        var summary = TransactionSummary(id: plan.id, date: Date(), mode: plan.mode, total: plan.operations.count, succeeded: 0, failed: 0, status: "Prepared")
        try store.save(summary)
        try journal.append("TransactionPrepared")
        var moves: [(RawPath, RawPath)] = []
        var parentNames: [RawPath: Set<Data>] = [:]
        var lastProgress = Date.distantPast
        for (index, original) in plan.operations.enumerated() {
            if token.cancelled { break }
            var op = original
            for (from, to) in moves { op.source = op.source.replacingPrefix(from, with: to) }
            var moved = false
            do {
                let fd = try FS.openDirectory(op.source.parent); defer { close(fd) }
                guard try FS.directoryIdentity(fd) == op.parentIdentity else { throw FSError("SourceChanged", ESTALE) }
                _ = try FS.capability(fd)
                guard Scanner.protectedReason(op.source) == nil else { throw FSError("VolumeSafetyUnsupported") }
                let s = try FS.metadata(fd, op.source.leaf)
                guard (s.st_mode & S_IFMT == S_IFREG || s.st_mode & S_IFMT == S_IFDIR) && s.st_flags & UInt32(SF_DATALESS) == 0 else { throw FSError("LinkedPathHelp") }
                try FS.verify(fd, raw: op.source.leaf, identity: op.identity)
                if parentNames[op.source.parent] == nil { parentNames[op.source.parent] = Set(try FS.names(fd)) }
                guard try FS.destinationAvailable(fd, source: op.source.leaf, dest: op.destination, expected: op.identity, names: parentNames[op.source.parent]!) else { throw FSError("ConflictHelp", EEXIST) }
                try journal.append("Prepared", operation: op)
                // There is no expected-inode atomic rename in Darwin. Recheck narrows but cannot eliminate external source races.
                try FS.verify(fd, raw: op.source.leaf, identity: op.identity)
                try FS.verifyVersion(fd, raw: op.source.leaf, expected: op.contentVersion)
                try move(fd, operation: op, from: op.source.leaf, to: op.temporary, token: token) { moved = true }
                try FS.verify(fd, raw: op.temporary, identity: op.identity)
                try journal.append("TemporaryRenamed", operation: op)
                try journal.append("FinalIntent", operation: op)
                try FS.verify(fd, raw: op.temporary, identity: op.identity)
                try move(fd, operation: op, from: op.temporary, to: op.destination, token: token) { moved = true }
                try journal.append("FinalRenamed", operation: op)
                try FS.verify(fd, raw: op.destination, identity: op.identity)
                guard try FS.absent(fd, raw: op.temporary), try FS.directoryIdentity(fd) == op.parentIdentity else { throw FSError("SourceChanged", ESTALE) }
                guard fsync(fd) == 0 else { throw FSError("JournalWriteFailed") }
                try journal.append("Verified", operation: op)
                summary.succeeded += 1
                parentNames[op.source.parent]?.remove(op.source.leaf); parentNames[op.source.parent]?.insert(op.destination)
                if s.st_mode & S_IFMT == S_IFDIR { moves.append((op.source, op.finalPath)) }
            } catch {
                summary.failed += 1
                let cause = (error as? FSError)?.code ?? "OperationError"
                let code = moved && cause == "SourceChanged" ? "SourceChangedAfterMove" : cause
                try journal.append("Failed", operation: op, error: code)
                if code == "Cancelled", !moved {
                    summary.failed -= 1; summary.status = "Cancelled"
                    try journal.append("Cancelled"); try store.save(summary); return summary
                }
                if moved || op.groupID != nil || code == "JournalWriteFailed" || code == "SourceChanged" || code == "FileCoordinationFailed" {
                    summary.status = "RecoveryNeedsReview"; try store.save(summary); return summary
                }
            }
            if index + 1 == plan.operations.count || Date().timeIntervalSince(lastProgress) >= 0.1 {
                progress(TransactionProgress(completed: index + 1, total: plan.operations.count, current: op.source.display)); lastProgress = Date()
            }
        }
        summary.status = token.cancelled ? "Cancelled" : summary.failed > 0 ? "CompletedWithErrors" : "Completed"
        try journal.append(summary.status); try store.save(summary)
        return summary
    }
}
