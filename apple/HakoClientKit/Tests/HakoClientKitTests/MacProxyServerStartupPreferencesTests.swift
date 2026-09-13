import Foundation
import Testing
@testable import HakoClientKit

@Test func independentProxyLaunchIntentSurvivesRelaunchAndExplicitStop() throws {
    let suite = "hako-startup-test-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let firstLaunch = MacProxyServerStartupPreferences(defaults: defaults)
    #expect(!firstLaunch.isEnabled)
    firstLaunch.enable(authenticationRequired: true)

    let nextLaunch = MacProxyServerStartupPreferences(defaults: try #require(UserDefaults(suiteName: suite)))
    #expect(nextLaunch.isEnabled)
    #expect(nextLaunch.authenticationRequired)
    nextLaunch.disable()
    #expect(!firstLaunch.isEnabled)
    // Stopping must retain the authentication choice for the next manual start.
    #expect(firstLaunch.authenticationRequired)
}

@Test func anonymousRestartDoesNotReuseEarlierAuthentication() throws {
    let suite = "hako-startup-test-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = MacProxyServerStartupPreferences(defaults: defaults)
    preferences.enable(authenticationRequired: true)
    preferences.disable()
    preferences.enable(authenticationRequired: false)
    let nextLaunch = MacProxyServerStartupPreferences(defaults: defaults)
    #expect(nextLaunch.isEnabled)
    #expect(!nextLaunch.authenticationRequired)
}
