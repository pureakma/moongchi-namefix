import Foundation
import Darwin
public actor DiagnosticLog {
    let root: URL
    public init(root: URL) { self.root = root }
    public func record(code: String, transaction: UUID? = nil, count: Int = 0) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fm = FileManager.default, current = root.appendingPathComponent("events.jsonl")
        let attributes = try? fm.attributesOfItem(atPath: current.path)
        if let size = attributes?[.size] as? NSNumber, size.intValue >= 10 * 1024 * 1024 {
            let oldest = root.appendingPathComponent("events.2.jsonl")
            if fm.fileExists(atPath: oldest.path) { try fm.removeItem(at: oldest) }
            let previous = root.appendingPathComponent("events.1.jsonl")
            if fm.fileExists(atPath: previous.path) { try fm.moveItem(at: previous, to: oldest) }
            try fm.moveItem(at: current, to: previous)
        }
        // Only application-owned diagnostic rotations expire. Recovery journals never enter this directory.
        for name in ["events.1.jsonl", "events.2.jsonl"] {
            let url = root.appendingPathComponent(name)
            if let date = (try? fm.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date, date < Date().addingTimeInterval(-30 * 86400) { try fm.removeItem(at: url) }
        }
        let value: [String: String] = ["timestamp": ISO8601DateFormatter().string(from: Date()), "code": code, "transaction": transaction?.uuidString ?? "", "count": String(count), "architecture": "arm64"]
        var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]); data.append(10)
        let fd = open(current.path, O_CREAT | O_APPEND | O_WRONLY | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw FSError("DiagnosticsError") }; defer { close(fd) }
        try Durable.writeAll(fd, data)
    }
}
