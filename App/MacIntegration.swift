import AppKit
import SwiftUI
import Combine
import ServiceManagement
import UserNotifications
import NameFixRuntime

@MainActor final class MacIntegration: NSObject {
    private var item: NSStatusItem?
    private var observation: AnyCancellable?
    private weak var model: AppModel?
    var reveal: (() -> Void)?
    init(model: AppModel) {
        self.model = model; super.init(); refresh()
        observation = model.objectWillChange.sink { [weak self] _ in Task { @MainActor [weak self] in self?.updateStatus() } }
    }
    private func updateStatus() {
        guard let model else { return }
        item?.button?.toolTip = model.busy ? model.phaseLabel + " · " + model.n(model.scanned) : model.t("MenuBarHelp")
        item?.button?.image = NSImage(systemSymbolName: model.busy ? "arrow.triangle.2.circlepath" : "textformat.abc", accessibilityDescription: "Moongchi NameFix")
    }
    func refresh() {
        guard let model else { return }
        let enabled = UserDefaults.standard.object(forKey: "NameFix.MenuBar") as? Bool ?? true
        if !enabled { if let item { NSStatusBar.system.removeStatusItem(item) }; item = nil; return }
        if item == nil { item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        guard let button = item?.button else { return }
        button.image = NSImage(systemSymbolName: "textformat.abc", accessibilityDescription: "Moongchi NameFix")
        button.toolTip = model.t("MenuBarHelp")
        button.subviews.forEach { $0.removeFromSuperview() }
        let drop = MenuDropTarget(frame: button.bounds); drop.autoresizingMask = [.width, .height]
        drop.receive = { [weak self] urls in self?.model?.add(urls, fromOS: true); self?.reveal?() }
        drop.menuProvider = { [weak self] in self?.makeMenu() ?? NSMenu() }; button.addSubview(drop); updateStatus()
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if let model, model.busy { let status = NSMenuItem(title: model.phaseLabel + " · " + model.n(model.scanned), action: nil, keyEquivalent: ""); status.isEnabled = false; menu.addItem(status); menu.addItem(.separator()) }
        for (key, selector) in [("OpenNameFix", #selector(open)), ("TextTool", #selector(textTool)), ("History", #selector(history)), ("Settings", #selector(settings))] {
            let entry = NSMenuItem(title: model?.t(key) ?? key, action: selector, keyEquivalent: ""); entry.target = self; menu.addItem(entry)
        }
        if let model, model.settings.rememberRecentFolders, !model.settings.recentFolders.isEmpty {
            let recent = NSMenuItem(title: model.t("RecentFolders"), action: nil, keyEquivalent: ""), submenu = NSMenu()
            for path in model.settings.recentFolders {
                submenu.addItem(ActionItem(URL(fileURLWithPath: path).lastPathComponent) { [weak self] in self?.model?.add([URL(fileURLWithPath: path)], fromOS: true); self?.reveal?() })
            }
            recent.submenu = submenu; menu.addItem(recent)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: model?.t("Quit") ?? "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""); quit.target = NSApp; menu.addItem(quit)
        return menu
    }
    @objc private func open() { reveal?() }
    @objc private func textTool() { guard let model, !model.busy else { return }; model.clipboard = ""; model.present("clipboard"); reveal?() }
    @objc private func history() { guard let model, !model.busy else { return }; model.present("history"); reveal?() }
    @objc private func settings() { guard let model, !model.busy else { return }; model.present("settings"); reveal?() }
    func finished(_ summary: TransactionSummary) {
        guard !NSApp.isActive, UserDefaults.standard.bool(forKey: "NameFix.Notifications"), let model else { return }
        let content = UNMutableNotificationContent(); content.title = "Moongchi NameFix"
        content.body = model.t("CompletionNotification", model.n(summary.succeeded), model.n(summary.failed)); content.sound = nil
        let request = UNNotificationRequest(identifier: summary.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak model] error in
            if error != nil { Task { @MainActor in model?.message = "NotificationFailed" } }
        }
    }
}
@MainActor private final class MenuDropTarget: NSView {
    var receive: (([URL]) -> Void)?
    var menuProvider: (() -> NSMenu)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]); setAccessibilityLabel("Moongchi NameFix"); setAccessibilityElement(true); setAccessibilityRole(.menuButton) }
    required init?(coder: NSCoder) { super.init(coder: coder); registerForDraggedTypes([.fileURL]) }
    override func mouseDown(with event: NSEvent) { if let menu = menuProvider?() { NSMenu.popUpContextMenu(menu, with: event, for: self) } }
    override func accessibilityPerformPress() -> Bool { menuProvider?().popUp(positioning: nil, at: .zero, in: self) ?? false }
    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation { sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : [] }
    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { return false }
        receive?(urls); return true
    }
}
struct IntegrationSettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("NameFix.MenuBar") private var menuBar = true
    @AppStorage("NameFix.Notifications") private var notifications = false
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var status = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(model.t("ShowMenuBar"), isOn: $menuBar).onChange(of: menuBar) { _, _ in AppDelegate.shared?.refreshIntegration() }
            Toggle(model.t("LoginLaunch"), isOn: Binding(get: { login }, set: setLogin))
            Text(model.t("LoginLaunchHelp")).font(.caption)
            Toggle(model.t("CompletionAlerts"), isOn: $notifications).onChange(of: notifications) { _, enabled in
                if enabled { Task {
                    do { let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert]); if !granted { notifications = false; status = "NotificationDenied" } }
                    catch { notifications = false; status = "NotificationFailed" }
                } }
            }
            if !status.isEmpty { Text(model.t(status)).font(.caption) }
            if SMAppService.mainApp.status == .requiresApproval { Button(model.t("OpenLoginSettings")) { SMAppService.openSystemSettingsLoginItems() } }
        }.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login = SMAppService.mainApp.status == .enabled }
    }
    private func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; login = SMAppService.mainApp.status == .enabled; status = login == enabled ? "" : "LoginNeedsApproval" }
        catch { login = SMAppService.mainApp.status == .enabled; status = "LoginLaunchFailed" }
    }
}
