import Foundation
import Darwin
import NameFixCore

/// A folder the user allowed the app to work in.
public struct AuthorizedRoot: Sendable, Equatable {
    /// The path the system reports for the folder, byte for byte.
    public let path: RawPath
    public let identity: FileIdentity
    public let volume: String?
}

/// The folders this process may work in, and where a walk to any folder starts.
///
/// A directly distributed app may open any folder, so a walk starts at "/" and checks every
/// ancestor without following a link. A sandboxed app may open only what the user allowed.
/// There the walk starts at the allowed folder — the user chose it, and macOS vouches for it —
/// and goes down from it the same way: one component at a time, never through a link.
/// Scanning, planning, the transaction, Undo and Recovery all open folders with
/// FS.openDirectory, so they share this one rule instead of each judging access.
public final class AccessRoots: @unchecked Sendable {
    public static let shared = AccessRoots()
    private struct Grant { let root: AuthorizedRoot; let fd: Int32; let url: URL; let lease: AccessLease; var holders: Int }
    private let lock = NSLock()
    private var grants: [RawPath: Grant] = [:]
    private var limited = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    /// True when only allowed folders can be opened (the App Sandbox).
    public var restricted: Bool { lock.lock(); defer { lock.unlock() }; return limited }
    /// Tests turn the rule on to run the sandbox walk outside a sandbox. The real sandbox is not replaced by this.
    public func restrict(_ on: Bool) { lock.lock(); limited = on; lock.unlock() }

    /// Starts working in a folder the user chose, dropped, opened or saved a bookmark for.
    /// Every grant is counted; `release` gives one back.
    @discardableResult public func grant(_ url: URL) throws -> AuthorizedRoot {
        let taken = try take(url)
        if let replaced = taken.replaced { close(replaced.fd) }
        return taken.root
    }
    /// Takes the folder only if it is the one that is wanted. `wanted` is asked with the folder in
    /// place, so it can try to reach something through it. A folder that is not wanted leaves
    /// everything as it was, also the place of a moved folder it would have taken over: nil.
    public func grant(_ url: URL, if wanted: (AuthorizedRoot) -> Bool) throws -> AuthorizedRoot? {
        let taken = try take(url)
        if wanted(taken.root) { if let replaced = taken.replaced { close(replaced.fd) }; return taken.root }
        lock.lock(); defer { lock.unlock() }
        guard var now = grants[taken.root.path] else { if let replaced = taken.replaced { close(replaced.fd) }; return nil }
        now.holders -= 1
        if var back = taken.replaced, now.fd == taken.fd {
            close(now.fd); back.holders = now.holders
            if back.holders > 0 { grants[taken.root.path] = back } else { close(back.fd); grants[taken.root.path] = nil }
        } else {
            if let replaced = taken.replaced { close(replaced.fd) }
            if now.holders > 0 { grants[taken.root.path] = now } else { close(now.fd); grants[taken.root.path] = nil }
        }
        return nil
    }
    /// Puts the folder in place and says what was there under another identity, still open.
    private func take(_ url: URL) throws -> (root: AuthorizedRoot, fd: Int32, replaced: Grant?) {
        let lease = AccessLease(url)
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw FSError(errno == ENOENT ? "UnavailableHelp" : "FolderAccessNeeded") }
        do {
            let root = AuthorizedRoot(path: try FS.rawDirectoryPath(fd), identity: try FS.directoryIdentity(fd), volume: FS.volumeUUID(fd))
            lock.lock(); defer { lock.unlock() }
            if var known = grants[root.path], known.root == root {
                // The same folder again. A descriptor that no longer leads there (its drive was taken out and
                // put back) is exchanged for the one just opened.
                if alive(known) { close(fd) } else { close(known.fd); known = Grant(root: root, fd: fd, url: url, lease: lease, holders: known.holders) }
                known.holders += 1; grants[root.path] = known
                return (root, known.fd, nil)
            }
            // Another folder is at that place now. Whoever held the place still holds it, and will give
            // it back once each: the count goes on, so nobody's release closes it under someone else.
            let earlier = grants[root.path]
            grants[root.path] = Grant(root: root, fd: fd, url: url, lease: lease, holders: (earlier?.holders ?? 0) + 1)
            return (root, fd, earlier)
        } catch { close(fd); throw error }
    }
    public func release(_ path: RawPath) {
        lock.lock(); defer { lock.unlock() }
        guard var grant = grants[path] else { return }
        grant.holders -= 1
        if grant.holders > 0 { grants[path] = grant } else { close(grant.fd); grants[path] = nil }
    }
    /// Still the folder that was allowed, and still where it was.
    private func alive(_ grant: Grant) -> Bool {
        (try? FS.directoryIdentity(grant.fd)) == grant.root.identity && (try? FS.rawDirectoryPath(grant.fd)) == grant.root.path
    }
    /// Gives back every folder. For tests, which share this one registry.
    public func releaseAll() { lock.lock(); grants.values.forEach { close($0.fd) }; grants = [:]; lock.unlock() }
    /// The allowed folder that contains this path, the deepest one when several do. It says that
    /// the place was allowed, also when the folder has been moved or replaced since.
    public func root(containing path: RawPath) -> AuthorizedRoot? {
        lock.lock(); defer { lock.unlock() }
        return match(path)?.root
    }
    /// The allowed folder a walk to this path would really start at now. A folder that was moved or
    /// replaced since it was allowed leads nowhere: what it covered is asked for again, and it is
    /// not remembered as the way back to anything.
    public func root(reaching path: RawPath) -> AuthorizedRoot? {
        lock.lock(); defer { lock.unlock() }
        return matches(path).first(where: alive)?.root
    }
    public func isRoot(_ path: RawPath) -> Bool { lock.lock(); defer { lock.unlock() }; return grants[path] != nil }
    /// True for an allowed folder whose own name cannot be changed yet: the name is kept by the
    /// folder above it, and that folder has not been allowed. Never true outside the sandbox.
    public func needsParent(_ path: RawPath) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return limited && grants[path] != nil && !matches(path.parent).contains(where: alive)
    }
    /// A bookmark that lets the app reach this allowed folder again after it is reopened.
    public func bookmark(for path: RawPath) -> Data? {
        lock.lock(); let url = grants[path]?.url; lock.unlock()
        return try? url?.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    /// Every allowed folder that contains this path, the deepest first.
    private func matches(_ path: RawPath) -> [Grant] {
        grants.filter { root, _ in path == root || path.bytes.starts(with: root.bytes + Data([47])) || root.bytes == Data([47]) }
            .map(\.value).sorted { $0.root.path.bytes.count > $1.root.path.bytes.count }
    }
    private func match(_ path: RawPath) -> Grant? { matches(path).first }
    /// Where a walk to `path` may start.
    enum Anchor {
        /// A descriptor for an allowed folder above the path, and the components still to walk.
        case open(fd: Int32, rest: [Data])
        /// A folder above the path was allowed, but it has been moved or replaced since.
        case moved
        /// No allowed folder contains the path.
        case none
    }
    /// The folder must still be the one that was allowed and still be where it was: a moved or
    /// replaced folder is not used. It is passed over, so a folder allowed above it can still lead there.
    func anchor(_ path: RawPath) -> Anchor {
        lock.lock(); defer { lock.unlock() }
        let candidates = matches(path)
        guard !candidates.isEmpty else { return .none }
        for grant in candidates where alive(grant) {
            let copy = openat(grant.fd, ".", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
            guard copy >= 0 else { continue }
            let remainder = path == grant.root.path ? Data() : Data(path.bytes.dropFirst(grant.root.path.bytes == Data([47]) ? 0 : grant.root.path.bytes.count))
            return .open(fd: copy, rest: remainder.split(separator: 47).map { Data($0) })
        }
        return .moved
    }
}

/// A folder access kept across launches because a finished operation may still be undone there.
/// Nothing else is kept: a folder that was only looked at is forgotten when the app quits.
public struct StoredGrant: Codable, Sendable, Identifiable, Equatable {
    public var id = UUID()
    public var path: String
    public var bookmark: Data
    public var volume: String?
    public var identity: FileIdentity
    /// The history records that need this folder. The grant is dropped with the last of them.
    public var transactions: [UUID]
    public init(root: AuthorizedRoot, bookmark: Data, transaction: UUID) {
        path = root.path.display; self.bookmark = bookmark; volume = root.volume; identity = root.identity; transactions = [transaction]
    }
}
public struct GrantLibrary: Codable, Sendable {
    public var schemaVersion = 1
    public var grants: [StoredGrant] = []
    public init() {}
    public func validate() throws {
        guard schemaVersion == 1 else { throw RuleFailure.schema }
        guard grants.count <= 2000, grants.allSatisfy({ $0.path.hasPrefix("/") && $0.bookmark.count <= 1_000_000 }) else { throw RuleFailure.invalid }
    }
    /// Why a stored folder can or cannot be used now.
    public enum Resolution: Sendable, Equatable { case granted(AuthorizedRoot), unavailable, differentFolder }
    /// Reaches a stored folder again. The bookmark alone is not trusted: the folder it leads to
    /// must be on the recorded volume and be the recorded folder, wherever it is mounted now.
    public static func resolve(_ grant: StoredGrant) -> (Resolution, renewed: Data?) {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: grant.bookmark, options: [.withSecurityScope, .withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) else { return (.unavailable, nil) }
        let taken: AuthorizedRoot?
        do {
            taken = try AccessRoots.shared.grant(url) { root in
                let sameVolume = grant.volume == nil ? root.identity.device == grant.identity.device : root.volume == grant.volume
                return sameVolume && root.identity.inode == grant.identity.inode && root.identity.birthSeconds == grant.identity.birthSeconds && root.identity.birthNanoseconds == grant.identity.birthNanoseconds
            }
        } catch { return (.unavailable, nil) }
        guard let root = taken else { return (.differentFolder, nil) }
        return (.granted(root), stale ? AccessRoots.shared.bookmark(for: root.path) : nil)
    }
}
public actor GrantStore {
    private let url: URL
    private var readOnly = false
    public init(url: URL) { self.url = url }
    public func load() throws -> GrantLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return GrantLibrary() }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 64_000_000 else { throw RuleFailure.budget }
            let library = try JSONDecoder().decode(GrantLibrary.self, from: Data(contentsOf: url)); try library.validate(); return library
        } catch { readOnly = true; throw error }
    }
    public func save(_ library: GrantLibrary) throws {
        guard !readOnly else { throw FSError("HistoryWarning") }; try library.validate()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Durable.atomic(library, to: url)
    }
}
