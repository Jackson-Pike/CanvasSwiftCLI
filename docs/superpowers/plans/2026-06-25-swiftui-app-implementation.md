# CanvasApp SwiftUI macOS Menu Bar App — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the Phase 2 Canvas CLI into a native macOS menu bar SwiftUI app with a grade dashboard and robust what-if/target-grade calculator.

**Architecture:** Extract all business logic into a local `CanvasCore` Swift Package library; build a new `CanvasApp` SwiftUI executable target that imports it. The CLI (`MyTool/`) is retired and deleted. A `CanvasCoreTests` target re-targets the existing tests against `CanvasCore`.

**Tech Stack:** Swift 5.9 toolchain, SwiftPM, SwiftUI, `MenuBarExtra` (macOS 13+), Foundation `URLSession`, Security framework (Keychain), XCTest.

## Global Constraints

- Swift tools version stays `5.9`; platform floor bumps to `.macOS(.v13)` (required for `MenuBarExtra`).
- `Package.swift` is gitignored — every commit that changes it MUST use `git add -f Package.swift`.
- API base URL: `https://byuh.instructure.com/api/v1`.
- JSON decoding uses `JSONDecoder` with `keyDecodingStrategy = .convertFromSnakeCase` everywhere.
- Brand colors: Red `#ba0c2f` (186, 12, 47), Gold `#c69214` (198, 146, 20).
- BYUH default grade scale: A≥94, A-≥90, B+≥87, B≥84, B-≥80, C+≥77, C≥74, C-≥70, D+≥67, D≥64, D-≥60, F≥0.
- Per-course Canvas grading scheme overrides the default when present (`course.gradingScheme`).
- No background polling; no disk cache; token stored in macOS Keychain only.

---

## File Map

| File | Status | Responsibility |
|---|---|---|
| `Sources/CanvasCore/Models.swift` | Create (migrate) | All Codable structs + GradedItem + GradingSchemeEntry |
| `Sources/CanvasCore/APIClient.swift` | Create (migrate) | URLSession calls; updated `courses()` for grading scheme |
| `Sources/CanvasCore/GradeCalculator.swift` | Create (migrate+extend) | Grade math, drop rules, `solveForTarget`, `byuhDefaultScale` |
| `Tests/CanvasCoreTests/GradeCalculatorTests.swift` | Migrate | Re-targeted; updated imports + `rules: nil` fixes |
| `Tests/CanvasCoreTests/ModelsTests.swift` | Migrate | Re-targeted; add grading scheme decode test |
| `Tests/CanvasCoreTests/SolverTests.swift` | Create | Tests for `solveForTarget` and `letterGrade(for:scale:)` |
| `Package.swift` | Rewrite | CanvasCore library + CanvasApp executable + CanvasCoreTests |
| `MyTool/` | Delete | CLI retired |
| `Tests/CanvasCLISwiftTests/` | Delete | Replaced by CanvasCoreTests |
| `CanvasApp/App/CanvasApp.swift` | Create | `@main`, `MenuBarExtra`, root popover content |
| `CanvasApp/App/AppState.swift` | Create | `@ObservableObject` — token presence, navigation |
| `CanvasApp/App/KeychainHelper.swift` | Create | Save/load/delete token from Keychain |
| `CanvasApp/App/BrandColors.swift` | Create | `Color.byuhRed`, `Color.byuhGold`, `Color.letterGradeColor(_:)` |
| `CanvasApp/App/Info.plist` | Create | `LSUIElement=true` (hide dock icon) |
| `CanvasApp/Views/SettingsView.swift` | Create | Token entry; onboarding sheet |
| `CanvasApp/Views/CourseListView.swift` | Create | Course list with grade + letter |
| `CanvasApp/Views/CourseDetailView.swift` | Create | Group dashboard with progress bars |
| `CanvasApp/Views/CalculatorView.swift` | Create | What-If tab + Solve-For-Me tab |
| `CanvasApp/ViewModels/CoursesViewModel.swift` | Create | Fetch + hold courses + enrollments |
| `CanvasApp/ViewModels/CourseDetailViewModel.swift` | Create | Fetch + build GradeCalculator for a course |
| `CanvasApp/ViewModels/CalculatorViewModel.swift` | Create | What-if state, live grade, solver integration |

---

## Task 1: Restructure SPM — Migrate CanvasCore + Retire CLI

**Files:**
- Create: `Sources/CanvasCore/Models.swift`
- Create: `Sources/CanvasCore/APIClient.swift`
- Create: `Sources/CanvasCore/GradeCalculator.swift`
- Rewrite: `Package.swift`
- Create: `Tests/CanvasCoreTests/GradeCalculatorTests.swift`
- Create: `Tests/CanvasCoreTests/ModelsTests.swift`
- Delete: `MyTool/` (all files)
- Delete: `Tests/CanvasCLISwiftTests/` (all files)

**Interfaces:**
- Produces: `CanvasCore` library with all Phase 2 types and functions at existing signatures. Later tasks import this.

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p Sources/CanvasCore
mkdir -p Tests/CanvasCoreTests
mkdir -p CanvasApp/App CanvasApp/Views CanvasApp/ViewModels
```

- [ ] **Step 2: Rewrite Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanvasCLISwift",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CanvasCore", targets: ["CanvasCore"]),
        .executable(name: "CanvasApp", targets: ["CanvasApp"]),
    ],
    targets: [
        .target(
            name: "CanvasCore",
            path: "Sources/CanvasCore"
        ),
        .executableTarget(
            name: "CanvasApp",
            dependencies: ["CanvasCore"],
            path: "CanvasApp",
            resources: [.process("App/Info.plist")]
        ),
        .testTarget(
            name: "CanvasCoreTests",
            dependencies: ["CanvasCore"],
            path: "Tests/CanvasCoreTests"
        )
    ]
)
```

- [ ] **Step 3: Write Sources/CanvasCore/Models.swift** (direct copy of MyTool/Models.swift — no changes yet)

```swift
import Foundation

struct Course: Codable {
    let id: Int
    let name: String
    let courseCode: String
    let applyAssignmentGroupWeights: Bool
}

struct Enrollment: Codable {
    let grades: Grades?
}

struct Grades: Codable {
    let currentScore: Double?
    let currentGrade: String?
}

struct AssignmentGroupRules: Codable {
    let dropLowest: Int?
    let dropHighest: Int?
    let neverDrop: [Int]?
}

struct AssignmentGroup: Codable {
    let id: Int
    let name: String
    let groupWeight: Double
    let rules: AssignmentGroupRules?
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

- [ ] **Step 4: Write Sources/CanvasCore/APIClient.swift** (direct copy of MyTool/APIClient.swift)

```swift
import Foundation

enum APIError: Error, CustomStringConvertible {
    case missingToken
    case unauthorized
    case http(Int)
    case network(String)

    var description: String {
        switch self {
        case .missingToken:     return "CANVAS_TOKEN is not set."
        case .unauthorized:     return "Invalid token — update in Settings."
        case .http(let code):   return "Canvas API returned HTTP \(code)."
        case .network(let msg): return "Network error: \(msg)."
        }
    }
}

public struct APIClient {
    let token: String
    private let baseURL = "https://byuh.instructure.com/api/v1"

    public init(token: String) { self.token = token }

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
        } catch let error as APIError { throw error }
        catch { throw APIError.network(error.localizedDescription) }
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    public func courses() async throws -> [Course] {
        let data = try await get("/courses", query: [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "50")
        ])
        return try decoder().decode([Course].self, from: data)
    }

    public func enrollments(courseId: Int) async throws -> [Enrollment] {
        let data = try await get("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "user_id", value: "self"),
            URLQueryItem(name: "include[]", value: "grades")
        ])
        return try decoder().decode([Enrollment].self, from: data)
    }

    public func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
        let data = try await get("/courses/\(courseId)/assignment_groups", query: [
            URLQueryItem(name: "include[]", value: "assignments"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([AssignmentGroup].self, from: data)
    }

    public func submissions(courseId: Int) async throws -> [Submission] {
        let data = try await get("/courses/\(courseId)/students/submissions", query: [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([Submission].self, from: data)
    }
}
```

- [ ] **Step 5: Write Sources/CanvasCore/GradeCalculator.swift** (direct copy of MyTool/GradeCalculator.swift)

```swift
import Foundation

public struct GroupInfo {
    public let name: String
    public let weight: Double
    public var dropLowest: Int = 0
    public var dropHighest: Int = 0
    public var neverDrop: Set<Int> = []

    public init(name: String, weight: Double, dropLowest: Int = 0, dropHighest: Int = 0, neverDrop: Set<Int> = []) {
        self.name = name; self.weight = weight
        self.dropLowest = dropLowest; self.dropHighest = dropHighest; self.neverDrop = neverDrop
    }
}

public struct GroupResult {
    public let groupId: Int
    public let name: String
    public let weight: Double
    public let percent: Double?
}

public func buildGradedItems(groups: [AssignmentGroup], submissions: [Submission]) -> [GradedItem] {
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

public struct GradeCalculator {
    public let items: [GradedItem]
    public let groups: [Int: GroupInfo]
    public let weighted: Bool

    public init(items: [GradedItem], groups: [Int: GroupInfo], weighted: Bool) {
        self.items = items; self.groups = groups; self.weighted = weighted
    }

    private func effectivePoints(_ item: GradedItem) -> Double? {
        item.whatIfPoints ?? item.earnedPoints
    }

    public func currentGrade() -> Double? {
        weighted ? weightedGrade() : unweightedGrade()
    }

    private func unweightedGrade() -> Double? {
        let graded = items.filter { effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        let earned   = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    func groupPercent(_ groupId: Int) -> Double? {
        let info = groups[groupId]
        var graded = items.filter { $0.groupId == groupId && effectivePoints($0) != nil }
        guard !graded.isEmpty else { return nil }
        if let info, (info.dropLowest > 0 || info.dropHighest > 0) {
            let neverDrop = info.neverDrop
            var droppable = graded.filter { !neverDrop.contains($0.assignmentId) }
            let pinned    = graded.filter {  neverDrop.contains($0.assignmentId) }
            droppable.sort {
                let pA = $0.pointsPossible > 0 ? (effectivePoints($0) ?? 0) / $0.pointsPossible : 0
                let pB = $1.pointsPossible > 0 ? (effectivePoints($1) ?? 0) / $1.pointsPossible : 0
                return pA < pB
            }
            let dropL = min(info.dropLowest, droppable.count)
            let dropH = min(info.dropHighest, max(0, droppable.count - dropL))
            graded = pinned + Array(droppable.dropFirst(dropL).dropLast(dropH))
        }
        guard !graded.isEmpty else { return nil }
        let earned   = graded.reduce(0.0) { $0 + (effectivePoints($1) ?? 0) }
        let possible = graded.reduce(0.0) { $0 + $1.pointsPossible }
        guard possible > 0 else { return nil }
        return earned / possible * 100
    }

    private func weightedGrade() -> Double? {
        var weightedSum = 0.0; var activeWeight = 0.0
        for (groupId, info) in groups {
            guard let pct = groupPercent(groupId) else { continue }
            weightedSum += (pct / 100) * info.weight
            activeWeight += info.weight
        }
        guard activeWeight > 0 else { return nil }
        return weightedSum / activeWeight * 100
    }

    public func groupBreakdown() -> [GroupResult] {
        groups.map { groupId, info in
            GroupResult(groupId: groupId, name: info.name, weight: info.weight, percent: groupPercent(groupId))
        }
    }
}

public extension Array where Element == GradedItem {
    func applyingWhatIf(percent: Double, toAssignmentIds ids: Set<Int>) -> [GradedItem] {
        map { item in
            guard ids.contains(item.assignmentId) else { return item }
            var copy = item; copy.whatIfPoints = item.pointsPossible * percent / 100; return copy
        }
    }
    func applyingBlanketToUngraded(percent: Double) -> [GradedItem] {
        map { item in
            guard item.earnedPoints == nil && item.whatIfPoints == nil else { return item }
            var copy = item; copy.whatIfPoints = item.pointsPossible * percent / 100; return copy
        }
    }
    func applyingPerfectRemaining() -> [GradedItem] { applyingBlanketToUngraded(percent: 100) }
}
```

- [ ] **Step 6: Write Tests/CanvasCoreTests/GradeCalculatorTests.swift**

Update the import and add `rules: nil` to all `AssignmentGroup` initializer calls:

```swift
import XCTest
@testable import CanvasCore

final class GradeCalculatorTests: XCTestCase {
    private func item(_ id: Int, group: Int, possible: Double, earned: Double?) -> GradedItem {
        GradedItem(assignmentId: id, name: "A\(id)", groupId: group, pointsPossible: possible, earnedPoints: earned, whatIfPoints: nil)
    }

    func testBuildGradedItemsJoinsScores() {
        let groups = [AssignmentGroup(id: 1, name: "HW", groupWeight: 100, rules: nil,
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

    func testWeightedGradeNormalizesOverActiveGroups() {
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(2, group: 2, possible: 100, earned: 80),
                     item(3, group: 3, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 40),
            2: GroupInfo(name: "Quiz", weight: 20),
            3: GroupInfo(name: "Final", weight: 40)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
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

    func testApplyingWhatIfSetsSelectedItemsByPercent() {
        let items = [item(1, group: 1, possible: 50, earned: 25),
                     item(2, group: 1, possible: 50, earned: 50)]
        let result = items.applyingWhatIf(percent: 100, toAssignmentIds: [1])
        XCTAssertEqual(result[0].whatIfPoints, 50)
        XCTAssertNil(result[1].whatIfPoints)
    }

    func testBlanketOnlyAffectsUngraded() {
        let items = [item(1, group: 1, possible: 100, earned: 70),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = items.applyingBlanketToUngraded(percent: 80)
        XCTAssertNil(result[0].whatIfPoints)
        XCTAssertEqual(result[1].whatIfPoints, 80)
    }

    func testPerfectRemainingSetsUngradedTo100() {
        let items = [item(1, group: 1, possible: 40, earned: nil)]
        let result = items.applyingPerfectRemaining()
        XCTAssertEqual(result[0].whatIfPoints, 40)
    }
}
```

- [ ] **Step 7: Write Tests/CanvasCoreTests/ModelsTests.swift**

```swift
import XCTest
@testable import CanvasCore

final class ModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }

    func testCourseDecodesSnakeCase() throws {
        let json = """
        [{"id":1,"name":"Data Structures","course_code":"CS 246","apply_assignment_group_weights":true}]
        """.data(using: .utf8)!
        let courses = try decoder().decode([Course].self, from: json)
        XCTAssertEqual(courses.first?.courseCode, "CS 246")
        XCTAssertTrue(courses.first!.applyAssignmentGroupWeights)
    }

    func testAssignmentGroupDecodesNestedAssignments() throws {
        let json = """
        [{"id":10,"name":"Homework","group_weight":40.0,"rules":null,
          "assignments":[{"id":100,"name":"HW1","points_possible":50.0,"due_at":null,"assignment_group_id":10}]}]
        """.data(using: .utf8)!
        let groups = try decoder().decode([AssignmentGroup].self, from: json)
        XCTAssertEqual(groups.first?.groupWeight, 40.0)
        XCTAssertEqual(groups.first?.assignments.first?.assignmentGroupId, 10)
        XCTAssertNil(groups.first?.assignments.first?.dueAt)
    }

    func testSubmissionDecodesNullScore() throws {
        let json = """
        [{"assignment_id":100,"score":null,"workflow_state":"unsubmitted"}]
        """.data(using: .utf8)!
        let subs = try decoder().decode([Submission].self, from: json)
        XCTAssertNil(subs.first?.score)
        XCTAssertEqual(subs.first?.workflowState, "unsubmitted")
    }
}
```

- [ ] **Step 8: Delete retired CLI files**

```bash
rm -rf MyTool
rm -rf Tests/CanvasCLISwiftTests
```

- [ ] **Step 9: Run tests to verify migration**

```bash
git add -f Package.swift
swift test --target CanvasCoreTests 2>&1
```

Expected: all 10 tests PASS, 0 failures.

- [ ] **Step 10: Commit**

```bash
git add -f Package.swift
git add Sources/ Tests/CanvasCoreTests/
git commit -m "feat: extract CanvasCore library, retire CLI, re-target tests"
```

---

## Task 2: Grading Scale — Models Update + letterGrade Function

**Files:**
- Modify: `Sources/CanvasCore/Models.swift` — add `GradingSchemeEntry`, extend `Course`
- Modify: `Sources/CanvasCore/APIClient.swift` — update `courses()` query
- Modify: `Sources/CanvasCore/GradeCalculator.swift` — add `byuhDefaultScale`, `letterGrade(for:scale:)`, add `gradingScale` to `GradeCalculator`
- Modify: `Tests/CanvasCoreTests/ModelsTests.swift` — add grading scheme decode test
- Modify: `Tests/CanvasCoreTests/GradeCalculatorTests.swift` — add `letterGrade` test

**Interfaces:**
- Produces:
  - `GradingSchemeEntry: Codable { name: String; value: Double }` (value = 0–1 fraction from API)
  - `Course.gradingScheme: [GradingSchemeEntry]?`
  - `byuhDefaultScale: [(String, Double)]` (percent thresholds, descending)
  - `func letterGrade(for percent: Double, scale: [(String, Double)]) -> String`
  - `GradeCalculator(items:groups:weighted:gradingScale:)` — `gradingScale` defaults to `byuhDefaultScale`

- [ ] **Step 1: Write failing test for grading scheme decode**

Add to `Tests/CanvasCoreTests/ModelsTests.swift`:

```swift
func testCourseDecodesGradingScheme() throws {
    let json = """
    [{"id":1,"name":"CS 420","course_code":"CS 420","apply_assignment_group_weights":true,
      "grading_scheme":[{"name":"A","value":0.94},{"name":"A-","value":0.90},{"name":"F","value":0.0}]}]
    """.data(using: .utf8)!
    let courses = try decoder().decode([Course].self, from: json)
    XCTAssertEqual(courses.first?.gradingScheme?.first?.name, "A")
    XCTAssertEqual(courses.first?.gradingScheme?.first?.value, 0.94, accuracy: 0.001)
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
swift test --target CanvasCoreTests --filter testCourseDecodesGradingScheme 2>&1
```

Expected: compile error — `Course` has no `gradingScheme`.

- [ ] **Step 3: Add GradingSchemeEntry + update Course in Models.swift**

Replace the `Course` struct with:

```swift
public struct GradingSchemeEntry: Codable {
    public let name: String
    public let value: Double  // 0.0–1.0 lower-bound fraction
}

public struct Course: Codable {
    public let id: Int
    public let name: String
    public let courseCode: String
    public let applyAssignmentGroupWeights: Bool
    public let gradingScheme: [GradingSchemeEntry]?
}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
swift test --target CanvasCoreTests --filter testCourseDecodesGradingScheme 2>&1
```

Expected: PASS.

- [ ] **Step 5: Write failing tests for letterGrade(for:scale:)**

Add to `Tests/CanvasCoreTests/GradeCalculatorTests.swift`:

```swift
func testLetterGradeByuhScale() {
    let scale = byuhDefaultScale
    XCTAssertEqual(letterGrade(for: 100.0, scale: scale), "A")
    XCTAssertEqual(letterGrade(for: 94.0,  scale: scale), "A")
    XCTAssertEqual(letterGrade(for: 93.9,  scale: scale), "A-")
    XCTAssertEqual(letterGrade(for: 90.0,  scale: scale), "A-")
    XCTAssertEqual(letterGrade(for: 84.0,  scale: scale), "B")
    XCTAssertEqual(letterGrade(for: 74.0,  scale: scale), "C")
    XCTAssertEqual(letterGrade(for: 59.9,  scale: scale), "F")
    XCTAssertEqual(letterGrade(for: 0.0,   scale: scale), "F")
}

func testLetterGradeCustomScale() {
    let custom: [(String, Double)] = [("A", 90.0), ("B", 80.0), ("F", 0.0)]
    XCTAssertEqual(letterGrade(for: 89.9, scale: custom), "B")
    XCTAssertEqual(letterGrade(for: 90.0, scale: custom), "A")
}
```

- [ ] **Step 6: Run tests — expect FAIL**

```bash
swift test --target CanvasCoreTests --filter testLetterGrade 2>&1
```

Expected: compile error — `byuhDefaultScale` and `letterGrade(for:scale:)` not defined.

- [ ] **Step 7: Add byuhDefaultScale + letterGrade + gradingScale to GradeCalculator.swift**

At the top of `Sources/CanvasCore/GradeCalculator.swift`, before `GroupInfo`, add:

```swift
public let byuhDefaultScale: [(String, Double)] = [
    ("A",  94.0), ("A-", 90.0),
    ("B+", 87.0), ("B",  84.0), ("B-", 80.0),
    ("C+", 77.0), ("C",  74.0), ("C-", 70.0),
    ("D+", 67.0), ("D",  64.0), ("D-", 60.0),
    ("F",   0.0)
]

public func letterGrade(for percent: Double, scale: [(String, Double)]) -> String {
    for (letter, threshold) in scale {
        if percent >= threshold { return letter }
    }
    return "F"
}
```

Update `GradeCalculator` to accept `gradingScale`:

```swift
public struct GradeCalculator {
    public let items: [GradedItem]
    public let groups: [Int: GroupInfo]
    public let weighted: Bool
    public let gradingScale: [(String, Double)]

    public init(items: [GradedItem], groups: [Int: GroupInfo], weighted: Bool,
                gradingScale: [(String, Double)] = byuhDefaultScale) {
        self.items = items; self.groups = groups
        self.weighted = weighted; self.gradingScale = gradingScale
    }

    public func letterGradeForPercent(_ percent: Double) -> String {
        letterGrade(for: percent, scale: gradingScale)
    }
    // ... keep all existing methods unchanged
}
```

- [ ] **Step 8: Update APIClient.courses() to include grading scheme**

In `Sources/CanvasCore/APIClient.swift`, replace the `courses()` method:

```swift
public func courses() async throws -> [Course] {
    let data = try await get("/courses", query: [
        URLQueryItem(name: "enrollment_state", value: "active"),
        URLQueryItem(name: "per_page", value: "50"),
        URLQueryItem(name: "include[]", value: "grading_scheme")
    ])
    return try decoder().decode([Course].self, from: data)
}
```

- [ ] **Step 9: Run all tests — expect PASS**

```bash
swift test --target CanvasCoreTests 2>&1
```

Expected: all tests PASS.

- [ ] **Step 10: Commit**

```bash
git add -f Package.swift
git add Sources/CanvasCore/ Tests/CanvasCoreTests/
git commit -m "feat: add grading scheme models, letterGrade(for:scale:), gradingScale in GradeCalculator"
```

---

## Task 3: Target Grade Solver

**Files:**
- Modify: `Sources/CanvasCore/GradeCalculator.swift` — add `SolveResult`, `solveForTarget`
- Create: `Tests/CanvasCoreTests/SolverTests.swift`

**Interfaces:**
- Produces:
  - `enum SolveResult: Equatable { case alreadyAchieved; case needed(percent: Double); case impossible(maxPossible: Double) }`
  - `GradeCalculator.solveForTarget(targetPercent: Double, solveAssignmentIds: Set<Int>) -> SolveResult`

- [ ] **Step 1: Write failing tests**

Create `Tests/CanvasCoreTests/SolverTests.swift`:

```swift
import XCTest
@testable import CanvasCore

final class SolverTests: XCTestCase {
    private func item(_ id: Int, group: Int, possible: Double, earned: Double?) -> GradedItem {
        GradedItem(assignmentId: id, name: "A\(id)", groupId: group,
                   pointsPossible: possible, earnedPoints: earned, whatIfPoints: nil)
    }

    private func calcUnweighted(_ items: [GradedItem]) -> GradeCalculator {
        GradeCalculator(items: items, groups: [1: GroupInfo(name: "HW", weight: 100)], weighted: false)
    }

    func testAlreadyAchievedUnweighted() {
        // 90/100 = 90% — target 85%
        let items = [item(1, group: 1, possible: 100, earned: 90)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 85, solveAssignmentIds: [99])
        XCTAssertEqual(result, .alreadyAchieved)
    }

    func testNeededUnweighted() {
        // item 1: 60/100, item 2 ungraded 100pts — need 90% overall
        // require: (60 + x) / 200 >= 0.90 → x >= 120 → 120% impossible on 100pts
        // actually: need (60 + x)/200 = 0.90 → x = 120, impossible since max is 100
        // Let's use a case that's achievable: target 70%
        // (60 + x)/200 = 0.70 → x = 80 → 80%
        let items = [item(1, group: 1, possible: 100, earned: 60),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 70, solveAssignmentIds: [2])
        guard case .needed(let pct) = result else { XCTFail("Expected .needed, got \(result)"); return }
        XCTAssertEqual(pct, 80.0, accuracy: 0.2)
    }

    func testImpossibleUnweighted() {
        // item 1: 60/100, item 2 ungraded 100pts — target 90% needs 120pts on item2
        let items = [item(1, group: 1, possible: 100, earned: 60),
                     item(2, group: 1, possible: 100, earned: nil)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 90, solveAssignmentIds: [2])
        guard case .impossible(let max) = result else { XCTFail("Expected .impossible, got \(result)"); return }
        XCTAssertEqual(max, 80.0, accuracy: 0.2)  // (60+100)/200 = 80%
    }

    func testNeededWeighted() {
        // HW (40%): 90%. Final (60%): ungraded. Target: 80%
        // 0.9*40 + x*60 = 80*100 / 100 → 36 + 60x = 80 → 60x = 44 → x = 73.33%
        let items = [item(1, group: 1, possible: 100, earned: 90),
                     item(2, group: 2, possible: 100, earned: nil)]
        let groups: [Int: GroupInfo] = [
            1: GroupInfo(name: "HW", weight: 40),
            2: GroupInfo(name: "Final", weight: 60)
        ]
        let calc = GradeCalculator(items: items, groups: groups, weighted: true)
        let result = calc.solveForTarget(targetPercent: 80, solveAssignmentIds: [2])
        guard case .needed(let pct) = result else { XCTFail("Expected .needed, got \(result)"); return }
        XCTAssertEqual(pct, 73.33, accuracy: 0.5)
    }

    func testSolveAcrossMultipleAssignments() {
        // item1 graded 70/100, items 2 and 3 ungraded 50pts each — target 80%
        // need uniform X on items 2 and 3: (70 + 50x/100 + 50x/100)/200 = 0.80
        // (70 + x)/200 = 0.80 where x = points from both = 100x/100
        // 70 + 0.5x + 0.5x = 160 → 70 + x = 160 → x = 90% on each
        let items = [item(1, group: 1, possible: 100, earned: 70),
                     item(2, group: 1, possible: 50,  earned: nil),
                     item(3, group: 1, possible: 50,  earned: nil)]
        let result = calcUnweighted(items).solveForTarget(targetPercent: 80, solveAssignmentIds: [2, 3])
        guard case .needed(let pct) = result else { XCTFail("Expected .needed, got \(result)"); return }
        XCTAssertEqual(pct, 90.0, accuracy: 0.5)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL**

```bash
swift test --target CanvasCoreTests --filter SolverTests 2>&1
```

Expected: compile error — `SolveResult` and `solveForTarget` not defined.

- [ ] **Step 3: Add SolveResult enum and solveForTarget to GradeCalculator.swift**

Append to `Sources/CanvasCore/GradeCalculator.swift`:

```swift
public enum SolveResult: Equatable {
    case alreadyAchieved
    case needed(percent: Double)
    case impossible(maxPossible: Double)

    public static func == (lhs: SolveResult, rhs: SolveResult) -> Bool {
        switch (lhs, rhs) {
        case (.alreadyAchieved, .alreadyAchieved): return true
        case (.needed(let a), .needed(let b)):       return abs(a - b) < 0.5
        case (.impossible(let a), .impossible(let b)): return abs(a - b) < 0.5
        default: return false
        }
    }
}

public extension GradeCalculator {
    func solveForTarget(targetPercent: Double, solveAssignmentIds: Set<Int>) -> SolveResult {
        // 1. Already achieved?
        if let current = currentGrade(), current >= targetPercent {
            return .alreadyAchieved
        }
        // 2. Check if achievable (apply 100% to all solve assignments)
        let maxItems = items.applyingWhatIf(percent: 100, toAssignmentIds: solveAssignmentIds)
        let maxCalc  = GradeCalculator(items: maxItems, groups: groups, weighted: weighted, gradingScale: gradingScale)
        guard let maxGrade = maxCalc.currentGrade(), maxGrade >= targetPercent else {
            return .impossible(maxPossible: maxCalc.currentGrade() ?? 0)
        }
        // 3. Binary search for the uniform % needed
        var lo = 0.0, hi = 100.0
        while hi - lo > 0.05 {
            let mid = (lo + hi) / 2
            let testItems = items.applyingWhatIf(percent: mid, toAssignmentIds: solveAssignmentIds)
            let testCalc  = GradeCalculator(items: testItems, groups: groups, weighted: weighted, gradingScale: gradingScale)
            if let grade = testCalc.currentGrade(), grade >= targetPercent {
                hi = mid
            } else {
                lo = mid
            }
        }
        return .needed(percent: hi)
    }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
swift test --target CanvasCoreTests 2>&1
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/GradeCalculator.swift Tests/CanvasCoreTests/SolverTests.swift
git commit -m "feat: add SolveResult enum and solveForTarget binary-search solver"
```

---

## Task 4: App Shell — MenuBarExtra + Keychain + Brand Colors

**Files:**
- Create: `CanvasApp/App/Info.plist`
- Create: `CanvasApp/App/KeychainHelper.swift`
- Create: `CanvasApp/App/BrandColors.swift`
- Create: `CanvasApp/App/AppState.swift`
- Create: `CanvasApp/App/CanvasApp.swift`

**Interfaces:**
- Produces:
  - `KeychainHelper.save(token:)`, `.load() -> String?`, `.delete()`
  - `Color.byuhRed`, `Color.byuhGold`, `Color.letterGradeColor(_:) -> Color`
  - `AppState: ObservableObject` with `token: String?`, `hasToken: Bool`, `saveToken(_:)`, `makeClient() -> APIClient?`
  - `@main CanvasApp: App` with `MenuBarExtra` popover

- [ ] **Step 1: Create Info.plist**

Create `CanvasApp/App/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleName</key>
    <string>Canvas</string>
    <key>CFBundleIdentifier</key>
    <string>com.byuh.CanvasApp</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
```

- [ ] **Step 2: Create KeychainHelper.swift**

Create `CanvasApp/App/KeychainHelper.swift`:

```swift
import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.byuh.CanvasApp"
    private static let account = "canvas_token"

    static func save(token: String) {
        let data = Data(token.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

- [ ] **Step 3: Create BrandColors.swift**

Create `CanvasApp/App/BrandColors.swift`:

```swift
import SwiftUI

extension Color {
    static let byuhRed  = Color(red: 186/255, green: 12/255,  blue: 47/255)
    static let byuhGold = Color(red: 198/255, green: 146/255, blue: 20/255)

    static func letterGradeColor(_ letter: String) -> Color {
        switch letter.prefix(1) {
        case "A": return Color(red: 52/255, green: 168/255, blue: 83/255)   // green
        case "B": return Color(red: 66/255, green: 133/255, blue: 244/255)  // blue
        case "C": return Color(red: 251/255, green: 188/255, blue: 4/255)   // yellow
        default:  return .byuhRed
        }
    }
}
```

- [ ] **Step 4: Create AppState.swift**

Create `CanvasApp/App/AppState.swift`:

```swift
import Foundation
import CanvasCore

@MainActor
final class AppState: ObservableObject {
    @Published var token: String? = KeychainHelper.load()
    @Published var showingSettings = false

    var hasToken: Bool { !(token ?? "").isEmpty }

    func saveToken(_ newToken: String) {
        let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(token: trimmed)
        token = trimmed
    }

    func makeClient() -> APIClient? {
        guard let token, !token.isEmpty else { return nil }
        return APIClient(token: token)
    }
}
```

- [ ] **Step 5: Create CanvasApp.swift**

Create `CanvasApp/App/CanvasApp.swift`:

```swift
import SwiftUI
import CanvasCore

@main
struct CanvasApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Canvas", systemImage: "graduationcap.fill") {
            PopoverContent()
                .environmentObject(appState)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PopoverContent: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if !appState.hasToken {
            SettingsView(isOnboarding: true)
                .environmentObject(appState)
        } else {
            NavigationStack {
                CourseListView()
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { appState.showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $appState.showingSettings) {
                SettingsView(isOnboarding: false)
                    .environmentObject(appState)
            }
        }
    }
}
```

- [ ] **Step 6: Create stub views so the app compiles**

Create `CanvasApp/Views/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    let isOnboarding: Bool
    @EnvironmentObject var appState: AppState
    @State private var tokenInput = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text(isOnboarding ? "Welcome to Canvas" : "Settings")
                .font(.headline)
            Text("Enter your Canvas API token")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            SecureField("Canvas API Token", text: $tokenInput)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                appState.saveToken(tokenInput)
                if !isOnboarding { dismiss() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.byuhRed)
            .disabled(tokenInput.isEmpty)
        }
        .padding(24)
        .frame(width: 340)
    }
}
```

Create `CanvasApp/Views/CourseListView.swift`:

```swift
import SwiftUI

struct CourseListView: View {
    var body: some View { Text("Course List — coming in Task 6") }
}
```

Create `CanvasApp/Views/CourseDetailView.swift`:

```swift
import SwiftUI
import CanvasCore

struct CourseDetailView: View {
    let course: Course
    var body: some View { Text("Detail — coming in Task 7") }
}
```

Create `CanvasApp/Views/CalculatorView.swift`:

```swift
import SwiftUI
import CanvasCore

struct CalculatorView: View {
    let course: Course
    let items: [GradedItem]
    let groupInfo: [Int: GroupInfo]
    let gradingScale: [(String, Double)]
    var body: some View { Text("Calculator — coming in Task 8") }
}
```

- [ ] **Step 7: Build to verify compilation**

```bash
git add -f Package.swift
swift build --target CanvasApp 2>&1
```

Expected: Build succeeded. The menu bar app binary is in `.build/debug/CanvasApp`.

- [ ] **Step 8: Smoke-test the app**

```bash
.build/debug/CanvasApp &
```

Expected: A graduation cap icon appears in the macOS menu bar. Clicking it opens a 380×520 popover showing the token entry form (since no token is in Keychain yet). Press Ctrl-C to stop.

- [ ] **Step 9: Commit**

```bash
git add CanvasApp/
git commit -m "feat: app shell — MenuBarExtra popover, Keychain token, brand colors"
```

---

## Task 5: Settings + Onboarding (complete implementation)

**Files:**
- Modify: `CanvasApp/Views/SettingsView.swift` — already complete from Task 4 stub

The stub written in Task 4 is production-quality. No additional implementation needed for Settings. This task verifies the full flow.

- [ ] **Step 1: Run the app and test token entry**

```bash
swift build --target CanvasApp && .build/debug/CanvasApp &
```

1. Click the graduation cap in menu bar — token entry sheet appears (onboarding mode).
2. Type a test token (e.g. `test123`) and click Save.
3. Close and reopen the popover — the Course List stub shows instead of onboarding (token persisted).
4. Click the gear icon — settings sheet opens showing an empty field (token hidden by SecureField).
5. Enter a new token and Save — token updates in Keychain.

Kill the app: `pkill CanvasApp`

- [ ] **Step 2: Clean up test token**

```bash
# The app stores the test token in Keychain. Clear it so tests start clean.
# Run the app, open settings, clear the field — or use:
security delete-generic-password -s "com.byuh.CanvasApp" 2>/dev/null; echo "cleared"
```

- [ ] **Step 3: Commit (no code changes — verification only)**

```bash
git commit --allow-empty -m "chore: verify settings + onboarding flow"
```

---

## Task 6: CoursesViewModel + CourseListView

**Files:**
- Create: `CanvasApp/ViewModels/CoursesViewModel.swift`
- Modify: `CanvasApp/Views/CourseListView.swift`

**Interfaces:**
- Produces: `CoursesViewModel` with `courses`, `enrollments`, `isLoading`, `error`, `fetch(client:)`

- [ ] **Step 1: Create CoursesViewModel.swift**

Create `CanvasApp/ViewModels/CoursesViewModel.swift`:

```swift
import Foundation
import CanvasCore

@MainActor
final class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var enrollments: [Int: Enrollment] = [:]
    @Published var isLoading = false
    @Published var error: String?

    func fetch(client: APIClient) async {
        isLoading = true
        error = nil
        do {
            let fetched = try await client.courses()
            courses = fetched
            await withTaskGroup(of: (Int, Enrollment?).self) { group in
                for course in fetched {
                    group.addTask {
                        let e = try? await client.enrollments(courseId: course.id).first
                        return (course.id, e)
                    }
                }
                for await (id, enrollment) in group {
                    if let enrollment { self.enrollments[id] = enrollment }
                }
            }
        } catch let e as APIError {
            error = e.description
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func currentScore(for courseId: Int) -> Double? {
        enrollments[courseId]?.grades?.currentScore
    }
}
```

- [ ] **Step 2: Implement CourseListView.swift**

Replace `CanvasApp/Views/CourseListView.swift`:

```swift
import SwiftUI
import CanvasCore

struct CourseListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = CoursesViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading courses…").padding()
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Retry") { Task { await refresh() } }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else if vm.courses.isEmpty {
                Text("No active courses found.")
                    .foregroundStyle(.secondary).padding()
            } else {
                List(vm.courses, id: \.id) { course in
                    NavigationLink(destination: CourseDetailView(course: course)) {
                        CourseRowView(course: course, score: vm.currentScore(for: course.id),
                                      gradingScale: course.gradingScheme.map { $0.map { ($0.name, $0.value * 100) } } ?? byuhDefaultScale)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Canvas")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        guard let client = appState.makeClient() else { return }
        await vm.fetch(client: client)
    }
}

struct CourseRowView: View {
    let course: Course
    let score: Double?
    let gradingScale: [(String, Double)]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.courseCode)
                    .font(.headline).foregroundStyle(Color.byuhRed)
                Text(course.name)
                    .font(.subheadline).foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            if let score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1f%%", score))
                        .font(.headline).foregroundStyle(Color.byuhGold)
                    let letter = letterGrade(for: score, scale: gradingScale)
                    Text(letter)
                        .font(.subheadline)
                        .foregroundStyle(Color.letterGradeColor(letter))
                }
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Build and smoke-test**

```bash
swift build --target CanvasApp 2>&1
```

Expected: Build succeeded.

```bash
export CANVAS_TOKEN="your_real_token_here"
# Save token via the app UI, then:
.build/debug/CanvasApp &
```

Open the menu bar icon. Verify:
- Loading spinner appears briefly
- Course list populates with course codes in red, grades in gold, letter grades

Kill: `pkill CanvasApp`

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/ViewModels/CoursesViewModel.swift CanvasApp/Views/CourseListView.swift
git commit -m "feat: course list view with grade + letter per course"
```

---

## Task 7: CourseDetailViewModel + CourseDetailView

**Files:**
- Create: `CanvasApp/ViewModels/CourseDetailViewModel.swift`
- Modify: `CanvasApp/Views/CourseDetailView.swift`

**Interfaces:**
- Produces: `CourseDetailViewModel` with `calculator: GradeCalculator?`, `groupInfo`, `gradingScale`, `fetch(client:)`

- [ ] **Step 1: Create CourseDetailViewModel.swift**

Create `CanvasApp/ViewModels/CourseDetailViewModel.swift`:

```swift
import Foundation
import CanvasCore

@MainActor
final class CourseDetailViewModel: ObservableObject {
    let course: Course
    @Published var calculator: GradeCalculator?
    @Published var groupInfo: [Int: GroupInfo] = [:]
    @Published var allItems: [GradedItem] = []
    @Published var isLoading = false
    @Published var error: String?

    init(course: Course) { self.course = course }

    var gradingScale: [(String, Double)] {
        course.gradingScheme.map { $0.map { ($0.name, $0.value * 100) } } ?? byuhDefaultScale
    }

    func fetch(client: APIClient) async {
        isLoading = true; error = nil
        do {
            async let groups = client.assignmentGroups(courseId: course.id)
            async let subs   = client.submissions(courseId: course.id)
            let (fetchedGroups, fetchedSubs) = try await (groups, subs)

            let info = Dictionary(uniqueKeysWithValues: fetchedGroups.map { g in
                (g.id, GroupInfo(name: g.name, weight: g.groupWeight,
                                 dropLowest:  g.rules?.dropLowest  ?? 0,
                                 dropHighest: g.rules?.dropHighest ?? 0,
                                 neverDrop:   Set(g.rules?.neverDrop ?? [])))
            })
            groupInfo = info
            let items = buildGradedItems(groups: fetchedGroups, submissions: fetchedSubs)
            allItems  = items
            calculator = GradeCalculator(items: items, groups: info,
                                          weighted: course.applyAssignmentGroupWeights,
                                          gradingScale: gradingScale)
        } catch let e as APIError { error = e.description }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}
```

- [ ] **Step 2: Implement CourseDetailView.swift**

Replace `CanvasApp/Views/CourseDetailView.swift`:

```swift
import SwiftUI
import CanvasCore

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var appState: AppState
    @StateObject private var vm: CourseDetailViewModel

    init(course: Course) {
        self.course = course
        _vm = StateObject(wrappedValue: CourseDetailViewModel(course: course))
    }

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading grades…").padding()
            } else if let error = vm.error {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Retry") { Task { await refresh() } }.buttonStyle(.bordered)
                }
                .padding()
            } else if let calc = vm.calculator {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GradeDashboardView(calc: calc, gradingScale: vm.gradingScale)
                        Divider().padding(.vertical, 8)
                        NavigationLink(destination: CalculatorView(
                            course: course, items: vm.allItems,
                            groupInfo: vm.groupInfo, gradingScale: vm.gradingScale)) {
                            Label("Open Calculator", systemImage: "function")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
                    }
                }
            } else {
                Text("No grade data available.").foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle(course.courseCode)
        .task { await refresh() }
    }

    private func refresh() async {
        guard let client = appState.makeClient() else { return }
        await vm.fetch(client: client)
    }
}

struct GradeDashboardView: View {
    let calc: GradeCalculator
    let gradingScale: [(String, Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let breakdown = calc.groupBreakdown().sorted { $0.weight > $1.weight }
            ForEach(breakdown, id: \.groupId) { result in
                GroupRowView(result: result, gradingScale: gradingScale)
            }
            Divider()
            HStack {
                Text("Overall").font(.headline)
                Spacer()
                if let overall = calc.currentGrade() {
                    Text(String(format: "%.1f%%", overall))
                        .font(.headline).foregroundStyle(Color.byuhGold)
                    let letter = letterGrade(for: overall, scale: gradingScale)
                    Text(letter).font(.headline)
                        .foregroundStyle(Color.letterGradeColor(letter))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

struct GroupRowView: View {
    let result: GroupResult
    let gradingScale: [(String, Double)]

    var body: some View {
        HStack(spacing: 8) {
            Text(result.name)
                .font(.subheadline).lineLimit(1)
                .frame(width: 120, alignment: .leading)
            Text(String(format: "(%.0f%%)", result.weight))
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 40)
            if let pct = result.percent {
                Text(String(format: "%.1f%%", pct))
                    .font(.subheadline).foregroundStyle(Color.byuhGold)
                    .frame(width: 52, alignment: .trailing)
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(Color.byuhRed)
                    .frame(width: 80)
                let letter = letterGrade(for: pct, scale: gradingScale)
                Text(letter).font(.caption.bold())
                    .foregroundStyle(Color.letterGradeColor(letter))
                    .frame(width: 24)
            } else {
                Text("not graded")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}
```

- [ ] **Step 3: Build and smoke-test**

```bash
swift build --target CanvasApp 2>&1
```

Expected: Build succeeded.

Run the app, navigate to a course. Verify:
- Progress bars show in red
- Grade percentages in gold
- Letter grades colored by tier
- "Open Calculator" button visible at bottom

Kill: `pkill CanvasApp`

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/ViewModels/CourseDetailViewModel.swift CanvasApp/Views/CourseDetailView.swift
git commit -m "feat: course detail grade dashboard with group breakdown and progress bars"
```

---

## Task 8: CalculatorViewModel + CalculatorView — What-If Tab

**Files:**
- Create: `CanvasApp/ViewModels/CalculatorViewModel.swift`
- Modify: `CanvasApp/Views/CalculatorView.swift`

**Interfaces:**
- Produces:
  - `CalculatorViewModel.WhatIfEntry` struct with `isActive`, `inputText`, `inputMode`, `resolvedPercent(possiblePoints:) -> Double?`
  - `CalculatorViewModel.effectiveItems: [GradedItem]`
  - `CalculatorViewModel.liveGrade: Double?`
  - `CalculatorViewModel.liveBreakdown: [GroupResult]`

- [ ] **Step 1: Create CalculatorViewModel.swift**

Create `CanvasApp/ViewModels/CalculatorViewModel.swift`:

```swift
import Foundation
import CanvasCore

@MainActor
final class CalculatorViewModel: ObservableObject {
    let course: Course
    let baseItems: [GradedItem]
    let groupInfo: [Int: GroupInfo]
    let gradingScale: [(String, Double)]

    @Published var whatIfEntries: [Int: WhatIfEntry] = [:]

    // Solve For Me
    @Published var targetMode: TargetMode = .letter
    @Published var targetLetter: String = "A"
    @Published var targetPercentInput: String = "90"
    @Published var solveScope: SolveScope = .single
    @Published var solveSingleId: Int?
    @Published var solveMultiIds: Set<Int> = []

    enum TargetMode { case letter, percent }
    enum SolveScope  { case single, spread }

    struct WhatIfEntry {
        var isActive: Bool = false
        var inputText: String = ""
        var inputMode: InputMode = .percent

        enum InputMode { case points, percent }

        func resolvedPercent(possiblePoints: Double) -> Double? {
            guard isActive, !inputText.isEmpty else { return nil }
            switch inputMode {
            case .percent:
                let cleaned = inputText.trimmingCharacters(in: .init(charactersIn: "%"))
                return Double(cleaned)
            case .points:
                guard let pts = Double(inputText), possiblePoints > 0 else { return nil }
                return pts / possiblePoints * 100
            }
        }

        func resolvedPoints(possiblePoints: Double) -> Double? {
            guard let pct = resolvedPercent(possiblePoints: possiblePoints) else { return nil }
            return possiblePoints * pct / 100
        }
    }

    init(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], gradingScale: [(String, Double)]) {
        self.course = course; self.baseItems = items
        self.groupInfo = groupInfo; self.gradingScale = gradingScale
        if let first = items.filter({ $0.earnedPoints == nil }).first {
            solveSingleId = first.assignmentId
        }
    }

    var effectiveItems: [GradedItem] {
        baseItems.map { item in
            guard let entry = whatIfEntries[item.assignmentId],
                  let pct = entry.resolvedPercent(possiblePoints: item.pointsPossible) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * pct / 100
            return copy
        }
    }

    var liveCalculator: GradeCalculator {
        GradeCalculator(items: effectiveItems, groups: groupInfo,
                        weighted: course.applyAssignmentGroupWeights, gradingScale: gradingScale)
    }

    var liveGrade: Double? { liveCalculator.currentGrade() }
    var liveBreakdown: [GroupResult] { liveCalculator.groupBreakdown().sorted { $0.weight > $1.weight } }

    var targetPercentValue: Double {
        switch targetMode {
        case .percent: return Double(targetPercentInput) ?? 90.0
        case .letter:  return gradingScale.first(where: { $0.0 == targetLetter })?.1 ?? 90.0
        }
    }

    var solveAssignmentIds: Set<Int> {
        switch solveScope {
        case .single:  return solveSingleId.map { [$0] } ?? []
        case .spread:  return solveMultiIds
        }
    }

    var solveResult: SolveResult? {
        guard !solveAssignmentIds.isEmpty else { return nil }
        return liveCalculator.solveForTarget(targetPercent: targetPercentValue,
                                              solveAssignmentIds: solveAssignmentIds)
    }

    var ungradedItems: [GradedItem] {
        baseItems.filter { $0.earnedPoints == nil }
    }

    func gradeLetter(for item: GradedItem) -> String? {
        guard let earned = item.earnedPoints, item.pointsPossible > 0 else { return nil }
        return letterGrade(for: earned / item.pointsPossible * 100, scale: gradingScale)
    }
}
```

- [ ] **Step 2: Implement CalculatorView.swift — What-If tab**

Replace `CanvasApp/Views/CalculatorView.swift`:

```swift
import SwiftUI
import CanvasCore

struct CalculatorView: View {
    @StateObject private var vm: CalculatorViewModel
    @State private var selectedTab = 0

    init(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], gradingScale: [(String, Double)]) {
        _vm = StateObject(wrappedValue: CalculatorViewModel(
            course: course, items: items, groupInfo: groupInfo, gradingScale: gradingScale))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Live grade header
            HStack {
                Text("Live Grade:")
                Spacer()
                if let grade = vm.liveGrade {
                    Text(String(format: "%.1f%%", grade))
                        .font(.title2.bold()).foregroundStyle(Color.byuhGold)
                    Text(letterGrade(for: grade, scale: vm.gradingScale))
                        .font(.title2.bold())
                        .foregroundStyle(Color.letterGradeColor(letterGrade(for: grade, scale: vm.gradingScale)))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Picker("Mode", selection: $selectedTab) {
                Text("What-If").tag(0)
                Text("Solve For Me").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                WhatIfTabView(vm: vm)
            } else {
                SolveForMeTabView(vm: vm)
            }
        }
        .navigationTitle("Calculator")
    }
}

struct WhatIfTabView: View {
    @ObservedObject var vm: CalculatorViewModel

    var body: some View {
        List(vm.baseItems, id: \.assignmentId) { item in
            WhatIfRowView(item: item, vm: vm)
        }
        .listStyle(.plain)
    }
}

struct WhatIfRowView: View {
    let item: GradedItem
    @ObservedObject var vm: CalculatorViewModel
    @FocusState private var focused: Bool

    private var binding: Binding<CalculatorViewModel.WhatIfEntry> {
        Binding(
            get: { vm.whatIfEntries[item.assignmentId] ?? CalculatorViewModel.WhatIfEntry() },
            set: { vm.whatIfEntries[item.assignmentId] = $0 }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("", isOn: binding.isActive)
                    .labelsHidden()
                Text(item.name).lineLimit(1)
                Spacer()
                // Original score
                if let earned = item.earnedPoints {
                    Text(String(format: "%.0f/%.0f", earned, item.pointsPossible))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(String(format: "—/%.0f", item.pointsPossible))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if binding.isActive.wrappedValue {
                HStack(spacing: 8) {
                    TextField("Score", text: binding.inputText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .focused($focused)
                    Picker("", selection: binding.inputMode) {
                        Text("%").tag(CalculatorViewModel.WhatIfEntry.InputMode.percent)
                        Text("pts").tag(CalculatorViewModel.WhatIfEntry.InputMode.points)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    Spacer()
                    if let pct = binding.wrappedValue.resolvedPercent(possiblePoints: item.pointsPossible) {
                        let letter = letterGrade(for: pct, scale: vm.gradingScale)
                        Text(letter).font(.caption.bold())
                            .foregroundStyle(Color.letterGradeColor(letter))
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 2)
        .onAppear { focused = false }
    }
}

// Placeholder — implemented in Task 9
struct SolveForMeTabView: View {
    @ObservedObject var vm: CalculatorViewModel
    var body: some View { Text("Solve For Me — coming in Task 9").padding() }
}
```

- [ ] **Step 3: Build and smoke-test**

```bash
swift build --target CanvasApp 2>&1
```

Expected: Build succeeded.

Run the app, navigate to a course, open Calculator. Verify:
- Live grade header shows current grade in gold
- Assignments list shows with toggle + original score
- Toggling an assignment reveals the score input (% / pts picker)
- Typing a score updates the Live Grade in real-time

Kill: `pkill CanvasApp`

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/ViewModels/CalculatorViewModel.swift CanvasApp/Views/CalculatorView.swift
git commit -m "feat: what-if calculator with live grade recalculation, points/percent input"
```

---

## Task 9: Solve For Me Tab

**Files:**
- Modify: `CanvasApp/Views/CalculatorView.swift` — replace `SolveForMeTabView` placeholder

**Interfaces:**
- Consumes: `CalculatorViewModel.solveResult: SolveResult?`, `vm.ungradedItems`, `vm.targetMode`, `vm.targetLetter`, `vm.targetPercentInput`, `vm.solveScope`, `vm.solveSingleId`, `vm.solveMultiIds`, `vm.solveAssignmentIds`

- [ ] **Step 1: Replace SolveForMeTabView with full implementation**

In `CanvasApp/Views/CalculatorView.swift`, replace the placeholder `SolveForMeTabView`:

```swift
struct SolveForMeTabView: View {
    @ObservedObject var vm: CalculatorViewModel

    private var gradeLetters: [String] {
        vm.gradingScale.map { $0.0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Target grade input ──────────────────────────
                GroupBox("Target Grade") {
                    Picker("Input mode", selection: $vm.targetMode) {
                        Text("Letter").tag(CalculatorViewModel.TargetMode.letter)
                        Text("Percent").tag(CalculatorViewModel.TargetMode.percent)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if vm.targetMode == .letter {
                        Picker("Grade", selection: $vm.targetLetter) {
                            ForEach(gradeLetters, id: \.self) { letter in
                                Text(letter).tag(letter)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        HStack {
                            TextField("90", text: $vm.targetPercentInput)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("%")
                        }
                    }
                }

                // ── Assignment scope ────────────────────────────
                GroupBox("Which assignments?") {
                    Picker("Scope", selection: $vm.solveScope) {
                        Text("Single assignment").tag(CalculatorViewModel.SolveScope.single)
                        Text("Spread across selected").tag(CalculatorViewModel.SolveScope.spread)
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    if vm.solveScope == .single {
                        if vm.ungradedItems.isEmpty {
                            Text("No ungraded assignments.").foregroundStyle(.secondary)
                        } else {
                            Picker("Assignment", selection: $vm.solveSingleId) {
                                Text("Select…").tag(nil as Int?)
                                ForEach(vm.ungradedItems, id: \.assignmentId) { item in
                                    Text(item.name).tag(item.assignmentId as Int?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(vm.ungradedItems, id: \.assignmentId) { item in
                                Toggle(item.name, isOn: Binding(
                                    get: { vm.solveMultiIds.contains(item.assignmentId) },
                                    set: { on in
                                        if on { vm.solveMultiIds.insert(item.assignmentId) }
                                        else  { vm.solveMultiIds.remove(item.assignmentId) }
                                    }
                                ))
                                .font(.subheadline)
                            }
                        }
                    }
                }

                // ── Result ──────────────────────────────────────
                GroupBox("Result") {
                    SolveResultView(vm: vm)
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct SolveResultView: View {
    @ObservedObject var vm: CalculatorViewModel

    var body: some View {
        Group {
            if vm.solveAssignmentIds.isEmpty {
                Text("Select an assignment above.")
                    .foregroundStyle(.secondary)
            } else if let result = vm.solveResult {
                switch result {
                case .alreadyAchieved:
                    Label("You've already hit your target grade!", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                case .needed(let percent):
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You need:").font(.subheadline).foregroundStyle(.secondary)
                        if vm.solveScope == .single, let id = vm.solveSingleId,
                           let item = vm.baseItems.first(where: { $0.assignmentId == id }) {
                            let pts = item.pointsPossible * percent / 100
                            Text(String(format: "**%.1f%%** (%.0f / %.0f pts) on %@",
                                        percent, pts, item.pointsPossible, item.name))
                                .font(.headline)
                        } else {
                            let n = vm.solveAssignmentIds.count
                            Text(String(format: "**%.1f%%** on each of your %d selected assignments", percent, n))
                                .font(.headline)
                        }
                        Text(String(format: "Target: %.1f%%  (%@)",
                                    vm.targetPercentValue,
                                    vm.targetMode == .letter ? vm.targetLetter : "\(vm.targetPercentInput)%"))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                case .impossible(let maxPossible):
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Not achievable", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red).font(.headline)
                        Text(String(format: "Even 100%% on selected assignments gives you %.1f%%.", maxPossible))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Build**

```bash
swift build --target CanvasApp 2>&1
```

Expected: Build succeeded.

- [ ] **Step 3: Smoke-test Solve For Me**

Run the app, navigate to a course, open Calculator, switch to "Solve For Me" tab. Verify:

1. **Already achieved:** Set target to "F", select any assignment → "You've already hit your target grade!"
2. **Needed (single):** Set target to "A" (94%), select the lowest-weight ungraded assignment → shows "You need X% (Y/Z pts) on [name]"
3. **Needed (spread):** Switch to "Spread across selected", check 2–3 ungraded items, target "B" → shows average % needed
4. **Impossible:** Set target to "A" (94%) when your grade is low and only one small assignment remains → shows "Not achievable — even 100% gives you X%"
5. **Compose with What-If:** Switch to What-If tab, toggle an assignment and set a low score. Switch back to Solve For Me — the live grade in the header should have dropped, and the solver now uses those what-if scores as the baseline.

Kill: `pkill CanvasApp`

- [ ] **Step 4: Run all tests to confirm nothing broken**

```bash
swift test --target CanvasCoreTests 2>&1
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add CanvasApp/Views/CalculatorView.swift
git commit -m "feat: Solve For Me tab — target grade solver with single and spread modes"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Task |
|---|---|
| macOS menu bar app | Task 4 |
| CanvasCore library | Task 1 |
| Keychain token storage | Task 4 |
| Onboarding + settings sheet | Task 4 + 5 |
| BYUH grade scale (A≥94) | Task 2 |
| Per-course grading scheme from Canvas API | Task 2 |
| Course list with red code + gold grade | Task 6 |
| Grade dashboard with progress bars | Task 7 |
| Assignment group weights, drop rules | Task 7 (CourseDetailViewModel) |
| Manual what-if (toggle, points/% input) | Task 8 |
| Live grade recalculation | Task 8 |
| Target grade — letter and % input | Task 9 |
| Solve single assignment | Task 9 |
| Solve spread across selected | Task 9 |
| Already achieved / impossible feedback | Task 9 |
| Compose what-if + solve | Task 9 (uses `liveCalculator`) |
| Parallel fetch (groups + submissions) | Task 7 (`async let`) |
| Refresh button | Task 6 (toolbar), Task 7 (toolbar) |
| API 401 error handling | Task 6 + 7 (error state) |
| Loading spinner | Task 6 + 7 |
| No grading scheme → fall back | Task 7 (`gradingScale` computed property) |

**No gaps found.** All spec requirements are covered.
