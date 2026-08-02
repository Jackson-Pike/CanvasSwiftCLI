import SwiftUI

/// A horizontal band showing progress through a term, with tick marks for
/// assignment due dates and a "today" marker. Pure value input — no
/// view-models, no Canvas data types.
public struct SemesterTimelineStrip: View {
    public struct Tick: Identifiable {
        public let id: Int
        public let dueAt: Date
        public let style: Style

        public enum Style {
            case graded
            case missing
            case upcoming
            case finalExam
        }

        public init(id: Int, dueAt: Date, style: Style) {
            self.id = id
            self.dueAt = dueAt
            self.style = style
        }
    }

    private let termStart: Date
    private let termEnd: Date
    private let now: Date
    private let ticks: [Tick]

    public init(termStart: Date, termEnd: Date, now: Date = .init(), ticks: [Tick]) {
        self.termStart = termStart
        self.termEnd = termEnd
        self.now = now
        self.ticks = ticks
    }

    private static let bandHeight: CGFloat = 32
    private static let markerOverhang: CGFloat = 6

    /// Fraction of the term elapsed for a given date, clamped to `0...1`.
    /// Returns `0` if the term has zero or negative duration.
    private func fraction(for date: Date) -> CGFloat {
        let totalDuration = termEnd.timeIntervalSince(termStart)
        guard totalDuration > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(termStart)
        let raw = CGFloat(elapsed / totalDuration)
        return min(max(raw, 0), 1)
    }

    private static let endDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let elapsedFraction = fraction(for: now)
                let elapsedX = width * elapsedFraction

                ZStack(alignment: .topLeading) {
                    // Band background with top+bottom hairline borders.
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.canvasRule)
                            .frame(height: 1)
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(Color.canvasRule)
                            .frame(height: 1)
                    }
                    .frame(width: width, height: Self.bandHeight)

                    // Elapsed overlay.
                    Rectangle()
                        .fill(Color.inkPrimary.opacity(0.035))
                        .frame(width: elapsedX, height: Self.bandHeight)

                    // Ticks.
                    ForEach(ticks) { tick in
                        let tickFraction = fraction(for: tick.dueAt)
                        let diameter = Self.diameter(for: tick.style)
                        Circle()
                            .fill(Self.color(for: tick.style))
                            .frame(width: diameter, height: diameter)
                            .position(x: width * tickFraction, y: Self.bandHeight / 2)
                    }

                    // Today marker.
                    Rectangle()
                        .fill(Color.inkPrimary)
                        .frame(width: 2, height: Self.bandHeight + 2 * Self.markerOverhang)
                        .position(x: elapsedX, y: Self.bandHeight / 2)
                }
                .frame(width: width, height: Self.bandHeight)
            }
            .frame(height: Self.bandHeight)
            .padding(.top, Self.markerOverhang)
            .padding(.bottom, Self.markerOverhang)

            HStack(spacing: 0) {
                Text("Week 1")
                Spacer()
                Text("today")
                Spacer()
                Text("Finals \u{00B7} \(Self.endDateFormatter.string(from: termEnd))")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Color.inkTertiary)
        }
    }

    private static func diameter(for style: Tick.Style) -> CGFloat {
        switch style {
        case .graded: return 7
        case .missing: return 9
        case .upcoming: return 9
        case .finalExam: return 12
        }
    }

    private static func color(for style: Tick.Style) -> Color {
        switch style {
        case .graded: return .inkTertiary
        case .missing: return .lostMissing
        case .upcoming: return .inkPrimary
        case .finalExam: return .inkPrimary
        }
    }
}

// MARK: - Preview

#if DEBUG
private func makeSyntheticTicks(termStart: Date) -> [SemesterTimelineStrip.Tick] {
    let calendar = Calendar.current
    func date(weeksFromStart weeks: Int) -> Date {
        calendar.date(byAdding: .day, value: weeks * 7, to: termStart) ?? termStart
    }
    return [
        .init(id: 1, dueAt: date(weeksFromStart: 1), style: .graded),
        .init(id: 2, dueAt: date(weeksFromStart: 3), style: .graded),
        .init(id: 3, dueAt: date(weeksFromStart: 5), style: .graded),
        .init(id: 4, dueAt: date(weeksFromStart: 6), style: .missing),
        .init(id: 5, dueAt: date(weeksFromStart: 9), style: .upcoming),
        .init(id: 6, dueAt: date(weeksFromStart: 16), style: .finalExam),
    ]
}

private struct SemesterTimelineStripPreviewContainer: View {
    var body: some View {
        let calendar = Calendar.current
        let termStart = calendar.date(from: DateComponents(year: 2026, month: 4, day: 27)) ?? .init()
        let termEnd = calendar.date(byAdding: .day, value: 16 * 7, to: termStart) ?? termStart
        let now = calendar.date(byAdding: .day, value: 8 * 7, to: termStart) ?? termStart
        let ticks = makeSyntheticTicks(termStart: termStart)

        SemesterTimelineStrip(termStart: termStart, termEnd: termEnd, now: now, ticks: ticks)
            .padding(24)
            .background(Color.canvasBG)
    }
}

#Preview("Semester Timeline Strip - Dark") {
    SemesterTimelineStripPreviewContainer()
        .preferredColorScheme(.dark)
}

#Preview("Semester Timeline Strip - Light") {
    SemesterTimelineStripPreviewContainer()
        .preferredColorScheme(.light)
}
#endif
