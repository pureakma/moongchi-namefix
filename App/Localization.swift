import Foundation
import AppKit
import SwiftUI
import CoreText

enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
    static let developer = "아일로"
    /// The developer card shows these rows only once the addresses are set.
    static let website: URL? = nil
    static let support: URL? = nil
}
enum L10n {
    static func language(_ value: String) -> String {
        if value != "system" { return String(value.prefix(2)) }
        return Locale.preferredLanguages.compactMap { let s = String($0.prefix(2)); return ["ko", "en", "ja"].contains(s) ? s : nil }.first ?? "en"
    }
    static func text(_ key: String, language: String, _ args: [String] = []) -> String {
        let lang = self.language(language)
        let bundle = Bundle.main.path(forResource: lang, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        var value = bundle.localizedString(forKey: key, value: key, table: nil)
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
