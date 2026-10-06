import XCTest
@testable import NameFixCore
final class UnicodeTests: XCTestCase {
    func testCanonicalTrapAcrossScripts() {
        for (source, expected) in [("e\u{301}", "é"), ("\u{1112}\u{1161}\u{11AB}", "한"), ("か\u{3099}", "が"), ("α\u{301}", "ά"), ("o\u{31b}\u{301}", "ớ")] {
            XCTAssertEqual(source, expected)
            let a = NormalizationAnalysis(raw: Data(source.utf8))
            XCTAssertTrue(a.status.fixable); XCTAssertEqual(a.nfc, Data(expected.utf8))
        }
    }
    func testInvalidCompatibilityAndEmoji() {
        XCTAssertEqual(NormalizationAnalysis(raw: Data([0xff])).status, .invalidUnicode)
        for s in ["", "ASCII", "中文", "👨‍👩‍👧‍👦", "✈️", "①", "Ａ"] { XCTAssertEqual(NormalizationAnalysis(raw: Data(s.utf8)).nfc, Data(s.utf8)) }
        XCTAssertEqual(NormalizationAnalysis(raw: Data("ée\u{301}".utf8)).status, .mixed)
    }
    func testNumberingAndNames() {
        for (input, output) in [(".env", ".env (1)"), ("archive.tar.gz", "archive.tar (1).gz"), ("a (1).txt", "a (1) (1).txt")] { XCTAssertEqual(NameRules.numbered(input, directory: false, number: 1), Data(output.utf8)) }
        XCTAssertEqual(NameRules.numbered("a.b", directory: true, number: 1), Data("a.b (1)".utf8))
        for s in ["", ".", "..", "a/b", "a\0b"] { XCTAssertFalse(NameRules.valid(Data(s.utf8))) }
        XCTAssertTrue(NameRules.valid(Data("CON?.txt".utf8)))
    }
    func testRawIdentityAndSingleRemap() {
        XCTAssertNotEqual(RawPath("/é"), RawPath("/e\u{301}"))
        XCTAssertEqual(HistoryPathMap.apply(RawPath("/a/b/c"), moves: [(RawPath("/a"),RawPath("/b")), (RawPath("/a/b"),RawPath("/a/z"))]), RawPath("/a/z/c"))
        XCTAssertEqual(HistoryPathMap.apply(RawPath("/abc"), moves: [(RawPath("/a"),RawPath("/b"))]), RawPath("/abc"))
    }
    func testClipboardGraphemeLimit() {
        let s = String(repeating: "a", count: 4095) + "👨‍👩‍👧‍👦"
        let (text, truncated) = NormalizationAnalysis.clipboard(s)
        XCTAssertTrue(truncated); XCTAssertEqual(text.utf16.count, 4095)
    }
}
