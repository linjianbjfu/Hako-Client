import Foundation
import Testing
@testable import HakoClientKit
#if os(macOS)
import Darwin
#endif

@Test func serverModeDisablesTUNAndOtherListeners() throws {
    let input: [String: Any] = [
        "tun": ["enable": true, "auto-route": true, "auto-redirect": true],
        "port": 8080, "socks-port": 1080, "mixed-port": 7890, "redir-port": 7891, "tproxy-port": 7892,
        "allow-lan": true, "listeners": [["type": "mixed", "port": 9000]],
        "tunnels": ["tcp,127.0.0.1:6553,1.1.1.1:53,DIRECT"],
        "ss-config": "example", "vmess-config": "example", "tuic-server": ["enable": true],
        "external-controller": "0.0.0.0:9090", "external-controller-unix": "/tmp/control.sock",
        "dns": ["enable": true, "listen": "0.0.0.0:53", "nameserver": ["1.1.1.1"]],
        "rules": ["MATCH,REJECT"], "proxies": [["name": "example", "type": "direct"]]
    ]
    let output = try MacProxyServerConfiguration.overrideJSON(
        json: JSONSerialization.data(withJSONObject: input), resourceDirectory: URL(fileURLWithPath: "/profiles"), workingDirectory: URL(fileURLWithPath: "/server")
    )
    let envelope = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
    let root = try #require(envelope["patch"] as? [String: Any])
    #expect((root["tun"] as? [String: Bool])?.values.allSatisfy { !$0 } == true)
    for key in ["port", "socks-port", "mixed-port", "redir-port", "tproxy-port"] { #expect(root[key] as? Int == 0) }
    #expect((root["listeners"] as? [Any])?.isEmpty == true)
    #expect((root["tunnels"] as? [Any])?.isEmpty == true)
    for key in ["external-controller", "external-controller-unix", "ss-config", "vmess-config"] {
        #expect(root[key] as? String == "")
    }
    #expect((root["tuic-server"] as? [String: Bool])?["enable"] == false)
    #expect((root["dns"] as? [String: Any])?["listen"] as? String == "")
    #expect((root["dns"] as? [String: Any])?["nameserver"] == nil)
    #expect(root["rules"] == nil)
    #expect(root["proxies"] == nil)
}

@Test func serverModeCopiesProvidersIntoItsOwnWorkingDirectory() throws {
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let resources = temporary.appendingPathComponent("resources")
    let working = temporary.appendingPathComponent("server")
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let source = resources.appendingPathComponent("nodes.yaml")
    try Data("proxies: []".utf8).write(to: source)
    let input = "{\"proxy-providers\":{\"local\":{\"path\":\"nodes.yaml\"}}}"
    let output = try MacProxyServerConfiguration.overrideJSON(json: Data(input.utf8), resourceDirectory: resources, workingDirectory: working)
    #expect(!output.contains("\\/"))
    let envelope = try #require(JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
    let root = try #require(envelope["patch"] as? [String: Any])
    let proxies = try #require(root["proxy-providers"] as? [String: [String: String]])
    let path = try #require(proxies["local"]?["path"])
    #expect(path.hasPrefix(working.path + "/"))
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data(contentsOf: source))
    try Data("changed".utf8).write(to: URL(fileURLWithPath: path))
    #expect(try String(contentsOf: source, encoding: .utf8) == "proxies: []")
}

@Test func serverModeRejectsProviderPathsOutsideItsProfileDirectory() throws {
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: temporary) }
    let input = "{\"proxy-providers\":{\"outside\":{\"path\":\"/etc/passwd\"}}}"
    #expect(throws: CocoaError.self) {
        try MacProxyServerConfiguration.overrideJSON(json: Data(input.utf8), resourceDirectory: temporary.appendingPathComponent("resources"), workingDirectory: temporary.appendingPathComponent("server"))
    }
}

@Test func anonymousServerClearsCredentialsAndRestrictsLANAddresses() throws {
    let json = Data("{\"authentication\":[\"old:password\"],\"allow-lan\":false}".utf8)
    let patch = try MacProxyServerConfiguration.overrideJSON(
        json: json, resourceDirectory: URL(fileURLWithPath: "/profiles"),
        workingDirectory: URL(fileURLWithPath: "/server"), anonymousPort: 7890
    )
    let envelope = try #require(JSONSerialization.jsonObject(with: Data(patch.utf8)) as? [String: Any])
    let root = try #require(envelope["patch"] as? [String: Any])
    #expect(root["mixed-port"] as? Int == 7890)
    #expect(root["allow-lan"] as? Bool == true)
    #expect((root["authentication"] as? [String])?.isEmpty == true)
    let allowed = try #require(root["lan-allowed-ips"] as? [String])
    #expect(allowed.contains("192.168.0.0/16"))
    #expect(!allowed.contains("0.0.0.0/0"))
    #expect((root["tun"] as? [String: Bool])?["enable"] == false)
}

@Test func globalRoutingSelectsAProxyInsteadOfDirect() {
    let proxies: [String: [String: Any]] = [
        "GLOBAL": ["type": "Selector", "now": "DIRECT", "all": ["DIRECT", "first", "group"]],
        "DIRECT": ["type": "Direct"], "first": ["type": "Http"], "second": ["type": "Vmess"],
        "group": ["type": "Selector", "now": "second", "all": ["DIRECT", "second"]]
    ]
    #expect(MacProxyServerRoutingPolicy.globalTarget(proxies: proxies, preferredGroup: nil) == "first")
    #expect(MacProxyServerRoutingPolicy.globalTarget(proxies: proxies, preferredGroup: "group") == "group")
    #expect(MacProxyServerRoutingPolicy.resolvedProxy("group", proxies: proxies) == "second")
    #expect(MacProxyServerRoutingPolicy.resolvedProxy("DIRECT", proxies: proxies) == nil)
}

@Test func globalRoutingRejectsDirectAliasesAndCycles() {
    let proxies: [String: [String: Any]] = [
        "GLOBAL": ["type": "Selector", "now": "alias", "all": ["alias", "a"]],
        "alias": ["type": "Selector", "now": "DIRECT", "all": ["DIRECT"]],
        "DIRECT": ["type": "Direct"],
        "a": ["type": "Selector", "now": "b", "all": ["b"]],
        "b": ["type": "Selector", "now": "a", "all": ["a"]]
    ]
    #expect(MacProxyServerRoutingPolicy.globalTarget(proxies: proxies, preferredGroup: nil) == nil)
    #expect(MacProxyServerRoutingPolicy.resolvedProxy("a", proxies: proxies) == nil)
}

#if os(macOS)
@Test(.enabled(if: ProcessInfo.processInfo.environment["HAKO_TEST_HELPER"] != nil))
func appToServerHandshakeAndShutdown() async throws {
    let executable = try #require(ProcessInfo.processInfo.environment["HAKO_TEST_HELPER"])
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    #expect(socket >= 0)
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    address.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian
    var length = socklen_t(MemoryLayout<sockaddr_in>.size)
    let bound = withUnsafeMutablePointer(to: &address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { pointer in
            Darwin.bind(socket, pointer, length) == 0 && getsockname(socket, pointer, &length) == 0
        }
    }
    Darwin.close(socket)
    #expect(bound)
    let port = Int32(UInt16(bigEndian: address.sin_port))
    let child = MacProxyServerProcess(executable: URL(fileURLWithPath: executable), onExit: {})
    let timeout = Task {
        try await Task.sleep(for: .seconds(15))
        child.cancel()
    }
    defer { timeout.cancel(); child.cancel(); child.waitForExit() }
    let request = MacProxyServerRequest(yaml: "tun: {enable: true}\ndns: {enable: false}\nrules:\n  - MATCH,DIRECT\n",
                                        resourceDirectory: directory.path, port: port, username: "test", password: "test-password")
    let reply = try await Task.detached { try child.start(request) }.value
    #expect(reply.error == nil)
    let status = try #require(reply.status)
    let object = try #require(JSONSerialization.jsonObject(with: Data(status.utf8)) as? [String: Any])
    #expect(object["enabled"] as? Bool == true)
    #expect(object["port"] as? Int == Int(port))
    #expect(child.isRunning)
    for _ in 0..<3 {
        let traffic = try await Task.detached { try child.fetchTraffic() }.value
        #expect(traffic.up >= 0 && traffic.down >= 0)
        #expect(traffic.upTotal >= 0 && traffic.downTotal >= 0)
    }
    let direct = try await Task.detached { try child.updateRouting(MacProxyServerRouting(mode: "direct", selections: [:])) }.value
    #expect(direct.error == nil)
    #expect(direct.routing?.mode == "direct")
    let rules = try await Task.detached { try child.updateRouting(MacProxyServerRouting(mode: "rule", selections: [:])) }.value
    #expect(rules.routing?.mode == "rule")
    child.cancel()
    await Task.detached { child.waitForExit() }.value
    #expect(!child.isRunning)
    #expect(throws: CocoaError.self) { try child.fetchTraffic() }
}

@Test func cancellationBeforeLaunchDoesNotStartAProcess() throws {
    let child = MacProxyServerProcess(executable: URL(fileURLWithPath: "/usr/bin/false"), onExit: {})
    child.cancel()
    let request = MacProxyServerRequest(yaml: "", resourceDirectory: "/tmp", port: 7890, username: "test", password: "test")
    #expect(throws: CancellationError.self) { try child.start(request) }
    #expect(!child.isRunning)
}
#endif
