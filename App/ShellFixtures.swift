import AppKit
import SwiftUI
import NameFixCore

@MainActor enum ShellFixtures {
    static func run(output: URL) throws {
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        NSApplication.shared.setActivationPolicy(.prohibited)
        var count = 0
        func capture(_ host: NSView, _ name: String) throws {
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "ShellRender", code: 1) }
            host.cacheDisplay(in: host.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "ShellRender", code: 2) }
            try data.write(to: output.appendingPathComponent(name + ".png")); count += 1
        }
        for lang in ["ko-KR", "en-US", "ja-JP"] {
            let model = AppModel(dataRoot: output.appendingPathComponent("isolated-support/\(lang)")); model.ready = true; model.settings.language = lang
            guard model.settings.theme == "olive" else { throw NSError(domain: "DefaultTheme", code: 1) }
            NSApp.appearance = NSAppearance(named: .aqua)
            for size in [CGSize(width: 1180, height: 720), CGSize(width: 600, height: 600), CGSize(width: 320, height: 560)] {
                let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.title = "Moongchi NameFix"; window.titlebarAppearsTransparent = true
                window.backgroundColor = NSColor(Palette(model.settings.theme, systemDark: false).canvas)
                let host = NSHostingView(rootView: MainView(model: model)); host.sizingOptions = []
                window.contentView = host
                let chrome = WindowChrome(model: model); chrome.install(on: window); window.setContentSize(size)
                RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                let actions = chrome.toolbar.items.filter { $0.itemIdentifier != .flexibleSpace }
                guard actions.count == 3, window.titleVisibility == .hidden, actions.first?.isEnabled == false else { throw NSError(domain: "ToolbarContract", code: 1) }
                model.roots = [RawPath("/fixture")]; chrome.refresh()
                guard actions.first?.isEnabled == true else { throw NSError(domain: "ToolbarContract", code: 2) }
                model.phase = "ActivityScan"; chrome.refresh()
                guard actions.first?.isEnabled == false else { throw NSError(domain: "ToolbarContract", code: 3) }
                model.phase = ""; model.roots = []; chrome.refresh()
                guard let frame = window.contentView?.superview else { throw NSError(domain: "ShellRender", code: 3) }
                try capture(frame, "\(lang)-window-\(Int(size.width))")
                print("Native titlebar height: \(window.frame.height - window.contentLayoutRect.height)pt at \(Int(size.width))pt width")
                // Dispatch a button on this unshown fixture only; never a user window.
                window.contentView = NSView(frame: CGRect(origin: .zero, size: size))
                (actions.last?.view as? NSButton)?.performClick(nil)
                guard model.sheet == "settings" else { throw NSError(domain: "ToolbarContract", code: 4) }
                model.sheet = nil
                window.close()
            }
            for theme in ["olive", "system", "dark", "light"] {
                model.settings.theme = theme; model.sheet = "settings"
                let dark = theme == "dark" || theme == "system"
                NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                for width in [640, 320] {
                    let size = CGSize(width: width, height: width == 320 ? 430 : 560)
                    let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false); window.isReleasedWhenClosed = false
                    let host = NSHostingView(rootView: SheetRouter(model: model, availableSize: CGSize(width: size.width + 24, height: size.height + 24)).frame(width: size.width, height: size.height)); host.sizingOptions = []
                    window.contentView = host; host.frame = CGRect(origin: .zero, size: size)
                    host.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                    let name = "\(lang)-settings-\(theme)-\(width)"
                    try capture(host, name)
                    if theme == "olive", width == 640 {
                        model.settings.theme = "dark"; NSApp.appearance = NSAppearance(named: .darkAqua)
                        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
                        try capture(host, "\(lang)-settings-live-theme")
                        model.settings.theme = theme; NSApp.appearance = NSAppearance(named: .aqua)
                        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                    }
                    if theme == "olive", width == 320 {
                        model.message = "SettingsSaveFailed"
                        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                        try capture(host, "\(lang)-settings-save-error")
                        model.message = nil
                    }
                    if width == 320 {
                        func scrolls(_ view: NSView) -> [NSScrollView] { ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrolls) }
                        if let scroll = scrolls(host).filter({ ($0.documentView?.bounds.height ?? 0) > $0.contentView.bounds.height + 100 }).max(by: { ($0.documentView?.bounds.height ?? 0) < ($1.documentView?.bounds.height ?? 0) }), let doc = scroll.documentView {
                            scroll.contentView.scroll(to: CGPoint(x: 0, y: doc.bounds.height - scroll.contentView.bounds.height)); scroll.reflectScrolledClipView(scroll.contentView)
                            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                        }
                        try capture(host, name + "-bottom")
                    }
                    window.close()
                }
            }
        }
        print("PASS: \(count) shell/settings renders; native toolbar actions, disabled states, hidden title and Olive default verified")
    }
}
