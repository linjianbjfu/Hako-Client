#if os(macOS)
import Foundation
import Testing
@testable import HakoClientKit

// The test process has no entitlement for this container. Initialization must
// be safe and each operation must return unavailable before calling CloudKit.
private let containerIdentifier = "iCloud.org.example.hako.unentitled-test"

@Test func unavailableBackupSinkDoesNotCrash() async {
    let sink = CloudKitBackupRecordSink(containerIdentifier: containerIdentifier)
    let payload = BackupRecordPayload(
        installID: "test", archive: Data(), sourceDevice: "test",
        exportedAt: Date(), schemaVersion: 1
    )
    let expected = BackupRecordSinkError.unavailable(CloudKitBackupAvailability.unavailableMessage)
    await #expect(throws: expected) { try await sink.upsert(payload) }
    await #expect(throws: expected) { try await sink.deleteOwn(installID: "test") }
}

@Test func unavailableBackupSourceDoesNotCrash() async {
    let source = CloudKitBackupRecordSource(containerIdentifier: containerIdentifier)
    let expected = BackupRecordSourceError.unavailable(CloudKitBackupAvailability.unavailableMessage)
    await #expect(throws: expected) { try await source.listBackups() }
    await #expect(throws: expected) { try await source.fetchArchive(installID: "test") }
}
#endif
