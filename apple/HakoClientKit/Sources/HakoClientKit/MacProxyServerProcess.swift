#if os(macOS)
import Darwin
import Foundation

/// Credentials travel only over an inherited pipe, never argv or a config file.
/// The child exits when its parent's stdin pipe closes, including on app crash.
public final class MacProxyServerProcess: @unchecked Sendable {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let lock = NSLock()
    private let ioLock = NSLock()
    private var cancelled = false

    public var isRunning: Bool { process.isRunning }

    public init(executable: URL, onExit: @escaping @Sendable () -> Void) {
        process.executableURL = executable
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in onExit() }
    }

    /// Blocking startup handshake; callers must run this off the main actor.
    public func start(_ request: MacProxyServerRequest) throws -> MacProxyServerReply {
        ioLock.lock()
        defer { ioLock.unlock() }
        lock.lock()
        guard !cancelled else { lock.unlock(); throw CancellationError() }
        do { try process.run() } catch { lock.unlock(); throw error }
        lock.unlock()
        var data = try JSONEncoder().encode(request)
        data.append(10)
        try input.fileHandleForWriting.write(contentsOf: data)
        return try readReply()
    }

    /// Requests one sample over the existing private pipe. No extra listener.
    public func fetchTraffic() throws -> MacProxyServerTraffic {
        guard let traffic = try fetchRuntime().traffic else { throw CocoaError(.fileReadCorruptFile) }
        return traffic
    }

    public func fetchRuntime() throws -> MacProxyServerReply {
        try request(Data("traffic\n".utf8))
    }

    public func updateRouting(_ routing: MacProxyServerRouting) throws -> MacProxyServerReply {
        var data = try JSONEncoder().encode(MacProxyServerControl(routing: routing))
        data.append(10)
        return try request(data)
    }

    private func request(_ data: Data) throws -> MacProxyServerReply {
        ioLock.lock()
        defer { ioLock.unlock() }
        lock.lock()
        let stopped = cancelled
        lock.unlock()
        guard !stopped, process.isRunning else { throw CocoaError(.fileReadUnknown) }
        try input.fileHandleForWriting.write(contentsOf: data)
        return try readReply()
    }

    private func readReply() throws -> MacProxyServerReply {
        var response = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while response.count < 8192 {
            let count = Darwin.read(output.fileHandleForReading.fileDescriptor, &bytes, bytes.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw CocoaError(.fileReadUnknown) }
            response.append(contentsOf: bytes.prefix(count))
            if let end = response.firstIndex(of: 10) {
                return try JSONDecoder().decode(MacProxyServerReply.self, from: response[..<end])
            }
        }
        throw CocoaError(.fileReadCorruptFile)
    }

    public func cancel() {
        lock.lock()
        guard !cancelled else { lock.unlock(); return }
        cancelled = true
        try? input.fileHandleForWriting.close()
        lock.unlock()
        // Normal teardown is EOF-driven. Bound teardown even if core startup
        // is blocked. Process retains/reaps its PID before these callbacks run.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [process] in
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 4) { [process] in
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    public func waitForExit() {
        if process.isRunning { process.waitUntilExit() }
    }
}
#endif
