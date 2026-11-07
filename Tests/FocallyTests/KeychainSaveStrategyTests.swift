import Foundation
import Testing
@testable import Focally

/// Decisión pura de guardado en keychain: testeable sin tocar SecItem.
@Suite("KeychainSaveStrategy")
struct KeychainSaveStrategyTests {
    @Test func successfulUpdateYieldsUpdateOnly() {
        #expect(KeychainHelper.saveStrategy(updateStatus: errSecSuccess) == .updateExisting)
    }

    @Test func itemNotFoundYieldsAdd() {
        #expect(KeychainHelper.saveStrategy(updateStatus: errSecItemNotFound) == .addNew)
    }

    @Test func otherErrorsYieldFailureWithOSStatus() {
        #expect(KeychainHelper.saveStrategy(updateStatus: errSecInteractionNotAllowed) == .reportFailure(errSecInteractionNotAllowed))
        #expect(KeychainHelper.saveStrategy(updateStatus: errSecAuthFailed) == .reportFailure(errSecAuthFailed))
        #expect(KeychainHelper.saveStrategy(updateStatus: OSStatus(paramErr)) == .reportFailure(OSStatus(paramErr)))
    }

    @Test func strategyIsEquatable() {
        #expect(KeychainSaveStrategy.updateExisting != .addNew)
        #expect(KeychainSaveStrategy.reportFailure(errSecAuthFailed) == .reportFailure(errSecAuthFailed))
        #expect(KeychainSaveStrategy.reportFailure(errSecAuthFailed) != .reportFailure(errSecItemNotFound))
    }
}
