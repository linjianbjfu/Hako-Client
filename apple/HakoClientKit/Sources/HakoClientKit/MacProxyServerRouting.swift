import Foundation

public struct MacProxyServerRouting: Codable, Equatable, Sendable {
    public let mode: String
    public let selections: [String: String]
    public let preferredGroup: String?

    public init(mode: String, selections: [String: String], preferredGroup: String? = nil) {
        self.mode = mode
        self.selections = selections
        self.preferredGroup = preferredGroup
    }
}

public struct MacProxyServerRoutingStatus: Codable, Equatable, Sendable {
    public let mode: String
    public let globalSelection: String?
    public let globalProxy: String?

    public init(mode: String, globalSelection: String?, globalProxy: String?) {
        self.mode = mode
        self.globalSelection = globalSelection
        self.globalProxy = globalProxy
    }
}

public struct MacProxyServerControl: Codable, Sendable {
    public let routing: MacProxyServerRouting
    public init(routing: MacProxyServerRouting) { self.routing = routing }
}

public enum MacProxyServerRoutingPolicy {
    public static func resolvedProxy(_ name: String, proxies: [String: [String: Any]]) -> String? {
        var current = name
        var visited = Set<String>()
        while visited.insert(current).inserted, visited.count <= 64 {
            guard let proxy = proxies[current] else { return nil }
            if let members = proxy["all"] as? [String] {
                guard let next = proxy["now"] as? String, members.contains(next) else { return nil }
                current = next
            } else {
                let type = (proxy["type"] as? String ?? "").lowercased()
                guard !["", "direct", "reject", "rejectdrop", "pass", "compatible"].contains(type),
                      !["DIRECT", "REJECT", "REJECT-DROP", "PASS", "COMPATIBLE"].contains(current) else { return nil }
                return current
            }
        }
        return nil
    }

    public static func globalTarget(proxies: [String: [String: Any]], preferredGroup: String?) -> String? {
        guard let global = proxies["GLOBAL"], let members = global["all"] as? [String] else { return nil }
        let candidates = [preferredGroup, global["now"] as? String].compactMap { $0 } + members
        return candidates.first { members.contains($0) && resolvedProxy($0, proxies: proxies) != nil }
    }
}
