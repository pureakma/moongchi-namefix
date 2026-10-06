import Foundation
import Darwin
import NameFixCore

public struct FSError: Error, Sendable, CustomStringConvertible {
    public let code: String
    public let number: Int32
    public init(_ code: String, _ number: Int32 = errno) { self.code = code; self.number = number }
    public var description: String { "\(code) (\(number))" }
}
public enum FS {
    public static func version(_ value: stat) -> FileVersion { FileVersion(size: value.st_size, modifiedSeconds: Int64(value.st_mtimespec.tv_sec), modifiedNanoseconds: Int64(value.st_mtimespec.tv_nsec)) }
    public static func verifyVersion(_ fd: Int32, raw: Data, expected: FileVersion?) throws {
        if let expected, version(try metadata(fd, raw)) != expected { throw FSError("SourceChanged") }
    }

    public static func cPath<T>(_ data: Data, _ body: (UnsafePointer<CChar>) throws -> T) rethrows -> T {
        try (Array(data) + [0]).withUnsafeBytes { try body($0.baseAddress!.assumingMemoryBound(to: CChar.self)) }
    }
    public static func identity(_ s: stat) -> FileIdentity { FileIdentity(device: s.st_dev, inode: s.st_ino, birthSeconds: Int64(s.st_birthtimespec.tv_sec), birthNanoseconds: Int64(s.st_birthtimespec.tv_nsec)) }
    // Walk every component with O_NOFOLLOW, including ancestors. Never resolve through a link.
    public static func openDirectory(_ path: RawPath) throws -> Int32 {
        guard path.bytes.first == 47, !path.bytes.contains(0) else { throw FSError("InvalidPath", EINVAL) }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw FSError("AccessDenied") }
        do {
            for part in path.bytes.split(separator: 47) {
                let leaf = Data(part)
                guard leaf != Data("..".utf8), leaf != Data(".".utf8) else { throw FSError("LinkedPathHelp", EINVAL) }
                let next = cPath(leaf) { openat(fd, $0, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC) }
                guard next >= 0 else {
                    throw FSError(errno == ELOOP ? "LinkedPathHelp" : "AccessDenied") }
                close(fd); fd = next
            }
            return fd
        } catch { close(fd); throw error }
    }
    public static func rawDirectoryPath(_ fd: Int32) throws -> RawPath {
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
        let result = buffer.withUnsafeMutableBytes { fcntl(fd, F_GETPATH, $0.baseAddress!) }
        guard result == 0, let end = buffer.firstIndex(of: 0), end > 0 else { throw FSError("UnavailableHelp") }
        return RawPath(bytes: Data(buffer[..<end]))
    }
    public static func metadata(_ fd: Int32, _ name: Data) throws -> stat {
        var s = stat()
        guard cPath(name, { fstatat(fd, $0, &s, AT_SYMLINK_NOFOLLOW) }) == 0 else { throw FSError(errno == EACCES ? "AccessHelp" : "UnavailableHelp") }
        return s
    }
    public static func directoryIdentity(_ fd: Int32) throws -> FileIdentity { var s = stat(); guard fstat(fd, &s) == 0 else { throw FSError("UnavailableHelp") }; return identity(s) }
    public static func names(_ fd: Int32) throws -> [Data] {
        let copy = openat(fd, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard copy >= 0, let dir = fdopendir(copy) else { if copy >= 0 { close(copy) }; throw FSError("AccessHelp") }
        defer { closedir(dir) }
        var result: [Data] = []
        while true {
            errno = 0
            guard let entry = readdir(dir) else { if errno != 0 { throw FSError("AccessHelp") }; break }
            let count = Int(entry.pointee.d_namlen)
            let data = withUnsafeBytes(of: entry.pointee.d_name) { Data($0.prefix(count)) }
            if data != Data(".".utf8) && data != Data("..".utf8) { result.append(data) }
        }
        return result
    }
    /// Finder alias bit in the big-endian FinderInfo flags, queried relative to a
    /// no-follow parent FD. This avoids Foundation URL resource-cache growth per file.
    public static func isFinderAlias(_ fd: Int32, name: Data) throws -> Bool {
        var attrs = attrlist()
        attrs.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        attrs.commonattr = attrgroup_t(ATTR_CMN_FNDRINFO)
        var buffer = [UInt8](repeating: 0, count: 36)
        let result = buffer.withUnsafeMutableBytes { bytes in
            cPath(name) { getattrlistat(fd, $0, &attrs, bytes.baseAddress, bytes.count, UInt(FSOPT_NOFOLLOW)) }
        }
        guard result == 0 else { throw FSError("AccessHelp") }
        return buffer[12] & 0x80 != 0
    }
    public static func capability(_ fd: Int32) throws -> String {
        var info = statfs()
        guard fstatfs(fd, &info) == 0 else { throw FSError("VolumeSafetyUnsupported") }
        let type = withUnsafeBytes(of: info.f_fstypename) { String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self)) }
        guard type == "apfs", info.f_flags & UInt32(MNT_LOCAL) != 0, info.f_flags & UInt32(MNT_RDONLY) == 0 else { throw FSError(type == "hfs" ? "VolumeNormalizationUnsupported" : "VolumeSafetyUnsupported", ENOTSUP) }
        return type
    }
    public static func noReplace(_ fd: Int32, from: Data, to: Data) throws {
        guard NameRules.valid(from), NameRules.valid(to, limit: Int(fpathconf(fd, _PC_NAME_MAX))) else { throw FSError("InvalidUnicodeHelp", EINVAL) }
        let result = cPath(from) { source in cPath(to) { renameatx_np(fd, source, fd, $0, UInt32(RENAME_EXCL)) } }
        guard result == 0 else { throw FSError(errno == EEXIST ? "ConflictHelp" : "OperationError") }
    }
    public static func storedName(_ fd: Int32, lookup: Data) throws -> Data {
        var attributes = attrlist(); attributes.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT); attributes.commonattr = attrgroup_t(ATTR_CMN_NAME)
        var buffer = [UInt8](repeating: 0, count: 2048)
        let result = buffer.withUnsafeMutableBytes { bytes in cPath(lookup) { getattrlistat(fd, $0, &attributes, bytes.baseAddress, bytes.count, UInt(FSOPT_NOFOLLOW)) } }
        guard result == 0 else { throw FSError("SourceChanged") }
        return try buffer.withUnsafeBytes { bytes in
            let total = Int(bytes.loadUnaligned(as: UInt32.self)), ref = bytes.loadUnaligned(fromByteOffset: 4, as: attrreference_t.self)
            let start = 4 + Int(ref.attr_dataoffset), length = Int(ref.attr_length)
            guard start >= 12, length > 1, start + length <= total, total <= bytes.count, bytes[start + length - 1] == 0 else { throw FSError("SourceChanged") }
            return Data(bytes[start..<(start + length - 1)])
        }
    }
    public static func absent(_ fd: Int32, raw: Data) throws -> Bool {
        var value = stat()
        let rc = cPath(raw) { fstatat(fd, $0, &value, AT_SYMLINK_NOFOLLOW) }
        if rc == 0 { return false }
        guard errno == ENOENT else { throw FSError("AccessHelp") }; return true
    }
    public static func verify(_ fd: Int32, raw: Data, identity: FileIdentity) throws {
        guard try storedName(fd, lookup: raw) == raw, try self.identity(metadata(fd, raw)) == identity else { throw FSError("SourceChanged", ESTALE) }
    }
    // Lookup aliases are accepted only when directory indexing proves one spelling for the inode.
    // Multiple hardlink spellings sharing the inode are conservatively treated as a conflict.
    public static func destinationAvailable(_ fd: Int32, source: Data, dest: Data, expected: FileIdentity, names: Set<Data>) throws -> Bool {
        guard source != dest else { return false }
        if names.contains(dest) { return false }
        var s = stat()
        let rc = cPath(dest) { fstatat(fd, $0, &s, AT_SYMLINK_NOFOLLOW) }
        if rc != 0 { if errno == ENOENT { return true }; throw FSError("AccessHelp") }
        guard identity(s) == expected, names.contains(source) else { return false }
        // NFC-equivalent raw leaves identify the same APFS directory entry. Inode
        // equality alone is insufficient when another hardlink owns the destination.
        guard let sourceText = String(data: source, encoding: .utf8), let destText = String(data: dest, encoding: .utf8) else { return false }
        let key = Data(destText.precomposedStringWithCanonicalMapping.lowercased().utf8)
        guard Data(sourceText.precomposedStringWithCanonicalMapping.lowercased().utf8) == key else { return false }
        return try storedName(fd, lookup: dest) == source
    }
}

/// Bounded, read-only handles for one preview/planning pass. Never shared with mutation.
public final class DirectoryReadSession {
    private var handles: [RawPath: Int32] = [:]
    private var order: [RawPath] = []
    public init() {}
    public func open(_ path: RawPath) throws -> Int32 {
        if let fd = handles[path] { return fd }
        let fd = try FS.openDirectory(path)
        if order.count == 32 { let oldest = order.removeFirst(); if let old = handles.removeValue(forKey: oldest) { close(old) } }
        handles[path] = fd; order.append(path); return fd
    }
    deinit { for fd in handles.values { close(fd) } }
}
