import Foundation
import Darwin
import NameFixCore
import NameFixRuntime

public enum RulePreview {
    public static func apply(_ entries: [FileEntry], pipeline: RulePipeline, access: ProductAccess, token: CancellationToken) async throws -> [FileEntry] {
        try pipeline.validate(access: access)
        let map = try pipeline.mapping?.index()
        var matchedKeys: [Data: Int] = [:], entryKeys: [RawPath: Data] = [:]
        func matchingKeys(_ path: RawPath, map: [Data: String]) -> [Data] {
            var keys: [Data] = []
            if map[path.bytes] != nil { keys.append(path.bytes) }
            for index in path.bytes.indices where path.bytes[index] == 47 && index + 1 < path.bytes.count {
                let suffix = Data(path.bytes.dropFirst(index + 1))
                if map[suffix] != nil { keys.append(suffix) }
            }
            return keys
        }
        if let map {
            for entry in entries where !entry.status.isError {
                let keys = matchingKeys(entry.path, map: map)
                guard keys.count <= 1 else { throw FSError("MappingAmbiguous") }
                if let key = keys.first { matchedKeys[key, default: 0] += 1; entryKeys[entry.path] = key }
            }
            // Refuse the entire import on ambiguous/unmatched input, rather than silently applying a subset.
            guard map.keys.allSatisfy({ matchedKeys[$0] == 1 }) else { throw FSError("MappingAmbiguous") }
        }
        // Validated once above; per-entry evaluation must not re-check the whole manual order.
        var rulesOnly = pipeline; rulesOnly.mapping = nil; rulesOnly.manualPaths = nil
        var result = entries
        let directories = DirectoryReadSession()
        // Byte order is independent of locale/UI filters and stable across repeated previews.
        let manual = Dictionary((pipeline.manualPaths ?? []).enumerated().map { (RawPath(bytes: $0.element), $0.offset) }, uniquingKeysWith: { a, _ in a })
        var order = entries.indices.sorted { a, b in
            switch pipeline.order ?? .path {
            case .reversePath: return entries[b].path.bytes.lexicographicallyPrecedes(entries[a].path.bytes)
            case .name:
                if entries[a].path.leaf != entries[b].path.leaf { return entries[a].path.leaf.lexicographicallyPrecedes(entries[b].path.leaf) }
            case .manual:
                let x = manual[entries[a].path] ?? Int.max, y = manual[entries[b].path] ?? Int.max
                if x != y { return x < y }
            case .path: break
            }
            return entries[a].path.bytes.lexicographicallyPrecedes(entries[b].path.bytes)
        }
        let extensions = (pipeline.pairExtensions ?? []).map { $0.lowercased() }
        let pairMembers = Dictionary(grouping: entries.indices.filter { !entries[$0].isDirectory && extensions.contains(RulePipeline.parts(entries[$0].name, directory: false).ext.lowercased()) }) { i in
            RawPath(bytes: entries[i].path.parent.bytes + Data([0]) + Data(RulePipeline.parts(entries[i].name, directory: false).stem.utf8))
        }
        var pairKeys: [Int: RawPath] = [:], invalidPairs = Set<Int>()
        for (key, members) in pairMembers {
            let ext = members.map { RulePipeline.parts(entries[$0].name, directory: false).ext.lowercased() }
            if Set(ext).count != ext.count || members.contains(where: { entries[$0].status.isError }) { invalidPairs.formUnion(members) }
            if members.count > 1 { for i in members { pairKeys[i] = key } }
        }
        if !pairKeys.isEmpty {
            var groupedOrder: [Int] = [], seenGroups = Set<RawPath>()
            for i in order {
                guard let key = pairKeys[i] else { groupedOrder.append(i); continue }
                if seenGroups.insert(key).inserted {
                    groupedOrder += (pairMembers[key] ?? []).sorted { a, b in
                        let x = extensions.firstIndex(of: RulePipeline.parts(entries[a].name, directory: false).ext.lowercased()) ?? Int.max
                        let y = extensions.firstIndex(of: RulePipeline.parts(entries[b].name, directory: false).ext.lowercased()) ?? Int.max
                        return x == y ? entries[a].path.bytes.lexicographicallyPrecedes(entries[b].path.bytes) : x < y
                    }
                }
            }
            order = groupedOrder
        }
        var pairResults: [RawPath: String] = [:], pairNumbers: [RawPath: (Int, Int)] = [:]
        let metadataKeys = Set(pipeline.rules.filter { $0.enabled && $0.kind == .metadata }.map(\.text))
        var parents: [RawPath: Int] = [:], number = 0
        var names: [RawPath: Set<Data>] = [:]
        for i in order {
            if token.cancelled { throw RuleFailure.cancelled }
            guard !entries[i].status.isError else { continue }
            var entry = entries[i]
            if invalidPairs.contains(i) { entry.status = .unsupported; entry.reason = "PairAmbiguous"; result[i] = entry; continue }
            entry.groupID = pairKeys[i]?.bytes
            // Finder bookkeeping files keep their names and do not consume a sequence number.
            if !pipeline.rules.isEmpty || pipeline.mapping != nil, NameRules.finderMetadata(entry.path.leaf) { entry.proposed = entry.path.leaf; entry.status = .normal; entry.reason = "NormalHelp"; result[i] = entry; continue }
            let existingNumbers = pairKeys[i].flatMap { pairNumbers[$0] }
            let indices = existingNumbers ?? (number, parents[entry.path.parent, default: 0])
            if existingNumbers == nil { number += 1; parents[entry.path.parent, default: 0] += 1; if let key = pairKeys[i] { pairNumbers[key] = indices } }
            var context = RuleContext(index: indices.0, folderIndex: indices.1, isDirectory: entry.isDirectory)
            do {
                if !metadataKeys.isEmpty {
                    let fd = try directories.open(entry.path.parent)
                    // Folders are exempt from the freshness check: renaming their children changes their mtime.
                    let current = try FS.metadata(fd, entry.path.leaf)
                    if current.st_mode & S_IFMT == S_IFREG { entry.contentVersion = FS.version(current) }
                    if pairKeys[i].flatMap({ pairResults[$0] }) == nil {
                        context.metadata = try await MetadataReader.read(entry, keys: metadataKeys, format: pipeline.dateFormat ?? "yyyy-MM-dd", zone: pipeline.timeZone ?? "UTC", token: token)
                        try FS.verifyVersion(fd, raw: entry.path.leaf, expected: entry.contentVersion)
                    }
                }
                let key = entryKeys[entry.path] ?? entry.path.leaf
                if map != nil && map?[key] == nil { entry.proposed = entry.path.leaf; entry.status = .normal; entry.reason = "MappingUnmatched"; result[i] = entry; continue }
                let inputName = map?[key] ?? entry.name
                if let pair = pairKeys[i], let stem = pairResults[pair] {
                    entry.proposed = Data((stem + "." + RulePipeline.parts(entry.name, directory: false).ext).utf8)
                } else {
                    let steps = try rulesOnly.evaluate(inputName, context: context, access: access, cancelled: { token.cancelled })
                    entry.proposed = Data((steps.last?.after ?? entry.name).utf8)
                    if let pair = pairKeys[i] { pairResults[pair] = RulePipeline.parts(entry.preview, directory: false).stem }
                }
                entry.status = entry.proposed == entry.path.leaf ? .normal : .needsNormalization
                entry.reason = entry.status == .normal ? "NormalHelp" : pipeline.rules.isEmpty && pipeline.mapping == nil ? pipeline.target == .nfd ? "NFDChangeHelp" : "ChangeHelp" : "RuleChangeHelp"
                let fd = try directories.open(entry.path.parent)
                guard entry.identity != nil else { throw FSError("SourceChanged") }
                if names[entry.path.parent] == nil { names[entry.path.parent] = Set(try FS.names(fd)) }
                guard NameRules.valid(entry.proposed, limit: Int(fpathconf(fd, _PC_NAME_MAX))) else { throw RuleFailure.invalid }
            } catch let error as RuleFailure {
                if error == .cancelled || error == .regexBudget || error == .regex { throw error }
                entry.status = .unsupported; entry.reason = error.rawValue
            } catch { entry.status = .unavailable; entry.reason = (error as? FSError)?.code ?? "OperationError" }
            result[i] = entry
        }
        let proposedGroups = Dictionary(grouping: result.filter { !$0.status.isError }) { e in RawPath(bytes: e.path.parent.bytes + Data([0]) + Data(e.preview.precomposedStringWithCanonicalMapping.lowercased().utf8)) }
        let duplicates = Set(proposedGroups.values.filter { $0.count > 1 }.flatMap { $0.filter { $0.status.fixable }.map(\.id) })
        for i in result.indices where duplicates.contains(result[i].id) { result[i].status = .conflict; result[i].reason = "ConflictHelp" }
        // Check destination occupants after every proposal is known. A selected plan will
        // recheck dependencies; an unselected source never grants permission to move it.
        let moving = Dictionary(grouping: result.filter { $0.status.fixable }) { RawPath(bytes: $0.path.parent.bytes + Data([0]) + Data($0.name.precomposedStringWithCanonicalMapping.lowercased().utf8)) }
        for i in result.indices where result[i].status.fixable {
            let entry = result[i]
            do {
                let fd = try directories.open(entry.path.parent)
                guard let identity = entry.identity else { throw FSError("SourceChanged") }
                let siblings = try names[entry.path.parent] ?? Set(FS.names(fd))
                if try !FS.destinationAvailable(fd, source: entry.path.leaf, dest: entry.proposed, expected: identity, names: siblings) {
                    let candidates = (moving[RawPath(bytes: entry.path.parent.bytes + Data([0]) + Data(entry.preview.precomposedStringWithCanonicalMapping.lowercased().utf8))] ?? []).filter { $0.id != entry.id }
                    if candidates.count != 1 { result[i].status = .conflict; result[i].reason = "ConflictHelp" }
                }
            } catch { result[i].status = .unavailable; result[i].reason = (error as? FSError)?.code ?? "OperationError" }
        }
        for members in pairMembers.values where members.count > 1 {
            if members.contains(where: { result[$0].status.isError || result[$0].status == .conflict }) {
                for i in members where result[i].status.fixable { result[i].status = .conflict; result[i].reason = "PairAmbiguous" }
            }
        }
        return result
    }
}
