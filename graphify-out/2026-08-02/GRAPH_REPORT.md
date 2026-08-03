# Graph Report - CanvasCLISwift  (2026-08-02)

## Corpus Check
- 98 files · ~90,897 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1346 nodes · 2704 edges · 69 communities (65 shown, 4 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 317 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `2d797bf8`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- APIClient
- CalculatorViewModel
- GroupInfo
- LedgerRowView
- CachedCourse
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
- .body
- File Map
- SettingsView
- SidebarItem
- GradedItem
- File Map
- .load
- 2026-06-26
- File Map
- Student UX Brief — CanvasCLISwift
- CourseListView
- StreamItem
- CanvasCore
- Global Constraints
- Global Constraints
- Canvas API Pagination Implementation Plan
- Course List Billboard Card Redesign Implementation Plan
- CLAUDE.md
- Package.swift
- .client
- ModelsTests
- View
- .normalizeHost
- SyncEngine
- .makeRepo
- .submissionChanges
- SyncEngineCourseTests
- CourseDetailViewModel
- SandboxRailView
- SemesterTimelineStrip
- DashboardView
- Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox
- DesignTokens.swift
- Task Dependency Order
- CourseGradeSummary
- APIError
- .getPaginated
- SyncStub
- WhatIfRowView
- .init
- RecordingStub
- Canvas Grades
- AssignmentRow
- TargetChips
- CanvasGradesApp
- SolveScope
- TargetMode
- run-app.sh

## God Nodes (most connected - your core abstractions)
1. `SyncEngine` - 53 edges
2. `CalculatorViewModel` - 53 edges
3. `APIClient` - 51 edges
4. `CanvasCore` - 37 edges
5. `Credentials` - 36 edges
6. `DashboardView` - 34 edges
7. `AppSession` - 32 edges
8. `GradedItem` - 26 edges
9. `CoursesViewModel` - 25 edges
10. `MockData` - 25 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `SandboxRailView`  [INFERRED]
  CanvasApp/Views/Window/CourseWorkspaceView.swift → Sources/CanvasUI/SandboxRail.swift
- `.body` --calls--> `letterGrade()`  [INFERRED]
  CanvasApp/Views/Window/CourseWorkspaceView.swift → Sources/CanvasCore/GradeCalculator.swift
- `.body` --references--> `CalculatorViewModel`  [INFERRED]
  CanvasApp/Views/Window/CourseWorkspaceView.swift → Sources/CanvasUI/CalculatorViewModel.swift
- `.body` --calls--> `CalculatorView`  [INFERRED]
  CanvasApp/Views/CourseDetailView.swift → Sources/CanvasUI/CalculatorView.swift
- `.body` --calls--> `GradeDashboard`  [INFERRED]
  CanvasApp/Views/CourseDetailView.swift → Sources/CanvasUI/GradeDashboard.swift

## Import Cycles
- None detected.

## Communities (69 total, 4 thin omitted)

### Community 0 - "APIClient"
Cohesion: 0.20
Nodes (8): APIClient, .baseURL, .token, URLSession, Credentials, Bool, ModelContainer, SyncEngineAllTests

### Community 1 - "CalculatorViewModel"
Cohesion: 0.15
Nodes (16): SolveForMeTabView, .body, .gradeLetters, SolveResultView, .body, String, CalculatorViewModel, .liveBreakdown (+8 more)

### Community 2 - "GroupInfo"
Cohesion: 0.08
Nodes (27): .headline, Array, GradeCalculator, GroupInfo, GroupResult, letterGrade(), SolveResult, alreadyAchieved (+19 more)

### Community 3 - "LedgerRowView"
Cohesion: 0.09
Nodes (23): .ledgerSection, GradeCalculator, PointsLedger, Double, LedgerHeaderRow, .body, LedgerRowView, .barCaption (+15 more)

### Community 4 - "CachedCourse"
Cohesion: 0.05
Nodes (47): FetchDescriptor, ModelContext, CanvasRepository, .context, Bool, Date, Int, ModelContainer (+39 more)

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

### Community 11 - "AppSession"
Cohesion: 0.20
Nodes (9): AppSession, .hasCredentials, .isDemo, Bool, CanvasRepository, Error, Int, Result (+1 more)

### Community 12 - "CanvasCLISwift Phase 2 Implementation Plan"
Cohesion: 0.12
Nodes (16): CanvasCLISwift Phase 2 Implementation Plan, File Structure, Global Constraints, Self-Review Notes, Task 10: TUI course detail — grade dashboard, Task 11: Calculator screen + `calc` subcommand, Task 1: Package setup — dependencies, file split, test target, Task 2: Models + JSON decoding tests (+8 more)

### Community 13 - "CoursesViewModel"
Cohesion: 0.20
Nodes (9): CoursesViewModel, Bool, Date, Double, Int, String, .body, Bool (+1 more)

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
Cohesion: 0.12
Nodes (11): APIClientMessagingTests, URLSession, APIClientPaginationTests, PaginationStub, Bool, Data, String, URLRequest (+3 more)

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
Cohesion: 0.17
Nodes (14): CourseWorkspaceBody, .body, CourseWorkspaceView, .body, Int, ComingSoonView, .body, MainWindowBody (+6 more)

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "SettingsView"
Cohesion: 0.20
Nodes (11): SettingsView, .canSave, .canTestConnection, Bool, String, TestState, failure, idle (+3 more)

### Community 24 - "SidebarItem"
Cohesion: 0.08
Nodes (33): CourseTab, announcements, assignments, discussions, files, grades, modules, syllabus (+25 more)

### Community 25 - "GradedItem"
Cohesion: 0.08
Nodes (31): Codable, Decodable, Decoder, buildGradedItems(), MockData, Int, String, Assignment (+23 more)

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

### Community 31 - "CourseListView"
Cohesion: 0.12
Nodes (18): .body, PopoverContent, .body, .coursesVM, CourseListView, .sinceYouLastLooked, String, KeychainWarningView (+10 more)

### Community 32 - "StreamItem"
Cohesion: 0.08
Nodes (33): GradesSandboxSplit, .actualCalculator, .body, .mainColumn, Date, GradeCalculator, CalculatorInputs, CanvasRepository (+25 more)

### Community 33 - "CanvasCore"
Cohesion: 0.07
Nodes (14): AppKit, CanvasCore, CanvasData, CanvasUI, Foundation, CanvasStore, Color, .secondaryLabel (+6 more)

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

### Community 40 - ".client"
Cohesion: 0.16
Nodes (7): FixedResponseStub, ProfileTests, Bool, Data, Int, String, URLRequest

### Community 42 - "View"
Cohesion: 0.06
Nodes (46): CourseDetailBody, .body, CourseDetailView, .body, Int, GradesTabView, .body, Void (+38 more)

### Community 43 - ".normalizeHost"
Cohesion: 0.29
Nodes (3): .normalizedHost, String, CredentialsTests

### Community 44 - "SyncEngine"
Cohesion: 0.07
Nodes (34): CustomStringConvertible, Error, ISO8601DateFormatter, Sendable, CanvasDate, Date, String, LegacyHiddenCourses (+26 more)

### Community 45 - ".makeRepo"
Cohesion: 0.33
Nodes (4): DerivedReadsTests, CanvasRepository, Date, String

### Community 46 - ".submissionChanges"
Cohesion: 0.16
Nodes (13): ChangeDetector, PendingChange, SubmissionSnapshot, Bool, Date, Double, Int, Set (+5 more)

### Community 47 - "SyncEngineCourseTests"
Cohesion: 0.21
Nodes (8): RouteStub, Bool, Data, Int, String, URLRequest, SyncEngineCourseTests, URLProtocol

### Community 48 - "CourseDetailViewModel"
Cohesion: 0.24
Nodes (8): CourseDetailViewModel, .calculator, Bool, Date, GradeCalculator, Int, String, ObservableObject

### Community 49 - "SandboxRailView"
Cohesion: 0.12
Nodes (19): HypotheticalSlider, .body, SandboxRailView, .answerSentence, .body, .footer, .header, .hypotheticalsSection (+11 more)

### Community 50 - "SemesterTimelineStrip"
Cohesion: 0.17
Nodes (16): makeSyntheticTicks(), SemesterTimelineStrip, .body, SemesterTimelineStripPreviewContainer, .body, Style, finalExam, graded (+8 more)

### Community 51 - "DashboardView"
Cohesion: 0.08
Nodes (34): CourseSettingsStore, Double, Int, String, CourseLedgerRow, DashboardViewModel, Bool, Color (+26 more)

### Community 52 - "Handoff: Canvas Grades — Dashboard (Phase 1) + What-If Sandbox"
Cohesion: 0.10
Nodes (20): 1.1 Header, 1.2 Semester timeline strip, 1.3 Ledger table, 1.4 Bottom panels — 2-column grid, `1fr 1.15fr`, gap 26, 1.5 Sidebar (both themes), 1. Dashboard (`SidebarItem.dashboard` detail pane) — options `3a` / `3b`, 2. Course workspace + Sandbox — option `1d`, About the Design Files (+12 more)

### Community 53 - "DesignTokens.swift"
Cohesion: 0.16
Nodes (15): Color, DesignTokenSwatches, .body, dynamic(), Font, .sectionLabel, InPlayHatch, .body (+7 more)

### Community 54 - "Task Dependency Order"
Cohesion: 0.11
Nodes (18): File Structure, Global Constraints, Phase 1a — Dashboard + What-If Sandbox Implementation Plan, Self-Review, Task 10: Dashboard bottom panels (`CanvasUI`), Task 11: DashboardView composition + wire into MainWindowView (`CanvasApp`), Task 12: Course-scope Sandbox rail + grades-tab dock (`CanvasUI` + `CanvasApp`), Task 13: Term-scope Sandbox rail on the Dashboard (`CanvasApp`) (+10 more)

### Community 55 - "CourseGradeSummary"
Cohesion: 0.32
Nodes (12): ceilingTermGPA(), CourseGradeSummary, currentTermGPA(), floorTermGPA(), gpaLift(), gpaPoints(), projectedTermGPA(), Double (+4 more)

### Community 56 - "APIError"
Cohesion: 0.16
Nodes (12): APIError, .description, forbidden, http, missingToken, network, rateLimited, unauthorized (+4 more)

### Community 57 - ".getPaginated"
Cohesion: 0.26
Nodes (4): Int, JSONDecoder, APIClientDemoTests, URLQueryItem

### Community 58 - "SyncStub"
Cohesion: 0.17
Nodes (7): SyncEnginePolicyTests, Bool, Data, Int, String, URLRequest, SyncStub

### Community 59 - "WhatIfRowView"
Cohesion: 0.16
Nodes (11): CalculatorView, .body, Binding, Bool, Double, Int, WhatIfRowView, .binding (+3 more)

### Community 60 - ".init"
Cohesion: 0.24
Nodes (9): .effectiveItems, InputMode, percent, points, Bool, Double, Int, String (+1 more)

### Community 61 - "RecordingStub"
Cohesion: 0.18
Nodes (5): HTTPURLResponse, RecordingStub, Bool, URL, URLRequest

### Community 62 - "Canvas Grades"
Cohesion: 0.17
Nodes (11): Build from source, Canvas Grades, Download, Features, Getting a Canvas API token, Homebrew (coming soon), Install, License (+3 more)

### Community 63 - "AssignmentRow"
Cohesion: 0.24
Nodes (10): AssignmentRow, .body, .isHypothetical, .assignmentsSection, .groupsSection, GroupLiftRow, .body, Bool (+2 more)

### Community 64 - "TargetChips"
Cohesion: 0.40
Nodes (4): .targetSection, Bool, TargetChips, .body

### Community 65 - "CanvasGradesApp"
Cohesion: 0.67
Nodes (3): App, CanvasGradesApp, Scene

### Community 66 - "SolveScope"
Cohesion: 0.67
Nodes (3): SolveScope, single, spread

### Community 67 - "TargetMode"
Cohesion: 0.67
Nodes (3): TargetMode, letter, percent

## Knowledge Gaps
- **372 isolated node(s):** `.isDemo`, `.hasCredentials`, `.coursesVM`, `Security`, `dashboard` (+367 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CanvasCore` connect `CanvasCore` to `StreamItem`, `GroupInfo`, `CachedCourse`, `SyncEngine`, `.submissionChanges`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Why does `Foundation` connect `CanvasCore` to `StreamItem`, `GroupInfo`, `LedgerRowView`, `CachedCourse`, `SyncStub`, `SyncEngine`, `.submissionChanges`, `CourseGradeSummary`, `SidebarItem`, `GradedItem`, `APIError`, `.load`?**
  _High betweenness centrality (0.060) - this node is a cross-community bridge._
- **Why does `CalculatorViewModel` connect `CalculatorViewModel` to `StreamItem`, `CanvasCore`, `GroupInfo`, `SolveScope`, `TargetMode`, `TargetChips`, `CourseDetailViewModel`, `SandboxRailView`, `GradedItem`, `WhatIfRowView`, `.init`, `AssignmentRow`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Are the 18 inferred relationships involving `SyncEngine` (e.g. with `.testConcurrentSyncAndReads()` and `.testCourseMissingFromFullFetchIsSoftDeleted()`) actually correct?**
  _`SyncEngine` has 18 INFERRED edges - model-reasoned connections that need verification._
- **Are the 9 inferred relationships involving `CalculatorViewModel` (e.g. with `.body` and `.assignmentsSection`) actually correct?**
  _`CalculatorViewModel` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 15 inferred relationships involving `APIClient` (e.g. with `.testConnection()` and `.wireEngine()`) actually correct?**
  _`APIClient` has 15 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.isDemo`, `.hasCredentials`, `.coursesVM` to the rest of the system?**
  _372 weakly-connected nodes found - possible documentation gaps or missing edges._