import XCTest
import Foundation
import NameFixCore
@testable import NameFixUIModel

@MainActor final class FolderTreeTests: XCTestCase {
    private func entry(_ path: String, directory: Bool = false, status: EntryStatus = .normal) -> FileEntry {
        FileEntry(path: RawPath(path), isDirectory: directory, status: status, reason: "", proposed: RawPath(path).leaf)
    }
    func testFoldersNestAndCountChangeableItemsBelowThem() {
        let entries = [
            entry("/a", directory: true), entry("/a/b", directory: true), entry("/a/c", directory: true),
            entry("/a/x.txt", status: .needsNormalization), entry("/a/b/y.txt", status: .needsNormalization), entry("/a/b/z.txt"),
            entry("/a/c", directory: true, status: .normal)
        ]
        let tree = FolderTree.build(roots: [RawPath("/a")], entries: entries)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].name, "a"); XCTAssertTrue(tree[0].isRoot); XCTAssertEqual(tree[0].pending, 2)
        XCTAssertEqual(tree[0].children?.map(\.name), ["b", "c"])
        XCTAssertEqual(tree[0].children?.first?.pending, 1); XCTAssertEqual(tree[0].children?.last?.pending, 0)
        XCTAssertNil(tree[0].children?.first?.children)
        XCTAssertEqual(FolderTree.paths(tree), [RawPath("/a"), RawPath("/a/b"), RawPath("/a/c")])
    }
    func testAddedFileIsALeafAndAChangeableFolderCountsItself() {
        let entries = [entry("/f.txt", status: .needsNormalization), entry("/d", directory: true, status: .needsNormalization)]
        let tree = FolderTree.build(roots: [RawPath("/f.txt"), RawPath("/d")], entries: entries)
        XCTAssertEqual(tree.map(\.isDirectory), [false, true])
        XCTAssertEqual(tree.map(\.pending), [1, 1])
    }
    func testContainsMatchesTheNodeAndItsDescendantsOnly() {
        XCTAssertTrue(FolderTree.contains(RawPath("/a/b"), RawPath("/a/b")))
        XCTAssertTrue(FolderTree.contains(RawPath("/a/b"), RawPath("/a/b/c.txt")))
        XCTAssertFalse(FolderTree.contains(RawPath("/a/b"), RawPath("/a/bc.txt")))
        XCTAssertFalse(FolderTree.contains(RawPath("/a/b"), RawPath("/a")))
    }
    func testFolderFilterNarrowsTheListWithoutChangingSelection() async throws {
        let root = URL(fileURLWithPath: "/private/tmp/namefix-tree-\(UUID())"); defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(dataRoot: root); model.ready = true
        let entries = [entry("/a", directory: true), entry("/a/b", directory: true), entry("/a/x.txt", status: .needsNormalization), entry("/a/b/y.txt", status: .needsNormalization)]
        model.entries = entries; model.roots = [RawPath("/a")]; model.selected = Set(entries.filter { $0.status.fixable }.map(\.id)); model.rebuildFolderTree()
        model.folderFilter = RawPath("/a/b")
        for _ in 0..<200 where model.visible.count != 2 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(Set(model.visible.map(\.path)), [RawPath("/a/b"), RawPath("/a/b/y.txt")])
        // Items outside the folder stay selected and are reported as hidden, so the confirmation still warns about them.
        XCTAssertEqual(model.selected.count, 2); XCTAssertEqual(model.hiddenSelected, 1)
        model.folderFilter = nil
        for _ in 0..<200 where model.visible.count != 4 { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(model.visible.count, 4); XCTAssertEqual(model.hiddenSelected, 0)
    }
}
