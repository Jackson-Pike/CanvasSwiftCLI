# Graph Report - desktop-app-phase0  (2026-08-01)

## Corpus Check
- 62 files · ~60,647 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 791 nodes · 1388 edges · 52 communities (47 shown, 5 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 128 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `1af48b71`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- .getPaginated
- CalculatorViewModel
- GradeCalculator
- CanvasCore
- CanvasRepository
- Canvas Grades — Windowed Desktop App Design Spec
- CanvasApp — SwiftUI macOS Menu Bar App Design
- File structure (end state)
- CanvasCLISwift — Phase 2 Design
- Demo Mode Design
- C2
- CourseDetailViewModel
- CanvasCLISwift Phase 2 Implementation Plan
- CoursesViewModel
- Course Filtering Design
- Onboarding — Demo-First First-Run Design
- CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan
- CourseCardView
- Visual Design
- Instructor Messaging — Design Spec
- Keychain Onboarding UX — Design Spec
- CanvasApp
- File Map
- HiddenCoursesStore
- AppState
- GradedItem
- File Map
- .load
- 2026-06-26
- File Map
- Student UX Brief — CanvasCLISwift
- View
- SwiftUI
- ChangeKind
- Global Constraints
- Global Constraints
- Canvas API Pagination Implementation Plan
- Course List Billboard Card Redesign Implementation Plan
- CLAUDE.md
- Package.swift
- RecordingStub
- APIError
- APIClient
- .client
- Credentials
- PaginationStub
- .makeClient
- Foundation
- .parse
- ModelsTests
- RepositoryTests.swift
- DisclosureRow

## God Nodes (most connected - your core abstractions)
1. `CalculatorViewModel` - 34 edges
2. `APIClient` - 30 edges
3. `GradeCalculator` - 27 edges
4. `CanvasRepository` - 26 edges
5. `AppState` - 24 edges
6. `GradedItem` - 21 edges
7. `CoursesViewModel` - 20 edges
8. `MockData` - 20 edges
9. `CourseDetailViewModel` - 19 edges
10. `GroupInfo` - 19 edges

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

## Communities (52 total, 5 thin omitted)

### Community 0 - ".getPaginated"
Cohesion: 0.15
Nodes (6): Data, Int, JSONDecoder, String, APIClientDemoTests, URLQueryItem

### Community 1 - "CalculatorViewModel"
Cohesion: 0.06
Nodes (41): Binding, CalculatorViewModel, .effectiveItems, .liveBreakdown, .liveCalculator, .liveGrade, .solveAssignmentIds, .solveResult (+33 more)

### Community 2 - "GradeCalculator"
Cohesion: 0.10
Nodes (22): .body, Equatable, Array, GradeCalculator, GroupInfo, GroupResult, letterGrade(), SolveResult (+14 more)

### Community 3 - "CanvasCore"
Cohesion: 0.25
Nodes (4): CanvasCore, APIClientMessagingTests, URLSession, XCTest

### Community 4 - "CanvasRepository"
Cohesion: 0.07
Nodes (39): ModelContext, CanvasRepository, .context, Bool, Date, Int, ModelContainer, String (+31 more)

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

### Community 11 - "CourseDetailViewModel"
Cohesion: 0.18
Nodes (15): CourseDetailViewModel, .gradingScale, Kind, awaitingGrade, feedback, recentlyGraded, upcoming, StreamAssignment (+7 more)

### Community 12 - "CanvasCLISwift Phase 2 Implementation Plan"
Cohesion: 0.12
Nodes (16): CanvasCLISwift Phase 2 Implementation Plan, File Structure, Global Constraints, Self-Review Notes, Task 10: TUI course detail — grade dashboard, Task 11: Calculator screen + `calc` subcommand, Task 1: Package setup — dependencies, file split, test target, Task 2: Models + JSON decoding tests (+8 more)

### Community 13 - "CoursesViewModel"
Cohesion: 0.16
Nodes (12): AnyCancellable, CoursesViewModel, Bool, Date, Double, Int, String, TimeInterval (+4 more)

### Community 14 - "Course Filtering Design"
Cohesion: 0.12
Nodes (15): Approach, AppState changes, Architecture, Change, Course Filtering Design, CourseListView changes, CoursesViewModel changes, Data Persistence (+7 more)

### Community 15 - "Onboarding — Demo-First First-Run Design"
Cohesion: 0.13
Nodes (14): AppState — demo state, Components, ConnectView (new) — replaces SettingsView as the onboarding entry, Current funnel (before), Data flow, Error handling / edge cases, Goal, KeychainWarningView (reused, relocated) (+6 more)

### Community 16 - "CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan"
Cohesion: 0.14
Nodes (13): CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan, File Map, Global Constraints, Self-Review, Task 1: Restructure SPM — Migrate CanvasCore + Retire CLI, Task 2: Grading Scale — Models Update + letterGrade Function, Task 3: Target Grade Solver, Task 4: App Shell — MenuBarExtra + Keychain + Brand Colors (+5 more)

### Community 17 - "CourseCardView"
Cohesion: 0.15
Nodes (11): CourseCardView, .body, .gradeColor, .letter, Double, String, Color, .secondaryLabel (+3 more)

### Community 18 - "Visual Design"
Cohesion: 0.15
Nodes (12): Card anatomy, Card chrome, Course List Redesign — Billboard Grade Cards, Files Changed, Goal, Grade color mapping (existing system), Layout / List Structure, No-grade state (+4 more)

### Community 19 - "Instructor Messaging — Design Spec"
Cohesion: 0.17
Nodes (11): `APIClient` additions, Compose ViewModel, `ComposeMessageSheet`, `CourseDetailViewModel` change, Data Layer, Error Handling, Files Changed / Added, Instructor Messaging — Design Spec (+3 more)

### Community 20 - "Keychain Onboarding UX — Design Spec"
Cohesion: 0.17
Nodes (11): `AppState` changes, `CanvasApp.swift` changes, Components, Files Changed, Flow, Goals, Keychain Onboarding UX — Design Spec, `KeychainHelper` changes (+3 more)

### Community 21 - "CanvasApp"
Cohesion: 0.40
Nodes (5): App, CanvasApp, .body, PopoverContent, Scene

### Community 22 - "File Map"
Cohesion: 0.20
Nodes (9): File Map, Global Constraints, Instructor Messaging Implementation Plan, Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`, Task 2: Add `sendConversation()` to `APIClient`, Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch, Task 4: Create `ComposeMessageViewModel`, Task 5: Create `ComposeMessageSheet` (+1 more)

### Community 23 - "HiddenCoursesStore"
Cohesion: 0.36
Nodes (4): HiddenCoursesStore, Bool, Int, Set

### Community 24 - "AppState"
Cohesion: 0.21
Nodes (8): AppState, .hasToken, Bool, Int, String, .body, .body, .body

### Community 25 - "GradedItem"
Cohesion: 0.11
Nodes (25): Codable, Decodable, Decoder, buildGradedItems(), MockData, Int, String, Assignment (+17 more)

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

### Community 31 - "View"
Cohesion: 0.15
Nodes (20): CourseDetailView, .body, CourseStreamView, .awaitingGrade, .body, .recentFeedback, .recentlyGraded, .upcoming (+12 more)

### Community 32 - "SwiftUI"
Cohesion: 0.23
Nodes (8): .body, CourseListView, KeychainWarningView, SettingsView, Bool, WelcomeView, CanvasUI, SwiftUI

### Community 33 - "ChangeKind"
Cohesion: 0.20
Nodes (10): CaseIterable, ChangeKind, dueSoon, gradeChanged, newAnnouncement, newFeedback, newGrade, newMessage (+2 more)

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

### Community 40 - "RecordingStub"
Cohesion: 0.29
Nodes (5): RecordingStub, Bool, URL, URLRequest, URLProtocol

### Community 41 - "APIError"
Cohesion: 0.16
Nodes (12): CustomStringConvertible, Error, APIError, .description, forbidden, http, missingToken, network (+4 more)

### Community 42 - "APIClient"
Cohesion: 0.28
Nodes (5): HTTPURLResponse, APIClient, .baseURL, .token, URLSession

### Community 43 - ".client"
Cohesion: 0.15
Nodes (7): FixedResponseStub, ProfileTests, Bool, Data, Int, String, URLRequest

### Community 44 - "Credentials"
Cohesion: 0.31
Nodes (4): Sendable, Credentials, String, CredentialsTests

### Community 45 - "PaginationStub"
Cohesion: 0.18
Nodes (7): APIClientPaginationTests, PaginationStub, Bool, Data, String, URLRequest, URLSession

### Community 47 - "Foundation"
Cohesion: 0.20
Nodes (4): Combine, Foundation, CanvasStore, SwiftData

### Community 48 - ".parse"
Cohesion: 0.29
Nodes (4): ISO8601DateFormatter, CanvasDate, Date, String

### Community 51 - "DisclosureRow"
Cohesion: 0.40
Nodes (4): DisclosureRow, .body, String, .body

## Knowledge Gaps
- **252 isolated node(s):** `.hasToken`, `Security`, `letter`, `percent`, `single` (+247 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `Foundation` to `SwiftUI`, `GradeCalculator`, `CanvasCore`, `CanvasRepository`, `APIError`, `CourseDetailViewModel`, `.parse`, `GradedItem`, `.load`?**
  _High betweenness centrality (0.078) - this node is a cross-community bridge._
- **Why does `CalculatorViewModel` connect `CalculatorViewModel` to `GradedItem`, `GradeCalculator`, `CanvasCore`, `CoursesViewModel`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `CanvasCore` connect `CanvasCore` to `SwiftUI`, `CalculatorViewModel`, `.getPaginated`, `CanvasRepository`, `CourseDetailViewModel`, `Credentials`, `PaginationStub`, `.client`, `Foundation`, `CanvasApp`, `View`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `CalculatorViewModel` (e.g. with `.body` and `.body`) actually correct?**
  _`CalculatorViewModel` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `APIClient` (e.g. with `APIClientDemoTests` and `.startLoading()`) actually correct?**
  _`APIClient` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `GradeCalculator` (e.g. with `.testCurrentGradeNilWhenNothingGraded()` and `.testGroupBreakdownReportsNilForUngradedGroup()`) actually correct?**
  _`GradeCalculator` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `CanvasRepository` (e.g. with `.testClearStoreEmptiesEveryModel()` and `.testCoursesSortPinnedFirstThenSortIndexAndExcludeHiddenAndRemoved()`) actually correct?**
  _`CanvasRepository` has 5 INFERRED edges - model-reasoned connections that need verification._