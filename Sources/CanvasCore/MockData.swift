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
               applyAssignmentGroupWeights: true, gradingScheme: nil,
               syllabusBody: "<p>Welcome to <strong>CS 101</strong>. We meet MWF and cover programming fundamentals, culminating in a midterm and final exam. Late work is accepted up to 3 days late for a 10% penalty per day.</p>"),
        Course(id: mathCourseId, name: "Calculus II", courseCode: "MATH 112",
               applyAssignmentGroupWeights: true, gradingScheme: nil,
               syllabusBody: "<p><strong>MATH 112 — Calculus II</strong> covers integration techniques, series, and polar coordinates. Weekly problem sets and quizzes count for half the grade; midterm and final exams count for the other half.</p>"),
        Course(id: histCourseId, name: "World Civilizations", courseCode: "HIST 201",
               applyAssignmentGroupWeights: true, gradingScheme: nil,
               syllabusBody: "<p><strong>HIST 201</strong> surveys world civilizations from antiquity through the age of exploration. Grades are based on discussion participation, two research papers, and two exams.</p>"),
        Course(id: relCourseId, name: "Teachings of the Book of Mormon", courseCode: "REL 225",
               applyAssignmentGroupWeights: true, gradingScheme: nil,
               syllabusBody: "<p><strong>REL 225</strong> studies the Book of Mormon through weekly reading journals and quizzes. There is no final exam; the reading journal and quiz grades are weighted equally.</p>"),
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

    // Rubric on the CS 101 Midterm Exam — the one demo assignment exercising the rubric UI end to end.
    private static let midtermRubric: [RubricCriterion] = [
        RubricCriterion(id: "crit_correctness", description: "Correctness of solutions", points: 50,
                         ratings: [
                            RubricRating(id: "r_full", description: "Fully correct", points: 50),
                            RubricRating(id: "r_partial", description: "Partially correct", points: 30),
                            RubricRating(id: "r_none", description: "Incorrect", points: 0),
                         ]),
        RubricCriterion(id: "crit_style", description: "Code style & readability", points: 30,
                         ratings: [
                            RubricRating(id: "s_clean", description: "Clean and idiomatic", points: 30),
                            RubricRating(id: "s_messy", description: "Works but messy", points: 15),
                         ]),
        RubricCriterion(id: "crit_docs", description: "Comments & documentation", points: 20,
                         ratings: [
                            RubricRating(id: "d_thorough", description: "Thorough", points: 20),
                            RubricRating(id: "d_sparse", description: "Sparse", points: 10),
                            RubricRating(id: "d_missing", description: "Missing", points: 0),
                         ]),
    ]

    private static let csAssignmentGroups: [AssignmentGroup] = [
        AssignmentGroup(
            id: hwId, name: "Homework", groupWeight: 30, rules: nil,
            assignments: [
                Assignment(id: 201, name: "Week 1 Reflection", pointsPossible: 20,
                           dueAt: "2026-01-15T23:59:00Z", assignmentGroupId: hwId,
                           descriptionHTML: "<p>Write a one-page reflection on this week's reading covering variables, types, and control flow.</p>",
                           submissionTypes: ["online_text_entry"]),
                Assignment(id: 202, name: "Week 2 Reflection", pointsPossible: 20,
                           dueAt: "2026-01-22T23:59:00Z", assignmentGroupId: hwId,
                           descriptionHTML: "<p>Reflect on functions, scope, and recursion from this week's lectures.</p>",
                           submissionTypes: ["online_text_entry"]),
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
                           dueAt: "2026-01-20T23:59:00Z", assignmentGroupId: qzId,
                           descriptionHTML: "<p>Timed quiz covering variable declarations, types, and scope.</p>",
                           submissionTypes: ["online_quiz"]),
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
                           dueAt: "2026-03-01T23:59:00Z", assignmentGroupId: exId,
                           descriptionHTML: "<p>Closed-book midterm covering everything through Week 6, graded with the attached rubric.</p>",
                           submissionTypes: ["online_upload"], rubric: midtermRubric),
                Assignment(id: 402, name: "Final Exam",   pointsPossible: 100,
                           dueAt: finalExamDueAt,          assignmentGroupId: exId,
                           descriptionHTML: "<p>Comprehensive final exam covering the full semester.</p>",
                           submissionTypes: ["online_upload"]),
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
        // Midterm carries a full rubric assessment, keyed by the criterion ids on assignment 401's rubric.
        Submission(id: 1008, userId: studentUserId, assignmentId: 401, score: 85,
                   workflowState: "graded", gradedAt: "2026-03-05T12:00:00Z",
                   submittedAt: "2026-03-01T22:00:00Z", submissionComments: nil,
                   rubricAssessment: [
                       "crit_correctness": RubricAssessmentEntry(points: 45, comments: "Minor logic error in problem 3.", ratingId: "r_partial"),
                       "crit_style": RubricAssessmentEntry(points: 25, comments: nil, ratingId: "s_messy"),
                       "crit_docs": RubricAssessmentEntry(points: 15, comments: "Add more inline comments next time.", ratingId: "d_sparse"),
                   ]),
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
                           dueAt: "2026-01-16T23:59:00Z", assignmentGroupId: mathPsId,
                           descriptionHTML: "<p>Problems 1–12 from Chapter 7 covering u-substitution and integration by parts.</p>",
                           submissionTypes: ["online_upload"]),
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
                           dueAt: "2026-02-20T23:59:00Z", assignmentGroupId: mathQzId,
                           descriptionHTML: "<p>Covers Taylor and Maclaurin series expansions.</p>",
                           submissionTypes: ["online_quiz"]),
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
        Submission(id: 2006, userId: studentUserId, assignmentId: 2401, score: 68,
                   workflowState: "graded", gradedAt: "2026-03-02T12:00:00Z",
                   submittedAt: "2026-02-27T21:00:00Z", submissionComments: nil),
        // Quiz 3 was never submitted; explicit missing row exercises the "absent-row" Missing case
        // (grade-neutral: score is nil here exactly as it was when no row existed at all).
        Submission(id: 2007, userId: studentUserId, assignmentId: 2303, score: nil,
                   workflowState: "unsubmitted", gradedAt: nil,
                   submittedAt: nil, submissionComments: nil, missing: true),
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
                           dueAt: "2026-02-04T23:59:00Z", assignmentGroupId: histPaperId,
                           descriptionHTML: "<p>5-page research paper analyzing the rise and fall of one ancient empire, with at least three primary sources.</p>",
                           submissionTypes: ["online_upload"]),
                Assignment(id: 3302, name: "Paper 2 — Age of Exploration", pointsPossible: 50,
                           dueAt: "2026-03-11T23:59:00Z", assignmentGroupId: histPaperId,
                           descriptionHTML: "<p>5-page research paper on a topic from the Age of Exploration.</p>",
                           submissionTypes: ["online_upload"]),
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
                           dueAt: "2026-01-16T23:59:00Z", assignmentGroupId: relJournalId,
                           descriptionHTML: "<p>Reading journal entry reflecting on 1 Nephi 1–22.</p>",
                           submissionTypes: ["online_text_entry"]),
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

    public static var submissions: [Int: [Submission]] = [
        csCourseId:   csSubmissions,
        mathCourseId: mathSubmissions,
        histCourseId: histSubmissions,
        relCourseId:  relSubmissions,
    ]

    public static let teacherIds: [Int] = [teacherUserId]

    // MARK: - Announcements

    private static func announcementDate(daysAgo: Double) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(-daysAgo * 24 * 60 * 60))
    }

    public static let announcements: [Int: [Announcement]] = [
        csCourseId: [
            Announcement(id: 5001, title: "Midterm grading complete",
                         message: "Midterm exams have been graded and returned with rubric feedback. Check your submission for details.",
                         postedAt: announcementDate(daysAgo: 3),
                         author: DiscussionAuthor(displayName: "Prof. Demo")),
            Announcement(id: 5002, title: "Office hours moved this week",
                         message: "Office hours are moved to Thursday 2-4pm this week only due to a conference.",
                         postedAt: announcementDate(daysAgo: 10),
                         author: DiscussionAuthor(displayName: "Prof. Demo")),
        ],
        mathCourseId: [
            Announcement(id: 5101, title: "Quiz 3 solutions posted",
                         message: "Solutions for Quiz 3 — Taylor Series are posted. Please review before the next problem set.",
                         postedAt: announcementDate(daysAgo: 2),
                         author: DiscussionAuthor(displayName: "Dr. Kekoa")),
            Announcement(id: 5102, title: "Final exam review session",
                         message: "A review session for the final exam will be held the week before the exam. Location TBD.",
                         postedAt: announcementDate(daysAgo: 8),
                         author: DiscussionAuthor(displayName: "Dr. Kekoa")),
        ],
        histCourseId: [
            Announcement(id: 5201, title: "Paper 2 topic list available",
                         message: "A list of suggested topics for Paper 2 — Age of Exploration is now available.",
                         postedAt: announcementDate(daysAgo: 4),
                         author: DiscussionAuthor(displayName: "Dr. Alaimalo")),
            Announcement(id: 5202, title: "Discussion 3 extended",
                         message: "Discussion 3 — Silk Road Trade has been extended by two days due to popular request.",
                         postedAt: announcementDate(daysAgo: 12),
                         author: DiscussionAuthor(displayName: "Dr. Alaimalo")),
        ],
        relCourseId: [
            Announcement(id: 5301, title: "Reading schedule reminder",
                         message: "Reminder to keep pace with the reading schedule — Helaman journal is due soon.",
                         postedAt: announcementDate(daysAgo: 5),
                         author: DiscussionAuthor(displayName: "Instructor")),
            Announcement(id: 5302, title: "No class Friday",
                         message: "There will be no class this Friday; use the time to work on your reading journal.",
                         postedAt: announcementDate(daysAgo: 15),
                         author: DiscussionAuthor(displayName: "Instructor")),
        ],
    ]

    public static let profile = Profile(id: studentUserId, name: "Demo Student", primaryEmail: "demo.student@example.edu")

    // MARK: - Phase 2 demo store (conversations)

    /// Mutable so demo writes (compose/reply/mark-read) persist for the session.
    public static var conversations: [Conversation] = [
        Conversation(id: 5001, subject: "Lab 3 feedback", workflowState: "unread",
                     lastMessage: "Resubmit the whole PDF so I have a single clean copy to grade. No rush — the revision window is open until Friday.",
                     lastMessageAt: "2026-08-07T08:15:00Z", messageCount: 4, contextName: "BIOL 100",
                     participants: [ConversationParticipant(id: teacherUserId, name: "Dr. Reed"),
                                    ConversationParticipant(id: studentUserId, name: "Demo Student")],
                     messages: nil),
        Conversation(id: 5002, subject: "Office hours", workflowState: "read",
                     lastMessage: "Perfect, I'll be there Thursday. Thanks!",
                     lastMessageAt: "2026-08-04T09:20:00Z", messageCount: 3, contextName: "CS 220",
                     participants: [ConversationParticipant(id: teacherUserId, name: "Prof. Lang"),
                                    ConversationParticipant(id: studentUserId, name: "Demo Student")],
                     messages: nil),
        Conversation(id: 5003, subject: "Withdrawn section", workflowState: "archived",
                     lastMessage: "Archived thread.",
                     lastMessageAt: "2026-07-20T12:00:00Z", messageCount: 1, contextName: "ENGL 101",
                     participants: [ConversationParticipant(id: teacherUserId, name: "Ms. Ová"),
                                    ConversationParticipant(id: studentUserId, name: "Demo Student")],
                     messages: nil),
    ]

    public static var conversationDetails: [Int: Conversation] = [
        5001: Conversation(id: 5001, subject: "Lab 3 feedback", workflowState: "unread",
                           lastMessage: nil, lastMessageAt: "2026-08-07T08:15:00Z", messageCount: 4,
                           contextName: "BIOL 100",
                           participants: [ConversationParticipant(id: teacherUserId, name: "Dr. Reed"),
                                          ConversationParticipant(id: studentUserId, name: "Demo Student")],
                           messages: [
                            ConversationMessage(id: 6001, authorId: studentUserId,
                                                body: "Hi Dr. Reed — I just submitted Lab 3. Before you grade it, is there anything obvious I should fix? I wasn't confident that my independent and dependent variables were labeled correctly on the graph, and I ran out of time to fully clean up the discussion section.",
                                                createdAt: "2026-08-06T17:00:00Z"),
                            ConversationMessage(id: 6002, authorId: teacherUserId,
                                                body: "Nice work overall — this is a real step up from Lab 2, and your data table is clean and easy to follow.\n\nTwo things to look at before the final version. First, on the graph in part 2 your axes are swapped: time is the independent variable, so it belongs on the x-axis, with temperature on the y-axis. Second, your discussion mentions the reaction \"slowed down,\" but the numbers actually show it plateauing — those aren't the same claim, so tie that sentence back to the specific readings at minutes 8–10.\n\nFix those two and you're in good shape. Everything in the methods section is solid.",
                                                createdAt: "2026-08-06T18:30:00Z"),
                            ConversationMessage(id: 6003, authorId: studentUserId,
                                                body: "That makes sense, thank you! I'll flip the axes and rewrite the discussion to talk about the plateau. Quick question — should I resubmit the whole PDF, or just the corrected part 2?",
                                                createdAt: "2026-08-06T19:05:00Z"),
                            ConversationMessage(id: 6004, authorId: teacherUserId,
                                                body: "Resubmit the whole PDF so I have a single clean copy to grade. No rush — the revision window is open until Friday at 11:59pm, and I won't count it late as long as it's in by then.",
                                                createdAt: "2026-08-07T08:15:00Z"),
                           ]),
        5002: Conversation(id: 5002, subject: "Office hours", workflowState: "read",
                           lastMessage: nil, lastMessageAt: "2026-08-04T09:20:00Z", messageCount: 3,
                           contextName: "CS 220",
                           participants: [ConversationParticipant(id: teacherUserId, name: "Prof. Lang"),
                                          ConversationParticipant(id: studentUserId, name: "Demo Student")],
                           messages: [
                            ConversationMessage(id: 6010, authorId: studentUserId,
                                                body: "Hi Prof. Lang — are office hours happening this week? I'm stuck on the recursion problem in the practice set (the one about counting paths through a grid) and I'd love to walk through it with you rather than guess.",
                                                createdAt: "2026-08-03T08:00:00Z"),
                            ConversationMessage(id: 6011, authorId: teacherUserId,
                                                body: "Yes — Thursday 2–4 in my office (Building 3, Room 214) works. Bring what you have so far, even if it's incomplete; the grid-paths problem is a great one to reason about at the whiteboard, and it'll make the memoization topic next week click.",
                                                createdAt: "2026-08-04T09:00:00Z"),
                            ConversationMessage(id: 6012, authorId: studentUserId,
                                                body: "Perfect, I'll be there Thursday. Thanks!",
                                                createdAt: "2026-08-04T09:20:00Z"),
                           ]),
        5003: Conversation(id: 5003, subject: "Withdrawn section", workflowState: "archived",
                           lastMessage: nil, lastMessageAt: "2026-07-20T12:00:00Z", messageCount: 1,
                           contextName: "ENGL 101",
                           participants: [ConversationParticipant(id: teacherUserId, name: "Ms. Ová"),
                                          ConversationParticipant(id: studentUserId, name: "Demo Student")],
                           messages: [ConversationMessage(id: 6020, authorId: teacherUserId,
                                                          body: "Archived thread.", createdAt: "2026-07-20T12:00:00Z")]),
    ]

    private static var demoNextId = 7000

    public static func demoCreateConversation(recipientIds: [Int], subject: String, body: String) -> Conversation {
        demoNextId += 1
        let id = demoNextId
        let now = ISO8601DateFormatter().string(from: Date())
        let detail = Conversation(id: id, subject: subject, workflowState: "read", lastMessage: body,
                                  lastMessageAt: now, messageCount: 1, contextName: "New Message",
                                  participants: [ConversationParticipant(id: studentUserId, name: "Demo Student"),
                                                 ConversationParticipant(id: recipientIds.first ?? teacherUserId, name: "Dr. Reed")],
                                  messages: [ConversationMessage(id: demoNextId + 100000, authorId: studentUserId,
                                                                 body: body, createdAt: now)])
        conversationDetails[id] = detail
        conversations.insert(detail, at: 0)
        return detail
    }

    public static func demoAppendReply(id: Int, body: String) -> Conversation {
        let now = ISO8601DateFormatter().string(from: Date())
        guard var detail = conversationDetails[id] else { return conversations.first! }
        var msgs = detail.messages ?? []
        demoNextId += 1
        msgs.append(ConversationMessage(id: demoNextId + 200000, authorId: studentUserId, body: body, createdAt: now))
        detail = Conversation(id: detail.id, subject: detail.subject, workflowState: "read", lastMessage: body,
                              lastMessageAt: now, messageCount: msgs.count, contextName: detail.contextName,
                              participants: detail.participants, messages: msgs)
        conversationDetails[id] = detail
        return detail
    }

    public static func demoMarkRead(id: Int) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        let c = conversations[idx]
        conversations[idx] = Conversation(id: c.id, subject: c.subject, workflowState: "read",
                                          lastMessage: c.lastMessage, lastMessageAt: c.lastMessageAt,
                                          messageCount: c.messageCount, contextName: c.contextName,
                                          participants: c.participants, messages: c.messages)
    }

    private static var demoFileId = 60000

    public static func demoUploadSlot(name: String, contentType: String) -> UploadTicket {
        UploadTicket(uploadURL: "https://demo.instructure.local/files/upload",
                     uploadParams: [("filename", name), ("content_type", contentType)])
    }

    public static func demoUploadedFileId() -> Int {
        demoFileId += 1
        return demoFileId
    }

    public static func demoCurrentSubmission(courseId: Int, assignmentId: Int) -> Submission {
        if let existing = submissions[courseId]?.first(where: { $0.assignmentId == assignmentId }) {
            return existing
        }
        return Submission(id: demoNextId, userId: studentUserId, assignmentId: assignmentId,
                          score: nil, workflowState: "unsubmitted", gradedAt: nil, submittedAt: nil,
                          submissionComments: nil, attempt: nil)
    }

    public static func demoSubmit(courseId: Int, assignmentId: Int, type: SubmissionType,
                                  text: String?, url: String?, fileIds: [Int]) -> Submission {
        let prior = submissions[courseId]?.first { $0.assignmentId == assignmentId }
        let nextAttempt = (prior?.attempt ?? 0) + 1
        let iso = ISO8601DateFormatter().string(from: Date())
        let updated = Submission(
            id: prior?.id ?? { demoNextId += 1; return demoNextId }(),
            userId: studentUserId, assignmentId: assignmentId,
            score: prior?.score, workflowState: "submitted",
            gradedAt: prior?.gradedAt, submittedAt: iso,
            submissionComments: prior?.submissionComments,
            late: false, missing: false, excused: false, attempt: nextAttempt)
        var list = submissions[courseId] ?? []
        if let idx = list.firstIndex(where: { $0.assignmentId == assignmentId }) { list[idx] = updated }
        else { list.append(updated) }
        submissions[courseId] = list
        return updated
    }

    // MARK: - Phase 2 demo store (discussions)

    public static let discussionTopics: [Int: [DiscussionTopic]] = [
        csCourseId: [
            DiscussionTopic(id: 3001, title: "Week 1 — Introductions",
                            message: "<p>Post a short intro about yourself.</p>",
                            postedAt: "2026-08-01T00:00:00Z", discussionSubentryCount: 3,
                            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/discussion_topics/3001"),
            DiscussionTopic(id: 3002, title: "Project ideas",
                            message: "<p>Share your project proposal here.</p>",
                            postedAt: "2026-08-05T00:00:00Z", discussionSubentryCount: 0,
                            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/discussion_topics/3002"),
        ],
    ]

    public static let discussionViews: [Int: DiscussionView] = [
        3001: DiscussionView(
            view: [
                DiscussionEntryNode(id: 4001, userId: teacherUserId, parentId: nil,
                                    message: "<p>Welcome! Tell us your major.</p>", createdAt: "2026-08-01T01:00:00Z",
                                    replies: [
                                        DiscussionEntryNode(id: 4002, userId: studentUserId, parentId: 4001,
                                                            message: "<p>CS major, second year.</p>",
                                                            createdAt: "2026-08-01T02:00:00Z", replies: nil),
                                    ]),
                DiscussionEntryNode(id: 4003, userId: studentUserId, parentId: nil,
                                    message: "<p>Excited for this course.</p>", createdAt: "2026-08-01T03:00:00Z",
                                    replies: nil),
            ],
            participants: [
                DiscussionParticipant(id: teacherUserId, displayName: "Prof. Lang"),
                DiscussionParticipant(id: studentUserId, displayName: "Demo Student"),
            ]),
        3002: DiscussionView(view: [], participants: []),
    ]

    // MARK: - Phase 3 demo store (planner items & calendar events)

    public static let plannerItems: [PlannerItem] = [
        PlannerItem(
            id: "assignment_201",
            title: "Week 1 Reflection",
            courseId: csCourseId,
            plannableId: 201,
            plannableType: "assignment",
            plannableDate: Date().addingTimeInterval(-7 * 86400),
            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/assignments/201",
            submissions: PlannerSubmissionSummary(submitted: true, graded: true, missing: false),
            plannerOverride: nil
        ),
        PlannerItem(
            id: "assignment_202",
            title: "Missing Lab Report",
            courseId: csCourseId,
            plannableId: 202,
            plannableType: "assignment",
            plannableDate: Date().addingTimeInterval(-2 * 86400),
            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/assignments/202",
            submissions: PlannerSubmissionSummary(submitted: false, graded: false, missing: true),
            plannerOverride: nil
        ),
        PlannerItem(
            id: "assignment_203",
            title: "Midterm Essay",
            courseId: csCourseId,
            plannableId: 203,
            plannableType: "assignment",
            plannableDate: Date().addingTimeInterval(2 * 86400),
            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/assignments/203",
            submissions: PlannerSubmissionSummary(submitted: false, graded: false, missing: false),
            plannerOverride: nil
        ),
        PlannerItem(
            id: "assignment_204",
            title: "Problem Set 3",
            courseId: mathCourseId,
            plannableId: 204,
            plannableType: "assignment",
            plannableDate: Date().addingTimeInterval(12 * 3600),
            htmlUrl: "https://byuh.instructure.com/courses/\(mathCourseId)/assignments/204",
            submissions: PlannerSubmissionSummary(submitted: false, graded: false, missing: false),
            plannerOverride: nil
        ),
        PlannerItem(
            id: "assignment_205",
            title: "Awaiting Grade Homework",
            courseId: histCourseId,
            plannableId: 205,
            plannableType: "assignment",
            plannableDate: Date().addingTimeInterval(-1 * 86400),
            htmlUrl: "https://byuh.instructure.com/courses/\(histCourseId)/assignments/205",
            submissions: PlannerSubmissionSummary(submitted: true, graded: false, missing: false),
            plannerOverride: nil
        )
    ]

    public static let calendarEvents: [CalendarEvent] = [
        CalendarEvent(
            id: 9001,
            title: "CS 101 Study Group",
            contextCode: "course_\(csCourseId)",
            startAt: Date().addingTimeInterval(24 * 3600),
            endAt: Date().addingTimeInterval(25.5 * 3600),
            locationName: "Library Room 204",
            description: "<p>Reviewing midterm materials.</p>",
            htmlUrl: "https://byuh.instructure.com/calendar?event_id=9001"
        ),
        CalendarEvent(
            id: 9002,
            title: "Math Office Hours",
            contextCode: "course_\(mathCourseId)",
            startAt: Date().addingTimeInterval(48 * 3600),
            endAt: Date().addingTimeInterval(49 * 3600),
            locationName: "McKay 120",
            description: "<p>Calculus help session.</p>",
            htmlUrl: "https://byuh.instructure.com/calendar?event_id=9002"
        )
    ]

    // MARK: - Phase 4 demo store (modules, folders, files)

    public static let modules: [Int: [Module]] = [
        csCourseId: [
            Module(
                id: 10101,
                name: "Module 1: Getting Started & Setup",
                position: 1,
                state: "completed",
                unlockAt: nil,
                itemsCount: 3,
                items: [
                    ModuleItem(
                        id: 1001,
                        moduleId: 10101,
                        title: "Course Orientation & Syllabus",
                        position: 1,
                        type: "Page",
                        indent: 0,
                        htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/modules/items/1001",
                        pageUrl: "course-orientation",
                        completionRequirement: CompletionRequirement(type: "must_view", completed: true)
                    ),
                    ModuleItem(
                        id: 1002,
                        moduleId: 10101,
                        title: "Week 1 Reflection",
                        position: 2,
                        type: "Assignment",
                        indent: 1,
                        contentId: 201,
                        htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/modules/items/1002",
                        completionRequirement: CompletionRequirement(type: "must_submit", completed: true)
                    ),
                    ModuleItem(
                        id: 1003,
                        moduleId: 10101,
                        title: "Development Environment Setup Guide",
                        position: 3,
                        type: "File",
                        indent: 1,
                        contentId: 8001,
                        htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/modules/items/1003",
                        completionRequirement: CompletionRequirement(type: "must_view", completed: true)
                    )
                ]
            ),
            Module(
                id: 10102,
                name: "Module 2: Core Concepts & Data Structures",
                position: 2,
                state: "started",
                unlockAt: nil,
                itemsCount: 2,
                items: [
                    ModuleItem(
                        id: 1004,
                        moduleId: 10102,
                        title: "Quiz 1 — Variables & Types",
                        position: 1,
                        type: "Quiz",
                        indent: 0,
                        contentId: 301,
                        htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/modules/items/1004",
                        completionRequirement: CompletionRequirement(type: "min_score", minScore: 20.0, completed: true)
                    ),
                    ModuleItem(
                        id: 1005,
                        moduleId: 10102,
                        title: "Official Swift Language Documentation",
                        position: 2,
                        type: "ExternalUrl",
                        indent: 0,
                        htmlUrl: "https://swift.org/documentation/",
                        externalUrl: "https://swift.org/documentation/",
                        completionRequirement: CompletionRequirement(type: "must_view", completed: false)
                    )
                ]
            )
        ]
    ]

    public static let folders: [Int: [CanvasFolder]] = [
        csCourseId: [
            CanvasFolder(
                id: 5001,
                name: "Course Documents",
                fullName: "course files/Course Documents",
                parentFolderId: nil,
                contextId: csCourseId,
                contextType: "Course",
                filesCount: 2,
                foldersCount: 1,
                updatedAt: Date().addingTimeInterval(-10 * 86400)
            ),
            CanvasFolder(
                id: 5002,
                name: "Lecture Notes",
                fullName: "course files/Course Documents/Lecture Notes",
                parentFolderId: 5001,
                contextId: csCourseId,
                contextType: "Course",
                filesCount: 1,
                foldersCount: 0,
                updatedAt: Date().addingTimeInterval(-5 * 86400)
            )
        ]
    ]

    public static let files: [Int: [CanvasFile]] = [
        csCourseId: [
            CanvasFile(
                id: 8001,
                folderId: 5001,
                displayName: "CS101_Syllabus.pdf",
                filename: "CS101_Syllabus.pdf",
                contentType: "application/pdf",
                url: "https://demo.canvas/CS101_Syllabus.pdf",
                size: 245000,
                createdAt: Date().addingTimeInterval(-20 * 86400),
                updatedAt: Date().addingTimeInterval(-15 * 86400),
                locked: false
            ),
            CanvasFile(
                id: 8002,
                folderId: 5002,
                displayName: "Lecture_01_Overview.pdf",
                filename: "Lecture_01_Overview.pdf",
                contentType: "application/pdf",
                url: "https://demo.canvas/Lecture_01_Overview.pdf",
                size: 1540000,
                createdAt: Date().addingTimeInterval(-10 * 86400),
                updatedAt: Date().addingTimeInterval(-10 * 86400),
                locked: false
            )
        ]
    ]
}
#endif

