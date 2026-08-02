# Graph Report - desktop-app-phase0  (2026-08-02)

## Corpus Check
- 74 files · ~67,475 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 995 nodes · 1988 edges · 44 communities (41 shown, 3 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 244 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0c0a8526`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- APIClient
- CalculatorViewModel
- GradeCalculator
- SubmissionSnapshot
- CanvasRepository
- Canvas Grades — Windowed Desktop App Design Spec
- CanvasApp — SwiftUI macOS Menu Bar App Design
- File structure (end state)
- CanvasCLISwift — Phase 2 Design
- Demo Mode Design
- C2
- AppSession
- CanvasCLISwift Phase 2 Implementation Plan
- HiddenCoursesStore
- Course Filtering Design
- Onboarding — Demo-First First-Run Design
- CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan
- APIError
- Visual Design
- Instructor Messaging — Design Spec
- Keychain Onboarding UX — Design Spec
- AppState
- File Map
- CoursesViewModel
- CourseTab
- MockData
- File Map
- Color
- 2026-06-26
- File Map
- Student UX Brief — CanvasCLISwift
- View
- Sendable
- CanvasCore
- Global Constraints
- Global Constraints
- Canvas API Pagination Implementation Plan
- Course List Billboard Card Redesign Implementation Plan
- CLAUDE.md
- Package.swift
- SyncStub
- ModelsTests
- .syncCourse
- CourseCardView

## God Nodes (most connected - your core abstractions)
1. `APIClient` - 52 edges
2. `SyncEngine` - 46 edges
3. `Credentials` - 35 edges
4. `CalculatorViewModel` - 34 edges
5. `CanvasCore` - 27 edges
6. `GradeCalculator` - 27 edges
7. `AppState` - 24 edges
8. `MockData` - 24 edges
9. `GradedItem` - 23 edges
10. `CourseDetailViewModel` - 21 edges

## Surprising Connections (you probably didn't know these)
- `.body` --calls--> `letterGrade()`  [INFERRED]
  CanvasApp/Views/CalculatorView.swift → Sources/CanvasCore/GradeCalculator.swift
- `.body` --calls--> `letterGrade()`  [INFERRED]
  CanvasApp/Views/CourseDetailView.swift → Sources/CanvasCore/GradeCalculator.swift
- `.letter` --calls--> `letterGrade()`  [INFERRED]
  CanvasApp/Views/CourseListView.swift → Sources/CanvasCore/GradeCalculator.swift
- `.liveCalculator` --calls--> `GradeCalculator`  [EXTRACTED]
  CanvasApp/ViewModels/CalculatorViewModel.swift → Sources/CanvasCore/GradeCalculator.swift
- `.body` --calls--> `letterGrade()`  [INFERRED]
  CanvasApp/Views/CalculatorView.swift → Sources/CanvasCore/GradeCalculator.swift

## Import Cycles
- None detected.

## Communities (44 total, 3 thin omitted)

### Community 0 - "APIClient"
Cohesion: 0.09
Nodes (25): APIClient, .baseURL, .token, URLSession, Credentials, String, Bool, ModelContainer (+17 more)

### Community 1 - "CalculatorViewModel"
Cohesion: 0.06
Nodes (41): Binding, CalculatorViewModel, .effectiveItems, .liveBreakdown, .liveCalculator, .liveGrade, .solveAssignmentIds, .solveResult (+33 more)

### Community 2 - "GradeCalculator"
Cohesion: 0.10
Nodes (22): .body, Equatable, Array, GradeCalculator, GroupInfo, GroupResult, letterGrade(), SolveResult (+14 more)

### Community 3 - "SubmissionSnapshot"
Cohesion: 0.17
Nodes (12): ChangeDetector, PendingChange, SubmissionSnapshot, Date, Double, Int, Set, String (+4 more)

### Community 4 - "CanvasRepository"
Cohesion: 0.06
Nodes (46): FetchDescriptor, ModelContext, CanvasRepository, .context, Bool, Date, Int, ModelContainer (+38 more)

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
Cohesion: 0.14
Nodes (13): AppSession, .hasCredentials, .isDemo, Bool, CanvasRepository, Error, Int, Result (+5 more)

### Community 12 - "CanvasCLISwift Phase 2 Implementation Plan"
Cohesion: 0.12
Nodes (16): CanvasCLISwift Phase 2 Implementation Plan, File Structure, Global Constraints, Self-Review Notes, Task 10: TUI course detail — grade dashboard, Task 11: Calculator screen + `calc` subcommand, Task 1: Package setup — dependencies, file split, test target, Task 2: Models + JSON decoding tests (+8 more)

### Community 13 - "HiddenCoursesStore"
Cohesion: 0.24
Nodes (5): HiddenCoursesStore, Bool, Int, Set, ObservableObject

### Community 14 - "Course Filtering Design"
Cohesion: 0.12
Nodes (15): Approach, AppState changes, Architecture, Change, Course Filtering Design, CourseListView changes, CoursesViewModel changes, Data Persistence (+7 more)

### Community 15 - "Onboarding — Demo-First First-Run Design"
Cohesion: 0.13
Nodes (14): AppState — demo state, Components, ConnectView (new) — replaces SettingsView as the onboarding entry, Current funnel (before), Data flow, Error handling / edge cases, Goal, KeychainWarningView (reused, relocated) (+6 more)

### Community 16 - "CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan"
Cohesion: 0.14
Nodes (13): CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan, File Map, Global Constraints, Self-Review, Task 1: Restructure SPM — Migrate CanvasCore + Retire CLI, Task 2: Grading Scale — Models Update + letterGrade Function, Task 3: Target Grade Solver, Task 4: App Shell — MenuBarExtra + Keychain + Brand Colors (+5 more)

### Community 17 - "APIError"
Cohesion: 0.06
Nodes (29): CustomStringConvertible, Error, APIError, .description, forbidden, http, missingToken, network (+21 more)

### Community 18 - "Visual Design"
Cohesion: 0.15
Nodes (12): Card anatomy, Card chrome, Course List Redesign — Billboard Grade Cards, Files Changed, Goal, Grade color mapping (existing system), Layout / List Structure, No-grade state (+4 more)

### Community 19 - "Instructor Messaging — Design Spec"
Cohesion: 0.17
Nodes (11): `APIClient` additions, Compose ViewModel, `ComposeMessageSheet`, `CourseDetailViewModel` change, Data Layer, Error Handling, Files Changed / Added, Instructor Messaging — Design Spec (+3 more)

### Community 20 - "Keychain Onboarding UX — Design Spec"
Cohesion: 0.17
Nodes (11): `AppState` changes, `CanvasApp.swift` changes, Components, Files Changed, Flow, Goals, Keychain Onboarding UX — Design Spec, `KeychainHelper` changes (+3 more)

### Community 21 - "AppState"
Cohesion: 0.13
Nodes (18): App, AppState, .hasToken, Bool, Int, String, CanvasApp, .body (+10 more)

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "CoursesViewModel"
Cohesion: 0.18
Nodes (10): AnyCancellable, CoursesViewModel, Bool, Date, Double, Int, String, TimeInterval (+2 more)

### Community 24 - "CourseTab"
Cohesion: 0.09
Nodes (27): CourseTab, announcements, assignments, discussions, files, grades, modules, syllabus (+19 more)

### Community 25 - "MockData"
Cohesion: 0.08
Nodes (33): CourseDetailViewModel, .gradingScale, Bool, Date, Double, Int, String, TimeInterval (+25 more)

### Community 26 - "File Map"
Cohesion: 0.22
Nodes (8): Course Filtering Implementation Plan, File Map, Global Constraints, Task 1: Add enrollment_type filter to APIClient, Task 2: Create HiddenCoursesStore, Task 3: Update CoursesViewModel and AppState, Task 4: Add swipe-to-hide in CourseListView, Task 5: Add Hidden Courses restore section in SettingsView

### Community 27 - "Color"
Cohesion: 0.15
Nodes (10): DisclosureRow, .body, String, WelcomeView, .body, Color, .secondaryLabel, .systemBackground (+2 more)

### Community 28 - "2026-06-26"
Cohesion: 0.25
Nodes (7): 2026-06-26, Bug Fixes, Canvas API, Changelog, Course Stream (new), Dev Experience, UI

### Community 29 - "File Map"
Cohesion: 0.25
Nodes (7): File Map, Global Constraints, Keychain Onboarding UX Implementation Plan, Task 1: Fix KeychainHelper — upsert save and friendly metadata, Task 2: Update AppState — lazy token load and acknowledgement flag, Task 3: Create KeychainWarningView, Task 4: Wire KeychainWarningView into PopoverContent and verify full flow

### Community 30 - "Student UX Brief — CanvasCLISwift"
Cohesion: 0.25
Nodes (7): Context, Larger Features (future scope), Prioritized Implementation Order, QoL Improvements, Quick Wins (implement first), Student UX Brief — CanvasCLISwift, Visual Polish

### Community 31 - "View"
Cohesion: 0.14
Nodes (21): CourseDetailView, .body, CourseStreamView, .awaitingGrade, .body, .recentFeedback, .recentlyGraded, .upcoming (+13 more)

### Community 32 - "Sendable"
Cohesion: 0.21
Nodes (15): Sendable, CalculatorInputs, CanvasRepository, Kind, awaitingGrade, feedback, recentlyGraded, upcoming (+7 more)

### Community 33 - "CanvasCore"
Cohesion: 0.10
Nodes (10): CanvasCore, CanvasData, Combine, Foundation, ISO8601DateFormatter, CanvasDate, CanvasStore, SwiftData (+2 more)

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
Cohesion: 0.06
Nodes (20): HTTPURLResponse, RecordingStub, Bool, URL, URLRequest, FixedResponseStub, Bool, String (+12 more)

### Community 44 - ".syncCourse"
Cohesion: 0.09
Nodes (23): Date, String, LegacyHiddenCourses, Int, Set, EntityKind, assignments, courses (+15 more)

### Community 51 - "CourseCardView"
Cohesion: 0.20
Nodes (9): CourseCardView, .body, .gradeColor, .letter, CourseListView, .body, Bool, Double (+1 more)

## Knowledge Gaps
- **281 isolated node(s):** `.isDemo`, `.hasCredentials`, `.hasToken`, `Security`, `dashboard` (+276 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `CanvasCore` to `Sendable`, `GradeCalculator`, `SubmissionSnapshot`, `CanvasRepository`, `SyncStub`, `AppSession`, `.syncCourse`, `HiddenCoursesStore`, `APIError`, `AppState`, `CourseTab`, `MockData`?**
  _High betweenness centrality (0.073) - this node is a cross-community bridge._
- **Why does `APIClient` connect `APIClient` to `SyncStub`, `AppSession`, `.syncCourse`, `APIError`, `CoursesViewModel`, `MockData`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Why does `CanvasCore` connect `CanvasCore` to `Sendable`, `CalculatorViewModel`, `SubmissionSnapshot`, `CanvasRepository`, `CourseCardView`, `AppState`, `View`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Are the 13 inferred relationships involving `APIClient` (e.g. with `.testConnection()` and `.wireEngine()`) actually correct?**
  _`APIClient` has 13 INFERRED edges - model-reasoned connections that need verification._
- **Are the 17 inferred relationships involving `SyncEngine` (e.g. with `.testCourseMissingFromFullFetchIsSoftDeleted()` and `.testLegacyHiddenIdsMigrate()`) actually correct?**
  _`SyncEngine` has 17 INFERRED edges - model-reasoned connections that need verification._
- **Are the 22 inferred relationships involving `Credentials` (e.g. with `.makeClient()` and `APIClientDemoTests`) actually correct?**
  _`Credentials` has 22 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `CalculatorViewModel` (e.g. with `.body` and `.body`) actually correct?**
  _`CalculatorViewModel` has 3 INFERRED edges - model-reasoned connections that need verification._