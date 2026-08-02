# Canvas Grades — Windowed Desktop App Design Spec

**Date:** 2026-08-01
**Scope:** macOS 14+. A full windowed application sharing one process, one data store, and one component library with the existing menu-bar popover.
**Status:** Approved design. Implementation to be planned separately, phase by phase.

---

## 1. Overview

Today the product is a 380×520 `MenuBarExtra` popover: course grade cards, a per-course activity stream, and a what-if / target-grade calculator, all over an in-memory cache of four Canvas endpoints.

This spec adds a **full windowed Canvas client** — assignments, submissions, announcements, discussions, modules, files, syllabus, inbox, calendar, and to-dos — and restructures the codebase so the popover and the window are two renderings of one underlying application rather than two applications.

Three principles govern the design:

1. **One process, two scenes.** A single `@main App` declares both a `MenuBarExtra` scene and a `Window` scene over one shared session. There is no IPC, no app group, no second bundle.
2. **One writer.** A `SyncEngine` is the only thing that fetches from Canvas and the only thing that writes to the local store. Views observe the store; views never fetch.
3. **Parity without duplication.** Anything both scenes show is a component in a shared UI package, used by both. The popover keeps its full current feature set.

### Non-goals

- iOS. The existing student UX brief contains iOS-specific items; they are out of scope here.
- Instructor/TA workflows. This is a student client.
- Posting to discussions. Discussions are read-only.
- A course roster / People tab.
- Any backend, telemetry, or third-party service. Data flows only between the Mac and Canvas.

---

## 2. Architecture

### 2.1 Package structure

`Package.swift` grows from two targets to four:

```
Sources/CanvasCore/     models, APIClient, GradeCalculator, MockData     (no UI imports)
Sources/CanvasData/     SwiftData schema, CanvasRepository, SyncEngine,
                        ChangeDetector, NotificationScheduler            (depends: CanvasCore)
Sources/CanvasUI/       shared SwiftUI components                        (depends: CanvasCore, CanvasData)
CanvasApp/              @main App, both scenes, AppSession, Router       (depends: all)
```

Test targets: `CanvasCoreTests` (existing, extended), `CanvasDataTests` (new).

Rationale for the split over folder-level separation: `CanvasCore` must stay UI-free so its existing test suite remains fast and headless, and `CanvasUI` must not be able to reach around the repository into the network layer. The compiler enforces both boundaries; folders do not.

### 2.2 Runtime composition

```
CanvasGradesApp (@main)
├── AppSession            credentials, repository, sync engine, demo flag
├── Router                @Observable selection state, shared by both scenes
├── Scene: MenuBarExtra   PopoverContent  — full current feature set
└── Scene: Window         MainWindowView  — NavigationSplitView shell
```

**`AppSession`** replaces today's `AppState`. It owns:

- `credentials: Credentials?` — token + host, loaded from Keychain (see §2.6)
- `repository: CanvasRepository`
- `syncEngine: SyncEngine`
- `isDemo: Bool` — true when the token is the literal `DEMO`
- onboarding flags (`hasSeenIntro`, `hasAcknowledgedKeychain`), preserved from `AppState`

`AppSession` is `@MainActor @Observable`. Both scenes receive it through the environment.

**`Router`** is `@MainActor @Observable`:

```swift
enum SidebarItem: Hashable {
    case dashboard, inbox, calendar, todo
    case course(Int)
}

enum CourseTab: String, CaseIterable, Hashable {
    case grades, assignments, announcements, discussions, modules, files, syllabus
}

@MainActor @Observable
final class Router {
    var sidebar: SidebarItem = .dashboard
    var courseTab: CourseTab = .grades
    var selectedAssignmentId: Int?
    var selectedConversationId: Int?

    func reveal(_ target: RevealTarget)   // sets the above coherently
}
```

`RevealTarget` is a small enum (`.assignment(courseId:assignmentId:)`, `.course(id:tab:)`, `.conversation(id:)`, `.section(SidebarItem)`). The popover calls `router.reveal(...)` then `openWindow(id: "main")`; the window, already observing `Router`, is on the right screen when it appears. One object, two renderings — this is the mechanism that makes the two surfaces feel like one app.

Window restoration: `Router.sidebar` and `courseTab` persist to `UserDefaults` (`@AppStorage`-backed mirror) so relaunch returns to the last view. Item selections do not persist.

### 2.3 Data flow

```
Canvas  ──APIClient──▶  SyncEngine  ──upsert──▶  SwiftData store
                            │                          │
                            ▼                          ▼
                     ChangeDetector            @Query / repository reads
                            │                          │
                            ▼                          ▼
                  NotificationScheduler          Popover + Window
```

Views read from the store and never call `APIClient`. A user-initiated refresh calls `syncEngine.refresh(scope:)`, which fetches, upserts, diffs, and lets the store's change notifications update every observing view in both scenes simultaneously.

This single mechanism is what delivers instant cold start, offline reading, "what changed since you last looked," grade-trend history, and notification triggers. They are not separate features; they are consequences of persisting and diffing every sync.

### 2.4 `CanvasRepository`

The read/write API that `CanvasUI` and the app target program against. It hides SwiftData behind plain-model returns where convenient and exposes `ModelContext` queries where `@Query` is the right tool.

```swift
@MainActor
protocol CanvasRepository {
    var modelContainer: ModelContainer { get }

    func courses(includeHidden: Bool) throws -> [CachedCourse]
    func course(id: Int) throws -> CachedCourse?
    func assignments(courseId: Int, filter: AssignmentFilter) throws -> [CachedAssignment]
    func conversations(scope: ConversationScope) throws -> [CachedConversation]
    func changes(since: Date) throws -> [ChangeRecord]
    func gradeSnapshots(courseId: Int) throws -> [GradeSnapshot]

    func setHidden(_ hidden: Bool, courseId: Int) throws
    func setPinned(_ pinned: Bool, courseId: Int) throws
    func markRead(conversationId: Int) async throws
}
```

`HiddenCoursesStore` (currently `UserDefaults`-backed) is absorbed into the store as a `hidden` flag on `CachedCourse`, with a one-time migration on first launch of the new version.

### 2.5 `SyncEngine`

A `@ModelActor` — it owns its own `ModelContext` off the main actor so syncs never block the UI.

```swift
enum SyncScope {
    case all                      // course list + every enrolled course, shallow
    case course(Int)              // one course, all tabs
    case tab(Int, CourseTab)      // one course, one tab
    case inbox
    case planner                  // calendar + todo
}

actor SyncEngine {
    func refresh(_ scope: SyncScope, force: Bool = false) async throws
    func backgroundTick() async     // periodic; see §6
    var state: SyncState { get }    // .idle / .syncing(SyncScope) / .failed(Error, Date)
}
```

Rules:

- **Freshness gate.** Each entity kind carries a TTL (grades 5 min, assignments 15 min, announcements/discussions 30 min, modules/files/syllabus 6 h, inbox 5 min, planner 15 min). `refresh` skips a fetch whose data is within TTL unless `force`.
- **Fan-out is bounded.** Per-course fetches run through a `TaskGroup` capped at 4 concurrent requests to stay well under Canvas rate limits.
- **Partial failure is normal.** A scope that fetches five endpoints and gets four succeeds. Each entity kind records its own `lastSyncedAt` and `lastError`; the UI surfaces staleness per-section rather than failing the whole screen.
- **Upsert, never replace.** Records are matched on Canvas ID and updated in place so SwiftData identity — and therefore view state and diff history — survives a refresh.
- **Deletion.** Records absent from a full-scope fetch are soft-deleted (`removedAt` set), not hard-deleted, so a transient partial response can't wipe history. Soft-deleted rows older than 90 days are purged at launch.

### 2.6 Credentials and host configuration

`byuh.instructure.com` is currently hardcoded in `APIClient`. It becomes configuration:

```swift
public struct Credentials: Sendable, Equatable {
    public let host: String     // e.g. "byuh.instructure.com" — host only, no scheme or path
    public let token: String
}
```

- `APIClient.init(credentials:)`. All URL construction derives from `https://\(host)/api/v1/...`.
- Onboarding gains a host field, defaulting to `byuh.instructure.com`, with inline validation: trim whitespace, strip a leading `https://` and any trailing path, reject anything that isn't a valid hostname.
- Host is stored in `UserDefaults`; the token stays in the Keychain (`KeychainHelper` unchanged except that the account key becomes host-scoped, so switching schools doesn't collide).
- **Connection test.** After entering credentials the app calls `GET /api/v1/users/self/profile` and shows the returned display name before proceeding — this turns "invalid token" from a runtime failure into an onboarding-time one.
- Changing the host clears the local store (with a confirmation sheet). Multi-account is not supported; one host at a time.

### 2.7 Demo mode

`MockData` grows to cover every new surface: assignments with descriptions and rubrics, announcements, discussion threads, modules, a small file tree, conversations, planner items, and calendar events, plus 30 days of synthetic grade snapshots so the trend chart and "what changed" feed have something to show. `APIClient` continues to short-circuit when `token == "DEMO"`; `SyncEngine` treats demo responses identically, so the persistence, diffing, and notification paths are exercised in demo too. Writes in demo mode (send message, submit) succeed locally against the mock store and never touch the network; the UI shows a subtle "Demo" badge on any confirmation.

Demo mode is the integration harness for this project: **every phase below is considered incomplete until it is fully walkable with `DEMO`.**

---

## 3. Data model (`CanvasData`)

SwiftData `@Model` types. Canvas IDs are the natural keys and are `@Attribute(.unique)` within their type.

| Model | Key fields | Notes |
|---|---|---|
| `CachedCourse` | `id`, `name`, `courseCode`, `applyGroupWeights`, `gradingScheme`, `hidden`, `pinned`, `sortIndex`, `accentColorHex`, `syllabusBody` | Root of most relationships |
| `CachedEnrollment` | `courseId`, `currentScore`, `currentGrade` | Canvas's own computed grade |
| `CachedAssignmentGroup` | `id`, `courseId`, `name`, `groupWeight`, `dropLowest`, `dropHighest`, `neverDrop` | |
| `CachedAssignment` | `id`, `courseId`, `groupId`, `name`, `pointsPossible`, `dueAt`, `unlockAt`, `lockAt`, `descriptionHTML`, `submissionTypes`, `allowedExtensions`, `htmlURL` | |
| `CachedSubmission` | `id`, `assignmentId`, `userId`, `score`, `workflowState`, `gradedAt`, `submittedAt`, `late`, `missing`, `excused`, `rubricAssessmentJSON`, `attempt` | |
| `CachedComment` | `id`, `submissionId`, `authorId`, `authorName`, `body`, `createdAt` | |
| `CachedAnnouncement` | `id`, `courseId`, `title`, `messageHTML`, `postedAt`, `authorName`, `readAt` | |
| `CachedDiscussionTopic` | `id`, `courseId`, `title`, `messageHTML`, `postedAt`, `replyCount`, `unreadCount` | |
| `CachedDiscussionEntry` | `id`, `topicId`, `parentId`, `authorName`, `messageHTML`, `createdAt` | Self-referencing tree |
| `CachedModule` | `id`, `courseId`, `name`, `position`, `state`, `unlockAt` | |
| `CachedModuleItem` | `id`, `moduleId`, `title`, `type`, `contentId`, `htmlURL`, `indent`, `completionState` | `type` maps to a `RevealTarget` where possible |
| `CachedFile` | `id`, `courseId`, `folderId`, `displayName`, `contentType`, `size`, `url`, `updatedAt`, `localPath` | `localPath` set once downloaded |
| `CachedFolder` | `id`, `courseId`, `parentId`, `name`, `fullName` | |
| `CachedConversation` | `id`, `subject`, `lastMessageAt`, `workflowState`, `participantsJSON`, `contextName` | |
| `CachedMessage` | `id`, `conversationId`, `authorId`, `authorName`, `body`, `createdAt`, `attachmentsJSON` | |
| `CachedPlannerItem` | `id`, `courseId`, `type`, `title`, `dueAt`, `completed` | |
| `CachedCalendarEvent` | `id`, `courseId`, `title`, `startAt`, `endAt`, `locationName`, `htmlURL` | |
| `GradeSnapshot` | `courseId`, `capturedAt`, `percent`, `letter` | One row per course per sync where the value changed |
| `ChangeRecord` | `id`, `kind`, `courseId`, `subjectId`, `title`, `detail`, `occurredAt`, `seenAt` | Feeds the change feed and notifications |
| `SyncMetadata` | `entityKind`, `scopeId`, `lastSyncedAt`, `lastErrorDescription` | Freshness gate + per-section staleness UI |

`CachedCourse` holds cascade-delete relationships to its groups, assignments, announcements, topics, modules, folders, and snapshots.

### 3.1 `ChangeDetector`

Runs inside `SyncEngine` after each upsert, comparing incoming values against what was in the store immediately prior. It emits `ChangeRecord`s for:

| `kind` | Trigger |
|---|---|
| `.newGrade` | `CachedSubmission.score` transitions `nil → non-nil`, or changes value |
| `.gradeChanged` | Course percent moved by ≥ 0.01 |
| `.newFeedback` | A `CachedComment` appears whose `authorId != submission.userId` |
| `.newAnnouncement` | A `CachedAnnouncement` ID not previously stored |
| `.newMessage` | A `CachedMessage` ID not previously stored |
| `.dueSoon` | An assignment crosses into the 24-hour window with no submission |

`seenAt` is set when the user views the change feed. Unseen records drive the menu-bar badge and the Dashboard's "Since you last looked" section. Records older than 30 days are purged.

**Canvas quirks the detector must respect** (verified against BYUH's instance):

- A submission with `workflowState == "graded"` and `score == nil` is a **muted/hidden** grade. It is "awaiting grade," not "recently graded" — it must not fire `.newGrade`, and it belongs in awaiting-grade lists.
- BYUH's Canvas never returns `"submitted"` as a workflow state; work jumps straight to `"graded"`. Do not treat `workflow_state == "submitted"` as the signal for "awaiting grade."
- `submission_comments` is not returned by default. Every submission fetch must pass `include[]=submission_comments`.
- Filter a student's own comments by comparing `comment.authorId != submission.userId`; no `/users/self` call is needed.

---

## 4. API surface (`CanvasCore`)

Existing: `courses`, `enrollments`, `assignmentGroups`, `submissions`, `courseTeachers`. All new calls reuse the existing `getPaginated` / `Link`-header pagination and the `snake_case` decoder.

| Method | Request |
|---|---|
| `profile()` | `GET /users/self/profile` |
| `courseColors()` | `GET /users/self/colors` |
| `assignments(courseId:)` | `GET /courses/{c}/assignments?include[]=submission&include[]=all_dates&per_page=100` |
| `submissionDetail(courseId:assignmentId:)` | `GET /courses/{c}/assignments/{a}/submissions/self?include[]=submission_comments&include[]=rubric_assessment&include[]=assignment` |
| `syllabus(courseId:)` | `GET /courses/{c}?include[]=syllabus_body` |
| `announcements(courseId:)` | `GET /courses/{c}/discussion_topics?only_announcements=true&per_page=50` |
| `discussionTopics(courseId:)` | `GET /courses/{c}/discussion_topics?per_page=50` |
| `discussionView(courseId:topicId:)` | `GET /courses/{c}/discussion_topics/{t}/view` — returns the full entry tree in one call |
| `modules(courseId:)` | `GET /courses/{c}/modules?include[]=items&per_page=100` |
| `folders(courseId:)` | `GET /courses/{c}/folders?per_page=100` |
| `files(courseId:)` | `GET /courses/{c}/files?per_page=100` |
| `downloadFile(_:to:)` | `GET` the file's `url` (pre-authenticated), streamed to disk |
| `conversations(scope:)` | `GET /conversations?scope={inbox\|unread\|archived}&per_page=50` |
| `conversation(id:)` | `GET /conversations/{id}` |
| `createConversation(recipientIds:subject:body:)` | `POST /conversations` — exists in the instructor-messaging spec; generalized here |
| `replyToConversation(id:body:)` | `POST /conversations/{id}/add_message` |
| `markConversationRead(id:)` | `PUT /conversations/{id}` with `conversation[workflow_state]=read` |
| `plannerItems(start:end:)` | `GET /planner/items?start_date=&end_date=&per_page=100` |
| `calendarEvents(contextCodes:start:end:)` | `GET /calendar_events?type=event&context_codes[]=course_{id}&start_date=&end_date=` |
| `uploadSubmissionFile(courseId:assignmentId:fileURL:)` | Three-step flow, §7 |
| `submitAssignment(courseId:assignmentId:submission:)` | `POST /courses/{c}/assignments/{a}/submissions` |

`APIError` gains `.rateLimited(retryAfter: TimeInterval)` (HTTP 403 with Canvas's throttle body) and `.forbidden`, both of which `SyncEngine` handles with backoff rather than surfacing as failures.

---

## 5. UI

### 5.1 Window shell

`NavigationSplitView` with two columns. The content column is the course workspace or a global section; there is no third column at the top level — item detail is presented inside the section (Inbox and Assignments use an internal list/detail split so the sidebar stays visible).

```
┌──────────┬────────────────────────────────────┐
│ Dashboard│  BIOL 100                     ↻ ⌘K │
│ Inbox  3 │ ─────────────────────────────────── │
│ Calendar │ [Grades][Assignments][Announce]…   │
│ To-Do  7 │                                    │
│          │   87.4%   B+     ▁▂▃▅▆▇ trend      │
│ COURSES  │   ──────────────────────────────   │
│ ● BIOL100│   Exams   92%   weight 30%         │
│ ● CS 220 │   Labs    81%   weight 25%         │
│ ● ENGL101│   HW      88%   weight 45%         │
└──────────┴────────────────────────────────────┘
```

Sidebar rows show a course accent color (from `/users/self/colors`, falling back to a hash of the course code), the letter grade badge, and an unseen-change dot. Pinned courses sort first; hidden courses are excluded and manageable from Settings. Minimum window size 900×600; the sidebar collapses below that.

The toolbar carries: refresh (with a spinner and a "Updated 3m ago" label bound to `SyncMetadata`), quick-open (`⌘K`), and an overflow menu with "Open in Canvas."

### 5.2 Global sections

**Dashboard** — a grid of course cards (grade ring, letter, delta since last snapshot), a "Since you last looked" feed of unseen `ChangeRecord`s grouped by course, a due-soon strip for the next 7 days, and an unread-inbox summary. Every row is a `RevealTarget`; clicking navigates.

**Inbox** — conversation list (unread bolded) → thread view with messages in order → inline reply composer. Compose sheet with a recipient picker seeded from course instructors (`courseTeachers`). Sending optimistically appends to the local thread and reconciles on the next sync; a failed send restores the draft and surfaces an inline error. This supersedes the standalone instructor-messaging sheet, which is folded in as a preset recipient.

**Calendar** — month, week, and agenda modes over assignment due dates and course calendar events, color-coded by course accent. Clicking an item reveals it. Month view fetches a ±60-day window and extends as the user navigates.

**To-Do** — three sections: *Missing* (past due, unsubmitted, not excused), *Due this week*, and *Awaiting grade* (using the muted-grade rule from §3.1). Backed by planner items where available, cross-checked against local assignment/submission state so it stays correct offline.

### 5.3 Course workspace tabs

**Grades** — the current grade dashboard, plus: a full assignment table (name / score / possible / group / due / status) sortable by any column; group breakdown showing drop rules in effect and which items were dropped; a trend chart from `GradeSnapshot`; and What-If + Solve-For-Me as a right-hand inspector panel rather than a separate screen, so hypotheticals update the table live. All grade math continues to run through the existing `GradeCalculator` — no logic moves.

**Assignments** — filter chips (Upcoming / Missing / Graded / All) over a list; detail pane shows rendered description, due/unlock/lock dates, points, submission types, current submission state, score, rubric assessment (criterion, points, rating, comment), and instructor comments. A **Submit** button appears when the assignment accepts submissions (Phase 5).

**Announcements** — list → rendered HTML detail; `readAt` set on view.

**Discussions** — topic list → threaded entries rendered from a single `/view` call, indented by depth, collapsible. Read-only, with "Reply in Canvas" linking out.

**Modules** — ordered modules with items indented per Canvas's `indent`, showing type icons and completion state. Items resolve to internal targets (assignment, file, page) where possible, otherwise open in Canvas.

**Files** — folder tree → file list with Quick Look preview (`QLPreviewController` via `NSViewRepresentable`) and download to `~/Downloads`. Downloaded files record `localPath` and preview locally thereafter.

**Syllabus** — rendered `syllabus_body`.

### 5.4 HTML rendering

Canvas returns HTML bodies for descriptions, announcements, discussions, and syllabi. Render with `AttributedString(html:)` where the markup is simple, falling back to a sandboxed `WKWebView` (JavaScript disabled, navigation intercepted and routed to the default browser) for content with tables, iframes, or LaTeX. A single `RichTextView` component in `CanvasUI` makes that choice internally; callers pass an HTML string.

### 5.5 Shared components (`CanvasUI`)

`CourseCard`, `GradeRing`, `LetterBadge`, `GroupBreakdownRow`, `AssignmentRow`, `StreamRow`, `ChangeFeedRow`, `DueSoonRow`, `WhatIfEditor`, `SolveResultView`, `RichTextView`, `StalenessLabel`, `SkeletonList`. Each takes plain value inputs and closures — no repository or session dependencies — so both scenes compose them freely and previews work without a store.

### 5.6 Popover changes

The popover keeps its full current feature set: course list, course detail with grade dashboard and stream, what-if calculator, settings. It gains:

- A "Since you last looked" section at the top when unseen changes exist.
- An "Open Window" affordance, and `⌘↩` on any row to reveal that item in the window.
- Its own views re-pointed at the repository instead of `CoursesViewModel`'s in-memory cache, so it opens instantly from disk.

`CoursesViewModel`, `CourseDetailViewModel`, and `CalculatorViewModel` survive; their fetch bodies are replaced with repository reads and `syncEngine.refresh` calls. `CalculatorViewModel` is unchanged apart from its data source — it already operates on `GradedItem` values.

### 5.7 Quick open (`⌘K`)

A sheet with fuzzy search over cached courses, assignments, announcements, files, and conversations. Results are grouped by kind and resolve to `RevealTarget`s. Because it queries the local store, it works offline and returns instantly. Full-text search over cached HTML bodies uses SwiftData predicates on a plain-text `searchBlob` field populated at upsert time.

### 5.8 Empty, loading, and error states

- **Cold, no cache:** skeleton rows, not a centered spinner.
- **Cached but stale:** content renders immediately with a "Updated 2h ago" label; a refresh spins in the toolbar.
- **Offline:** cached content plus a non-blocking banner. Write actions are disabled with an explanatory tooltip.
- **Expired token:** a dedicated re-auth state ("Your Canvas token expired — reconnect") replacing the raw error string, reachable from both scenes.
- **Per-section failure:** the failing tab shows an inline retry; siblings render normally.

---

## 6. Notifications and background refresh

`NotificationScheduler` (in `CanvasData`) consumes unseen `ChangeRecord`s and posts `UNNotificationRequest`s.

- **Permission** is requested lazily — the first time the user enables a notification category in Settings, never at launch.
- **Categories**, each independently toggleable: new grades, new feedback, new inbox messages, assignment due soon. Default: grades and feedback on, others off.
- **Background refresh** runs on a `Timer` in the app process (the app is always resident via the menu bar item). Default interval 30 minutes, configurable 15 min – 4 h, plus an immediate sync on wake from sleep and on network reachability returning. Suspended while on battery below 20% and while the display is asleep for more than an hour.
- **Coalescing:** more than three changes of one kind in one sync produce a single summary notification ("4 new grades in BIOL 100").
- **Tapping** a notification calls `router.reveal(...)` and opens the window on that item.
- **Quiet hours** configurable in Settings; suppressed notifications still populate the change feed.
- The menu bar icon shows a badge count of unseen changes.

---

## 7. Assignment submission (Phase 5)

The highest-stakes surface in the app; specified precisely because a silent failure has real academic cost.

**Supported types:** `online_upload`, `online_text_entry`, `online_url`. Anything else (quizzes, external tools, on-paper) shows "Submit in Canvas" and links out. The assignment's `submissionTypes` and `allowedExtensions` drive which editor appears and what files are accepted; a disallowed extension is rejected client-side before any upload begins.

**File upload — Canvas's three-step flow:**

1. `POST /courses/{c}/assignments/{a}/submissions/self/files` with `name`, `size`, `content_type` → returns `upload_url` and `upload_params`.
2. `POST` multipart to `upload_url` with `upload_params` first and the file bytes last. Canvas returns a 3xx.
3. `GET` the redirect target to confirm → returns the file object with its `id`.

Then `POST /courses/{c}/assignments/{a}/submissions` with `submission[submission_type]=online_upload` and `submission[file_ids][]`.

**Safety requirements:**

- A confirmation sheet before submitting shows the assignment name, due date, whether the submission will be late, the attempt number, and the exact files or text being sent.
- Upload progress is reported per file; the flow is cancellable up to the final POST.
- After a successful submit, the app immediately re-fetches the submission and displays the returned `attempt`, `submitted_at`, and attached filenames as confirmation. **A submission is not reported as successful until this verification round-trip confirms it.**
- Any failure preserves the user's draft (text, URL, or file selection) in the local store and offers retry plus "Open in Canvas" as an escape hatch.
- Submitting is disabled offline and in the absence of a verified token.
- In demo mode the flow runs end to end against the mock store and is labeled as a demo.

---

## 8. Testing

**`CanvasCoreTests`** (extends the existing suite): a decode test per new endpoint against a captured JSON fixture, including the muted-grade and missing-`submitted`-state cases from §3.1; pagination across `Link` headers for new paginated endpoints; URL construction under a non-default host; the upload flow's request shaping, driven by a stubbed transport.

**`CanvasDataTests`** (new): `ChangeDetector` — a table-driven test per change kind, including the negative cases (muted grade must not fire `.newGrade`; a re-fetch with identical data must produce zero records). `SyncEngine` over an in-memory `ModelContainer` — upsert idempotency across repeated syncs, partial-failure isolation, TTL gating, soft-delete behavior. `CanvasRepository` — filters, sorting, and the `HiddenCoursesStore` migration.

**Manual verification per phase:** the phase's surface is walked end to end in demo mode, then against a live account, in both scenes, including offline (network disabled) and stale-token paths.

The existing suite must stay green throughout; `GradeCalculator` is not modified by this work.

---

## 9. Phasing

Each phase is independently shippable and gated on the previous phase's tests passing.

**Phase 0 — Foundation.**
Package split; `Credentials` + configurable host + connection test; SwiftData schema; `CanvasRepository`; `SyncEngine` and `ChangeDetector` over the five existing endpoints; `HiddenCoursesStore` migration; `AppSession`; `Router`; the `Window` scene with the sidebar shell; popover re-pointed at the repository; cross-scene reveal.
*Ships as: today's app, in a resizable window, that opens instantly and works offline.*

**Phase 1 — Course workspace (read).**
Assignments (list + detail + rubric + comments), Announcements, Syllabus, the expanded Grades tab (assignment table, trend chart, inspector-panel calculator), and the Dashboard.
*Ships as: a Canvas reader that covers daily use.*

**Phase 2 — Communication.**
Inbox (list, thread, compose, reply, mark read), Discussions read-only, `NotificationScheduler`, background refresh, Settings for notification categories and quiet hours.

**Phase 3 — Time.**
Calendar (month/week/agenda), To-Do triage, due-soon surfaces in both scenes.

**Phase 4 — Content.**
Modules, Files with Quick Look and download, quick-open (`⌘K`) and full-text search.

**Phase 5 — Submission.**
Upload flow, text and URL entry, confirmation sheet, verification round-trip, draft preservation.

---

## 10. Open risks

- **SwiftData under concurrent access.** `SyncEngine` as a `@ModelActor` writing while `@Query` reads on the main actor is the supported pattern, but it is worth validating early in Phase 0 with a stress test rather than discovering contention in Phase 3.
- **Canvas rate limits.** Full-scope sync across 6 enrolled courses × 7 endpoints is ~42 requests. The concurrency cap and TTL gate should keep this comfortable, but the `.rateLimited` path must be exercised, not just written.
- **HTML fidelity.** Canvas course content varies wildly. The `AttributedString` / `WKWebView` split in §5.4 is a judgment call that will need tuning against real course pages.
- **Host portability.** The quirks in §3.1 were observed on BYU–Hawaii's instance. Making the host configurable means other schools may behave differently — particularly around workflow states. The detector's rules should be written defensively rather than assuming BYUH's behavior is universal.
