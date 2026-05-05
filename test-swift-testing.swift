import Testing

@Suite("Swift Testing Check")
struct SwiftTestingCheck {
    @Test("Check if Swift Testing works")
    func checkSwiftTesting() {
        #expect(true)
    }
}
