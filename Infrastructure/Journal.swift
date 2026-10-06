import Foundation
import CryptoKit
import Darwin
import NameFixCore

public enum Durable {
    public static func writeAll(_ fd: Int32, _ data: Data) throws {
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let n = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw FSError("JournalWriteFailed") }
                offset += n
            }
        }
    }
    public static func sync(_ fd: Int32) throws { guard fsync(fd) == 0 else { throw FSError("JournalWriteFailed") }; guard fcntl(fd, F_FULLFSYNC) == 0 else { throw FSError("JournalWriteFailed") } }
    public static func atomic<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".write-\(UUID())")
        let fd = open(tmp.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw FSError("JournalWriteFailed") }
        defer { close(fd) }
        try writeAll(fd, data); try sync(fd)
        // Replacement is limited to application-owned settings/summary files, never user files.
        guard rename(tmp.path, url.path) == 0 else { throw FSError("JournalWriteFailed") }
        let dir = try FS.openDirectory(RawPath(url.deletingLastPathComponent().path)); defer { close(dir) }
        guard fsync(dir) == 0 else { throw FSError("JournalWriteFailed") }
    }
    public static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
public struct JournalEvent: Codable, Sendable {
    public var schemaVersion: Int = 2
    public var sequence: Int
    public var previous: String
    public var date: Date = Date()
    public var state: String
    public var operation: RenameOperation?
    public var error: String?
}
private struct Envelope: Codable { var payload: Data; var checksum: String }
public struct JournalReplay: Sendable {
    public var events: [JournalEvent]
    public var valid: Bool
}
public struct TransactionSummary: Codable, Identifiable, Sendable {
    public var schemaVersion: Int = 1
    public var id: UUID
    public var date: Date
    public var mode: String
    public var total: Int
    public var succeeded: Int
    public var failed: Int
    public var status: String
}
public final class JournalWriter {
    private let fd: Int32
    private var sequence = 0
    private var previous = ""
    public init(url: URL) throws {
        fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw FSError("JournalWriteFailed") }
        let dir = try FS.openDirectory(RawPath(url.deletingLastPathComponent().path)); defer { close(dir) }
        // deinit closes fd when this throws; closing here as well would release it twice.
        guard fsync(dir) == 0 else { throw FSError("JournalWriteFailed") }
    }
    deinit { close(fd) }
    public func append(_ state: String, operation: RenameOperation? = nil, error: String? = nil) throws {
        let event = JournalEvent(sequence: sequence, previous: previous, state: state, operation: operation, error: error)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(event), checksum = Durable.hash(payload)
        var line = try encoder.encode(Envelope(payload: payload, checksum: checksum)); line.append(10)
        try Durable.writeAll(fd, line); try Durable.sync(fd)
        sequence += 1; previous = checksum
    }
}
public struct JournalStore: Sendable {
    public let root: URL
    public init(root: URL) throws { self.root = root; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]) }
    public func journalURL(_ id: UUID) -> URL { root.appendingPathComponent("\(id).jsonl") }
    public func summaryURL(_ id: UUID) -> URL { root.appendingPathComponent("\(id).summary.json") }
    public func save(_ summary: TransactionSummary) throws { try Durable.atomic(summary, to: summaryURL(summary.id)) }
    public func summaries() throws -> [TransactionSummary] {
        var summaries: [TransactionSummary] = []
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) where url.lastPathComponent.hasSuffix(".jsonl") {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            do {
                let s = try JSONDecoder().decode(TransactionSummary.self, from: Data(contentsOf: summaryURL(id)))
                guard s.schemaVersion == 1 else { throw FSError("NewerSchema") }; summaries.append(s)
            } catch { summaries.append(TransactionSummary(id: id, date: .distantPast, mode: "recovery", total: 0, succeeded: 0, failed: 0, status: "RecoveryNeedsReview")) }
        }
        return summaries.sorted { $0.date > $1.date }
    }
    public func replay(_ id: UUID) throws -> JournalReplay {
        let handle = try FileHandle(forReadingFrom: journalURL(id)); defer { try? handle.close() }
        var buffer = Data(), events: [JournalEvent] = [], previous = ""
        while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty {
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline]); buffer.removeSubrange(...newline)
                guard let env = try? JSONDecoder().decode(Envelope.self, from: line), Durable.hash(env.payload) == env.checksum,
                      let event = try? JSONDecoder().decode(JournalEvent.self, from: env.payload), (1...2).contains(event.schemaVersion), event.sequence == events.count, event.previous == previous else { return JournalReplay(events: events, valid: false) }
                previous = env.checksum; events.append(event)
            }
            if buffer.count > 1_048_576 { return JournalReplay(events: events, valid: false) }
        }
        return JournalReplay(events: events, valid: buffer.isEmpty)
    }
}

extension JournalStore {
    /// Successful journals retain Undo/path-map dependencies indefinitely. Only old,
    /// terminal transactions that never durably prepared a mutation may expire.
    public func pruneUnneeded(limit: Int) throws {
        let all = try summaries()
        for summary in all.dropFirst(max(1, limit)) where summary.succeeded == 0 && ["Completed", "CompletedWithErrors", "Cancelled"].contains(summary.status) {
            let replay = try replay(summary.id)
            guard replay.valid, !replay.events.contains(where: { ["Prepared", "TemporaryRenamed", "FinalIntent", "FinalRenamed", "Verified"].contains($0.state) }) else { continue }
            try FileManager.default.removeItem(at: summaryURL(summary.id))
            try FileManager.default.removeItem(at: journalURL(summary.id))
        }
    }
}
