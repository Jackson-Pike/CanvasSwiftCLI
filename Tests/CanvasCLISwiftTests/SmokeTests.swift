import XCTest
@testable import CanvasCLISwift

final class SmokeTests: XCTestCase {
    func testPaletteConstantsExist() {
        XCTAssertEqual(RESET, "\u{001B}[0m")
        XCTAssertFalse(banner.isEmpty)
    }
}
