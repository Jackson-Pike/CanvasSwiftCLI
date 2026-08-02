# Phase 1a — Dashboard + What-If Sandbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Canvas Grades macOS **Dashboard** detail pane and the docked **What-If Sandbox** rail (course-scope and term-scope), replacing today's `ComingSoonView(title: "Dashboard", …)` and the hidden `.inspector` calculator.

**Architecture:** All new grade math (ceiling/floor, points ledger, term GPA, term scenario solving) lands as **pure, XCTest-covered functions in `CanvasCore`** (the only test-covered layer besides `CanvasData`). SwiftUI is a thin consumer: value-driven reusable pieces in `CanvasUI`, app-level composition and view-models in `CanvasApp`. Phase 1a is verified end-to-end against **demo mode / `MockData`**; live-API wiring for new fields (colors, term dates, retained ungraded group totals) is explicitly deferred to a follow-up.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest. Package `CanvasCLISwift`, `platforms: [.macOS(.v14)]`. Build: `swift build`. Test: `swift test` (target a suite with `swift test --filter CanvasCoreTests`).

## Global Constraints

- **Platform floor:** macOS 14. Window minimum stays `minWidth: 900, minHeight: 600` (spec §5.1).
- **Test framework:** XCTest only (`final class …: XCTestCase`, `@testable import`). No Swift Testing. Only two test targets exist: `CanvasCoreTests` (deps `CanvasCore`) and `CanvasDataTests` (deps `CanvasData`, `CanvasCore`). **There is no app/UI test target** — SwiftUI in `CanvasApp`/`CanvasUI` is verified by `swift build` succeeding plus visual check against the design reference and `MockData`, not by unit tests. Put every testable behavior in `CanvasCore`.
- **Demo verifiability:** every number the UI shows must be computable from `Sources/CanvasCore/MockData.swift` (wrapped in `#if DEBUG`). Verify implementations in demo mode against those values.
- **Palette:** retire BYU–Hawaii red/gold as chrome. New tokens (exact hex in Task 4). `accent` (indigo) is reserved **exclusively** for hypothetical/what-if values; `lost` (burnt-orange) is reserved **exclusively** for lost/missing points. `Color.letterGradeColor` (green/blue/yellow/red) is kept only where a letter grade is shown.
- **Credit hours:** real term GPA needs per-course credit hours. Phase 1a default = **3.0 credits per course**, overridable via a Settings field persisted in `UserDefaults`. GPA uses a 4.0 scale mapping (Task 2).
- **Persistence pattern:** new `Router` flags persist to `UserDefaults` exactly like the existing `router.sidebar` (`didSet` → `UserDefaults.standard.set(...)`, read in `init()`).
- **Design reference (read before implementing UI):** `docs/superpowers/specs/2026-08-02-phase1a-dashboard-sandbox-handoff.md` (the handoff) and `docs/superpowers/design-assets/2026-08-02-canvas-desktop.dc.html` (open in a browser; approved options are `3a` dark dashboard, `3b` light dashboard, `1d` course workspace + Sandbox). Nothing in the HTML is ported literally — recreate in SwiftUI.
- **No literal ports; follow existing patterns:** value-driven `public struct … : View` with `public init` in `CanvasUI`; `@Observable`/`ObservableObject` view-models in `CanvasApp`; SF Symbols (`square.grid.2x2`, `tray`, `calendar`, `checklist`, `arrow.clockwise`, `gearshape`, `function`, `clock`, `checkmark.circle`, `bubble.left`). No bundled images.

---

## File Structure

**Create:**
- `Sources/CanvasCore/PointsLedger.swift` — `PointsLedger` struct + `GradeCalculator.pointsLedger()`, `.ceilingGrade()`, `.floorGrade()`.
- `Sources/CanvasCore/TermGPA.swift` — letter→GPA-points mapping, `CourseGradeSummary`, `termGPA(...)`, ceiling/floor GPA, `TermScenario` solve helpers.
- `Sources/CanvasUI/DesignTokens.swift` — theme-aware palette + typography helpers (extends the `Color` and `Font` namespaces).
- `Sources/CanvasUI/SemesterTimelineStrip.swift` — value-driven timeline view.
- `Sources/CanvasUI/LedgerTable.swift` — `LedgerRowView` + `PointsBar` value views.
- `Sources/CanvasUI/DashboardPanels.swift` — `AwaitingGradePanel`, `RecentFeedbackPanel`, `AgeCapsule`.
- `Sources/CanvasUI/SandboxRail.swift` — `SandboxRailView` (course scope, consumes `CalculatorViewModel`) + shared rail sub-views (`TargetChips`, `HypotheticalSlider`, `ScenarioChips`).
- `CanvasApp/ViewModels/DashboardViewModel.swift` — cross-course aggregation.
- `CanvasApp/ViewModels/TermScenarioViewModel.swift` — term-scope sandbox state.
- `CanvasApp/App/CourseSettingsStore.swift` — per-course credit hours + target grade (`UserDefaults`).
- `CanvasApp/Views/Window/DashboardView.swift` — Dashboard detail pane composition.
- `CanvasApp/Views/Window/TermSandboxRail.swift` — term-scope rail (Dashboard variant).
- `Tests/CanvasCoreTests/PointsLedgerTests.swift`
- `Tests/CanvasCoreTests/TermGPATests.swift`

**Modify:**
- `Sources/CanvasUI/BrandColors.swift` — keep existing; new tokens go in `DesignTokens.swift` to avoid churn.
- `CanvasApp/App/Router.swift` — add `sandboxOpen`, `dashboardDensity` (persisted).
- `CanvasApp/Views/Window/MainWindowView.swift` — `.dashboard` case → `DashboardView`; sidebar course rows show percentage (per handoff §1.5).
- `CanvasApp/Views/Window/CourseWorkspaceView.swift` — `GradesTabView` docks `SandboxRailView` in an `HStack`, replacing `.inspector`.
- `CanvasApp/Views/SettingsView.swift` — credit-hours field, default-dashboard-view, theme, per-course target grade.

---

## Task Dependency Order

Tasks 1–3 (CanvasCore math, TDD) → Task 4 (tokens) → Task 5 (Router) → Task 6 (DashboardViewModel + CourseSettingsStore) → Tasks 8–10 (CanvasUI value views) → Task 11 (DashboardView + wire-in) → Task 12 (course Sandbox rail) → Task 13 (term Sandbox) → Task 14 (Settings). Tasks 1–5 are independent of each other except where noted and may be dispatched in parallel; 6+ depend on 1–5.

---

### Task 1: Points ledger + ceiling/floor grade math (`CanvasCore`)

**Files:**
- Create: `Sources/CanvasCore/PointsLedger.swift`
- Test: `Tests/CanvasCoreTests/PointsLedgerTests.swift`

**Interfaces:**
- Consumes: existing `GradedItem(assignmentId:name:groupId:pointsPossible:earnedPoints:whatIfPoints:)`, `GradeCalculator(items:groups:weighted:gradingScale:)`, `GradeCalculator.currentGrade() -> Double?`, and the existing `[GradedItem]` extensions `applyingPerfectRemaining()` and `applyingBlanketToUngraded(percent:)`.
- Produces:
  - `public struct PointsLedger: Equatable { public let earned: Double; public let lost: Double; public let inPlay: Double; public let total: Double }`
  - `public extension GradeCalculator { func pointsLedger() -> PointsLedger; func ceilingGrade() -> Double?; func floorGrade() -> Double? }`

Definitions (these are the contract other tasks rely on):
- `earned` = Σ `earnedPoints` over items where `earnedPoints != nil`.
- `lost` = Σ (`pointsPossible − earnedPoints`) over graded items (`earnedPoints != nil`).
- `inPlay` = Σ `pointsPossible` over ungraded items (`earnedPoints == nil`).
- `total` = Σ `pointsPossible` over all items. (`earned + lost + inPlay == total`.)
- `ceilingGrade()` = `GradeCalculator(items: items.applyingPerfectRemaining(), groups: groups, weighted: weighted, gradingScale: gradingScale).currentGrade()`.
- `floorGrade()` = same with `items.applyingBlanketToUngraded(percent: 0)`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CanvasCore

final class PointsLedgerTests: XCTestCase {
    // One group, unweighted, 3 items @100 pts: two graded (90, 80), one ungraded.
    private func makeCalc() -> GradeCalculator {
        let items = [
            GradedItem(assignmentId: 1, name: "A", groupId: 10, pointsPossible: 100, earnedPoints: 90),
            GradedItem(assignmentId: 2, name: "B", groupId: 10, pointsPossible: 100, earnedPoints: 80),
            GradedItem(assignmentId: 3, name: "C", groupId: 10, pointsPossible: 100, earnedPoints: nil),
        ]
        return GradeCalculator(items: items, groups: [10: GroupInfo(name: "G", weight: 100)], weighted: false)
    }

    func testPointsLedgerSplits() {
        let l = makeCalc().pointsLedger()
        XCTAssertEqual(l.earned, 170, accuracy: 0.001)
        XCTAssertEqual(l.lost, 30, accuracy: 0.001)      // (100-90)+(100-80)
        XCTAssertEqual(l.inPlay, 100, accuracy: 0.001)
        XCTAssertEqual(l.total, 300, accuracy: 0.001)
        XCTAssertEqual(l.earned + l.lost + l.inPlay, l.total, accuracy: 0.001)
    }

    func testCeilingFloorBracketCurrent() {
        let calc = makeCalc()
        let now = calc.currentGrade()!        // (90+80)/200 = 85.0
        let ceiling = calc.ceilingGrade()!     // (90+80+100)/300 = 90.0
        let floor = calc.floorGrade()!         // (90+80+0)/300 = 56.666…
        XCTAssertEqual(now, 85.0, accuracy: 0.01)
        XCTAssertEqual(ceiling, 90.0, accuracy: 0.01)
        XCTAssertEqual(floor, 170.0/300.0*100, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(ceiling, now)
        XCTAssertLessThanOrEqual(floor, now)
    }

    func testMockDataLedgerIsSelfConsistent() {
        // For every demo course, earned+lost+inPlay == total and ceiling >= floor.
        for (courseId, groups) in MockData.assignmentGroups {
            let subs = MockData.submissions[courseId] ?? []
            let items = buildGradedItems(groups: groups, submissions: subs)
            let course = MockData.courses.first { $0.id == courseId }!
            let calc = GradeCalculator(items: items,
                                       groups: Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) }),
                                       weighted: course.applyAssignmentGroupWeights ?? true)
            let l = calc.pointsLedger()
            XCTAssertEqual(l.earned + l.lost + l.inPlay, l.total, accuracy: 0.01, "course \(courseId)")
            if let c = calc.ceilingGrade(), let f = calc.floorGrade() {
                XCTAssertGreaterThanOrEqual(c + 0.001, f, "course \(courseId)")
            }
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter PointsLedgerTests`
Expected: FAIL — `value of type 'GradeCalculator' has no member 'pointsLedger'`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/CanvasCore/PointsLedger.swift
import Foundation

public struct PointsLedger: Equatable {
    public let earned: Double
    public let lost: Double
    public let inPlay: Double
    public let total: Double
    public init(earned: Double, lost: Double, inPlay: Double, total: Double) {
        self.earned = earned; self.lost = lost; self.inPlay = inPlay; self.total = total
    }
}

public extension GradeCalculator {
    func pointsLedger() -> PointsLedger {
        var earned = 0.0, lost = 0.0, inPlay = 0.0, total = 0.0
        for item in items {
            total += item.pointsPossible
            if let e = item.earnedPoints {
                earned += e
                lost += max(0, item.pointsPossible - e)
            } else {
                inPlay += item.pointsPossible
            }
        }
        return PointsLedger(earned: earned, lost: lost, inPlay: inPlay, total: total)
    }

    func ceilingGrade() -> Double? {
        GradeCalculator(items: items.applyingPerfectRemaining(),
                        groups: groups, weighted: weighted, gradingScale: gradingScale).currentGrade()
    }

    func floorGrade() -> Double? {
        GradeCalculator(items: items.applyingBlanketToUngraded(percent: 0),
                        groups: groups, weighted: weighted, gradingScale: gradingScale).currentGrade()
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter PointsLedgerTests`
Expected: PASS (3 tests). If `applyingPerfectRemaining`/`applyingBlanketToUngraded` signatures differ, adapt to the real ones in `GradeCalculator.swift`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/PointsLedger.swift Tests/CanvasCoreTests/PointsLedgerTests.swift
git commit -m "feat(core): points ledger + ceiling/floor grade math"
```

---

### Task 2: Letter→GPA points + term GPA aggregation (`CanvasCore`)

**Files:**
- Create: `Sources/CanvasCore/TermGPA.swift`
- Test: `Tests/CanvasCoreTests/TermGPATests.swift`

**Interfaces:**
- Consumes: `letterGrade(for:scale:) -> String`, `byuhDefaultScale`.
- Produces:
  - `public func gpaPoints(forLetter letter: String) -> Double` — maps a letter (`A`,`A-`,`B+`,…,`F`) to 4.0-scale points.
  - `public struct CourseGradeSummary: Equatable { public let courseId: Int; public let credits: Double; public let nowPercent: Double?; public let ceilingPercent: Double?; public let floorPercent: Double?; public let scale: [(String, Double)] }` — note `[(String,Double)]` is not `Equatable`; implement `==` manually comparing the scalar fields and `scale` element-wise, or drop `Equatable` and compare fields in tests. **Decision: do NOT conform to `Equatable`** (tuple array blocks synthesis); tests compare fields directly.
  - `public func termGPA(_ summaries: [CourseGradeSummary], using pick: (CourseGradeSummary) -> Double?) -> Double?` — weighted mean of `gpaPoints(forLetter: letterGrade(for: pick(summary), scale: summary.scale))` by `credits`, skipping summaries whose `pick` is nil. Returns nil if no creditable course.
  - Convenience: `public func currentTermGPA(_ s: [CourseGradeSummary]) -> Double?` (pick `nowPercent`), `ceilingTermGPA` (pick `ceilingPercent`), `floorTermGPA` (pick `floorPercent`).

GPA mapping (4.0 scale, standard): `A 4.0, A- 3.7, B+ 3.3, B 3.0, B- 2.7, C+ 2.3, C 2.0, C- 1.7, D+ 1.3, D 1.0, D- 0.7, F 0.0`. Match on the letter string prefix produced by `letterGrade(for:scale:)`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CanvasCore

final class TermGPATests: XCTestCase {
    func testGpaPointsMapping() {
        XCTAssertEqual(gpaPoints(forLetter: "A"), 4.0, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "A-"), 3.7, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "B+"), 3.3, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "C-"), 1.7, accuracy: 0.001)
        XCTAssertEqual(gpaPoints(forLetter: "F"), 0.0, accuracy: 0.001)
    }

    func testWeightedTermGPA() {
        let s = [
            CourseGradeSummary(courseId: 1, credits: 3, nowPercent: 95, ceilingPercent: 100, floorPercent: 50, scale: byuhDefaultScale), // A -> 4.0
            CourseGradeSummary(courseId: 2, credits: 4, nowPercent: 84, ceilingPercent: 90, floorPercent: 40, scale: byuhDefaultScale),  // B -> 3.0
        ]
        // (4.0*3 + 3.0*4) / 7 = 24/7 = 3.4286
        XCTAssertEqual(currentTermGPA(s)!, 24.0/7.0, accuracy: 0.001)
        XCTAssertEqual(ceilingTermGPA(s)!, 4.0, accuracy: 0.001)          // A and A- ... 100->A(4.0), 90->A-(3.7): (4*3+3.7*4)/7
        // fix expectation: ceiling letters are A(4.0) and A-(3.7)
    }

    func testCeilingGPAExact() {
        let s = [
            CourseGradeSummary(courseId: 1, credits: 3, nowPercent: 95, ceilingPercent: 100, floorPercent: 50, scale: byuhDefaultScale),
            CourseGradeSummary(courseId: 2, credits: 4, nowPercent: 84, ceilingPercent: 90, floorPercent: 40, scale: byuhDefaultScale),
        ]
        XCTAssertEqual(ceilingTermGPA(s)!, (4.0*3 + 3.7*4)/7, accuracy: 0.001)
        XCTAssertEqual(floorTermGPA(s)!, (0.0*3 + 0.0*4)/7, accuracy: 0.001) // 50->F, 40->F
    }

    func testNilPercentSkipped() {
        let s = [
            CourseGradeSummary(courseId: 1, credits: 3, nowPercent: nil, ceilingPercent: 100, floorPercent: 0, scale: byuhDefaultScale),
            CourseGradeSummary(courseId: 2, credits: 3, nowPercent: 94, ceilingPercent: 100, floorPercent: 0, scale: byuhDefaultScale),
        ]
        XCTAssertEqual(currentTermGPA(s)!, 4.0, accuracy: 0.001) // only course 2 counts
    }
}
```

(Remove the stray comment/expectation in `testWeightedTermGPA` — the exact ceiling assertion lives in `testCeilingGPAExact`. Keep `testWeightedTermGPA` asserting only `currentTermGPA`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TermGPATests`
Expected: FAIL — `cannot find 'gpaPoints' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/CanvasCore/TermGPA.swift
import Foundation

public func gpaPoints(forLetter letter: String) -> Double {
    switch letter {
    case "A":  return 4.0
    case "A-": return 3.7
    case "B+": return 3.3
    case "B":  return 3.0
    case "B-": return 2.7
    case "C+": return 2.3
    case "C":  return 2.0
    case "C-": return 1.7
    case "D+": return 1.3
    case "D":  return 1.0
    case "D-": return 0.7
    default:   return 0.0   // F and anything unrecognized
    }
}

public struct CourseGradeSummary {
    public let courseId: Int
    public let credits: Double
    public let nowPercent: Double?
    public let ceilingPercent: Double?
    public let floorPercent: Double?
    public let scale: [(String, Double)]
    public init(courseId: Int, credits: Double, nowPercent: Double?, ceilingPercent: Double?, floorPercent: Double?, scale: [(String, Double)]) {
        self.courseId = courseId; self.credits = credits
        self.nowPercent = nowPercent; self.ceilingPercent = ceilingPercent; self.floorPercent = floorPercent
        self.scale = scale
    }
}

public func termGPA(_ summaries: [CourseGradeSummary], using pick: (CourseGradeSummary) -> Double?) -> Double? {
    var totalPoints = 0.0, totalCredits = 0.0
    for s in summaries {
        guard let pct = pick(s) else { continue }
        let letter = letterGrade(for: pct, scale: s.scale)
        totalPoints += gpaPoints(forLetter: letter) * s.credits
        totalCredits += s.credits
    }
    guard totalCredits > 0 else { return nil }
    return totalPoints / totalCredits
}

public func currentTermGPA(_ s: [CourseGradeSummary]) -> Double? { termGPA(s) { $0.nowPercent } }
public func ceilingTermGPA(_ s: [CourseGradeSummary]) -> Double? { termGPA(s) { $0.ceilingPercent } }
public func floorTermGPA(_ s: [CourseGradeSummary]) -> Double? { termGPA(s) { $0.floorPercent } }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TermGPATests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/TermGPA.swift Tests/CanvasCoreTests/TermGPATests.swift
git commit -m "feat(core): letter->GPA mapping and weighted term GPA"
```

---

### Task 3: Term scenario solving (`CanvasCore`)

**Files:**
- Modify: `Sources/CanvasCore/TermGPA.swift`
- Test: `Tests/CanvasCoreTests/TermGPATests.swift`

**Interfaces:**
- Consumes: `termGPA(_:using:)`, `gpaPoints(forLetter:)`, `letterGrade(for:scale:)`, existing `GradeCalculator.solveForTarget(targetPercent:solveAssignmentIds:) -> SolveResult`, `[GradedItem].applyingBlanketToUngraded(percent:)`.
- Produces:
  - `public func projectedTermGPA(_ summaries: [CourseGradeSummary], overrides: [Int: Double]) -> Double?` — `overrides[courseId]` supplies a hypothetical **percent** for that course (used in place of `nowPercent`); other courses use `nowPercent`. Nil-percent courses without an override are skipped.
  - `public func gpaLift(_ summaries: [CourseGradeSummary], overrides: [Int: Double]) -> Double?` — `projectedTermGPA − currentTermGPA` (nil if either is nil).

This is the math the term-scope Sandbox rail (Task 13) drives: per-course "remaining work" sliders set `overrides[courseId]` and the projected-GPA card recomputes live.

- [ ] **Step 1: Write the failing test**

```swift
func testProjectedTermGPAWithOverride() {
    let s = [
        CourseGradeSummary(courseId: 1, credits: 3, nowPercent: 71, ceilingPercent: 90, floorPercent: 30, scale: byuhDefaultScale), // now C -> 2.0
        CourseGradeSummary(courseId: 2, credits: 3, nowPercent: 95, ceilingPercent: 100, floorPercent: 40, scale: byuhDefaultScale), // A -> 4.0
    ]
    // current: (2.0+4.0)/2 = 3.0
    XCTAssertEqual(currentTermGPA(s)!, 3.0, accuracy: 0.001)
    // override course 1 to 84% (B -> 3.0): (3.0+4.0)/2 = 3.5
    XCTAssertEqual(projectedTermGPA(s, overrides: [1: 84])!, 3.5, accuracy: 0.001)
    XCTAssertEqual(gpaLift(s, overrides: [1: 84])!, 0.5, accuracy: 0.001)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TermGPATests/testProjectedTermGPAWithOverride`
Expected: FAIL — `cannot find 'projectedTermGPA' in scope`.

- [ ] **Step 3: Write minimal implementation** (append to `TermGPA.swift`)

```swift
public func projectedTermGPA(_ summaries: [CourseGradeSummary], overrides: [Int: Double]) -> Double? {
    termGPA(summaries) { overrides[$0.courseId] ?? $0.nowPercent }
}

public func gpaLift(_ summaries: [CourseGradeSummary], overrides: [Int: Double]) -> Double? {
    guard let base = currentTermGPA(summaries),
          let proj = projectedTermGPA(summaries, overrides: overrides) else { return nil }
    return proj - base
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter TermGPATests`
Expected: PASS (all TermGPA tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/TermGPA.swift Tests/CanvasCoreTests/TermGPATests.swift
git commit -m "feat(core): projected term GPA and lift for scenario sliders"
```

---

### Task 4: Design tokens & typography (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/DesignTokens.swift`

**Interfaces:**
- Produces (all on `Color`/`Font`, theme-aware via `Color(nsColor:)` dynamic providers or `@Environment(\.colorScheme)` — use dynamic `NSColor` providers so values resolve automatically):
  - `Color.canvasBG`, `.canvasPanel`, `.canvasHairline`, `.canvasHairlineStrong`, `.canvasRule`
  - `.inkPrimary`, `.inkSecondary`, `.inkTertiary`, `.inkQuaternary`
  - `.accentHypothetical`, `.onAccent`, `.lostMissing`, `.earnedBar`, `.barTrack`, `.rowHighlightMissing`
  - `ShapeStyle` for the in-play hatch: `func inPlayHatch(_ scheme: ColorScheme) -> LinearGradient` **(SwiftUI cannot render true repeating stripe gradients simply; implement the hatch as a reusable `InPlayHatch: View` using a `Canvas` drawing diagonal lines, exposed here)**.
  - Typography: `Font.display(_ size: CGFloat) -> Font` (system, weight `.bold`, wide-negative tracking applied by caller via `.tracking(-0.03 * size)`); `Font.mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font` (system `.monospacedDigit()`); `Font.sectionLabel` (system 10.5 bold, callers add `.tracking` + `.textCase(.uppercase)`).

Exact token values (dynamic light/dark). Implement each as:
```swift
static let canvasBG = Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua]) != nil ? dark : light })
```
Use this helper:
```swift
private func dynamic(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    })
}
```

Dark / Light hex pairs (from handoff §Design Tokens):

| Token | Dark | Light |
|---|---|---|
| canvasBG | `#17161A` | `#FBFAF8` |
| canvasPanel | `#131217` | `#F1EFEB` |
| canvasHairline | `rgba(255,255,255,.07)` | `rgba(0,0,0,.07)` |
| canvasHairlineStrong | `rgba(255,255,255,.09)` | `rgba(0,0,0,.09)` |
| canvasRule | `rgba(255,255,255,.12)` | `rgba(0,0,0,.13)` |
| inkPrimary | `#EDEBF2` (codes/GPA use `#FFFFFF`) | `#17161A` |
| inkSecondary | `#C6C2D2` | `#57545E` |
| inkTertiary | `#9C98A8` | `#8B8894` |
| inkQuaternary | `#6B6878` | `#8B8894` |
| accentHypothetical | `#7A6EFF` | `#5A4FCF` |
| onAccent | `#0F0E12` | `#FFFFFF` |
| lostMissing | `#E2703A` | `#C2410C` |
| earnedBar | `#EDEBF2` | `#2B2833` |
| barTrack | `#2A2833` (approx panel) | `#ECE9E3` |
| rowHighlightMissing | `rgba(226,112,58,.09)` | `rgba(194,65,12,.06)` |

Add `Color.gpaCodeWhite = dynamic(light: NSColor(hex: "#17161A"), dark: .white)` for course codes / the big GPA per handoff. Provide a small `NSColor(hex:)` convenience in this file.

- [ ] **Step 1: Implement the tokens file** (all tokens above, the `dynamic(light:dark:)` helper, `NSColor(hex:)`, `InPlayHatch` view, and the `Font` helpers).
- [ ] **Step 2: Add a trivial preview** at the bottom under `#if DEBUG` showing swatches, to eyeball both themes.
- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/CanvasUI/DesignTokens.swift
git commit -m "feat(ui): Phase 1a design tokens and typography helpers"
```

---

### Task 5: Router — sandbox + dashboard-density persisted state (`CanvasApp`)

**Files:**
- Modify: `CanvasApp/App/Router.swift`

**Interfaces:**
- Consumes: existing `Router` (`@MainActor @Observable`, `sidebar` persisted via `didSet`).
- Produces on `Router`:
  - `enum DashboardDensity: String { case cards, ledger }`
  - `var dashboardDensity: DashboardDensity { didSet → UserDefaults "router.dashboardDensity" = rawValue }` (default `.ledger`)
  - `var sandboxOpen: Bool { didSet → UserDefaults "router.sandboxOpen" }` (default `false`)
  - `init()` reads both keys.

- [ ] **Step 1: Add the enum + two stored properties with `didSet` persistence**, mirroring the existing `sidebar`/`courseTab` pattern exactly.

```swift
enum DashboardDensity: String { case cards, ledger }

var dashboardDensity: DashboardDensity {
    didSet { UserDefaults.standard.set(dashboardDensity.rawValue, forKey: "router.dashboardDensity") }
}
var sandboxOpen: Bool {
    didSet { UserDefaults.standard.set(sandboxOpen, forKey: "router.sandboxOpen") }
}
```

- [ ] **Step 2: Initialize in `init()`** after the existing reads:

```swift
let densityRaw = UserDefaults.standard.string(forKey: "router.dashboardDensity") ?? DashboardDensity.ledger.rawValue
self.dashboardDensity = DashboardDensity(rawValue: densityRaw) ?? .ledger
self.sandboxOpen = UserDefaults.standard.bool(forKey: "router.sandboxOpen")
```

(Place these before any use; `@Observable` requires all stored props initialized before methods run. If `init()` assigns `sidebar`/`courseTab` first, append these there.)

- [ ] **Step 3: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/App/Router.swift
git commit -m "feat(app): Router sandboxOpen and dashboardDensity persisted state"
```

---

### Task 6: CourseSettingsStore + DashboardViewModel (`CanvasApp`)

**Files:**
- Create: `CanvasApp/App/CourseSettingsStore.swift`
- Create: `CanvasApp/ViewModels/DashboardViewModel.swift`

**Interfaces:**
- Consumes: `CoursesViewModel` (`courses: [CachedCourse]`, `currentScore(for:)`, `letter(for:)`, `lastSyncedAt`), `AppSession` (repository access as `CourseDetailViewModel` uses it: `repository.calculatorInputs(courseId:)`, `repository.stream(courseId:)`), `CalculatorInputs`, `StreamItem`/`StreamItem.Kind`, and Tasks 1–3 (`GradeCalculator.pointsLedger/ceilingGrade/floorGrade`, `CourseGradeSummary`, `currentTermGPA`/`ceilingTermGPA`/`floorTermGPA`).
- Produces:
  - `final class CourseSettingsStore` (`@MainActor @Observable`): `func credits(for courseId: Int) -> Double` (default 3.0, key `"course.credits.\(id)"`), `func setCredits(_:for:)`, `func targetGrade(for:) -> String?` (key `"course.target.\(id)"`), `func setTargetGrade(_:for:)`.
  - `struct CourseLedgerRow: Identifiable` — `id: Int` (courseId), `code: String`, `name: String`, `dotColor: Color`, `nowPercent: Double?`, `ledger: PointsLedger`, `ceilingPercent: Double?`, `ceilingLetter: String?`, `floorPercent: Double?`, `floorLetter: String?`, `missingCount: Int`, `missingLabel: String?`.
  - `@MainActor @Observable final class DashboardViewModel`: published `termGPA: Double?`, `ceilingGPA: Double?`, `floorGPA: Double?`, `pointsInPlay: Double`, `rows: [CourseLedgerRow]`, `awaitingGrade: [StreamItem]`, `recentFeedback: [StreamItem]`, `termStart: Date?`, `termEnd: Date?`, `isLoading`, `error: String?`, `lastSyncedAt: Date?`; `func load(session:coursesVM:settings:force:) async`.

Aggregation rules:
- For each non-hidden course: build `GradeCalculator` from `repository.calculatorInputs(courseId:)` (same path `CourseDetailViewModel` uses). `nowPercent = calc.currentGrade()`, `ledger = calc.pointsLedger()`, `ceilingPercent = calc.ceilingGrade()`, `floorPercent = calc.floorGrade()`, letters via `calc.letterGradeForPercent(_:)`.
- `missingCount` = number of `StreamItem` with `.kind == .awaitingGrade` for that course whose submission is genuinely missing — **for Phase 1a, approximate as count of ungraded items past due**; if that data isn't cheaply available, set `missingLabel = "\(n) missing …"` only when `> 0`, else nil. Keep the rule defensive.
- `awaitingGrade` / `recentFeedback`: merge `repository.stream(courseId:)` across courses, filter by `.kind` (`.awaitingGrade`; `.feedback`), sort by recency, cap awaitingGrade at all, feedback at 3.
- GPA: assemble `[CourseGradeSummary]` (`credits: settings.credits(for:)`, `scale: course.gradingScale`), then `currentTermGPA/ceilingTermGPA/floorTermGPA`.
- `pointsInPlay` = Σ `ledger.inPlay` across rows.
- `termStart`/`termEnd`: min/max assignment `dueAt` across all courses (demo fallback; no term API in 1a).
- `dotColor`: from the fixed demo map in the handoff (`CS #14B8A6 · MATH #3B82F6 · HIST #8B5CF6 · REL #EF4444`) keyed by course-code prefix, falling back to `MainWindowView.accentColor(for:)`.

- [ ] **Step 1:** Implement `CourseSettingsStore` (UserDefaults-backed, defaults as above).
- [ ] **Step 2:** Implement `CourseLedgerRow` and `DashboardViewModel.load(...)` following the aggregation rules; reuse the repository-read pattern from `CourseDetailViewModel.readFromStore`.
- [ ] **Step 3: Build**

Run: `swift build`
Expected: clean.

- [ ] **Step 4: Demo sanity check** — temporary `#if DEBUG` `print` (or a scratch test) confirming, in demo mode, four rows with `earned+lost+inPlay==total` each and a non-nil `termGPA`. Remove the print before commit.

- [ ] **Step 5: Commit**

```bash
git add CanvasApp/App/CourseSettingsStore.swift CanvasApp/ViewModels/DashboardViewModel.swift
git commit -m "feat(app): CourseSettingsStore and cross-course DashboardViewModel"
```

---

### Task 8: Semester timeline strip (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/SemesterTimelineStrip.swift`

**Interfaces:**
- Produces: `public struct SemesterTimelineStrip: View` with
  `public init(termStart: Date, termEnd: Date, now: Date = .init(), ticks: [Tick])` where
  `public struct Tick: Identifiable { public let id: Int; public let dueAt: Date; public let style: Style; public enum Style { case graded, missing, upcoming, finalExam } }`.

Layout (handoff §1.2): 32pt-tall band with 1px top+bottom `canvasRule` borders. Elapsed overlay from left to `(now−start)/(end−start)` filled `inkPrimary` @ 3.5% alpha. `Today` marker: 2pt `inkPrimary` bar at the elapsed fraction, extending 6pt above/below. Ticks as circles positioned at `(dueAt−start)/(end−start)`, vertically centered: graded 7pt `inkTertiary`; missing 9pt `lostMissing`; upcoming 9pt `inkPrimary`; finalExam 12pt `inkPrimary`. Below: a 10.5pt `inkTertiary` row `Week 1` · `today` · `Finals · <formatted end>` with `space-between` (`HStack` + `Spacer`s). Clamp all fractions to `0...1`. Use `GeometryReader` for x-positions.

- [ ] **Step 1:** Implement the view + `Tick` type with a `#if DEBUG` preview using synthetic ticks in both color schemes.
- [ ] **Step 2: Build** — `swift build`, clean.
- [ ] **Step 3: Visual check** against option `3a`/`3b` in the `.dc.html`.
- [ ] **Step 4: Commit**

```bash
git add Sources/CanvasUI/SemesterTimelineStrip.swift
git commit -m "feat(ui): semester timeline strip"
```

---

### Task 9: Ledger table — row + points bar (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/LedgerTable.swift`

**Interfaces:**
- Consumes: `PointsLedger` (Task 1), `Color.letterGradeColor` (existing), design tokens (Task 4).
- Produces:
  - `public struct PointsBar: View` — `public init(ledger: PointsLedger)`. 15pt-tall, 3pt-radius, three abutting segments with **no gaps**: earned width `earned/total` filled `earnedBar`; lost width `lost/total` filled `lostMissing`; in-play remainder filled with the `InPlayHatch` (135°, 5pt on/off). Guard `total > 0`.
  - `public struct LedgerHeaderRow: View` — column captions `COURSE`(184) · `EARNED / LOST / IN PLAY`(flex) · `CEILING`(86,right) · `FLOOR`(70,right), 10.5pt/700/.09em tracking, `inkTertiary`, uppercase.
  - `public struct LedgerRowView: View` — `public init(code: String, name: String, dotColor: Color, nowPercent: Double?, ledger: PointsLedger, ceilingPercent: Double?, ceilingLetter: String?, floorPercent: Double?, floorLetter: String?, missingLabel: String?, onTap: @escaping () -> Void)`.

Row layout (handoff §1.3): `padding 11 0`, 1px top `canvasRule` divider. Course cell 184pt: code 14pt/600 `inkPrimary`; subtitle 10.5pt `inkTertiary` 2pt below — but if `missingLabel != nil`, subtitle = `missingLabel` in `lostMissing`, and the whole row gets a `rowHighlightMissing` background + 8pt horizontal padding (course cell narrows to 176). Bar cell flex, 20pt right padding: `PointsBar` then a 10pt `.monospacedDigit()` `inkSecondary` caption `now \(nowPercent, "%.1f")% · \(Int(ledger.inPlay)) pts in play`. Ceiling 86pt right: 16pt/700 mono `inkPrimary`, letter beneath 9.5pt `inkTertiary`. Floor 70pt right: same in `lostMissing`. Hover fill `inkPrimary`@4%. Whole row is a `Button`/`onTapGesture` calling `onTap`.

- [ ] **Step 1:** Implement `PointsBar`, `LedgerHeaderRow`, `LedgerRowView` + `#if DEBUG` preview from `MockData`-like values in both schemes.
- [ ] **Step 2: Build** — clean.
- [ ] **Step 3: Visual check** against `3a`/`3b`.
- [ ] **Step 4: Commit**

```bash
git add Sources/CanvasUI/LedgerTable.swift
git commit -m "feat(ui): ledger table row and points bar"
```

---

### Task 10: Dashboard bottom panels (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/DashboardPanels.swift`

**Interfaces:**
- Consumes: `StreamItem`/`StreamItem.Kind` (CanvasData) — **but `CanvasUI` must not depend on `CanvasData`.** Instead define value structs in `CanvasUI` and let `DashboardView` (Task 11) map `StreamItem` → these:
  - `public struct AwaitingRow: Identifiable { public let id: Int; public let dotColor: Color; public let title: String; public let subtitle: String; public let ageDays: Int; public let onTap: () -> Void }`
  - `public struct FeedbackRow: Identifiable { public let id: Int; public let initials: String; public let tint: Color; public let author: String; public let context: String; public let comment: String; public let onTap: () -> Void }`
- Produces:
  - `public struct AwaitingGradePanel: View` — `public init(rows: [AwaitingRow], heldBackNote: String?)`. Section label `AWAITING GRADE` + count (mono). Each row (`padding 8 0`, 1px top divider): 7pt course dot, title 12.5pt `inkPrimary` single-line ellipsis, subtitle 10.5pt `inkTertiary`; right = `AgeCapsule(days:)`. Footnote 10.5pt `inkTertiary` = `heldBackNote` when non-nil.
  - `public struct RecentFeedbackPanel: View` — `public init(rows: [FeedbackRow])`. Each row (`padding 9 0`, 1px top divider, 11pt gap): 26pt circle w/ initials 10.5pt/700 tinted `tint`@18%; line 1 12pt author bold + `context` in `inkTertiary`; line 2 12pt `inkSecondary` comment in quotes.
  - `public struct AgeCapsule: View` — `public init(days: Int)`. 10.5pt mono, padding 5×8, radius 99; neutral fill under 5 days, `lostMissing`@14% (dark)/10% (light) at 5+ days. This aging rule is the point of the panel.

- [ ] **Step 1:** Implement the three views + previews (both schemes; include one 5+ day capsule).
- [ ] **Step 2: Build** — clean.
- [ ] **Step 3: Visual check** against `3a`/`3b`.
- [ ] **Step 4: Commit**

```bash
git add Sources/CanvasUI/DashboardPanels.swift
git commit -m "feat(ui): dashboard awaiting-grade and recent-feedback panels"
```

---

### Task 11: DashboardView composition + wire into MainWindowView (`CanvasApp`)

**Files:**
- Create: `CanvasApp/Views/Window/DashboardView.swift`
- Modify: `CanvasApp/Views/Window/MainWindowView.swift`

**Interfaces:**
- Consumes: `DashboardViewModel`, `CourseSettingsStore`, `Router` (Task 5), all CanvasUI views (Tasks 8–10), tokens (Task 4). Maps `StreamItem` → `AwaitingRow`/`FeedbackRow` here (keeps `CanvasUI` free of `CanvasData`).
- Produces: `struct DashboardView: View` composing header (TERM GPA display 58pt via `Font.display`, the sentence with bolded points/ceiling/floor where the ceiling value uses `accentHypothetical`, and a `Play it out →` button toggling `router.sandboxOpen`), `SemesterTimelineStrip`, `LedgerHeaderRow` + `LedgerRowView`s (rows call `router.reveal(.course(id:tab:.grades))`), and the 2-column bottom grid (`1fr 1.15fr`, gap 26). Awaiting/feedback rows call `router.reveal(.assignment(courseId:assignmentId:))`.

States (handoff §Interactions): cold load → `SkeletonList` for ledger + panels, header GPA shown as a dashed placeholder (not `0.00`); error → `ContentUnavailableView` reusing the `Invalid token` → `Update Token…` affordance exactly as `CourseListView`; empty (no courses) → existing "No Active Courses"; if no feedback OR nothing awaiting, hide that panel and let the other span both columns.

`CourseSettingsStore` and `DashboardViewModel` should be created/owned where `CoursesViewModel` is (in `AppSession` or `MainWindowBody`); inject via `@Environment`/`@State` consistent with existing wiring. `StalenessLabel` moves into the sidebar footer on the Dashboard (handoff §1.5).

- [ ] **Step 1:** Build `DashboardView` with the `StreamItem`→row mapping and all states.
- [ ] **Step 2:** In `MainWindowView`, replace `case .dashboard: ComingSoonView(...)` with `DashboardView(...)`; add the `.task` that calls `vm.load(...)`; update sidebar course rows to show the current percentage right-aligned in 12pt mono (below-target courses in `lostMissing`) per handoff §1.5, keeping `LetterBadge` only on the course workspace.
- [ ] **Step 3: Build** — `swift build`, clean.
- [ ] **Step 4: Run in demo mode** and verify the four demo courses render with self-consistent bars, a term GPA, and that clicking a ledger row reveals the course grades tab.
- [ ] **Step 5: Commit**

```bash
git add CanvasApp/Views/Window/DashboardView.swift CanvasApp/Views/Window/MainWindowView.swift
git commit -m "feat(app): Dashboard detail pane wired into the window"
```

---

### Task 12: Course-scope Sandbox rail + grades-tab dock (`CanvasUI` + `CanvasApp`)

**Files:**
- Create: `Sources/CanvasUI/SandboxRail.swift`
- Modify: `CanvasApp/Views/Window/CourseWorkspaceView.swift`

**Interfaces:**
- Consumes: existing `CalculatorViewModel` (`@ObservedObject`; `liveGrade`, `liveBreakdown`, `whatIfEntries`, `targetMode`/`targetLetter`/`targetPercentInput`, `solveResult`, `ungradedItems`, `effectiveItems`), `GroupResult`, `SolveResult` (`.alreadyAchieved`/`.needed(percent:)`/`.impossible(maxPossible:)`), tokens (Task 4).
- Produces: `public struct SandboxRailView: View` — `public init(vm: CalculatorViewModel)`. A 330pt docked rail (1pt left `canvasHairline` border, `canvasPanel` bg) with: header `Sandbox` 13pt/700 + subtitle *"Drag any ungraded item. Nothing here is sent to Canvas."*; target block `I WANT TO FINISH WITH` → chips `A- | A | B+ | 90%` bound to `vm.targetMode`/`vm.targetLetter`/`vm.targetPercentInput`; the answer sentence mapping `vm.solveResult` (`.needed(p)` → "Score **\(p)%** or better …" with the percent in `accentHypothetical`; `.alreadyAchieved` → "You've already locked this in."; `.impossible(max)` → "Out of reach — the best you can finish is \(max)%."); `HYPOTHETICALS` = one `HypotheticalSlider` per active `whatIfEntry`, each showing value in `accentHypothetical` mono, and on the slider that satisfies the target a 2pt green vertical marker at the required percent with a 10.5pt green caption "green line = the \(p)% you need"; `SCENARIOS` preset chips; footer `Save scenario` (accent) · `Pin to menu bar` (outline). Sliders recompute with **no debounce**; dependent numbers animate ~180ms ease-out and nothing re-lays-out while dragging.
  - Sub-views (public): `TargetChips`, `HypotheticalSlider(label:value:required:onChange:)`, `ScenarioChips`.

**Grades-tab refactor** (`GradesTabView`): replace the `.inspector(isPresented: $showCalculator) { CalculatorView(...) }` with a horizontal split — a `@StateObject var calc = CalculatorViewModel(items:groupInfo:gradingScale:weighted:)` **owned by the tab** and passed to BOTH the main column and the rail so a slider drag updates both. Structure:
```swift
HStack(spacing: 0) {
    gradesMainColumn(calc: calc)          // headline actual→projected, GROUPS bars w/ what-if lift, ASSIGNMENTS
    if router.sandboxOpen {
        SandboxRailView(vm: calc).frame(width: 330).transition(.move(edge: .trailing).combined(with: .opacity))
    }
}
.animation(.easeInOut(duration: 0.2), value: router.sandboxOpen)
```
Toolbar `Sandbox` toggle drives `router.sandboxOpen` (replaces the `showCalculator` `@State`). Main column headline (handoff §2): `ACTUAL 89.4 → PROJECTED 92.6` (projected in `accentHypothetical`) + projected `LetterBadge`; `GROUPS` rows show real % in `letterGradeColor` with the what-if lift as an appended accent segment (compare `calc`'s base vs live breakdown); `ASSIGNMENTS` hypothetical rows get accent-tinted fill + 1pt accent border + a `what-if 91/100` accent capsule.

Note: `CalculatorView`'s current internal-VM design is not reused for the rail; leave `CalculatorView` in place (still referenced nowhere after this change is fine) or delete it if no other caller remains — grep first.

- [ ] **Step 1:** Implement `SandboxRailView` + sub-views in `CanvasUI` with previews (both schemes; include a `.needed` case showing the green marker).
- [ ] **Step 2:** Refactor `GradesTabView` to own the shared `CalculatorViewModel`, dock the rail, and wire `router.sandboxOpen`; build the actual→projected headline, group lift bars, and hypothetical assignment rows.
- [ ] **Step 3: Build** — `swift build`, clean. Grep for remaining `CalculatorView(` usages; if none, remove the type (optional) and confirm build.
- [ ] **Step 4: Run in demo mode** — open a course, toggle the rail, drag a hypothetical, confirm the headline/group bars animate and the green marker appears when the target is met.
- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasUI/SandboxRail.swift CanvasApp/Views/Window/CourseWorkspaceView.swift
git commit -m "feat: docked course-scope What-If Sandbox rail"
```

---

### Task 13: Term-scope Sandbox rail on the Dashboard (`CanvasApp`)

**Files:**
- Create: `CanvasApp/Views/Window/TermSandboxRail.swift`
- Create: `CanvasApp/ViewModels/TermScenarioViewModel.swift`
- Modify: `CanvasApp/Views/Window/DashboardView.swift`

**Interfaces:**
- Consumes: `DashboardViewModel.rows`/GPA numbers, Task 3 (`projectedTermGPA`, `gpaLift`), tokens, and the shared rail sub-views (`TargetChips`, `ScenarioChips`) from Task 12.
- Produces:
  - `@MainActor @Observable final class TermScenarioViewModel` — `var overrides: [Int: Double]` (courseId → hypothetical percent), `var targetGPA: Double` (from chips `3.5 | 3.7 | 4.0`), computed `projectedGPA: Double?` and `lift: Double?` from `[CourseGradeSummary]` (built from `DashboardViewModel.rows` + `CourseSettingsStore`), and a `reset()`.
  - `struct TermSandboxRail: View` — 296pt wide (per handoff), scope chip `TERM`; target chips are GPA values; the sentence names a course ("Pull **MATH 112** to a **B-** … That's **78%** on the final."); per-course "remaining work" sliders labeled `71.1 → 79.4 · C- → B-` driving `overrides`; a summary card `Projected GPA 3.50 · from 3.25 · +0.25`; unreachable targets stated plainly ("4.0 is out of reach — MATH caps at 85.5%." using each row's `ceilingPercent`).

`DashboardView` shows `TermSandboxRail` when `router.sandboxOpen` (same `HStack`/animation pattern as Task 12), and the header `Play it out →` toggles it.

- [ ] **Step 1:** Implement `TermScenarioViewModel` (pure recompute via Task 3 functions).
- [ ] **Step 2:** Implement `TermSandboxRail` reusing shared chips/slider styling.
- [ ] **Step 3:** Dock it in `DashboardView` behind `router.sandboxOpen`.
- [ ] **Step 4: Build** — clean.
- [ ] **Step 5: Run in demo mode** — `Play it out →`, drag a course's remaining-work slider, confirm the projected-GPA card and summary update live, and that an out-of-reach target shows the plain-language cap.
- [ ] **Step 6: Commit**

```bash
git add CanvasApp/Views/Window/TermSandboxRail.swift CanvasApp/ViewModels/TermScenarioViewModel.swift CanvasApp/Views/Window/DashboardView.swift
git commit -m "feat: term-scope What-If Sandbox on the Dashboard"
```

---

### Task 14: Settings additions (`CanvasApp`)

**Files:**
- Modify: `CanvasApp/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `CourseSettingsStore` (Task 6), `Router.dashboardDensity` (Task 5), `CoursesViewModel` (`courses`, `hide`/`restore`/`hiddenCourses`).
- Produces: Settings controls for — per-course **credit hours** (stepper/field, writes `CourseSettingsStore.setCredits`), **default dashboard view** (Cards/Ledger → `router.dashboardDensity`), **theme** (light/dark/system via `@AppStorage("appearance")` applied at the `Window` scene with `.preferredColorScheme`), **per-course target grade** (writes `setTargetGrade`, feeds the sidebar "below target" coloring), and **hidden-course management** (list with restore, using existing `CoursesViewModel.hiddenCourses`/`restore`).

- [ ] **Step 1:** Add a `Form`/`Section` block with the five controls above, bound to the stores.
- [ ] **Step 2:** Apply the theme preference at the `Window` scene (`.preferredColorScheme(...)` driven by `@AppStorage("appearance")`).
- [ ] **Step 3: Build** — clean.
- [ ] **Step 4: Run in demo mode** — change credit hours and confirm the Dashboard term GPA recomputes; toggle density and theme.
- [ ] **Step 5: Commit**

```bash
git add CanvasApp/Views/SettingsView.swift CanvasApp/App/CanvasApp.swift
git commit -m "feat(app): Settings for credits, density, theme, targets, hidden courses"
```

---

## Self-Review

**Spec coverage (handoff §-by-§):**
- §1.1 Header → Task 11. §1.2 Timeline → Task 8. §1.3 Ledger → Task 9 (view) + Task 6 (data). §1.4 Bottom panels → Task 10 + Task 11 mapping. §1.5 Sidebar percentages/footer → Task 11. §2 Course workspace + Sandbox → Task 12. §2 Dashboard-scope variant → Task 13. Interactions/States → Tasks 11–13. State Management (`DashboardViewModel`, `Router` flags, scope) → Tasks 5, 6, 12, 13. Ceiling/floor math → Task 1. GPA → Tasks 2–3. Customization (density/sandbox switches, Settings) → Tasks 5, 14. Tokens/typography → Task 4. Assets → none (SF Symbols).
- **Deferred, tracked (demo-first per user):** live `/users/self/colors`, `/courses/:id?include[]=term` term bounds, retaining per-group ungraded totals from the API, and `Save scenario`/`Pin to menu bar` persistence beyond in-memory. Called out in the Global Constraints; not Phase 1a tasks.

**Placeholder scan:** math tasks carry full test + impl code; UI tasks carry exact tokens, sizes, and layout from the handoff with build-green + demo verification (no XCTest is possible for `CanvasApp`/`CanvasUI` — the only honest verification is build + visual, stated explicitly).

**Type consistency:** `PointsLedger`(earned/lost/inPlay/total), `CourseGradeSummary`(now/ceiling/floor Percent + scale + credits), `CourseLedgerRow`, `SolveResult`(.alreadyAchieved/.needed/.impossible), `CalculatorViewModel` shared-instance dock, and `Router`(sandboxOpen/dashboardDensity) are used consistently across tasks. `CanvasUI` never imports `CanvasData` — `StreamItem` is mapped to `AwaitingRow`/`FeedbackRow` in `DashboardView` (Task 11).

**Note on task numbering:** Tasks 7 folded into Task 6 (CourseSettingsStore ships with the VM that needs it). Numbering jumps 6 → 8 intentionally; there is no Task 7.
