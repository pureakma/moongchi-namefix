import Foundation

public enum EntryStatus: String, Codable, Sendable, CaseIterable {
    case normal = "Normal", needsNormalization = "NeedsNormalization", mixed = "Mixed", conflict = "Conflict", invalidUnicode = "InvalidUnicode", accessDenied = "AccessDenied", unavailable = "Unavailable", unsupported = "Unsupported"
    public var fixable: Bool { self == .needsNormalization || self == .mixed }
    public var isError: Bool { [.invalidUnicode, .accessDenied, .unavailable, .unsupported].contains(self) }
}
public struct FileIdentity: Codable, Hashable, Sendable {
    public var device: Int32
    public var inode: UInt64
    public var birthSeconds: Int64
    public var birthNanoseconds: Int64
    public init(device: Int32, inode: UInt64, birthSeconds: Int64, birthNanoseconds: Int64) { self.device = device; self.inode = inode; self.birthSeconds = birthSeconds; self.birthNanoseconds = birthNanoseconds }
}
public struct RawPath: Codable, Hashable, Sendable {
    public var bytes: Data
    public init(_ string: String) { bytes = Data(string.utf8) }
    public init(bytes: Data) { self.bytes = bytes }
    // Data's own hashing has sampled only a leading window of bytes on some macOS
    // releases. Sibling paths share that window, so path-keyed sets must hash it all.
    public static func == (a: RawPath, b: RawPath) -> Bool { a.bytes == b.bytes }
    public func hash(into hasher: inout Hasher) { bytes.withUnsafeBytes { hasher.combine(bytes: $0) } }
    public var display: String { String(data: bytes, encoding: .utf8) ?? "⟨invalid UTF-8⟩" }
    public var leaf: Data { Data(bytes.split(separator: 47).last ?? Data.SubSequence()) }
    public var parent: RawPath { let cut = bytes.lastIndex(of: 47) ?? bytes.startIndex; return RawPath(bytes: cut == bytes.startIndex ? Data([47]) : Data(bytes[..<cut])) }
    public var depth: Int { bytes.filter { $0 == 47 }.count }
    public func appending(_ leaf: Data) -> RawPath { RawPath(bytes: bytes + (bytes == Data([47]) ? Data() : Data([47])) + leaf) }
    public func replacingPrefix(_ from: RawPath, with to: RawPath) -> RawPath {
        if bytes == from.bytes { return to }
        let prefix = from.bytes + Data([47])
        guard bytes.starts(with: prefix) else { return self }
        return RawPath(bytes: to.bytes + bytes.dropFirst(from.bytes.count))
    }
}
public struct FileVersion: Codable, Equatable, Sendable {
    public var size: Int64
    public var modifiedSeconds: Int64
    public var modifiedNanoseconds: Int64
    public init(size: Int64, modifiedSeconds: Int64, modifiedNanoseconds: Int64) { self.size = size; self.modifiedSeconds = modifiedSeconds; self.modifiedNanoseconds = modifiedNanoseconds }
}
public struct FileEntry: Identifiable, Codable, Sendable {
    public var id: UUID
    public var path: RawPath
    public var identity: FileIdentity?
    public var parentIdentity: FileIdentity?
    public var isDirectory: Bool
    public var status: EntryStatus
    public var reason: String
    public var proposed: Data
    public var contentVersion: FileVersion?
    public var groupID: Data?
    public var name: String { String(data: path.leaf, encoding: .utf8) ?? "⟨invalid UTF-8⟩" }
    public var preview: String { String(data: proposed, encoding: .utf8) ?? "⟨invalid UTF-8⟩" }
    public init(id: UUID = UUID(), path: RawPath, identity: FileIdentity? = nil, parentIdentity: FileIdentity? = nil, isDirectory: Bool = false, status: EntryStatus, reason: String, proposed: Data) {
        self.id = id; self.path = path; self.identity = identity; self.parentIdentity = parentIdentity; self.isDirectory = isDirectory; self.status = status; self.reason = reason; self.proposed = proposed
    }
}
public struct NormalizationAnalysis: Sendable {
    public let text: String?
    public let nfc: Data
    public let proposed: Data
    public let status: EntryStatus
    public init(raw: Data, target: NormalizationTarget = .nfc) {
        guard let text = String(data: raw, encoding: .utf8) else { self.text = nil; nfc = raw; proposed = raw; status = .invalidUnicode; return }
        self.text = text
        nfc = Data(text.precomposedStringWithCanonicalMapping.utf8)
        proposed = Data(target.apply(text).utf8)
        if raw == proposed { status = .normal }
        else {
            // Mixed: at least one already-composed grapheme and one non-NFC grapheme.
            var composed = false, decomposed = false
            for character in text {
                let s = String(character), n = s.precomposedStringWithCanonicalMapping
                if Data(s.utf8) != Data(n.utf8) { decomposed = true }
                else if Data(s.utf8) != Data(s.decomposedStringWithCanonicalMapping.utf8) { composed = true }
            }
            status = target == .nfc && composed && decomposed ? .mixed : .needsNormalization
        }
    }
    public var forms: [(String, String)] {
        guard let text else { return [] }
        return [("NFC", text.precomposedStringWithCanonicalMapping), ("NFD", text.decomposedStringWithCanonicalMapping), ("NFKC", text.precomposedStringWithCompatibilityMapping), ("NFKD", text.decomposedStringWithCompatibilityMapping)]
    }
    public var scalars: String { text?.unicodeScalars.map { String(format: "U+%04X", $0.value) }.joined(separator: " ") ?? "" }
    public var utf16: String { text?.utf16.map { String(format: "%04X", $0) }.joined(separator: " ") ?? "" }
    public static func clipboard(_ text: String) -> (String, Bool) {
        var result = "", count = 0
        for c in text { let size = String(c).utf16.count; if count + size > 4096 { return (result, true) }; result.append(c); count += size }
        return (result, false)
    }
}
public enum NameRules {
    /// Finder's own bookkeeping files. Batch rules never rename them.
    public static func finderMetadata(_ raw: Data) -> Bool { raw == Data(".DS_Store".utf8) || raw == Data(".localized".utf8) }
    public static func valid(_ raw: Data, limit: Int = 255) -> Bool {
        !raw.isEmpty && raw.count <= limit && !raw.contains(0) && !raw.contains(47) && raw != Data(".".utf8) && raw != Data("..".utf8) && String(data: raw, encoding: .utf8) != nil
    }
    public static func numbered(_ name: String, directory: Bool, number: Int) -> Data {
        let dot = directory ? nil : name.lastIndex(of: ".")
        if let dot, dot != name.startIndex { return Data("\(name[..<dot]) (\(number))\(name[dot...])".utf8) }
        return Data("\(name) (\(number))".utf8)
    }
}
public enum PlanError: Error { case missingIdentity }
public struct RenameOperation: Codable, Sendable, Identifiable {
    public var id: UUID = UUID()
    public var entryID: UUID
    public var source: RawPath
    public var destination: Data
    public var temporary: Data = Data(".namefix-\(UUID().uuidString)".utf8)
    public var identity: FileIdentity
    public var parentIdentity: FileIdentity
    public var undoOf: UUID?
    public var groupID: Data?
    public var contentVersion: FileVersion?
    /// UUID of the volume the item was on when the operation was planned. A device number is
    /// only valid while a volume stays mounted; this names the volume itself. Absent in older records.
    public var volume: String?
    public init(entry: FileEntry, destination: Data? = nil, undoOf: UUID? = nil) throws {
        guard let identity = entry.identity, let parent = entry.parentIdentity else { throw PlanError.missingIdentity }
        groupID = entry.groupID; contentVersion = entry.contentVersion; entryID = entry.id; source = entry.path; self.destination = destination ?? entry.proposed; self.identity = identity; parentIdentity = parent; self.undoOf = undoOf
    }
    public var finalPath: RawPath { source.parent.appending(destination) }
}
public struct RenamePlan: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var generation: UUID
    public var createdAt: Date = Date()
    public var operations: [RenameOperation]
    public var excluded: Int
    public var mode: String
    public init(generation: UUID, operations: [RenameOperation], excluded: Int = 0, mode: String = "rename") { self.generation = generation; self.operations = operations; self.excluded = excluded; self.mode = mode }
}
public enum HistoryPathMap {
    public static func apply(_ path: RawPath, moves: [(RawPath, RawPath)]) -> RawPath {
        let ordered = moves.sorted { $0.0.bytes.count > $1.0.bytes.count }
        for (from, to) in ordered { let candidate = path.replacingPrefix(from, with: to); if candidate != path { return candidate } }
        return path
    }
}

public struct WatchedFile: Codable, Equatable, Sendable {
    public var identity: FileIdentity
    public var version: FileVersion
    public init(identity: FileIdentity, version: FileVersion) { self.identity = identity; self.version = version }
}
