import XCTest
@testable import Focally

@MainActor
final class StatusTitleAssignerTests: XCTestCase {
    func testAssignsOnlyWhenStringChanges() {
        var assigner = StatusTitleAssigner()

        XCTAssertEqual(assigner.title(for: "  Deep work"), "  Deep work", "First assignment must always apply")
        XCTAssertNil(assigner.title(for: "  Deep work"), "Identical string must NOT re-assign")
        XCTAssertNil(assigner.title(for: "  Deep work"), "Repeated identical strings keep skipping")
        XCTAssertEqual(assigner.title(for: "  Deep work "), "  Deep work ", "Any character change must re-assign")
        XCTAssertEqual(assigner.title(for: ""), "", "Empty transition (session end) must re-assign")
        XCTAssertNil(assigner.title(for: ""), "Empty state repeated must NOT re-assign")
    }

    func testResetForcesNextAssignment() {
        var assigner = StatusTitleAssigner()
        _ = assigner.title(for: "  Focus")
        XCTAssertNil(assigner.title(for: "  Focus"))

        assigner.reset()

        XCTAssertEqual(assigner.title(for: "  Focus"), "  Focus", "After reset the same string must be assigned again")
    }
}
