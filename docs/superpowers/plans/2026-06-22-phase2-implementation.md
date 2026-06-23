# CanvasCLISwift Phase 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the Phase 1 Canvas CLI from a single grade-printer script into a multi-command tool with an interactive arrow-key TUI, a weighted grade dashboard, and a what-if grade calculator.

**Architecture:** Split the current monolithic `main.swift` into focused files under the `CanvasCLISwift` executable target (`Models`, `APIClient`, `GradeCalculator`, `Display`, `TUI`, `main`). All pure logic — grade math, formatting, JSON decoding — lives in functions with no I/O so it can be unit-tested. A new `CanvasCLISwiftTests` target `@testable import`s the executable target and drives the pure logic with XCTest. `main.swift` uses `swift-argument-parser` to register subcommands; the no-arg invocation launches the raw-mode TUI.

**Tech Stack:** Swift 6.3 (toolchain present), SwiftPM, `swift-argument-parser` 1.x, XCTest, Foundation `URLSession`, Darwin `termios` for raw terminal mode.

## Global Constraints

- Swift tools version stays `5.9`; platform floor stays `.macOS(.v12)` — copied verbatim from existing `Package.swift`.
- All source files live in `MyTool/` (the executable target's `path`), as named in the spec's File Structure section.
- API base URL is exactly `https://byuh.instructure.com/api/v1`.
- Auth uses the `CANVAS_TOKEN` environment variable only — no config file (out of scope).
- `Package.swift` and `canvas` are **gitignored**; any commit that changes `Package.swift` MUST use `git add -f Package.swift`. The compiled `canvas` binary is never committed.
- JSON decoding uses `JSONDecoder` with `keyDecodingStrategy = .convertFromSnakeCase` everywhere (matches Phase 1 and lets Swift property names stay camelCase).
- ANSI color constants reuse the Phase 1 palette: RED `#ba0c2f`, GOLD `#c69214`.
- Grade percentages are represented as `Double` on a 0–100 scale unless a function explicitly documents a 0–1 fraction.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `MyTool/Models.swift` | All `Codable` structs (`Course`, `Enrollment`, `Grades`, `AssignmentGroup`, `Assignment`, `Submission`) plus the internal `GradedItem` join struct. No logic. |
| `MyTool/APIClient.swift` | `APIClient` struct: every `URLSession` call + `APIError` enum. The only file that does network I/O. |
| `MyTool/GradeCalculator.swift` | Pure grade math: weighted/unweighted current grade, per-group breakdown, what-if mutations. No UI, no API, no `print`. |
| `MyTool/Display.swift` | Pure formatting: letter grade, progress bar, percent strings, ANSI palette, banner. No I/O beyond returning strings. |
| `MyTool/TUI.swift` | Raw terminal mode (`termios`), key-input loop, and the three interactive screens. |
| `MyTool/main.swift` | `Canvas` root `AsyncParsableCommand` + `Courses` / `Grades` / `Calc` subcommands; the entry-point top-level `await Canvas.main()`. |
| `Tests/CanvasCLISwiftTests/*` | XCTest cases for `Models`, `GradeCalculator`, `Display`. |

`APIClient` and `TUI` are not unit-tested (network + terminal I/O); their tasks end in a build + manual smoke-test deliverable. Everything else is TDD.

---

## Type Contract (shared across tasks)

These signatures are defined in early tasks and consumed by later ones. Listed here once so every task agrees on names and types.

```swift
// Models.swift
struct Course: Codable { let id: Int; let name: String; let courseCode: String; let applyAssignmentGroupWeights: Bool }
struct Enrollment: Codable { let grades: Grades }
struct Grades: Codable { let currentScore: Double?; let currentGrade: String? }
struct AssignmentGroup: Codable { let id: Int; let name: String; let groupWeight: Double; let assignments: [Assignment] }
struct Assignment: Codable { let id: Int; let name: String; let pointsPossible: Double; let dueAt: String?; let assignmentGroupId: Int }
struct Submission: Codable { let assignmentId: Int; let score: Double?; let workflowState: String }
struct GradedItem { let assignmentId: Int; let name: String; let groupId: Int; let pointsPossible: Double; var earnedPoints: Double?; var whatIfPoints: Double? }

// GradeCalculator.swift
struct GroupInfo { let name: String; let weight: Double }          // weight on 0–100 scale
struct GroupResult { let groupId: Int; let name: String; let weight: Double; let percent: Double? } // percent 0–100, nil if no graded items
struct GradeCalculator {
    let items: [GradedItem]
    let groups: [Int: GroupInfo]
    let weighted: Bool
    func currentGrade() -> Double?                 // 0–100, nil if nothing graded
    func groupBreakdown() -> [GroupResult]
}
extension Array where Element == GradedItem {
    func applyingWhatIf(percent: Double, toAssignmentIds ids: Set<Int>) -> [GradedItem]
    func applyingBlanketToUngraded(percent: Double) -> [GradedItem]
    func applyingPerfectRemaining() -> [GradedItem]
}
func buildGradedItems(groups: [AssignmentGroup], submissions: [Submission]) -> [GradedItem]

// Display.swift
func letterGrade(for percent: Double) -> String
func progressBar(percent: Double, width: Int) -> String
func formatPercent(_ value: Double?) -> String     // "88.4%" or "—" for nil

// APIClient.swift
enum APIError: Error, CustomStringConvertible { case missingToken, unauthorized, http(Int), network(String) }
struct APIClient {
    let token: String
    func courses() async throws -> [Course]
    func enrollments(courseId: Int) async throws -> [Enrollment]
    func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup]
    func submissions(courseId: Int) async throws -> [Submission]
}
```

---

## Task 1: Package setup — dependencies, file split, test target

**Files:**
- Modify: `Package.swift`
- Create: `MyTool/Models.swift`, `MyTool/Display.swift`
- Modify: `MyTool/main.swift`
- Create: `Tests/CanvasCLISwiftTests/SmokeTests.swift`

**Interfaces:**
- Produces: a buildable executable target `CanvasCLISwift` with the `ArgumentParser` product linked, and a test target `CanvasCLISwiftTests` that can `@testable import CanvasCLISwift`.

- [ ] **Step 1: Rewrite `Package.swift` to add the dependency and test target**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanvasCLISwift",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "CanvasCLISwift",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "MyTool"
        ),
        .testTarget(
            name: "CanvasCLISwiftTests",
            dependencies: ["CanvasCLISwift"],
            path: "Tests/CanvasCLISwiftTests"
        )
    ]
)
```

- [ ] **Step 2: Move the banner/palette out of `main.swift` into `MyTool/Display.swift`**

Create `MyTool/Display.swift` with the palette and banner lifted verbatim from Phase 1 `main.swift` (lines 6–19). The remaining `Display` functions are added in Task 6 — this step only relocates existing constants so `main.swift` can shrink.

```swift
import Foundation

let RED   = "\u{001B}[38;2;186;12;47m"   // #ba0c2f
let GOLD  = "\u{001B}[38;2;198;146;20m"  // #c69214
let BOLD  = "\u{001B}[1m"
let RESET = "\u{001B}[0m"

let banner = """
\(BOLD)\(RED) ██████╗ █████╗ ███╗   ██╗██╗   ██╗ █████╗ ███████╗\(RESET)
\(BOLD)\(RED)██╔════╝██╔══██╗████╗  ██║██║   ██║██╔══██╗██╔════╝\(RESET)
\(BOLD)\(RED)██║     ███████║██╔██╗ ██║██║   ██║███████║███████╗\(RESET)
\(BOLD)\(RED)██║     ██╔══██║██║╚██╗██║╚██╗ ██╔╝██╔══██║╚════██║\(RESET)
\(BOLD)\(RED)╚██████╗██║  ██║██║ ╚████║ ╚████╔╝ ██║  ██║███████║\(RESET)
\(BOLD)\(RED) ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝  ╚═╝╚══════╝\(RESET)
"""
```

- [ ] **Step 3: Create an empty `MyTool/Models.swift` placeholder**

```swift
import Foundation

// Codable models added in Task 2.
```

- [ ] **Step 4: Replace `main.swift` with a minimal ArgumentParser entry point**

The Phase 1 fetch logic is deleted here (it is rebuilt properly in Tasks 5 and 8). This keeps the project compiling with the new structure.

```swift
import ArgumentParser
import Foundation

struct Canvas: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "canvas",
        abstract: "Canvas CLI for BYU–Hawaii."
    )

    func run() async throws {
        print(banner)
        print("Phase 2 scaffolding — subcommands coming online.")
    }
}

await Canvas.main()
```

- [ ] **Step 5: Create the smoke test**

```swift
import XCTest
@testable import CanvasCLISwift

final class SmokeTests: XCTestCase {
    func testPaletteConstantsExist() {
        XCTAssertEqual(RESET, "\u{001B}[0m")
        XCTAssertFalse(banner.isEmpty)
    }
}
```

- [ ] **Step 6: Resolve, build, and test**

Run: `swift build && swift test`
Expected: dependency `swift-argument-parser` resolves, build succeeds, `SmokeTests.testPaletteConstantsExist` PASSES.

- [ ] **Step 7: Commit**

```bash
git add -f Package.swift
git add Package.resolved MyTool/main.swift MyTool/Models.swift MyTool/Display.swift Tests/CanvasCLISwiftTests/SmokeTests.swift
git commit -m "feat: add ArgumentParser, split files, add test target"
```

---

## Task 2: Models + JSON decoding tests

**Files:**
- Modify: `MyTool/Models.swift`
- Create: `Tests/CanvasCLISwiftTests/ModelsTests.swift`

**Interfaces:**
- Produces: the `Codable` structs and `GradedItem` from the Type Contract.

- [ ] **Step 1: Write failing decoding tests**

```swift
import XCTest
@testable import CanvasCLISwift

final class ModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testCourseDecodesSnakeCase() throws {
        let json = """
        [{"id": 1, "name": "Data Structures", "course_code": "CS 246", "apply_assignment_group_weights": true}]
        """.data(using: .utf8)!
        let courses = try decoder().decode([Course].self, from: json)
        XCTAssertEqual(courses.first?.courseCode, "CS 246")
        XCTAssertTrue(courses.first!.applyAssignmentGroupWeights)
    }

    func testAssignmentGroupDecodesNestedAssignments() throws {
        let json = """
        [{"id": 10, "name": "Homework", "group_weight": 40.0,
          "assignments": [{"id": 100, "name": "HW1", "points_possible": 50.0, "due_at": null, "assignment_group_id": 10}]}]
        """.data(using: .utf8)!
        let groups = try decoder().decode([AssignmentGroup].self, from: json)
        XCTAssertEqual(groups.first?.groupWeight, 40.0)
        XCTAssertEqual(groups.first?.assignments.first?.assignmentGroupId, 10)
        XCTAssertNil(groups.first?.assignments.first?.dueAt)
    }

    func testSubmissionDecodesNullScore() throws {
        let json = """
        [{"assignment_id": 100, "score": null, "workflow_state": "unsubmitted"}]
        """.data(using: .utf8)!
        let subs = try decoder().decode([Submission].self, from: json)
        XCTAssertNil(subs.first?.score)
        XCTAssertEqual(subs.first?.workflowState, "unsubmitted")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter ModelsTests`
Expected: FAIL — `Course` has no `applyAssignmentGroupWeights`, types `AssignmentGroup`/`Assignment`/`Submission` undefined.

- [ ] **Step 3: Implement the models**

```swift
import Foundation

struct Course: Codable {
    let id: Int
    let name: String
    let courseCode: String
    let applyAssignmentGroupWeights: Bool
}

struct Enrollment: Codable {
    let grades: Grades
}

struct Grades: Codable {
    let currentScore: Double?
    let currentGrade: String?
}

struct AssignmentGroup: Codable {
    let id: Int
    let name: String
    let groupWeight: Double
    let assignments: [Assignment]
}

struct Assignment: Codable {
    let id: Int
    let name: String
    let pointsPossible: Double
    let dueAt: String?
    let assignmentGroupId: Int
}

struct Submission: Codable {
    let assignmentId: Int
    let score: Double?
    let workflowState: String
}

struct GradedItem {
    let assignmentId: Int
    let name: String
    let groupId: Int
    let pointsPossible: Double
    var earnedPoints: Double?
    var whatIfPoints: Double?
}
```

Note: `Course.applyAssignmentGroupWeights` requires the courses API call to include `?include[]=total_scores` is NOT needed, but the field only appears with `?include[]=` of nothing special — Canvas returns it by default on `/courses`. Task 5 keeps the existing `/courses` query and adds nothing for this field.

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter ModelsTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add MyTool/Models.swift Tests/CanvasCLISwiftTests/ModelsTests.swift
git commit -m "feat: add Phase 2 Codable models with decoding tests"
```

---

## Task 3: GradeCalculator — item building + unweighted current grade

**Files:**
- Create: `MyTool/GradeCalculator.swift`
- Create: `Tests/CanvasCLISwiftTests/GradeCalculatorTests.swift`

**Interfaces:**
- Consumes: `GradedItem`, `AssignmentGroup`, `Submission` (Task 2).
- Produces: `GroupInfo`, `GroupResult`, `GradeCalculator` (with `currentGrade()` for the unweighted path), and `buildGradedItems(groups:submissions:)`.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import CanvasCLISwift

final class GradeCalculatorTests: XCTestCase {
    private func item(_ id: Int, group: Int, possible: Double, earned: Double?) -> GradedItem {
        GradedItem(assignmentId: id, name: "A\(id)", groupId: group, pointsPossible: possible, earnedPoints: earned, whatIfPoints: nil)
    }

    func testBuildGradedItemsJoinsScores() {
        let groups = [AssignmentGroup(id: 1, name: "HW", groupWeight: 100,
            assignments: [Assignment(id: 100, name: "HW1", pointsPossible: 10, dueAt: nil, assignmentGroupId: 1)])]
        let subs = [Submission(assignmentId: 100, score: 8, workflowState: "graded")]
        let items = buildGradedItems(groups: groups, submissions: subs)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].earnedPoints, 8)
        XCTAssertEqual(items[0].groupId, 1)
    }

    func testUnweightedIgnoresUngradedItems() {
        let items = [item(1, group: 1, possible: 10, earned: 9),
                     item(2, group: 1, possible: 10, earned: nil)]
        let calc = GradeCalculator(items: items, groups: [1: GroupInfo(name: "HW", weight: 100)], weighted: false)
        XCTAssertEqual(calc.currentGrade()!, 90.0, accuracy: 0.001)
    }

    func testCurrentGradeNilWhenNothingGraded() {
        let items = [item(1, group: 1, possible: 10, earned: nil)]
        let calc = GradeCalculator(items: items, groups: [1: GroupInfo(name: "HW", weight: 100)], weighted: false)
        XCTAssertNil(calc.currentGrade())
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter GradeCalculatorTests`
Expected: FAIL — `GradeCalculator`, `GroupInfo`, `buildGradedItems` undefined.

- [ ] **Step 3: Implement the unweighted calculator**

```swift
import Foundation

struct GroupInfo {
    let name: String
    let weight: Double      // 0–100
}

struct GroupResult {
    let groupId: Int
    let name: String
    let weight: Double
    let percent: Double?    // 0–100, nil when the group has no graded items
}

func buildGradedItems(groups: [AssignmentGroup], submissions: [Submission]) -> [GradedItem] {
    let scoreByAssignment = Dictionary(
        submissions.map { ($0.assignmentId, $0.score) },
        uniquingKeysWith: { first, _ in first }
    )
    return groups.flatMap { group in
        group.assignments.map { a in
            GradedItem(assignmentId: a.id, name: a.name, groupId: a.assignmentGroupId,
                       pointsPossible: a.pointsPossible,
                       earnedPoints: scoreByAssignment[a.id] ?? nil,
                       whatIfPoints: nil)
        }
    }
}

struct GradeCalculator {
    let items: [GradedItem]
    let groups: [Int: GroupInfo]
    let weighted: Bool

    /// whatIf overrides real earned points when present.
    private func effectivePoints(_ item: GradedItem) -> Double? {
        item.whatIfPoints ?? item.earnedPoints
    }

    func currentGrade() -> Double? {
        if weighted { return weightedGrade() }
        return unweightedGrade()
    }

    private func unweightedGrade() -> Double? {
        let graded = items.filter { effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        let earned = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    // weightedGrade() and groupBreakdown() implemented in Task 4.
    private func weightedGrade() -> Double? { nil }
    func groupBreakdown() -> [GroupResult] { [] }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter GradeCalculatorTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add MyTool/GradeCalculator.swift Tests/CanvasCLISwiftTests/GradeCalculatorTests.swift
git commit -m "feat: add unweighted grade calculation and item joining"
```

---

## Task 4: GradeCalculator — weighted grade + group breakdown

**Files:**
- Modify: `MyTool/GradeCalculator.swift`
- Modify: `Tests/CanvasCLISwiftTests/GradeCalculatorTests.swift`

**Interfaces:**
- Consumes: `GradeCalculator`, `GroupInfo`, `GroupResult` (Task 3).
- Produces: working `weightedGrade()` and `groupBreakdown()`.

- [ ] **Step 1: Add failing tests**

Append to `GradeCalculatorTests`:

```swift
    func testWeightedGradeNormalizesOverActiveGroups() {
        // HW (weight 40): 90%. Quiz (weight 20): 80%. Final (weight 40): ungraded.
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(2, group: 2, possible: 100, earned: 80),
                     item(3, group: 3, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 40),
            2: GroupInfo(name: "Quiz", weight: 20),
            3: GroupInfo(name: "Final", weight: 40)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
        // (0.9*40 + 0.8*20) / (40+20) = (36+16)/60 = 86.666...
        XCTAssertEqual(calc.currentGrade()!, 86.6667, accuracy: 0.001)
    }

    func testGroupBreakdownReportsNilForUngradedGroup() {
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(3, group: 3, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 60),
            3: GroupInfo(name: "Final", weight: 40)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
        let breakdown = calc.groupBreakdown().sorted { $0.groupId < $1.groupId }
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown[0].percent!, 90.0, accuracy: 0.001)
        XCTAssertNil(breakdown[1].percent)
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter GradeCalculatorTests`
Expected: FAIL — `weightedGrade()` returns `nil`, `groupBreakdown()` returns `[]`.

- [ ] **Step 3: Implement weighted math + breakdown**

Replace the two placeholder methods at the bottom of `GradeCalculator`:

```swift
    /// Percent (0–100) for one group over its graded items only; nil if none graded.
    private func groupPercent(_ groupId: Int) -> Double? {
        let graded = items.filter { $0.groupId == groupId && effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        let earned = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    private func weightedGrade() -> Double? {
        var weightedSum = 0.0
        var activeWeight = 0.0
        for (groupId, info) in groups {
            guard let pct = groupPercent(groupId) else { continue }
            weightedSum += (pct / 100) * info.weight
            activeWeight += info.weight
        }
        guard activeWeight > 0 else { return nil }
        return weightedSum / activeWeight * 100
    }

    func groupBreakdown() -> [GroupResult] {
        groups.map { groupId, info in
            GroupResult(groupId: groupId, name: info.name, weight: info.weight, percent: groupPercent(groupId))
        }
    }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter GradeCalculatorTests`
Expected: PASS (5 tests total).

- [ ] **Step 5: Commit**

```bash
git add MyTool/GradeCalculator.swift Tests/CanvasCLISwiftTests/GradeCalculatorTests.swift
git commit -m "feat: add weighted grade calculation and group breakdown"
```

---

## Task 5: GradeCalculator — what-if mutations

**Files:**
- Modify: `MyTool/GradeCalculator.swift`
- Modify: `Tests/CanvasCLISwiftTests/GradeCalculatorTests.swift`

**Interfaces:**
- Consumes: `GradedItem` (Task 2).
- Produces: `applyingWhatIf(percent:toAssignmentIds:)`, `applyingBlanketToUngraded(percent:)`, `applyingPerfectRemaining()` on `[GradedItem]`.

- [ ] **Step 1: Add failing tests**

Append to `GradeCalculatorTests`:

```swift
    func testApplyingWhatIfSetsSelectedItemsByPercent() {
        let items = [item(1, group: 1, possible: 50, earned: 25),
                     item(2, group: 1, possible: 50, earned: 50)]
        let result = items.applyingWhatIf(percent: 100, toAssignmentIds: [1])
        XCTAssertEqual(result[0].whatIfPoints, 50)   // 100% of 50
        XCTAssertNil(result[1].whatIfPoints)         // untouched
    }

    func testBlanketOnlyAffectsUngraded() {
        let items = [item(1, group: 1, possible: 100, earned: 70),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = items.applyingBlanketToUngraded(percent: 80)
        XCTAssertNil(result[0].whatIfPoints)         // already graded → untouched
        XCTAssertEqual(result[1].whatIfPoints, 80)   // 80% of 100
    }

    func testPerfectRemainingSetsUngradedTo100() {
        let items = [item(1, group: 1, possible: 40, earned: nil)]
        let result = items.applyingPerfectRemaining()
        XCTAssertEqual(result[0].whatIfPoints, 40)
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter GradeCalculatorTests`
Expected: FAIL — the three `applying...` methods are undefined.

- [ ] **Step 3: Implement the mutations**

Append to `MyTool/GradeCalculator.swift`:

```swift
extension Array where Element == GradedItem {
    /// An item is "ungraded" when it has neither a real earned score nor a prior what-if.
    private func isUngraded(_ item: GradedItem) -> Bool {
        item.earnedPoints == nil && item.whatIfPoints == nil
    }

    func applyingWhatIf(percent: Double, toAssignmentIds ids: Set<Int>) -> [GradedItem] {
        map { item in
            guard ids.contains(item.assignmentId) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * percent / 100
            return copy
        }
    }

    func applyingBlanketToUngraded(percent: Double) -> [GradedItem] {
        map { item in
            guard isUngraded(item) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * percent / 100
            return copy
        }
    }

    func applyingPerfectRemaining() -> [GradedItem] {
        applyingBlanketToUngraded(percent: 100)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter GradeCalculatorTests`
Expected: PASS (8 tests total).

- [ ] **Step 5: Commit**

```bash
git add MyTool/GradeCalculator.swift Tests/CanvasCLISwiftTests/GradeCalculatorTests.swift
git commit -m "feat: add what-if, blanket, and perfect-remaining grade mutations"
```

---

## Task 6: Display formatting helpers

**Files:**
- Modify: `MyTool/Display.swift`
- Create: `Tests/CanvasCLISwiftTests/DisplayTests.swift`

**Interfaces:**
- Produces: `letterGrade(for:)`, `progressBar(percent:width:)`, `formatPercent(_:)`.

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import CanvasCLISwift

final class DisplayTests: XCTestCase {
    func testLetterGradeBoundaries() {
        XCTAssertEqual(letterGrade(for: 93), "A")
        XCTAssertEqual(letterGrade(for: 92.9), "A-")
        XCTAssertEqual(letterGrade(for: 87), "B+")
        XCTAssertEqual(letterGrade(for: 59.9), "F")
    }

    func testProgressBarFillsProportionally() {
        let bar = progressBar(percent: 50, width: 10)
        XCTAssertEqual(bar.filter { $0 == "█" }.count, 5)
        XCTAssertEqual(bar.count, 10)
    }

    func testFormatPercentRoundsToOneDecimal() {
        XCTAssertEqual(formatPercent(88.44), "88.4%")
        XCTAssertEqual(formatPercent(nil), "—")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter DisplayTests`
Expected: FAIL — the three functions are undefined.

- [ ] **Step 3: Implement the helpers**

Append to `MyTool/Display.swift`:

```swift
func letterGrade(for percent: Double) -> String {
    switch percent {
    case 93...:      return "A"
    case 90..<93:    return "A-"
    case 87..<90:    return "B+"
    case 83..<87:    return "B"
    case 80..<83:    return "B-"
    case 77..<80:    return "C+"
    case 73..<77:    return "C"
    case 70..<73:    return "C-"
    case 67..<70:    return "D+"
    case 63..<67:    return "D"
    case 60..<63:    return "D-"
    default:         return "F"
    }
}

func progressBar(percent: Double, width: Int) -> String {
    let clamped = max(0, min(100, percent))
    let filled = Int((clamped / 100 * Double(width)).rounded())
    return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
}

func formatPercent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.1f%%", value)
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter DisplayTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add MyTool/Display.swift Tests/CanvasCLISwiftTests/DisplayTests.swift
git commit -m "feat: add letter-grade, progress-bar, and percent formatting"
```

---

## Task 7: APIClient — networking layer

**Files:**
- Create: `MyTool/APIClient.swift`

**Interfaces:**
- Consumes: `Course`, `Enrollment`, `AssignmentGroup`, `Submission` (Task 2).
- Produces: `APIError`, `APIClient` with `courses()`, `enrollments(courseId:)`, `assignmentGroups(courseId:)`, `submissions(courseId:)`.

This task has no unit tests (network I/O). The deliverable is a clean build plus a manual smoke test against the live API.

- [ ] **Step 1: Implement the client**

```swift
import Foundation

enum APIError: Error, CustomStringConvertible {
    case missingToken
    case unauthorized
    case http(Int)
    case network(String)

    var description: String {
        switch self {
        case .missingToken: return "CANVAS_TOKEN is not set. Export it and try again."
        case .unauthorized: return "Invalid token — check your CANVAS_TOKEN environment variable."
        case .http(let code): return "Canvas API returned HTTP \(code)."
        case .network(let msg): return "Network error: \(msg)."
        }
    }
}

struct APIClient {
    let token: String
    private let baseURL = "https://byuh.instructure.com/api/v1"

    private func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.network("bad URL \(path)")
        }
        components.queryItems = query
        guard let url = components.url else { throw APIError.network("bad query for \(path)") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 { throw APIError.unauthorized }
                guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
            }
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func courses() async throws -> [Course] {
        let data = try await get("/courses", query: [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "50")
        ])
        return try decoder().decode([Course].self, from: data)
    }

    func enrollments(courseId: Int) async throws -> [Enrollment] {
        let data = try await get("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "user_id", value: "self"),
            URLQueryItem(name: "include[]", value: "grades")
        ])
        return try decoder().decode([Enrollment].self, from: data)
    }

    func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
        let data = try await get("/courses/\(courseId)/assignment_groups", query: [
            URLQueryItem(name: "include[]", value: "assignments"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([AssignmentGroup].self, from: data)
    }

    func submissions(courseId: Int) async throws -> [Submission] {
        let data = try await get("/courses/\(courseId)/students/submissions", query: [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([Submission].self, from: data)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete, no errors.

- [ ] **Step 3: Manual smoke test (requires a real token)**

Add a temporary debug subcommand is unnecessary — instead verify wiring after Task 8. For now confirm the build only. If `CANVAS_TOKEN` is available, the reviewer may add a throwaway `print` in `main.swift`'s `run()` calling `APIClient(token:).courses()`; this is optional and must be reverted before commit.

- [ ] **Step 4: Commit**

```bash
git add MyTool/APIClient.swift
git commit -m "feat: add APIClient with courses, enrollments, groups, submissions"
```

---

## Task 8: Non-interactive subcommands — `courses` and `grades`

**Files:**
- Modify: `MyTool/main.swift`

**Interfaces:**
- Consumes: `APIClient`, `GradeCalculator`, `buildGradedItems`, `Display` helpers, models.
- Produces: `Canvas.Courses` and `Canvas.Grades` subcommands and a shared `requireToken()` helper.

- [ ] **Step 1: Rewrite `main.swift` with the token helper and subcommands**

```swift
import ArgumentParser
import Foundation

func requireToken() throws -> String {
    let token = ProcessInfo.processInfo.environment["CANVAS_TOKEN"] ?? ""
    guard !token.isEmpty else { throw APIError.missingToken }
    return token
}

struct Canvas: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "canvas",
        abstract: "Canvas CLI for BYU–Hawaii.",
        subcommands: [Courses.self, Grades.self],
        defaultSubcommand: nil
    )

    func run() async throws {
        // No subcommand → interactive TUI (wired in Task 9). For now, list courses.
        print(banner)
        try await Courses().run()
    }
}

extension Canvas {
    struct Courses: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List active courses with current grade.")

        func run() async throws {
            let client = APIClient(token: try requireToken())
            do {
                let courses = try await client.courses()
                for course in courses {
                    let enrollments = try await client.enrollments(courseId: course.id)
                    let score = enrollments.first?.grades.currentScore
                    print("\(BOLD)\(course.courseCode)\(RESET) — \(course.name)  \(GOLD)\(formatPercent(score))\(RESET)")
                }
            } catch let error as APIError {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
                throw ExitCode(1)
            }
        }
    }

    struct Grades: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Full grade breakdown for one course.")

        @Argument(help: "Canvas course id.") var courseId: Int

        func run() async throws {
            let client = APIClient(token: try requireToken())
            do {
                let groups = try await client.assignmentGroups(courseId: courseId)
                let submissions = try await client.submissions(courseId: courseId)
                let course = try await client.courses().first { $0.id == courseId }

                let items = buildGradedItems(groups: groups, submissions: submissions)
                let groupInfo = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) })
                let weighted = course?.applyAssignmentGroupWeights ?? false
                let calc = GradeCalculator(items: items, groups: groupInfo, weighted: weighted)

                let title = course.map { "\($0.courseCode) — \($0.name)" } ?? "Course \(courseId)"
                let overall = calc.currentGrade()
                let letter = overall.map { " " + letterGrade(for: $0) } ?? ""
                print("\(BOLD)\(title)\(RESET)   \(formatPercent(overall))\(letter)")
                print(String(repeating: "─", count: 53))

                for result in calc.groupBreakdown().sorted(by: { $0.weight > $1.weight }) {
                    let weightLabel = weighted ? String(format: "(%.0f%%)", result.weight) : "     "
                    if let pct = result.percent {
                        let bar = progressBar(percent: pct, width: 14)
                        print(" \(result.name.padding(toLength: 16, withPad: " ", startingAt: 0)) \(weightLabel)  \(formatPercent(pct))  \(bar)  \(letterGrade(for: pct))")
                    } else {
                        print(" \(result.name.padding(toLength: 16, withPad: " ", startingAt: 0)) \(weightLabel)  not yet graded")
                    }
                }
            } catch let error as APIError {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
                throw ExitCode(1)
            }
        }
    }
}

await Canvas.main()
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete, no errors.

- [ ] **Step 3: Verify the unit suite still passes**

Run: `swift test`
Expected: all prior tests PASS (no regressions).

- [ ] **Step 4: Manual smoke test**

Run: `CANVAS_TOKEN=$CANVAS_TOKEN swift run CanvasCLISwift courses`
Expected: prints active courses with a gold percentage each. Then `swift run CanvasCLISwift grades <id>` prints a dashboard with a group breakdown. With no token: `swift run CanvasCLISwift courses` prints the missing-token error to stderr and exits 1.

- [ ] **Step 5: Commit**

```bash
git add MyTool/main.swift
git commit -m "feat: add courses and grades subcommands with dashboard output"
```

---

## Task 9: TUI core — raw mode + course list screen

**Files:**
- Create: `MyTool/TUI.swift`
- Modify: `MyTool/main.swift`

**Interfaces:**
- Consumes: `APIClient`, models, `Display` helpers.
- Produces: `RawMode` helper, `Key` enum, `readKey()`, and `runTUI(client:)` entry that renders the course list and navigates with arrow keys.

No unit tests (terminal I/O). Deliverable is a clean build + manual interaction.

- [ ] **Step 1: Implement raw-mode terminal handling and key reading**

```swift
import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum Key {
    case up, down, enter, escape, char(Character), other
}

/// Enters raw mode on init, restores the previous termios on deinit.
final class RawMode {
    private var original = termios()

    init() {
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        raw.c_lflag &= ~(UInt(ECHO | ICANON))
        raw.c_cc.6 = 1   // VMIN
        raw.c_cc.5 = 0   // VTIME
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }

    func restore() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    }

    deinit { restore() }
}

func readKey() -> Key {
    var byte: UInt8 = 0
    guard read(STDIN_FILENO, &byte, 1) == 1 else { return .other }
    switch byte {
    case 0x0A, 0x0D: return .enter
    case 0x1B:       // ESC — could be a bare escape or an arrow sequence
        var seq: [UInt8] = [0, 0]
        guard read(STDIN_FILENO, &seq[0], 1) == 1, seq[0] == 0x5B,  // '['
              read(STDIN_FILENO, &seq[1], 1) == 1 else { return .escape }
        switch seq[1] {
        case 0x41: return .up
        case 0x42: return .down
        default:   return .other
        }
    default:
        return .char(Character(UnicodeScalar(byte)))
    }
}
```

Note: `c_cc.5` / `c_cc.6` index the `VTIME`/`VMIN` slots of the imported C tuple on Apple platforms; these indices are stable for Darwin's `termios`.

- [ ] **Step 2: Implement the course list screen**

Append to `MyTool/TUI.swift`:

```swift
private let CLEAR = "\u{001B}[2J\u{001B}[H"

func runTUI(client: APIClient) async throws {
    let courses: [Course]
    do {
        courses = try await client.courses()
    } catch let error as APIError {
        print(error.description)
        return
    }
    guard !courses.isEmpty else { print("No active courses found."); return }

    let raw = RawMode()
    defer { raw.restore(); print(RESET) }

    var selected = 0
    while true {
        renderCourseList(courses, selected: selected)
        switch readKey() {
        case .up:    selected = max(0, selected - 1)
        case .down:  selected = min(courses.count - 1, selected + 1)
        case .enter:
            raw.restore()
            try await showCourseDetail(courses[selected], client: client)  // Task 10
            _ = RawMode()  // re-enter raw mode after detail returns
        case .escape, .char("q"): return
        default: break
        }
    }
}

private func renderCourseList(_ courses: [Course], selected: Int) {
    print(CLEAR, terminator: "")
    print("\(BOLD)\(RED)Canvas — Courses\(RESET)   (↑/↓ move · Enter open · q quit)\n")
    for (i, course) in courses.enumerated() {
        let marker = i == selected ? "\(GOLD)❯ \(RESET)" : "  "
        let name = i == selected ? "\(BOLD)\(course.name)\(RESET)" : course.name
        print("\(marker)\(course.courseCode)  \(name)")
    }
}
```

The `showCourseDetail` call is a forward reference satisfied in Task 10. To keep this task compiling on its own, add a temporary stub at the bottom of `TUI.swift`:

```swift
// Temporary stub — replaced in Task 10.
func showCourseDetail(_ course: Course, client: APIClient) async throws {
    print(CLEAR, terminator: "")
    print("Detail for \(course.name) — press any key to return.")
    _ = readKey()
}
```

- [ ] **Step 3: Wire the no-arg path to the TUI in `main.swift`**

Replace `Canvas.run()`:

```swift
    func run() async throws {
        let client = APIClient(token: try requireToken())
        try await runTUI(client: client)
    }
```

- [ ] **Step 4: Build**

Run: `swift build`
Expected: Build complete, no errors.

- [ ] **Step 5: Manual smoke test**

Run: `CANVAS_TOKEN=$CANVAS_TOKEN swift run CanvasCLISwift`
Expected: course list renders; ↑/↓ moves the gold `❯`; Enter shows the stub detail; `q` restores the terminal cleanly (cursor visible, echo on).

- [ ] **Step 6: Commit**

```bash
git add MyTool/TUI.swift MyTool/main.swift
git commit -m "feat: add raw-mode TUI with arrow-key course list"
```

---

## Task 10: TUI course detail — grade dashboard

**Files:**
- Modify: `MyTool/TUI.swift`

**Interfaces:**
- Consumes: `APIClient`, `GradeCalculator`, `buildGradedItems`, `Display` helpers.
- Produces: real `showCourseDetail(_:client:)` rendering the dashboard; `c` opens the calculator (Task 11), `b`/`Esc` returns.

- [ ] **Step 1: Replace the Task 9 stub with the real detail screen**

```swift
func showCourseDetail(_ course: Course, client: APIClient) async throws {
    let groups: [AssignmentGroup]
    let submissions: [Submission]
    do {
        groups = try await client.assignmentGroups(courseId: course.id)
        submissions = try await client.submissions(courseId: course.id)
    } catch let error as APIError {
        print(CLEAR, terminator: ""); print(error.description); _ = readKey(); return
    }

    let items = buildGradedItems(groups: groups, submissions: submissions)
    let groupInfo = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) })
    let calc = GradeCalculator(items: items, groups: groupInfo, weighted: course.applyAssignmentGroupWeights)

    let raw = RawMode()
    defer { raw.restore() }
    while true {
        renderDashboard(course: course, calc: calc, weighted: course.applyAssignmentGroupWeights)
        switch readKey() {
        case .char("c"):
            raw.restore()
            try await runCalculator(course: course, items: items, groupInfo: groupInfo,
                                    weighted: course.applyAssignmentGroupWeights)  // Task 11
            _ = RawMode()
        case .escape, .char("b"): return
        default: break
        }
    }
}

private func renderDashboard(course: Course, calc: GradeCalculator, weighted: Bool) {
    print(CLEAR, terminator: "")
    let overall = calc.currentGrade()
    let letter = overall.map { " " + letterGrade(for: $0) } ?? ""
    print("\(BOLD)\(course.courseCode) — \(course.name)\(RESET)   \(GOLD)\(formatPercent(overall))\(letter)\(RESET)")
    print(String(repeating: "─", count: 53))
    for result in calc.groupBreakdown().sorted(by: { $0.weight > $1.weight }) {
        let name = result.name.padding(toLength: 16, withPad: " ", startingAt: 0)
        let weightLabel = weighted ? String(format: "(%.0f%%)", result.weight) : "     "
        if let pct = result.percent {
            print(" \(name) \(weightLabel)  \(formatPercent(pct))  \(progressBar(percent: pct, width: 14))  \(letterGrade(for: pct))")
        } else {
            print(" \(name) \(weightLabel)  \(GOLD)not yet graded\(RESET)")
        }
    }
    print("\n(c calculator · b back)")
}
```

The `runCalculator(...)` call is a forward reference satisfied in Task 11. Add a temporary stub at the bottom of `TUI.swift`:

```swift
// Temporary stub — replaced in Task 11.
func runCalculator(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], weighted: Bool) async throws {
    print(CLEAR, terminator: ""); print("Calculator — press any key to return."); _ = readKey()
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete, no errors.

- [ ] **Step 3: Manual smoke test**

Run: `CANVAS_TOKEN=$CANVAS_TOKEN swift run CanvasCLISwift`
Expected: select a course, press Enter → dashboard shows overall grade, letter, per-group bars; ungraded groups show "not yet graded"; `b` returns to the list; `c` shows the calculator stub.

- [ ] **Step 4: Commit**

```bash
git add MyTool/TUI.swift
git commit -m "feat: add TUI course-detail grade dashboard"
```

---

## Task 11: Calculator screen + `calc` subcommand

**Files:**
- Modify: `MyTool/TUI.swift`
- Modify: `MyTool/main.swift`

**Interfaces:**
- Consumes: `GradeCalculator`, what-if mutations, `Display` helpers.
- Produces: real `runCalculator(course:items:groupInfo:weighted:)` and the `Canvas.Calc` subcommand.

- [ ] **Step 1: Replace the Task 10 stub with the interactive calculator**

```swift
func runCalculator(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], weighted: Bool) async throws {
    guard !items.isEmpty else {
        print(CLEAR, terminator: ""); print("No assignments found."); _ = readKey(); return
    }

    var working = items          // mutated by what-if actions
    var selected = 0
    let raw = RawMode()
    defer { raw.restore() }

    while true {
        renderCalculator(course: course, items: working, groupInfo: groupInfo, weighted: weighted, selected: selected)
        switch readKey() {
        case .up:   selected = max(0, selected - 1)
        case .down: selected = min(working.count - 1, selected + 1)
        case .enter:
            raw.restore()
            if let pct = promptPercent("What-if score for \(working[selected].name) (0–100): ") {
                working = working.applyingWhatIf(percent: pct, toAssignmentIds: [working[selected].assignmentId])
            }
            _ = RawMode()
        case .char("b"):
            raw.restore()
            if let pct = promptPercent("Blanket score for all ungraded (0–100): ") {
                working = working.applyingBlanketToUngraded(percent: pct)
            }
            _ = RawMode()
        case .char("p"):
            working = working.applyingPerfectRemaining()
        case .char("r"):
            working = items      // reset to real scores
        case .escape, .char("q"): return
        default: break
        }
    }
}

private func renderCalculator(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], weighted: Bool, selected: Int) {
    print(CLEAR, terminator: "")
    let calc = GradeCalculator(items: items, groups: groupInfo, weighted: weighted)
    print("\(BOLD)What-if — \(course.courseCode)\(RESET)   projected \(GOLD)\(formatPercent(calc.currentGrade()))\(RESET)")
    print(String(repeating: "─", count: 53))
    for (i, item) in items.enumerated() {
        let marker = i == selected ? "\(GOLD)❯\(RESET)" : " "
        let effective = item.whatIfPoints ?? item.earnedPoints
        let pct = effective.map { item.pointsPossible > 0 ? $0 / item.pointsPossible * 100 : 0 }
        let tag = item.whatIfPoints != nil ? "\(GOLD)*\(RESET)" : " "
        print("\(marker)\(tag)\(item.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(formatPercent(pct))")
    }
    print("\n(↑/↓ select · Enter what-if · b blanket · p perfect · r reset · q exit)")
}

/// Reads a 0–100 percentage from a normal (cooked) terminal line; nil on invalid/empty.
private func promptPercent(_ message: String) -> Double? {
    print(CLEAR, terminator: "")
    print(message, terminator: "")
    guard let line = readLine(), let value = Double(line.trimmingCharacters(in: .whitespaces)) else { return nil }
    return max(0, min(100, value))
}
```

- [ ] **Step 2: Add the `calc` subcommand to `main.swift`**

Add `Calc.self` to the root `subcommands` array, then add this extension member:

```swift
extension Canvas {
    struct Calc: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Interactive what-if grade calculator.")

        @Argument(help: "Canvas course id.") var courseId: Int

        func run() async throws {
            let client = APIClient(token: try requireToken())
            do {
                let groups = try await client.assignmentGroups(courseId: courseId)
                let submissions = try await client.submissions(courseId: courseId)
                guard let course = try await client.courses().first(where: { $0.id == courseId }) else {
                    print("Course \(courseId) not found."); throw ExitCode(1)
                }
                let items = buildGradedItems(groups: groups, submissions: submissions)
                let groupInfo = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) })
                try await runCalculator(course: course, items: items, groupInfo: groupInfo, weighted: course.applyAssignmentGroupWeights)
            } catch let error as APIError {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
                throw ExitCode(1)
            }
        }
    }
}
```

Update the root configuration line to:

```swift
        subcommands: [Courses.self, Grades.self, Calc.self],
```

- [ ] **Step 3: Build and run the full unit suite**

Run: `swift build && swift test`
Expected: build succeeds; all unit tests PASS.

- [ ] **Step 4: Manual smoke test**

Run: `CANVAS_TOKEN=$CANVAS_TOKEN swift run CanvasCLISwift calc <id>`
Expected: assignment list with selection cursor and live "projected" grade at top; Enter prompts a what-if score and the projection updates with a `*` tag on the item; `b` applies a blanket score to ungraded items; `p` sets all remaining to 100%; `r` resets; `q` exits. Also confirm the same screen is reachable from the TUI via `c` on the course detail.

- [ ] **Step 5: Commit**

```bash
git add MyTool/TUI.swift MyTool/main.swift
git commit -m "feat: add interactive what-if calculator screen and calc subcommand"
```

---

## Self-Review Notes

**Spec coverage:** Command structure (Task 8, 11 + Task 9 default) · new endpoints (Task 7) · models (Task 2) · `GradedItem` join (Task 3) · unweighted/weighted math (Tasks 3–4) · what-if/blanket/perfect modes (Task 5) · composable modes (Task 11 mutates `working` cumulatively) · TUI three screens (Tasks 9–11) · `termios` raw mode + arrow sequences + restore on exit (Task 9) · ANSI clear/home/color (Tasks 9–11) · dashboard layout (Task 10) · error handling: missing token / 401 / network / no assignments (Tasks 7, 8, 11). Out-of-scope items are not implemented.

**Composability:** blanket-then-override works because `applyingBlanketToUngraded` only touches items where both `earnedPoints` and `whatIfPoints` are nil, so a later per-item what-if (or vice-versa via the cumulative `working` array) is preserved.

**Known manual-test dependencies:** Tasks 7–11 require a live `CANVAS_TOKEN`; their deliverables are build + manual smoke test, not unit tests. All pure logic (Tasks 2–6) is fully unit-tested.

**Risk flag — `termios` tuple indices:** `c_cc.5`/`c_cc.6` (VTIME/VMIN) rely on the Darwin C-tuple layout. If raw input misbehaves on the target machine, verify the indices in `/usr/include/sys/termios.h` during Task 9's smoke test before proceeding.
