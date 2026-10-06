import XCTest
import Foundation
import Darwin
import NameFixCore
import NameFixRuntime
import NameFixApplication

final class ExpansionPerformanceTests: XCTestCase, @unchecked Sendable {
    func testTenThousandPreviewFiveRuns() async throws {
        guard ProcessInfo.processInfo.environment["NAMEFIX_EXPANSION_PERF"] == "1" else { throw XCTSkip("Opt-in development performance profile") }
        let root = URL(fileURLWithPath: "/private/tmp/namefix-expansion-perf-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: root) }
        let fd = try FS.openDirectory(RawPath(root.path)); defer { close(fd) }
        for i in 0..<10000 { let file = FS.cPath(Data("file-\(i).txt".utf8)) { openat(fd, $0, O_CREAT | O_EXCL | O_WRONLY, 0o600) }; XCTAssertGreaterThanOrEqual(file, 0); close(file) }
        var prefix = RenameRule(.prefix); prefix.text = "Project_"
        let pipeline = RulePipeline(rules: [prefix, RenameRule(.numbering)])
        var samples: [Double] = []
        for run in 1...5 {
            var before = rusage(); getrusage(RUSAGE_SELF, &before)
            let start = Date(), token = CancellationToken()
            let scan = Scanner.scan(roots: [RawPath(root.path)], recursive: true, token: token)
            let scanned = Date()
            let entries = try await RulePreview.apply(scan.entries.filter { !$0.isDirectory }, pipeline: pipeline, access: .free, token: token)
            let previewed = Date()
            let plan = try Planning.make(entries: entries, selected: Set(entries.map(\.id)), generation: UUID())
            let elapsed = Date().timeIntervalSince(start); samples.append(elapsed)
            XCTAssertEqual(plan.operations.count, 10000); XCTAssertEqual(plan.excluded, 0)
            var after = rusage(); getrusage(RUSAGE_SELF, &after)
            let cpu = Double(after.ru_utime.tv_sec - before.ru_utime.tv_sec + after.ru_stime.tv_sec - before.ru_stime.tv_sec) + Double(after.ru_utime.tv_usec - before.ru_utime.tv_usec + after.ru_stime.tv_usec - before.ru_stime.tv_usec) / 1_000_000
            print("EXPANSION_PERF run=\(run) count=10000 scan=\(scanned.timeIntervalSince(start)) preview=\(previewed.timeIntervalSince(scanned)) plan=\(Date().timeIntervalSince(previewed)) total=\(elapsed) cpu=\(cpu) peakBytes=\(after.ru_maxrss)")
        }
        let sorted = samples.sorted(); print("EXPANSION_PERF median=\(sorted[2]) p95_nearest_rank=\(sorted[4]) runs=5 Debug arm64")
    }
}
