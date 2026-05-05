import XCTest

// MARK: - Simple Tests Without @testable Import

class SimpleFrameworkTests: XCTestCase {

    func testFoundationWorks() {
        XCTAssertTrue(true)
        XCTAssertFalse(false)
        XCTAssertEqual(1 + 1, 2)
        XCTAssertNotEqual(1, 2)
        XCTAssertGreaterThan(2, 1)
        XCTAssertLessThan(1, 2)
    }

    func testDateCreation() {
        let date = Date()
        XCTAssertNotNil(date)
        XCTAssertLessThan(abs(date.timeIntervalSinceNow), 0.1) // Allow small clock differences
    }

    func testStringOperations() {
        let text = "Hello, XCTest!"
        XCTAssertEqual(text, "Hello, XCTest!")
        XCTAssertTrue(text.contains("XCTest"))
        XCTAssertEqual(text.count, 14)
    }

    func testArrayOperations() {
        let array = [1, 2, 3]
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array.first, 1)
        XCTAssertEqual(array.last, 3)
        XCTAssertTrue(array.contains(2))
    }

    func testOptionalUnwrapping() {
        let optional: String? = "Test"
        XCTAssertNotNil(optional)
        XCTAssertEqual(optional!, "Test")

        let nilOptional: String? = nil
        XCTAssertNil(nilOptional)
    }
}
