import XCTest
@testable import NameFixCore

/// Names from the three markets and beyond: what is repaired, what is left alone, and why.
final class GlobalNameTests: XCTestCase {
    private func analysis(_ scalars: String, target: NormalizationTarget = .nfc) -> NormalizationAnalysis { NormalizationAnalysis(raw: Data(scalars.utf8), target: target) }
    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    func testDecomposedNamesAreComposedAcrossScripts() {
        let cases: [(String, String, String)] = [
            ("Hangul jamo", "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}", "한글"),
            ("Hangul without a final", "\u{1100}\u{1161}", "가"),
            ("Latin acute", "cafe\u{301}", "café"),
            ("Latin ring", "A\u{30A}ngstro\u{308}m", "Ångström"),
            ("Latin tilde", "sen\u{303}or", "señor"),
            ("Latin diaeresis", "u\u{308}ber", "über"),
            ("Two marks on one letter", "Vie\u{323}\u{302}t", "Việt"),
            ("Two marks in the other order", "Vie\u{302}\u{323}t", "Việt"),
            ("Horn and acute", "o\u{31B}\u{301}", "ớ"),
            ("Hiragana voiced", "か\u{3099}き\u{3099}", "がぎ"),
            ("Hiragana semi-voiced", "は\u{309A}ひ\u{309A}", "ぱぴ"),
            ("Katakana voiced", "カ\u{3099}イト\u{3099}", "ガイド"),
            ("Katakana semi-voiced", "ハ\u{309A}スホ\u{309A}ート", "パスポート"),
            ("Greek tonos", "α\u{301}", "ά"),
            ("Cyrillic breve", "и\u{306}", "й"),
            ("Angstrom sign", "\u{212B}", "Å"),
            ("Ohm sign", "\u{2126}", "Ω")
        ]
        for (label, stored, wanted) in cases {
            let result = analysis(stored)
            XCTAssertEqual(result.status, .needsNormalization, label)
            XCTAssertEqual(result.proposed, bytes(wanted), label)
            XCTAssertNotEqual(bytes(stored), bytes(wanted), label)
            // Composing is reversible for these: decomposing the result gives canonical decomposition back.
            XCTAssertEqual(analysis(wanted).status, .normal, label)
        }
    }

    func testPartlyComposedNamesAreMixed() {
        XCTAssertEqual(analysis("한\u{1100}\u{1173}\u{11AF}").status, .mixed)
        XCTAssertEqual(analysis("ée\u{301}").status, .mixed)
        XCTAssertEqual(analysis("がき\u{3099}").status, .mixed)
        XCTAssertEqual(analysis("\u{1112}\u{1161}\u{11AB}").status, .needsNormalization, "All decomposed is not mixed")
        XCTAssertEqual(analysis("plain e\u{301}").status, .needsNormalization, "Letters with no composed form do not make a name mixed")
    }

    func testNamesWithNothingToComposeAreLeftAlone() {
        let cases: [(String, String)] = [
            ("ZWJ family", "👨‍👩‍👧‍👦"), ("Skin tone", "👍🏽"), ("Variation selector", "✈️"), ("Keycap", "1️⃣"), ("Flag", "🇰🇷"),
            ("Outside the BMP", "𝒜𠮷"), ("Han", "中文日本語"), ("Leading combining mark", "\u{301}a"), ("Mark with no composed form", "q\u{301}"),
            ("Standalone voiced mark", "か\u{309B}"), ("Hangul compatibility jamo", "ㅎㅏㄴㄱㅡㄹ"), ("Arabic", "العربية"), ("Thai", "ไทย"), ("Devanagari", "हिन्दी")
        ]
        for (label, name) in cases {
            let result = analysis(name)
            XCTAssertEqual(result.status, .normal, label); XCTAssertEqual(result.proposed, bytes(name), label)
        }
    }

    /// Compatibility forms look similar but are different characters. They are shown for
    /// information and never applied: full width, half width, ligatures and circled digits stay.
    func testCompatibilityFormsAreNeverApplied() {
        for name in ["Ａ１ｂ", "ｶﾞｲﾄﾞ", "ﬁle", "①②", "㍿", "ｱ", "²"] {
            for target in [NormalizationTarget.nfc, .nfd] {
                let result = analysis(name, target: target)
                XCTAssertEqual(result.proposed, bytes(target == .nfc ? name.precomposedStringWithCanonicalMapping : name.decomposedStringWithCanonicalMapping), name)
            }
            XCTAssertEqual(analysis(name).status, .normal, name)
            let forms = Dictionary(uniqueKeysWithValues: analysis(name).forms)
            XCTAssertNotEqual(forms["NFKC"], forms["NFC"], "The compatibility form differs and is only displayed: \(name)")
        }
        // Half-width kana with a half-width voiced mark is not a canonical pair either.
        XCTAssertEqual(analysis("ｶﾞ").proposed, bytes("ｶﾞ"))
    }

    /// Old-form characters of personal and place names are separate code points that the
    /// standard forms would replace with look-alike unified characters. They are kept.
    func testCompatibilityIdeographsKeepTheirShape() {
        let shrine = "\u{FA19}\u{FA4C}", takashi = "\u{F9DC}", music = "\u{F914}", supplement = "\u{2F800}"
        XCTAssertNotEqual(Array(shrine.precomposedStringWithCanonicalMapping.unicodeScalars), Array(shrine.unicodeScalars), "The standard form would change them")
        for name in [shrine, takashi, music, supplement, shrine + " 案内.txt"] {
            for target in [NormalizationTarget.nfc, .nfd] where target == .nfc || !name.contains("案") {
                let result = analysis(name, target: target)
                XCTAssertEqual(result.status, .normal, name); XCTAssertEqual(result.proposed, bytes(name), name)
            }
        }
        // The rest of the name is still repaired around them, in both directions.
        let stored = shrine + "カ\u{3099}イト\u{3099} cafe\u{301}.txt"
        let repaired = analysis(stored)
        XCTAssertEqual(repaired.status, .needsNormalization)
        XCTAssertEqual(Array(String(decoding: repaired.proposed, as: UTF8.self).unicodeScalars), Array((shrine + "ガイド café.txt").unicodeScalars))
        XCTAssertEqual(Array(NameForm.decomposed(shrine + "ガ").unicodeScalars), Array((shrine + "カ\u{3099}").unicodeScalars))
        // A mark after a kept character stays with it and is not lost.
        XCTAssertEqual(Array(NameForm.composed(takashi + "\u{301}e\u{301}").unicodeScalars), Array((takashi + "\u{301}é").unicodeScalars))
        // Look-alike signs that are not ideographs are still unified: Å, Ω.
        XCTAssertEqual(NameForm.composed("\u{212B}\u{2126}"), "\u{C5}\u{3A9}")
        XCTAssertFalse(NameForm.kept("神")); XCTAssertTrue(NameForm.kept("\u{FA19}"))
    }

    func testSeparatingIsTheExactOpposite() {
        for (composed, decomposed) in [("한글", "\u{1112}\u{1161}\u{11AB}\u{1100}\u{1173}\u{11AF}"), ("café", "cafe\u{301}"), ("ガイド", "カ\u{3099}イト\u{3099}")] {
            let result = analysis(composed, target: .nfd)
            XCTAssertEqual(result.status, .needsNormalization); XCTAssertEqual(result.proposed, bytes(decomposed))
            XCTAssertEqual(analysis(decomposed, target: .nfd).status, .normal)
        }
        XCTAssertEqual(analysis("👨‍👩‍👧‍👦", target: .nfd).status, .normal)
    }

    func testInvalidBytesAndEquivalentNamesStayDistinct() {
        for raw in [Data([0xFF]), Data([0x66, 0xC3]), Data([0xED, 0xA0, 0x80]), Data([0xF8, 0x88, 0x80, 0x80, 0x80])] {
            let result = NormalizationAnalysis(raw: raw)
            XCTAssertEqual(result.status, .invalidUnicode); XCTAssertEqual(result.proposed, raw, "Invalid bytes are never rewritten")
            XCTAssertFalse(NameRules.valid(raw))
        }
        // Two spellings of one name are different stored names, and both want the same result.
        let composed = RawPath("/folder/é.txt"), decomposed = RawPath("/folder/e\u{301}.txt")
        XCTAssertNotEqual(composed, decomposed); XCTAssertNotEqual(composed.leaf, decomposed.leaf)
        XCTAssertEqual(NormalizationAnalysis(raw: decomposed.leaf).proposed, composed.leaf)
        XCTAssertEqual(Set([composed, decomposed]).count, 2)
    }

    func testGraphemesAreNotSplitWhenTextIsCut() {
        for cluster in ["👨‍👩‍👧‍👦", "🇰🇷", "e\u{301}\u{323}", "\u{1112}\u{1161}\u{11AB}", "👍🏽"] {
            let text = String(repeating: "a", count: 4096 - cluster.utf16.count + 1) + cluster
            let (cut, truncated) = NormalizationAnalysis.clipboard(text)
            XCTAssertTrue(truncated, cluster); XCTAssertFalse(cut.hasSuffix(String(cluster.unicodeScalars.first!)), cluster)
            XCTAssertEqual(cut, String(repeating: "a", count: 4096 - cluster.utf16.count + 1), cluster)
        }
    }

    func testNamesWindowsCannotUseAreReportedAndNothingElse() {
        let flagged: [(String, [String])] = [
            ("report: final.txt", ["WindowsReservedCharacter"]), ("what?.txt", ["WindowsReservedCharacter"]), ("a*b", ["WindowsReservedCharacter"]),
            ("quote\".txt", ["WindowsReservedCharacter"]), ("a<b>.txt", ["WindowsReservedCharacter"]), ("pipe|name", ["WindowsReservedCharacter"]), ("back\\slash", ["WindowsReservedCharacter"]),
            ("notes.", ["WindowsTrailingDotOrSpace"]), ("notes ", ["WindowsTrailingDotOrSpace"]), ("한글 문서. ", ["WindowsTrailingDotOrSpace"]),
            ("CON", ["WindowsReservedName"]), ("con.txt", ["WindowsReservedName"]), ("Nul.tar.gz", ["WindowsReservedName"]), ("COM1", ["WindowsReservedName"]), ("lpt9.log", ["WindowsReservedName"]), ("AUX .txt", ["WindowsReservedName"]),
            ("tab\tname", ["WindowsControlCharacter"]), ("line\nbreak", ["WindowsControlCharacter"]),
            ("PRN?.", ["WindowsReservedCharacter", "WindowsTrailingDotOrSpace"])
        ]
        for (name, issues) in flagged { XCTAssertEqual(NameRules.windowsIssues(bytes(name)), issues, name) }
        let fine = ["report.txt", "한글 문서.hwp", "カ\u{3099}イト\u{3099}.pdf", "café menu.pdf", "CONTACT.txt", "console.log", "COM10.txt", "nul-terminated.c", ".gitignore", "a.b.c", "name (1).txt", "👨‍👩‍👧‍👦.jpg", "#hash & more!.txt"]
        for name in fine { XCTAssertEqual(NameRules.windowsIssues(bytes(name)), [], name) }
        XCTAssertEqual(NameRules.windowsIssues(Data([0xFF])), [], "Invalid bytes are reported by their own status")
        // Reporting is all it does: these are valid names on a Mac.
        for (name, _) in flagged where !name.contains("/") { XCTAssertTrue(NameRules.valid(bytes(name)), name) }
    }
}
