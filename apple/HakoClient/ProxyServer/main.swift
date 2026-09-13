import Darwin
import Foundation
import Hako
import HakoClientKit

final class ProxyServerPlatform: NSObject, HakoPlatformInterfaceProtocol {
    func writeLog(_ message: String?) {}
    func underNetworkExtension() -> Bool { false }
    func usePlatformAutoDetectControl() -> Bool { false }
    func autoDetectControl(_ fd: Int32) throws {}
    func startDefaultInterfaceMonitor(_ listener: (any HakoInterfaceUpdateListenerProtocol)?) throws {}
    func closeDefaultInterfaceMonitor(_ listener: (any HakoInterfaceUpdateListenerProtocol)?) throws {}
    func getInterfaces() throws -> any HakoNetworkInterfaceIteratorProtocol {
        throw CocoaError(.featureUnsupported)
    }
    func openTun(_ options: (any HakoTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        // Defense in depth: this executable cannot create a VPN/TUN.
        throw CocoaError(.featureUnsupported)
    }
}

func reply(_ value: MacProxyServerReply) {
    guard var data = try? JSONEncoder().encode(value) else { return }
    data.append(10)
    try? FileHandle.standardOutput.write(contentsOf: data)
}

func anonymousStatus(core: HakoBoxService, port: Int32) throws -> String {
    let json = core.runtimeDiagnosticsJSON()
    let diagnostics = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
    // This configuration enables only one mixed listener. The core computes
    // inboundCount from listeners actually bound; a port conflict leaves zero.
    guard diagnostics?["running"] as? Bool == true,
          diagnostics?["inboundCount"] as? Int == 1 else {
        throw CocoaError(.fileReadUnknown)
    }
    let status: [String: Any] = ["enabled": true, "port": port, "protocols": ["http", "socks5"], "authenticationRequired": false]
    return String(decoding: try JSONSerialization.data(withJSONObject: status), as: UTF8.self)
}

enum ProxyRoutingError: Error { case noGlobalProxy, invalidMode }

func proxyInventory() throws -> [String: [String: Any]] {
    let root = try JSONSerialization.jsonObject(with: Data(HakoProxiesJSON().utf8)) as? [String: Any]
    guard let proxies = root?["proxies"] as? [String: [String: Any]] else { throw CocoaError(.fileReadCorruptFile) }
    return proxies
}

func routingStatus() throws -> MacProxyServerRoutingStatus {
    let status = try JSONSerialization.jsonObject(with: Data(HakoStatusJSON().utf8)) as? [String: Any]
    let proxies = try proxyInventory()
    let selected = proxies["GLOBAL"]?["now"] as? String
    return MacProxyServerRoutingStatus(mode: status?["mode"] as? String ?? "rule", globalSelection: selected,
                                       globalProxy: selected.flatMap { MacProxyServerRoutingPolicy.resolvedProxy($0, proxies: proxies) })
}

func applyRouting(_ requested: MacProxyServerRouting, core: HakoBoxService, closeConnections: Bool) throws -> MacProxyServerRoutingStatus {
    guard ["global", "rule", "direct"].contains(requested.mode) else { throw ProxyRoutingError.invalidMode }
    let previous = try routingStatus()
    var proxies = try proxyInventory()
    var changed = false
    func select(_ group: String, _ name: String) throws {
        if proxies[group]?["now"] as? String == name { return }
        var error: NSError?
        HakoSelectProxy(group, name, &error)
        if let error { throw error }
        changed = true
    }
    // App-owned selections are authoritative; a copied core cache can be stale.
    for group in requested.selections.keys.sorted() {
        guard let name = requested.selections[group],
              let members = proxies[group]?["all"] as? [String], members.contains(name),
              let type = proxies[group]?["type"] as? String,
              ["selector", "urltest", "fallback"].contains(type.lowercased()) else { continue }
        try select(group, name)
    }
    proxies = try proxyInventory()
    if requested.mode == "global" {
        guard let target = MacProxyServerRoutingPolicy.globalTarget(proxies: proxies, preferredGroup: requested.preferredGroup) else {
            throw ProxyRoutingError.noGlobalProxy
        }
        try select("GLOBAL", target)
    }
    try core.setMode(requested.mode)
    if closeConnections && (changed || previous.mode != requested.mode) { HakoCloseAllConnections() }
    return try routingStatus()
}

signal(SIGPIPE, SIG_IGN)
// Keep the Unix control socket below sockaddr_un's path length limit.
let runtimeDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("hp-" + String(UUID().uuidString.prefix(8)), isDirectory: true)
var service: HakoBoxService?
var failure = "startFailed"
defer {
    try? service?.close()
    try? FileManager.default.removeItem(at: runtimeDirectory)
}
do {
    guard let line = readLine(), line.utf8.count <= 64 * 1024 * 1024 else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let request = try JSONDecoder().decode(MacProxyServerRequest.self, from: Data(line.utf8))
    guard request.username.isEmpty == request.password.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
    let anonymous = request.username.isEmpty && request.password.isEmpty
    let resources = URL(fileURLWithPath: request.resourceDirectory, isDirectory: true)
    let working = runtimeDirectory.appendingPathComponent("working", isDirectory: true)
    try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true,
                                          attributes: [.posixPermissions: 0o700])
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: runtimeDirectory.path)
    for name in ["GeoIP.dat", "GeoSite.dat", "geoip.metadb", "ASN.mmdb"] {
        let source = resources.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: working.appendingPathComponent(name))
        }
    }
    // Preserve previously selected proxy groups without sharing a live cache.
    let cache = resources.appendingPathComponent("cache.db")
    if FileManager.default.fileExists(atPath: cache.path) {
        try FileManager.default.copyItem(at: cache, to: working.appendingPathComponent("cache.db"))
    }
    let options = HakoSetupOptions()
    options.basePath = runtimeDirectory.path
    options.workingPath = working.path
    options.tempPath = runtimeDirectory.appendingPathComponent("temp").path
    options.runtimeProfile = "macosApplication"
    options.timeZone = TimeZone.current.identifier
    options.systemDNSServerLines = HakoSystemResolverLines()
    options.logMaxLines = 100
    var error: NSError?
    HakoSetup(options, &error)
    if let error { throw error }
    failure = "configuration"
    guard let json = HakoYamlToJSON(request.yaml, &error) else {
        throw error ?? CocoaError(.fileReadCorruptFile)
    }
    let patch = try MacProxyServerConfiguration.overrideJSON(
        json: Data(json.value.utf8), resourceDirectory: resources, workingDirectory: working,
        anonymousPort: anonymous ? request.port : nil
    )
    guard let configuration = HakoMergeOverrideForIOS(request.yaml, patch, &error) else {
        throw error ?? CocoaError(.fileReadCorruptFile)
    }
    guard let core = HakoNewService(ProxyServerPlatform(), &error) else {
        throw error ?? CocoaError(.featureUnsupported)
    }
    service = core
    if anonymous { HakoSetAllowLanPermitted(true) }
    try core.start(configuration.value)
    failure = "routing"
    let initialRouting: MacProxyServerRoutingStatus
    if let requested = request.routing {
        initialRouting = try applyRouting(requested, core: core, closeConnections: false)
    } else {
        initialRouting = try routingStatus()
    }
    failure = "startFailed"
    if anonymous {
        failure = "portInUse"
        reply(MacProxyServerReply(status: try anonymousStatus(core: core, port: request.port), routing: initialRouting))
    } else {
        do {
            try core.startProxyShare(request.port, username: request.username, password: request.password)
        } catch {
            if error.localizedDescription.contains("proxy-share port") { failure = "portInUse" }
            throw error
        }
        reply(MacProxyServerReply(status: core.proxyShareStatusJSON(), routing: initialRouting))
    }
    var samples = 0
    while let command = readLine() {
        if command == "traffic" {
            let traffic = try JSONDecoder().decode(MacProxyServerTraffic.self, from: Data(HakoTrafficJSON().utf8))
            samples += 1
            reply(MacProxyServerReply(traffic: traffic, routing: samples % 5 == 0 ? try routingStatus() : nil))
        } else {
            do {
                let control = try JSONDecoder().decode(MacProxyServerControl.self, from: Data(command.utf8))
                reply(MacProxyServerReply(routing: try applyRouting(control.routing, core: core, closeConnections: true)))
            } catch {
                reply(MacProxyServerReply(error: "routing", routing: try? routingStatus()))
            }
        }
    }
} catch {
    // Core errors may include private configuration fragments.
    reply(MacProxyServerReply(error: failure))
}
