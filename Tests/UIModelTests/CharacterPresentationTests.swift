import XCTest
import NameFixCore
@testable import NameFixUIModel

final class CharacterPresentationTests: XCTestCase {
    func testHangulExplainsActualScalarsWithoutChangingName() throws {
        let name = "한글.txt", bytes = Data("한글.txt".utf8)
        let explanation = CharacterPresentation(name)
        XCTAssertEqual(explanation.changes.count, 2)
        let first = try XCTUnwrap(explanation.changes.first)
        XCTAssertEqual(first.before.map(\.glyph), ["ㅎ", "ㅏ", "ㄴ"])
        XCTAssertEqual(first.before.map(\.code), ["U+1112", "U+1161", "U+11AB"])
        XCTAssertEqual(first.after.map(\.glyph), ["한"])
        XCTAssertEqual(first.after.map(\.code), ["U+D55C"])
        XCTAssertEqual(Data(explanation.units.map(\.original).joined().utf8), bytes)
        XCTAssertEqual(Data(name.utf8), bytes)
    }
    func testAccentsJapaneseAndCanonicalVariants() throws {
        for (original, before, after) in [("e\u{301}", ["e", "◌́"], ["é"]), ("か\u{3099}", ["か", "◌゛"], ["が"])] {
            let unit = try XCTUnwrap(CharacterPresentation(original).changes.first)
            XCTAssertEqual(unit.before.map(\.glyph), before); XCTAssertEqual(unit.after.map(\.glyph), after)
        }
        XCTAssertEqual(CharacterPresentation.tokens("\u{3099}").first?.code, "U+3099")
        XCTAssertEqual(CharacterPresentation.tokens("\u{309A}").first?.glyph, "◌゜")
        XCTAssertEqual(CharacterPresentation.statusKey(.needsNormalization, name: "e\u{301}"), "NeedsNormalization")
        XCTAssertEqual(CharacterPresentation.statusKey(.needsNormalization, name: "\u{212B}"), "CanonicalVariant")
        XCTAssertEqual(CharacterPresentation("\u{212B}").changes.first?.after.first?.glyph, "Å")
        XCTAssertEqual(CharacterPresentation.statusKey(.conflict, name: "e\u{301}"), "Conflict")
    }
    func testAlreadyNFCAndCompatibilityCharactersStayUntouched() {
        for text in ["한글.txt", "café.txt", "が.txt", "👨‍👩‍👧‍👦.txt", "①Ａ.txt", "ascii.txt"] {
            let p = CharacterPresentation(text)
            XCTAssertTrue(p.changes.isEmpty)
            XCTAssertEqual(Data(p.units.map(\.original).joined().utf8), Data(text.utf8))
        }
    }
    func testMixedLongNameRetainsEveryCharacterAndMarksOnlyDifferences() {
        let text = "é" + String(repeating: "한", count: 20) + ".txt"
        let p = CharacterPresentation(text)
        XCTAssertEqual(p.changes.count, 20); XCTAssertEqual(p.units.count, 25)
        XCTAssertEqual(p.changes.first?.id, 1)
        XCTAssertEqual(Data(p.units.map(\.original).joined().utf8), Data(text.utf8))
        XCTAssertEqual(Data(p.units.map(\.composed).joined().utf8), Data(text.precomposedStringWithCanonicalMapping.utf8))
    }
    func testCombiningSequencesAndInvisibleScalarsAreExplicit() {
        let tokens = CharacterPresentation.tokens(" \u{200D}\u{202E}\u{301}")
        XCTAssertEqual(tokens.map(\.glyph), ["␠", "U+200D", "U+202E", "◌́"])
        XCTAssertEqual(tokens.map(\.code), ["U+0020", "U+200D", "U+202E", "U+0301"])
        let text = "a" + String(repeating: "\u{301}", count: 50)
        XCTAssertEqual(CharacterPresentation(text).units[0].before.count, 51)
    }
    func testNFDPreviewAndRuleStatusReflectActualOutput() {
        let changes = CharacterPresentation.comparison(original: "한글", proposed: "한글".decomposedStringWithCanonicalMapping)
        XCTAssertEqual(changes.count, 2); XCTAssertEqual(changes[0].after.count, 3); XCTAssertEqual(changes[0].before.count, 1)
        XCTAssertTrue(CharacterPresentation.comparison(original: "한글", proposed: "Project_한글").isEmpty)
        XCTAssertEqual(CharacterPresentation.statusKey(.needsNormalization, name: "한글", reason: "RuleChangeHelp"), "PlannedChange")
        XCTAssertEqual(CharacterPresentation.statusKey(.needsNormalization, name: "한글", reason: "NFDChangeHelp"), "NFDPlannedChange")
        // An item left alone because of where it is says so, instead of looking broken.
        XCTAssertEqual(CharacterPresentation.statusKey(.unsupported, name: "한글", reason: "VolumeReadOnly"), "StatusReadOnly")
        XCTAssertEqual(CharacterPresentation.statusKey(.unsupported, name: "한글", reason: "CloudLocationExcluded"), "StatusCloudExcluded")
        for reason in ["VolumeFATUnsupported", "VolumeNetworkUnsupported", "VolumeFormatUnsupported", "VolumeNormalizationUnsupported"] {
            XCTAssertEqual(CharacterPresentation.statusKey(.unsupported, name: "한글", reason: reason), "StatusDriveExcluded")
        }
        XCTAssertEqual(CharacterPresentation.statusKey(.unsupported, name: "한글", reason: "LinkedPathHelp"), "Unsupported")
        // The folder that was added, or a whole disk: listed, and its own name is simply not a target.
        for reason in ["RootNameExcluded", "VolumeRootExcluded"] { XCTAssertEqual(CharacterPresentation.statusKey(.unsupported, name: "한글", reason: reason), "NotTarget") }
    }

    func testItemsBatchRenameLeavesAloneAreLabelledAsNotTargets() {
        XCTAssertEqual(CharacterPresentation.statusKey(.normal, name: "trip", reason: "FolderExcluded"), "NotTarget")
        XCTAssertEqual(CharacterPresentation.statusKey(.normal, name: ".env", reason: "HiddenExcluded"), "NotTarget")
        XCTAssertEqual(CharacterPresentation.statusKey(.normal, name: "a.txt", reason: "NormalHelp"), "Normal")
    }
}
