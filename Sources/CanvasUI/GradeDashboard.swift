import SwiftUI
import CanvasCore

/// Value-driven replacement for the old `GradeDashboardView`. The caller supplies
/// `breakdown`/`overall` (typically via `calc.groupBreakdown()`/`calc.currentGrade()`)
/// instead of handing over the whole `GradeCalculator`.
public struct GradeDashboard: View {
    private let breakdown: [GroupResult]
    private let overall: Double?
    private let gradingScale: [(String, Double)]

    public init(breakdown: [GroupResult], overall: Double?, gradingScale: [(String, Double)]) {
        self.breakdown = breakdown
        self.overall = overall
        self.gradingScale = gradingScale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(breakdown, id: \.groupId) { result in
                GroupBreakdownRow(result: result, gradingScale: gradingScale)
            }
            Divider()
            HStack {
                Text("Overall").font(.headline)
                Spacer()
                if let overall {
                    Text(String(format: "%.1f%%", overall))
                        .font(.headline.monospacedDigit()).foregroundStyle(.primary)
                    LetterBadge(letter: letterGrade(for: overall, scale: gradingScale))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top)
    }
}

/// Value-driven replacement for the old `GroupRowView`.
public struct GroupBreakdownRow: View {
    private let result: GroupResult
    private let gradingScale: [(String, Double)]

    public init(result: GroupResult, gradingScale: [(String, Double)]) {
        self.result = result
        self.gradingScale = gradingScale
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(result.name)
                .font(.subheadline).lineLimit(1)
                .frame(width: 120, alignment: .leading)
            Text(String(format: "(%.0f%%)", result.weight))
                .font(.caption).foregroundStyle(.secondary)
                .frame(width: 40)
            if let pct = result.percent {
                Text(String(format: "%.1f%%", pct))
                    .font(.subheadline.monospacedDigit()).foregroundStyle(.primary)
                    .frame(width: 52, alignment: .trailing)
                let letter = letterGrade(for: pct, scale: gradingScale)
                ProgressView(value: pct, total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(Color.letterGradeColor(letter))
                    .frame(width: 80)
                    .accessibilityValue(String(format: "%.0f percent", pct))
                LetterBadge(letter: letter)
                    .frame(width: 32)
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

#Preview {
    let items = [
        GradedItem(assignmentId: 1, name: "HW 1", groupId: 1, pointsPossible: 100, earnedPoints: 92),
        GradedItem(assignmentId: 2, name: "HW 2", groupId: 1, pointsPossible: 100, earnedPoints: 88),
        GradedItem(assignmentId: 3, name: "Midterm", groupId: 2, pointsPossible: 100, earnedPoints: nil)
    ]
    let groups: [Int: GroupInfo] = [
        1: GroupInfo(name: "Homework", weight: 40),
        2: GroupInfo(name: "Exams", weight: 60)
    ]
    let calc = GradeCalculator(items: items, groups: groups, weighted: true)
    return GradeDashboard(
        breakdown: calc.groupBreakdown().sorted { $0.weight > $1.weight },
        overall: calc.currentGrade(),
        gradingScale: byuhDefaultScale
    )
}

#Preview("GroupBreakdownRow") {
    let items = [GradedItem(assignmentId: 1, name: "HW 1", groupId: 1, pointsPossible: 100, earnedPoints: 92)]
    let groups: [Int: GroupInfo] = [1: GroupInfo(name: "Homework", weight: 40)]
    let calc = GradeCalculator(items: items, groups: groups, weighted: true)
    return GroupBreakdownRow(result: calc.groupBreakdown()[0], gradingScale: byuhDefaultScale)
        .padding()
}
