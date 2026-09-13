import Foundation

/// Stores launch intent separately from process status. A startup failure must
/// not silently disable the option or downgrade an authenticated listener.
public struct MacProxyServerStartupPreferences {
    private let defaults: UserDefaults
    private static let enabledKey = "proxyShare.independent.enabled"
    private static let authenticationKey = "proxyShare.independent.authenticationRequired"

    public init(defaults: UserDefaults) { self.defaults = defaults }

    public var isEnabled: Bool { defaults.bool(forKey: Self.enabledKey) }
    public var authenticationRequired: Bool { defaults.bool(forKey: Self.authenticationKey) }

    public func enable(authenticationRequired: Bool) {
        defaults.set(authenticationRequired, forKey: Self.authenticationKey)
        defaults.set(true, forKey: Self.enabledKey)
    }

    public func disable() { defaults.set(false, forKey: Self.enabledKey) }
}
