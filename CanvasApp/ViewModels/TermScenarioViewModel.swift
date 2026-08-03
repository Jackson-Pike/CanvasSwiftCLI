import Foundation
import CanvasCore

/// Drives the term-scope What-If Sandbox rail on the Dashboard. Holds a set of
/// per-course hypothetical percent overrides and a target GPA, and recomputes
/// projected/lift purely from `CanvasCore`'s `[CourseGradeSummary]` functions —
/// mirrors `CalculatorViewModel`'s role for the course-scope rail but at term
/// granularity (no assignment-level math here, just summary-level GPA).
@MainActor @Observable
final class TermScenarioViewModel {
    /// courseId -> hypothetical percent replacing that course's `nowPercent`.
    var overrides: [Int: Double] = [:]
    var targetGPA: Double = 3.7
    var summaries: [CourseGradeSummary] = []
    /// courseId -> course code (e.g. "MATH 112"), for labeling sliders and messages.
    /// `CourseGradeSummary` itself carries no display name, so this is fed in from
    /// `DashboardViewModel.rows` alongside `summaries`.
    var codes: [Int: String] = [:]

    var currentGPA: Double? { currentTermGPA(summaries) }
    var projectedGPA: Double? { projectedTermGPA(summaries, overrides: overrides) }
    var lift: Double? { gpaLift(summaries, overrides: overrides) }

    func setOverride(_ percent: Double?, for courseId: Int) {
        if let percent {
            overrides[courseId] = percent
        } else {
            overrides.removeValue(forKey: courseId)
        }
    }

    func reset() {
        overrides.removeAll()
    }

    /// The course with the lowest ceiling — the one capping the term GPA when a
    /// target is unreachable even at everyone's best possible finish.
    private var cappingSummary: CourseGradeSummary? {
        summaries.min { (lhs, rhs) in
            (lhs.ceilingPercent ?? .infinity) < (rhs.ceilingPercent ?? .infinity)
        }
    }

    /// Non-nil only when `targetGPA` exceeds what's reachable even in the best case
    /// (`ceilingTermGPA`), naming the course whose ceiling caps the term.
    var unreachableMessage: String? {
        guard let ceiling = ceilingTermGPA(summaries), targetGPA > ceiling else { return nil }
        guard let capping = cappingSummary, let capPercent = capping.ceilingPercent else {
            return String(format: "%.1f is out of reach this term.", targetGPA)
        }
        let code = codes[capping.courseId] ?? "a course"
        return String(format: "%.1f is out of reach — %@ caps at %.1f%%.", targetGPA, code, capPercent)
    }

    struct Suggestion {
        let code: String
        let letter: String
        let requiredPercent: Double
    }

    /// A single-course "pull this course to X" suggestion for the rail's headline
    /// sentence. Heuristic, not a solver: picks the course with the most room to
    /// improve (lowest `nowPercent`) and searches upward from its current percent
    /// for the smallest value that — held alone, with every other course at its
    /// own `nowPercent` — reaches `targetGPA`. If no single-course move reaches it,
    /// or there's nothing to suggest, returns nil rather than fabricating a number.
    var suggestion: Suggestion? {
        guard !summaries.isEmpty, ceilingTermGPA(summaries) ?? 0 >= targetGPA else { return nil }
        guard let candidate = summaries
            .filter({ $0.nowPercent != nil })
            .min(by: { ($0.nowPercent ?? 100) < ($1.nowPercent ?? 100) })
        else { return nil }

        let start = candidate.nowPercent ?? 0
        var percent = start
        while percent <= 100 {
            let projected = termGPA(summaries) { summary in
                summary.courseId == candidate.courseId ? percent : summary.nowPercent
            }
            if let projected, projected >= targetGPA {
                let code = codes[candidate.courseId] ?? "this course"
                let letter = letterGrade(for: percent, scale: candidate.scale)
                return Suggestion(code: code, letter: letter, requiredPercent: percent)
            }
            percent += 0.5
        }
        return nil
    }
}
