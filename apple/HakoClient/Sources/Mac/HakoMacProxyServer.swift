import Foundation
import Combine
import HakoClientKit

@MainActor
final class HakoMacProxyServer: ObservableObject, ProxyShareCommanding {
    @Published private(set) var traffic: MacProxyServerTraffic?
    @Published private(set) var routingStatus: MacProxyServerRoutingStatus?
    var configuration: () throws -> (yaml: String, resources: URL) = { throw ProxyShareError.serverNeedsProfile }
    var routing: () -> MacProxyServerRouting = { MacProxyServerRouting(mode: "rule", selections: [:]) }
    var profileID: () -> String? = { nil }
    var didStop: (_ unexpected: Bool) -> Void = { _ in }
    private var local: MacProxyServerProcess?
    private var localStatus = ProxyShareStatus.disabled
    private var generation: UInt64 = 0
    private var trafficTask: Task<Void, Never>?
    private var lastRouting: MacProxyServerRouting?
    private var runningProfileID: String?

    var proxyShareWithoutVPNAvailable: Bool { true }
    var proxyShareAPIReady: Bool { true }
    var proxyShareAPIClientReady: Bool { proxyShareAPIReady }
    var proxyShareRunsWithoutVPN: Bool { local != nil }

    func fetchProxyShareStatus() async throws -> ProxyShareStatus {
        if let local {
            guard local.isRunning else { throw ProxyShareError.serverStopped }
            return localStatus
        }
        return .disabled
    }

    func startProxyShare(_ value: ProxyShareConfiguration) async throws -> ProxyShareStatus {
        guard local == nil else { throw ProxyShareError.operationInProgress }
        let source = try configuration()
        let requestedRouting = routing()
        runningProfileID = profileID()
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HakoProxyServer")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw ProxyShareError.serverUnavailable
        }
        generation &+= 1
        let token = generation
        let child = MacProxyServerProcess(executable: executable) { [weak self] in
            Task { @MainActor in
                // Startup owns failures until the ready handshake is accepted.
                guard let self, self.generation == token, self.localStatus.enabled else { return }
                self.local = nil
                self.localStatus = .disabled
                self.clearTraffic()
                self.routingStatus = nil
                self.lastRouting = nil
                self.didStop(true)
            }
        }
        local = child
        let request = MacProxyServerRequest(yaml: source.yaml, resourceDirectory: source.resources.path,
                                            port: value.port, username: value.username, password: value.password, routing: requestedRouting)
        do {
            let response = try await withTaskCancellationHandler {
                try await Task.detached(priority: .userInitiated) { try child.start(request) }.value
            } onCancel: {
                child.cancel()
            }
            try Task.checkCancellation()
            switch response.error {
            case "portInUse": throw ProxyShareError.portInUse
            case "configuration": throw ProxyShareError.serverConfiguration
            case "routing": throw ProxyShareError.serverRouting
            case .some: throw ProxyShareError.coreRejected
            case .none: break
            }
            guard generation == token, local === child, child.isRunning else { throw ProxyShareError.serverStopped }
            guard let json = response.status else { throw ProxyShareError.invalidResponse }
            localStatus = try ProxyShareStatusParser.parse(json, allowUnauthenticated: !value.authenticationRequired)
            routingStatus = response.routing
            lastRouting = requestedRouting
            try await synchronizeRouting()
            startTrafficUpdates(child: child, token: token)
            return localStatus
        } catch {
            if local === child {
                generation &+= 1
                local = nil
                localStatus = .disabled
                clearTraffic()
                routingStatus = nil
                lastRouting = nil
            }
            child.cancel()
            await Task.detached { child.waitForExit() }.value
            throw error
        }
    }

    func stopProxyShare() async throws -> ProxyShareStatus {
        if local != nil {
            await stopLocal()
            return .disabled
        }
        return .disabled
    }

    func stopLocal() async {
        guard let child = local else { return }
        generation &+= 1
        clearTraffic()
        routingStatus = nil
        lastRouting = nil
        child.cancel()
        await Task.detached { child.waitForExit() }.value
        if local === child {
            local = nil
            localStatus = .disabled
            didStop(false)
        }
    }

    func synchronizeRouting(mode: String? = nil) async throws {
        guard let child = local, localStatus.enabled else { return }
        guard profileID() == runningProfileID else { throw ProxyShareError.serverRestartRequired }
        let current = routing()
        let requested = MacProxyServerRouting(mode: mode ?? current.mode, selections: current.selections, preferredGroup: current.preferredGroup)
        // Browsing/expanding a group updates its presentation preference too;
        // that alone must not change the active GLOBAL route.
        if let lastRouting, requested.mode == lastRouting.mode, requested.selections == lastRouting.selections { return }
        let token = generation
        let response = try await Task.detached(priority: .userInitiated) { try child.updateRouting(requested) }.value
        guard token == generation, local === child else { throw ProxyShareError.serverStopped }
        if let status = response.routing { routingStatus = status }
        guard response.error == nil, response.routing?.mode == requested.mode else { throw ProxyShareError.serverRouting }
        lastRouting = requested
    }

    private func startTrafficUpdates(child: MacProxyServerProcess, token: UInt64) {
        clearTraffic()
        traffic = .zero
        trafficTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let sample = try await Task.detached(priority: .utility) { try child.fetchRuntime() }.value
                    guard let self, !Task.isCancelled,
                          self.generation == token, self.local === child else { return }
                    self.traffic = sample.traffic ?? .zero
                    if let status = sample.routing, status != self.routingStatus { self.routingStatus = status }
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch {
                guard let self, self.generation == token, self.local === child else { return }
                // Do not leave the last transfer's speed stuck in the menu bar.
                self.traffic = .zero
            }
        }
    }

    private func clearTraffic() {
        trafficTask?.cancel()
        trafficTask = nil
        traffic = nil
    }
}
