import AppKit
import SwiftUI
import Combine
import NameFixCore

@main @MainActor struct NameFixMain {
    static func main() {
        L10n.registerFonts()
        if let flag = CommandLine.arguments.firstIndex(of: "--render-expansion"), CommandLine.arguments.count > flag + 1 {
            do { try ExpansionFixtures.run(output: URL(fileURLWithPath: CommandLine.arguments[flag + 1])); exit(0) }
            catch { print("Expansion render failed:", error); exit(1) }
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-shell"), CommandLine.arguments.count > flag + 1 {
            do { try ShellFixtures.run(output: URL(fileURLWithPath: CommandLine.arguments[flag + 1])); exit(0) }
            catch { print("Shell render failed:", error); exit(1) }
        }
        if CommandLine.arguments.contains("--self-test") {
            let checks = ["ko", "en", "ja"].allSatisfy { L10n.text("WorkspaceTitle", language: $0) != "WorkspaceTitle" }
            let fonts = ["PretendardVariable-Regular", "PretendardJPVariable-Regular"].allSatisfy { NSFont(name: $0, size: 13) != nil }
            print("NameFix arm64 resource startup: locales=\(checks) fonts=\(fonts)")
            exit(checks && fonts ? 0 : 1)
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-responsive"), CommandLine.arguments.count > flag + 1 {
            do { try ResponsiveFixtures.run(output: URL(fileURLWithPath: CommandLine.arguments[flag + 1])); exit(0) }
            catch { print("Responsive render failed:", error); exit(1) }
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-characters"), CommandLine.arguments.count > flag + 1 {
            do { try RenderFixtures.review(output: URL(fileURLWithPath: CommandLine.arguments[flag + 1]), characters: true); exit(0) }
            catch { print("Character render failed:", error); exit(1) }
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-review"), CommandLine.arguments.count > flag + 1 {
            do { try RenderFixtures.review(output: URL(fileURLWithPath: CommandLine.arguments[flag + 1])); exit(0) }
            catch { print("Review render failed:", error); exit(1) }
        }
        if let flag = CommandLine.arguments.firstIndex(of: "--render-fixtures"), CommandLine.arguments.count > flag + 1 {
            do { try RenderFixtures.run(output: URL(fileURLWithPath: CommandLine.arguments[flag + 1])); exit(0) }
            catch { print("Off-screen render failed:", error); exit(1) }
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?
    let model = AppModel()
    private var window: NSWindow?
    private var integration: MacIntegration?
    private var windowChrome: WindowChrome?
    private var sidebarController: MainSidebarController?
    private var observation: AnyCancellable?
    private var lastLanguage = ""
    private var lastTheme = ""
    private var quitting = false
    private let placementStore = WindowPlacementStore()
    private var placementSave: Task<Void, Never>?
    private var fullScreenTransition = false
    private var adjustingScreen = false
    private var normalPlacement: WindowPlacement?
    private func screenArea(_ screen: NSScreen) -> ScreenArea {
        ScreenArea(id: (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue ?? "main", visibleFrame: screen.visibleFrame)
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.minSize = .zero; window.title = "Moongchi NameFix"; window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false; window.delegate = self
        let split = MainSidebarController(model: model); sidebarController = split
        window.contentViewController = split
        let chrome = WindowChrome(model: model); chrome.install(on: window, split: split); windowChrome = chrome
        self.window = window
        let screens = NSScreen.screens.map(screenArea)
        if let frame = WindowLayout.restored(placementStore.load(), screens: screens, preferredID: NSScreen.main.map { screenArea($0).id }) { window.setFrame(frame, display: false) }
        applyAppearance(); buildMenus(); window.makeKeyAndOrderFront(nil)
        savePlacement()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.servicesProvider = self
        observation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.applyAppearance() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        integration = MacIntegration(model: model)
        integration?.reveal = { [weak self] in self?.window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
        model.transactionFinished = { [weak self] summary in self?.integration?.finished(summary) }
        Task { await model.start() }
    }
    func refreshIntegration() { integration?.refresh() }
    private func savePlacement() {
        guard let window, !fullScreenTransition, !adjustingScreen, !window.styleMask.contains(.fullScreen), !window.isMiniaturized,
              let screen = window.screen ?? NSScreen.main else { return }
        let area = screenArea(screen)
        let value = WindowPlacement(frame: window.frame, screenID: area.id, screenFrame: area.visibleFrame)
        normalPlacement = value; placementStore.save(value)
    }
    private func schedulePlacementSave() {
        placementSave?.cancel()
        guard !fullScreenTransition else { return }
        placementSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            self?.savePlacement()
        }
    }
    func windowDidResize(_ notification: Notification) { sidebarController?.fit(width: window?.frame.width ?? 1180); schedulePlacementSave() }
    func windowDidMove(_ notification: Notification) { schedulePlacementSave() }
    func windowDidEndLiveResize(_ notification: Notification) { placementSave?.cancel(); savePlacement() }
    func windowWillEnterFullScreen(_ notification: Notification) { savePlacement(); fullScreenTransition = true; placementSave?.cancel() }
    func windowDidEnterFullScreen(_ notification: Notification) { fullScreenTransition = false }
    func windowWillExitFullScreen(_ notification: Notification) { fullScreenTransition = true; placementSave?.cancel() }
    func windowDidExitFullScreen(_ notification: Notification) { fullScreenTransition = false; screensChanged() }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) { fullScreenTransition = false; savePlacement() }
    func windowDidFailToExitFullScreen(_ window: NSWindow) { fullScreenTransition = false }
    @objc private func screensChanged() {
        guard let window, !fullScreenTransition, !window.styleMask.contains(.fullScreen), !window.isMiniaturized else { return }
        placementSave?.cancel(); adjustingScreen = true
        let saved = normalPlacement ?? placementStore.load()
        if let frame = WindowLayout.restored(saved, screens: NSScreen.screens.map(screenArea), preferredID: NSScreen.main.map { screenArea($0).id }) {
            window.setFrame(frame, display: true)
        }
        adjustingScreen = false; savePlacement()
    }
    @objc private func woke() { model.restartWatches(); if !model.busy, model.plan == nil { model.scan() } }
    private func applyAppearance() {
        if lastTheme != model.settings.theme {
            lastTheme = model.settings.theme
            NSApp.appearance = lastTheme == "system" ? nil : NSAppearance(named: lastTheme == "dark" ? .darkAqua : .aqua)
            window?.appearance = NSApp.appearance
            window?.backgroundColor = NSColor(Palette(lastTheme, systemDark: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua).canvas)
        }
        if lastLanguage != model.settings.language { lastLanguage = model.settings.language; buildMenus(); integration?.refresh() }
    }
    func pick(folders: Bool) {
        guard model.canInput else { model.message = "BusyDropRejected"; return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = folders; panel.canChooseFiles = !folders; panel.allowsMultipleSelection = true; panel.resolvesAliases = false
        if let window { panel.beginSheetModal(for: window) { [weak self] response in if response == .OK { self?.model.add(panel.urls) } } }
    }
    func application(_ application: NSApplication, open urls: [URL]) { model.add(urls, fromOS: true); window?.makeKeyAndOrderFront(nil) }
    @objc func inspectNames(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { error.pointee = model.t("NoInputs") as NSString; return }
        model.add(urls, fromOS: true); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { window?.makeKeyAndOrderFront(nil); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitting { return .terminateNow }
        placementSave?.cancel(); savePlacement()
        quitting = true; model.message = "CancelBeforeClose"
        Task { await model.shutdown(); NSApp.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { placementSave?.cancel(); savePlacement(); if model.busy { model.message = "CancelBeforeClose"; model.cancel(); return false }; return true }
    private func buildMenus() {
        let main = NSMenu()
        func menu(_ title: String) -> NSMenu { let item = NSMenuItem(title: title, action: nil, keyEquivalent: ""); let sub = NSMenu(title: title); item.submenu = sub; main.addItem(item); return sub }
        let app = menu("Moongchi NameFix")
        app.addItem(ActionItem(model.t("About")) { [weak self] in self?.model.sheet = "about" })
        app.addItem(ActionItem(model.t("Settings"), key: ",") { [weak self] in self?.model.sheet = "settings" })
        let services = NSMenuItem(title: model.t("Services"), action: nil, keyEquivalent: ""); services.submenu = NSMenu(title: model.t("Services")); app.addItem(services); NSApp.servicesMenu = services.submenu
        app.addItem(.separator()); app.addItem(NSMenuItem(title: model.t("Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let file = menu(model.t("FileMenu"))
        file.addItem(ActionItem(model.t("AddFiles"), key: "o") { [weak self] in self?.pick(folders: false) })
        let folder = ActionItem(model.t("AddFolders"), key: "O") { [weak self] in self?.pick(folders: true) }; folder.keyEquivalentModifierMask = [.command, .shift]; file.addItem(folder)
        file.addItem(ActionItem(model.t("Rescan"), key: "r") { [weak self] in self?.model.scan() })
        let edit = menu(model.t("EditMenu"))
        for (title, key, action) in [("MenuUndo", "z", "undo:"), ("MenuRedo", "Z", "redo:"), ("MenuCut", "x", "cut:"), ("MenuCopy", "c", "copy:"), ("MenuPaste", "v", "paste:"), ("MenuSelectAll", "a", "selectAll:")] { edit.addItem(NSMenuItem(title: model.t(title), action: Selector(action), keyEquivalent: key)) }
        let view = menu(model.t("ViewMenu"))
        view.addItem(ActionItem(model.t("Search"), key: "f") { [weak self] in self?.model.searchFocus = true })
        view.addItem(ActionItem(model.t("Inspector")) { [weak self] in self?.model.sheet = "inspector" })
        view.addItem(ActionItem(model.t("ToggleSidebar")) { [weak self] in self?.sidebarController?.toggleSidebar(nil) })
        view.addItem(ActionItem(model.t("HistoryShort")) { [weak self] in self?.model.sheet = "history"; Task { await self?.model.reloadHistory() } })
        view.addItem(ActionItem(model.t("ClipboardInspect")) { [weak self] in self?.model.inspectClipboard() })
        view.addItem(ActionItem(model.t("Rules"), key: "k") { [weak self] in guard self?.model.busy == false, self?.model.plan == nil else { return }; self?.model.openWorkbench() })
        view.addItem(ActionItem(model.t("FolderWatch")) { [weak self] in guard self?.model.busy == false, self?.model.plan == nil else { return }; self?.model.sheet = "watch" })
        let help = menu(model.t("HelpMenu")); help.addItem(ActionItem(model.t("HelpTitle")) { [weak self] in self?.model.sheet = "help" })
        NSApp.mainMenu = main
    }
}
@MainActor final class ActionItem: NSMenuItem {
    private var handler: (() -> Void)? = nil
    init(_ title: String, key: String = "", action: @escaping () -> Void) { handler = action; super.init(title: title, action: #selector(run), keyEquivalent: key); target = self }
    required init(coder: NSCoder) { super.init(coder: coder) }
    @objc func run() { handler?() }
}
@MainActor final class DropHostingView<Content: View>: NSHostingView<Content> {
    weak var model: AppModel?
    required init(rootView: Content) { super.init(rootView: rootView); registerForDraggedTypes([.fileURL]) }
    @MainActor required dynamic init?(coder: NSCoder) { nil }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        if model?.settings.theme == "system" { window?.backgroundColor = NSColor(Palette("system", systemDark: effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua).canvas) }
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let model, model.canInput, urls(sender).isEmpty == false else { return [] }; model.dragActive = true; return .copy
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { model?.dragActive = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { model?.canInput == true }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        model?.dragActive = false
        guard let model, model.canInput else { model?.message = "BusyDropRejected"; return false }
        let values = urls(sender); guard !values.isEmpty else { return false }; model.add(values); return true
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { model?.dragActive = false }
    private func urls(_ sender: NSDraggingInfo) -> [URL] { (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? [] }
}
