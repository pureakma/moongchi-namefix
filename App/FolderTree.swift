import Foundation
import NameFixCore

/// One row of the sidebar tree: an added file, an added folder, or a folder found inside one.
/// Built from scan results only; selecting a node narrows the list, it never changes what is renamed.
struct FolderNode: Identifiable, Hashable, Sendable {
    let id: RawPath
    let name: String
    let isDirectory: Bool
    let isRoot: Bool
    /// Changeable items in this folder and everything below it.
    let pending: Int
    var children: [FolderNode]?
}

enum FolderTree {
    static func build(roots: [RawPath], entries: [FileEntry]) -> [FolderNode] {
        var directories = Set<RawPath>(), childFolders: [RawPath: [RawPath]] = [:], pending: [RawPath: Int] = [:]
        for entry in entries where entry.isDirectory { directories.insert(entry.path) }
        for path in directories where directories.contains(path.parent) { childFolders[path.parent, default: []].append(path) }
        var pendingFiles = Set<RawPath>()
        for entry in entries where entry.status.fixable {
            if !entry.isDirectory { pendingFiles.insert(entry.path) }
            // Count toward the containing folder and every scanned ancestor.
            var folder = entry.isDirectory ? entry.path : entry.path.parent
            while directories.contains(folder) {
                pending[folder, default: 0] += 1
                let parent = folder.parent
                if parent == folder { break }
                folder = parent
            }
        }
        func name(_ path: RawPath) -> String { String(data: path.leaf, encoding: .utf8) ?? path.display }
        func node(_ path: RawPath, root: Bool) -> FolderNode {
            let children = (childFolders[path] ?? []).sorted { name($0).localizedStandardCompare(name($1)) == .orderedAscending }.map { node($0, root: false) }
            return FolderNode(id: path, name: name(path), isDirectory: true, isRoot: root, pending: pending[path] ?? 0, children: children.isEmpty ? nil : children)
        }
        return roots.map { root in
            directories.contains(root) ? node(root, root: true)
                : FolderNode(id: root, name: name(root), isDirectory: false, isRoot: true, pending: pendingFiles.contains(root) ? 1 : 0, children: nil)
        }
    }
    /// True when `path` is the selected node itself or lies inside it.
    static func contains(_ folder: RawPath, _ path: RawPath) -> Bool { Scope(folder).contains(path) }
    /// A folder and everything inside it, for checking many paths: the prefix is built once.
    struct Scope: Sendable {
        let folder: RawPath
        private let prefix: Data
        init(_ folder: RawPath) { self.folder = folder; prefix = folder.bytes + Data([47]) }
        func contains(_ path: RawPath) -> Bool { path == folder || path.bytes.starts(with: prefix) }
    }
    static func paths(_ nodes: [FolderNode]) -> Set<RawPath> {
        var result = Set<RawPath>()
        func visit(_ node: FolderNode) { result.insert(node.id); node.children?.forEach(visit) }
        nodes.forEach(visit); return result
    }
}
