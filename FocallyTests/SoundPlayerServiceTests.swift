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
        for sound in service.sounds {
            let url = service.soundURL(for: sound)
            XCTAssertNotNil(url, "Sound URL for \(sound) should not be nil")
        }
    }

    func testSoundURLUnknown() {
        let service = SoundPlayerService.shared
        XCTAssertNil(service.soundURL(for: "NonExistentSound"))
    }
}
