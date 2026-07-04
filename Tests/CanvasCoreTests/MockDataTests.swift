import XCTest
@testable import CanvasCore

#if DEBUG
final class MockDataTests: XCTestCase {

    // MARK: - Course

    func testCourseHasExpectedIdentity() {
        let course = MockData.courses.first { $0.id == MockData.csCourseId }!
        XCTAssertEqual(course.id, 99999)
        XCTAssertEqual(course.name, "Intro to Software Engineering")
        XCTAssertEqual(course.courseCode, "CS 101")
        XCTAssertEqual(course.applyAssignmentGroupWeights, true)
        XCTAssertNil(course.gradingScheme)
    }

    func testFourCoursesAvailable() {
        XCTAssertEqual(MockData.courses.count, 4)
    }

    // MARK: - Enrollment

    func testEnrollmentHasScore() {
        let enrollment = MockData.enrollments[MockData.csCourseId]!
        XCTAssertEqual(enrollment.grades?.currentScore, 87.2)
        XCTAssertEqual(enrollment.grades?.currentGrade, "B+")
    }

    // MARK: - Assignment Groups

    func testThreeGroupsWithCorrectWeights() {
        let groups = MockData.assignmentGroups[MockData.csCourseId]!
        XCTAssertEqual(groups.count, 3)
        let weights = groups.map { $0.groupWeight }
        XCTAssertEqual(weights.reduce(0, +), 100.0, accuracy: 0.001)
    }

    func testHomeworkGroupHasFourAssignments() {
        let hw = MockData.assignmentGroups[MockData.csCourseId]!.first { $0.name == "Homework" }!
        XCTAssertEqual(hw.assignments.count, 4)
        XCTAssertTrue(hw.assignments.allSatisfy { $0.pointsPossible == 20 })
    }

    func testQuizzesGroupHasThreeAssignments() {
        let q = MockData.assignmentGroups[MockData.csCourseId]!.first { $0.name == "Quizzes" }!
        XCTAssertEqual(q.assignments.count, 3)
    }

    func testExamsGroupHasTwoAssignments() {
        let e = MockData.assignmentGroups[MockData.csCourseId]!.first { $0.name == "Exams" }!
        XCTAssertEqual(e.assignments.count, 2)
    }

    func testFinalExamDueInFuture() {
        let exams = MockData.assignmentGroups[MockData.csCourseId]!.first { $0.name == "Exams" }!
        let final_ = exams.assignments.first { $0.name == "Final Exam" }!
        let iso = ISO8601DateFormatter()
        let dueDate = iso.date(from: final_.dueAt!)!
        XCTAssertGreaterThan(dueDate, Date())
    }

    // MARK: - Submissions

    func testSubmissionsCountAndStudentId() {
        let submissions = MockData.submissions[MockData.csCourseId]!
        XCTAssertEqual(submissions.count, 8)
        XCTAssertTrue(submissions.allSatisfy { $0.userId == MockData.studentUserId })
    }

    func testAwaitingGradeSubmissionExists() {
        let awaiting = MockData.submissions[MockData.csCourseId]!.filter {
            $0.workflowState == "submitted" && $0.score == nil
        }
        XCTAssertEqual(awaiting.count, 1)
        XCTAssertEqual(awaiting[0].assignmentId, 303) // Quiz 3
    }

    func testFeedbackCommentHasDifferentAuthor() {
        let withComments = MockData.submissions[MockData.csCourseId]!.filter {
            $0.submissionComments?.isEmpty == false
        }
        XCTAssertEqual(withComments.count, 1)
        let comment = withComments[0].submissionComments![0]
        XCTAssertNotEqual(comment.authorId, MockData.studentUserId)
        XCTAssertEqual(comment.authorId, MockData.teacherUserId)
        XCTAssertFalse(comment.comment.isEmpty)
    }

    func testMidtermIsGradedWithScore() {
        let midterm = MockData.submissions[MockData.csCourseId]!.first { $0.assignmentId == 401 }!
        XCTAssertEqual(midterm.workflowState, "graded")
        XCTAssertEqual(midterm.score, 85)
    }

    func testNoSubmissionForFinalExam() {
        let finalSub = MockData.submissions[MockData.csCourseId]!.first { $0.assignmentId == 402 }
        XCTAssertNil(finalSub)
    }

    // MARK: - Teachers

    func testTeacherIdsContainsTeacherUserId() {
        XCTAssertEqual(MockData.teacherIds, [MockData.teacherUserId])
    }
}
#endif
