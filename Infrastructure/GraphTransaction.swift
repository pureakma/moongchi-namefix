import Foundation
import Darwin
import NameFixCore

extension TransactionCoordinator {
    static func key(parent: RawPath, name: Data) -> RawPath {
        RawPath(bytes: parent.bytes + Data([0]) + Data(String(decoding: name, as: UTF8.self).precomposedStringWithCanonicalMapping.lowercased().utf8))
    }
    static func needsGraph(_ operations: [RenameOperation]) -> Bool {
        let sources = Dictionary(operations.map { (key(parent: $0.source.parent, name: $0.source.leaf), $0.id) }, uniquingKeysWith: { first, _ in first })
        return operations.contains { op in sources[key(parent: op.source.parent, name: op.destination)].map { $0 != op.id } ?? false }
    }
    // Caller holds the same process lock as the normal transaction path.
    func executeGraph(_ plan: RenamePlan, token: CancellationToken, fast: Bool = false, progress: @Sendable (TransactionProgress) -> Void) throws -> TransactionSummary {
        let journal = try JournalWriter(url: store.journalURL(plan.id), fast: fast)
        var summary = TransactionSummary(id: plan.id, date: Date(), mode: plan.mode, total: plan.operations.count, succeeded: 0, failed: 0, status: "Prepared")
        try store.save(summary); try journal.append("TransactionPrepared")
        let groups = Dictionary(grouping: plan.operations, by: { $0.source.parent }).sorted { $0.key.depth > $1.key.depth }
        for (_, originals) in groups {
            if token.cancelled { break }
            // Children are fully processed before their parent groups. No prior peer
            // rename may remap a different source in a swap/cycle.
            let operations = originals
            guard let first = operations.first else { continue }
            var pending: RenameOperation?
            var staged = false
            do {
                let fd = try FS.openDirectory(first.source.parent); defer { close(fd) }
                _ = try FS.capability(fd)
                guard try FS.directoryIdentity(fd) == first.parentIdentity else { throw FSError("SourceChanged") }
                let names = Set(try FS.names(fd))
                var destinations = Set<RawPath>(), temporaries = Set<Data>()
                let sourceIndex = Dictionary(grouping: operations) { Self.key(parent: $0.source.parent, name: $0.source.leaf) }
                for op in operations {
                    pending = op
                    guard op.source.parent == first.source.parent, op.parentIdentity == first.parentIdentity,
                          Scanner.protectedReason(op.source) == nil,
                          NameRules.valid(op.destination), !names.contains(op.temporary), temporaries.insert(op.temporary).inserted,
                          destinations.insert(Self.key(parent: op.source.parent, name: op.destination)).inserted else { throw FSError("ConflictHelp") }
                    try FS.verify(fd, raw: op.source.leaf, identity: op.identity)
                    let sourceStat = try FS.metadata(fd, op.source.leaf)
                    guard sourceStat.st_mode & S_IFMT == S_IFREG || sourceStat.st_mode & S_IFMT == S_IFDIR, sourceStat.st_flags & UInt32(SF_DATALESS) == 0 else { throw FSError("LinkedPathHelp") }
                    if try !FS.destinationAvailable(fd, source: op.source.leaf, dest: op.destination, expected: op.identity, names: names) {
                        let occupant = try FS.identity(FS.metadata(fd, op.destination))
                        let peers = sourceIndex[Self.key(parent: op.source.parent, name: op.destination)] ?? []
                        guard peers.count == 1, peers[0].identity == occupant else { throw FSError("ConflictHelp") }
                    }
                }
                // Durable intents for every staged source, so partial staging can be recovered.
                for op in operations { try journal.append("Prepared", operation: op) }
                for op in operations {
                    pending = op
                    if token.cancelled { throw FSError("Cancelled") }
                    try FS.verify(fd, raw: op.source.leaf, identity: op.identity)
                    try FS.verifyVersion(fd, raw: op.source.leaf, expected: op.contentVersion)
                    try move(fd, operation: op, from: op.source.leaf, to: op.temporary, token: token) { staged = true }
                    try FS.verify(fd, raw: op.temporary, identity: op.identity)
                    try journal.append("TemporaryRenamed", operation: op)
                }
                for op in operations {
                    pending = op
                    if token.cancelled { throw FSError("Cancelled") }
                    try journal.append("FinalIntent", operation: op)
                    try FS.verify(fd, raw: op.temporary, identity: op.identity)
                    try move(fd, operation: op, from: op.temporary, to: op.destination, token: token) { staged = true }
                    try journal.append("FinalRenamed", operation: op)
                    try FS.verify(fd, raw: op.destination, identity: op.identity)
                    guard try FS.absent(fd, raw: op.temporary), fsync(fd) == 0 else { throw FSError("SourceChanged") }
                    try journal.append("Verified", operation: op)
                    summary.succeeded += 1
                    progress(TransactionProgress(completed: summary.succeeded, total: plan.operations.count, current: op.source.display))
                }
            } catch {
                summary.failed += 1
                let cause = (error as? FSError)?.code ?? "OperationError"
                try journal.append("Failed", operation: pending, error: staged && cause == "SourceChanged" ? "SourceChangedAfterMove" : cause)
                summary.status = staged ? "RecoveryNeedsReview" : cause == "Cancelled" ? "Cancelled" : "CompletedWithErrors"
                // Nothing in this group moved, so the transaction is terminal; without this
                // event the inspector would list earlier verified groups as unfinished.
                if !staged { try journal.append(summary.status) }
                try store.save(summary); return summary
            }
        }
        summary.status = token.cancelled ? "Cancelled" : "Completed"
        try journal.append(summary.status); try store.save(summary); return summary
    }
}
