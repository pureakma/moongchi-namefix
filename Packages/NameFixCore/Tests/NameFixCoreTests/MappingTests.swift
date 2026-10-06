import XCTest
@testable import NameFixCore
final class MappingTests: XCTestCase {
    func testQuotedBOMNewlineAndRawSpellingRoundTrip() throws {
        let rows = [["source", "destination"], ["e\u{301},\"a\n.txt", "가.txt"], ["x\r\ny", "z"]]
        let encoded = DelimitedText.encode(rows, spreadsheetSafe: false)
        XCTAssertEqual(try DelimitedText.parse(Data([0xEF, 0xBB, 0xBF]) + encoded), rows)
        XCTAssertEqual(Data(try DelimitedText.parse(encoded)[1][0].utf8), Data(rows[1][0].utf8))
        XCTAssertEqual(try DelimitedText.parse(Data("a\tb\n1\t2\n".utf8), separator: "\t"), [["a","b"],["1","2"]])
    }
    func testMalformedAndAmbiguousMappingsRejected() throws {
        for bad in ["\"unterminated", "\"a\"x,b", "a\"b,c"] { XCTAssertThrowsError(try DelimitedText.parse(Data(bad.utf8))) }
        XCTAssertThrowsError(try NameMapping(rows: [.init(source: "a", destination: "x"), .init(source: "a", destination: "y")]).index())
        XCTAssertThrowsError(try NameMapping(rows: [.init(source: "a", destination: "../x")]).index())
        let map = try NameMapping(rows: [.init(source: "é", destination: "x"), .init(source: "e\u{301}", destination: "y")]).index()
        XCTAssertEqual(map.count, 2)
    }
    func testSpreadsheetSafeExportAndFutureSchema() throws {
        XCTAssertEqual(try DelimitedText.parse(DelimitedText.encode([["=SUM(1)", "@a", "normal"]]))[0], ["'=SUM(1)", "'@a", "normal"])
        var pipeline = RulePipeline(); pipeline.schemaVersion = 99
        XCTAssertThrowsError(try pipeline.validate(access: .pro))
        pipeline.schemaVersion = 1; pipeline.pairExtensions = ["jpg","JPG"]
        XCTAssertThrowsError(try pipeline.validate(access: .pro))
        pipeline.pairExtensions = ["jpg","raw"]
        XCTAssertThrowsError(try pipeline.validate(access: .free))
        XCTAssertNoThrow(try pipeline.validate(access: .pro))
    }
    func testEntitlementExpiryRevocationAndOfflineFailClosed() throws {
        let date = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(Entitlement(state: .active).access(at: date), .pro)
        XCTAssertEqual(Entitlement(state: .active, validUntil: date).access(at: date), .free)
        XCTAssertEqual(Entitlement(state: .revoked).access(at: date), .free)
        XCTAssertEqual(Entitlement(state: .unavailable).access(at: date), .free)
        XCTAssertEqual(Entitlement(state: .active, validUntil: date.addingTimeInterval(1)).access(at: date), .pro)
    }

    func testCSVErrorRowAndCancellation() throws {
        do { _ = try DelimitedText.parse(Data("a,b\n\"bad\"x,y".utf8)); XCTFail() }
        catch let error as DelimitedTextError { XCTAssertEqual(error.row, 2) }
        XCTAssertThrowsError(try DelimitedText.parse(Data("a,b".utf8), cancelled: { true })) { XCTAssertEqual($0 as? RuleFailure, .cancelled) }
    }
    func testExplicitMetadataFallback() throws {
        var rule = RenameRule(.metadata); rule.text = "photo.camera"; rule.replacement = "_"
        XCTAssertThrowsError(try RulePipeline(rules: [rule]).evaluate("photo.jpg", access: .pro))
        rule.metadataFallback = "Unknown"
        XCTAssertEqual(try RulePipeline(rules: [rule]).evaluate("photo.jpg", access: .pro).last?.after, "photo_Unknown.jpg")
    }

}
