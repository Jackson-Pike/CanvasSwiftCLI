import XCTest
@testable import CanvasCLISwift

final class DisplayTests: XCTestCase {
    func testLetterGradeBoundaries() {
        XCTAssertEqual(letterGrade(for: 93), "A")
        XCTAssertEqual(letterGrade(for: 92.9), "A-")
        XCTAssertEqual(letterGrade(for: 87), "B+")
        XCTAssertEqual(letterGrade(for: 59.9), "F")
    }

    func testProgressBarFillsProportionally() {
        let bar = progressBar(percent: 50, width: 10)
        XCTAssertEqual(bar.filter { $0 == "█" }.count, 5)
        XCTAssertEqual(bar.count, 10)
    }

    func testFormatPercentRoundsToOneDecimal() {
        XCTAssertEqual(formatPercent(88.44), "88.4%")
        XCTAssertEqual(formatPercent(nil), "—")
    }
}
