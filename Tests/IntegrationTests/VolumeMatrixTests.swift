import XCTest
import Foundation
import Darwin
import NameFixCore
@testable import NameFixRuntime
import NameFixApplication

/// Volume contracts, run by eng/test-volumes.py on disposable disk images (APFS, case-sensitive
/// APFS, exFAT, FAT). Without its environment the same checks run on the internal disk.
/// Every file is made by the test inside a folder it creates; nothing else is touched.
final class VolumeMatrixTests: XCTestCase, @unchecked Sendable {
    private let env = ProcessInfo.processInfo.environment
    private var kind: String { env["NAMEFIX_VOLUME_KIND"] ?? "apfs" }
    private var phase: String { env["NAMEFIX_VOLUME_PHASE"] ?? "" }
    private var onImage: Bool { env["NAMEFIX_FIXTURE_ROOT"] != nil }
    private var base: URL { URL(fileURLWithPath: env["NAMEFIX_FIXTURE_ROOT"] ?? "/private/tmp") }
    private var apfs: Bool { kind.hasPrefix("apfs") }
    private func only(apfs wanted: Bool, phase wantedPhase: String = "") throws {
        guard phase == wantedPhase else { throw XCTSkip("Runs in phase '\(wantedPhase)'") }
        guard apfs == wanted else { throw XCTSkip("Not for \(kind)") }
    }
    private func fixture(_ name: String = "namefix-volume-\(UUID())") throws -> URL {
        let root = base.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
    /// Journals live on the internal disk, as they do in the app, not on the volume under test.
    private func store(_ name: String = "namefix-volume-journal-\(UUID())") throws -> JournalStore {
        let root = URL(fileURLWithPath: env["NAMEFIX_STATE_DIR"] ?? "/private/tmp").appendingPathComponent(name)
        // Phase journals are read by the next phase; the tool removes their folder at the end.
        if phase.isEmpty { journals.append(root) }
        return try JournalStore(root: root)
    }
    private var journals: [URL] = []
    override func tearDown() { for root in journals { try? FileManager.default.removeItem(at: root) }; journals = [] }
    /// Creates an entry whose name is exactly these bytes.
    @discardableResult private func make(_ directory: URL, _ raw: Data, folder: Bool = false, payload: String = "payload") throws -> RawPath {
        let fd = try FS.openDirectory(RawPath(directory.path)); defer { close(fd) }
        if folder { guard FS.cPath(raw, { mkdirat(fd, $0, 0o755) }) == 0 else { throw FSError("FixtureCreate") } }
        else {
            let file = FS.cPath(raw) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }
            guard file >= 0 else { throw FSError("FixtureCreate") }
            let bytes = Array(payload.utf8); _ = write(file, bytes, bytes.count); close(file)
        }
        return try FS.rawDirectoryPath(fd).appending(raw)
    }
    private func names(_ directory: URL) throws -> Set<Data> {
        let fd = try FS.openDirectory(RawPath(directory.path)); defer { close(fd) }
        return Set(try FS.names(fd).filter { !$0.starts(with: Data("._".utf8)) })
    }
    private func scan(_ root: URL, recursive: Bool = true) -> [FileEntry] {
        Scanner.scan(roots: [RawPath(root.path)], recursive: recursive, token: CancellationToken()).entries
    }
    private func plan(_ entries: [FileEntry]) throws -> RenamePlan {
        try Planning.make(entries: entries, selected: Set(entries.filter { $0.status.fixable }.map(\.id)), generation: UUID())
    }
    private func decomposed(_ text: String) -> Data { Data(text.decomposedStringWithCanonicalMapping.utf8) }
    private func composed(_ text: String) -> Data { Data(text.precomposedStringWithCanonicalMapping.utf8) }

    // MARK: Support level

    func testSupportLevelMatchesTheVolume() throws {
        guard phase.isEmpty else { throw XCTSkip("Phase run") }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let support = try FS.support(fd)
        print("VOLUME kind=\(kind) filesystem=\(support.filesystem) local=\(support.local) writable=\(support.writable) caseSensitive=\(support.caseSensitive) level=\(support.level.rawValue) reason=\(support.reason ?? "-")")
        XCTAssertTrue(support.local); XCTAssertTrue(support.writable)
        if apfs {
            XCTAssertEqual(support.filesystem, "apfs"); XCTAssertEqual(support.level, .supported); XCTAssertNil(support.reason)
            XCTAssertEqual(try FS.capability(fd), "apfs")
            if onImage { XCTAssertEqual(support.caseSensitive, kind == "apfs-case-sensitive") }
        } else {
            XCTAssertEqual(support.level, .unsupported); XCTAssertEqual(support.reason, "VolumeFATUnsupported")
            XCTAssertThrowsError(try FS.capability(fd)) { XCTAssertEqual(($0 as? FSError)?.code, "VolumeFATUnsupported") }
        }
        XCTAssertTrue(VolumeSupport.locationReasons.contains("VolumeFATUnsupported"))
    }

    // MARK: Names from many scripts, repaired and restored byte for byte

    func testGlobalNamesAreRepairedAndRestoredByteForByte() async throws {
        try only(apfs: true)
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        // Stored decomposed; repaired to the composed form.
        let repaired = ["한글 문서.txt", "프로젝트_최종.key", "café.txt", "Ångström.pdf", "señor.md", "über uns.rtf", "Việt Nam.txt", "ớ.txt",
                        "がぎぐげご.txt", "ぱぴぷぺぽ.txt", "ガイド.pdf", "パスポート.jpg", "ελληνικά ά.txt", "й.txt"]
        // Already composed, or made of characters that have no composed form: left alone.
        let untouched = ["👨‍👩‍👧‍👦 family.txt", "👍🏽.txt", "✈️.txt", "𝒜 math.txt", "中文.txt", "Ａ１ fullwidth.txt", "ｶﾞ halfwidth.txt", "ㅎㅏㄴ compat jamo.txt", "\u{301}leading mark.txt", "plain ASCII.txt"]
        for name in repaired { try make(root, decomposed(name), payload: name) }
        for name in untouched { try make(root, Data(name.utf8), payload: name) }
        // Part composed, part decomposed.
        let mixed = Data("한".utf8) + decomposed("글") + Data(" mixed.txt".utf8)
        try make(root, mixed, payload: "mixed")
        // A decomposed folder with a decomposed child: the child is renamed before its parent.
        let folder = try make(root, decomposed("여행 사진"), folder: true)
        try make(URL(fileURLWithPath: folder.display), decomposed("저녁 식사.jpg"), payload: "child")
        let before = try names(root)
        let entries = scan(root)
        for name in repaired { XCTAssertEqual(entries.first { $0.path.leaf == decomposed(name) }?.status, .needsNormalization, name) }
        for name in untouched { XCTAssertEqual(entries.first { $0.path.leaf == Data(name.utf8) }?.status, .normal, name) }
        XCTAssertEqual(entries.first { $0.path.leaf == mixed }?.status, .mixed)
        let journal = try store(), coordinator = TransactionCoordinator(store: journal)
        let approved = try plan(entries)
        XCTAssertEqual(approved.operations.count, repaired.count + 3); XCTAssertEqual(approved.excluded, 0)
        let summary = try await coordinator.execute(approved, token: CancellationToken())
        XCTAssertEqual(summary.succeeded, approved.operations.count); XCTAssertEqual(summary.status, "Completed")
        let after = try names(root)
        for name in repaired { XCTAssertTrue(after.contains(composed(name)), name); XCTAssertFalse(after.contains(decomposed(name)), name) }
        for name in untouched { XCTAssertTrue(after.contains(Data(name.utf8)), name) }
        XCTAssertTrue(after.contains(composed("한글 mixed.txt"))); XCTAssertTrue(after.contains(composed("여행 사진")))
        XCTAssertEqual(try names(root.appendingPathComponent("여행 사진")), [composed("저녁 식사.jpg")])
        for name in repaired { XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8), name) }
        XCTAssertEqual(scan(root).filter { $0.status.fixable }.count, 0)
        XCTAssertFalse(after.contains { $0.starts(with: Data(".namefix-".utf8)) })
        let undo = try History.undo(store: journal, id: approved.id, generation: UUID())
        XCTAssertEqual(undo.operations.count, approved.operations.count)
        let undone = try await coordinator.execute(undo, token: CancellationToken())
        XCTAssertEqual(undone.succeeded, approved.operations.count)
        XCTAssertEqual(try names(root), before, "Undo restores every stored name byte for byte")
        XCTAssertEqual(try names(URL(fileURLWithPath: folder.display)), [decomposed("저녁 식사.jpg")])
    }

    // MARK: Collisions

    func testEquivalentAndCaseNamesFollowTheVolume() throws {
        try only(apfs: true)
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let sensitive = try FS.support(fd).caseSensitive
        // A composed and a decomposed spelling are one name on APFS in either case mode.
        try make(root, decomposed("é.txt"))
        XCTAssertThrowsError(try make(root, composed("é.txt")))
        XCTAssertEqual(try FS.storedName(fd, lookup: composed("é.txt")), decomposed("é.txt"))
        // Names that differ only in case are one name unless the volume is case-sensitive.
        try make(root, Data("readme.txt".utf8))
        if sensitive { XCTAssertNoThrow(try make(root, Data("README.txt".utf8))) } else { XCTAssertThrowsError(try make(root, Data("README.txt".utf8))) }
        let listed = Set(try FS.names(fd))
        let identity = try FS.identity(FS.metadata(fd, decomposed("é.txt")))
        // Respelling the same entry is allowed; it is not a collision.
        XCTAssertTrue(try FS.destinationAvailable(fd, source: decomposed("é.txt"), dest: composed("é.txt"), expected: identity, names: listed))
        let readme = try FS.identity(FS.metadata(fd, Data("readme.txt".utf8)))
        XCTAssertEqual(try FS.destinationAvailable(fd, source: Data("readme.txt".utf8), dest: Data("README.txt".utf8), expected: readme, names: listed), !sensitive,
                       "Free as a case-only respelling of itself; taken when another file owns it")
    }

    func testNoDestinationIsEverOverwritten() async throws {
        try only(apfs: true)
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let sensitive = try FS.support(fd).caseSensitive
        // source name, wanted name, name already there, whether that is a folder
        var cases: [(String, Data, Data, Bool)] = [
            ("exact.txt", Data("taken.txt".utf8), Data("taken.txt".utf8), false),
            ("equivalent.txt", composed("ü.txt"), decomposed("ü.txt"), false),
            ("file-to-folder", Data("Folder".utf8), Data("Folder".utf8), true),
            ("hardlink.txt", Data("second-link.txt".utf8), Data("second-link.txt".utf8), false)
        ]
        if !sensitive { cases.append(("case.txt", Data("LICENSE".utf8), Data("license".utf8), false)) }
        var entries: [FileEntry] = []
        for (source, wanted, occupant, folder) in cases {
            let path = try make(root, Data(source.utf8), payload: "source \(source)")
            if source == "hardlink.txt" { XCTAssertEqual(linkat(fd, source, fd, "second-link.txt", 0), 0) }
            else { try make(root, occupant, folder: folder, payload: "occupant \(source)") }
            let identity = try FS.identity(FS.metadata(fd, Data(source.utf8)))
            XCTAssertFalse(try FS.destinationAvailable(fd, source: Data(source.utf8), dest: wanted, expected: identity, names: Set(try FS.names(fd))), source)
            XCTAssertThrowsError(try FS.noReplace(fd, from: Data(source.utf8), to: wanted), source) { XCTAssertEqual(($0 as? FSError)?.code, "ConflictHelp") }
            entries.append(FileEntry(path: path, identity: identity, parentIdentity: try FS.directoryIdentity(fd), status: .needsNormalization, reason: "RuleChangeHelp", proposed: wanted))
        }
        let before = try names(root)
        // A plan built on these wishes contains nothing, and a forced run moves nothing.
        XCTAssertEqual(try plan(entries).operations.count, 0)
        let forced = RenamePlan(generation: UUID(), operations: try entries.map { try RenameOperation(entry: $0) })
        let summary = try await TransactionCoordinator(store: try store()).execute(forced, token: CancellationToken())
        XCTAssertEqual(summary.succeeded, 0); XCTAssertEqual(summary.failed, cases.count)
        XCTAssertEqual(try names(root), before)
        for (source, _, occupant, folder) in cases where source != "hardlink.txt" && !folder {
            XCTAssertEqual(try String(contentsOf: FileCoordination.url(RawPath(root.path).appending(occupant)), encoding: .utf8), "occupant \(source)")
            XCTAssertEqual(try String(contentsOf: root.appendingPathComponent(source), encoding: .utf8), "source \(source)")
        }
        if sensitive {
            // On a case-sensitive volume a name that differs only in case is a free name.
            let path = try make(root, Data("case.txt".utf8)); try make(root, Data("license".utf8), payload: "lower")
            let identity = try FS.identity(FS.metadata(fd, Data("case.txt".utf8)))
            let entry = FileEntry(path: path, identity: identity, parentIdentity: try FS.directoryIdentity(fd), status: .needsNormalization, reason: "RuleChangeHelp", proposed: Data("LICENSE".utf8))
            let done = try await TransactionCoordinator(store: try store()).execute(try plan([entry]), token: CancellationToken())
            XCTAssertEqual(done.succeeded, 1)
            XCTAssertTrue(try names(root).isSuperset(of: [Data("LICENSE".utf8), Data("license".utf8)]))
            XCTAssertEqual(try String(contentsOf: root.appendingPathComponent("license"), encoding: .utf8), "lower")
        }
    }

    // MARK: Profile (opt-in)

    func testScanRenameAndUndoProfile() async throws {
        try only(apfs: true)
        guard env["NAMEFIX_MUTATION_PERF"] == "1" else { throw XCTSkip("Opt-in profile") }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for i in 0..<1000 { try make(root, decomposed("보고서 é \(i).txt"), payload: "\(i)") }
        var start = Date()
        let entries = scan(root); let scanSeconds = Date().timeIntervalSince(start)
        start = Date(); let approved = try plan(entries); let planSeconds = Date().timeIntervalSince(start)
        XCTAssertEqual(approved.operations.count, 1000)
        let journal = try store(), coordinator = TransactionCoordinator(store: journal)
        start = Date(); let done = try await coordinator.execute(approved, token: CancellationToken()); let renameSeconds = Date().timeIntervalSince(start)
        XCTAssertEqual(done.succeeded, 1000)
        start = Date(); let undo = try History.undo(store: journal, id: approved.id, generation: UUID()); let undoPlanSeconds = Date().timeIntervalSince(start)
        start = Date(); let undone = try await coordinator.execute(undo, token: CancellationToken()); let undoSeconds = Date().timeIntervalSince(start)
        XCTAssertEqual(undone.succeeded, 1000)
        print(String(format: "VOLUME_PROFILE kind=%@ onImage=%@ files=1000 scan=%.3f plan=%.3f rename=%.3f undoPlan=%.3f undo=%.3f", kind, onImage ? "yes" : "no", scanSeconds, planSeconds, renameSeconds, undoPlanSeconds, undoSeconds))
    }

    // MARK: A disk added as a whole

    func testAddedDiskIsScannedButItsOwnNameIsNotChanged() throws {
        try only(apfs: true)
        guard onImage else { throw XCTSkip("Needs a mounted fixture volume") }
        let child = try make(base, decomposed("루트 파일 \(UUID().uuidString.prefix(6)).txt"))
        defer { unlink(child.display) }
        let entries = scan(base, recursive: false)
        XCTAssertEqual(entries.first?.path, RawPath(base.path)); XCTAssertEqual(entries.first?.status, .unsupported); XCTAssertEqual(entries.first?.reason, "VolumeRootExcluded")
        XCTAssertEqual(entries.first { $0.path == child }?.status, .needsNormalization)
    }

    // MARK: FAT and exFAT are listed and left alone

    func testFATVolumeIsListedAndLeftAlone() throws {
        try only(apfs: false)
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        // The decisive fact: a name created composed is listed decomposed, so the stored spelling cannot be observed.
        try make(root, composed("한글.txt")); try make(root, composed("café.txt")); try make(root, Data("plain.txt".utf8))
        let listed = try names(root)
        XCTAssertFalse(listed.contains(composed("한글.txt"))); XCTAssertTrue(listed.contains(decomposed("한글.txt")))
        XCTAssertFalse(listed.contains(composed("café.txt"))); XCTAssertTrue(listed.contains(decomposed("café.txt")))
        // Recorded for the report; these may differ between macOS versions.
        let first = try FS.identity(FS.metadata(fd, Data("plain.txt".utf8)))
        let exclusive = FS.cPath(Data("plain.txt".utf8)) { a in FS.cPath(Data("moved.txt".utf8)) { renameatx_np(fd, a, fd, $0, UInt32(RENAME_EXCL)) } }
        let exclusiveError = exclusive == 0 ? 0 : errno
        let now = try? FS.identity(FS.metadata(fd, Data((exclusive == 0 ? "moved.txt" : "plain.txt").utf8)))
        print("FAT_FACTS kind=\(kind) exclusiveRename=\(exclusive == 0 ? "ok" : "errno \(exclusiveError)") identityKeptAcrossRename=\(now == first) composedNameListedDecomposed=true")
        // The app lists the items, explains why, and plans nothing.
        let before = try names(root)
        let entries = scan(root)
        XCTAssertEqual(entries.count, try FS.names(fd).count + 1)
        for entry in entries where entry.path != RawPath(root.path) { XCTAssertEqual(entry.status, .unsupported, entry.name); XCTAssertEqual(entry.reason, "VolumeFATUnsupported", entry.name) }
        let wishes = entries.map { item -> FileEntry in var e = item; e.status = .needsNormalization; return e }
        XCTAssertEqual(try plan(wishes).operations.count, 0, "Even a forged selection cannot be planned on this volume")
        XCTAssertEqual(try names(root), before)
    }

    // MARK: Detach, attach again, another disk in its place, read-only (driven by eng/test-volumes.py)

    private struct State: Codable { var plan: UUID; var twinPlan: UUID; var folder: String; var twinFolder: String; var original: [Data]; var repaired: [Data] }
    private var stateURL: URL { URL(fileURLWithPath: env["NAMEFIX_STATE_DIR"] ?? "/private/tmp").appendingPathComponent("volume-state.json") }
    private func state() throws -> State { try JSONDecoder().decode(State.self, from: Data(contentsOf: stateURL)) }

    func testPhasePrepareRenamesOnTheVolume() async throws {
        try only(apfs: true, phase: "prepare")
        let original = ["보고서.txt", "résumé.pdf", "ガイド.txt"].map(decomposed)
        let journal = try store("phase-journal"), coordinator = TransactionCoordinator(store: journal)
        var plans: [UUID] = [], folders: [String] = []
        for name in ["phase-renamed", "phase-twin"] {
            let root = try fixture(name)
            for raw in original { try make(root, raw) }
            let approved = try plan(scan(root))
            XCTAssertTrue(approved.operations.allSatisfy { $0.volume != nil }, "Every operation names its volume")
            let summary = try await coordinator.execute(approved, token: CancellationToken())
            XCTAssertEqual(summary.succeeded, 3)
            plans.append(approved.id); folders.append(root.path)
        }
        // A third folder stays decomposed for the read-only phase.
        let readOnly = try fixture("phase-readonly")
        for raw in original { try make(readOnly, raw) }
        try JSONEncoder().encode(State(plan: plans[0], twinPlan: plans[1], folder: folders[0], twinFolder: folders[1], original: original, repaired: ["보고서.txt", "résumé.pdf", "ガイド.txt"].map(composed))).write(to: stateURL)
    }

    func testPhaseDetachedVolumeFailsSafely() throws {
        try only(apfs: true, phase: "detached")
        let state = try state(), journal = try store("phase-journal")
        XCTAssertFalse(FileManager.default.fileExists(atPath: state.folder), "The volume is detached")
        // Nothing can be planned, nothing is guessed, and the record stays readable.
        let undo = try History.undo(store: journal, id: state.plan, generation: UUID())
        XCTAssertEqual(undo.operations.count, 0); XCTAssertEqual(undo.excluded, 3)
        XCTAssertEqual(try History.details(store: journal, id: state.plan).filter { $0.state == "Verified" }.count, 3)
        let gone = scan(URL(fileURLWithPath: state.folder))
        XCTAssertEqual(gone.count, 1); XCTAssertTrue(gone[0].status == .unavailable || gone[0].status == .accessDenied)
    }

    func testPhaseReattachedVolumeIsRecognizedAndUndone() async throws {
        try only(apfs: true, phase: "reattached")
        let state = try state(), journal = try store("phase-journal")
        let folder = URL(fileURLWithPath: state.folder)
        XCTAssertEqual(try names(folder), Set(state.repaired))
        let recorded = try History.details(store: journal, id: state.plan).map(\.operation.identity.device)
        let fd = try FS.openDirectory(RawPath(folder.path)); defer { close(fd) }
        let device = try FS.directoryIdentity(fd).device
        print("REATTACHED recordedDevice=\(recorded.first ?? 0) currentDevice=\(device) sameNumber=\(recorded.first == device)")
        // The same volume under whatever device number it has now: the record identifies the files.
        let undo = try History.undo(store: journal, id: state.plan, generation: UUID())
        XCTAssertEqual(undo.operations.count, 3); XCTAssertEqual(undo.excluded, 0)
        let undone = try await TransactionCoordinator(store: journal).execute(undo, token: CancellationToken())
        XCTAssertEqual(undone.succeeded, 3); XCTAssertEqual(try names(folder), Set(state.original))
    }

    func testPhaseAnotherDiskInItsPlaceIsRefused() throws {
        try only(apfs: true, phase: "twin")
        let state = try state(), journal = try store("phase-journal")
        // A different volume mounted at the same place, with the same folder, the same names and
        // even the same creation times as the record. It is not the volume the record names.
        let folder = try fixture("phase-twin")
        XCTAssertEqual(folder.path, state.twinFolder)
        let operations = try History.details(store: journal, id: state.twinPlan).map(\.operation)
        XCTAssertEqual(operations.count, 3)
        for operation in operations {
            let path = try make(folder, operation.destination)
            var attributes = attrlist(); attributes.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT); attributes.commonattr = attrgroup_t(ATTR_CMN_CRTIME)
            var created = timespec(tv_sec: Int(operation.identity.birthSeconds), tv_nsec: Int(operation.identity.birthNanoseconds))
            XCTAssertEqual(setattrlist(path.display, &attributes, &created, MemoryLayout<timespec>.size, 0), 0)
        }
        let before = try names(folder)
        do {
            let undo = try History.undo(store: journal, id: state.twinPlan, generation: UUID())
            XCTAssertEqual(undo.operations.count, 0); XCTAssertEqual(undo.excluded, 3)
        } catch let error as FSError { XCTAssertEqual(error.code, "UndoAfterReconnect") }
        XCTAssertTrue(try History.inspect(store: journal, id: state.twinPlan).isEmpty, "A finished record has nothing to recover")
        XCTAssertEqual(try names(folder), before)
    }

    func testPhaseReadOnlyVolumeIsReviewOnly() throws {
        try only(apfs: true, phase: "readonly")
        let state = try state()
        let folder = URL(fileURLWithPath: state.folder).deletingLastPathComponent().appendingPathComponent("phase-readonly")
        let fd = try FS.openDirectory(RawPath(folder.path)); defer { close(fd) }
        let support = try FS.support(fd)
        XCTAssertEqual(support.level, .previewOnly); XCTAssertEqual(support.reason, "VolumeReadOnly"); XCTAssertFalse(support.writable)
        let entries = scan(folder)
        XCTAssertEqual(entries.count, 4)
        for entry in entries where !entry.isDirectory {
            XCTAssertEqual(entry.status, .unsupported); XCTAssertEqual(entry.reason, "VolumeReadOnly")
            XCTAssertNotEqual(entry.proposed, entry.path.leaf, "The composed name is still shown for review")
        }
        let wishes = entries.map { item -> FileEntry in var e = item; if !e.isDirectory { e.status = .needsNormalization }; return e }
        XCTAssertEqual(try plan(wishes).operations.count, 0)
        XCTAssertThrowsError(try FS.noReplace(fd, from: state.original[0], to: state.repaired[0]))
        XCTAssertEqual(try names(folder), Set(state.original))
    }
}
