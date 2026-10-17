import XCTest
@testable import NameFixUIModel
import NameFixRuntime

final class LocalizationTests: XCTestCase {
    func testNewInstallFollowsSystemLanguage() {
        XCTAssertEqual(AppSettings().language, "system")
        for (preferred, expected) in [(["ko-KR", "en-US"], "ko"), (["en-GB", "ko-KR"], "en"), (["ja-JP", "en-US"], "ja")] {
            XCTAssertEqual(L10n.language("system", preferredLanguages: preferred), expected)
        }
    }

    func testSystemUsesFirstSupportedPreferenceAndEnglishFallback() {
        XCTAssertEqual(L10n.language("system", preferredLanguages: ["fr-FR", "ja-JP", "en-US"]), "ja")
        XCTAssertEqual(L10n.language("system", preferredLanguages: ["de-DE", "fr-FR"]), "en")
        XCTAssertEqual(L10n.language("system", preferredLanguages: []), "en")
    }

    func testExplicitAppLanguageOverridesSystemPreference() {
        XCTAssertEqual(L10n.language("ko-KR", preferredLanguages: ["ja-JP"]), "ko")
        XCTAssertEqual(L10n.language("en-US", preferredLanguages: ["ko-KR"]), "en")
        XCTAssertEqual(L10n.language("ja-JP", preferredLanguages: ["en-US"]), "ja")
    }
}
