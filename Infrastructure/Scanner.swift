import Foundation
import Darwin
import UniformTypeIdentifiers
import NameFixCore

public final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    private var cancellationHandlers: [UUID: @Sendable () -> Void] = [:]
    public init() {}
    public func cancel() {
        lock.lock(); value = true; let handlers = Array(cancellationHandlers.values); cancellationHandlers.removeAll(); lock.unlock()
        for handler in handlers { handler() }
    }
    public func onCancel(_ handler: @escaping @Sendable () -> Void) -> UUID {
        let id = UUID()
        lock.lock(); let alreadyCancelled = value
        if !alreadyCancelled { cancellationHandlers[id] = handler }; lock.unlock()
        if alreadyCancelled { handler() }; return id
    }
    public func removeCancellationHandler(_ id: UUID) { lock.lock(); cancellationHandlers.removeValue(forKey: id); lock.unlock() }
    public var cancelled: Bool { lock.lock(); defer { lock.unlock() }; return value }
}
public struct ScanResult: Sendable {
    public var entries: [FileEntry]
    public var roots: [RawPath]
    public var limited: Bool
    public var cancelled: Bool
}
public enum Scanner {
    public static func protectedReason(_ path: RawPath) -> String? {
        let s = path.display
        if ["/", "/System", "/bin", "/sbin", "/usr", "/dev", "/Library"].contains(s) || ["/System/", "/Library/", "/bin/", "/sbin/", "/usr/", "/dev/"].contains(where: s.hasPrefix) { return "VolumeSafetyUnsupported" }
        if s.contains("/Library/CloudStorage/") || s.contains("/Library/Mobile Documents/") { return "CloudLocationExcluded" }
        // A sandboxed app cannot read anything above the folder the user allowed.
        // Up to that folder the items themselves are asked; above it only the name can tell.
        let boundary = AccessRoots.shared.restricted ? AccessRoots.shared.root(containing: path)?.path.display : nil
        var url = URL(fileURLWithPath: s), outside = false
        while url.path != "/" {
            if url.lastPathComponent == ".git" { return "PackageExcluded" }
            if outside {
                if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .package) { return "PackageExcluded" }
            } else {
                do {
                    let values = try url.resourceValues(forKeys: [.isPackageKey, .isAliasFileKey, .isUbiquitousItemKey])
                    if values.isPackage == true { return "PackageExcluded" }
                    if values.isAliasFile == true { return "LinkedPathHelp" }
                    if values.isUbiquitousItem == true { return "CloudLocationExcluded" }
                } catch { return "AccessHelp" }
            }
            if url.path == boundary { outside = true }
            url.deleteLastPathComponent()
        }
        return nil
    }
    public static func scan(roots: [RawPath], recursive: Bool, token: CancellationToken, limit: Int = 200_000, target: NormalizationTarget = .nfc, progress: @Sendable (Int) -> Void = { _ in }) -> ScanResult {
        var result: [FileEntry] = [], seen = Set<RawPath>()
        var resolvedRoots: [RawPath: RawPath] = [:]
        var work: [(RawPath, Int, Int32?)] = roots.map { ($0, 0, nil) }
        var lastUpdate = Date.distantPast
        var protection: [RawPath: String] = [:]
        var directoryFDs: [RawPath: (fd: Int32, path: RawPath)] = [:]
        defer { for value in directoryFDs.values { close(value.fd) } }
        func parentFD(_ path: RawPath) throws -> (fd: Int32, path: RawPath) {
            if let value = directoryFDs[path] { return value }
            if directoryFDs.count >= 64 { for value in directoryFDs.values { close(value.fd) }; directoryFDs.removeAll(keepingCapacity: true) }
            let fd = try FS.openDirectory(path)
            do {
                let value = (fd: fd, path: try FS.rawDirectoryPath(fd))
                directoryFDs[path] = value; return value
            } catch { close(fd); throw error }
        }
        func protectionReason(_ path: RawPath, directory: Bool, fd: Int32, metadata: stat) throws -> String? {
            let parentReason: String
            if let cached = protection[path.parent] { parentReason = cached }
            else { parentReason = protectedReason(path.parent) ?? ""; protection[path.parent] = parentReason }
            if !parentReason.isEmpty { return parentReason }
            if path.leaf == Data(".git".utf8) { return "PackageExcluded" }
            if metadata.st_flags & UInt32(SF_DATALESS) != 0 { return "CloudLocationExcluded" }
            if !directory { return try FS.isFinderAlias(fd, name: path.leaf) ? "LinkedPathHelp" : nil }
            let values = try URL(fileURLWithPath: path.display).resourceValues(forKeys: [.isPackageKey, .isAliasFileKey, .isUbiquitousItemKey])
            if values.isPackage == true { return "PackageExcluded" }
            if values.isAliasFile == true { return "LinkedPathHelp" }
            if values.isUbiquitousItem == true { return "CloudLocationExcluded" }
            return nil
        }
        var indices: [RawPath: ([Data], Set<Data>)] = [:]
        // One answer per folder: everything in a folder is on the folder's volume.
        var volumes: [RawPath: VolumeSupport] = [:]
        // Test the limit before popping so the item that would exceed it stays counted as pending.
        while !token.cancelled, result.count < limit, let (requested, level, device) = work.popLast() {
            if seen.contains(requested) { continue }
            do {
                // Sandboxed: the name of the folder the user allowed lives in a folder the app may
                // not open yet. The folder is listed and its contents are scanned. If its own name
                // would change, the row says the folder above has to be chosen first; once it is,
                // this branch is not taken and the folder is a row like any other.
                if level == 0, AccessRoots.shared.restricted, AccessRoots.shared.root(containing: requested.parent) == nil, AccessRoots.shared.root(containing: requested) != nil {
                    let rootFD = try FS.openDirectory(requested); defer { close(rootFD) }
                    let path = try FS.rawDirectoryPath(rootFD), identity = try FS.directoryIdentity(rootFD)
                    resolvedRoots[requested] = path
                    guard seen.insert(path).inserted else { continue }
                    let blocked = protectedReason(path)
                    let proposed = NormalizationAnalysis(raw: path.leaf, target: target).proposed, changes = proposed != path.leaf
                    result.append(FileEntry(path: path, identity: identity, isDirectory: true, status: blocked != nil ? .unsupported : changes ? .accessDenied : .normal,
                                            reason: blocked ?? (changes ? "ParentFolderNeeded" : "NormalHelp"), proposed: proposed))
                    if blocked == nil { work.append(contentsOf: try FS.names(rootFD).map { (path.appending($0), 1, identity.device) }) }
                    continue
                }
                let opened = try parentFD(requested.parent), fd = opened.fd
                let index: ([Data], Set<Data>)
                if let cached = indices[requested.parent] { index = cached } else { let names = try FS.names(fd); index = (names, Set(names)); indices[requested.parent] = index }
                let names = index.0
                let requestedStat = try FS.metadata(fd, requested.leaf)
                // Accept a differently normalized input URL only if the raw entry is unique.
                let raw: Data
                if index.1.contains(requested.leaf) { raw = requested.leaf }
                else {
                    let requestedKey = String(data: requested.leaf, encoding: .utf8)?.precomposedStringWithCanonicalMapping.lowercased()
                    let candidates = try names.filter { name in
                        guard let value = String(data: name, encoding: .utf8), let requestedKey else { return false }
                        guard value.precomposedStringWithCanonicalMapping.lowercased() == requestedKey else { return false }
                        return try FS.identity(FS.metadata(fd, name)) == FS.identity(requestedStat)
                    }
                    guard candidates.count == 1 else { throw FSError("SourceChanged", ESTALE) }
                    raw = candidates[0]
                }
                let path = opened.path.appending(raw)
                if level == 0 { resolvedRoots[requested] = path }
                guard seen.insert(path).inserted else { continue }
                let s = try FS.metadata(fd, raw), identity = FS.identity(s), parent = try FS.directoryIdentity(fd)
                let dir = s.st_mode & S_IFMT == S_IFDIR, link = s.st_mode & S_IFMT == S_IFLNK
                let analysis = NormalizationAnalysis(raw: raw, target: target)
                var entry = FileEntry(path: path, identity: identity, parentIdentity: parent, isDirectory: dir, status: analysis.status, reason: analysis.status == .normal ? "NormalHelp" : target == .nfd ? "NFDChangeHelp" : "ChangeHelp", proposed: analysis.proposed)
                // Directories change mtime as our own children are renamed. Only
                // regular files carry the scan-time content freshness snapshot.
                if s.st_mode & S_IFMT == S_IFREG { entry.contentVersion = FS.version(s) }
                var mayTraverse = false
                if analysis.text == nil { entry.reason = "InvalidUnicodeHelp" }
                else if link { entry.status = .unsupported; entry.reason = "LinkedPathHelp" }
                else if let reason = try protectionReason(path, directory: dir, fd: fd, metadata: s) { entry.status = .unsupported; entry.reason = reason }
                else if let device, device != s.st_dev { entry.status = .unsupported; entry.reason = "MountBoundaryExcluded" }
                else if s.st_mode & S_IFMT != S_IFREG && !dir { entry.status = .unsupported; entry.reason = "Unsupported" }
                else {
                    mayTraverse = true
                    // A disk the user added is scanned; its own name is the mount point and is left alone.
                    if dir && s.st_dev != parent.device { entry.status = .unsupported; entry.reason = level == 0 ? "VolumeRootExcluded" : "MountBoundaryExcluded" }
                    else {
                        do {
                            let volume: VolumeSupport
                            if let known = volumes[requested.parent] { volume = known } else { volume = try FS.support(fd); volumes[requested.parent] = volume }
                            if volume.level != .supported { entry.status = .unsupported; entry.reason = volume.reason ?? "VolumeFormatUnsupported" }
                        } catch let error as FSError { entry.status = .unsupported; entry.reason = error.code }
                    }
                    if entry.status.fixable {
                        if !NameRules.valid(entry.proposed, limit: Int(fpathconf(fd, _PC_NAME_MAX))) { entry.status = .unsupported; entry.reason = "InvalidUnicodeHelp" }
                        else if try !FS.destinationAvailable(fd, source: raw, dest: entry.proposed, expected: identity, names: index.1) { entry.status = .conflict; entry.reason = "ConflictHelp" }
                    }
                }
                result.append(entry)
                if dir && !link && mayTraverse && (recursive || level == 0) {
                    do {
                        let childFD = try FS.openDirectory(path); defer { close(childFD) }
                        guard try FS.directoryIdentity(childFD) == identity else { throw FSError("SourceChanged") }
                        work.append(contentsOf: try FS.names(childFD).map { (path.appending($0), level + 1, device ?? s.st_dev) })
                    } catch {
                        let code = (error as? FSError)?.code ?? "OperationError"
                        result[result.count - 1].status = code.contains("Access") ? .accessDenied : .unavailable
                        result[result.count - 1].reason = code
                    }
                }
            } catch {
                let code = (error as? FSError)?.code ?? "OperationError"
                result.append(FileEntry(path: requested, status: code.contains("Access") ? .accessDenied : .unavailable, reason: code, proposed: requested.leaf))
            }
            if Date().timeIntervalSince(lastUpdate) > 0.1 { progress(result.count); lastUpdate = Date() }
        }
        var uniqueRoots = Set<RawPath>()
        let currentRoots = roots.map { resolvedRoots[$0] ?? $0 }.filter { uniqueRoots.insert($0).inserted }
        return ScanResult(entries: result, roots: currentRoots, limited: !work.isEmpty && result.count >= limit, cancelled: token.cancelled)
    }
}
