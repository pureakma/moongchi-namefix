import Foundation

/// Only a verified purchase adapter may produce an active entitlement in production.
/// Transport errors must not invent a grant or extend an existing expiry.
public struct Entitlement: Codable, Equatable, Sendable {
    public enum State: String, Codable, Sendable { case free, active, revoked, unavailable }
    public var state: State
    public var validUntil: Date?
    public init(state: State, validUntil: Date? = nil) { self.state = state; self.validUntil = validUntil }
    public func access(at date: Date = Date()) -> ProductAccess {
        guard state == .active, validUntil.map({ date < $0 }) ?? true else { return .free }; return .pro
    }
}
public protocol EntitlementProvider: Sendable { func verifiedEntitlement() async throws -> Entitlement }
public struct UnconfiguredEntitlementProvider: EntitlementProvider {
    public init() {}
    public func verifiedEntitlement() async throws -> Entitlement { Entitlement(state: .unavailable) }
}
#if DEBUG
public struct DevelopmentEntitlementProvider: EntitlementProvider {
    public var enabled: Bool
    public init(enabled: Bool) { self.enabled = enabled }
    public func verifiedEntitlement() async throws -> Entitlement { Entitlement(state: enabled ? .active : .free) }
}
#endif
