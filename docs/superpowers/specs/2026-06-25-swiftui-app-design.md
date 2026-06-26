# CanvasApp — SwiftUI macOS Menu Bar App Design

**Date:** 2026-06-25
**Author:** Jackson Pike
**Replaces:** Phase 2 TUI (CLI is retired)

---

## Overview

Transform the Phase 2 Canvas CLI into a native macOS menu bar app built in SwiftUI. The app provides the same grade dashboard and what-if calculator as the TUI, with a polished graphical interface using BYU–Hawaii brand colors (red `#ba0c2f`, gold `#c69214`). The CLI (`canvas` command) is retired; all interaction is through the menu bar popover.

---

## Architecture

### Option Chosen: Local Swift Package + SwiftUI App Target

The business logic is extracted into a local Swift Package library (`CanvasCore`). The SwiftUI app target imports `CanvasCore` as a dependency. This keeps the presentation layer thin and the logic independently testable.

### Repository Structure

```
CanvasCLISwift/
  Sources/
    CanvasCore/
      APIClient.swift         ← all URLSession calls
      GradeCalculator.swift   ← pure grade math + solver
      Models.swift            ← all Codable structs + GradedItem
  CanvasApp/
    App/
      CanvasApp.swift         ← @main, NSStatusItem / menu bar setup
    Views/
      CourseListView.swift
      CourseDetailView.swift
      CalculatorView.swift
      SettingsView.swift      ← token input, onboarding
    ViewModels/
      CoursesViewModel.swift
      CourseDetailViewModel.swift
      CalculatorViewModel.swift
  Tests/
    CanvasCoreTests/
      GradeCalculatorTests.swift   ← migrated from Phase 2
      ModelsTests.swift
      DisplayTests.swift
  docs/
    superpowers/specs/
    superpowers/plans/
  MyTool/                     ← DELETED (CLI retired)
```

`Package.swift` defines two products: `CanvasCore` (library) and `CanvasApp` (executable, SwiftUI app). The SwiftUI app uses `NSApplicationDelegateAdaptor` or `MenuBarExtra` (macOS 13+) for the status bar item.

---

## Data & API

All API endpoints are unchanged from Phase 2. `CanvasCore/APIClient.swift` is a direct migration of `MyTool/APIClient.swift` with no changes to endpoints or decoding logic.

**Base URL:** `https://byuh.instructure.com/api/v1`

**Endpoints used:**
| Endpoint | Purpose |
|---|---|
| `GET /courses` | Active courses |
| `GET /courses/:id/enrollments` | Current grade/score |
| `GET /courses/:id/assignment_groups?include[]=assignments` | Groups, weights, drop rules, assignments |
| `GET /courses/:id/submissions?student_ids[]=self` | Submission scores + workflow state |

**Token:** Stored in macOS Keychain via the `Security` framework. On first launch (no token found), the app shows an onboarding sheet with a text field to enter the token. A settings sheet (gear icon) allows updating it later.

---

## Models

All models carry forward from Phase 2 unchanged:

```swift
// CanvasCore/Models.swift
struct Course: Codable { let id: Int; let name: String; let courseCode: String; let applyAssignmentGroupWeights: Bool }
struct Enrollment: Codable { let grades: Grades? }
struct Grades: Codable { let currentScore: Double?; let currentGrade: String? }
struct AssignmentGroupRules: Codable { let dropLowest: Int?; let dropHighest: Int?; let neverDrop: [Int]? }
struct AssignmentGroup: Codable { let id: Int; let name: String; let groupWeight: Double; let rules: AssignmentGroupRules?; let assignments: [Assignment] }
struct Assignment: Codable { let id: Int; let name: String; let pointsPossible: Double; let dueAt: String?; let assignmentGroupId: Int }
struct Submission: Codable { let assignmentId: Int; let score: Double?; let workflowState: String }
struct GradedItem { let assignmentId: Int; let name: String; let groupId: Int; let pointsPossible: Double; var earnedPoints: Double?; var whatIfPoints: Double? }
```

JSON decoding uses `keyDecodingStrategy = .convertFromSnakeCase` throughout.

---

## Grade Calculator

### Existing Logic (carry forward unchanged)

- `GroupInfo`: name, weight, dropLowest, dropHighest, neverDrop
- `buildGradedItems(groups:submissions:)`: joins assignment + submission data
- `GradeCalculator.currentGrade()`: weighted or unweighted, respects drop rules
- `GradeCalculator.groupBreakdown()`: per-group percent for dashboard display
- `Array<GradedItem>.applyingWhatIf(percent:toAssignmentIds:)`
- `Array<GradedItem>.applyingBlanketToUngraded(percent:)`
- `Array<GradedItem>.applyingPerfectRemaining()`

Drop rules (`drop_lowest`, `drop_highest`, `never_drop`) are decoded from the Canvas API and applied automatically in `groupPercent()`. No user interaction is required.

### New: Target Grade Solver

```swift
enum SolveResult {
    case alreadyAchieved
    case needed(percent: Double)          // 0–100
    case impossible(maxPossible: Double)  // even 100% on everything yields this
}

extension GradeCalculator {
    func solveForTarget(
        targetPercent: Double,
        solveAssignmentIds: Set<Int>
    ) -> SolveResult
}
```

**Algorithm (binary search):**
1. If `currentGrade() >= targetPercent` → `.alreadyAchieved`
2. Apply 100% to all solve assignments → if result < target → `.impossible(maxPossible:)`
3. Binary search score X ∈ [0, 100]: apply X to all solve assignments, check if result ≥ target. Converge to 0.1% precision. → `.needed(X)`

Binary search handles both weighted and unweighted courses without a closed-form inverse. Drop rules are respected automatically since the solver calls the existing `groupPercent()` path.

### Grade Scale

**⚠️ Must verify against BYUH Registrar before implementation.**

Placeholder (standard plus/minus scale):
```swift
let letterThresholds: [(String, Double)] = [
    ("A",  93.0), ("A-", 90.0),
    ("B+", 87.0), ("B",  83.0), ("B-", 80.0),
    ("C+", 77.0), ("C",  73.0), ("C-", 70.0),
    ("D+", 67.0), ("D",  63.0), ("D-", 60.0),
    ("F",   0.0)
]
```

This is stored as a single constant in `GradeCalculator.swift`. If BYUH uses different cutoffs, only this one value changes.

---

## Screens

### 1. Course List View

- Shown on popover open
- Fetches courses on appear; shows loading spinner during fetch
- Each row: course code (bold, red), course name, current grade % (gold), letter grade
- Tap a row → navigate to Course Detail
- Refresh button in header re-fetches

### 2. Course Detail View

Mirrors the TUI grade dashboard from Phase 2, rendered natively in SwiftUI:

```
2026 Spr CS 420 — Programming Languages
──────────────────────────────────────────
Programming Exam  (25%)  100.0%  ████████████  A
Practice          (25%)  100.0%  ████████████  A
Exams             (20%)   75.0%  █████████░░░  C
Attendance        (10%)   94.0%  ███████████░  A
Project           (10%)  100.0%  ████████████  A
Homework           (5%)  100.0%  ████████████  A
Lecture Quizzes    (5%)  100.0%  ████████████  A

Overall: 94.4%  A
```

Progress bars use SwiftUI `ProgressView` styled with BYU–Hawaii brand colors. Letter grade uses the verified BYUH grade scale.

"Open Calculator" button at the bottom navigates to the Calculator view.

### 3. Calculator View

Two modes, toggled via a `Picker` (segmented control) at the top:

#### Manual What-If Tab

- List of all assignments for the course
- Each row: assignment name, points possible, current score (or "—" if ungraded)
- Toggle any assignment on to enter a hypothetical score
- Score input accepts **points** (e.g. `47`) or **percentage** (e.g. `94%`); auto-converts to the other on entry
- Live grade recalculates after each keystroke
- Recalculated overall grade shown prominently at top (gold %)
- Per-group breakdown updates live below

#### Solve For Me Tab

- Target grade input at top: segmented `Letter / %` picker
  - Letter: dropdown of grade letters (A through F)
  - Percent: numeric text field
- Assignment scope picker: "Single assignment" vs "Spread across selected"
  - Single: dropdown of ungraded assignments
  - Spread: multi-select list of ungraded assignments
- **Result display:**
  - `.alreadyAchieved` → "✓ You've already hit your target grade"
  - `.needed(X)` → "You need **87.5% (44/50 pts)** on [Final Exam]" (or "You need **X%** on each of your N selected assignments" — the solver finds a single uniform score applied to all selected assignments)
  - `.impossible(max)` → "Not achievable — even 100% on everything gives you 88.2%"
- Manual what-if scores from the other tab are composited in before solving ("given what you've entered, what else do you need?")

### 4. Settings / Onboarding Sheet

- Shown automatically if no token in Keychain
- Text field labeled "Canvas API Token" with secure text entry
- "Save" writes to Keychain
- Accessible any time via gear icon in popover header

---

## Visual Style

- **Brand colors:** Red `#ba0c2f` (header, accents), Gold `#c69214` (grade percentages, highlights)
- **Typography:** System font (SF Pro); course codes bold; grades in gold
- **Background:** Native macOS popover background (vibrancy/material)
- **Progress bars:** Filled in red, track in light gray
- **Letter grades:** Colored by tier (A = green, B = blue, C = yellow, D/F = red)
- **Popover size:** ~380 × 520 pts (comfortable for grade table); resizable

---

## Error Handling

| Scenario | Behavior |
|---|---|
| No token in Keychain | Show onboarding sheet; block other screens |
| API 401 | Show inline error "Invalid token — update in Settings" |
| Network failure | Show retry button with error message |
| Course with no assignments | Show "No assignments yet" in calculator |
| Target grade impossible | Show max-achievable grade clearly |
| BYUH grade scale unverified | ⚠️ Placeholder — must confirm before shipping |

---

## Data Refresh

- **On popover open:** Fetch courses list
- **On course tap:** Fetch assignment groups + submissions in parallel
- **Manual refresh:** Header refresh button re-fetches current view's data
- **No background polling:** Personal tool; manual refresh is sufficient
- **Caching:** In-memory only; no disk cache; close + reopen re-fetches

---

## Out of Scope (Phase 3)

- Announcements
- To-do / upcoming assignments list
- Submitting or modifying assignments
- iOS / iPadOS app
- Background refresh / notifications
- Disk-based caching
- Multiple Canvas instances (BYUH only)
