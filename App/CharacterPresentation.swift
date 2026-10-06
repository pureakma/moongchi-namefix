import Foundation
import NameFixCore

/// Read-only explanation. Display glyphs must never be used as filesystem names.
struct CharacterToken: Equatable, Sendable {
    let glyph: String
    let code: String
}
struct CharacterUnit: Identifiable, Sendable {
    let id: Int
    let original: String
    let composed: String
    var changed: Bool { Data(original.utf8) != Data(composed.utf8) }
    var before: [CharacterToken] { CharacterPresentation.tokens(original) }
    var after: [CharacterToken] { CharacterPresentation.tokens(composed) }
}
struct CharacterPresentation: Sendable {
    let units: [CharacterUnit]
    init(_ original: String) {
        units = original.enumerated().map { index, character in
            let text = String(character)
            return CharacterUnit(id: index, original: text, composed: text.precomposedStringWithCanonicalMapping)
        }
    }
    var changes: [CharacterUnit] { units.filter(\.changed) }
    static func comparison(original: String, proposed: String) -> [CharacterUnit] {
        guard original == proposed else { return [] } // Canonical equivalence for display only.
        return zip(original, proposed).enumerated().map { index, pair in CharacterUnit(id: index, original: String(pair.0), composed: String(pair.1)) }.filter(\.changed)
    }
    static func statusKey(_ status: EntryStatus, name: String, reason: String? = nil) -> String {
        if reason == "FolderExcluded" || reason == "HiddenExcluded" { return "NotTarget" }
        if status.fixable, reason == "RuleChangeHelp" { return "PlannedChange" }
        if status.fixable, reason == "NFDChangeHelp" { return "NFDPlannedChange" }
        // Non-NFC also includes canonical singleton/reordering cases, not only NFD.
        if status == .needsNormalization && Data(name.utf8) != Data(name.decomposedStringWithCanonicalMapping.utf8) { return "CanonicalVariant" }
        return status.rawValue
    }
    private static let initials = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    private static let vowels = Array("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
    private static let finals = Array("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ")
    static func tokens(_ text: String) -> [CharacterToken] {
        text.unicodeScalars.map { scalar in
            let code = String(format: "U+%04X", scalar.value)
            let glyph: String
            // Modern canonical Hangul jamo get familiar standalone glyphs, while
            // the code label continues to identify the actual original scalar.
            switch scalar.value {
            case 0x1100...0x1112: glyph = String(initials[Int(scalar.value - 0x1100)])
            case 0x1161...0x1175: glyph = String(vowels[Int(scalar.value - 0x1161)])
            case 0x11A8...0x11C2: glyph = String(finals[Int(scalar.value - 0x11A8)])
            case 0x20: glyph = "␠"
            // Kana combining marks can disappear on a dotted-circle glyph in
            // system-font fallback. Use their standalone display equivalents.
            case 0x3099: glyph = "◌゛"
            case 0x309A: glyph = "◌゜"
            default:
                switch scalar.properties.generalCategory {
                case .nonspacingMark, .spacingMark, .enclosingMark: glyph = "◌" + String(scalar)
                case .control, .format, .lineSeparator, .paragraphSeparator, .spaceSeparator: glyph = code
                default: glyph = String(scalar)
                }
            }
            return CharacterToken(glyph: glyph, code: code)
        }
    }
}
