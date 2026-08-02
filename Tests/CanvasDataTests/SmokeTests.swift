import XCTest
@testable import CanvasData

final class SmokeTests: XCTestCase {
    func testChangeKindRoundTrip() throws {
        for kind in ChangeKind.allCases {
            XCTAssertEqual(ChangeKind(rawValue: kind.rawValue), kind)
        }
    }
}
