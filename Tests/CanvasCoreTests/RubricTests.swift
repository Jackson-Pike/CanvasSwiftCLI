import XCTest
@testable import CanvasCore

final class RubricTests: XCTestCase {
    func testFormatRubricAssessmentJoinsRatingAndComment() throws {
        let criteria = [
            RubricCriterion(id: "1", description: "Content", points: 10.0, ratings: [
                RubricRating(id: "r1", description: "Great", points: 10.0),
                RubricRating(id: "r2", description: "Okay", points: 5.0),
            ]),
            RubricCriterion(id: "2", description: "Grammar", points: 5.0, ratings: nil),
        ]
        let assessment: [String: RubricAssessmentEntry] = [
            "1": RubricAssessmentEntry(points: 10.0, comments: "Nice work", ratingId: "r1"),
        ]

        let lines = formatRubricAssessment(criteria: criteria, assessment: assessment)

        XCTAssertEqual(lines.count, 2)

        let scored = lines[0]
        XCTAssertEqual(scored.criterionDescription, "Content")
        XCTAssertEqual(scored.possiblePoints, 10.0)
        XCTAssertEqual(scored.earnedPoints, 10.0)
        XCTAssertEqual(scored.ratingLabel, "Great")
        XCTAssertEqual(scored.comment, "Nice work")

        let unscored = lines[1]
        XCTAssertEqual(unscored.criterionDescription, "Grammar")
        XCTAssertEqual(unscored.possiblePoints, 5.0)
        XCTAssertNil(unscored.earnedPoints)
        XCTAssertNil(unscored.ratingLabel)
        XCTAssertNil(unscored.comment)
    }
}
