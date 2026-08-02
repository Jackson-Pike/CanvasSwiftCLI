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

public func projectedTermGPA(_ summaries: [CourseGradeSummary], overrides: [Int: Double]) -> Double? {
    termGPA(summaries) { overrides[$0.courseId] ?? $0.nowPercent }
}

public func gpaLift(_ summaries: [CourseGradeSummary], overrides: [Int: Double]) -> Double? {
    guard let base = currentTermGPA(summaries),
          let proj = projectedTermGPA(summaries, overrides: overrides) else { return nil }
    return proj - base
}
