import Foundation
import CryptoKit
import NameFixCore
import NameFixRuntime

public enum WatchSnapshot {
    public static func key(_ path: RawPath) -> Data { Data(SHA256.hash(data: path.bytes)) }
    /// Watch workflows process files only; the authorized root itself is never renamed.
    public static func candidates(_ entries: [FileEntry], baseline: [Data: WatchedFile], token: CancellationToken, pairExtensions: [String] = []) async throws -> [FileEntry] {
        let directories = DirectoryReadSession()
        var result: [FileEntry] = [], unchanged: [FileEntry] = []
        for var entry in entries where !entry.isDirectory {
            if token.cancelled { throw RuleFailure.cancelled }
            do {
                guard let identity = entry.identity else { result.append(entry); continue }
                let fd = try directories.open(entry.path.parent)
                try FS.verify(fd, raw: entry.path.leaf, identity: identity)
                let version = FS.version(try FS.metadata(fd, entry.path.leaf))
                entry.contentVersion = version
                if baseline[key(entry.path)] == WatchedFile(identity: identity, version: version) { unchanged.append(entry); continue }
            } catch { entry.status = .unavailable; entry.reason = "WatchWriting" }
            result.append(entry)
        }
        if !pairExtensions.isEmpty {
            func key(_ entry: FileEntry) -> Data? {
                let parts = RulePipeline.parts(entry.name, directory: false)
                guard pairExtensions.contains(where: { $0.lowercased() == parts.ext.lowercased() }) else { return nil }
                return entry.path.parent.bytes + Data([0]) + Data(parts.stem.utf8)
            }
            let changedGroups = Set(result.compactMap(key))
            result += unchanged.filter { key($0).map(changedGroups.contains) ?? false }
        }
        if !result.isEmpty { try await Task.sleep(for: .milliseconds(250)) }
        for i in result.indices where !result[i].status.isError {
            if token.cancelled { throw RuleFailure.cancelled }
            do {
                let fd = try directories.open(result[i].path.parent)
                try FS.verifyVersion(fd, raw: result[i].path.leaf, expected: result[i].contentVersion)
            } catch { result[i].status = .unavailable; result[i].reason = "WatchWriting" }
        }
        return result
    }
}
