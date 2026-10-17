import Foundation
import AppKit
import SwiftUI
import CoreText

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
    /// The Moongchi site and the address for bug reports and questions.
    static let website = URL(string: "https://moongchi.ailoworks.com")
    static let support = URL(string: "mailto:ailo@ailoworks.com")
    /// Where a newer version is announced. The app opens it in the browser and never contacts it itself.
    /// The Mac App Store edition is updated by the store, so it offers no update check of its own.
}
enum L10n {
    static func language(_ value: String, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if value != "system" { return String(value.prefix(2)) }
        return preferredLanguages.compactMap { let s = String($0.prefix(2)); return ["ko", "en", "ja"].contains(s) ? s : nil }.first ?? "en"
    }
    static func text(_ key: String, language: String, _ args: [String] = []) -> String {
        let lang = self.language(language)
        let bundle = Bundle.main.path(forResource: lang, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        var value = bundle.localizedString(forKey: key, value: key, table: nil)
        // A wording for exactly one, where the catalog has it (key + "One").
        if args.first == "1" { let one = bundle.localizedString(forKey: key + "One", value: "\u{0}", table: nil); if one != "\u{0}" { value = one } }
        for (i, arg) in args.enumerated() { value = value.replacingOccurrences(of: "{\(i)}", with: arg) }
        return value
    }
    static func registerFonts() {
        for name in ["PretendardVariable", "PretendardJPVariable"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }
    static func font(_ language: String, size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        let name = self.language(language) == "ja" ? "PretendardJPVariable-Regular" : "PretendardVariable-Regular"
        return .custom(name, size: size, relativeTo: .body).weight(weight)
    }
}
