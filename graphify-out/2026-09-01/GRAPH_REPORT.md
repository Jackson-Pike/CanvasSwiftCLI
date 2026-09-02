# Graph Report - CanvasCLISwift  (2026-08-21)

## Corpus Check
- 162 files · ~139,705 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2241 nodes · 5000 edges · 119 communities (107 shown, 12 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 692 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `25694a66`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Credentials
- CachedCourse
- GroupInfo
- LedgerRowView
- CanvasRepository
- Canvas Grades — Windowed Desktop App Design Spec
- CanvasApp — SwiftUI macOS Menu Bar App Design
- File structure (end state)
- CanvasCLISwift — Phase 2 Design
- Demo Mode Design
- C2
- InboxViewModel
- CanvasCLISwift Phase 2 Implementation Plan
- CoursesViewModel
- Course Filtering Design
- Onboarding — Demo-First First-Run Design
- CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan
- PaginationStub
- Visual Design
- Instructor Messaging — Design Spec
- Keychain Onboarding UX — Design Spec
- .body
- File Map
- CourseSettingsStore
- SidebarItem
- Codable
- File Map
- .load
- 2026-06-26
- File Map
- Student UX Brief — CanvasCLISwift
- SettingsView
- StreamItem
- CanvasCore
- Global Constraints
- Global Constraints
- Canvas API Pagination Implementation Plan
- Course List Billboard Card Redesign Implementation Plan
- CLAUDE.md
- Package.swift
- SyncStub
- ModelsTests
- CourseCard
- XCTestCase
- SyncEngine
- .makeRepo
- ChangeKind
- 2026-08-09-phase3-time.md
- CourseDetailViewModel
- SandboxRailView
- SemesterTimelineStrip
- FeedbackRow
- Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox
- .plan
- Task Dependency Order
- CourseGradeSummary
- APIError
- Task Dependency Order
- APIClient
- Text
- AssignmentPredicatesTests
- CanvasGradesApp
- Canvas Grades
- View
- UnifiedCalendarItem
- RichTextView
- AnnouncementListRow
- ToDoItem
- run-app.sh
- SkeletonList
- RouteStub
- AssignmentsTabView
- DashboardView
- htmlNeedsWebView
- CanvasData
- Foundation
- CalculatorViewModel
- AssignmentListRow
- RecordingStub
- .client
- FixedResponseStub
- Color
- .ids
- GROUP A — INBOX
- ComposeSheet
- AssignmentsViewModel
- DiscussionsViewModel
- GradeTrendChart
- MockData
- AnnouncementsViewModel
- CachedConversation
- Sendable
- Router
- Conversation
- ChangeRecord
- Task
- CodingKeys
- PowerState
- AssignmentFilter
- FormRecordingStub
- CachedSubmission
- BackgroundRefreshController.swift
- AppSession
- AgeCapsule
- .userNotificationCenter
- CalendarViewModel
- ConversationAPITests
- ConversationModelsTests
- PointsLedgerTests
- CachedPlannerItem
- DiscussionModelsTests
- ToDoViewModel
- PlannerItem
- CourseTab
- CalendarEvent
- LedgerHeaderRow
- .makeEngine
- CalendarModelsTests
- PlannerModelsTests

## God Nodes (most connected - your core abstractions)
1. `CanvasCore` - 85 edges
2. `APIClient` - 79 edges
3. `SyncEngine` - 76 edges
4. `AppSession` - 63 edges
5. `CalculatorViewModel` - 53 edges
6. `Credentials` - 49 edges
7. `CanvasData` - 46 edges
8. `XCTest` - 42 edges
9. `MockData` - 41 edges
10. `CanvasRepository` - 39 edges

## Surprising Connections (you probably didn't know these)
- `.filteredRows` --calls--> `assignmentMatchesFilter()`  [INFERRED]
  CanvasApp/ViewModels/AssignmentsViewModel.swift → Sources/CanvasCore/AssignmentPredicates.swift
- `.body` --calls--> `SandboxRailView`  [INFERRED]
  CanvasApp/Views/Window/CourseWorkspaceView.swift → Sources/CanvasUI/SandboxRail.swift
- `AppSession` --calls--> `NotificationScheduler`  [INFERRED]
  CanvasApp/App/AppSession.swift → Sources/CanvasData/NotificationScheduler.swift
- `.selected` --references--> `CachedAnnouncement`  [INFERRED]
  CanvasApp/ViewModels/AnnouncementsViewModel.swift → Sources/CanvasData/Models/AnnouncementModels.swift
- `.selectedTopic` --references--> `CachedDiscussionTopic`  [INFERRED]
  CanvasApp/ViewModels/DiscussionsViewModel.swift → Sources/CanvasData/Models/DiscussionModels.swift

## Import Cycles
- None detected.

## Communities (119 total, 12 thin omitted)

### Community 0 - "Credentials"
Cohesion: 0.13
Nodes (11): FetchDescriptor, Credentials, Bool, ModelContainer, AnnouncementSyncTests, ConversationSyncTests, SyncEngineAllTests, Int (+3 more)

### Community 1 - "CachedCourse"
Cohesion: 0.16
Nodes (15): CachedAssignment, .rubric, CachedAssignmentGroup, CachedCourse, .gradingScale, CachedEnrollment, SchemePair, Bool (+7 more)

### Community 2 - "GroupInfo"
Cohesion: 0.08
Nodes (26): Array, GradeCalculator, GroupInfo, GroupResult, letterGrade(), SolveResult, alreadyAchieved, impossible (+18 more)

### Community 3 - "LedgerRowView"
Cohesion: 0.07
Nodes (33): GradeCalculator, PointsLedger, Double, Color, DesignTokenSwatches, .body, dynamic(), Font (+25 more)

### Community 4 - "CanvasRepository"
Cohesion: 0.11
Nodes (8): ModelContext, CanvasRepository, .context, Bool, Date, Int, ModelContainer, String

### Community 5 - "Canvas Grades — Windowed Desktop App Design Spec"
Cohesion: 0.07
Nodes (28): 10. Open risks, 1. Overview, 2.1 Package structure, 2.2 Runtime composition, 2.3 Data flow, 2.4 `CanvasRepository`, 2.5 `SyncEngine`, 2.6 Credentials and host configuration (+20 more)

### Community 6 - "CanvasApp — SwiftUI macOS Menu Bar App Design"
Cohesion: 0.09
Nodes (22): 1. Course List View, 2. Course Detail View, 3. Calculator View, 4. Settings / Onboarding Sheet, Architecture, CanvasApp — SwiftUI macOS Menu Bar App Design, Data & API, Data Refresh (+14 more)

### Community 7 - "File structure (end state)"
Cohesion: 0.09
Nodes (21): Desktop App — Phase 0 (Foundation) Implementation Plan, Deviations from spec (flagged for reviewer), File structure (end state), Global Constraints, Spec coverage map (Phase 0 items → tasks), Task 10: Derived reads — `CalculatorInputs` and course stream from the store, Task 11: `CanvasUI` shared components, Task 12: `AppSession` + `Router` (+13 more)

### Community 8 - "CanvasCLISwift — Phase 2 Design"
Cohesion: 0.11
Nodes (18): Architecture, Calculator Modes, CanvasCLISwift — Phase 2 Design, Command Structure (`swift-argument-parser`), Data & API, Error Handling, File Structure, Grade Calculator (+10 more)

### Community 9 - "Demo Mode Design"
Cohesion: 0.11
Nodes (18): Activation, Assignment Groups, Course, `courseTeachers(courseId:)`, Demo Mode Design, Enrollment, Exams (weight: 40, id: 1003), File Layout (+10 more)

### Community 10 - "C2"
Cohesion: 0.18
Nodes (4): C1, C2, C3, Int

### Community 11 - "InboxViewModel"
Cohesion: 0.22
Nodes (11): InboxViewModel, Bool, Date, Int, String, InboxView, .body, .listColumn (+3 more)

### Community 12 - "CanvasCLISwift Phase 2 Implementation Plan"
Cohesion: 0.12
Nodes (16): CanvasCLISwift Phase 2 Implementation Plan, File Structure, Global Constraints, Self-Review Notes, Task 10: TUI course detail — grade dashboard, Task 11: Calculator screen + `calc` subcommand, Task 1: Package setup — dependencies, file split, test target, Task 2: Models + JSON decoding tests (+8 more)

### Community 13 - "CoursesViewModel"
Cohesion: 0.14
Nodes (14): PopoverContent, .coursesVM, CoursesViewModel, Bool, Date, Double, Int, String (+6 more)

### Community 14 - "Course Filtering Design"
Cohesion: 0.12
Nodes (15): Approach, AppState changes, Architecture, Change, Course Filtering Design, CourseListView changes, CoursesViewModel changes, Data Persistence (+7 more)

### Community 15 - "Onboarding — Demo-First First-Run Design"
Cohesion: 0.13
Nodes (14): AppState — demo state, Components, ConnectView (new) — replaces SettingsView as the onboarding entry, Current funnel (before), Data flow, Error handling / edge cases, Goal, KeychainWarningView (reused, relocated) (+6 more)

### Community 16 - "CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan"
Cohesion: 0.14
Nodes (13): CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan, File Map, Global Constraints, Self-Review, Task 1: Restructure SPM — Migrate CanvasCore + Retire CLI, Task 2: Grading Scale — Models Update + letterGrade Function, Task 3: Target Grade Solver, Task 4: App Shell — MenuBarExtra + Keychain + Brand Colors (+5 more)

### Community 17 - "PaginationStub"
Cohesion: 0.10
Nodes (10): HTTPURLResponse, APIClientMessagingTests, URLSession, APIClientPaginationTests, PaginationStub, Bool, Data, String (+2 more)

### Community 18 - "Visual Design"
Cohesion: 0.15
Nodes (12): Card anatomy, Card chrome, Course List Redesign — Billboard Grade Cards, Files Changed, Goal, Grade color mapping (existing system), Layout / List Structure, No-grade state (+4 more)

### Community 19 - "Instructor Messaging — Design Spec"
Cohesion: 0.17
Nodes (11): `APIClient` additions, Compose ViewModel, `ComposeMessageSheet`, `CourseDetailViewModel` change, Data Layer, Error Handling, Files Changed / Added, Instructor Messaging — Design Spec (+3 more)

### Community 20 - "Keychain Onboarding UX — Design Spec"
Cohesion: 0.17
Nodes (11): `AppState` changes, `CanvasApp.swift` changes, Components, Files Changed, Flow, Goals, Keychain Onboarding UX — Design Spec, `KeychainHelper` changes (+3 more)

### Community 21 - ".body"
Cohesion: 0.16
Nodes (12): .listColumn, MainWindowBody, .body, .inboxUnread, Bool, Color, Double, Int (+4 more)

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "CourseSettingsStore"
Cohesion: 0.26
Nodes (9): CourseSettingsStore, Double, Int, String, UserDefaults, CourseSettingsRow, .body, CustomizationSection (+1 more)

### Community 24 - "SidebarItem"
Cohesion: 0.13
Nodes (15): RevealTarget, assignment, conversation, course, section, SidebarItem, calendar, course (+7 more)

### Community 25 - "Codable"
Cohesion: 0.21
Nodes (23): Codable, Decodable, Decoder, buildGradedItems(), Announcement, Assignment, AssignmentGroup, AssignmentGroupRules (+15 more)

### Community 26 - "File Map"
Cohesion: 0.22
Nodes (8): Course Filtering Implementation Plan, File Map, Global Constraints, Task 1: Add enrollment_type filter to APIClient, Task 2: Create HiddenCoursesStore, Task 3: Update CoursesViewModel and AppState, Task 4: Add swipe-to-hide in CourseListView, Task 5: Add Hidden Courses restore section in SettingsView

### Community 27 - ".load"
Cohesion: 0.53
Nodes (3): KeychainHelper, String, Security

### Community 28 - "2026-06-26"
Cohesion: 0.25
Nodes (7): 2026-06-26, Bug Fixes, Canvas API, Changelog, Course Stream (new), Dev Experience, UI

### Community 29 - "File Map"
Cohesion: 0.25
Nodes (7): File Map, Global Constraints, Keychain Onboarding UX Implementation Plan, Task 1: Fix KeychainHelper — upsert save and friendly metadata, Task 2: Update AppState — lazy token load and acknowledgement flag, Task 3: Create KeychainWarningView, Task 4: Wire KeychainWarningView into PopoverContent and verify full flow

### Community 30 - "Student UX Brief — CanvasCLISwift"
Cohesion: 0.25
Nodes (7): Context, Larger Features (future scope), Prioritized Implementation Order, QoL Improvements, Quick Wins (implement first), Student UX Brief — CanvasCLISwift, Visual Polish

### Community 31 - "SettingsView"
Cohesion: 0.11
Nodes (19): .body, KeychainWarningView, .body, NotificationSettingsSection, .body, .hourOptions, SettingsView, .canSave (+11 more)

### Community 32 - "StreamItem"
Cohesion: 0.10
Nodes (28): .mainColumn, CalculatorInputs, CanvasRepository, Kind, awaitingGrade, feedback, recentlyGraded, upcoming (+20 more)

### Community 34 - "Global Constraints"
Cohesion: 0.33
Nodes (5): Demo Mode Implementation Plan, Global Constraints, Task 1: MockData.swift, Task 2: APIClient Demo Intercepts, Task 3: Manual Smoke Test

### Community 35 - "Global Constraints"
Cohesion: 0.40
Nodes (4): API Caching — TTL Guard + AppState VM Lift, Global Constraints, Task 1: Add TTL guard to both view models, Task 2: Lift view models into AppState; update views to use @ObservedObject

### Community 36 - "Canvas API Pagination Implementation Plan"
Cohesion: 0.50
Nodes (3): Canvas API Pagination Implementation Plan, Global Constraints, Task 1: Implement `getPaginated` and update all endpoints

### Community 37 - "Course List Billboard Card Redesign Implementation Plan"
Cohesion: 0.50
Nodes (3): Course List Billboard Card Redesign Implementation Plan, Global Constraints, Task 1: Rewrite `CourseCardView` and update `CourseListView`

### Community 40 - "SyncStub"
Cohesion: 0.18
Nodes (6): Bool, Data, Int, String, URLRequest, SyncStub

### Community 42 - "CourseCard"
Cohesion: 0.28
Nodes (7): CourseCard, .body, .displayLetter, .gradeColor, Color, Double, String

### Community 43 - "XCTestCase"
Cohesion: 0.13
Nodes (11): .normalizedHost, String, CalendarAPITests, CredentialsTests, PlannerAPITests, RubricTests, ConcurrencyStressTests, ConversationWriteTests (+3 more)

### Community 44 - "SyncEngine"
Cohesion: 0.09
Nodes (34): Error, EntityKind, announcements, assignments, calendarEvents, conversations, courses, discussionEntries (+26 more)

### Community 45 - ".makeRepo"
Cohesion: 0.33
Nodes (4): DerivedReadsTests, CanvasRepository, Date, String

### Community 46 - "ChangeKind"
Cohesion: 0.07
Nodes (29): ISO8601DateFormatter, CanvasDate, Date, String, ChangeDetector, PendingChange, SubmissionSnapshot, Bool (+21 more)

### Community 47 - "2026-08-09-phase3-time.md"
Cohesion: 0.08
Nodes (25): Architecture, Context, File Structure, Global Constraints, GROUP A — CORE MODELS & API CLIENT (CanvasCore), GROUP B — DATA PERSISTENCE & SYNC (CanvasData), GROUP C — CALENDAR UI (CanvasUI & CanvasApp), GROUP D — TO-DO UI & DUE-SOON SURFACES (CanvasUI & CanvasApp) (+17 more)

### Community 48 - "CourseDetailViewModel"
Cohesion: 0.17
Nodes (13): CourseDetailViewModel, .calculator, Bool, Date, GradeCalculator, Int, String, CourseDetailBody (+5 more)

### Community 49 - "SandboxRailView"
Cohesion: 0.09
Nodes (24): HypotheticalSlider, .body, SandboxRailView, .answerSentence, .body, .footer, .header, .hypotheticalsSection (+16 more)

### Community 50 - "SemesterTimelineStrip"
Cohesion: 0.17
Nodes (16): makeSyntheticTicks(), SemesterTimelineStrip, .body, SemesterTimelineStripPreviewContainer, .body, Style, finalExam, graded (+8 more)

### Community 51 - "FeedbackRow"
Cohesion: 0.24
Nodes (15): AwaitingGradePanel, AwaitingRow, DashboardPanelsPreview, .awaitingRows, .body, .feedbackRows, FeedbackRow, RecentFeedbackPanel (+7 more)

### Community 52 - "Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox"
Cohesion: 0.10
Nodes (20): 1.1 Header, 1.2 Semester timeline strip, 1.3 Ledger table, 1.4 Bottom panels — 2-column grid, `1fr 1.15fr`, gap 26, 1.5 Sidebar (both themes), 1. Dashboard (`SidebarItem.dashboard` detail pane) — options `3a` / `3b`, 2. Course workspace + Sandbox — option `1d`, About the Design Files (+12 more)

### Community 53 - ".plan"
Cohesion: 0.08
Nodes (26): Date, NotificationSettingsStore, .anyCategoryEnabled, .settings, Stored, Bool, Int, NotificationPlanner (+18 more)

### Community 54 - "Task Dependency Order"
Cohesion: 0.11
Nodes (18): File Structure, Global Constraints, Phase 1a — Dashboard + What-If Sandbox Implementation Plan, Self-Review, Task 10: Dashboard bottom panels (`CanvasUI`), Task 11: DashboardView composition + wire into MainWindowView (`CanvasApp`), Task 12: Course-scope Sandbox rail + grades-tab dock (`CanvasUI` + `CanvasApp`), Task 13: Term-scope Sandbox rail on the Dashboard (`CanvasApp`) (+10 more)

### Community 55 - "CourseGradeSummary"
Cohesion: 0.12
Nodes (31): CourseLedgerRow, DashboardViewModel, Color, Date, Double, Int, String, Suggestion (+23 more)

### Community 56 - "APIError"
Cohesion: 0.17
Nodes (11): CustomStringConvertible, APIError, .description, forbidden, missingToken, rateLimited, unauthorized, TimeInterval (+3 more)

### Community 57 - "Task Dependency Order"
Cohesion: 0.09
Nodes (22): Architecture, Context, Critical Files for Implementation, File Structure, Global Constraints, Phase 1b — Assignments, Announcements, Syllabus, Grade Trend Chart Implementation Plan, Task 10: Grade trend chart (`CanvasUI`), Task 11: `AssignmentsViewModel` + `AssignmentsTabView` (`CanvasApp`) (+14 more)

### Community 58 - "APIClient"
Cohesion: 0.11
Nodes (15): APIClient, .baseURL, .token, http, network, Data, Date, Int (+7 more)

### Community 59 - "Text"
Cohesion: 0.10
Nodes (25): DisclosureRow, .body, Color, String, WelcomeView, .body, .headline, Bool (+17 more)

### Community 60 - "AssignmentPredicatesTests"
Cohesion: 0.15
Nodes (6): assignmentMatchesFilter(), isAssignmentMissing(), Bool, Date, Double, AssignmentPredicatesTests

### Community 61 - "CanvasGradesApp"
Cohesion: 0.33
Nodes (7): App, CanvasGradesApp, .body, .preferredColorScheme, ColorScheme, String, Scene

### Community 62 - "Canvas Grades"
Cohesion: 0.17
Nodes (11): Build from source, Canvas Grades, Download, Features, Getting a Canvas API token, Homebrew (coming soon), Install, License (+3 more)

### Community 63 - "View"
Cohesion: 0.10
Nodes (30): AssignmentRow, .body, .isHypothetical, CourseWorkspaceBody, .body, CourseWorkspaceView, .body, GradesSandboxSplit (+22 more)

### Community 64 - "UnifiedCalendarItem"
Cohesion: 0.23
Nodes (18): CalendarAgendaView, .body, .groupedItems, CalendarEventPill, .body, CalendarMonthView, .body, .monthDays (+10 more)

### Community 65 - "RichTextView"
Cohesion: 0.08
Nodes (33): Context, NSObject, NSViewRepresentable, .body, .body, AttributedHTMLText, .attributed, .body (+25 more)

### Community 66 - "AnnouncementListRow"
Cohesion: 0.20
Nodes (13): AnnouncementComponentFormat, AnnouncementComponentsPreview, .body, .posted, AnnouncementListRow, .body, .content, .subtitle (+5 more)

### Community 67 - "ToDoItem"
Cohesion: 0.24
Nodes (14): .dashboardContent, DueSoonStrip, .body, Bool, Color, Date, Int, String (+6 more)

### Community 69 - "SkeletonList"
Cohesion: 0.25
Nodes (5): Bool, .body, SkeletonList, .body, Int

### Community 70 - "RouteStub"
Cohesion: 0.29
Nodes (4): RouteStub, Bool, Data, URLRequest

### Community 71 - "AssignmentsTabView"
Cohesion: 0.19
Nodes (9): AssignmentsTabView, .body, .commentsSection, .detailColumn, .listColumn, Bool, Date, Int (+1 more)

### Community 72 - "DashboardView"
Cohesion: 0.12
Nodes (19): DashboardView, .awaitingRows, .body, .bottomPanels, .dotColors, .emptyState, .errorState, .feedbackRows (+11 more)

### Community 73 - "htmlNeedsWebView"
Cohesion: 0.14
Nodes (4): htmlNeedsWebView(), Bool, String, RichTextHeuristicTests

### Community 74 - "CanvasData"
Cohesion: 0.13
Nodes (3): CanvasData, CanvasUI, SwiftUI

### Community 75 - "Foundation"
Cohesion: 0.10
Nodes (3): Foundation, CanvasStore, SwiftData

### Community 76 - "CalculatorViewModel"
Cohesion: 0.06
Nodes (42): CalculatorView, .body, SolveForMeTabView, .body, .gradeLetters, SolveResultView, .body, Binding (+34 more)

### Community 77 - "AssignmentListRow"
Cohesion: 0.09
Nodes (33): formatRubricAssessment(), RubricAssessmentEntry, RubricCriterion, RubricLine, RubricRating, Double, String, AssignmentComponentFormat (+25 more)

### Community 78 - "RecordingStub"
Cohesion: 0.29
Nodes (5): RecordingStub, Bool, URL, URLRequest, URLProtocol

### Community 79 - ".client"
Cohesion: 0.36
Nodes (3): ProfileTests, Data, Int

### Community 80 - "FixedResponseStub"
Cohesion: 0.29
Nodes (4): FixedResponseStub, Bool, String, URLRequest

### Community 81 - "Color"
Cohesion: 0.29
Nodes (5): Color, .secondaryLabel, .systemBackground, .systemGroupedBackground, String

### Community 82 - ".ids"
Cohesion: 0.33
Nodes (4): LegacyHiddenCourses, Int, Set, UserDefaults

### Community 83 - "GROUP A — INBOX"
Cohesion: 0.06
Nodes (32): Architecture, Context, Execution Handoff, File Structure, Global Constraints, Global test harness reference, GROUP A — INBOX, GROUP B — DISCUSSIONS (read-only) (+24 more)

### Community 84 - "ComposeSheet"
Cohesion: 0.22
Nodes (15): .threadColumn, ComposeSheet, .body, .canSend, ConversationRow, .body, MessageBubble, ReplyComposer (+7 more)

### Community 85 - "AssignmentsViewModel"
Cohesion: 0.19
Nodes (11): AssignmentsViewModel, .filteredRows, .instructorComments, .selectedRow, Row, .id, Bool, Date (+3 more)

### Community 86 - "DiscussionsViewModel"
Cohesion: 0.11
Nodes (22): DiscussionsViewModel, .selectedTopic, Date, Int, String, DiscussionsTabView, .detailColumn, .listColumn (+14 more)

### Community 87 - "GradeTrendChart"
Cohesion: 0.15
Nodes (17): .trendSection, Charts, ClosedRange, GradeTrendChart, .body, .chart, .emptyState, .visibleThresholds (+9 more)

### Community 88 - "MockData"
Cohesion: 0.17
Nodes (3): MockData, Double, MockDataTests

### Community 89 - "AnnouncementsViewModel"
Cohesion: 0.16
Nodes (13): AnnouncementsViewModel, .selected, Date, Int, String, AnnouncementsTabView, .detailColumn, Int (+5 more)

### Community 90 - "CachedConversation"
Cohesion: 0.29
Nodes (9): .selected, CachedConversation, .participants, CachedMessage, Bool, Data, Date, Int (+1 more)

### Community 91 - "Sendable"
Cohesion: 0.38
Nodes (10): Equatable, Sendable, DiscussionEntryNode, DiscussionParticipant, DiscussionTopic, DiscussionView, FlatDiscussionEntry, flattenDiscussion() (+2 more)

### Community 92 - "Router"
Cohesion: 0.20
Nodes (9): DashboardDensity, cards, ledger, Router, .courseTab, .dashboardDensity, .sandboxOpen, .sidebar (+1 more)

### Community 93 - "Conversation"
Cohesion: 0.23
Nodes (11): Conversation, ConversationMessage, ConversationParticipant, ConversationScope, archived, inbox, unread, Int (+3 more)

### Community 94 - "ChangeRecord"
Cohesion: 0.28
Nodes (9): ChangeRecord, .changeKind, GradeSnapshot, Date, Double, Int, String, SyncMetadata (+1 more)

### Community 95 - "Task"
Cohesion: 0.28
Nodes (5): BackgroundRefreshController, Date, Task, Timer, UNUserNotificationCenterDelegate

### Community 96 - "CodingKeys"
Cohesion: 0.15
Nodes (13): CodingKey, CodingKeys, assignmentGroupId, descriptionHTML, dueAt, htmlURL, id, lockAt (+5 more)

### Community 97 - "PowerState"
Cohesion: 0.32
Nodes (6): PowerState, shouldRunBackgroundTick(), Bool, Date, Int, BackgroundGateTests

### Community 98 - "AssignmentFilter"
Cohesion: 0.21
Nodes (9): AssignmentFilter, all, graded, missing, upcoming, String, AssignmentFilterChips, .body (+1 more)

### Community 99 - "FormRecordingStub"
Cohesion: 0.20
Nodes (7): InputStream, FormRecordingStub, Bool, Data, String, URL, URLRequest

### Community 100 - "CachedSubmission"
Cohesion: 0.33
Nodes (9): CachedComment, CachedSubmission, .rubricAssessment, Bool, Data, Date, Double, Int (+1 more)

### Community 101 - "BackgroundRefreshController.swift"
Cohesion: 0.33
Nodes (4): AppKit, IOKit.ps, Network, UserNotifications

### Community 102 - "AppSession"
Cohesion: 0.14
Nodes (13): AppSession, .hasCredentials, .isDemo, Bool, CanvasRepository, Error, Int, Result (+5 more)

### Community 103 - "AgeCapsule"
Cohesion: 0.25
Nodes (7): AgeCapsule, .body, .isAged, .body, AwaitingGradeRowView, .body, Bool

### Community 104 - ".userNotificationCenter"
Cohesion: 0.33
Nodes (4): UNNotification, UNNotificationPresentationOptions, UNNotificationResponse, UNUserNotificationCenter

### Community 105 - "CalendarViewModel"
Cohesion: 0.11
Nodes (16): CalendarViewModel, Mode, agenda, .id, month, week, Bool, Color (+8 more)

### Community 109 - "CachedPlannerItem"
Cohesion: 0.32
Nodes (8): CachedCalendarEvent, CachedPlannerItem, Bool, Date, Int, String, PlannerModelsDataTests, ToDoTriageTests

### Community 111 - "ToDoViewModel"
Cohesion: 0.22
Nodes (7): Bool, Color, Int, String, ToDoViewModel, ToDoView, .body

### Community 112 - "PlannerItem"
Cohesion: 0.40
Nodes (7): PlannerItem, PlannerOverride, PlannerSubmissionSummary, Bool, Date, Int, String

### Community 113 - "CourseTab"
Cohesion: 0.25
Nodes (8): CourseTab, announcements, assignments, discussions, files, grades, modules, syllabus

### Community 114 - "CalendarEvent"
Cohesion: 0.43
Nodes (5): CalendarEvent, .courseId, Date, Int, String

### Community 115 - "LedgerHeaderRow"
Cohesion: 0.33
Nodes (5): .ledgerSection, LedgerHeaderRow, .body, LedgerTablePreview, .body

## Knowledge Gaps
- **475 isolated node(s):** `.isDemo`, `.hasCredentials`, `IOKit.ps`, `Network`, `.coursesVM` (+470 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CanvasCore` connect `CanvasCore` to `StreamItem`, `UnifiedCalendarItem`, `GroupInfo`, `RichTextView`, `ToDoItem`, `BackgroundRefreshController.swift`, `CanvasData`, `Foundation`, `ChangeKind`, `SandboxRailView`, `.plan`, `DiscussionsViewModel`, `GradeTrendChart`, `CalendarModelsTests`, `PlannerModelsTests`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Why does `AppSession` connect `AppSession` to `Credentials`, `SkeletonList`, `Foundation`, `SyncEngine`, `CoursesViewModel`, `InboxViewModel`, `ToDoViewModel`, `CourseDetailViewModel`, `SettingsView`, `CourseSettingsStore`, `.plan`, `AssignmentsViewModel`, `CourseGradeSummary`, `DiscussionsViewModel`, `Router`, `CanvasGradesApp`, `Task`?**
  _High betweenness centrality (0.076) - this node is a cross-community bridge._
- **Why does `Foundation` connect `Foundation` to `GroupInfo`, `LedgerRowView`, `CourseSettingsStore`, `Codable`, `.load`, `StreamItem`, `SyncStub`, `ChangeKind`, `.plan`, `CourseGradeSummary`, `APIError`, `CanvasData`, `AssignmentListRow`, `.ids`, `MockData`, `Sendable`, `Conversation`, `PowerState`, `AssignmentFilter`, `BackgroundRefreshController.swift`, `PlannerItem`, `CalendarEvent`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Are the 98 inferred relationships involving `Text` (e.g. with `.body` and `.body`) actually correct?**
  _`Text` has 98 INFERRED edges - model-reasoned connections that need verification._
- **Are the 26 inferred relationships involving `APIClient` (e.g. with `.testConnection()` and `.wireEngine()`) actually correct?**
  _`APIClient` has 26 INFERRED edges - model-reasoned connections that need verification._
- **Are the 23 inferred relationships involving `SyncEngine` (e.g. with `.testAnnouncementResyncPreservesReadAt()` and `.testCourseSyncPopulatesAnnouncements()`) actually correct?**
  _`SyncEngine` has 23 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isDemo`, `.hasCredentials`, `IOKit.ps` to the rest of the system?**
  _475 weakly-connected nodes found - possible documentation gaps or missing edges._