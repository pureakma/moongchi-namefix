import XCTest
import Foundation
import Darwin
import CryptoKit
import ImageIO
import AVFoundation
import CoreGraphics
import UniformTypeIdentifiers
import NameFixCore
import NameFixRuntime
import NameFixApplication

final class ExpansionTests: XCTestCase, @unchecked Sendable {
    func fixture() throws -> URL {
        let url = URL(fileURLWithPath: "/private/tmp/namefix-expansion-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    func testNFDThenUndoRawBytesAndContents() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let leaf = Data("한글é.txt".utf8), payload = Data("preserved".utf8)
        let parent = try FS.openDirectory(RawPath(root.path))
        let file = FS.cPath(leaf) { openat(parent, $0, O_WRONLY | O_CREAT | O_EXCL, 0o600) }
        XCTAssertGreaterThanOrEqual(file, 0)
        try Durable.writeAll(file, payload); close(file); close(parent)
        let scan = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken(), target: .nfd)
        let selected = Set(scan.entries.filter { $0.status.fixable }.map(\.id))
        let plan = try Planning.make(entries: scan.entries, selected: selected, generation: UUID())
        XCTAssertEqual(plan.operations.count, 1)
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let result = try await coordinator.execute(plan, token: CancellationToken()); XCTAssertEqual(result.succeeded, 1)
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        XCTAssertTrue(try FS.names(fd).contains(Data("한글é.txt".decomposedStringWithCanonicalMapping.utf8)))
        let undo = try History.undo(store: store, id: plan.id, generation: UUID())
        let reverted = try await coordinator.execute(undo, token: CancellationToken()); XCTAssertEqual(reverted.succeeded, 1)
        XCTAssertTrue(try FS.names(fd).contains(leaf))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("한글é.txt")), payload)
    }
    func testFreeRulePlanForPreviouslyNormalNames() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("a".utf8).write(to: root.appendingPathComponent("A.txt"))
        var r = RenameRule(.prefix); r.text = "Project_"
        let scan = Scanner.scan(roots: [RawPath(root.appendingPathComponent("A.txt").path)], recursive: false, token: CancellationToken())
        let entries = try await RulePreview.apply(scan.entries, pipeline: RulePipeline(rules: [r]), access: .free, token: CancellationToken())
        XCTAssertTrue(entries[0].status.fixable)
        let plan = try Planning.make(entries: entries, selected: [entries[0].id], generation: UUID())
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let result = try await TransactionCoordinator(store: store).execute(plan, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 1)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("Project_A.txt")), Data("a".utf8))
    }
    func testRecipeCorruptionPreservesOriginal() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("recipes.json"), original = Data("corrupt".utf8)
        try original.write(to: url); let store = RecipeStore(url: url)
        do { _ = try await store.load(); XCTFail() } catch {}
        do { try await store.save(RecipeLibrary()); XCTFail() } catch {}
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testSwapAndUndoPreserveIdentityAndPayload() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("first".utf8).write(to: root.appendingPathComponent("a.txt"))
        try Data("second".utf8).write(to: root.appendingPathComponent("b.txt"))
        var pipeline = RulePipeline(target: .unchanged)
        pipeline.mapping = NameMapping(rows: [.init(source: "a.txt", destination: "b.txt"), .init(source: "b.txt", destination: "a.txt")])
        let scan = Scanner.scan(roots: [RawPath(root.path)], recursive: false, token: CancellationToken())
        let entries = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: .pro, token: CancellationToken())
        XCTAssertEqual(entries.filter { $0.status.fixable }.count, 2)
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let result = try await coordinator.execute(plan, token: CancellationToken())
        XCTAssertEqual(result.succeeded, 2)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("a.txt")), Data("second".utf8))
        let undo = try History.undo(store: store, id: plan.id, generation: UUID())
        XCTAssertEqual(undo.operations.count, 2)
        let undone = try await coordinator.execute(undo, token: CancellationToken()); XCTAssertEqual(undone.succeeded, 2)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("a.txt")), Data("first".utf8))
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("b.txt")), Data("second".utf8))
    }
    func testUnselectedSwapDependencyAndDuplicateDestinationBlocked() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for name in ["a.txt", "b.txt"] { try Data(name.utf8).write(to: root.appendingPathComponent(name)) }
        let scan = Scanner.scan(roots: [RawPath(root.path)], recursive: false, token: CancellationToken())
        var p = RulePipeline(); p.mapping = NameMapping(rows: [.init(source: "a.txt", destination: "b.txt"), .init(source: "b.txt", destination: "a.txt")])
        let entries = try await RulePreview.apply(scan.entries, pipeline: p, access: .pro, token: CancellationToken())
        let a = try XCTUnwrap(entries.first { $0.name == "a.txt" })
        XCTAssertEqual(try Planning.make(entries: entries, selected: [a.id], generation: UUID()).operations.count, 0)
        p.mapping = NameMapping(rows: [.init(source: "a.txt", destination: "c.txt"), .init(source: "b.txt", destination: "c.txt")])
        let duplicates = try await RulePreview.apply(scan.entries, pipeline: p, access: .pro, token: CancellationToken())
        XCTAssertEqual(duplicates.filter { $0.status == .conflict }.count, 2)
    }
    func testCaseOnlyRenameAndMetadataRead() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        try Data("abc".utf8).write(to: root.appendingPathComponent("lower.txt"))
        let scan = Scanner.scan(roots: [RawPath(root.appendingPathComponent("lower.txt").path)], recursive: false, token: CancellationToken())
        let values = try await MetadataReader.read(scan.entries[0], keys: ["size", "created"])
        XCTAssertEqual(values["size"], "3"); XCTAssertNotNil(values["created"])
        let entries = try await RulePreview.apply(scan.entries, pipeline: RulePipeline(rules: [RenameRule(.uppercase)]), access: .free, token: CancellationToken())
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
        XCTAssertEqual(plan.operations.count, 1)
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let result = try await TransactionCoordinator(store: store).execute(plan, token: CancellationToken()); XCTAssertEqual(result.succeeded, 1)
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        XCTAssertTrue(try FS.names(fd).contains(Data("LOWER.txt".utf8)))
    }

    func testStoredNameLookupReturnsRawSpelling() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        let raw = Data("한글É.txt".decomposedStringWithCanonicalMapping.utf8)
        let file = FS.cPath(raw) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }; XCTAssertGreaterThanOrEqual(file, 0); close(file)
        XCTAssertEqual(try FS.storedName(fd, lookup: Data("한글É.txt".utf8)), raw)
        XCTAssertEqual(try FS.storedName(fd, lookup: Data("한글é.TXT".utf8)), raw)
        XCTAssertEqual(try FS.storedName(fd, lookup: raw), raw)
    }

    func testCycleCancellationRecoveryAndRemap() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let names = ["a.txt", "b.txt", "c.txt"]
        for name in names { try Data(name.utf8).write(to: root.appendingPathComponent(name)) }
        var pipeline = RulePipeline(target: .unchanged)
        pipeline.mapping = NameMapping(rows: names.enumerated().map { .init(source: $0.element, destination: names[($0.offset + 1) % 3]) })
        let entries = try await RulePreview.apply(Scanner.scan(roots: names.map { RawPath(root.appendingPathComponent($0).path) }, recursive: false, token: CancellationToken()).entries, pipeline: pipeline, access: .pro, token: CancellationToken())
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store), token = CancellationToken()
        let partial = try await coordinator.execute(plan, token: token) { _ in token.cancel() }
        XCTAssertEqual(partial.succeeded, 1); XCTAssertEqual(partial.status, "RecoveryNeedsReview")
        let recovery = try History.recovery(store: store, id: plan.id, generation: UUID())
        XCTAssertEqual(recovery.operations.count, 3)
        let restored = try await coordinator.execute(recovery, token: CancellationToken()); XCTAssertEqual(restored.succeeded, 3)
        for name in names { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(name)), Data(name.utf8)) }
        XCTAssertTrue(try History.inspect(store: store, id: plan.id).isEmpty)
        var freshPlan = plan; freshPlan.id = UUID()
        let again = try await coordinator.execute(freshPlan, token: CancellationToken()); XCTAssertEqual(again.succeeded, 3)
        let roots = names.map { RawPath(root.appendingPathComponent($0).path) }
        let moved = try History.remap(roots, store: store, id: freshPlan.id)
        XCTAssertEqual(moved, [roots[1], roots[2], roots[0]])
    }
    func testPairsShareNumberAndPartialSelectionIsBlocked() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let names = ["a.jpg", "a.raw", "b.jpg", "b.raw"]
        for name in names { try Data(name.utf8).write(to: root.appendingPathComponent(name)) }
        var rule = RenameRule(.numbering); rule.text = "_"
        var pipeline = RulePipeline(rules: [rule]); pipeline.pairExtensions = ["jpg","raw"]
        let scan = Scanner.scan(roots: names.map { RawPath(root.appendingPathComponent($0).path) }, recursive: false, token: CancellationToken())
        let entries = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: .pro, token: CancellationToken())
        XCTAssertEqual(Set(entries.map(\.preview)), ["a_001.jpg", "a_001.raw", "b_002.jpg", "b_002.raw"])
        XCTAssertEqual(try Planning.make(entries: entries, selected: [entries[0].id], generation: UUID()).operations.count, 0)
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
        XCTAssertEqual(plan.operations.count, 4)
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let result = try await TransactionCoordinator(store: store).execute(plan, token: CancellationToken()); XCTAssertEqual(result.succeeded, 4)
    }
    func testMetadataSnapshotRejectsContentEditedAfterPreview() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("a.txt"); try Data("a".utf8).write(to: url)
        var rule = RenameRule(.metadata); rule.text = "size"; rule.replacement = "_"
        let scan = Scanner.scan(roots: [RawPath(url.path)], recursive: false, token: CancellationToken())
        let entries = try await RulePreview.apply(scan.entries, pipeline: RulePipeline(rules: [rule]), access: .pro, token: CancellationToken())
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID()); XCTAssertEqual(plan.operations.count, 1)
        let handle = try FileHandle(forWritingTo: url); try handle.write(contentsOf: Data("changed".utf8)); try handle.close()
        XCTAssertTrue(try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID()).operations.isEmpty)
        let store = try JournalStore(root: root.appendingPathComponent("journal"))
        let result = try await TransactionCoordinator(store: store).execute(plan, token: CancellationToken()); XCTAssertEqual(result.succeeded, 0)
        XCTAssertEqual(try Data(contentsOf: url), Data("changed".utf8))
    }
    func testPhotoAndPDFMetadataAreReadWithoutContentChanges() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let imageURL = root.appendingPathComponent("photo.jpg"), pdfURL = root.appendingPathComponent("document.pdf")
        let context = try XCTUnwrap(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage()), destination = try XCTUnwrap(CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:01:02 01:00:00", "OffsetTimeOriginal" as CFString: "+09:00"], kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Fixture Camera"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        var box = CGRect(x: 0, y: 0, width: 100, height: 100)
        let pdf = try XCTUnwrap(CGContext(pdfURL as CFURL, mediaBox: &box, [kCGPDFContextTitle: "Fixture Title", kCGPDFContextAuthor: "Fixture Author"] as CFDictionary))
        pdf.beginPDFPage(nil); pdf.endPDFPage(); pdf.closePDF()
        let originals = try [imageURL, pdfURL].map { try Data(contentsOf: $0) }
        let scan = Scanner.scan(roots: [RawPath(imageURL.path), RawPath(pdfURL.path)], recursive: false, token: CancellationToken())
        let photo = try XCTUnwrap(scan.entries.first { $0.name == "photo.jpg" }), document = try XCTUnwrap(scan.entries.first { $0.name == "document.pdf" })
        let values = try await MetadataReader.read(photo, keys: ["photo.date", "photo.camera"], zone: "UTC")
        XCTAssertEqual(values["photo.camera"], "Fixture Camera"); XCTAssertEqual(values["photo.date"], "2024-01-01")
        let sourceZone = try await MetadataReader.read(photo, keys: ["photo.date"], zone: "source"); XCTAssertEqual(sourceZone["photo.date"], "2024-01-02")
        let doc = try await MetadataReader.read(document, keys: ["document.title", "document.author"])
        XCTAssertEqual(doc["document.title"], "Fixture Title"); XCTAssertEqual(doc["document.author"], "Fixture Author")
        XCTAssertEqual(try [imageURL, pdfURL].map { try Data(contentsOf: $0) }, originals)
    }
    func testRelativeMappingAndAmbiguity() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for folder in ["one", "two"] { let url = root.appendingPathComponent(folder); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); try Data().write(to: url.appendingPathComponent("a.txt")) }
        let scan = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken())
        var pipeline = RulePipeline(); pipeline.mapping = NameMapping(rows: [.init(source: "a.txt", destination: "b.txt")])
        do { _ = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: .pro, token: CancellationToken()); XCTFail() } catch {}
        pipeline.mapping = NameMapping(rows: [.init(source: "one/a.txt", destination: "b.txt")])
        let entries = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: .pro, token: CancellationToken())
        XCTAssertEqual(entries.filter { $0.status.fixable }.count, 1)
    }
    func testFolderEventsQueueWithoutMutationAndFutureStorePreserved() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let changed = expectation(description: "FSEvents delivered"); changed.assertForOverFulfill = false
        let watcher = FolderWatcher(); try watcher.start(path: root.path) { _ in changed.fulfill() }; defer { watcher.stop() }
        let url = root.appendingPathComponent("untouched.txt")
        let writer = Process(); writer.executableURL = URL(fileURLWithPath: "/bin/sh"); writer.arguments = ["-c", "printf original > \"$1\"", "fixture", url.path]
        try writer.run(); writer.waitUntilExit(); XCTAssertEqual(writer.terminationStatus, 0)
        await fulfillment(of: [changed], timeout: 5)
        XCTAssertEqual(try Data(contentsOf: url), Data("original".utf8))
        var config = WatchLibrary(); config.schemaVersion = 99
        let storeURL = root.appendingPathComponent("watch.json"), data = try JSONEncoder().encode(config); try data.write(to: storeURL)
        let store = WatchStore(url: storeURL)
        do { _ = try await store.load(); XCTFail() } catch {}
        do { try await store.save(WatchLibrary()); XCTFail() } catch {}
        XCTAssertEqual(try Data(contentsOf: storeURL), data)
    }
    func testNestedDirectorySwapUndoAndLaterRenameLineage() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for name in ["a", "b"] {
            let directory = root.appendingPathComponent(name); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(name.utf8).write(to: directory.appendingPathComponent("x.txt"))
        }
        var pipeline = RulePipeline(target: .unchanged)
        pipeline.mapping = NameMapping(rows: [.init(source: "a", destination: "b"), .init(source: "b", destination: "a"), .init(source: "a/x.txt", destination: "y.txt"), .init(source: "b/x.txt", destination: "z.txt")])
        let scan = Scanner.scan(roots: [RawPath(root.appendingPathComponent("a").path), RawPath(root.appendingPathComponent("b").path)], recursive: true, token: CancellationToken())
        let entries = try await RulePreview.apply(scan.entries, pipeline: pipeline, access: .pro, token: CancellationToken())
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
        XCTAssertEqual(plan.operations.count, 4)
        let store = try JournalStore(root: root.appendingPathComponent("journal")), coordinator = TransactionCoordinator(store: store)
        let result = try await coordinator.execute(plan, token: CancellationToken()); XCTAssertEqual(result.succeeded, 4)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("b/y.txt")), Data("a".utf8))
        let undo = try History.undo(store: store, id: plan.id, generation: UUID()); XCTAssertEqual(undo.operations.count, 4)
        let reverted = try await coordinator.execute(undo, token: CancellationToken()); XCTAssertEqual(reverted.succeeded, 4)
        for name in ["a", "b"] { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("\(name)/x.txt")), Data(name.utf8)) }
    }
    func testMusicAndVideoMetadataFromGeneratedM4A() async throws {
        guard #available(macOS 15, *) else { throw XCTSkip("Fixture export convenience requires macOS 15; provider remains macOS 14") }
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("silence.caf"), destination = root.appendingPathComponent("tagged.m4a")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4410)); buffer.frameLength = 4410
        if let samples = buffer.floatChannelData { samples[0].initialize(repeating: 0, count: 4410) }
        do { let audio = try AVAudioFile(forWriting: source, settings: format.settings); try audio.write(from: buffer) }
        let export = try XCTUnwrap(AVAssetExportSession(asset: AVURLAsset(url: source), presetName: AVAssetExportPresetAppleM4A))
        export.metadata = [(AVMetadataIdentifier.commonIdentifierTitle, "Fixture Song"), (.commonIdentifierArtist, "Fixture Artist"), (.commonIdentifierAlbumName, "Fixture Album")].map { id, text in
            let item = AVMutableMetadataItem(); item.identifier = id; item.value = text as NSString; item.dataType = "com.apple.metadata.datatype.UTF-8"; return item
        }
        try await export.export(to: destination, as: .m4a)
        let original = try Data(contentsOf: destination)
        let scan = Scanner.scan(roots: [RawPath(destination.path)], recursive: false, token: CancellationToken())
        let entry = try XCTUnwrap(scan.entries.first)
        let values = try await MetadataReader.read(entry, keys: ["music.title", "music.artist", "music.album", "video.duration"])
        XCTAssertEqual(values["music.title"], "Fixture Song"); XCTAssertEqual(values["music.artist"], "Fixture Artist"); XCTAssertEqual(values["music.album"], "Fixture Album"); XCTAssertNotNil(values["video.duration"])
        XCTAssertEqual(try Data(contentsOf: destination), original)
        let token = CancellationToken(); token.cancel()
        do { _ = try await MetadataReader.read(entry, keys: ["music.title"], token: token); XCTFail() } catch { XCTAssertEqual(error as? RuleFailure, .cancelled) }
    }

    func testWatchBaselineSkipsProcessedFilesAndDefersWriters() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let a = root.appendingPathComponent("a.txt"), b = root.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: a); try Data("b".utf8).write(to: b)
        let entries = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: CancellationToken()).entries
        let initial = try await WatchSnapshot.candidates(entries, baseline: [:], token: CancellationToken())
        XCTAssertEqual(initial.count, 2); XCTAssertTrue(initial.allSatisfy { !$0.isDirectory })
        let baseline = Dictionary(uniqueKeysWithValues: initial.map { (WatchSnapshot.key($0.path), WatchedFile(identity: $0.identity!, version: $0.contentVersion!)) })
        var library = WatchLibrary(); let id = UUID(); library.baselines = [id: baseline]
        let storage = WatchStore(url: root.appendingPathComponent("watch.json")); try await storage.save(library)
        let restored = try await storage.load()
        let unchanged = try await WatchSnapshot.candidates(entries, baseline: restored.baselines?[id] ?? [:], token: CancellationToken()); XCTAssertTrue(unchanged.isEmpty)
        let writer = Task { try await Task.sleep(for: .milliseconds(50)); let file = try FileHandle(forWritingTo: a); try file.write(contentsOf: Data("writing".utf8)); try file.close() }
        let unstable = try await WatchSnapshot.candidates(entries, baseline: [:], token: CancellationToken()); try await writer.value
        XCTAssertEqual(unstable.first { $0.name == "a.txt" }?.reason, "WatchWriting")
        let changed = try await WatchSnapshot.candidates(entries, baseline: baseline, token: CancellationToken())
        XCTAssertEqual(changed.count, 1); XCTAssertEqual(changed[0].name, "a.txt")
    }
    func testTIFFHEICAndMP3FieldProviders() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let context = try XCTUnwrap(CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try XCTUnwrap(context.makeImage())
        for (ext, type) in [("tiff", UTType.tiff), ("heic", UTType.heic)] {
            let url = root.appendingPathComponent("image." + ext), destination = try XCTUnwrap(CGImageDestinationCreateWithURL(root.appendingPathComponent("image." + ext) as CFURL, type.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "Fixture Camera"], kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2024:01:02 12:00:00"]] as CFDictionary)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            let entry = try XCTUnwrap(Scanner.scan(roots: [RawPath(url.path)], recursive: false, token: CancellationToken()).entries.first)
            let values = try await MetadataReader.read(entry, keys: ["photo.camera", "photo.date"])
            XCTAssertEqual(values["photo.camera"], "Fixture Camera"); XCTAssertEqual(values["photo.date"], "2024-01-02")
        }
        func frame(_ key: String, _ text: String) -> Data {
            let value = Data([0]) + Data(text.utf8), count = UInt32(value.count)
            return Data(key.utf8) + Data([UInt8((count >> 24) & 255), UInt8((count >> 16) & 255), UInt8((count >> 8) & 255), UInt8(count & 255), 0, 0]) + value
        }
        let tags = frame("TIT2", "Fixture Song") + frame("TPE1", "Fixture Artist") + frame("TALB", "Fixture Album") + frame("TRCK", "3/12")
        let count = tags.count
        var bytes = Data([0x49,0x44,0x33,3,0,0,UInt8((count >> 21) & 127),UInt8((count >> 14) & 127),UInt8((count >> 7) & 127),UInt8(count & 127)]) + tags
        for _ in 0..<100 { bytes += Data([0xff,0xfb,0x90,0]) + Data(repeating: 0, count: 413) }
        let url = root.appendingPathComponent("generated.mp3"); try bytes.write(to: url)
        let entry = try XCTUnwrap(Scanner.scan(roots: [RawPath(url.path)], recursive: false, token: CancellationToken()).entries.first)
        let metadata = try await MetadataReader.read(entry, keys: ["music.title","music.artist","music.album","music.track"])
        XCTAssertEqual(metadata["music.title"], "Fixture Song"); XCTAssertEqual(metadata["music.artist"], "Fixture Artist"); XCTAssertEqual(metadata["music.album"], "Fixture Album"); XCTAssertEqual(metadata["music.track"], "3")
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }
    func testMOVAndMP4DateDurationFields() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for (ext, type) in [("mov", AVFileType.mov), ("mp4", AVFileType.mp4)] {
            let url = root.appendingPathComponent("generated." + ext), writer = try AVAssetWriter(outputURL: root.appendingPathComponent("generated." + ext), fileType: type)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 16, AVVideoHeightKey: 16])
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 16, kCVPixelBufferHeightKey as String: 16])
            let date = AVMutableMetadataItem(); date.identifier = .commonIdentifierCreationDate; date.value = "2024-01-02T12:00:00Z" as NSString; date.dataType = "com.apple.metadata.datatype.UTF-8"
            writer.metadata = [date]; writer.add(input); XCTAssertTrue(writer.startWriting()); writer.startSession(atSourceTime: .zero)
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferCreate(nil,16,16,kCVPixelFormatType_32ARGB,nil,&buffer), kCVReturnSuccess)
            let pixels = try XCTUnwrap(buffer); CVPixelBufferLockBaseAddress(pixels,[])
            memset(CVPixelBufferGetBaseAddress(pixels),0,CVPixelBufferGetBytesPerRow(pixels)*16); CVPixelBufferUnlockBaseAddress(pixels,[])
            for second in 0...1 {
                var wait = 0
                while !input.isReadyForMoreMediaData && wait < 100 { try await Task.sleep(for: .milliseconds(10)); wait += 1 }
                XCTAssertTrue(adaptor.append(pixels, withPresentationTime: CMTime(value: Int64(second), timescale: 1)))
            }
            input.markAsFinished(); await writer.finishWriting(); XCTAssertEqual(writer.status, .completed)
            let original = try Data(contentsOf: url)
            let entry = try XCTUnwrap(Scanner.scan(roots: [RawPath(url.path)], recursive: false, token: CancellationToken()).entries.first)
            let metadata = try await MetadataReader.read(entry, keys: ["video.date", "video.duration"])
            XCTAssertEqual(metadata["video.date"], "2024-01-02"); XCTAssertGreaterThanOrEqual(Int(metadata["video.duration"] ?? "") ?? 0, 1)
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }

    func testRegexPreviewStopsAtFirstTimeout() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        for count in 120...124 { try Data().write(to: root.appendingPathComponent(String(repeating: "a", count: count) + "!.txt")) }
        let entries = Scanner.scan(roots: [RawPath(root.path)], recursive: false, token: CancellationToken()).entries.filter { !$0.isDirectory }
        var rule = RenameRule(.regex); rule.text = "(a+)+$"; rule.replacement = "x"
        let start = Date()
        do { _ = try await RulePreview.apply(entries, pipeline: RulePipeline(rules: [rule]), access: .pro, token: CancellationToken()); XCTFail() }
        catch { XCTAssertEqual(error as? RuleFailure, .regexBudget) }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.3)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 5)
    }

    func testPairMetadataPriorityAndFreshPlanExcludeEntireChangedPair() async throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let jpg = root.appendingPathComponent("photo.jpg"), raw = root.appendingPathComponent("photo.raw")
        try Data("123".utf8).write(to: jpg); try Data("12345".utf8).write(to: raw)
        var rule = RenameRule(.metadata); rule.text = "size"; rule.replacement = "_"
        var pipeline = RulePipeline(rules: [rule]); pipeline.order = .reversePath; pipeline.pairExtensions = ["JPG", "RAW"]
        let scanned = Scanner.scan(roots: [RawPath(jpg.path), RawPath(raw.path)], recursive: false, token: CancellationToken()).entries
        let entries = try await RulePreview.apply(scanned, pipeline: pipeline, access: .pro, token: CancellationToken())
        XCTAssertEqual(Set(entries.map(\.preview)), ["photo_3.jpg", "photo_3.raw"])
        let handle = try FileHandle(forWritingTo: jpg); try handle.write(contentsOf: Data("123456".utf8)); try handle.close()
        let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
        XCTAssertTrue(plan.operations.isEmpty); XCTAssertEqual(plan.excluded, 2)
    }

    func testLegacyJournalReadOnlyAndNewVersionBoundary() throws {
        let root = try fixture(); defer { try? FileManager.default.removeItem(at: root) }
        let store = try JournalStore(root: root), legacy = UUID(), future = UUID(), current = UUID()
        func line(version: Int) throws -> Data {
            let payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": version, "sequence": 0, "previous": "", "date": 0, "state": "Completed"], options: .sortedKeys)
            var envelope = try JSONSerialization.data(withJSONObject: ["payload": payload.base64EncodedString(), "checksum": Durable.hash(payload)], options: .sortedKeys)
            envelope.append(10); return envelope
        }
        let oldBytes = try line(version: 1); try oldBytes.write(to: store.journalURL(legacy))
        XCTAssertTrue(try store.replay(legacy).valid); XCTAssertEqual(try Data(contentsOf: store.journalURL(legacy)), oldBytes)
        try line(version: 99).write(to: store.journalURL(future)); XCTAssertFalse(try store.replay(future).valid)
        let writer = try JournalWriter(url: store.journalURL(current)); try writer.append("TransactionPrepared")
        let replay = try store.replay(current); XCTAssertTrue(replay.valid); XCTAssertEqual(replay.events.first?.schemaVersion, 2)
    }

}
