import XCTest
import Foundation
import Darwin
import NameFixCore
@testable import NameFixRuntime
import NameFixApplication

/// The rule a sandboxed app lives by, switched on outside a sandbox: only folders the user
/// allowed can be opened, and a walk starts at the allowed folder. This checks the app's own
/// rule. That the system enforces its side is checked inside a real sandbox by eng/test-sandbox.py.
final class AccessRootsTests: XCTestCase, @unchecked Sendable {
    private var made: [URL] = []
    override func setUp() { AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(true) }
    override func tearDown() {
        AccessRoots.shared.releaseAll(); AccessRoots.shared.restrict(false)
        for url in made { try? FileManager.default.removeItem(at: url) }; made = []
    }
    private func folder(_ name: String = "namefix-access-\(UUID())") throws -> URL {
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NAMEFIX_FIXTURE_ROOT"] ?? "/private/tmp").appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); made.append(url); return url
    }
    private func decomposed(_ text: String) -> Data { Data(text.decomposedStringWithCanonicalMapping.utf8) }
    private func composed(_ text: String) -> Data { Data(text.precomposedStringWithCanonicalMapping.utf8) }
    @discardableResult private func make(_ directory: URL, _ raw: Data, folder: Bool = false) throws -> RawPath {
        let path = directory.path + "/" + String(decoding: raw, as: UTF8.self)
        let ok: Bool = (Array(Data(path.utf8)) + [0]).withUnsafeBytes { bytes in
            let name = bytes.baseAddress!.assumingMemoryBound(to: CChar.self)
            if folder { return mkdir(name, 0o755) == 0 }
            let file = open(name, O_CREAT | O_EXCL | O_WRONLY, 0o600); if file >= 0 { close(file) }; return file >= 0
        }
        guard ok else { throw FSError("FixtureCreate") }
        return RawPath(bytes: Data(directory.path.utf8) + Data([47]) + raw)
    }
    private func names(_ directory: RawPath) throws -> Set<Data> { let fd = try FS.openDirectory(directory); defer { close(fd) }; return Set(try FS.names(fd)) }
    private func scan(_ roots: [RawPath]) -> [FileEntry] { Scanner.scan(roots: roots, recursive: true, token: CancellationToken()).entries }
    private func plan(_ entries: [FileEntry]) throws -> RenamePlan { try Planning.make(entries: entries, selected: Set(entries.filter { $0.status.fixable }.map(\.id)), generation: UUID()) }

    func testOnlyAllowedFoldersCanBeOpenedAndTheWalkStartsThere() throws {
        let allowed = try folder(), other = try folder()
        try FileManager.default.createDirectory(at: allowed.appendingPathComponent("a/b/c"), withIntermediateDirectories: true)
        // Nothing is allowed yet: every folder is refused, with the reason the interface asks about.
        for path in [allowed.path, other.path, "/", "/private/tmp"] {
            XCTAssertThrowsError(try FS.openDirectory(RawPath(path)), path) { XCTAssertEqual(($0 as? FSError)?.code, "FolderAccessNeeded") }
        }
        let root = try AccessRoots.shared.grant(allowed)
        XCTAssertEqual(root.path, RawPath(allowed.path)); XCTAssertNotNil(root.volume)
        let deep = try FS.openDirectory(RawPath(allowed.path + "/a/b/c")); defer { close(deep) }
        XCTAssertEqual(try FS.rawDirectoryPath(deep), RawPath(allowed.path + "/a/b/c"))
        let top = try FS.openDirectory(root.path); defer { close(top) }
        XCTAssertEqual(try FS.directoryIdentity(top), root.identity)
        // Its neighbours, its parent and a look-alike prefix stay closed.
        for path in [other.path, allowed.deletingLastPathComponent().path, allowed.path + "-copy", allowed.path + "/../" + other.lastPathComponent] {
            XCTAssertThrowsError(try FS.openDirectory(RawPath(path)), path)
        }
        XCTAssertEqual(AccessRoots.shared.root(containing: RawPath(allowed.path + "/a/b")), root)
        XCTAssertNil(AccessRoots.shared.root(containing: RawPath(allowed.path + "-copy/a")))
    }

    func testALinkInsideAnAllowedFolderIsNeverFollowedOut() throws {
        let allowed = try folder(), outside = try folder()
        try make(outside, Data("secret.txt".utf8))
        XCTAssertEqual(symlink(outside.path, allowed.path + "/escape"), 0)
        XCTAssertEqual(symlink("../" + outside.lastPathComponent, allowed.path + "/relative"), 0)
        try AccessRoots.shared.grant(allowed)
        for link in ["escape", "relative"] {
            XCTAssertThrowsError(try FS.openDirectory(RawPath(allowed.path + "/" + link))) { XCTAssertEqual(($0 as? FSError)?.code, "LinkedPathHelp") }
        }
        XCTAssertThrowsError(try FS.openDirectory(RawPath(allowed.path + "/..")))
        // The scan lists the links as links and never lists what they point to.
        let entries = scan([RawPath(allowed.path)])
        XCTAssertEqual(entries.filter { $0.reason == "LinkedPathHelp" }.count, 2)
        XCTAssertFalse(entries.contains { $0.path.display.hasSuffix("secret.txt") })
    }

    func testAMovedOrReplacedAllowedFolderIsNotUsed() throws {
        let allowed = try folder()
        let root = try AccessRoots.shared.grant(allowed)
        // Another folder takes its place: same path, different folder.
        let moved = allowed.deletingLastPathComponent().appendingPathComponent("namefix-access-moved-\(UUID())"); made.append(moved)
        try FileManager.default.moveItem(at: allowed, to: moved)
        try FileManager.default.createDirectory(at: allowed, withIntermediateDirectories: true)
        // It was allowed and is gone from there: that is "not available", not a request for access.
        XCTAssertThrowsError(try FS.openDirectory(root.path)) { XCTAssertEqual(($0 as? FSError)?.code, "UnavailableHelp") }
        XCTAssertEqual(scan([root.path]).first?.reason, "UnavailableHelp")
        // Allowing the folder that is there now works again, as a different folder.
        let replaced = try AccessRoots.shared.grant(allowed)
        XCTAssertNotEqual(replaced.identity, root.identity)
        let fd = try FS.openDirectory(replaced.path); close(fd)
    }
    /// Two allowed folders are renamed so that one takes the other's old name. The stale grant for
    /// that name is passed over, and the folder allowed above both still leads to what is there now.
    func testAStaleGrantDoesNotHideAFolderAllowedAboveIt() throws {
        let above = try folder()
        let a = above.appendingPathComponent("A"), b = above.appendingPathComponent("B"), c = above.appendingPathComponent("C")
        for url in [a, b] { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
        try make(a, Data("inside-a.txt".utf8))
        try AccessRoots.shared.grant(above); let wasA = try AccessRoots.shared.grant(a); try AccessRoots.shared.grant(b)
        try FileManager.default.moveItem(at: b, to: c); try FileManager.default.moveItem(at: a, to: b)
        // /above/B is now the folder that was A. The grant kept under that name belongs to the folder now at C.
        let fd = try FS.openDirectory(RawPath(b.path)); defer { close(fd) }
        XCTAssertEqual(AccessRoots.shared.root(reaching: RawPath(b.path))?.path, RawPath(above.path), "What leads there is the folder above, not the grant that went stale")
        XCTAssertEqual(AccessRoots.shared.root(containing: RawPath(b.path))?.path, RawPath(b.path), "The place itself is still known as one that was allowed")
        XCTAssertEqual(try FS.directoryIdentity(fd), wasA.identity)
        XCTAssertEqual(try FS.names(fd), [Data("inside-a.txt".utf8)])
        // Without the folder above, the same name is simply not available.
        AccessRoots.shared.release(RawPath(above.path))
        XCTAssertThrowsError(try FS.openDirectory(RawPath(b.path))) { XCTAssertEqual(($0 as? FSError)?.code, "UnavailableHelp") }
        // Never allowed at all is still a request for access.
        let stranger = try folder()
        XCTAssertThrowsError(try FS.openDirectory(RawPath(stranger.path))) { XCTAssertEqual(($0 as? FSError)?.code, "FolderAccessNeeded") }
    }
    /// A folder that turns out not to be the wanted one is not taken. Where it would have taken over
    /// the place of a folder that was moved away, that place stays as it was: not available, and
    /// still held by whoever held it.
    func testAFolderThatIsNotWantedLeavesEverythingAsItWas() throws {
        let place = try folder()
        let first = try AccessRoots.shared.grant(place)
        func replace() throws {
            let moved = place.deletingLastPathComponent().appendingPathComponent("namefix-access-moved-\(UUID())"); made.append(moved)
            try FileManager.default.moveItem(at: place, to: moved); try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        }
        try replace()
        XCTAssertNil(try AccessRoots.shared.grant(place, if: { root in XCTAssertNotEqual(root.identity, first.identity); return false }))
        XCTAssertThrowsError(try FS.openDirectory(first.path)) { XCTAssertEqual(($0 as? FSError)?.code, "UnavailableHelp") }
        XCTAssertNil(AccessRoots.shared.root(reaching: first.path), "A moved folder leads nowhere")
        XCTAssertTrue(AccessRoots.shared.isRoot(first.path), "Its holder still holds the place")
        AccessRoots.shared.release(first.path); XCTAssertFalse(AccessRoots.shared.isRoot(first.path))
        // Not wanted, with nothing there before: not kept either.
        XCTAssertNil(try AccessRoots.shared.grant(place, if: { _ in false })); XCTAssertFalse(AccessRoots.shared.isRoot(first.path))
        // Wanted: it is asked while the folder is in place, and the folder is kept.
        let kept = try XCTUnwrap(try AccessRoots.shared.grant(place, if: { root in (try? FS.openDirectory(root.path)).map { fd -> Bool in close(fd); return true } ?? false }))
        XCTAssertEqual(AccessRoots.shared.root(reaching: kept.path), kept)
        // Taking over a moved folder's place carries its holders on: each of them gives the place back once.
        try replace()
        let third = try AccessRoots.shared.grant(place)
        XCTAssertNotEqual(third.identity, kept.identity)
        AccessRoots.shared.release(third.path); XCTAssertEqual(AccessRoots.shared.root(reaching: third.path), third, "One of the two holders gave it back")
        AccessRoots.shared.release(third.path); XCTAssertFalse(AccessRoots.shared.isRoot(third.path))
    }

    func testScanRenameAndUndoInsideAnAllowedFolder() async throws {
        let allowed = try folder(), state = try folder()
        let inner = try make(allowed, composed("하위 폴더"), folder: true)
        let files = ["보고서.txt", "café.pdf"].map(decomposed)
        for raw in files { try make(allowed, raw) }
        try make(URL(fileURLWithPath: inner.display), decomposed("ガイド.txt"))
        let root = try AccessRoots.shared.grant(allowed)
        try AccessRoots.shared.grant(state)   // where the app keeps its own records
        let entries = scan([root.path])
        // The allowed folder is listed like any other row: its name needs no change, so nothing more is needed.
        XCTAssertEqual(entries.first?.path, root.path); XCTAssertEqual(entries.first?.status, .normal); XCTAssertEqual(entries.first?.reason, "NormalHelp")
        XCTAssertTrue(AccessRoots.shared.needsParent(root.path)); XCTAssertFalse(AccessRoots.shared.needsParent(inner))
        XCTAssertEqual(entries.filter { $0.status.fixable }.count, 3)
        let journal = try JournalStore(root: state.appendingPathComponent("History")), coordinator = TransactionCoordinator(store: journal)
        let approved = try plan(entries); XCTAssertEqual(approved.operations.count, 3)
        XCTAssertTrue(approved.operations.allSatisfy { $0.volume == root.volume })
        let done = try await coordinator.execute(approved, token: CancellationToken()); XCTAssertEqual(done.succeeded, 3)
        XCTAssertEqual(try names(root.path), [composed("하위 폴더"), composed("보고서.txt"), composed("café.pdf")])
        // Without the folder nothing can be undone, and the record says which folder it needs.
        AccessRoots.shared.release(root.path)
        XCTAssertEqual(try History.folderNeeded(store: journal, id: approved.id), root.path)
        XCTAssertEqual(try History.undo(store: journal, id: approved.id, generation: UUID()).operations.count, 0)
        // With it, the undo is exact.
        try AccessRoots.shared.grant(allowed)
        XCTAssertNil(try History.folderNeeded(store: journal, id: approved.id))
        let undo = try History.undo(store: journal, id: approved.id, generation: UUID()); XCTAssertEqual(undo.operations.count, 3)
        let undone = try await coordinator.execute(undo, token: CancellationToken()); XCTAssertEqual(undone.succeeded, 3)
        XCTAssertEqual(try names(root.path), Set(files + [composed("하위 폴더")]))
    }

    func testAFileOnItsOwnAsksForItsFolder() throws {
        let allowed = try folder()
        let file = try make(allowed, decomposed("혼자.txt"))
        let alone = scan([file])
        XCTAssertEqual(alone.count, 1); XCTAssertEqual(alone[0].status, .accessDenied); XCTAssertEqual(alone[0].reason, "FolderAccessNeeded")
        XCTAssertEqual(try plan(alone.map { item in var e = item; e.status = .needsNormalization; return e }).operations.count, 0)
        try AccessRoots.shared.grant(allowed)
        XCTAssertEqual(scan([file]).first?.status, .needsNormalization)
    }

    func testAKeptBookmarkLeadsBackOnlyToTheSameFolder() throws {
        let allowed = try folder()
        let root = try AccessRoots.shared.grant(allowed)
        let bookmark = try XCTUnwrap(AccessRoots.shared.bookmark(for: root.path))
        let kept = StoredGrant(root: root, bookmark: bookmark, transaction: UUID())
        AccessRoots.shared.releaseAll()
        // A new session: the bookmark opens the folder again.
        guard case .granted(let again) = GrantLibrary.resolve(kept).0 else { return XCTFail("The folder should be reachable") }
        XCTAssertEqual(again, root); XCTAssertTrue(AccessRoots.shared.isRoot(root.path))
        AccessRoots.shared.releaseAll()
        // The record names another volume, or another folder: the bookmark alone is not trusted.
        var otherVolume = kept; otherVolume.volume = UUID().uuidString
        XCTAssertEqual(GrantLibrary.resolve(otherVolume).0, .differentFolder)
        var otherFolder = kept; otherFolder.identity.inode += 1
        XCTAssertEqual(GrantLibrary.resolve(otherFolder).0, .differentFolder)
        XCTAssertFalse(AccessRoots.shared.isRoot(root.path), "A refused folder is given back")
        // The folder is gone: nothing is guessed.
        try FileManager.default.removeItem(at: allowed)
        XCTAssertEqual(GrantLibrary.resolve(kept).0, .unavailable)
        var broken = kept; broken.bookmark = Data([1, 2, 3])
        XCTAssertEqual(GrantLibrary.resolve(broken).0, .unavailable)
    }

    func testGrantsAreCountedAndTheStoreKeepsWhatItIsGiven() async throws {
        let allowed = try folder(), state = try folder()
        let first = try AccessRoots.shared.grant(allowed), second = try AccessRoots.shared.grant(allowed)
        XCTAssertEqual(first, second)
        AccessRoots.shared.release(first.path); XCTAssertTrue(AccessRoots.shared.isRoot(first.path), "Still held once")
        AccessRoots.shared.release(first.path); XCTAssertFalse(AccessRoots.shared.isRoot(first.path))
        AccessRoots.shared.release(first.path)   // one too many is harmless
        let root = try AccessRoots.shared.grant(allowed)
        try AccessRoots.shared.grant(state)
        let store = GrantStore(url: state.appendingPathComponent("access.json"))
        var library = try await store.load(); XCTAssertTrue(library.grants.isEmpty)
        library.grants.append(StoredGrant(root: root, bookmark: try XCTUnwrap(AccessRoots.shared.bookmark(for: root.path)), transaction: UUID()))
        try await store.save(library)
        let loaded = try await GrantStore(url: state.appendingPathComponent("access.json")).load()
        XCTAssertEqual(loaded.grants, library.grants)
        // A file from a newer version is left as it is and not written over.
        try Data(#"{"schemaVersion":2,"grants":[]}"#.utf8).write(to: state.appendingPathComponent("newer.json"))
        let newer = GrantStore(url: state.appendingPathComponent("newer.json"))
        do { _ = try await newer.load(); XCTFail("A newer file must not be read as this version") } catch {}
        do { try await newer.save(GrantLibrary()); XCTFail("A newer file must not be replaced") } catch {}
    }

    func testUnrestrictedAppsStillWalkFromTheTop() throws {
        AccessRoots.shared.restrict(false)
        let anywhere = try folder()
        let fd = try FS.openDirectory(RawPath(anywhere.path)); close(fd)
        // Allowing a folder changes nothing for a directly distributed app: every ancestor is still checked.
        let inside = try folder()
        XCTAssertEqual(symlink(inside.path, anywhere.path + "/link"), 0)
        try AccessRoots.shared.grant(inside)
        XCTAssertThrowsError(try FS.openDirectory(RawPath(anywhere.path + "/link"))) { XCTAssertEqual(($0 as? FSError)?.code, "LinkedPathHelp") }
        XCTAssertNil(try History.folderNeeded(store: try JournalStore(root: anywhere.appendingPathComponent("History")), id: UUID()))
    }
}
