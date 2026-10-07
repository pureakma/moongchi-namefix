import XCTest
import Foundation
import Darwin
import CryptoKit
import NameFixCore
@testable import NameFixRuntime

final class FilesystemTests: XCTestCase {
    func fixture() throws -> URL { let p = URL(fileURLWithPath: ProcessInfo.processInfo.environment["NAMEFIX_FIXTURE_ROOT"] ?? "/private/tmp").appendingPathComponent("namefix-fixture-\(UUID())"); try FileManager.default.createDirectory(at: p, withIntermediateDirectories: true); return p }
    func testVolumeCaseBehavior() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let a = openat(fd, "Case.txt", O_CREAT | O_EXCL | O_WRONLY, 0o600); XCTAssertGreaterThanOrEqual(a, 0); close(a)
        let b = openat(fd, "case.txt", O_CREAT | O_EXCL | O_WRONLY, 0o600)
        let error = errno
        if b >= 0 { close(b) }
        // The volume says which it is; the fixture may be either kind of APFS.
        if try FS.support(fd).caseSensitive { XCTAssertGreaterThanOrEqual(b, 0) }
        else { XCTAssertEqual(b, -1); XCTAssertEqual(error, EEXIST) }
        print("CASE_SENSITIVE", b >= 0)
    }
    func testAPFSRawSpellingAndExclusiveRename() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let nfd = Data("e\u{301}.txt".utf8), nfc = Data("é.txt".utf8), tmp = Data(".temporary".utf8)
        print("FIXTURE", root.path)
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        XCTAssertEqual(try FS.capability(fd), "apfs")
        let f = FS.cPath(nfd) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }; XCTAssertGreaterThanOrEqual(f, 0); close(f)
        let identity = try FS.identity(FS.metadata(fd, nfd))
        XCTAssertEqual(try FS.identity(FS.metadata(fd, nfc)), identity)
        XCTAssertTrue(try FS.names(fd).contains(nfd)); XCTAssertFalse(try FS.names(fd).contains(nfc))
        try FS.noReplace(fd, from: nfd, to: tmp); try FS.noReplace(fd, from: tmp, to: nfc)
        try FS.verify(fd, raw: nfc, identity: identity)
        XCTAssertEqual(try FS.identity(FS.metadata(fd, nfd)), identity, "Old spelling lookup still resolves on APFS")
        let g = FS.cPath(tmp) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }; close(g)
        XCTAssertThrowsError(try FS.noReplace(fd, from: nfc, to: tmp))
        try FS.verify(fd, raw: nfc, identity: identity)
    }
}
