import AppKit
import SwiftUI
import ServiceManagement
import UserNotifications
import NameFixRuntime

/// What the app asks of macOS around its own window: a notice when an operation finished while
/// another app was in front. The app has no icon in the menu bar (D-041).
@MainActor final class MacIntegration: NSObject {
    private weak var model: AppModel?
    init(model: AppModel) { self.model = model; super.init() }
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
struct IntegrationSettingsView: View {
    @ObservedObject var model: AppModel
    @AppStorage("NameFix.Notifications") private var notifications = false
    @State private var login = SMAppService.mainApp.status == .enabled
    @State private var status = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("LoginLaunch", Binding(get: { login }, set: setLogin))
            Text(model.t("LoginLaunchHelp")).font(.caption)
            row("CompletionAlerts", $notifications).onChange(of: notifications) { _, enabled in
                if enabled { Task {
                    do { let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert]); if !granted { notifications = false; status = "NotificationDenied" } }
                    catch { notifications = false; status = "NotificationFailed" }
                } }
            }
            if !status.isEmpty { Text(model.t(status)).font(.caption) }
            if SMAppService.mainApp.status == .requiresApproval { HStack { Spacer(minLength: 0); Button(model.t("OpenLoginSettings")) { SMAppService.openSystemSettingsLoginItems() } } }
        }.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login = SMAppService.mainApp.status == .enabled }
    }
    /// Same row as the other settings: name on the left, switch at the right edge.
    private func row(_ key: String, _ isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(model.t(key)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Toggle(model.t(key), isOn: isOn).labelsHidden().fixedSize()
        }
    }
    private func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; login = SMAppService.mainApp.status == .enabled; status = login == enabled ? "" : "LoginNeedsApproval" }
        catch { login = SMAppService.mainApp.status == .enabled; status = "LoginLaunchFailed" }
    }
}
