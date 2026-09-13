import CloudKit
import Foundation
#if os(macOS)
import Security
#endif

enum CloudKitBackupAvailability {
    static let unavailableMessage = "iCloud backup is unavailable in this build."

    static func container(identifier: String) -> CKContainer? {
        #if os(macOS)
        // CloudKit traps when initialized without its signed entitlements.
        // Inspect the running process rather than the project's entitlement file.
        guard let task = SecTaskCreateFromSelf(nil),
              let services = SecTaskCopyValueForEntitlement(
                task, "com.apple.developer.icloud-services" as CFString, nil
              ) as? [String], services.contains("CloudKit"),
              let containers = SecTaskCopyValueForEntitlement(
                task, "com.apple.developer.icloud-container-identifiers" as CFString, nil
              ) as? [String], containers.contains(identifier) else {
            return nil
        }
        #endif
        return CKContainer(identifier: identifier)
    }
}
