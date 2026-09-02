# Graph Report - CanvasCLISwift  (2026-08-08)

## Corpus Check
- 144 files · ~131,524 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2062 nodes · 4545 edges · 112 communities (100 shown, 12 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 638 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `aa04d6dc`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Credentials
- CalculatorViewModel
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
- AppSession
- Course Filtering Design
- Onboarding — Demo-First First-Run Design
- CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan
- XCTestCase
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
- .normalizeHost
- SyncEngine
- .makeRepo
- .submissionChanges
- SyncEngineCourseTests
- CourseDetailViewModel
- ScenarioChips
- SemesterTimelineStrip
- FeedbackRow
- Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox
- ChangeKind
- Task Dependency Order
- CourseGradeSummary
- APIError
- Task Dependency Order
- APIClient
- Text
- AssignmentPredicatesTests
- CanvasGradesApp
- Canvas Grades
- GradesSandboxSplit
- TargetChips
- Coordinator
- AnnouncementListRow
- TargetMode
- run-app.sh
- SkeletonList
- RouteStub
- AssignmentsViewModel
- DashboardView
- htmlNeedsWebView
- SwiftUI
- Foundation
- WhatIfRowView
- AssignmentListRow
- RecordingStub
- .client
- FixedResponseStub
- Color
- .ids
- GROUP A — INBOX
- InboxView
- View
- DiscussionsViewModel
- GradeTrendChart
- MockData
- StalenessLabel
- CachedConversation
- Sendable
- Router
- Conversation
- .init
- Task
- CodingKeys
- PowerState
- SandboxRailView
- FormRecordingStub
- DiscussionTopicRow
- BackgroundRefreshController.swift
- AnnouncementsViewModel
- AgeCapsule
- .userNotificationCenter
- ConversationScope
- ConversationAPITests
- ConversationModelsTests
- PointsLedgerTests
- .makeEngine
- DiscussionModelsTests
- .init

## God Nodes (most connected - your core abstractions)
1. `APIClient` - 73 edges
2. `CanvasCore` - 70 edges
3. `SyncEngine` - 70 edges
4. `AppSession` - 61 edges
5. `CalculatorViewModel` - 53 edges
6. `Credentials` - 46 edges
7. `MockData` - 39 edges
8. `CanvasData` - 38 edges
9. `DashboardView` - 36 edges
10. `CanvasRepository` - 34 edges

## Surprising Connections (you probably didn't know these)
- `.selected` --references--> `CachedAnnouncement`  [INFERRED]
  CanvasApp/ViewModels/AnnouncementsViewModel.swift → Sources/CanvasData/Models/AnnouncementModels.swift
- `.body` --calls--> `SandboxRailView`  [INFERRED]
  CanvasApp/Views/Window/CourseWorkspaceView.swift → Sources/CanvasUI/SandboxRail.swift
- `AppSession` --calls--> `NotificationScheduler`  [INFERRED]
  CanvasApp/App/AppSession.swift → Sources/CanvasData/NotificationScheduler.swift
- `.filteredRows` --calls--> `assignmentMatchesFilter()`  [INFERRED]
  CanvasApp/ViewModels/AssignmentsViewModel.swift → Sources/CanvasCore/AssignmentPredicates.swift
- `.selectedTopic` --references--> `CachedDiscussionTopic`  [INFERRED]
  CanvasApp/ViewModels/DiscussionsViewModel.swift → Sources/CanvasData/Models/DiscussionModels.swift

## Import Cycles
- None detected.

## Communities (112 total, 12 thin omitted)

### Community 0 - "Credentials"
Cohesion: 0.14
Nodes (8): Credentials, Bool, ModelContainer, AnnouncementSyncTests, DiscussionSyncTests, ModelContainer, SyncEngineAllTests, SyncEnginePolicyTests

### Community 1 - "CalculatorViewModel"
Cohesion: 0.15
Nodes (15): SolveResultView, .body, CalculatorViewModel, .liveBreakdown, .liveCalculator, .liveGrade, .solveAssignmentIds, .solveResult (+7 more)

### Community 2 - "GroupInfo"
Cohesion: 0.07
Nodes (31): .headline, Array, GradeCalculator, GroupInfo, GroupResult, letterGrade(), SolveResult, alreadyAchieved (+23 more)

### Community 3 - "LedgerRowView"
Cohesion: 0.06
Nodes (38): .ledgerSection, GradeCalculator, PointsLedger, Double, Color, DesignTokenSwatches, .body, dynamic() (+30 more)

### Community 4 - "CanvasRepository"
Cohesion: 0.05
Nodes (45): FetchDescriptor, ModelContext, CanvasRepository, .context, Bool, Date, Int, ModelContainer (+37 more)

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
Cohesion: 0.27
Nodes (7): Bool, InboxViewModel, Bool, Date, Int, String, .body

### Community 12 - "CanvasCLISwift Phase 2 Implementation Plan"
Cohesion: 0.12
Nodes (16): CanvasCLISwift Phase 2 Implementation Plan, File Structure, Global Constraints, Self-Review Notes, Task 10: TUI course detail — grade dashboard, Task 11: Calculator screen + `calc` subcommand, Task 1: Package setup — dependencies, file split, test target, Task 2: Models + JSON decoding tests (+8 more)

### Community 13 - "AppSession"
Cohesion: 0.11
Nodes (20): AppSession, .hasCredentials, .isDemo, CanvasRepository, Error, Int, Result, String (+12 more)

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
Cohesion: 0.09
Nodes (12): HTTPURLResponse, APIClientMessagingTests, URLSession, APIClientPaginationTests, PaginationStub, Bool, Data, String (+4 more)

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
Cohesion: 0.27
Nodes (8): MainWindowBody, .body, .inboxUnread, Bool, Color, Double, Int, String

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "CourseSettingsStore"
Cohesion: 0.24
Nodes (9): CourseSettingsStore, Double, Int, String, CourseSettingsRow, .body, CustomizationSection, .body (+1 more)

### Community 24 - "SidebarItem"
Cohesion: 0.11
Nodes (19): CourseTab, announcements, assignments, discussions, files, grades, modules, syllabus (+11 more)

### Community 25 - "Codable"
Cohesion: 0.24
Nodes (22): Codable, Decodable, buildGradedItems(), Announcement, Assignment, AssignmentGroup, AssignmentGroupRules, Course (+14 more)

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
Cohesion: 0.10
Nodes (23): PopoverContent, .body, .coursesVM, KeychainWarningView, .body, NotificationSettingsSection, .body, .hourOptions (+15 more)

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

### Community 43 - ".normalizeHost"
Cohesion: 0.33
Nodes (3): .normalizedHost, String, CredentialsTests

### Community 44 - "SyncEngine"
Cohesion: 0.10
Nodes (30): Hashable, EntityKind, announcements, assignments, conversations, courses, discussionEntries, discussionTopics (+22 more)

### Community 45 - ".makeRepo"
Cohesion: 0.33
Nodes (4): DerivedReadsTests, CanvasRepository, Date, String

### Community 46 - ".submissionChanges"
Cohesion: 0.09
Nodes (20): ISO8601DateFormatter, CanvasDate, Date, String, ChangeDetector, PendingChange, SubmissionSnapshot, Bool (+12 more)

### Community 47 - "SyncEngineCourseTests"
Cohesion: 0.53
Nodes (3): Int, String, SyncEngineCourseTests

### Community 48 - "CourseDetailViewModel"
Cohesion: 0.32
Nodes (7): CourseDetailViewModel, .calculator, Date, GradeCalculator, Int, String, ObservableObject

### Community 49 - "ScenarioChips"
Cohesion: 0.23
Nodes (9): HypotheticalSlider, .body, .scenariosSection, ScenarioChips, .actualPercent, .body, Double, String (+1 more)

### Community 50 - "SemesterTimelineStrip"
Cohesion: 0.15
Nodes (18): .dashboardContent, Identifiable, makeSyntheticTicks(), SemesterTimelineStrip, .body, SemesterTimelineStripPreviewContainer, .body, Style (+10 more)

### Community 51 - "FeedbackRow"
Cohesion: 0.23
Nodes (16): .bottomPanels, AwaitingGradePanel, AwaitingRow, DashboardPanelsPreview, .awaitingRows, .body, .feedbackRows, FeedbackRow (+8 more)

### Community 52 - "Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox"
Cohesion: 0.10
Nodes (20): 1.1 Header, 1.2 Semester timeline strip, 1.3 Ledger table, 1.4 Bottom panels — 2-column grid, `1fr 1.15fr`, gap 26, 1.5 Sidebar (both themes), 1. Dashboard (`SidebarItem.dashboard` detail pane) — options `3a` / `3b`, 2. Course workspace + Sandbox — option `1d`, About the Design Files (+12 more)

### Community 53 - "ChangeKind"
Cohesion: 0.06
Nodes (36): Date, NotificationSettingsStore, .anyCategoryEnabled, .settings, Stored, Bool, Int, ChangeKind (+28 more)

### Community 54 - "Task Dependency Order"
Cohesion: 0.11
Nodes (18): File Structure, Global Constraints, Phase 1a — Dashboard + What-If Sandbox Implementation Plan, Self-Review, Task 10: Dashboard bottom panels (`CanvasUI`), Task 11: DashboardView composition + wire into MainWindowView (`CanvasApp`), Task 12: Course-scope Sandbox rail + grades-tab dock (`CanvasUI` + `CanvasApp`), Task 13: Term-scope Sandbox rail on the Dashboard (`CanvasApp`) (+10 more)

### Community 55 - "CourseGradeSummary"
Cohesion: 0.11
Nodes (32): CourseLedgerRow, DashboardViewModel, Bool, Color, Date, Double, Int, String (+24 more)

### Community 56 - "APIError"
Cohesion: 0.17
Nodes (12): CustomStringConvertible, Error, APIError, .description, forbidden, missingToken, rateLimited, unauthorized (+4 more)

### Community 57 - "Task Dependency Order"
Cohesion: 0.09
Nodes (22): Architecture, Context, Critical Files for Implementation, File Structure, Global Constraints, Phase 1b — Assignments, Announcements, Syllabus, Grade Trend Chart Implementation Plan, Task 10: Grade trend chart (`CanvasUI`), Task 11: `AssignmentsViewModel` + `AssignmentsTabView` (`CanvasApp`) (+14 more)

### Community 58 - "APIClient"
Cohesion: 0.12
Nodes (14): APIClient, .baseURL, .token, http, network, Data, Int, JSONDecoder (+6 more)

### Community 59 - "Text"
Cohesion: 0.15
Nodes (19): DisclosureRow, .body, Color, String, .body, Bool, Double, String (+11 more)

### Community 60 - "AssignmentPredicatesTests"
Cohesion: 0.09
Nodes (16): .filteredRows, AssignmentFilter, all, graded, missing, upcoming, assignmentMatchesFilter(), isAssignmentMissing() (+8 more)

### Community 61 - "CanvasGradesApp"
Cohesion: 0.33
Nodes (7): App, CanvasGradesApp, .body, .preferredColorScheme, ColorScheme, String, Scene

### Community 62 - "Canvas Grades"
Cohesion: 0.17
Nodes (11): Build from source, Canvas Grades, Download, Features, Getting a Canvas API token, Homebrew (coming soon), Install, License (+3 more)

### Community 63 - "GradesSandboxSplit"
Cohesion: 0.11
Nodes (25): AssignmentRow, .body, .isHypothetical, CourseWorkspaceBody, .body, CourseWorkspaceView, .body, GradesSandboxSplit (+17 more)

### Community 64 - "TargetChips"
Cohesion: 0.40
Nodes (4): .targetSection, Bool, TargetChips, .body

### Community 65 - "Coordinator"
Cohesion: 0.14
Nodes (17): Context, NSObject, NSViewRepresentable, Coordinator, RichTextWebViewRepresentable, Binding, CGFloat, ColorScheme (+9 more)

### Community 66 - "AnnouncementListRow"
Cohesion: 0.20
Nodes (13): AnnouncementComponentFormat, AnnouncementComponentsPreview, .body, .posted, AnnouncementListRow, .body, .content, .subtitle (+5 more)

### Community 67 - "TargetMode"
Cohesion: 0.67
Nodes (3): TargetMode, letter, percent

### Community 69 - "SkeletonList"
Cohesion: 0.25
Nodes (5): Bool, .body, SkeletonList, .body, Int

### Community 70 - "RouteStub"
Cohesion: 0.29
Nodes (5): RouteStub, Bool, Data, URLRequest, URLProtocol

### Community 71 - "AssignmentsViewModel"
Cohesion: 0.13
Nodes (17): AssignmentsViewModel, .instructorComments, .selectedRow, Row, .id, Bool, Date, Int (+9 more)

### Community 72 - "DashboardView"
Cohesion: 0.13
Nodes (18): DashboardView, .awaitingRows, .body, .dotColors, .emptyState, .errorState, .feedbackRows, .header (+10 more)

### Community 73 - "htmlNeedsWebView"
Cohesion: 0.14
Nodes (4): htmlNeedsWebView(), Bool, String, RichTextHeuristicTests

### Community 75 - "Foundation"
Cohesion: 0.11
Nodes (4): CanvasData, Foundation, CanvasStore, SwiftData

### Community 76 - "WhatIfRowView"
Cohesion: 0.14
Nodes (15): CalculatorView, .body, SolveForMeTabView, .body, .gradeLetters, Binding, Bool, Double (+7 more)

### Community 77 - "AssignmentListRow"
Cohesion: 0.09
Nodes (35): .commentsSection, formatRubricAssessment(), RubricAssessmentEntry, RubricCriterion, RubricLine, RubricRating, Double, String (+27 more)

### Community 78 - "RecordingStub"
Cohesion: 0.29
Nodes (4): RecordingStub, Bool, URL, URLRequest

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
Nodes (3): LegacyHiddenCourses, Int, Set

### Community 83 - "GROUP A — INBOX"
Cohesion: 0.06
Nodes (32): Architecture, Context, Execution Handoff, File Structure, Global Constraints, Global test harness reference, GROUP A — INBOX, GROUP B — DISCUSSIONS (read-only) (+24 more)

### Community 84 - "InboxView"
Cohesion: 0.15
Nodes (21): InboxView, .listColumn, .recipients, .threadColumn, Int, String, ComposeSheet, .body (+13 more)

### Community 85 - "View"
Cohesion: 0.14
Nodes (19): Int, String, SyllabusTabView, .body, AttributedHTMLText, .attributed, .body, AttributedString (+11 more)

### Community 86 - "DiscussionsViewModel"
Cohesion: 0.18
Nodes (12): DiscussionsViewModel, .selectedTopic, Bool, Date, Int, String, .body, CachedDiscussionEntry (+4 more)

### Community 87 - "GradeTrendChart"
Cohesion: 0.15
Nodes (17): .trendSection, Charts, ClosedRange, GradeTrendChart, .body, .chart, .emptyState, .visibleThresholds (+9 more)

### Community 88 - "MockData"
Cohesion: 0.17
Nodes (3): MockData, Double, MockDataTests

### Community 89 - "StalenessLabel"
Cohesion: 0.15
Nodes (12): AnnouncementsTabView, .detailColumn, .listColumn, Int, String, DiscussionsTabView, .detailColumn, .listColumn (+4 more)

### Community 90 - "CachedConversation"
Cohesion: 0.26
Nodes (10): .selected, CachedConversation, .participants, CachedMessage, Bool, Data, Date, Int (+2 more)

### Community 91 - "Sendable"
Cohesion: 0.38
Nodes (10): Equatable, Sendable, DiscussionEntryNode, DiscussionParticipant, DiscussionTopic, DiscussionView, FlatDiscussionEntry, flattenDiscussion() (+2 more)

### Community 92 - "Router"
Cohesion: 0.15
Nodes (12): RevealTarget, assignment, conversation, course, section, Router, .courseTab, .dashboardDensity (+4 more)

### Community 93 - "Conversation"
Cohesion: 0.36
Nodes (7): Conversation, ConversationMessage, ConversationParticipant, Int, String, Int, String

### Community 94 - ".init"
Cohesion: 0.22
Nodes (9): .effectiveItems, InputMode, percent, points, Bool, Double, Int, String (+1 more)

### Community 95 - "Task"
Cohesion: 0.28
Nodes (5): BackgroundRefreshController, Date, Task, Timer, UNUserNotificationCenterDelegate

### Community 96 - "CodingKeys"
Cohesion: 0.15
Nodes (13): CodingKey, CodingKeys, assignmentGroupId, descriptionHTML, dueAt, htmlURL, id, lockAt (+5 more)

### Community 97 - "PowerState"
Cohesion: 0.32
Nodes (6): PowerState, shouldRunBackgroundTick(), Bool, Date, Int, BackgroundGateTests

### Community 98 - "SandboxRailView"
Cohesion: 0.17
Nodes (11): SandboxRailView, .answerSentence, .body, .footer, .header, .hypotheticalsSection, .requiredItemId, .requiredPercent (+3 more)

### Community 99 - "FormRecordingStub"
Cohesion: 0.20
Nodes (7): InputStream, FormRecordingStub, Bool, Data, String, URL, URLRequest

### Community 100 - "DiscussionTopicRow"
Cohesion: 0.33
Nodes (9): DiscussionEntryView, .body, DiscussionTopicRow, .body, Bool, Date, Int, String (+1 more)

### Community 101 - "BackgroundRefreshController.swift"
Cohesion: 0.24
Nodes (8): AppKit, CourseDetailBody, CourseDetailView, .body, Int, IOKit.ps, Network, UserNotifications

### Community 102 - "AnnouncementsViewModel"
Cohesion: 0.25
Nodes (7): AnnouncementsViewModel, .selected, Bool, Date, Int, String, .body

### Community 103 - "AgeCapsule"
Cohesion: 0.25
Nodes (7): AgeCapsule, .body, .isAged, .body, AwaitingGradeRowView, .body, Bool

### Community 104 - ".userNotificationCenter"
Cohesion: 0.33
Nodes (4): UNNotification, UNNotificationPresentationOptions, UNNotificationResponse, UNUserNotificationCenter

### Community 105 - "ConversationScope"
Cohesion: 0.33
Nodes (5): CaseIterable, ConversationScope, archived, inbox, unread

## Knowledge Gaps
- **447 isolated node(s):** `.isDemo`, `.hasCredentials`, `IOKit.ps`, `Network`, `.coursesVM` (+442 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CanvasCore` connect `CanvasCore` to `StreamItem`, `GroupInfo`, `LedgerRowView`, `CanvasRepository`, `BackgroundRefreshController.swift`, `DiscussionTopicRow`, `SwiftUI`, `Foundation`, `WhatIfRowView`, `AssignmentListRow`, `ScenarioChips`, `InboxView`, `ChangeKind`, `GradeTrendChart`, `CourseSettingsStore`, `View`, `GradesSandboxSplit`?**
  _High betweenness centrality (0.099) - this node is a cross-community bridge._
- **Why does `AppSession` connect `AppSession` to `Credentials`, `SkeletonList`, `AnnouncementsViewModel`, `AssignmentsViewModel`, `InboxViewModel`, `Foundation`, `SyncEngine`, `SettingsView`, `CourseDetailViewModel`, `CourseSettingsStore`, `ChangeKind`, `DiscussionsViewModel`, `CourseGradeSummary`, `Router`, `CanvasGradesApp`, `Task`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Why does `SyncEngine` connect `SyncEngine` to `Credentials`, `Foundation`, `AppSession`, `.submissionChanges`, `.makeEngine`, `.makeRepo`, `SyncEngineCourseTests`, `APIError`, `APIClient`, `Sendable`, `Task`?**
  _High betweenness centrality (0.068) - this node is a cross-community bridge._
- **Are the 89 inferred relationships involving `Text` (e.g. with `.body` and `.body`) actually correct?**
  _`Text` has 89 INFERRED edges - model-reasoned connections that need verification._
- **Are the 23 inferred relationships involving `APIClient` (e.g. with `.testConnection()` and `.wireEngine()`) actually correct?**
  _`APIClient` has 23 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `SyncEngine` (e.g. with `.testAnnouncementResyncPreservesReadAt()` and `.testCourseSyncPopulatesAnnouncements()`) actually correct?**
  _`SyncEngine` has 22 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isDemo`, `.hasCredentials`, `IOKit.ps` to the rest of the system?**
  _447 weakly-connected nodes found - possible documentation gaps or missing edges._