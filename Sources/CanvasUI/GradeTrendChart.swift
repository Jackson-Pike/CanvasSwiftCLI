import SwiftUI
import Charts
import CanvasCore

/// A line chart of a course grade over time, with faint horizontal rules at the
/// letter-grade thresholds so a letter crossing reads straight off the plot —
/// no legend needed.
///
/// Pure value input: the caller maps its own grade snapshots into `Point`s.
/// `CanvasUI` does not depend on `CanvasData`, same as `DashboardPanels`.
public struct GradeTrendChart: View {
    public struct Point: Identifiable {
        public let id = UUID()
        public let date: Date
        public let percent: Double

        public init(date: Date, percent: Double) {
            self.date = date
            self.percent = percent
        }
    }

    private let points: [Point]
    private let gradingScale: [(String, Double)]

    /// - Parameters:
    ///   - points: Grade snapshots, in any order (sorted internally by date).
    ///   - gradingScale: `(letter, minimumPercent)` pairs, highest first —
    ///     the same shape `CalculatorViewModel` takes.
    public init(points: [Point], gradingScale: [(String, Double)]) {
        self.points = points.sorted { $0.date < $1.date }
        self.gradingScale = gradingScale
    }

    private static let chartHeight: CGFloat = 168

    /// Minimum vertical span, in percentage points, so a course that has
    /// hovered inside one letter still shows a readable band rather than a
    /// flat line filling the whole plot.
    private static let minimumSpan: Double = 10

    /// Y range: the data's own range padded out, clamped to `0...100`, and
    /// widened to `minimumSpan` if the grades barely moved.
    private var yDomain: ClosedRange<Double> {
        let percents = points.map(\.percent)
        guard let rawLow = percents.min(), let rawHigh = percents.max() else {
            return 0...100
        }
        var low = rawLow - 3
        var high = rawHigh + 3
        let span = high - low
        if span < Self.minimumSpan {
            let grow = (Self.minimumSpan - span) / 2
            low -= grow
            high += grow
        }
        return max(0, low)...min(100, max(high, low + Self.minimumSpan))
    }

    /// Thresholds that actually fall inside the visible band. The `F` floor at
    /// 0 is dropped — a rule pinned to the axis reads as a border, not a grade.
    private var visibleThresholds: [(letter: String, percent: Double)] {
        let domain = yDomain
        return gradingScale
            .filter { $0.1 > 0 && domain.contains($0.1) }
            .map { (letter: $0.0, percent: $0.1) }
    }

    public var body: some View {
        if points.count < 2 {
            emptyState
        } else {
            chart
        }
    }

    private var emptyState: some View {
        Text("Not enough history yet — check back after your next graded assignment.")
            .font(.system(size: 12))
            .foregroundStyle(Color.inkTertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, minHeight: Self.chartHeight)
    }

    private var chart: some View {
        Chart {
            ForEach(visibleThresholds, id: \.letter) { threshold in
                RuleMark(y: .value("Threshold", threshold.percent))
                    .foregroundStyle(Color.canvasHairline)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .topLeading, alignment: .leading, spacing: 1) {
                        Text(threshold.letter)
                            .font(.mono(9, weight: .medium))
                            .foregroundStyle(Color.inkTertiary)
                    }
            }

            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Grade", point.percent)
                )
                .foregroundStyle(Color.inkPrimary)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            ForEach(points) { point in
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Grade", point.percent)
                )
                .foregroundStyle(Color.inkPrimary)
                .symbolSize(28)
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let percent = value.as(Double.self) {
                        Text("\(Int(percent.rounded()))%")
                            .font(.mono(9))
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
                AxisGridLine().foregroundStyle(Color.canvasRule.opacity(0.5))
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.mono(9))
                            .foregroundStyle(Color.inkTertiary)
                    }
                }
                AxisGridLine().foregroundStyle(Color.canvasRule.opacity(0.5))
            }
        }
        .frame(height: Self.chartHeight)
    }
}

// MARK: - Preview

#if DEBUG
private func makeSyntheticPoints() -> [GradeTrendChart.Point] {
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 4)) ?? .init()
    let percents: [Double] = [78.4, 80.1, 79.6, 83.2, 85.0, 86.8, 88.5, 91.2]
    return percents.enumerated().map { index, percent in
        let date = calendar.date(byAdding: .day, value: index * 9, to: start) ?? start
        return .init(date: date, percent: percent)
    }
}

private struct GradeTrendChartPreviewContainer: View {
    var body: some View {
        GradeTrendChart(points: makeSyntheticPoints(), gradingScale: byuhDefaultScale)
            .padding(24)
            .background(Color.canvasBG)
    }
}

#Preview("Grade Trend Chart - Dark") {
    GradeTrendChartPreviewContainer()
        .preferredColorScheme(.dark)
}

#Preview("Grade Trend Chart - Light") {
    GradeTrendChartPreviewContainer()
        .preferredColorScheme(.light)
}

#Preview("Grade Trend Chart - Empty") {
    GradeTrendChart(
        points: [.init(date: .init(), percent: 92)],
        gradingScale: byuhDefaultScale
    )
    .padding(24)
    .background(Color.canvasBG)
    .preferredColorScheme(.dark)
}
#endif
