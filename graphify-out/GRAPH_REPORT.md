# Graph Report - CanvasCLISwift  (2026-09-02)

## Corpus Check
- 185 files · ~149,931 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2485 nodes · 5610 edges · 120 communities (106 shown, 14 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 770 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `d1ae2013`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Credentials
- CachedCourse
- DashboardView
- CanvasData
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
- AssignmentPredicatesTests
- File Map
- CachedFile
- Router
- Codable
- File Map
- .load
- 2026-06-26
- File Map
- Student UX Brief — CanvasCLISwift
- SettingsView
- ChangeKind
- CanvasCore
- Global Constraints
- Global Constraints
- Canvas API Pagination Implementation Plan
- Course List Billboard Card Redesign Implementation Plan
- CLAUDE.md
- Package.swift
- FeedbackRow
- ModelsTests
- CourseCard
- XCTestCase
- SyncEngine
- .makeRepo
- .submissionChanges
- 2026-08-09-phase3-time.md
- CourseDetailViewModel
- ScenarioChips
- LedgerRowView
- Conversation
- Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox
- .plan
- Task Dependency Order
- CourseGradeSummary
- SyncStub
- Task Dependency Order
- APIClient
- Text
- SemesterTimelineStrip
- SyncEngineCourseTests
- Canvas Grades
- AssignmentRow
- UnifiedCalendarItem
- RichTextView
- CachedSubmission
- ToDoItem
- run-app.sh
- ModuleSectionView
- AssignmentFilter
- AssignmentsViewModel
- 2026-08-22-phase4-content.md
- htmlNeedsWebView
- SwiftUI
- Foundation
- CalculatorViewModel
- AssignmentListRow
- StreamItem
- .client
- RubricCriterion
- Color
- MainWindowView.swift
- GROUP A — INBOX
- ComposeSheet
- Identifiable
- DiscussionsViewModel
- GradeTrendChart
- MockData
- AnnouncementsViewModel
- CachedConversation
- Equatable
- SidebarItem
- CachedPlannerItem
- ModulesViewModel
- BackgroundRefreshController
- CodingKeys
- PowerState
- SearchResultItem
- FormRecordingStub
- CachedModuleItem
- AgeCapsule
- AppSession
- GroupInfo
- .normalizeHost
- ConversationModelsTests
- RepositoryTests
- Style
- Paper & Signal — Implementation Plan
- BackgroundRefreshController.swift
- QuickOpenViewModel
- Sendable
- CalendarEvent
- CalendarModelsTests
- PlannerModelsTests
- CanvasFile
- FileModelsTests
- ModuleModelsTests
- DiscussionModelsTests
- View

## God Nodes (most connected - your core abstractions)
1. `CanvasCore` - 100 edges
2. `APIClient` - 92 edges
3. `SyncEngine` - 83 edges
4. `AppSession` - 73 edges
5. `CanvasData` - 57 edges
6. `Credentials` - 54 edges
7. `CalculatorViewModel` - 53 edges
8. `XCTest` - 49 edges
9. `CanvasRepository` - 46 edges
10. `MockData` - 44 edges

## Surprising Connections (you probably didn't know these)
- `.filteredRows` --calls--> `assignmentMatchesFilter()`  [INFERRED]
  CanvasApp/ViewModels/AssignmentsViewModel.swift → Sources/CanvasCore/AssignmentPredicates.swift
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

## Communities (120 total, 14 thin omitted)

### Community 0 - "Credentials"
Cohesion: 0.15
Nodes (8): Credentials, CanvasStore, Bool, ModelContainer, AnnouncementSyncTests, ConversationSyncTests, SyncEngineAllTests, SyncEnginePolicyTests

### Community 1 - "CachedCourse"
Cohesion: 0.21
Nodes (14): CachedAssignment, .rubric, CachedAssignmentGroup, CachedCourse, .gradingScale, CachedEnrollment, SchemePair, Bool (+6 more)

### Community 2 - "DashboardView"
Cohesion: 0.12
Nodes (20): DashboardView, .awaitingRows, .body, .dashboardContent, .dotColors, .emptyState, .errorState, .feedbackRows (+12 more)

### Community 4 - "CanvasRepository"
Cohesion: 0.10
Nodes (9): FetchDescriptor, ModelContext, CanvasRepository, .context, Bool, Date, Int, ModelContainer (+1 more)

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

### Community 11 - "InboxViewModel"
Cohesion: 0.21
Nodes (12): InboxViewModel, Bool, Date, Int, String, InboxView, .body, .listColumn (+4 more)

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
Cohesion: 0.13
Nodes (9): APIClientMessagingTests, URLSession, APIClientPaginationTests, PaginationStub, Bool, Data, String, URLRequest (+1 more)

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
Cohesion: 0.15
Nodes (6): assignmentMatchesFilter(), isAssignmentMissing(), Bool, Date, Double, AssignmentPredicatesTests

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "CachedFile"
Cohesion: 0.11
Nodes (25): FilesViewModel, .visibleFiles, .visibleFolders, Int, String, URL, FilesTabView, .body (+17 more)

### Community 24 - "Router"
Cohesion: 0.16
Nodes (12): RevealTarget, assignment, conversation, course, section, Router, .courseTab, .dashboardDensity (+4 more)

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
Cohesion: 0.15
Nodes (14): NotificationSettingsSection, .body, .hourOptions, SettingsView, .canSave, .canTestConnection, Binding, Bool (+6 more)

### Community 32 - "ChangeKind"
Cohesion: 0.14
Nodes (17): ChangeKind, dueSoon, gradeChanged, newAnnouncement, newFeedback, newGrade, newMessage, ChangeRecord (+9 more)

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

### Community 40 - "FeedbackRow"
Cohesion: 0.23
Nodes (16): .bottomPanels, AwaitingGradePanel, AwaitingRow, DashboardPanelsPreview, .awaitingRows, .body, .feedbackRows, FeedbackRow (+8 more)

### Community 42 - "CourseCard"
Cohesion: 0.28
Nodes (7): CourseCard, .body, .displayLetter, .gradeColor, Color, Double, String

### Community 43 - "XCTestCase"
Cohesion: 0.10
Nodes (15): CalendarAPITests, FileAPITests, ModuleAPITests, PlannerAPITests, ConcurrencyStressTests, ConversationWriteTests, ModelContainer, DiscussionSyncTests (+7 more)

### Community 44 - "SyncEngine"
Cohesion: 0.06
Nodes (52): CustomStringConvertible, Error, ISO8601DateFormatter, CanvasDate, Date, String, LegacyHiddenCourses, Int (+44 more)

### Community 45 - ".makeRepo"
Cohesion: 0.33
Nodes (4): DerivedReadsTests, CanvasRepository, Date, String

### Community 46 - ".submissionChanges"
Cohesion: 0.11
Nodes (17): ChangeDetector, PendingChange, SubmissionSnapshot, Bool, Date, Double, Int, Set (+9 more)

### Community 47 - "2026-08-09-phase3-time.md"
Cohesion: 0.08
Nodes (25): Architecture, Context, File Structure, Global Constraints, GROUP A — CORE MODELS & API CLIENT (CanvasCore), GROUP B — DATA PERSISTENCE & SYNC (CanvasData), GROUP C — CALENDAR UI (CanvasUI & CanvasApp), GROUP D — TO-DO UI & DUE-SOON SURFACES (CanvasUI & CanvasApp) (+17 more)

### Community 48 - "CourseDetailViewModel"
Cohesion: 0.16
Nodes (11): CourseDetailViewModel, .calculator, Bool, Date, GradeCalculator, Int, String, .body (+3 more)

### Community 49 - "ScenarioChips"
Cohesion: 0.17
Nodes (12): HypotheticalSlider, .body, ScenarioChips, .actualPercent, .body, Binding, Bool, Double (+4 more)

### Community 50 - "LedgerRowView"
Cohesion: 0.06
Nodes (38): .ledgerSection, GradeCalculator, PointsLedger, Double, Color, DesignTokenSwatches, .body, dynamic() (+30 more)

### Community 51 - "Conversation"
Cohesion: 0.21
Nodes (12): CaseIterable, Conversation, ConversationMessage, ConversationParticipant, ConversationScope, archived, inbox, unread (+4 more)

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
Cohesion: 0.08
Nodes (40): CourseSettingsStore, Double, Int, String, UserDefaults, CourseLedgerRow, DashboardViewModel, Bool (+32 more)

### Community 56 - "SyncStub"
Cohesion: 0.09
Nodes (12): HTTPURLResponse, RecordingStub, Bool, URL, URLRequest, Bool, Data, Int (+4 more)

### Community 57 - "Task Dependency Order"
Cohesion: 0.09
Nodes (22): Architecture, Context, Critical Files for Implementation, File Structure, Global Constraints, Phase 1b — Assignments, Announcements, Syllabus, Grade Trend Chart Implementation Plan, Task 10: Grade trend chart (`CanvasUI`), Task 11: `AssignmentsViewModel` + `AssignmentsTabView` (`CanvasApp`) (+14 more)

### Community 58 - "APIClient"
Cohesion: 0.10
Nodes (21): APIClient, .baseURL, .token, APIError, .description, forbidden, http, missingToken (+13 more)

### Community 59 - "Text"
Cohesion: 0.12
Nodes (26): Bool, Double, String, Void, TermSandboxRail, .body, .footer, .header (+18 more)

### Community 60 - "SemesterTimelineStrip"
Cohesion: 0.24
Nodes (11): makeSyntheticTicks(), SemesterTimelineStrip, .body, SemesterTimelineStripPreviewContainer, .body, CGFloat, Color, Date (+3 more)

### Community 61 - "SyncEngineCourseTests"
Cohesion: 0.21
Nodes (7): RouteStub, Bool, Data, Int, String, URLRequest, SyncEngineCourseTests

### Community 62 - "Canvas Grades"
Cohesion: 0.17
Nodes (11): Build from source, Canvas Grades, Download, Features, Getting a Canvas API token, Homebrew (coming soon), Install, License (+3 more)

### Community 63 - "AssignmentRow"
Cohesion: 0.24
Nodes (10): AssignmentRow, .body, .isHypothetical, .assignmentsSection, .groupsSection, GroupLiftRow, .body, Bool (+2 more)

### Community 64 - "UnifiedCalendarItem"
Cohesion: 0.09
Nodes (33): CalendarViewModel, Mode, agenda, .id, month, week, Bool, Color (+25 more)

### Community 65 - "RichTextView"
Cohesion: 0.08
Nodes (35): Content, Context, NSViewRepresentable, AttributedHTMLText, .attributed, .body, AttributedString, Coordinator (+27 more)

### Community 66 - "CachedSubmission"
Cohesion: 0.24
Nodes (9): CachedComment, CachedSubmission, .rubricAssessment, Bool, Data, Date, Double, Int (+1 more)

### Community 67 - "ToDoItem"
Cohesion: 0.14
Nodes (20): Bool, Color, Int, String, ToDoViewModel, ToDoView, .body, DueSoonStrip (+12 more)

### Community 69 - "ModuleSectionView"
Cohesion: 0.20
Nodes (10): ModuleItemRow, .body, .completionIcon, ModuleSectionView, .body, .header, Bool, Color (+2 more)

### Community 70 - "AssignmentFilter"
Cohesion: 0.21
Nodes (9): AssignmentFilter, all, graded, missing, upcoming, String, AssignmentFilterChips, .body (+1 more)

### Community 71 - "AssignmentsViewModel"
Cohesion: 0.12
Nodes (19): AssignmentsViewModel, .filteredRows, .instructorComments, .selectedRow, Row, .id, Bool, Date (+11 more)

### Community 72 - "2026-08-22-phase4-content.md"
Cohesion: 0.07
Nodes (26): Architecture, Context, File Structure, Global Constraints, GROUP A — CORE MODELS & API CLIENT (CanvasCore), GROUP B — DATA PERSISTENCE & SYNC (CanvasData), GROUP C — MODULES UI (CanvasUI & CanvasApp), GROUP D — FILES & QUICK LOOK UI (CanvasUI & CanvasApp) (+18 more)

### Community 73 - "htmlNeedsWebView"
Cohesion: 0.13
Nodes (5): htmlNeedsWebView(), Bool, String, .needsWebView, RichTextHeuristicTests

### Community 74 - "SwiftUI"
Cohesion: 0.10
Nodes (3): CanvasUI, QuickLook, SwiftUI

### Community 76 - "CalculatorViewModel"
Cohesion: 0.06
Nodes (42): CalculatorView, .body, SolveForMeTabView, .body, .gradeLetters, SolveResultView, .body, Binding (+34 more)

### Community 77 - "AssignmentListRow"
Cohesion: 0.11
Nodes (26): AssignmentComponentFormat, AssignmentComponentsPreview, .body, .due, .rubricLines, AssignmentListRow, .body, .content (+18 more)

### Community 78 - "StreamItem"
Cohesion: 0.07
Nodes (36): GradesSandboxSplit, .actualCalculator, .body, .mainColumn, Date, GradeCalculator, CalculatorInputs, CanvasRepository (+28 more)

### Community 79 - ".client"
Cohesion: 0.15
Nodes (7): FixedResponseStub, ProfileTests, Bool, Data, Int, String, URLRequest

### Community 80 - "RubricCriterion"
Cohesion: 0.40
Nodes (8): formatRubricAssessment(), RubricAssessmentEntry, RubricCriterion, RubricLine, RubricRating, Double, String, RubricTests

### Community 81 - "Color"
Cohesion: 0.22
Nodes (6): Color, .secondaryLabel, .systemBackground, .systemGroupedBackground, Int, String

### Community 82 - "MainWindowView.swift"
Cohesion: 0.18
Nodes (11): .body, KeychainWarningView, .body, DisclosureRow, .body, Color, String, WelcomeView (+3 more)

### Community 83 - "GROUP A — INBOX"
Cohesion: 0.06
Nodes (32): Architecture, Context, Execution Handoff, File Structure, Global Constraints, Global test harness reference, GROUP A — INBOX, GROUP B — DISCUSSIONS (read-only) (+24 more)

### Community 84 - "ComposeSheet"
Cohesion: 0.20
Nodes (16): ComposeSheet, .body, .canSend, ConversationRow, .body, MessageBubble, .body, ReplyComposer (+8 more)

### Community 85 - "Identifiable"
Cohesion: 0.36
Nodes (9): Identifiable, CompletionRequirement, Module, ModuleItem, Bool, Date, Double, Int (+1 more)

### Community 86 - "DiscussionsViewModel"
Cohesion: 0.10
Nodes (25): DiscussionsViewModel, .selectedTopic, Bool, Date, Int, String, DiscussionsTabView, .body (+17 more)

### Community 87 - "GradeTrendChart"
Cohesion: 0.15
Nodes (17): .trendSection, Charts, ClosedRange, GradeTrendChart, .body, .chart, .emptyState, .visibleThresholds (+9 more)

### Community 88 - "MockData"
Cohesion: 0.17
Nodes (3): MockData, Double, MockDataTests

### Community 89 - "AnnouncementsViewModel"
Cohesion: 0.08
Nodes (29): AnnouncementsViewModel, .selected, Bool, Date, Int, String, AnnouncementsTabView, .body (+21 more)

### Community 90 - "CachedConversation"
Cohesion: 0.36
Nodes (9): .selected, CachedConversation, .participants, CachedMessage, Bool, Data, Date, Int (+1 more)

### Community 91 - "Equatable"
Cohesion: 0.38
Nodes (9): Equatable, DiscussionEntryNode, DiscussionParticipant, DiscussionTopic, DiscussionView, FlatDiscussionEntry, flattenDiscussion(), Int (+1 more)

### Community 92 - "SidebarItem"
Cohesion: 0.11
Nodes (20): CourseTab, announcements, assignments, discussions, files, grades, modules, syllabus (+12 more)

### Community 93 - "CachedPlannerItem"
Cohesion: 0.42
Nodes (7): CachedCalendarEvent, CachedPlannerItem, Bool, Date, Int, String, PlannerModelsDataTests

### Community 94 - "ModulesViewModel"
Cohesion: 0.39
Nodes (6): ModulesViewModel, Int, String, ModulesTabView, .body, Int

### Community 95 - "BackgroundRefreshController"
Cohesion: 0.11
Nodes (16): App, BackgroundRefreshController, Date, CanvasGradesApp, .body, .preferredColorScheme, ColorScheme, String (+8 more)

### Community 96 - "CodingKeys"
Cohesion: 0.15
Nodes (13): CodingKey, CodingKeys, assignmentGroupId, descriptionHTML, dueAt, htmlURL, id, lockAt (+5 more)

### Community 97 - "PowerState"
Cohesion: 0.32
Nodes (6): PowerState, shouldRunBackgroundTick(), Bool, Date, Int, BackgroundGateTests

### Community 98 - "SearchResultItem"
Cohesion: 0.13
Nodes (18): Category, announcement, assignment, course, discussion, file, moduleItem, SearchResultItem (+10 more)

### Community 99 - "FormRecordingStub"
Cohesion: 0.12
Nodes (9): InputStream, ConversationAPITests, FormRecordingStub, Bool, Data, String, URL, URLRequest (+1 more)

### Community 100 - "CachedModuleItem"
Cohesion: 0.50
Nodes (6): CachedModule, CachedModuleItem, Bool, Date, Int, String

### Community 101 - "AgeCapsule"
Cohesion: 0.25
Nodes (7): AgeCapsule, .body, .isAged, .body, AwaitingGradeRowView, .body, Bool

### Community 102 - "AppSession"
Cohesion: 0.16
Nodes (12): AppSession, .apiClient, .hasCredentials, .isDemo, Bool, CanvasRepository, Error, Int (+4 more)

### Community 103 - "GroupInfo"
Cohesion: 0.06
Nodes (33): .headline, Array, GradeCalculator, GroupInfo, GroupResult, letterGrade(), SolveResult, alreadyAchieved (+25 more)

### Community 104 - ".normalizeHost"
Cohesion: 0.29
Nodes (3): .normalizedHost, String, CredentialsTests

### Community 107 - "Style"
Cohesion: 0.40
Nodes (5): Style, finalExam, graded, missing, upcoming

### Community 108 - "Paper & Signal — Implementation Plan"
Cohesion: 0.18
Nodes (10): 1a. Set the token to orchid, 1b. Key subtlety — `.tint()` vs `Color.accentColor`, 1c. Sites to re-point (from grep 2026-09-01), 1d. Verify, Chosen values, Direction in one line, HIG guardrails, Paper & Signal — Implementation Plan (+2 more)

### Community 109 - "BackgroundRefreshController.swift"
Cohesion: 0.33
Nodes (4): AppKit, IOKit.ps, Network, UserNotifications

### Community 111 - "QuickOpenViewModel"
Cohesion: 0.20
Nodes (11): QuickOpenViewModel, .query, Bool, Int, String, QuickOpenOverlay, .body, .headerSearchField (+3 more)

### Community 112 - "Sendable"
Cohesion: 0.38
Nodes (8): Sendable, PlannerItem, PlannerOverride, PlannerSubmissionSummary, Bool, Date, Int, String

### Community 114 - "CalendarEvent"
Cohesion: 0.43
Nodes (5): CalendarEvent, .courseId, Date, Int, String

### Community 120 - "CanvasFile"
Cohesion: 0.44
Nodes (7): CanvasFile, CanvasFolder, Bool, Date, Int, Int64, String

### Community 125 - "View"
Cohesion: 0.10
Nodes (28): CourseDetailBody, CourseDetailView, .body, Int, CourseWorkspaceBody, .body, CourseWorkspaceView, .body (+20 more)

## Knowledge Gaps
- **526 isolated node(s):** `.isDemo`, `.hasCredentials`, `IOKit.ps`, `Network`, `.coursesVM` (+521 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `View` connect `View` to `DashboardView`, `InboxViewModel`, `CoursesViewModel`, `CachedFile`, `SettingsView`, `FeedbackRow`, `CourseCard`, `CourseDetailViewModel`, `ScenarioChips`, `LedgerRowView`, `CourseGradeSummary`, `Text`, `SemesterTimelineStrip`, `AssignmentRow`, `UnifiedCalendarItem`, `RichTextView`, `ToDoItem`, `ModuleSectionView`, `AssignmentFilter`, `AssignmentsViewModel`, `CalculatorViewModel`, `AssignmentListRow`, `StreamItem`, `MainWindowView.swift`, `ComposeSheet`, `DiscussionsViewModel`, `GradeTrendChart`, `AnnouncementsViewModel`, `ModulesViewModel`, `SearchResultItem`, `AgeCapsule`, `GroupInfo`, `QuickOpenViewModel`?**
  _High betweenness centrality (0.143) - this node is a cross-community bridge._
- **Why does `CanvasCore` connect `CanvasCore` to `UnifiedCalendarItem`, `CachedCourse`, `RichTextView`, `CanvasData`, `ToDoItem`, `GroupInfo`, `SwiftUI`, `Foundation`, `BackgroundRefreshController.swift`, `StreamItem`, `AssignmentListRow`, `MainWindowView.swift`, `ComposeSheet`, `.plan`, `DiscussionsViewModel`, `GradeTrendChart`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `SyncEngine` connect `SyncEngine` to `Credentials`, `AppSession`, `Foundation`, `XCTestCase`, `.makeRepo`, `Sendable`, `APIClient`, `SyncEngineCourseTests`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Are the 109 inferred relationships involving `Text` (e.g. with `.body` and `.body`) actually correct?**
  _`Text` has 109 INFERRED edges - model-reasoned connections that need verification._
- **Are the 29 inferred relationships involving `APIClient` (e.g. with `APIClientDemoTests` and `.startLoading()`) actually correct?**
  _`APIClient` has 29 INFERRED edges - model-reasoned connections that need verification._
- **Are the 25 inferred relationships involving `SyncEngine` (e.g. with `.testAnnouncementResyncPreservesReadAt()` and `.testCourseSyncPopulatesAnnouncements()`) actually correct?**
  _`SyncEngine` has 25 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isDemo`, `.hasCredentials`, `IOKit.ps` to the rest of the system?**
  _526 weakly-connected nodes found - possible documentation gaps or missing edges._