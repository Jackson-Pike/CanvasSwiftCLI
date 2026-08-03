# Phase 1b — Assignments, Announcements, Syllabus, Grade Trend Chart Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

The master design spec (`docs/superpowers/specs/2026-08-01-desktop-app-design.md`, §9) defines **Phase 1 — Course workspace (read)** as: Assignments (list+detail+rubric+comments), Announcements, Syllabus, the expanded Grades tab (assignment table, trend chart, inspector-panel calculator), and the Dashboard. **Phase 1a** (merged: `d043d2a`) delivered the Dashboard and the What-If Sandbox inspector panel. This plan — **Phase 1b** — builds everything else Phase 1 promised: the three still-stubbed course-workspace tabs (`CourseWorkspaceView.swift:37` currently renders `ComingSoonView(title: ..., phase: "a later phase")` for anything but `.grades`) and the Grades tab's missing trend chart (`GradeSnapshot` already exists and is populated by `SyncEngine.applyEnrollment` on every score change, but no view consumes it yet).

Discussions is explicitly **out of scope** — the master spec puts it in Phase 2 (Communication) alongside Inbox/Notifications, and although `CourseTab.discussions` already exists as a case, it stays a `ComingSoonView` stub. Submission upload is Phase 5 — the Assignments detail pane is read-only, no Submit button.

Goal after this plan: every course tab except Discussions/Modules/Files renders real, synced data, and the Grades tab shows a trend line.

## Architecture

New decode/predicate/heuristic logic (rubric formatting, missing-assignment predicate, HTML-render-strategy heuristic) lands as pure, XCTest-covered functions in `CanvasCore`, matching the Phase 1a pattern. New sync/upsert/store logic is covered in `CanvasDataTests` against the existing in-memory `CanvasStore.container(inMemory: true)` + `DEMO` `APIClient` pattern already used by `SyncEngineCourseTests`. SwiftUI stays a thin consumer: value-driven views in `CanvasUI`, small per-tab `ObservableObject` view-models + composition in `CanvasApp`, following `CourseDetailViewModel`'s existing shape (repository read + `session.refresh(.course(id))` trigger) rather than one god view-model.

**Tech stack additions:** `WebKit` and `Charts` imports, both `CanvasUI`-only, both available at the existing macOS 14 floor — no platform bump.

## Global Constraints

- **Test framework:** XCTest only, `@testable import`, mirroring Phase 1a exactly. No app/UI test target exists — `CanvasApp`/`CanvasUI` verified by `swift build` + demo-mode walkthrough. Every testable behavior (decoding, rubric formatting, missing-assignment predicate, the WKWebView-vs-`AttributedString` heuristic, sync upserts) goes in `CanvasCore`/`CanvasData`.
- **Demo verifiability:** every new surface must be walkable end-to-end with `CANVAS_TOKEN=DEMO` — `MockData` grows to cover assignment descriptions, submission types, one rubric, late/missing/excused flags, and announcements.
- **Palette/tokens:** reuse `Sources/CanvasUI/DesignTokens.swift` exclusively, no new tokens. Do **not** reuse `accentHypothetical` for assignment filter chips — that color stays reserved exclusively for what-if values per Phase 1a's own constraint. Active filter chip = `inkPrimary`-on-fill, inactive = `canvasHairline` border, matching `LedgerRowView`'s existing idiom.
- **Deviation from the master spec's API table (justified):** the spec lists a standalone `assignments(courseId:)` call. This plan does not add it — `APIClient.assignmentGroups(courseId:)` already fetches every assignment nested (`include[]=assignments`) in the same request the Grades tab already depends on. Adding a second endpoint would double-fetch the same assignments through two upsert paths. Instead, Task 2 enriches the existing nested fetch with more `include[]` params.
- **Syllabus fetch strategy (justified):** rather than the spec's separate per-course `syllabus(courseId:)` call, extend `APIClient.courses()` with `include[]=syllabus_body` and decode it onto `Course`/write it to `CachedCourse.syllabusBody` (field already exists, unused). `courses()` already fetches every course in one paginated call — a separate per-course call would cost N extra requests for data obtainable for free. TTL stays the existing `.courses` 300s bucket.
- **Announcements — new sync path:** unlike syllabus, announcements need their own endpoint (`discussion_topics?only_announcements=true`) and their own staleness. New `EntityKind.announcements`, TTL **1800s** per spec §2.5, fetched in `syncCourse` as a third `async let` alongside groups/subs, same partial-failure tolerance.
- **`readAt` is device-local:** announcement "viewed" state is a local `CachedAnnouncement.readAt` timestamp set when the detail view is selected — not a round-trip to Canvas's own read-state API. Mirrors how `ChangeRecord.seenAt` already works. A re-sync must never clobber an existing `readAt`.
- **Rubric/late/missing/excused persistence:** `late`/`missing`/`excused`/`attempt` on `CachedSubmission` are plain scalars (mirrors `CachedCourse.applyGroupWeights`). Rubric *criteria* (`CachedAssignment.rubricJSON`) and *assessment results* (`CachedSubmission.rubricAssessmentJSON`) are `Data?` JSON blobs decoded on read, mirroring the existing `CachedCourse.gradingSchemeJSON` pattern.
- **No literal ports; follow existing patterns:** value-driven `public struct … : View` with `public init` in `CanvasUI`; `ObservableObject`/`@Published` view-models in `CanvasApp` (matches `CourseDetailViewModel`, not the `@Observable` style reserved for `Router`); SF Symbols only (`doc.text`, `megaphone`, `list.bullet.rectangle`, `chart.line.uptrend.xyaxis`, `checkmark.seal`, `exclamationmark.triangle`, `clock.badge.checkmark`). No bundled images.
- **No submit button, no discussions:** Assignments detail is strictly read-only. `CourseTab.discussions` keeps falling through to `ComingSoonView`.
- **Existing deep-link entry point:** `router.reveal(.assignment(courseId:assignmentId:))` is already called from `DashboardView.swift` (lines ~264 and ~290, its "awaiting grade"/"recent feedback" panels) — NOT from the course workspace's `StreamSection`/`StreamRow` inside the Grades tab, which is a pure value view with no tap action at all. Task 11's Assignments tab should consume `router.selectedAssignmentId` so that existing Dashboard-panel deep link finally lands somewhere; do not assume `StreamSection` already wires this — it doesn't, and wiring it is optional/out of scope for this plan (nice-to-have, not required for "done").

---

## File Structure

**Create:**
- `Sources/CanvasCore/Rubric.swift` — `RubricCriterion`, `RubricRating`, `RubricAssessmentEntry` Codable structs; `RubricLine` value type; `formatRubricAssessment(criteria:assessment:) -> [RubricLine]`.
- `Sources/CanvasCore/AssignmentPredicates.swift` — `isAssignmentMissing(...)`, `AssignmentFilter` enum (`.upcoming, .missing, .graded, .all`), `assignmentMatchesFilter(...)`.
- `Sources/CanvasCore/RichTextHeuristic.swift` — `htmlNeedsWebView(_ html: String) -> Bool`.
- `Tests/CanvasCoreTests/RubricTests.swift`, `Tests/CanvasCoreTests/AssignmentPredicatesTests.swift`, `Tests/CanvasCoreTests/RichTextHeuristicTests.swift`
- `Sources/CanvasData/Models/AnnouncementModels.swift` — `@Model CachedAnnouncement`.
- `Sources/CanvasUI/RichTextView.swift` — `RichTextView` (AttributedString/WKWebView split).
- `Sources/CanvasUI/AssignmentComponents.swift` — `AssignmentFilterChips`, `AssignmentListRow`, `RubricTable`, `InstructorCommentRow`.
- `Sources/CanvasUI/AnnouncementComponents.swift` — `AnnouncementListRow`.
- `Sources/CanvasUI/GradeTrendChart.swift` — `GradeTrendChart`.
- `CanvasApp/ViewModels/AssignmentsViewModel.swift`, `CanvasApp/ViewModels/AnnouncementsViewModel.swift`
- `CanvasApp/Views/Window/AssignmentsTabView.swift`, `CanvasApp/Views/Window/AnnouncementsTabView.swift`, `CanvasApp/Views/Window/SyllabusTabView.swift`
- `Tests/CanvasDataTests/AnnouncementSyncTests.swift`

**Modify:**
- `Sources/CanvasCore/Models.swift` — extend `Course` (`syllabusBody`), `Assignment` (`descriptionHTML`, `submissionTypes`, `unlockAt`, `lockAt`, `htmlURL`, `rubric`), `Submission` (`late`, `missing`, `excused`, `attempt`, `rubricAssessment`); add `Announcement`, `DiscussionAuthor`.
- `Sources/CanvasCore/APIClient.swift` — extend `courses()` (`include[]=syllabus_body`), `assignmentGroups()` (`include[]=rubric`), `submissions()` (`include[]=rubric_assessment`); add `announcements(courseId:)`.
- `Sources/CanvasCore/MockData.swift` — descriptions/submission types/one rubric/late-missing-excused flags/announcements/syllabus bodies.
- `Sources/CanvasData/Models/CourseModels.swift` — `CachedAssignment` gains `descriptionHTML`, `submissionTypes: [String]`, `unlockAt/lockAt: Date?`, `htmlURL: String?`, `rubricJSON: Data?` (+ computed `.rubric`).
- `Sources/CanvasData/Models/SubmissionModels.swift` — `CachedSubmission` gains `late/missing/excused: Bool`, `attempt: Int?`, `rubricAssessmentJSON: Data?` (+ computed `.rubricAssessment`).
- `Sources/CanvasData/CanvasStore.swift` — add `CachedAnnouncement.self` to the `Schema([...])` array.
- `Sources/CanvasData/SyncEngine.swift` — `EntityKind.announcements` + TTL 1800s; extend `upsertGroups`/`upsertSubmissions`; write `syllabusBody` in `upsertCourses`; new `upsertAnnouncements` + third `async let` in `syncCourse`.
- `Sources/CanvasData/CanvasRepository.swift` — `announcements(courseId:)`, `markAnnouncementRead(_:now:)`, `assignment(id:)`, `submission(assignmentId:)`; update `clearStore()` to delete `CachedAnnouncement`.
- `CanvasApp/Views/Window/CourseWorkspaceView.swift` — wire `.assignments`/`.announcements`/`.syllabus`; add `GradeTrendChart` into `GradesSandboxSplit.mainColumn` after `groupsSection`; add `@Environment(AppSession.self)` to `GradesSandboxSplit`.
- `Tests/CanvasCoreTests/ModelsTests.swift`, `Tests/CanvasCoreTests/APIClientDemoTests.swift`, `Tests/CanvasDataTests/SyncEngineCourseTests.swift`, `Tests/CanvasDataTests/RepositoryTests.swift` — extended coverage.

No changes needed to `CanvasApp/App/Router.swift` (`CourseTab`, `RevealTarget.assignment`, `selectedAssignmentId` already exist) or `Sources/CanvasData/DerivedReads.swift` (new tabs read `CanvasRepository` directly, not `StreamItem`).

---

## Task Dependency Order

Tasks 1–3 (`CanvasCore`, TDD) are independent and may run in parallel. Task 4 (`CanvasData` models) depends on Task 1. Task 5 (`SyncEngine`) depends on 1, 2, 4. Task 6 (`CanvasRepository` + `MockData`) depends on 4–5. Tasks 7–10 (`CanvasUI` value views) depend only on Task 1/2 pure types and can run in parallel with each other. Tasks 11–13 (`CanvasApp` view-models + tab views) depend on Task 6 and Tasks 7–10. Task 14 (final wiring into `CourseWorkspaceView`) depends on everything above and runs last.

---

### Task 1: Extend Codable models — Assignment, Submission, Course, Announcement, Rubric (`CanvasCore`)

**Files:** Modify `Sources/CanvasCore/Models.swift`; Create `Sources/CanvasCore/Rubric.swift`; Test `Tests/CanvasCoreTests/ModelsTests.swift` (extend), `Tests/CanvasCoreTests/RubricTests.swift`

```swift
// Models.swift additions
public struct Course: Codable {
    // existing fields...
    public let syllabusBody: String?   // decodes "syllabus_body" via existing .convertFromSnakeCase
}

public struct Assignment: Codable {
    // existing fields...
    enum CodingKeys: String, CodingKey {
        case id, name, pointsPossible, dueAt, assignmentGroupId
        case descriptionHTML = "description"
        case submissionTypes, unlockAt, lockAt
        case htmlURL = "htmlUrl"   // .convertFromSnakeCase turns "html_url" -> "htmlUrl"
        case rubric
    }
    public let descriptionHTML: String?
    public let submissionTypes: [String]?
    public let unlockAt: String?
    public let lockAt: String?
    public let htmlURL: String?
    public let rubric: [RubricCriterion]?
}

public struct Submission: Codable {
    // existing fields...
    public let late: Bool?
    public let missing: Bool?
    public let excused: Bool?
    public let attempt: Int?
    public let rubricAssessment: [String: RubricAssessmentEntry]?   // "rubric_assessment"
}

public struct DiscussionAuthor: Codable { public let displayName: String? }
public struct Announcement: Codable {
    public let id: Int
    public let title: String
    public let message: String?
    public let postedAt: String?
    public let author: DiscussionAuthor?
}
```

```swift
// Rubric.swift
public struct RubricRating: Codable { public let id: String; public let description: String; public let points: Double }
public struct RubricCriterion: Codable { public let id: String; public let description: String; public let points: Double; public let ratings: [RubricRating]? }
public struct RubricAssessmentEntry: Codable { public let points: Double?; public let comments: String?; public let ratingId: String? }
public struct RubricLine { public let criterionDescription: String; public let possiblePoints: Double; public let earnedPoints: Double?; public let ratingLabel: String?; public let comment: String? }

public func formatRubricAssessment(criteria: [RubricCriterion], assessment: [String: RubricAssessmentEntry]) -> [RubricLine] {
    criteria.map { c in
        let entry = assessment[c.id]
        let ratingLabel = entry?.ratingId.flatMap { rid in c.ratings?.first { $0.id == rid }?.description }
        return RubricLine(criterionDescription: c.description, possiblePoints: c.points,
                          earnedPoints: entry?.points, ratingLabel: ratingLabel, comment: entry?.comments)
    }
}
```

- [ ] **Step 1:** Write failing tests in `ModelsTests.swift` — decode fixture JSON for `Course` (with `syllabus_body`), `Assignment` (`description`, `submission_types`, `unlock_at`, `lock_at`, `html_url`, nested `rubric`), `Submission` (`late`, `missing`, `excused`, `attempt`, `rubric_assessment`), `Announcement` (`posted_at`, nested `author.display_name`). `RubricTests.swift`: `testFormatRubricAssessmentJoinsRatingAndComment` — 2 criteria, 1 assessed, 1 unassessed (nil earned/comment).
- [ ] **Step 2:** Run `swift test --filter ModelsTests --filter RubricTests` — confirm failure.
- [ ] **Step 3:** Implement the additions above.
- [ ] **Step 4:** Run again — confirm pass.
- [ ] **Step 5:** Commit — `git commit -m "feat(core): extend Assignment/Submission/Course models, add Announcement and Rubric types"`

---

### Task 2: Missing-assignment predicate + rich-text render heuristic (`CanvasCore`)

**Files:** Create `Sources/CanvasCore/AssignmentPredicates.swift`, `Sources/CanvasCore/RichTextHeuristic.swift`; Test `Tests/CanvasCoreTests/AssignmentPredicatesTests.swift`, `Tests/CanvasCoreTests/RichTextHeuristicTests.swift`

```swift
// AssignmentPredicates.swift
public func isAssignmentMissing(dueAt: Date?, submissionWorkflowState: String?, missingFlag: Bool?, now: Date) -> Bool {
    if missingFlag == true { return true }
    guard let due = dueAt, due < now else { return false }
    return submissionWorkflowState == nil || submissionWorkflowState == "unsubmitted"
}

public enum AssignmentFilter: String, CaseIterable { case upcoming, missing, graded, all }

public func assignmentMatchesFilter(_ filter: AssignmentFilter, dueAt: Date?, workflowState: String?,
                                    score: Double?, missingFlag: Bool?, now: Date) -> Bool {
    switch filter {
    case .all: return true
    case .missing: return isAssignmentMissing(dueAt: dueAt, submissionWorkflowState: workflowState, missingFlag: missingFlag, now: now)
    case .graded: return workflowState == "graded" && score != nil
    case .upcoming: return (dueAt.map { $0 >= now }) ?? false
    }
}
```

```swift
// RichTextHeuristic.swift
/// True when `html` needs the sandboxed WKWebView fallback (tables, iframes, embedded
/// media, LaTeX/MathJax) rather than `AttributedString(html:)`, which only renders
/// simple inline markup and silently drops anything else.
public func htmlNeedsWebView(_ html: String) -> Bool {
    let lower = html.lowercased()
    let complexTags = ["<table", "<iframe", "<script", "<video", "<audio", "<embed", "<object"]
    if complexTags.contains(where: lower.contains) { return true }
    if lower.contains("\\(") || lower.contains("\\[") || lower.contains("class=\"math") { return true }
    return false
}
```

- [ ] **Step 1:** Write failing tests: predicate cases — past-due/no submission → missing; past-due/`workflowState=="unsubmitted"` → missing; `missingFlag==true` overrides even a future due date (trust the server flag); future due date → not missing; graded → not missing. `assignmentMatchesFilter` table-tested against all four filters. Heuristic: plain `<p><strong>` markup → `false`; `<table>` → `true`; `\(x^2\)` → `true`; `<iframe>` → `true`.
- [ ] **Step 2:** Run to verify failure.
- [ ] **Step 3:** Implement as above.
- [ ] **Step 4:** Run `swift test --filter AssignmentPredicatesTests --filter RichTextHeuristicTests` — confirm pass.
- [ ] **Step 5:** Commit — `git commit -m "feat(core): missing-assignment predicate, filter matcher, HTML render-strategy heuristic"`

---

### Task 3: APIClient extensions — richer includes + announcements (`CanvasCore`)

**Files:** Modify `Sources/CanvasCore/APIClient.swift`, `Sources/CanvasCore/MockData.swift`; Test `Tests/CanvasCoreTests/APIClientDemoTests.swift` (extend)

```swift
public func courses() async throws -> [Course] {
    // add URLQueryItem(name: "include[]", value: "syllabus_body") to the existing query array
}
public func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
    // add URLQueryItem(name: "include[]", value: "rubric")
}
public func submissions(courseId: Int) async throws -> [Submission] {
    // add URLQueryItem(name: "include[]", value: "rubric_assessment")
}
public func announcements(courseId: Int) async throws -> [Announcement] {
    #if DEBUG
    if token == "DEMO" { return MockData.announcements[courseId] ?? [] }
    #endif
    let data = try await getPaginated("/courses/\(courseId)/discussion_topics", query: [
        URLQueryItem(name: "only_announcements", value: "true"),
        URLQueryItem(name: "per_page", value: "50"),
    ])
    return try decoder().decode([Announcement].self, from: data)
}
```

MockData additions (append, do not restructure existing arrays):
- Give one CS 101 assignment (the Midterm Exam) a `rubric` (2–3 `RubricCriterion`s) and give its matching submission a `rubricAssessment` dict keyed by those criterion ids — the one demo assignment exercising the rubric UI end to end.
- Add `descriptionHTML`/`submissionTypes` to several assignments across all four courses so the Assignments detail pane always has content.
- Add a `missing: true` submission row for one currently-submission-less assignment (e.g. MATH 112 "Quiz 3 — Taylor Series") so the Missing filter has both a submission-backed and an absent-row case.
- New `public static let announcements: [Int: [Announcement]]`, 2 per course, dated relative to `Date()` (mirror the existing `finalExamDueAt` relative-date pattern so demo data doesn't go stale).
- Add a short `syllabusBody` HTML string to each of the four `MockData.courses` entries (needed by Task 13).

- [ ] **Step 1:** Write failing test — `testDemoAnnouncementsReturnsMockData` in `APIClientDemoTests.swift`.
- [ ] **Step 2:** Run to verify failure (`cannot find 'announcements' in scope`).
- [ ] **Step 3:** Implement the three query extensions + `announcements()` + MockData additions above.
- [ ] **Step 4:** Run `swift test --filter APIClientDemoTests` — confirm pass.
- [ ] **Step 5:** Commit — `git commit -m "feat(core): richer assignment/submission includes, syllabus_body on courses(), announcements() call"`

---

### Task 4: CanvasData SwiftData model extensions (`CanvasData`)

**Files:** Modify `Sources/CanvasData/Models/CourseModels.swift`, `Sources/CanvasData/Models/SubmissionModels.swift`, `Sources/CanvasData/CanvasStore.swift`; Create `Sources/CanvasData/Models/AnnouncementModels.swift`

```swift
// CourseModels.swift — CachedAssignment additions
public var descriptionHTML: String?
public var submissionTypes: [String]      // mirrors CachedAssignmentGroup.neverDrop
public var unlockAt: Date?
public var lockAt: Date?
public var htmlURL: String?
public var rubricJSON: Data?
public var rubric: [RubricCriterion] {
    guard let rubricJSON, let r = try? JSONDecoder().decode([RubricCriterion].self, from: rubricJSON) else { return [] }
    return r
}
```

```swift
// SubmissionModels.swift — CachedSubmission additions
public var late: Bool
public var missing: Bool
public var excused: Bool
public var attempt: Int?
public var rubricAssessmentJSON: Data?
public var rubricAssessment: [String: RubricAssessmentEntry] {
    guard let rubricAssessmentJSON, let a = try? JSONDecoder().decode([String: RubricAssessmentEntry].self, from: rubricAssessmentJSON) else { return [:] }
    return a
}
```

```swift
// AnnouncementModels.swift
import Foundation
import SwiftData

@Model
public final class CachedAnnouncement {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var title: String
    public var message: String?
    public var postedAt: Date?
    public var authorName: String?
    public var readAt: Date?
    public var removedAt: Date?

    public init(id: Int, courseId: Int, title: String, message: String?, postedAt: Date?,
               authorName: String?, readAt: Date? = nil, removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.title = title; self.message = message
        self.postedAt = postedAt; self.authorName = authorName; self.readAt = readAt; self.removedAt = removedAt
    }
}
```

`RubricCriterion`/`RubricAssessmentEntry` are `CanvasCore` types — `CourseModels.swift`/`SubmissionModels.swift` already `import CanvasCore` (see existing `byuhDefaultScale` usage), no new import needed.

- [ ] **Step 1:** Add the fields + computed decode properties above to both existing model files; update both `init`s, defaulting new scalars (`false`/`nil`/`[]`) so existing call sites keep compiling until Task 5.
- [ ] **Step 2:** Create `AnnouncementModels.swift`.
- [ ] **Step 3:** Add `CachedAnnouncement.self` to the `Schema([...])` array in `Sources/CanvasData/CanvasStore.swift`.
- [ ] **Step 4:** `swift build` — should succeed in isolation since new fields have defaults; `SyncEngine`'s existing `CachedAssignment(...)`/`CachedSubmission(...)` positional call sites are updated in Task 5, not here.
- [ ] **Step 5:** Commit — `git commit -m "feat(data): extend CachedAssignment/CachedSubmission, add CachedAnnouncement model"`

---

### Task 5: SyncEngine — richer upserts, syllabus write, announcements sync (`CanvasData`)

**Files:** Modify `Sources/CanvasData/SyncEngine.swift`; Test `Tests/CanvasDataTests/SyncEngineCourseTests.swift` (extend), `Tests/CanvasDataTests/AnnouncementSyncTests.swift` (new)

- `EntityKind` gains `case announcements`; `ttl` table gains `.announcements: 1800`.
- `upsertCourses`: after `row.gradingSchemeJSON = schemeJSON`, also set `row.syllabusBody = c.syllabusBody` in both the existing-row and new-row branches.
- `upsertGroups`: in the assignment loop, additionally set `descriptionHTML`, `submissionTypes = a.submissionTypes ?? []`, `unlockAt`/`lockAt` (via `CanvasDate.parse`, same as `dueAt`), `htmlURL`, `rubricJSON = a.rubric.flatMap { try? JSONEncoder().encode($0) }` (nil when `a.rubric == nil`).
- `upsertSubmissions`: additionally set `late = sub.late ?? false`, `missing = sub.missing ?? false`, `excused = sub.excused ?? false`, `attempt = sub.attempt`, `rubricAssessmentJSON = sub.rubricAssessment.flatMap { try? JSONEncoder().encode($0) }`.
- `syncCourse`: change the early-out guard to `guard needAssignments || needSubmissions || needAnnouncements else { return }`; add a third `async let announcementsFetch: [Announcement]` gated by `needAnnouncements = force || !isFresh(.announcements, scope: "\(courseId)", now: now)`, same try/catch/touch/partial-failure pattern as groups/subs.

```swift
private func upsertAnnouncements(_ items: [Announcement], courseId: Int, now: Date) {
    let existing = Dictionary(uniqueKeysWithValues:
        ((try? modelContext.fetch(FetchDescriptor<CachedAnnouncement>(
            predicate: #Predicate<CachedAnnouncement> { $0.courseId == courseId }))) ?? [])
            .map { ($0.id, $0) })
    let fetchedIds = Set(items.map(\.id))
    for a in items {
        let postedAt = CanvasDate.parse(a.postedAt)
        if let row = existing[a.id] {
            row.title = a.title; row.message = a.message; row.postedAt = postedAt
            row.authorName = a.author?.displayName; row.removedAt = nil
        } else {
            modelContext.insert(CachedAnnouncement(id: a.id, courseId: courseId, title: a.title,
                message: a.message, postedAt: postedAt, authorName: a.author?.displayName))
        }
    }
    for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil { row.removedAt = now }
}
```

`readAt` is never touched by sync (device-local) — `upsertAnnouncements` never assigns `row.readAt`, so a re-sync preserves whatever `CanvasRepository.markAnnouncementRead` (Task 6) previously set.

- [ ] **Step 1:** Write failing tests: extend `testCourseSyncPopulatesGroupsAssignmentsSubmissionsComments` — assert the Midterm Exam's `rubric.count > 0` and `descriptionHTML != nil`; assert one submission has `missing == true`; assert the CS midterm submission's `rubricAssessment` is non-empty. New `AnnouncementSyncTests.swift`: `testCourseSyncPopulatesAnnouncements` (count matches `MockData.announcements[courseId]`), `testAnnouncementResyncPreservesReadAt` (sync → `markAnnouncementRead` → force-resync → `readAt` survives).
- [ ] **Step 2:** Run to verify failure.
- [ ] **Step 3:** Implement the changes above.
- [ ] **Step 4:** Run `swift test --filter CanvasDataTests` — confirm pass.
- [ ] **Step 5:** Commit — `git commit -m "feat(data): sync richer assignment/submission fields, syllabus body, announcements with own TTL"`

---

### Task 6: CanvasRepository reads + clearStore (`CanvasData`)

**Files:** Modify `Sources/CanvasData/CanvasRepository.swift`; Test `Tests/CanvasDataTests/RepositoryTests.swift`

```swift
public func announcements(courseId: Int) throws -> [CachedAnnouncement] {
    let predicate = #Predicate<CachedAnnouncement> { $0.courseId == courseId }
    let all = try context.fetch(FetchDescriptor(predicate: predicate))
    return all.filter { $0.removedAt == nil }.sorted { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
}

public func markAnnouncementRead(_ id: Int, now: Date = .init()) throws {
    let predicate = #Predicate<CachedAnnouncement> { $0.id == id }
    guard let row = try context.fetch(FetchDescriptor(predicate: predicate)).first else { return }
    if row.readAt == nil { row.readAt = now; try context.save() }
}

public func assignment(id: Int) throws -> CachedAssignment? {
    let predicate = #Predicate<CachedAssignment> { $0.id == id }
    return try context.fetch(FetchDescriptor(predicate: predicate)).first
}

public func submission(assignmentId: Int) throws -> CachedSubmission? {
    let predicate = #Predicate<CachedSubmission> { $0.assignmentId == assignmentId }
    return try context.fetch(FetchDescriptor(predicate: predicate)).first
}
```

`clearStore()`: add `try context.delete(model: CachedAnnouncement.self)` alongside the other `delete(model:)` calls.

- [ ] **Step 1:** Write failing tests: `testAnnouncementsSortedByPostedAtDescending`, `testMarkAnnouncementReadIsIdempotent` (second call doesn't overwrite an earlier `readAt`), `testClearStoreRemovesAnnouncements`.
- [ ] **Step 2:** Run to verify failure.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run to verify pass.
- [ ] **Step 5:** Commit — `git commit -m "feat(data): repository reads for announcements and single assignment/submission lookups"`

---

### Task 7: `RichTextView` — AttributedString/WKWebView split (`CanvasUI`)

**Files:** Create `Sources/CanvasUI/RichTextView.swift`

```swift
public struct RichTextView: View {
    public init(html: String, linkBaseURL: URL? = nil) { ... }
    public var body: some View { ... }
}
```

- Uses `CanvasCore.htmlNeedsWebView(html)` (Task 2) to choose branch. `false` → build via `NSAttributedString(data:options:documentAttributes:)` with `.documentType: .html`, wrap in `AttributedString`, apply `.foregroundStyle(Color.inkPrimary)`/default font since inline HTML styles won't pick up dynamic tokens. `true` → an `NSViewRepresentable` wrapping `WKWebView`: `WKWebpagePreferences.allowsContentJavaScript = false`; a `navigationDelegate` that intercepts every non-initial navigation (`decidePolicyFor:` → `.cancel` + `NSWorkspace.shared.open(url)`, `.allow` only for the initial `loadHTMLString` load); height driven by reading `document.body.scrollHeight` via `evaluateJavaScript` after `didFinish` (safe even with content-JS disabled — that flag blocks scripts *embedded in the loaded HTML*, not our own driver calls). Inject a small `<style>color-scheme: light dark;</style>` block (plus token-matching background/text colors) before `loadHTMLString` so dark mode doesn't render a white box.
- Both branches wrapped in a shared `padding(16)` / `Color.canvasPanel` background container so callers (Assignment detail, Announcement detail, Syllabus) don't reimplement chrome.
- [ ] **Step 1:** Implement both branches + `#if DEBUG` preview with one simple-HTML and one table-HTML sample, both color schemes.
- [ ] **Step 2:** `swift build` — clean.
- [ ] **Step 3:** Manual check — drop a table-HTML sample into a preview canvas, confirm it renders via the web view, not a text dump.
- [ ] **Step 4:** Commit — `git commit -m "feat(ui): RichTextView with AttributedString/WKWebView split and sandboxed link handling"`

---

### Task 8: Assignments-tab components (`CanvasUI`)

**Files:** Create `Sources/CanvasUI/AssignmentComponents.swift`

```swift
public struct AssignmentFilterChips: View {
    public init(selected: Binding<AssignmentFilter>) { ... }
}
public struct AssignmentListRow: View {
    public init(name: String, dueAt: Date?, pointsPossible: Double?, score: Double?,
               workflowState: String?, isMissing: Bool, isSelected: Bool, onTap: @escaping () -> Void) { ... }
}
public struct RubricTable: View {
    public init(lines: [RubricLine]) { ... }
}
public struct InstructorCommentRow: View {
    public init(authorName: String, comment: String, createdAt: Date?) { ... }
}
```

No handoff doc exists for Phase 1b, so follow existing `LedgerRowView`/`StreamSection`/`DashboardPanels` conventions rather than inventing a new idiom: `AssignmentListRow` — 1px top hairline divider like `LedgerRowView`; name 13pt `inkPrimary`; due date + points 10.5pt `inkTertiary` subtitle; right-aligned score/state badge (percent in `letterGradeColor`, or a small "Missing" capsule using the `lost` token when `isMissing`); selected row gets `inkPrimary`@4% background, same as `LedgerRowView`'s hover fill. `RubricTable` — one row per `RubricLine`: criterion left, `earned/possible` mono right, `ratingLabel` as an `inkTertiary` caption beneath, `comment` (if present) as an indented `inkSecondary` line. `InstructorCommentRow` reuses `DashboardPanels`' `RecentFeedbackPanel` comment-row grammar (initials circle, author bold + comment beneath) rather than inventing a third style.

- [ ] **Step 1:** Implement all four views + `#if DEBUG` previews in both color schemes (include one `isMissing: true` row, one partially-graded rubric).
- [ ] **Step 2:** `swift build` — clean.
- [ ] **Step 3:** Commit — `git commit -m "feat(ui): assignments-tab list row, filter chips, rubric table, comment row"`

---

### Task 9: Announcements-tab components (`CanvasUI`)

**Files:** Create `Sources/CanvasUI/AnnouncementComponents.swift`

```swift
public struct AnnouncementListRow: View {
    public init(title: String, authorName: String?, postedAt: Date?, isUnread: Bool, isSelected: Bool, onTap: @escaping () -> Void) { ... }
}
```

Unread rows show a small 6pt filled `inkPrimary` dot left of the title; read rows show none. Same divider/selected-highlight treatment as `AssignmentListRow`. Detail rendering reuses `RichTextView` directly inside `AnnouncementsTabView` (Task 12) — no separate detail component needed.

- [ ] **Step 1:** Implement + preview (unread/read states, both schemes).
- [ ] **Step 2:** `swift build` — clean.
- [ ] **Step 3:** Commit — `git commit -m "feat(ui): announcements-tab list row"`

---

### Task 10: Grade trend chart (`CanvasUI`)

**Files:** Create `Sources/CanvasUI/GradeTrendChart.swift`

```swift
import Charts
public struct GradeTrendChart: View {
    public struct Point: Identifiable { public let id = UUID(); public let date: Date; public let percent: Double
        public init(date: Date, percent: Double) { self.date = date; self.percent = percent } }
    public init(points: [Point], gradingScale: [(String, Double)]) { ... }
}
```

Takes a pre-mapped `[Point]` value type (not `GradeSnapshot` directly — `CanvasUI` must not depend on `CanvasData`, same reason `DashboardPanels` takes pre-mapped values). Caller (Task 14) maps `[GradeSnapshot]` → `[Point]`. Renders a `Chart` with a `LineMark` (`inkPrimary`, `.interpolationMethod(.monotone)`) + `PointMark`s per snapshot; faint `RuleMark`s at the grading-scale letter thresholds, labeled in `inkTertiary`, so a grade-letter crossing reads directly off the chart without a legend. Empty/single-point state (new course, 0–1 grade changes) shows a centered `Text("Not enough history yet — check back after your next graded assignment.")` in `inkTertiary` instead of a degenerate chart.

- [ ] **Step 1:** Implement + preview (≈8 synthetic upward-trending points, both color schemes, plus the empty-state preview).
- [ ] **Step 2:** `swift build` — clean.
- [ ] **Step 3:** Commit — `git commit -m "feat(ui): grade trend chart with letter-threshold gridlines"`

---

### Task 11: `AssignmentsViewModel` + `AssignmentsTabView` (`CanvasApp`)

**Files:** Create `CanvasApp/ViewModels/AssignmentsViewModel.swift`, `CanvasApp/Views/Window/AssignmentsTabView.swift`

```swift
@MainActor
final class AssignmentsViewModel: ObservableObject {
    let courseId: Int
    @Published var filter: AssignmentFilter = .upcoming
    @Published var rows: [(assignment: CachedAssignment, submission: CachedSubmission?)] = []
    @Published var selectedAssignmentId: Int?
    @Published var comments: [CachedComment] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?

    init(courseId: Int) { self.courseId = courseId }
    func load(session: AppSession, force: Bool = false) async { ... }   // same readFromStore/refresh shape as CourseDetailViewModel
    func select(_ assignmentId: Int) { selectedAssignmentId = assignmentId; loadComments(...) }
    var filteredRows: [...] {
        rows.filter { assignmentMatchesFilter(filter, dueAt: $0.assignment.dueAt, workflowState: $0.submission?.workflowState,
                                              score: $0.submission?.score, missingFlag: $0.submission?.missing, now: .init()) }
    }
}
```

`load(session:force:)` follows `CourseDetailViewModel.load` exactly: instant `readFromStore` render, then `session.refresh(.course(courseId), force:)`, then re-read. `readFromStore` calls `repository.assignments(courseId:)` + `repository.submissions(courseId:)`, zips by `assignmentId` (submission may be nil). `AssignmentsTabView` is a two-pane `HStack`: left = `AssignmentFilterChips` header + `ScrollView` of `AssignmentListRow`s over `filteredRows` (Task 8); right = `RichTextView(html: assignment.descriptionHTML ?? "<p>No description.</p>")` + a metadata block (due/unlock/lock dates, points, submission-types badges, current score/state) + `RubricTable(formatRubricAssessment(criteria: assignment.rubric, assessment: submission.rubricAssessment))` when `!assignment.rubric.isEmpty` + `InstructorCommentRow`s from `comments.filter { $0.authorId != studentUserId }` (student's own id from `session.profile`). On `.task`, if `router.selectedAssignmentId != nil`, call `vm.select(...)` once and clear it — this is where `RevealTarget.assignment`'s existing plumbing (called from `DashboardView.swift`'s panels) finally gets consumed. Loading/error/empty states mirror `GradesTabView`'s `SkeletonList`/`ContentUnavailableView` pattern.

- [ ] **Step 1:** Implement `AssignmentsViewModel`.
- [ ] **Step 2:** Implement `AssignmentsTabView` composing Task 7/8 views.
- [ ] **Step 3:** `swift build` — clean.
- [ ] **Step 4:** Demo check (`CANVAS_TOKEN=DEMO`) — open a course, Assignments tab: filter chips work; CS 101 Midterm Exam shows a populated rubric table; MATH 112 Quiz 3 shows under Missing; an assignment with comments shows the instructor comment row. From the Dashboard's Awaiting Grade / Recent Feedback panels, click an item and confirm it deep-links into that course's Assignments tab with the item pre-selected.
- [ ] **Step 5:** Commit — `git commit -m "feat(app): Assignments tab — filtered list, detail pane, rubric, comments"`

---

### Task 12: `AnnouncementsViewModel` + `AnnouncementsTabView` (`CanvasApp`)

**Files:** Create `CanvasApp/ViewModels/AnnouncementsViewModel.swift`, `CanvasApp/Views/Window/AnnouncementsTabView.swift`

```swift
@MainActor
final class AnnouncementsViewModel: ObservableObject {
    let courseId: Int
    @Published var announcements: [CachedAnnouncement] = []
    @Published var selectedId: Int?
    @Published var isLoading = false
    @Published var error: String?
    init(courseId: Int) { self.courseId = courseId }
    func load(session: AppSession, force: Bool = false) async { ... }
    func markSelectedRead(session: AppSession) { ... }   // repository.markAnnouncementRead, then update local readAt
}
```

Same `load` shape as Task 11. `AnnouncementsTabView`: two-pane `HStack` — left `ScrollView` of `AnnouncementListRow`s (`isUnread: row.readAt == nil`); right = title (16pt/700 `inkPrimary`) + `authorName · postedAt` 11pt `inkTertiary` subtitle + `RichTextView(html: announcement.message ?? "")`. `.task(id: vm.selectedId)` calls `vm.markSelectedRead(session:)` — "readAt set on view" as a side effect of selection, per spec §5.3, not a separate button.

- [ ] **Step 1:** Implement view-model.
- [ ] **Step 2:** Implement tab view.
- [ ] **Step 3:** `swift build` — clean.
- [ ] **Step 4:** Demo check — open Announcements, confirm the unread dot disappears on view and stays gone across a tab switch and an app relaunch (persisted `readAt`).
- [ ] **Step 5:** Commit — `git commit -m "feat(app): Announcements tab — list, detail, local read tracking"`

---

### Task 13: Syllabus tab (`CanvasApp`)

**Files:** Create `CanvasApp/Views/Window/SyllabusTabView.swift`

```swift
struct SyllabusTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @State private var syllabusBody: String?
    var body: some View { ... }   // ScrollView { RichTextView(html: syllabusBody ?? "<p>No syllabus posted.</p>") }
}
```

No dedicated view-model — reads `session.repository.course(id: courseId)?.syllabusBody` directly in `.task`, matching the "smallest thing that works" bar the codebase already sets (`CourseSettingsStore` in Phase 1a similarly skipped a view-model where a direct store read sufficed). Syllabus data arrives for free via the existing course sync (Task 5's `upsertCourses` change) — no extra refresh call needed; if `syllabusBody == nil`, show a one-line fallback (`"Syllabus not yet loaded — open the Grades tab to sync this course."`) rather than triggering a redundant fetch.

- [ ] **Step 1:** Implement. Confirm Task 3 added a `syllabusBody` to every `MockData.courses` entry (it's the only consumer — add now if missed).
- [ ] **Step 2:** `swift build` — clean.
- [ ] **Step 3:** Demo check — Syllabus tab renders the seeded HTML for each demo course.
- [ ] **Step 4:** Commit — `git commit -m "feat(app): Syllabus tab"`

---

### Task 14: Wire all three tabs + Grades trend chart into `CourseWorkspaceView` (`CanvasApp`)

**Files:** Modify `CanvasApp/Views/Window/CourseWorkspaceView.swift`

- [ ] **Step 1:** Replace the `else { ComingSoonView(...) }` branch:
```swift
if router.courseTab == .grades {
    GradesTabView(vm: vm, onFixCredentials: { showSettings = true })
} else if router.courseTab == .assignments {
    AssignmentsTabView(courseId: courseId)
} else if router.courseTab == .announcements {
    AnnouncementsTabView(courseId: courseId)
} else if router.courseTab == .syllabus {
    SyllabusTabView(courseId: courseId)
} else {
    ComingSoonView(title: router.courseTab.rawValue.capitalized, phase: "a later phase")
}
```
The trailing `ComingSoonView` now covers only `.discussions`, `.modules`, `.files`.
- [ ] **Step 2:** In `GradesSandboxSplit`, add `@Environment(AppSession.self) private var session` (it's already inside the same view tree as `CourseWorkspaceBody`, which has it — plain environment read, no upstream plumbing change). In `mainColumn`, insert a `trendSection` between `groupsSection` and `assignmentsSection`:
```swift
private var trendSection: some View {
    let snapshots = (try? session.repository.gradeSnapshots(courseId: vm.courseId)) ?? []
    let points = snapshots.map { GradeTrendChart.Point(date: $0.capturedAt, percent: $0.percent) }
    return VStack(alignment: .leading, spacing: 6) {
        Text("TREND").font(.sectionLabel).tracking(0.6).foregroundStyle(Color.inkSecondary)
        GradeTrendChart(points: points, gradingScale: calc.gradingScale)
            .frame(height: 160)
    }
}
```
(`GradesSandboxSplit` needs a `courseId`/`vm.courseId` reference — thread it through if `vm` isn't already accessible at this scope; check the existing `GradesTabView`→`GradesSandboxSplit` init and extend it if needed rather than assuming.)
- [ ] **Step 3:** `swift build` — clean.
- [ ] **Step 4:** Demo check — every tab in the segmented picker shows real content except Discussions/Modules/Files. Note: fresh demo data may show the trend chart's empty state, since `GradeSnapshot` rows are only written on a real score *change* — to exercise the populated chart, temporarily edit a `MockData.enrollments[...]` score, rerun, and revert (a demo-data limitation, not a bug — call this out to whoever verifies).
- [ ] **Step 5:** Commit — `git commit -m "feat(app): wire Assignments/Announcements/Syllabus tabs and grade trend chart into the course workspace"`

---

## Verification

**Build:**
```bash
swift build
```
Expected: clean build.

**Unit tests:**
```bash
swift test --filter CanvasCoreTests
swift test --filter CanvasDataTests
```
Expected: all pass, including every new/extended test file listed above.

**Demo-mode walkthrough** (`CANVAS_TOKEN=DEMO`, run the app target):
1. Open any course → **Assignments** tab: filter chips work; CS 101 Midterm Exam shows a populated rubric; MATH 112 Quiz 3 shows under Missing; comments render.
2. From the Dashboard's Awaiting Grade / Recent Feedback panels, click an item and confirm it deep-links into Assignments with that item pre-selected.
3. **Announcements** — unread dot clears on view, stays cleared after relaunch.
4. **Syllabus** — renders HTML, not raw tags.
5. **Grades** — new TREND section appears below Groups (see Task 14 Step 4 note on forcing a second snapshot in demo mode to see a populated line).
6. Toggle light/dark appearance in Settings, re-check all four new surfaces — especially `RichTextView`'s WKWebView branch (must not render a white box in dark mode).

### Critical Files for Implementation

- `Sources/CanvasCore/Models.swift` — every new field flows from these Codable shapes.
- `Sources/CanvasData/SyncEngine.swift` — single convergence point for all new fetch/upsert/TTL logic; get this wrong and it breaks the existing Grades-tab sync too.
- `Sources/CanvasData/CanvasRepository.swift` — the only read surface every new tab's view-model goes through.
- `CanvasApp/Views/Window/CourseWorkspaceView.swift` — final wiring point for all three tabs and the trend chart; also where `GradesSandboxSplit` needs the `AppSession` environment addition.
- `Sources/CanvasUI/RichTextView.swift` — shared by Assignments, Announcements, and Syllabus; get the WKWebView sandboxing right once here rather than three times.
