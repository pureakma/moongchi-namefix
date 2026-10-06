import Foundation
import CoreServices
import NameFixCore

public struct WatchedFolder: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var bookmark: Data
    public var path: String
    public var pipeline: RulePipeline
    public var enabled = true
    public init(bookmark: Data, path: String, pipeline: RulePipeline) { self.bookmark = bookmark; self.path = path; self.pipeline = pipeline }
}
public struct WatchLibrary: Codable, Sendable {
    public var schemaVersion = 1
    public var folders: [WatchedFolder] = []
    public var baselines: [UUID: [Data: WatchedFile]]?
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw RuleFailure.schema }
        guard folders.count <= 100, Set(folders.map(\.id)).count == folders.count else { throw RuleFailure.invalid }
        guard (baselines ?? [:]).values.reduce(0, { $0 + $1.count }) <= 200000,
              (baselines ?? [:]).values.allSatisfy({ $0.keys.allSatisfy { $0.count == 32 } }) else { throw RuleFailure.budget }
        for folder in folders { guard folder.path.hasPrefix("/"), folder.bookmark.count <= 1_000_000 else { throw RuleFailure.invalid }; try folder.pipeline.validate(access: .pro) }
    }
}
public actor WatchStore {
    private let url: URL
    private var readOnly = false
    public init(url: URL) { self.url = url }
    public func load() throws -> WatchLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return WatchLibrary() }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 96_000_000 else { throw RuleFailure.budget }
            let result = try JSONDecoder().decode(WatchLibrary.self, from: Data(contentsOf: url)); try result.validate(); return result
        } catch { readOnly = true; throw error }
    }
    public func save(_ value: WatchLibrary) throws {
        guard !readOnly else { throw FSError("WatchReadOnly") }; try value.validate()
        // Refuse what load() would reject, so the saved file can always be read back.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard try encoder.encode(value).count <= 96_000_000 else { throw RuleFailure.budget }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Durable.atomic(value, to: url)
    }
}

// The CF stream retains a callback box, never the watcher. Start/stop are serialized.
public final class FolderWatcher: @unchecked Sendable {
    private final class Callback: @unchecked Sendable {
        let action: @Sendable (Bool) -> Void
        init(_ action: @escaping @Sendable (Bool) -> Void) { self.action = action }
    }
    private let lock = NSLock()
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "com.moongchi.namefix.watch", qos: .utility)
    public init() {}
    public func start(path: String, onChange: @escaping @Sendable (Bool) -> Void) throws {
        lock.lock(); defer { lock.unlock() }; stopLocked()
        let box = Unmanaged.passRetained(Callback(onChange))
        var context = FSEventStreamContext(version: 0, info: box.toOpaque(), retain: nil, release: { pointer in
            if let pointer { Unmanaged<Callback>.fromOpaque(pointer).release() }
        }, copyDescription: nil)
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagIgnoreSelf)
        guard let created = FSEventStreamCreate(nil, { _, pointer, count, _, flags, _ in
            guard let pointer else { return }
            let box = Unmanaged<Callback>.fromOpaque(pointer).takeUnretainedValue()
            var rescan = false
            for i in 0..<count {
                if flags[i] & UInt32(kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagUserDropped | kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagRootChanged) != 0 { rescan = true }
            }
            box.action(rescan)
        }, &context, [path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.5, flags) else { box.release(); throw FSError("WatchUnavailable") }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else { FSEventStreamInvalidate(created); FSEventStreamRelease(created); throw FSError("WatchUnavailable") }
        stream = created
    }
    public func stop() { lock.lock(); defer { lock.unlock() }; stopLocked() }
    private func stopLocked() { if let stream { FSEventStreamStop(stream); FSEventStreamInvalidate(stream); FSEventStreamRelease(stream); self.stream = nil } }
    deinit { stopLocked() }
}
