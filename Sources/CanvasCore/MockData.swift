#if DEBUG
import Foundation

public enum MockData {

    public static let courseId      = 99999
    public static let studentUserId = 77777
    public static let teacherUserId = 88888

    public static let course = Course(
        id: courseId,
        name: "Intro to Software Engineering",
        courseCode: "CS 101",
        applyAssignmentGroupWeights: true,
        gradingScheme: nil
    )

    public static let enrollment = Enrollment(
        grades: Grades(currentScore: 87.2, currentGrade: "B+")
    )

    private static let hwId   = 1001
    private static let qzId   = 1002
    private static let exId   = 1003

    private static let finalExamDueAt: String = {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(14 * 24 * 60 * 60))
    }()

    public static let assignmentGroups: [AssignmentGroup] = [
        AssignmentGroup(
            id: hwId, name: "Homework", groupWeight: 30, rules: nil,
            assignments: [
                Assignment(id: 201, name: "Week 1 Reflection", pointsPossible: 20,
                           dueAt: "2026-01-15T23:59:00Z", assignmentGroupId: hwId),
                Assignment(id: 202, name: "Week 2 Reflection", pointsPossible: 20,
                           dueAt: "2026-01-22T23:59:00Z", assignmentGroupId: hwId),
                Assignment(id: 203, name: "Week 3 Reflection", pointsPossible: 20,
                           dueAt: "2026-01-29T23:59:00Z", assignmentGroupId: hwId),
                Assignment(id: 204, name: "Week 4 Reflection", pointsPossible: 20,
                           dueAt: "2026-02-05T23:59:00Z", assignmentGroupId: hwId),
            ]
        ),
        AssignmentGroup(
            id: qzId, name: "Quizzes", groupWeight: 30, rules: nil,
            assignments: [
                Assignment(id: 301, name: "Quiz 1 — Variables", pointsPossible: 25,
                           dueAt: "2026-01-20T23:59:00Z", assignmentGroupId: qzId),
                Assignment(id: 302, name: "Quiz 2 — Functions", pointsPossible: 25,
                           dueAt: "2026-02-10T23:59:00Z", assignmentGroupId: qzId),
                Assignment(id: 303, name: "Quiz 3 — Objects",   pointsPossible: 25,
                           dueAt: "2026-02-24T23:59:00Z", assignmentGroupId: qzId),
            ]
        ),
        AssignmentGroup(
            id: exId, name: "Exams", groupWeight: 40, rules: nil,
            assignments: [
                Assignment(id: 401, name: "Midterm Exam", pointsPossible: 100,
                           dueAt: "2026-03-01T23:59:00Z", assignmentGroupId: exId),
                Assignment(id: 402, name: "Final Exam",   pointsPossible: 100,
                           dueAt: finalExamDueAt,          assignmentGroupId: exId),
            ]
        ),
    ]

    public static let submissions: [Submission] = [
        // Homework — all graded; assignment 201 has instructor feedback
        Submission(id: 1001, userId: studentUserId, assignmentId: 201, score: 18,
                   workflowState: "graded", gradedAt: "2026-01-16T10:00:00Z",
                   submittedAt: "2026-01-15T22:00:00Z",
                   submissionComments: [
                       SubmissionComment(authorId: teacherUserId, authorName: "Prof. Demo",
                                         comment: "Great reflection — keep pushing your analysis deeper.",
                                         createdAt: "2026-01-16T10:00:00Z")
                   ]),
        Submission(id: 1002, userId: studentUserId, assignmentId: 202, score: 19,
                   workflowState: "graded", gradedAt: "2026-01-23T11:00:00Z",
                   submittedAt: "2026-01-22T21:00:00Z", submissionComments: nil),
        Submission(id: 1003, userId: studentUserId, assignmentId: 203, score: 17,
                   workflowState: "graded", gradedAt: "2026-01-30T09:00:00Z",
                   submittedAt: "2026-01-29T20:00:00Z", submissionComments: nil),
        Submission(id: 1004, userId: studentUserId, assignmentId: 204, score: 20,
                   workflowState: "graded", gradedAt: "2026-02-06T08:00:00Z",
                   submittedAt: "2026-02-05T23:00:00Z", submissionComments: nil),
        // Quizzes — 2 graded, 1 submitted-not-graded (→ Awaiting Grade stream)
        Submission(id: 1005, userId: studentUserId, assignmentId: 301, score: 22,
                   workflowState: "graded", gradedAt: "2026-01-21T14:00:00Z",
                   submittedAt: "2026-01-20T22:00:00Z", submissionComments: nil),
        Submission(id: 1006, userId: studentUserId, assignmentId: 302, score: 24,
                   workflowState: "graded", gradedAt: "2026-02-11T15:00:00Z",
                   submittedAt: "2026-02-10T22:00:00Z", submissionComments: nil),
        Submission(id: 1007, userId: studentUserId, assignmentId: 303, score: nil,
                   workflowState: "submitted", gradedAt: nil,
                   submittedAt: "2026-02-24T21:00:00Z", submissionComments: nil),
        // Exams — midterm graded (→ Recently Graded); no submission for final (→ Upcoming)
        Submission(id: 1008, userId: studentUserId, assignmentId: 401, score: 85,
                   workflowState: "graded", gradedAt: "2026-03-05T12:00:00Z",
                   submittedAt: "2026-03-01T22:00:00Z", submissionComments: nil),
    ]

    public static let teacherIds: [Int] = [teacherUserId]
}
#endif
