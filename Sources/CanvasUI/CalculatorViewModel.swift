import Foundation
import CanvasCore

@MainActor
public final class CalculatorViewModel: ObservableObject {
    public let baseItems: [GradedItem]
    public let groupInfo: [Int: GroupInfo]
    public let gradingScale: [(String, Double)]
    public let weighted: Bool

    @Published public var whatIfEntries: [Int: WhatIfEntry] = [:]

    // Solve For Me
    @Published public var targetMode: TargetMode = .letter
    @Published public var targetLetter: String = "A"
    @Published public var targetPercentInput: String = "90"
    @Published public var solveScope: SolveScope = .single
    @Published public var solveSingleId: Int?
    @Published public var solveMultiIds: Set<Int> = []

    public enum TargetMode { case letter, percent }
    public enum SolveScope  { case single, spread }

    public struct WhatIfEntry {
        public var isActive: Bool
        public var inputText: String
        public var inputMode: InputMode

        public enum InputMode { case points, percent }

        public init(isActive: Bool = false, inputText: String = "", inputMode: InputMode = .percent) {
            self.isActive = isActive
            self.inputText = inputText
            self.inputMode = inputMode
        }

        public func resolvedPercent(possiblePoints: Double) -> Double? {
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

        public func resolvedPoints(possiblePoints: Double) -> Double? {
            guard let pct = resolvedPercent(possiblePoints: possiblePoints) else { return nil }
            return possiblePoints * pct / 100
        }
    }

    public init(items: [GradedItem], groupInfo: [Int: GroupInfo], gradingScale: [(String, Double)], weighted: Bool) {
        self.baseItems = items
        self.groupInfo = groupInfo
        self.gradingScale = gradingScale
        self.weighted = weighted
        if let first = items.filter({ $0.earnedPoints == nil }).first {
            solveSingleId = first.assignmentId
        }
    }

    public var effectiveItems: [GradedItem] {
        baseItems.map { item in
            guard let entry = whatIfEntries[item.assignmentId],
                  let pct = entry.resolvedPercent(possiblePoints: item.pointsPossible) else { return item }
            var copy = item
            copy.whatIfPoints = item.pointsPossible * pct / 100
            return copy
        }
    }

    public var liveCalculator: GradeCalculator {
        GradeCalculator(items: effectiveItems, groups: groupInfo,
                        weighted: weighted, gradingScale: gradingScale)
    }

    public var liveGrade: Double? { liveCalculator.currentGrade() }
    public var liveBreakdown: [GroupResult] { liveCalculator.groupBreakdown().sorted { $0.weight > $1.weight } }

    public var targetPercentValue: Double {
        switch targetMode {
        case .percent: return Double(targetPercentInput) ?? 90.0
        case .letter:  return gradingScale.first(where: { $0.0 == targetLetter })?.1 ?? 90.0
        }
    }

    public var solveAssignmentIds: Set<Int> {
        switch solveScope {
        case .single:  return solveSingleId.map { [$0] } ?? []
        case .spread:  return solveMultiIds
        }
    }

    public var solveResult: SolveResult? {
        guard !solveAssignmentIds.isEmpty else { return nil }
        return liveCalculator.solveForTarget(targetPercent: targetPercentValue,
                                              solveAssignmentIds: solveAssignmentIds)
    }

    public var ungradedItems: [GradedItem] {
        baseItems.filter { $0.earnedPoints == nil }
    }

    public func gradeLetter(for item: GradedItem) -> String? {
        guard let earned = item.earnedPoints, item.pointsPossible > 0 else { return nil }
        return letterGrade(for: earned / item.pointsPossible * 100, scale: gradingScale)
    }
}
