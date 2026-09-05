# Graph Report - CanvasCLISwift  (2026-09-04)

## Corpus Check
- 207 files · ~173,257 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2905 nodes · 6844 edges · 153 communities (133 shown, 20 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 855 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b9f10d28`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Credentials
- CachedAssignment
- Identifiable
- RichTextController
- CanvasRepository
- Canvas Grades — Windowed Desktop App Design Spec
- CanvasApp — SwiftUI macOS Menu Bar App Design
- File structure (end state)
- CanvasCLISwift — Phase 2 Design
- Demo Mode Design
- C2
- AppSession
- CanvasCLISwift Phase 2 Implementation Plan
- CoursesViewModel
- Course Filtering Design
- Onboarding — Demo-First First-Run Design
- CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan
- XCTestCase
- Visual Design
- Instructor Messaging — Design Spec
- Keychain Onboarding UX — Design Spec
- AssignmentPredicatesTests
- File Map
- CachedFile
- Router
- Codable
- File Map
- .body
- 2026-06-26
- File Map
- Student UX Brief — CanvasCLISwift
- TestState
- ChangeKind
- CanvasCore
- Global Constraints
- Global Constraints
- Canvas API Pagination Implementation Plan
- Course List Billboard Card Redesign Implementation Plan
- CLAUDE.md
- Package.swift
- DashboardView
- ModelsTests
- CourseCard
- .makeRepo
- SyncEngine
- AssignmentGroupingTests
- .submissionChanges
- 2026-08-09-phase3-time.md
- SemesterTimelineStrip
- ScenarioChips
- LedgerRowView
- String
- Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox
- .plan
- Task Dependency Order
- CourseGradeSummary
- RecordingStub
- Task Dependency Order
- APIClient
- Text
- letterGrade
- CanvasData
- Canvas Grades
- StreamItem
- UnifiedCalendarItem
- RichTextView
- CachedSubmission
- ToDoItem
- run-app.sh
- FilesViewModel
- BackgroundRefreshController
- AssignmentsViewModel
- 2026-08-22-phase4-content.md
- htmlNeedsWebView
- SwiftUI
- Foundation
- CalculatorViewModel
- GroupInfo
- CachedModuleItem
- .client
- RubricCriterion
- Color
- CourseSettingsStore
- GROUP A — INBOX
- ComposeSheet
- Module
- DiscussionsViewModel
- GradeTrendChart
- MockData
- AnnouncementsViewModel
- CachedConversation
- Sendable
- SidebarItem
- CachedPlannerItem
- View
- DueChip
- CodingKeys
- PowerState
- SearchResultItem
- FormRecordingStub
- 2026-09-03-phase5-submission.md
- .init
- NotificationSettingsSection
- GradeCalculator
- CalendarModelsTests
- ConversationModelsTests
- ConversationScope
- ModuleModelsTests
- Paper & Signal — Implementation Plan
- SubmissionViewModel
- .boardColumn
- QuickOpenViewModel
- PlannerItem
- SubmissionHTML
- CalendarEvent
- .html
- SolverTests
- SyncScope
- RichTextEditorRepresentable
- AssignmentRow
- CanvasFile
- DueUrgency
- FileModelsTests
- BoardStatus
- DiscussionModelsTests
- CourseDetailViewModel
- SyncStub
- SubmissionRequestTests
- .ids
- SubmitOrchestrationTests
- SubmissionEditor
- AssignmentGrouping
- RouteStub
- BoardTint
- FixedResponseStub
- AddQuickLinkSheet
- CanvasGradesApp
- RichTextControllerTests
- .userNotificationCenter
- RichTextToolbar
- CourseTab
- PickedFileEntry
- Backlog: On-Device AI Pacing Tracker (per-course "behind risk")
- APIError
- SubmissionType
- .build
- Phase
- ConversationAPITests
- PointsLedgerTests
- PlannerModelsTests
- .makeEngine
- .makeEngine
- HTTPURLResponse

## God Nodes (most connected - your core abstractions)
1. `CanvasCore` - 113 edges
2. `APIClient` - 99 edges
3. `SyncEngine` - 94 edges
4. `AppSession` - 78 edges
5. `CanvasData` - 62 edges
6. `XCTest` - 57 edges
7. `Credentials` - 56 edges
8. `CalculatorViewModel` - 53 edges
9. `MockData` - 50 edges
10. `CanvasRepository` - 48 edges

## Surprising Connections (you probably didn't know these)
- `.dueThisWeek` --calls--> `calendarDaysUntil()`  [INFERRED]
  CanvasApp/ViewModels/AssignmentsViewModel.swift → Sources/CanvasCore/AssignmentGrouping.swift
- `.body` --calls--> `SandboxRailView`  [INFERRED]
  CanvasApp/Views/Window/CourseWorkspaceView.swift → Sources/CanvasUI/SandboxRail.swift
- `AppSession` --calls--> `NotificationScheduler`  [INFERRED]
  CanvasApp/App/AppSession.swift → Sources/CanvasData/NotificationScheduler.swift
- `.apiClient` --calls--> `APIClient`  [EXTRACTED]
  CanvasApp/App/AppSession.swift → Sources/CanvasCore/APIClient.swift
- `.selected` --references--> `CachedAnnouncement`  [INFERRED]
  CanvasApp/ViewModels/AnnouncementsViewModel.swift → Sources/CanvasData/Models/AnnouncementModels.swift

## Import Cycles
- None detected.

## Communities (153 total, 20 thin omitted)

### Community 0 - "Credentials"
Cohesion: 0.11
Nodes (12): ModelContext, Credentials, CanvasStore, Bool, ModelContainer, AnnouncementSyncTests, ConversationSyncTests, SubmissionDraftTests (+4 more)

### Community 1 - "CachedAssignment"
Cohesion: 0.11
Nodes (16): CachedAssignment, .rubric, CachedAssignmentGroup, CachedCourse, .gradingScale, CachedEnrollment, SchemePair, Bool (+8 more)

### Community 2 - "Identifiable"
Cohesion: 0.14
Nodes (23): .bottomPanels, Identifiable, AgeCapsule, .body, .isAged, AwaitingGradePanel, .body, AwaitingGradeRowView (+15 more)

### Community 3 - "RichTextController"
Cohesion: 0.12
Nodes (16): NSFont, NSFontDescriptor, NSFontTraitMask, NSTextStorage, RichTextController, .body, Any, Bool (+8 more)

### Community 4 - "CanvasRepository"
Cohesion: 0.14
Nodes (9): FetchDescriptor, CanvasRepository, .context, Bool, Int, ModelContainer, CachedSubmissionDraft, Date (+1 more)

### Community 5 - "Canvas Grades — Windowed Desktop App Design Spec"
Cohesion: 0.06
Nodes (33): Known debt (candidates for the next planning pass), Next up, Phase status, Project Status — Canvas Grades (Windowed Desktop Client), What this project actually is, 10. Open risks, 1. Overview, 2.1 Package structure (+25 more)

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

### Community 11 - "AppSession"
Cohesion: 0.12
Nodes (18): AppSession, .apiClient, .hasCredentials, .isDemo, Bool, CanvasRepository, Bool, Bool (+10 more)

### Community 12 - "CanvasCLISwift Phase 2 Implementation Plan"
Cohesion: 0.12
Nodes (16): CanvasCLISwift Phase 2 Implementation Plan, File Structure, Global Constraints, Self-Review Notes, Task 10: TUI course detail — grade dashboard, Task 11: Calculator screen + `calc` subcommand, Task 1: Package setup — dependencies, file split, test target, Task 2: Models + JSON decoding tests (+8 more)

### Community 13 - "CoursesViewModel"
Cohesion: 0.16
Nodes (12): PopoverContent, .coursesVM, CoursesViewModel, Bool, Date, Double, Int, CourseListView (+4 more)

### Community 14 - "Course Filtering Design"
Cohesion: 0.12
Nodes (15): Approach, AppState changes, Architecture, Change, Course Filtering Design, CourseListView changes, CoursesViewModel changes, Data Persistence (+7 more)

### Community 15 - "Onboarding — Demo-First First-Run Design"
Cohesion: 0.13
Nodes (14): AppState — demo state, Components, ConnectView (new) — replaces SettingsView as the onboarding entry, Current funnel (before), Data flow, Error handling / edge cases, Goal, KeychainWarningView (reused, relocated) (+6 more)

### Community 16 - "CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan"
Cohesion: 0.14
Nodes (13): CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan, File Map, Global Constraints, Self-Review, Task 1: Restructure SPM — Migrate CanvasCore + Retire CLI, Task 2: Grading Scale — Models Update + letterGrade Function, Task 3: Target Grade Solver, Task 4: App Shell — MenuBarExtra + Keychain + Brand Colors (+5 more)

### Community 17 - "XCTestCase"
Cohesion: 0.06
Nodes (22): .normalizedHost, APIClientMessagingTests, URLSession, APIClientPaginationTests, PaginationStub, Bool, Data, URLRequest (+14 more)

### Community 18 - "Visual Design"
Cohesion: 0.15
Nodes (12): Card anatomy, Card chrome, Course List Redesign — Billboard Grade Cards, Files Changed, Goal, Grade color mapping (existing system), Layout / List Structure, No-grade state (+4 more)

### Community 19 - "Instructor Messaging — Design Spec"
Cohesion: 0.17
Nodes (11): `APIClient` additions, Compose ViewModel, `ComposeMessageSheet`, `CourseDetailViewModel` change, Data Layer, Error Handling, Files Changed / Added, Instructor Messaging — Design Spec (+3 more)

### Community 20 - "Keychain Onboarding UX — Design Spec"
Cohesion: 0.17
Nodes (11): `AppState` changes, `CanvasApp.swift` changes, Components, Files Changed, Flow, Goals, Keychain Onboarding UX — Design Spec, `KeychainHelper` changes (+3 more)

### Community 21 - "AssignmentPredicatesTests"
Cohesion: 0.06
Nodes (32): AssignmentFilter, all, graded, missing, upcoming, assignmentMatchesFilter(), isAssignmentMissing(), Bool (+24 more)

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "CachedFile"
Cohesion: 0.17
Nodes (13): CachedFile, CachedFolder, Date, Int, Int64, FileRow, .body, FolderRow (+5 more)

### Community 24 - "Router"
Cohesion: 0.18
Nodes (9): DashboardDensity, cards, ledger, Router, .courseTab, .dashboardDensity, .sandboxOpen, .sidebar (+1 more)

### Community 25 - "Codable"
Cohesion: 0.18
Nodes (22): Codable, Decodable, buildGradedItems(), Announcement, Assignment, AssignmentGroup, AssignmentGroupRules, Course (+14 more)

### Community 26 - "File Map"
Cohesion: 0.22
Nodes (8): Course Filtering Implementation Plan, File Map, Global Constraints, Task 1: Add enrollment_type filter to APIClient, Task 2: Create HiddenCoursesStore, Task 3: Update CoursesViewModel and AppState, Task 4: Add swipe-to-hide in CourseListView, Task 5: Add Hidden Courses restore section in SettingsView

### Community 27 - ".body"
Cohesion: 0.24
Nodes (5): KeychainHelper, CustomizationSection, .body, .body, Security

### Community 28 - "2026-06-26"
Cohesion: 0.25
Nodes (7): 2026-06-26, Bug Fixes, Canvas API, Changelog, Course Stream (new), Dev Experience, UI

### Community 29 - "File Map"
Cohesion: 0.25
Nodes (7): File Map, Global Constraints, Keychain Onboarding UX Implementation Plan, Task 1: Fix KeychainHelper — upsert save and friendly metadata, Task 2: Update AppState — lazy token load and acknowledgement flag, Task 3: Create KeychainWarningView, Task 4: Wire KeychainWarningView into PopoverContent and verify full flow

### Community 30 - "Student UX Brief — CanvasCLISwift"
Cohesion: 0.25
Nodes (7): Context, Larger Features (future scope), Prioritized Implementation Order, QoL Improvements, Quick Wins (implement first), Student UX Brief — CanvasCLISwift, Visual Polish

### Community 31 - "TestState"
Cohesion: 0.40
Nodes (5): TestState, failure, idle, success, testing

### Community 32 - "ChangeKind"
Cohesion: 0.13
Nodes (15): ChangeKind, dueSoon, gradeChanged, newAnnouncement, newFeedback, newGrade, newMessage, ChangeRecord (+7 more)

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

### Community 40 - "DashboardView"
Cohesion: 0.08
Nodes (29): CourseLedgerRow, DashboardViewModel, Bool, Color, Date, Double, Int, DashboardView (+21 more)

### Community 42 - "CourseCard"
Cohesion: 0.29
Nodes (6): CourseCard, .body, .displayLetter, .gradeColor, Color, Double

### Community 43 - ".makeRepo"
Cohesion: 0.39
Nodes (3): DerivedReadsTests, CanvasRepository, Date

### Community 44 - "SyncEngine"
Cohesion: 0.09
Nodes (27): Date, EntityKind, announcements, assignments, calendarEvents, conversations, courses, discussionEntries (+19 more)

### Community 45 - "AssignmentGroupingTests"
Cohesion: 0.12
Nodes (7): assignmentKind(), AssignmentGroupingTests, Bool, Calendar, Date, Double, Int

### Community 46 - ".submissionChanges"
Cohesion: 0.12
Nodes (14): ChangeDetector, PendingChange, SubmissionSnapshot, Bool, Date, Double, Int, Set (+6 more)

### Community 47 - "2026-08-09-phase3-time.md"
Cohesion: 0.08
Nodes (25): Architecture, Context, File Structure, Global Constraints, GROUP A — CORE MODELS & API CLIENT (CanvasCore), GROUP B — DATA PERSISTENCE & SYNC (CanvasData), GROUP C — CALENDAR UI (CanvasUI & CanvasApp), GROUP D — TO-DO UI & DUE-SOON SURFACES (CanvasUI & CanvasApp) (+17 more)

### Community 48 - "SemesterTimelineStrip"
Cohesion: 0.17
Nodes (16): makeSyntheticTicks(), SemesterTimelineStrip, .body, SemesterTimelineStripPreviewContainer, .body, Style, finalExam, graded (+8 more)

### Community 49 - "ScenarioChips"
Cohesion: 0.23
Nodes (8): HypotheticalSlider, .body, .hypotheticalsSection, ScenarioChips, .actualPercent, .body, Binding, Double

### Community 50 - "LedgerRowView"
Cohesion: 0.06
Nodes (36): .ledgerSection, GradeCalculator, PointsLedger, Double, Color, DesignTokenSwatches, .body, dynamic() (+28 more)

### Community 51 - "String"
Cohesion: 0.14
Nodes (15): String, Int, Result, AssignmentReadonlySections, .body, .commentsSection, Error, Conversation (+7 more)

### Community 52 - "Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox"
Cohesion: 0.10
Nodes (20): 1.1 Header, 1.2 Semester timeline strip, 1.3 Ledger table, 1.4 Bottom panels — 2-column grid, `1fr 1.15fr`, gap 26, 1.5 Sidebar (both themes), 1. Dashboard (`SidebarItem.dashboard` detail pane) — options `3a` / `3b`, 2. Course workspace + Sandbox — option `1d`, About the Design Files (+12 more)

### Community 53 - ".plan"
Cohesion: 0.08
Nodes (22): Date, NotificationSettingsStore, .anyCategoryEnabled, .settings, Stored, Bool, Int, NotificationPlanner (+14 more)

### Community 54 - "Task Dependency Order"
Cohesion: 0.11
Nodes (18): File Structure, Global Constraints, Phase 1a — Dashboard + What-If Sandbox Implementation Plan, Self-Review, Task 10: Dashboard bottom panels (`CanvasUI`), Task 11: DashboardView composition + wire into MainWindowView (`CanvasApp`), Task 12: Course-scope Sandbox rail + grades-tab dock (`CanvasUI` + `CanvasApp`), Task 13: Term-scope Sandbox rail on the Dashboard (`CanvasApp`) (+10 more)

### Community 55 - "CourseGradeSummary"
Cohesion: 0.17
Nodes (21): Suggestion, Double, Int, TermScenarioViewModel, .cappingSummary, .currentGPA, .lift, .projectedGPA (+13 more)

### Community 56 - "RecordingStub"
Cohesion: 0.29
Nodes (5): RecordingStub, Bool, URL, URLRequest, URLProtocol

### Community 57 - "Task Dependency Order"
Cohesion: 0.09
Nodes (22): Architecture, Context, Critical Files for Implementation, File Structure, Global Constraints, Phase 1b — Assignments, Announcements, Syllabus, Grade Trend Chart Implementation Plan, Task 10: Grade trend chart (`CanvasUI`), Task 11: `AssignmentsViewModel` + `AssignmentsTabView` (`CanvasApp`) (+14 more)

### Community 58 - "APIClient"
Cohesion: 0.10
Nodes (15): APIClient, .baseURL, .token, http, network, Data, Date, Int (+7 more)

### Community 59 - "Text"
Cohesion: 0.08
Nodes (34): DisclosureRow, .body, Color, .body, ComingSoonView, .body, Bool, Double (+26 more)

### Community 60 - "letterGrade"
Cohesion: 0.18
Nodes (11): .headline, GroupResult, letterGrade(), .body, GradeDashboard, .body, GroupBreakdownRow, .body (+3 more)

### Community 62 - "Canvas Grades"
Cohesion: 0.17
Nodes (11): Build from source, Canvas Grades, Download, Features, Getting a Canvas API token, Homebrew (coming soon), Install, License (+3 more)

### Community 63 - "StreamItem"
Cohesion: 0.09
Nodes (24): GradesSandboxSplit, .actualCalculator, .body, .mainColumn, .trendSection, Date, GradeCalculator, Int (+16 more)

### Community 64 - "UnifiedCalendarItem"
Cohesion: 0.12
Nodes (25): CalendarViewModel, Bool, Color, Date, Int, CalendarView, .body, .periodTitle (+17 more)

### Community 65 - "RichTextView"
Cohesion: 0.06
Nodes (42): DiscussionEntryView, .body, DiscussionTopicRow, .body, Bool, Date, Int, Void (+34 more)

### Community 66 - "CachedSubmission"
Cohesion: 0.21
Nodes (8): CachedComment, CachedSubmission, .rubricAssessment, Bool, Data, Date, Double, Int

### Community 67 - "ToDoItem"
Cohesion: 0.15
Nodes (18): Bool, Color, Int, ToDoViewModel, ToDoView, .body, DueSoonStrip, .body (+10 more)

### Community 69 - "FilesViewModel"
Cohesion: 0.27
Nodes (9): FilesViewModel, .visibleFiles, .visibleFolders, Int, URL, FilesTabView, .body, .breadcrumbBar (+1 more)

### Community 70 - "BackgroundRefreshController"
Cohesion: 0.29
Nodes (4): BackgroundRefreshController, Date, Timer, UNUserNotificationCenterDelegate

### Community 71 - "AssignmentsViewModel"
Cohesion: 0.13
Nodes (18): AssignmentsViewModel, .boardColumns, .dueThisWeek, .instructorComments, .selectedRow, BoardColumnRows, .count, Row (+10 more)

### Community 72 - "2026-08-22-phase4-content.md"
Cohesion: 0.07
Nodes (26): Architecture, Context, File Structure, Global Constraints, GROUP A — CORE MODELS & API CLIENT (CanvasCore), GROUP B — DATA PERSISTENCE & SYNC (CanvasData), GROUP C — MODULES UI (CanvasUI & CanvasApp), GROUP D — FILES & QUICK LOOK UI (CanvasUI & CanvasApp) (+18 more)

### Community 73 - "htmlNeedsWebView"
Cohesion: 0.15
Nodes (3): htmlNeedsWebView(), Bool, RichTextHeuristicTests

### Community 74 - "SwiftUI"
Cohesion: 0.07
Nodes (5): AppKit, CanvasUI, QuickLook, SwiftUI, WebKit

### Community 75 - "Foundation"
Cohesion: 0.06
Nodes (8): Foundation, IOKit.ps, ISO8601DateFormatter, Network, CanvasDate, DateFormatter, UniformTypeIdentifiers, UserNotifications

### Community 76 - "CalculatorViewModel"
Cohesion: 0.08
Nodes (31): CalculatorView, .body, SolveForMeTabView, .body, .gradeLetters, SolveResultView, .body, Binding (+23 more)

### Community 77 - "GroupInfo"
Cohesion: 0.32
Nodes (4): GroupInfo, GradeCalculatorTests, Double, Int

### Community 78 - "CachedModuleItem"
Cohesion: 0.06
Nodes (38): ModulesViewModel, Int, ModulesTabView, .anyExpanded, .body, .expandCollapseBar, Binding, Bool (+30 more)

### Community 79 - ".client"
Cohesion: 0.31
Nodes (3): ProfileTests, Data, Int

### Community 80 - "RubricCriterion"
Cohesion: 0.23
Nodes (11): formatRubricAssessment(), RubricAssessmentEntry, RubricCriterion, RubricLine, RubricRating, Double, RubricTable, .body (+3 more)

### Community 81 - "Color"
Cohesion: 0.25
Nodes (5): Color, .secondaryLabel, .systemBackground, .systemGroupedBackground, Int

### Community 82 - "CourseSettingsStore"
Cohesion: 0.23
Nodes (8): CourseQuickLink, CourseSettingsStore, Double, Int, UserDefaults, UUID, CourseSettingsRow, .body

### Community 83 - "GROUP A — INBOX"
Cohesion: 0.06
Nodes (32): Architecture, Context, Execution Handoff, File Structure, Global Constraints, Global test harness reference, GROUP A — INBOX, GROUP B — DISCUSSIONS (read-only) (+24 more)

### Community 84 - "ComposeSheet"
Cohesion: 0.18
Nodes (15): ComposeSheet, .body, .canSend, ConversationRow, .body, MessageBubble, .body, ReplyComposer (+7 more)

### Community 85 - "Module"
Cohesion: 0.36
Nodes (7): CompletionRequirement, Module, ModuleItem, Bool, Date, Double, Int

### Community 86 - "DiscussionsViewModel"
Cohesion: 0.17
Nodes (13): DiscussionsViewModel, .selectedTopic, Date, Int, DiscussionsTabView, .body, .detailColumn, .listColumn (+5 more)

### Community 87 - "GradeTrendChart"
Cohesion: 0.16
Nodes (15): Charts, ClosedRange, GradeTrendChart, .body, .chart, .emptyState, .visibleThresholds, .yDomain (+7 more)

### Community 88 - "MockData"
Cohesion: 0.13
Nodes (4): MockData, Double, Int, MockDataTests

### Community 89 - "AnnouncementsViewModel"
Cohesion: 0.08
Nodes (25): AnnouncementsViewModel, .selected, Bool, Date, Int, AnnouncementsTabView, .body, .detailColumn (+17 more)

### Community 90 - "CachedConversation"
Cohesion: 0.27
Nodes (8): .selected, CachedConversation, .participants, CachedMessage, Bool, Data, Date, Int

### Community 91 - "Sendable"
Cohesion: 0.18
Nodes (16): Equatable, Sendable, DiscussionEntryNode, DiscussionParticipant, DiscussionTopic, DiscussionView, FlatDiscussionEntry, flattenDiscussion() (+8 more)

### Community 92 - "SidebarItem"
Cohesion: 0.14
Nodes (14): RevealTarget, assignment, conversation, course, section, SidebarItem, calendar, course (+6 more)

### Community 93 - "CachedPlannerItem"
Cohesion: 0.18
Nodes (7): Date, CachedCalendarEvent, CachedPlannerItem, Bool, Date, Int, PlannerModelsDataTests

### Community 94 - "View"
Cohesion: 0.11
Nodes (27): .body, KeychainWarningView, .body, SettingsView, .canSave, .canTestConnection, WelcomeView, QuickLinkEditor (+19 more)

### Community 95 - "DueChip"
Cohesion: 0.16
Nodes (15): AssignmentBoardCard, .body, .pointsText, Color, DueChip, .body, .color, .label (+7 more)

### Community 96 - "CodingKeys"
Cohesion: 0.04
Nodes (45): CodingKey, CodingKeys, contextCode, description, endAt, htmlUrl, id, locationName (+37 more)

### Community 97 - "PowerState"
Cohesion: 0.32
Nodes (6): PowerState, shouldRunBackgroundTick(), Bool, Date, Int, BackgroundGateTests

### Community 98 - "SearchResultItem"
Cohesion: 0.14
Nodes (17): Category, announcement, assignment, course, discussion, file, moduleItem, SearchResultItem (+9 more)

### Community 99 - "FormRecordingStub"
Cohesion: 0.22
Nodes (6): InputStream, FormRecordingStub, Bool, Data, URL, URLRequest

### Community 100 - "2026-09-03-phase5-submission.md"
Cohesion: 0.08
Nodes (23): File Structure, Global Constraints, GROUP A — CORE MODELS, PURE BUILDERS & API CLIENT (`CanvasCore`), GROUP B — DATA PERSISTENCE & ORCHESTRATION (`CanvasData`), GROUP C — SUBMISSION UI (`CanvasUI`), GROUP D — APP INTEGRATION (`CanvasApp`), GROUP E — VERIFICATION, Phase 5 — Submission Implementation Plan (+15 more)

### Community 101 - ".init"
Cohesion: 0.24
Nodes (8): .effectiveItems, InputMode, percent, points, Bool, Double, Int, WhatIfEntry

### Community 102 - "NotificationSettingsSection"
Cohesion: 0.33
Nodes (5): NotificationSettingsSection, .body, .hourOptions, Binding, Bool

### Community 103 - "GradeCalculator"
Cohesion: 0.19
Nodes (10): Array, GradeCalculator, SolveResult, alreadyAchieved, impossible, needed, Bool, Double (+2 more)

### Community 106 - "ConversationScope"
Cohesion: 0.18
Nodes (10): Mode, agenda, .id, month, week, CaseIterable, ConversationScope, archived (+2 more)

### Community 108 - "Paper & Signal — Implementation Plan"
Cohesion: 0.18
Nodes (10): 1a. Set the token to orchid, 1b. Key subtlety — `.tint()` vs `Color.accentColor`, 1c. Sites to re-point (from grep 2026-09-01), 1d. Verify, Chosen values, Direction in one line, HIG guardrails, Paper & Signal — Implementation Plan (+2 more)

### Community 109 - "SubmissionViewModel"
Cohesion: 0.13
Nodes (15): SubmissionViewModel, .attemptNumber, .canSubmit, .isSubmitting, .uiFiles, Bool, Date, Int (+7 more)

### Community 110 - ".boardColumn"
Cohesion: 0.27
Nodes (7): .boardColumn, AssignmentBoardColumn, BoardSummaryLine, .body, .divider, Content, Int

### Community 111 - "QuickOpenViewModel"
Cohesion: 0.22
Nodes (10): QuickOpenViewModel, .query, Bool, Int, QuickOpenOverlay, .body, .headerSearchField, .resultsList (+2 more)

### Community 112 - "PlannerItem"
Cohesion: 0.31
Nodes (9): Encoder, NestedPlannable, PlannerItem, PlannerOverride, PlannerSubmissionSummary, Bool, Date, Decoder (+1 more)

### Community 113 - "SubmissionHTML"
Cohesion: 0.17
Nodes (10): ListKind, ordered, unordered, SubmissionHTML, Any, Bool, CGFloat, Int (+2 more)

### Community 114 - "CalendarEvent"
Cohesion: 0.38
Nodes (5): CalendarEvent, .courseId, Date, Decoder, Int

### Community 115 - ".html"
Cohesion: 0.23
Nodes (3): SubmissionHTMLTests, Any, NSAttributedString

### Community 116 - "SolverTests"
Cohesion: 0.36
Nodes (4): SolverTests, Double, GradeCalculator, Int

### Community 117 - "SyncScope"
Cohesion: 0.15
Nodes (13): SyncScope, all, conversation, course, discussion, files, inbox, modules (+5 more)

### Community 118 - "RichTextEditorRepresentable"
Cohesion: 0.13
Nodes (12): Notification, NSObject, NSScrollView, NSTextViewDelegate, NSViewRepresentable, Coordinator, RichTextEditor, .body (+4 more)

### Community 119 - "AssignmentRow"
Cohesion: 0.25
Nodes (9): AssignmentRow, .body, .isHypothetical, .assignmentsSection, .groupsSection, GroupLiftRow, .body, Bool (+1 more)

### Community 120 - "CanvasFile"
Cohesion: 0.44
Nodes (6): CanvasFile, CanvasFolder, Bool, Date, Int, Int64

### Community 121 - "DueUrgency"
Cohesion: 0.19
Nodes (16): BoardAssignment, BoardColumn, boardColumns(), calendarDaysUntil(), DueUrgency, later, none, overdue (+8 more)

### Community 123 - "BoardStatus"
Cohesion: 0.21
Nodes (14): AssignmentDetailFormat, AssignmentDetailHeader, .body, assignmentDueDescription(), assignmentPointsPill(), assignmentStatusPill(), Date, DateFormatter (+6 more)

### Community 125 - "CourseDetailViewModel"
Cohesion: 0.13
Nodes (16): CourseDetailViewModel, .calculator, Date, GradeCalculator, Int, CourseDetailBody, .body, CourseDetailView (+8 more)

### Community 126 - "SyncStub"
Cohesion: 0.20
Nodes (5): Bool, Data, Int, URLRequest, SyncStub

### Community 127 - "SubmissionRequestTests"
Cohesion: 0.18
Nodes (3): SubmissionValidator, Bool, SubmissionRequestTests

### Community 128 - ".ids"
Cohesion: 0.33
Nodes (4): LegacyHiddenCourses, Int, Set, UserDefaults

### Community 130 - "SubmissionEditor"
Cohesion: 0.24
Nodes (12): PickedFile, SubmissionConfirmationSheet, .body, SubmissionEditor, .body, .fileList, Binding, Bool (+4 more)

### Community 131 - "AssignmentGrouping"
Cohesion: 0.27
Nodes (8): AssignmentGrouping, due, .label, status, type, AssignmentGroupByControl, .body, Binding

### Community 132 - "RouteStub"
Cohesion: 0.29
Nodes (4): RouteStub, Bool, Data, URLRequest

### Community 133 - "BoardTint"
Cohesion: 0.19
Nodes (10): BoardTint, accent, danger, muted, neutral, positive, warning, .body (+2 more)

### Community 134 - "FixedResponseStub"
Cohesion: 0.33
Nodes (3): FixedResponseStub, Bool, URLRequest

### Community 135 - "AddQuickLinkSheet"
Cohesion: 0.19
Nodes (10): AddQuickLinkSheet, .body, .canSave, .isEditing, .title, Bool, Content, Int (+2 more)

### Community 136 - "CanvasGradesApp"
Cohesion: 0.40
Nodes (6): App, CanvasGradesApp, .body, .preferredColorScheme, ColorScheme, Scene

### Community 138 - ".userNotificationCenter"
Cohesion: 0.33
Nodes (4): UNNotification, UNNotificationPresentationOptions, UNNotificationResponse, UNUserNotificationCenter

### Community 139 - "RichTextToolbar"
Cohesion: 0.22
Nodes (6): RichTextToolbar, .divider, .headingLabel, .linkPopover, Bool, Void

### Community 140 - "CourseTab"
Cohesion: 0.25
Nodes (8): CourseTab, announcements, assignments, discussions, files, grades, modules, syllabus

### Community 141 - "PickedFileEntry"
Cohesion: 0.32
Nodes (5): PickedFileEntry, .id, Data, URL, UUID

### Community 142 - "Backlog: On-Device AI Pacing Tracker (per-course "behind risk")"
Cohesion: 0.25
Nodes (7): Architecture (mirrors the existing `calculatorInputs` → `GradeCalculator` split), Backlog: On-Device AI Pacing Tracker (per-course "behind risk"), Critical files, Design notes, Scope decisions (from brainstorming), Summary, Verification

### Community 143 - "APIError"
Cohesion: 0.15
Nodes (12): CustomStringConvertible, APIError, .description, forbidden, missingToken, rateLimited, unauthorized, TimeInterval (+4 more)

### Community 144 - "SubmissionType"
Cohesion: 0.13
Nodes (8): SubmissionType, onlineText, onlineUpload, onlineURL, SubmissionFile, Data, MockDataSubmitTests, Int

### Community 146 - "Phase"
Cohesion: 0.22
Nodes (9): Phase, failed, idle, submitting, success, uploading, verifying, SubmissionStatusView (+1 more)

## Knowledge Gaps
- **627 isolated node(s):** `.isDemo`, `.hasCredentials`, `IOKit.ps`, `Network`, `.coursesVM` (+622 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **20 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `String` connect `String` to `Credentials`, `CachedAssignment`, `Identifiable`, `RichTextController`, `CanvasRepository`, `AppSession`, `CoursesViewModel`, `XCTestCase`, `AssignmentPredicatesTests`, `CachedFile`, `Router`, `Codable`, `.body`, `TestState`, `ChangeKind`, `DashboardView`, `CourseCard`, `.makeRepo`, `SyncEngine`, `AssignmentGroupingTests`, `.submissionChanges`, `ScenarioChips`, `LedgerRowView`, `.plan`, `CourseGradeSummary`, `APIClient`, `Text`, `letterGrade`, `CanvasData`, `StreamItem`, `UnifiedCalendarItem`, `RichTextView`, `CachedSubmission`, `ToDoItem`, `FilesViewModel`, `AssignmentsViewModel`, `htmlNeedsWebView`, `CalculatorViewModel`, `GroupInfo`, `CachedModuleItem`, `.client`, `RubricCriterion`, `Color`, `CourseSettingsStore`, `ComposeSheet`, `Module`, `DiscussionsViewModel`, `GradeTrendChart`, `MockData`, `AnnouncementsViewModel`, `CachedConversation`, `Sendable`, `SidebarItem`, `CachedPlannerItem`, `View`, `DueChip`, `CodingKeys`, `SearchResultItem`, `FormRecordingStub`, `.init`, `NotificationSettingsSection`, `GradeCalculator`, `ConversationScope`, `SubmissionViewModel`, `.boardColumn`, `QuickOpenViewModel`, `PlannerItem`, `SubmissionHTML`, `CalendarEvent`, `.html`, `SyncScope`, `RichTextEditorRepresentable`, `AssignmentRow`, `CanvasFile`, `DueUrgency`, `BoardStatus`, `CourseDetailViewModel`, `SyncStub`, `SubmissionRequestTests`, `SubmissionEditor`, `AssignmentGrouping`, `RouteStub`, `BoardTint`, `FixedResponseStub`, `AddQuickLinkSheet`, `CanvasGradesApp`, `RichTextControllerTests`, `RichTextToolbar`, `CourseTab`, `PickedFileEntry`, `APIError`, `SubmissionType`, `.build`, `Phase`?**
  _High betweenness centrality (0.435) - this node is a cross-community bridge._
- **Why does `View` connect `View` to `Identifiable`, `AssignmentGrouping`, `SubmissionEditor`, `BoardTint`, `AddQuickLinkSheet`, `AppSession`, `RichTextToolbar`, `CoursesViewModel`, `Phase`, `AssignmentPredicatesTests`, `CachedFile`, `.body`, `DashboardView`, `CourseCard`, `SemesterTimelineStrip`, `ScenarioChips`, `LedgerRowView`, `String`, `Text`, `letterGrade`, `StreamItem`, `UnifiedCalendarItem`, `RichTextView`, `ToDoItem`, `FilesViewModel`, `AssignmentsViewModel`, `CalculatorViewModel`, `CachedModuleItem`, `RubricCriterion`, `CourseSettingsStore`, `ComposeSheet`, `DiscussionsViewModel`, `GradeTrendChart`, `AnnouncementsViewModel`, `DueChip`, `SearchResultItem`, `NotificationSettingsSection`, `SubmissionViewModel`, `.boardColumn`, `QuickOpenViewModel`, `RichTextEditorRepresentable`, `AssignmentRow`, `BoardStatus`, `CourseDetailViewModel`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Why does `CanvasCore` connect `CanvasCore` to `UnifiedCalendarItem`, `ToDoItem`, `SwiftUI`, `Foundation`, `CachedModuleItem`, `XCTestCase`, `GradeTrendChart`, `Sendable`, `CanvasData`, `DueChip`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 130 inferred relationships involving `Text` (e.g. with `.body` and `.body`) actually correct?**
  _`Text` has 130 INFERRED edges - model-reasoned connections that need verification._
- **Are the 30 inferred relationships involving `APIClient` (e.g. with `APIClientDemoTests` and `.startLoading()`) actually correct?**
  _`APIClient` has 30 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isDemo`, `.hasCredentials`, `IOKit.ps` to the rest of the system?**
  _627 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Credentials` be split into smaller, more focused modules?**
  _Cohesion score 0.10584415584415584 - nodes in this community are weakly interconnected._