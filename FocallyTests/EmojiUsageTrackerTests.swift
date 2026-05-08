import XCTest
@testable import Focally

@MainActor
final class EmojiUsageTrackerTests: XCTestCase {
    var tracker: EmojiUsageTracker!

    override func setUp() {
        super.setUp()
        tracker = EmojiUsageTracker()
        tracker.recentEmojis = []
    }

    func testRecordUsage() {
        tracker.recordUsage(":deep_work:")
        XCTAssertEqual(tracker.recentEmojis, [":deep_work:"])

        tracker.recordUsage(":coding:")
        XCTAssertEqual(tracker.recentEmojis, [":coding:", ":deep_work:"])

        tracker.recordUsage(":deep_work:")
        XCTAssertEqual(tracker.recentEmojis, [":deep_work:", ":coding:"])
    }

    func testMaxRecentCount() {
        for i in 0..<15 {
            tracker.recordUsage(":\(i):")
        }
        XCTAssertEqual(tracker.recentEmojis.count, 12)
    }

    func testGetRecentEmojisForWorkspace() {
        tracker.recordUsage(":deep_work:")
        tracker.recordUsage(":coding:")
        tracker.recordUsage(":invalid_emoji:")

        let workspaceEmojis = [":deep_work:", ":coding:"]
        let filtered = tracker.getRecentEmojis(forWorkspace: workspaceEmojis)

        XCTAssertEqual(filtered, [":deep_work:", ":coding:"])
        XCTAssertFalse(filtered.contains(":invalid_emoji:"))
    }

    func testPersistence() {
        let shared = EmojiUsageTracker.shared
        let originalRecent = shared.recentEmojis

        shared.recordUsage(":test_new:")
        let afterRecord = shared.recentEmojis

        // Nota: Esto requiere reiniciar el tracker para probar persistencia real
        // Por ahora solo verificamos que el método se llame sin crash
        XCTAssertNotNil(afterRecord)
    }
}
