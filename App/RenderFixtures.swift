import AppKit
import SwiftUI
import NameFixCore

@MainActor enum RenderFixtures {
    /// Off-screen layout evidence only. Never activates, orders, or operates a user window.
    static func run(output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        for language in ["ko-KR", "en-US", "ja-JP"] {
            for theme in ["dark", "light", "olive", "system"] {
                let model = AppModel(); model.settings.language = language; model.settings.theme = theme; model.ready = true
                let appearance = NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
                app.appearance = appearance
                let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1180,height: 780), styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.appearance = appearance
                let host = NSHostingView(rootView: MainView(model: model).frame(width: 1180, height: 780)); window.contentView = host
                host.frame = NSRect(x: 0, y: 0, width: 1180, height: 780)
                host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "Render", code: 1) }
                host.cacheDisplay(in: host.bounds, to: rep)
                guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "Render", code: 2) }
                try data.write(to: output.appendingPathComponent("\(language)-\(theme)-empty.png"))
                // The nonempty surface must lay out the native virtual table as well.
                if language == "ko-KR" {
                    let names = ["한글 보고서.txt", "cafe\u{301}.txt", "か\u{3099}.txt", "정상 파일.txt"]
                    let rows = names.map { name in let a = NormalizationAnalysis(raw: Data(name.utf8)); return FileEntry(path: RawPath("/fixture/" + name), status: a.status, reason: "ChangeHelp", proposed: a.nfc) }
                    model.entries = rows; model.visible = rows; model.selected = Set(rows.filter { $0.status.fixable }.map(\.id)); model.counts = ["TotalCaption": rows.count, "NeededCaption": 3, "ConflictCaption": 0]
                    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.15)); host.cacheDisplay(in: host.bounds, to: rep)
                    if let data = rep.representation(using: .png, properties: [:]) { try data.write(to: output.appendingPathComponent("\(language)-\(theme)-rows.png")) }
                }
                window.close()
            }
        }
        print("Rendered 16 off-screen layouts; no Finder gestures or window interactions performed")
    }
    static func review(output: URL, characters: Bool = false) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        var count = 0
        func snapshot<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat, dark: Bool) throws {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            NSApp.appearance = appearance
            let frame = NSRect(x: 0, y: 0, width: width, height: height)
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = appearance
            let host = NSHostingView(rootView: view.frame(width: width, height: height)); window.contentView = host; host.frame = frame
            host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "ReviewRender", code: 1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "ReviewRender", code: 2) }
            try data.write(to: output.appendingPathComponent(name + ".png")); window.close(); count += 1
        }
        for language in ["ko-KR", "en-US", "ja-JP"] {
            for theme in ["system", "dark", "light", "olive"] {
                let model = AppModel(); model.settings.language = language; model.settings.theme = theme; model.ready = true
                let dark = theme == "dark" || theme == "system"
                let names = characters ? ["한글 보고서.txt".decomposedStringWithCanonicalMapping, "cafe\u{301}.txt", "か\u{3099}.txt", "é와 e\u{301} 혼합.txt", "정상 한글.txt"] : ["한글 보고서 e\u{301}.txt", "cafe\u{301}.txt", "長い名前の報告書 か\u{3099}.txt", "normal.txt"]
                let rows = names.map { name in let a = NormalizationAnalysis(raw: Data(name.utf8)); return FileEntry(path: RawPath("/fixture/" + name), status: a.status, reason: "ChangeHelp", proposed: a.nfc) }
                model.entries = rows; model.visible = rows; model.selected = Set(rows.filter { $0.status.fixable }.map(\.id))
                model.counts = ["TotalCaption": rows.count, "NeededCaption": rows.filter { $0.status.fixable }.count, "ConflictCaption": 0]
                model.settings.rememberRecentFolders = true
                model.settings.recentFolders = (1...10).map { "/fixture/Recent folder \($0)" }
                try snapshot(MainView(model: model), name: "\(language)-\(theme)-900", width: 900, height: 612, dark: dark)
                if characters {
                    if theme == "olive" {
                        model.focused = rows.first?.id; model.sheet = "inspector"
                        try snapshot(SheetRouter(model: model), name: "\(language)-inspector", width: 680, height: 560, dark: dark)
                        model.sheet = nil
                    }
                    continue
                }
                if theme == "olive" || language == "ko-KR" {
                    model.sheet = "settings"
                    try snapshot(SheetRouter(model: model), name: "\(language)-\(theme)-settings", width: 680, height: 560, dark: dark)
                    model.sheet = nil
                }
                if language == "ko-KR", theme == "olive" || theme == "dark" {
                    try snapshot(MainView(model: model), name: "\(language)-\(theme)-1600", width: 1600, height: 1000, dark: dark)
                }
            }
        }
        print("Rendered \(count) product-review layouts off-screen")
    }

}
