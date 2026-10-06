import Foundation
import Darwin
import NameFixCore
public enum AppTheme: String, CaseIterable, Sendable {
    case system, dark, light, olive
    public var titleKey: String {
        switch self { case .system: "System"; case .dark: "Dark"; case .light: "Light"; case .olive: "OliveArchive" }
    }
}
public struct AppSettings: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var platform = "macOS"
    public var language = "system"
    public var theme = "olive"
    public var recursive = true
    public var hideNormal = false
    public var clearSelectionAfterRun = true
    public var historyLimit = 100
    public var diagnostics = true
    public var rememberRecentFolders = false
    public var recentFolders: [String] = []
    public var workbenchEnabled: Bool? = nil // Optional for existing schema-1 settings.
    public var compactRows = false
    public var nameColumnRatio = 50.0
    public init() {}
    public var valid: Bool { schemaVersion == 1 && platform == "macOS" && ["system", "ko-KR", "en-US", "ja-JP"].contains(language) && ["dark", "light", "olive", "system"].contains(theme) && (1...1000).contains(historyLimit) && nameColumnRatio.isFinite && (25...75).contains(nameColumnRatio) && recentFolders.count <= 10 }
}
public actor SettingsStore {
    public let url: URL
    private var readOnly = false
    public init(url: URL) { self.url = url }
    public func load() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppSettings() }
        let data = try Data(contentsOf: url)
        if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let version = object["schemaVersion"] as? Int, version > 1 { readOnly = true; throw FSError("NewerSchema") }
        do { let s = try JSONDecoder().decode(AppSettings.self, from: data); guard s.valid else { throw FSError("SettingsWarning") }; return s }
        catch {
            // Preserve exact corrupt bytes before restoring writable defaults.
            let backup = url.appendingPathExtension("corrupt-\(UUID().uuidString)")
            let fd = open(backup.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { readOnly = true; throw FSError("SettingsWarning") }
            defer { close(fd) }
            do { try Durable.writeAll(fd, data); try Durable.sync(fd); try Durable.atomic(AppSettings(), to: url) }
            catch { readOnly = true; throw FSError("SettingsWarning") }
            throw FSError("SettingsWarning")
        }
    }
    public func save(_ settings: AppSettings) throws {
        guard !readOnly, settings.valid else { throw FSError(readOnly ? "SettingsWarning" : "SettingsSaveFailed") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        do { try Durable.atomic(settings, to: url) } catch { throw FSError("SettingsSaveFailed") }
    }
}
public final class AccessLease {
    private let url: URL
    private let scoped: Bool
    public init(_ url: URL) { self.url = url; scoped = url.startAccessingSecurityScopedResource() }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}
