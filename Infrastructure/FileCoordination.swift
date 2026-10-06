import Foundation
import NameFixCore

/// Coordinates cooperating macOS writers. Raw descriptor-relative identity checks
/// remain authoritative; coordination cannot exclude writers that bypass it.
public enum FileCoordination {
    public static func url(_ path: RawPath) -> URL {
        FS.cPath(path.bytes) { URL(fileURLWithFileSystemRepresentation: $0, isDirectory: false, relativeTo: nil) }
    }

    public static func move<T>(from: RawPath, to: RawPath, token: CancellationToken,
                               timeout: TimeInterval = 15,
                               accessor: (NSFileCoordinator) throws -> T) throws -> T {
        guard !token.cancelled else { throw FSError("Cancelled") }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        let wait = CoordinationWait(coordinator)
        let registration = token.onCancel { wait.cancel() }
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { wait.cancel() }; timer.resume()
        defer { timer.cancel(); token.removeCancellationHandler(registration) }
        var error: NSError?, result: Result<T, Error>?
        let source = url(from), destination = url(to)
        coordinator.coordinate(writingItemAt: source, options: .forMoving,
                               writingItemAt: destination, options: .forReplacing, error: &error) { actualSource, actualDestination in
            timer.cancel()
            result = Result {
                guard wait.beginAccess(), !token.cancelled else { throw FSError(token.cancelled ? "Cancelled" : "FileCoordinationFailed") }
                // A presenter may have moved a path while we waited. Do not
                // silently extend the user's approved plan to another location.
                guard Data(actualSource.absoluteString.utf8) == Data(source.absoluteString.utf8),
                      Data(actualDestination.absoluteString.utf8) == Data(destination.absoluteString.utf8) else { throw FSError("SourceChanged") }
                return try accessor(coordinator)
            }
        }
        if let result { return try result.get() }
        throw FSError(token.cancelled ? "Cancelled" : "FileCoordinationFailed", Int32(error?.code ?? 0))
    }
}

// NSFileCoordinator.cancel is explicitly safe from another thread. All other
// coordinator use stays on the transaction executor; the lock arbitrates timeout
// versus entry to the accessor, so an expired wait never starts a mutation.
private final class CoordinationWait: @unchecked Sendable {
    private let coordinator: NSFileCoordinator
    private let lock = NSLock()
    private var waiting = true
    private var cancelled = false
    init(_ coordinator: NSFileCoordinator) { self.coordinator = coordinator }
    func cancel() {
        lock.lock()
        guard waiting else { lock.unlock(); return }
        cancelled = true; lock.unlock(); coordinator.cancel()
    }
    func beginAccess() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return false }; waiting = false; return true
    }
}
