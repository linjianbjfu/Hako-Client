import Foundation

@main
struct MacStorageChecks {
    static func main() throws {
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sandbox) }
        var groupCalls = 0
        let group = sandbox.appendingPathComponent("protected-group")
        let local = HakoAppIdentifiers.resolveMacStorage(useLocalStorage: true, home: sandbox) {
            groupCalls += 1
            return group
        }
        precondition(local == sandbox.appendingPathComponent(".clashhako", isDirectory: true))
        precondition(groupCalls == 0, "Local storage must not probe the App Group")
        let attributes = try FileManager.default.attributesOfItem(atPath: local!.path)
        precondition((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        let shared = HakoAppIdentifiers.resolveMacStorage(useLocalStorage: false, home: sandbox) {
            groupCalls += 1
            return group
        }
        precondition(shared == group && groupCalls == 1)
        let invalidHome = sandbox.appendingPathComponent("file")
        try Data().write(to: invalidHome)
        let failed = HakoAppIdentifiers.resolveMacStorage(useLocalStorage: true, home: invalidHome) {
            groupCalls += 1
            return group
        }
        precondition(failed == nil && groupCalls == 1, "A local failure must not fall back to the protected group")
        precondition(HakoAppIdentifiers.usesLocalStorage, "This test executable must be built without App Group entitlements")
        precondition(HakoAppIdentifiers.preferencesSuiteName == HakoAppIdentifiers.macAppBundleID + ".local")
        print("PASS: local directory isolation, permissions, failure behavior and unsigned preferences")
    }
}
