import Foundation
#if os(macOS)
import Security
#endif

extension HakoAppIdentifiers {
    /// App Group entitlements belong to the signed process, not project.yml.
    /// Local builds must not probe the protected group as a fallback.
    static let usesLocalStorage: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(
                task, "com.apple.security.application-groups" as CFString, nil
              ) as? [String] else { return true }
        return !groups.contains(appGroup)
        #else
        return false
        #endif
    }()

    static var preferencesSuiteName: String {
        usesLocalStorage ? macAppBundleID + ".local" : appGroup
    }

    static let appGroupContainer: URL? = {
        #if os(macOS)
        return resolveMacStorage(
            useLocalStorage: usesLocalStorage,
            home: FileManager.default.homeDirectoryForCurrentUser,
            groupContainer: {
                FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
            }
        )
        #else
        let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
        #if os(tvOS)
        return root?.appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
        #else
        return root
        #endif
        #endif
    }()

    #if os(macOS)
    static func resolveMacStorage(useLocalStorage: Bool, home: URL,
                                  groupContainer: () -> URL?) -> URL? {
        guard useLocalStorage else { return groupContainer() }
        let root = home.appendingPathComponent(".clashhako", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            return root
        } catch {
            // A failed local directory must not trigger a protected-container read.
            return nil
        }
    }
    #endif
}
