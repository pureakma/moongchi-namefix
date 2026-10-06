import Foundation
import Darwin
import NameFixCore
import NameFixRuntime

public enum Planning {
    public static func make(entries: [FileEntry], selected: Set<UUID>, generation: UUID) throws -> RenamePlan {
        var operations: [RenameOperation] = [], excluded = entries.filter { $0.status == .conflict || $0.status.isError }.count
        let groups = Dictionary(grouping: entries.filter { $0.groupID != nil }, by: { $0.groupID! })
        let incompleteGroups = Set(groups.filter { _, rows in rows.contains { !$0.status.fixable || !selected.contains($0.id) } }.keys)
        let candidates = entries.filter { selected.contains($0.id) && $0.status.fixable && ($0.groupID == nil || !incompleteGroups.contains($0.groupID!)) }
        excluded += entries.filter { selected.contains($0.id) && $0.status.fixable && $0.groupID.map(incompleteGroups.contains) == true }.count
        var snapshots: [RawPath: Set<Data>] = [:]
        let directories = DirectoryReadSession()
        for entry in candidates.sorted(by: { $0.path.depth == $1.path.depth ? $0.path.bytes.lexicographicallyPrecedes($1.path.bytes) : $0.path.depth > $1.path.depth }) {
            guard let identity = entry.identity, let parent = entry.parentIdentity else { excluded += 1; continue }
            do {
                let fd = try directories.open(entry.path.parent)
                guard try FS.directoryIdentity(fd) == parent else { throw FSError("SourceChanged") }
                _ = try FS.capability(fd)
                let names: Set<Data>
                if let cached = snapshots[entry.path.parent] { names = cached } else { names = Set(try FS.names(fd)); snapshots[entry.path.parent] = names }
                guard names.contains(entry.path.leaf), try FS.identity(FS.metadata(fd, entry.path.leaf)) == identity, NameRules.valid(entry.proposed, limit: Int(fpathconf(fd, _PC_NAME_MAX))) else { throw FSError("SourceChanged") }
                try FS.verifyVersion(fd, raw: entry.path.leaf, expected: entry.contentVersion)
                var fresh = entry
                let metadata = try FS.metadata(fd, entry.path.leaf)
                guard FS.identity(metadata) == identity else { throw FSError("SourceChanged") }
                if let expected = entry.contentVersion, expected != FS.version(metadata) { throw FSError("SourceChanged") }
                if metadata.st_mode & S_IFMT == S_IFREG { fresh.contentVersion = FS.version(metadata) }
                operations.append(try RenameOperation(entry: fresh))
            } catch { excluded += 1 }
        }
        // Remove every duplicate destination, never select an arbitrary winner.
        let grouped = Dictionary(grouping: operations) { op in op.source.parent.bytes + Data([0]) + Data(String(decoding: op.destination, as: UTF8.self).precomposedStringWithCanonicalMapping.lowercased().utf8) }
        let duplicates = Set(grouped.values.filter { $0.count > 1 }.flatMap { $0.map(\.id) })
        excluded += operations.filter { duplicates.contains($0.id) }.count
        operations.removeAll { duplicates.contains($0.id) }
        // Propagate exclusions: a destination must be free or vacated by an included source.
        var changed = true
        while changed {
            changed = false
            let operationGroupCounts = Dictionary(grouping: operations.filter { $0.groupID != nil }, by: { $0.groupID! }).mapValues(\.count)
            let completeGroups = Set(groups.filter { key, members in operationGroupCounts[key] == members.count }.keys)
            let peersByKey = Dictionary(grouping: operations) { op in op.source.parent.bytes + Data([0]) + Data(String(decoding: op.source.leaf, as: UTF8.self).precomposedStringWithCanonicalMapping.lowercased().utf8) }
            operations = operations.filter { op in
                if let group = op.groupID, !completeGroups.contains(group) { excluded += 1; changed = true; return false }
                do {
                    let fd = try directories.open(op.source.parent)
                    if try FS.destinationAvailable(fd, source: op.source.leaf, dest: op.destination, expected: op.identity, names: snapshots[op.source.parent] ?? []) { return true }
                    let key = Data(String(decoding: op.destination, as: UTF8.self).precomposedStringWithCanonicalMapping.lowercased().utf8)
                    let peers = (peersByKey[op.source.parent.bytes + Data([0]) + key] ?? []).filter { $0.id != op.id }
                    if peers.count == 1, try FS.identity(FS.metadata(fd, op.destination)) == peers[0].identity { try FS.verify(fd, raw: peers[0].source.leaf, identity: peers[0].identity); return true }
                } catch { /* Count and surface excluded operations in the confirmation. */ }
                excluded += 1; changed = true; return false
            }
        }
        return RenamePlan(generation: generation, operations: operations, excluded: excluded)
    }
    public static func numbered(_ entries: [FileEntry]) throws -> [FileEntry] {
        var result = entries, reserved: [RawPath: Set<String>] = [:]
        for i in result.indices.sorted(by: { result[$0].path.bytes.lexicographicallyPrecedes(result[$1].path.bytes) }) where result[i].status == .conflict {
            let entry = result[i]
            guard let identity = entry.identity else { continue }
            let fd = try FS.openDirectory(entry.path.parent); defer { close(fd) }
            try FS.verify(fd, raw: entry.path.leaf, identity: identity)
            let names = Set(try FS.names(fd))
            for number in 1...200_000 {
                let proposal = NameRules.numbered(entry.preview, directory: entry.isDirectory, number: number)
                guard NameRules.valid(proposal, limit: Int(fpathconf(fd, _PC_NAME_MAX))) else { break }
                let key = String(decoding: proposal, as: UTF8.self).precomposedStringWithCanonicalMapping.lowercased()
                if reserved[entry.path.parent, default: []].contains(key) { continue }
                if try FS.destinationAvailable(fd, source: entry.path.leaf, dest: proposal, expected: identity, names: names) {
                    reserved[entry.path.parent, default: []].insert(key)
                    result[i].proposed = proposal; result[i].status = .needsNormalization; result[i].reason = "NumberExplanation"; break
                }
            }
        }
        return result
    }
}

public struct HistoryDetail: Identifiable, Sendable {
    public var id: UUID { operation.id }
    public var operation: RenameOperation
    public var state: String
    public var error: String?
}
public struct RecoveryInspection: Identifiable, Sendable {
    public var id: UUID { operation.id }
    public var operation: RenameOperation
    public var current: RawPath?
    public var status: String
    public var observedLocations: [RawPath] = []
    public init(operation: RenameOperation, current: RawPath?, status: String, observedLocations: [RawPath] = []) {
        self.operation = operation; self.current = current; self.status = status; self.observedLocations = observedLocations
    }
}
public enum History {
    public static func details(store: JournalStore, id: UUID) throws -> [HistoryDetail] {
        let replay = try store.replay(id)
        guard replay.valid else { throw FSError("HistoryWarning") }
        var rows: [UUID: HistoryDetail] = [:], order: [UUID] = []
        for event in replay.events { if let op = event.operation { if rows[op.id] == nil { order.append(op.id) }; rows[op.id] = HistoryDetail(operation: op, state: event.state, error: event.error) } }
        return order.compactMap { rows[$0] }
    }
    private static func batches(store: JournalStore) throws -> [(UUID, [RenameOperation])] {
        try store.summaries().sorted { $0.date < $1.date }.map { summary in
            let replay = try store.replay(summary.id)
            guard replay.valid else { throw FSError("HistoryWarning") }
            return (summary.id, replay.events.compactMap { $0.state == "Verified" ? $0.operation : nil })
        }
    }
    private static func timeline(store: JournalStore) throws -> [RenameOperation] { try batches(store: store).flatMap { $0.1 } }
    private static func mapped(_ path: RawPath, through operations: [RenameOperation]) -> RawPath {
        let groups = Dictionary(grouping: operations, by: { $0.source.parent }).sorted { $0.key.depth > $1.key.depth }
        return groups.reduce(path) { path, group in HistoryPathMap.apply(path, moves: group.value.map { ($0.source, $0.finalPath) }) }
    }
    public static func undo(store: JournalStore, id: UUID, generation: UUID) throws -> RenamePlan {
        let replay = try store.replay(id)
        guard replay.valid else { throw FSError("HistoryWarning") }
        let all = try timeline(store: store)
        let completed = Set(all.compactMap(\.undoOf))
        let batchList = try batches(store: store)
        guard let batchIndex = batchList.firstIndex(where: { $0.0 == id }) else { throw FSError("HistoryWarning") }
        let originals = replay.events.compactMap { $0.state == "Verified" ? $0.operation : nil }
        var operations: [RenameOperation] = [], excluded = 0
        for original in replay.events.compactMap({ $0.state == "Verified" ? $0.operation : nil }).reversed() {
            if completed.contains(original.id) { continue }
            var current = mapped(original.finalPath, through: originals.filter { $0.source.depth < original.source.depth })
            for batch in batchList.dropFirst(batchIndex + 1) { current = mapped(current, through: batch.1) }
            do {
                let fd = try FS.openDirectory(current.parent); defer { close(fd) }
                try FS.verify(fd, raw: current.leaf, identity: original.identity)
                guard try FS.directoryIdentity(fd) == original.parentIdentity else { throw FSError("SourceChanged") }
                // Destination occupancy is validated for the entire reverse plan below.
                let e = FileEntry(path: current, identity: original.identity, parentIdentity: original.parentIdentity, status: .needsNormalization, reason: "Undo", proposed: original.source.leaf)
                operations.append(try RenameOperation(entry: e, undoOf: original.id))
            } catch { excluded += 1 }
        }
        let entries = operations.map { FileEntry(id: $0.entryID, path: $0.source, identity: $0.identity, parentIdentity: $0.parentIdentity, status: .needsNormalization, reason: "Undo", proposed: $0.destination) }
        var plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: generation)
        let byEntry = Dictionary(operations.map { ($0.entryID, $0) }, uniquingKeysWith: { first, _ in first })
        for i in plan.operations.indices { plan.operations[i].undoOf = byEntry[plan.operations[i].entryID]?.undoOf }
        plan.mode = "undo"; plan.excluded += excluded
        return plan
    }
    public static func inspect(store: JournalStore, id: UUID) throws -> [RecoveryInspection] {
        let replay = try store.replay(id)
        guard replay.valid else { throw FSError("HistoryWarning") }
        let rows = try details(store: store, id: id)
        let all = try timeline(store: store), completed = Set(all.compactMap(\.undoOf))
        let unfinished = !replay.events.contains { ["Completed", "CompletedWithErrors", "Cancelled"].contains($0.state) }
        return rows.filter { !completed.contains($0.id) && (unfinished || $0.state != "Verified") }.map { row in
            let op = row.operation
            do {
                let fd = try FS.openDirectory(op.source.parent); defer { close(fd) }
                guard try FS.directoryIdentity(fd) == op.parentIdentity else { throw FSError("SourceChanged") }
                let names = Set(try FS.names(fd))
                let candidates = [op.source.leaf, op.temporary, op.destination].filter { names.contains($0) }
                let matching = try candidates.filter { try FS.identity(FS.metadata(fd, $0)) == op.identity }
                guard matching.count == 1 else { return RecoveryInspection(operation: op, current: nil, status: "Ambiguous", observedLocations: candidates.map { op.source.parent.appending($0) }) }
                return RecoveryInspection(operation: op, current: op.source.parent.appending(matching[0]), status: matching[0] == op.source.leaf ? "RolledBack" : "Present", observedLocations: candidates.map { op.source.parent.appending($0) })
            } catch { return RecoveryInspection(operation: op, current: nil, status: "Ambiguous") }
        }
    }
    public static func recovery(store: JournalStore, id: UUID, generation: UUID) throws -> RenamePlan {
        let rows = try inspect(store: store, id: id)
        var operations: [RenameOperation] = [], excluded = 0
        for row in rows {
            guard let path = row.current else { excluded += 1; continue }
            if row.status == "RolledBack" { continue }
            let op = row.operation
            let e = FileEntry(path: path, identity: op.identity, parentIdentity: op.parentIdentity, status: .needsNormalization, reason: "RecoveryNeedsReview", proposed: op.source.leaf)
            operations.append(try RenameOperation(entry: e, undoOf: op.id))
        }
        let entries = operations.map { FileEntry(id: $0.entryID, path: $0.source, identity: $0.identity, parentIdentity: $0.parentIdentity, status: .needsNormalization, reason: "RecoveryNeedsReview", proposed: $0.destination) }
        var plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: generation)
        let byEntry = Dictionary(operations.map { ($0.entryID, $0.undoOf) }, uniquingKeysWith: { first, _ in first })
        for i in plan.operations.indices { plan.operations[i].undoOf = byEntry[plan.operations[i].entryID] ?? nil }
        plan.mode = "recovery"; plan.excluded += excluded
        return plan
    }
    public static func remap(_ roots: [RawPath], store: JournalStore, id: UUID) throws -> [RawPath] {
        let replay = try store.replay(id)
        guard replay.valid else { throw FSError("HistoryWarning") }
        let moves = replay.events.compactMap { $0.state == "Verified" ? $0.operation : nil }
        // Each parent group is simultaneous; never feed A→B into its peer B→A.
        let groups = Dictionary(grouping: moves, by: { $0.source.parent }).sorted { $0.key.depth > $1.key.depth }
        return groups.reduce(roots) { paths, group in
            paths.map { HistoryPathMap.apply($0, moves: group.value.map { ($0.source, $0.finalPath) }) }
        }
    }
}
