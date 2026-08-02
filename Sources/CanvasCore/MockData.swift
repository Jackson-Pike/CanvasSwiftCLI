#if DEBUG
import Foundation

public enum MockData {

    public static let studentUserId = 77777
    public static let teacherUserId = 88888

    // MARK: - Course IDs

    public static let csCourseId   = 99999
    public static let mathCourseId = 99998
    public static let histCourseId = 99997
    public static let relCourseId  = 99996

    public static let courses: [Course] = [
        Course(id: csCourseId, name: "Intro to Software Engineering", courseCode: "CS 101",
               applyAssignmentGroupWeights: true, gradingScheme: nil),
        Course(id: mathCourseId, name: "Calculus II", courseCode: "MATH 112",
               applyAssignmentGroupWeights: true, gradingScheme: nil),
        Course(id: histCourseId, name: "World Civilizations", courseCode: "HIST 201",
               applyAssignmentGroupWeights: true, gradingScheme: nil),
        Course(id: relCourseId, name: "Teachings of the Book of Mormon", courseCode: "REL 225",
               applyAssignmentGroupWeights: true, gradingScheme: nil),
    ]

    public static let enrollments: [Int: Enrollment] = [
        csCourseId:   Enrollment(grades: Grades(currentScore: 87.2, currentGrade: "B+")),
        mathCourseId: Enrollment(grades: Grades(currentScore: 73.5, currentGrade: "C")),
        histCourseId: Enrollment(grades: Grades(currentScore: 95.1, currentGrade: "A")),
        relCourseId:  Enrollment(grades: Grades(currentScore: 91.4, currentGrade: "A-")),
    ]

    private static let finalExamDueAt: String = {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(14 * 24 * 60 * 60))
    }()

    // MARK: - CS 101

    private static let hwId = 1001
    private static let qzId = 1002
    private static let exId = 1003

    private static let csAssignmentGroups: [AssignmentGroup] = [
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

    private static let csSubmissions: [Submission] = [
        // Homework — all graded; assignment 201 has instructor feedback
        Submission(id: 1001, userId: studentUserId, assignmentId: 201, score: 18,
                   workflowState: "graded", gradedAt: "2026-01-16T10:00:00Z",
                   submittedAt: "2026-01-15T22:00:00Z",
                   submissionComments: [
                       SubmissionComment(id: 9001, authorId: teacherUserId, authorName: "Prof. Demo",
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
        // Final Exam — graded but muted by the instructor before release: score withheld (score nil).
        Submission(id: 1009, userId: studentUserId, assignmentId: 402, score: nil,
                   workflowState: "graded", gradedAt: "2026-03-10T12:00:00Z",
                   submittedAt: nil, submissionComments: nil),
    ]

    // MARK: - MATH 112 (Calculus II)

    private static let mathPsId  = 2001
    private static let mathQzId  = 2002
    private static let mathExId  = 2003

    private static let mathAssignmentGroups: [AssignmentGroup] = [
        AssignmentGroup(
            id: mathPsId, name: "Problem Sets", groupWeight: 25, rules: nil,
            assignments: [
                Assignment(id: 2201, name: "Problem Set 1 — Integration Techniques", pointsPossible: 30,
                           dueAt: "2026-01-16T23:59:00Z", assignmentGroupId: mathPsId),
                Assignment(id: 2202, name: "Problem Set 2 — Series & Sequences", pointsPossible: 30,
                           dueAt: "2026-01-30T23:59:00Z", assignmentGroupId: mathPsId),
                Assignment(id: 2203, name: "Problem Set 3 — Polar Coordinates", pointsPossible: 30,
                           dueAt: "2026-02-13T23:59:00Z", assignmentGroupId: mathPsId),
            ]
        ),
        AssignmentGroup(
            id: mathQzId, name: "Quizzes", groupWeight: 25, rules: nil,
            assignments: [
                Assignment(id: 2301, name: "Quiz 1 — Integration by Parts", pointsPossible: 20,
                           dueAt: "2026-01-23T23:59:00Z", assignmentGroupId: mathQzId),
                Assignment(id: 2302, name: "Quiz 2 — Convergence Tests", pointsPossible: 20,
                           dueAt: "2026-02-06T23:59:00Z", assignmentGroupId: mathQzId),
                // Past due, never submitted → shows as Missing
                Assignment(id: 2303, name: "Quiz 3 — Taylor Series", pointsPossible: 20,
                           dueAt: "2026-02-20T23:59:00Z", assignmentGroupId: mathQzId),
            ]
        ),
        AssignmentGroup(
            id: mathExId, name: "Exams", groupWeight: 50, rules: nil,
            assignments: [
                Assignment(id: 2401, name: "Midterm Exam", pointsPossible: 100,
                           dueAt: "2026-02-27T23:59:00Z", assignmentGroupId: mathExId),
                Assignment(id: 2402, name: "Final Exam", pointsPossible: 100,
                           dueAt: finalExamDueAt, assignmentGroupId: mathExId),
            ]
        ),
    ]

    private static let mathSubmissions: [Submission] = [
        Submission(id: 2001, userId: studentUserId, assignmentId: 2201, score: 26,
                   workflowState: "graded", gradedAt: "2026-01-17T10:00:00Z",
                   submittedAt: "2026-01-16T22:00:00Z", submissionComments: nil),
        Submission(id: 2002, userId: studentUserId, assignmentId: 2202, score: 21,
                   workflowState: "graded", gradedAt: "2026-01-31T09:00:00Z",
                   submittedAt: "2026-01-30T23:00:00Z",
                   submissionComments: [
                       SubmissionComment(id: 9002, authorId: teacherUserId, authorName: "Dr. Kekoa",
                                         comment: "Watch your algebra on problem 4 — the rest is solid.",
                                         createdAt: "2026-01-31T09:00:00Z")
                   ]),
        Submission(id: 2003, userId: studentUserId, assignmentId: 2203, score: nil,
                   workflowState: "submitted", gradedAt: nil,
                   submittedAt: "2026-02-13T22:30:00Z", submissionComments: nil),
        Submission(id: 2004, userId: studentUserId, assignmentId: 2301, score: 15,
                   workflowState: "graded", gradedAt: "2026-01-24T08:00:00Z",
                   submittedAt: "2026-01-23T22:00:00Z", submissionComments: nil),
        Submission(id: 2005, userId: studentUserId, assignmentId: 2302, score: 13,
                   workflowState: "graded", gradedAt: "2026-02-07T08:00:00Z",
                   submittedAt: "2026-02-06T23:00:00Z", submissionComments: nil),
        // Quiz 3 has no submission at all — appears as Missing since due date has passed
        Submission(id: 2006, userId: studentUserId, assignmentId: 2401, score: 68,
                   workflowState: "graded", gradedAt: "2026-03-02T12:00:00Z",
                   submittedAt: "2026-02-27T21:00:00Z", submissionComments: nil),
    ]

    // MARK: - HIST 201 (World Civilizations)

    private static let histDiscId = 3001
    private static let histPaperId = 3002
    private static let histExId = 3003

    private static let histAssignmentGroups: [AssignmentGroup] = [
        AssignmentGroup(
            id: histDiscId, name: "Discussions", groupWeight: 20, rules: nil,
            assignments: [
                Assignment(id: 3201, name: "Discussion 1 — Mesopotamia", pointsPossible: 10,
                           dueAt: "2026-01-14T23:59:00Z", assignmentGroupId: histDiscId),
                Assignment(id: 3202, name: "Discussion 2 — Classical Greece", pointsPossible: 10,
                           dueAt: "2026-01-28T23:59:00Z", assignmentGroupId: histDiscId),
                Assignment(id: 3203, name: "Discussion 3 — Silk Road Trade", pointsPossible: 10,
                           dueAt: "2026-02-11T23:59:00Z", assignmentGroupId: histDiscId),
            ]
        ),
        AssignmentGroup(
            id: histPaperId, name: "Papers", groupWeight: 40, rules: nil,
            assignments: [
                Assignment(id: 3301, name: "Paper 1 — Ancient Empires", pointsPossible: 50,
                           dueAt: "2026-02-04T23:59:00Z", assignmentGroupId: histPaperId),
                Assignment(id: 3302, name: "Paper 2 — Age of Exploration", pointsPossible: 50,
                           dueAt: "2026-03-11T23:59:00Z", assignmentGroupId: histPaperId),
            ]
        ),
        AssignmentGroup(
            id: histExId, name: "Exams", groupWeight: 40, rules: nil,
            assignments: [
                Assignment(id: 3401, name: "Midterm Exam", pointsPossible: 100,
                           dueAt: "2026-02-25T23:59:00Z", assignmentGroupId: histExId),
                Assignment(id: 3402, name: "Final Exam", pointsPossible: 100,
                           dueAt: finalExamDueAt, assignmentGroupId: histExId),
            ]
        ),
    ]

    private static let histSubmissions: [Submission] = [
        Submission(id: 3001, userId: studentUserId, assignmentId: 3201, score: 10,
                   workflowState: "graded", gradedAt: "2026-01-15T09:00:00Z",
                   submittedAt: "2026-01-14T20:00:00Z", submissionComments: nil),
        Submission(id: 3002, userId: studentUserId, assignmentId: 3202, score: 10,
                   workflowState: "graded", gradedAt: "2026-01-29T09:00:00Z",
                   submittedAt: "2026-01-28T21:00:00Z", submissionComments: nil),
        Submission(id: 3003, userId: studentUserId, assignmentId: 3203, score: 9,
                   workflowState: "graded", gradedAt: "2026-02-12T09:00:00Z",
                   submittedAt: "2026-02-11T22:00:00Z", submissionComments: nil),
        Submission(id: 3004, userId: studentUserId, assignmentId: 3301, score: 48,
                   workflowState: "graded", gradedAt: "2026-02-06T14:00:00Z",
                   submittedAt: "2026-02-04T20:00:00Z",
                   submissionComments: [
                       SubmissionComment(id: 9003, authorId: teacherUserId, authorName: "Dr. Alaimalo",
                                         comment: "Excellent thesis and use of primary sources.",
                                         createdAt: "2026-02-06T14:00:00Z")
                   ]),
        Submission(id: 3005, userId: studentUserId, assignmentId: 3401, score: 94,
                   workflowState: "graded", gradedAt: "2026-02-26T12:00:00Z",
                   submittedAt: "2026-02-25T21:00:00Z", submissionComments: nil),
        // Paper 2 not yet due — no submission (→ Upcoming)
    ]

    // MARK: - REL 225 (Teachings of the Book of Mormon)

    private static let relJournalId = 4001
    private static let relQuizId    = 4002

    private static let relAssignmentGroups: [AssignmentGroup] = [
        AssignmentGroup(
            id: relJournalId, name: "Reading Journals", groupWeight: 50, rules: nil,
            assignments: [
                Assignment(id: 4201, name: "Journal — 1 Nephi", pointsPossible: 15,
                           dueAt: "2026-01-16T23:59:00Z", assignmentGroupId: relJournalId),
                Assignment(id: 4202, name: "Journal — Mosiah", pointsPossible: 15,
                           dueAt: "2026-01-30T23:59:00Z", assignmentGroupId: relJournalId),
                Assignment(id: 4203, name: "Journal — Alma", pointsPossible: 15,
                           dueAt: "2026-02-13T23:59:00Z", assignmentGroupId: relJournalId),
                Assignment(id: 4204, name: "Journal — Helaman", pointsPossible: 15,
                           dueAt: "2026-02-27T23:59:00Z", assignmentGroupId: relJournalId),
            ]
        ),
        AssignmentGroup(
            id: relQuizId, name: "Quizzes", groupWeight: 50, rules: nil,
            assignments: [
                Assignment(id: 4301, name: "Quiz — Small Plates", pointsPossible: 25,
                           dueAt: "2026-01-23T23:59:00Z", assignmentGroupId: relQuizId),
                Assignment(id: 4302, name: "Quiz — Words of Mormon through Alma", pointsPossible: 25,
                           dueAt: "2026-02-20T23:59:00Z", assignmentGroupId: relQuizId),
            ]
        ),
    ]

    private static let relSubmissions: [Submission] = [
        Submission(id: 4001, userId: studentUserId, assignmentId: 4201, score: 15,
                   workflowState: "graded", gradedAt: "2026-01-17T09:00:00Z",
                   submittedAt: "2026-01-16T21:00:00Z", submissionComments: nil),
        Submission(id: 4002, userId: studentUserId, assignmentId: 4202, score: 14,
                   workflowState: "graded", gradedAt: "2026-01-31T09:00:00Z",
                   submittedAt: "2026-01-30T22:00:00Z", submissionComments: nil),
        Submission(id: 4003, userId: studentUserId, assignmentId: 4203, score: 15,
                   workflowState: "graded", gradedAt: "2026-02-14T09:00:00Z",
                   submittedAt: "2026-02-13T20:00:00Z", submissionComments: nil),
        Submission(id: 4004, userId: studentUserId, assignmentId: 4301, score: 24,
                   workflowState: "graded", gradedAt: "2026-01-24T09:00:00Z",
                   submittedAt: "2026-01-23T21:00:00Z", submissionComments: nil),
        Submission(id: 4005, userId: studentUserId, assignmentId: 4302, score: nil,
                   workflowState: "submitted", gradedAt: nil,
                   submittedAt: "2026-02-20T22:00:00Z", submissionComments: nil),
        // Journal — Helaman not yet due — no submission (→ Upcoming)
    ]

    // MARK: - Lookups keyed by course ID

    public static let assignmentGroups: [Int: [AssignmentGroup]] = [
        csCourseId:   csAssignmentGroups,
        mathCourseId: mathAssignmentGroups,
        histCourseId: histAssignmentGroups,
        relCourseId:  relAssignmentGroups,
    ]

    public static let submissions: [Int: [Submission]] = [
        csCourseId:   csSubmissions,
        mathCourseId: mathSubmissions,
        histCourseId: histSubmissions,
        relCourseId:  relSubmissions,
    ]

    public static let teacherIds: [Int] = [teacherUserId]

    public static let profile = Profile(id: studentUserId, name: "Demo Student", primaryEmail: "demo.student@example.edu")
}
#endif
