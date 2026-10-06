import XCTest
@testable import NameFixCore
final class RuleTests: XCTestCase {
    func testFreeComposedWorkflowAndGraphemes() throws {
        var prefix = RenameRule(.prefix); prefix.text = "Project_"
        var number = RenameRule(.numbering); number.text = "_"; number.start = 7
        let p = RulePipeline(rules: [RenameRule(.spaces), prefix, number])
        XCTAssertEqual(try p.evaluate("  e\u{301}  photo.jpg").last?.after, "Project_é photo_007.jpg")
        var remove = RenameRule(.removeFirst); remove.position = 1
        XCTAssertEqual(try RulePipeline(rules: [remove]).evaluate("👨‍👩‍👧‍👦photo.txt").last?.after, "photo.txt")
    }
    func testNFDOutputIncludesInsertedText() throws {
        var r = RenameRule(.prefix); r.text = "한"
        let result = try XCTUnwrap(RulePipeline(target: .nfd, rules: [r]).evaluate("é.txt").last?.after)
        XCTAssertEqual(Data(result.utf8), Data("한é.txt".decomposedStringWithCanonicalMapping.utf8))
        XCTAssertNotEqual(Data(result.utf8), Data("한é.txt".utf8))
    }
    func testCapabilitiesAndOverflow() throws {
        var r = RenameRule(.regex); r.text = "(a+)"; r.replacement = "$1x"
        XCTAssertThrowsError(try RulePipeline(rules: [r]).evaluate("a.txt"))
        XCTAssertEqual(try RulePipeline(rules: [r]).evaluate("a.txt", access: .pro).last?.after, "ax.txt")
        var number = RenameRule(.numbering); number.start = Int.max
        XCTAssertThrowsError(try RulePipeline(rules: [number]).evaluate("a", context: RuleContext(index: 1)))
    }
    func testRegexBudgetAndCancellation() throws {
        var r = RenameRule(.regex); r.text = "(a+)+$"; r.replacement = "x"
        let start = Date()
        XCTAssertThrowsError(try RulePipeline(rules: [r]).evaluate(String(repeating: "a", count: 1500) + "!", access: .pro))
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertThrowsError(try RulePipeline(rules: [r]).evaluate("a", access: .pro, cancelled: { true }))
    }
    func testExtensionHiddenFilesAndForms() throws {
        var r = RenameRule(.suffix); r.text = "_new"
        XCTAssertEqual(try RulePipeline(rules: [r]).evaluate(".hidden").last?.after, ".hidden_new")
        XCTAssertEqual(try RulePipeline(rules: [r]).evaluate("archive.tar.gz").last?.after, "archive.tar_new.gz")
        let analysis = NormalizationAnalysis(raw: Data("é".utf8), target: .nfd)
        XCTAssertTrue(analysis.status.fixable)
        XCTAssertEqual(analysis.proposed, Data("e\u{301}".utf8))
        XCTAssertEqual(NormalizationAnalysis(raw: analysis.proposed, target: .nfd).status, .normal)
    }
    func testRuleEditorIdentityPreservesRawTextChanges() {
        var a = RenameRule(.prefix); a.text = "é"
        var b = a; b.text = "e\u{301}"
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, a)
    }

    func testEmptyIntermediateStemKeepsExtensionForMetadataComposition() throws {
        let clear = RenameRule(.setName)
        var date = RenameRule(.metadata); date.text = "photo.date"
        var number = RenameRule(.numbering); number.text = "_"
        let result = try RulePipeline(rules: [clear, date, number]).evaluate("photo.jpg", context: RuleContext(metadata: ["photo.date": "2024-10-04"]), access: .pro)
        XCTAssertEqual(result.last?.after, "2024-10-04_001.jpg")
        var prefix = RenameRule(.prefix); prefix.text = "p_"
        XCTAssertEqual(try RulePipeline(rules: [prefix]).evaluate("file.").last?.after, "p_file.")
    }

}
