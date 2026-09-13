import Foundation

public struct MacProxyServerRequest: Codable, Sendable {
    public let yaml: String
    public let resourceDirectory: String
    public let port: Int32
    public let username: String
    public let password: String
    public let routing: MacProxyServerRouting?

    public init(yaml: String, resourceDirectory: String, port: Int32, username: String, password: String, routing: MacProxyServerRouting? = nil) {
        self.yaml = yaml
        self.resourceDirectory = resourceDirectory
        self.port = port
        self.username = username
        self.password = password
        self.routing = routing
    }
}

public struct MacProxyServerReply: Codable, Sendable {
    public let status: String?
    public let error: String?
    public let traffic: MacProxyServerTraffic?
    public let routing: MacProxyServerRoutingStatus?

    public init(status: String? = nil, error: String? = nil, traffic: MacProxyServerTraffic? = nil, routing: MacProxyServerRoutingStatus? = nil) {
        self.status = status
        self.error = error
        self.traffic = traffic
        self.routing = routing
    }
}

public struct MacProxyServerTraffic: Codable, Equatable, Sendable {
    public let up: Int64
    public let down: Int64
    public let upTotal: Int64
    public let downTotal: Int64

    public static let zero = MacProxyServerTraffic(up: 0, down: 0, upTotal: 0, downTotal: 0)
}

public enum MacProxyServerConfiguration {
    /// Build a patch instead of serializing the entire configuration. The core's
    /// merge API preserves source ordering, including first-match DNS policies.
    public static func overrideJSON(json: Data, resourceDirectory: URL, workingDirectory: URL, anonymousPort: Int32? = nil) throws -> String {
        guard let root = try JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        var patch: [String: Any] = [
            "tun": ["enable": false, "auto-route": false, "auto-redirect": false],
            "listeners": [], "tunnels": [], "allow-lan": false, "geo-auto-update": false,
            "ss-config": "", "vmess-config": "", "tuic-server": ["enable": false],
            "iptables": NSNull(), "ebpf": NSNull()
        ]
        for key in ["port", "socks-port", "mixed-port", "redir-port", "tproxy-port"] { patch[key] = 0 }
        if let anonymousPort {
            guard (1024...65535).contains(anonymousPort) else { throw CocoaError(.propertyListReadCorrupt) }
            patch["mixed-port"] = anonymousPort
            patch["allow-lan"] = true
            patch["bind-address"] = "*"
            patch["authentication"] = []
            patch["skip-auth-prefixes"] = []
            patch["lan-allowed-ips"] = ["127.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
                                        "169.254.0.0/16", "::1/128", "fc00::/7", "fe80::/10"]
            patch["lan-disallowed-ips"] = []
        }
        for key in ["external-controller", "external-controller-tls", "external-controller-unix",
                    "external-controller-pipe", "external-doh-server", "external-ui", "external-ui-url"] {
            patch[key] = ""
        }
        if root["dns"] is [String: Any] { patch["dns"] = ["listen": ""] }
        for kind in ["proxy-providers", "rule-providers"] {
            guard let providers = root[kind] as? [String: [String: Any]] else { continue }
            var paths: [String: [String: String]] = [:]
            let destination = workingDirectory.appendingPathComponent("provider-resources", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true,
                                                  attributes: [.posixPermissions: 0o700])
            let allowedRoot = resourceDirectory.resolvingSymlinksInPath().standardizedFileURL.path + "/"
            for (index, name) in providers.keys.sorted().enumerated() {
                guard let path = providers[name]?["path"] as? String, !path.isEmpty else { continue }
                let source = (path.hasPrefix("/") ? URL(fileURLWithPath: path) : resourceDirectory.appendingPathComponent(path))
                    .resolvingSymlinksInPath().standardizedFileURL
                // Subscription paths must not become arbitrary local file reads.
                guard source.path.hasPrefix(allowedRoot) else { throw CocoaError(.fileReadNoPermission) }
                let target = destination.appendingPathComponent("\(kind)-\(index)").appendingPathExtension(source.pathExtension)
                if FileManager.default.fileExists(atPath: source.path) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
                    guard attributes[.type] as? FileAttributeType == .typeRegular else { throw CocoaError(.fileReadUnsupportedScheme) }
                    try FileManager.default.copyItem(at: source, to: target)
                    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
                }
                // The core enforces provider containment in its own working dir.
                // Copying also prevents side updates from modifying the VPN's files.
                paths[name] = ["path": target.path]
            }
            if !paths.isEmpty { patch[kind] = paths }
        }
        let data = try JSONSerialization.data(withJSONObject: ["patch": patch], options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
}
