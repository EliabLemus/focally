import XCTest
@testable import Focally

// MARK: - SoundPlayerService Tests (Test @testable import)

class SoundPlayerServiceTests: XCTestCase {

    func testSoundListNotEmpty() {
        let service = SoundPlayerService.shared
        XCTAssertFalse(service.sounds.isEmpty)
    }

    func testSoundListContainsExpected() {
        let service = SoundPlayerService.shared
        XCTAssertTrue(service.sounds.contains("Basso"))
        XCTAssertTrue(service.sounds.contains("Glass"))
        XCTAssertTrue(service.sounds.contains("Ping"))
        XCTAssertTrue(service.sounds.contains("Hero"))
    }

    func testSoundURLValid() {
        let service = SoundPlayerService.shared
        // Only test sounds that we know exist in the app bundle
        // Some system sounds (Basso, Blow, etc.) may not be available in test environment
        let bundledSounds: [String] = ["Bell", "confirmation_003", "glass_005", "pluck_002"]
        for sound in bundledSounds {
            let url = service.soundURL(for: sound)
            XCTAssertNotNil(url, "Sound URL for \(sound) should not be nil")
        }
    }

    func testSoundURLUnknown() {
        let service = SoundPlayerService.shared
        XCTAssertNil(service.soundURL(for: "NonExistentSound"))
    }
}
