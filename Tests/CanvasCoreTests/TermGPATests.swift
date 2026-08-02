import XCTest
@testable import CanvasCore

final class TermGPATests: XCTestCase {
    func testGpaPointsMapping() {
        XCTAssertEqual(gpaPoints(forLetter: "A"), 4.0, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "A-"), 3.7, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "B+"), 3.3, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "C-"), 1.7, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "F"), 0.0, accuracy: 0.001)
    }

    func testWeightedTermGPA() {
        let s = [
            CourseGradeSummary(courseId: 1, credits: 3, nowPercent: 95, ceilingPercent: 100, floorPercent: 50, scale: byuhDefaultScale), // A -> 4.0
            CourseGradeSummary(courseId: 2, credits: 4, nowPercent: 84, ceilingPercent: 90, floorPercent: 40, scale: byuhDefaultScale),  // B -> 3.0
        ]
        // (4.0*3 + 3.0*4) / 7 = 24/7 = 3.4286
        XCTAssertEqual(currentTermGPA(s)!, 24.0/7.0, accuracy: 0.001)
    }

    func testCeilingGPAExact() {
        let s = [
            CourseGradeSummary(courseId: 1, credits: 3, nowPercent: 95, ceilingPercent: 100, floorPercent: 50, scale: byuhDefaultScale),
            CourseGradeSummary(courseId: 2, credits: 4, nowPercent: 84, ceilingPercent: 90, floorPercent: 40, scale: byuhDefaultScale),
        ]
        XCTAssertEqual(ceilingTermGPA(s)!, (4.0*3 + 3.7*4)/7, accuracy: 0.001)
        XCTAssertEqual(floorTermGPA(s)!, (0.0*3 + 0.0*4)/7, accuracy: 0.001) // 50->F, 40->F
    }

    func testNilPercentSkipped() {
        let s = [
            CourseGradeSummary(courseId: 1, credits: 3, nowPercent: nil, ceilingPercent: 100, floorPercent: 0, scale: byuhDefaultScale),
            CourseGradeSummary(courseId: 2, credits: 3, nowPercent: 94, ceilingPercent: 100, floorPercent: 0, scale: byuhDefaultScale),
        ]
        XCTAssertEqual(currentTermGPA(s)!, 4.0, accuracy: 0.001) // only course 2 counts
    }
}
