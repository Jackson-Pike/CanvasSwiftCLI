import SwiftUI
import CanvasCore

// MARK: - PointsBar

/// 15pt-tall, 3pt-corner-radius bar of three abutting segments (no gaps):
/// earned (solid `earnedBar`), lost (solid `lostMissing`), and the in-play
/// remainder (135° hatch via `InPlayHatch`).
public struct PointsBar: View {
    private let ledger: PointsLedger

    public init(ledger: PointsLedger) {
        self.ledger = ledger
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            if ledger.total > 0 {
                let earnedWidth = width * CGFloat(ledger.earned / ledger.total)
                let lostWidth = width * CGFloat(ledger.lost / ledger.total)
                let inPlayWidth = max(0, width - earnedWidth - lostWidth)

                HStack(spacing: 0) {
                    Color.earnedBar
                        .frame(width: earnedWidth)
                    Color.lostMissing
                        .frame(width: lostWidth)
                    InPlayHatch()
                        .frame(width: inPlayWidth)
                }
            } else {
                Color.barTrack
                    .frame(width: width)
            }
        }
        .frame(height: 15)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - LedgerHeaderRow

public struct LedgerHeaderRow: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            Text("COURSE")
                .frame(width: 184, alignment: .leading)
            Text("EARNED / LOST / IN PLAY")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CEILING")
                .frame(width: 86, alignment: .trailing)
            Text("FLOOR")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.sectionLabel)
        .tracking(0.9)
        .textCase(.uppercase)
        .foregroundStyle(Color.inkTertiary)
    }
}

// MARK: - LedgerRowView

public struct LedgerRowView: View {
    private let code: String
    private let name: String
    private let dotColor: Color
    private let nowPercent: Double?
    private let ledger: PointsLedger
    private let ceilingPercent: Double?
    private let ceilingLetter: String?
    private let floorPercent: Double?
    private let floorLetter: String?
    private let missingLabel: String?
    private let onTap: () -> Void

    @State private var isHovering = false

    public init(
        code: String,
        name: String,
        dotColor: Color,
        nowPercent: Double?,
        ledger: PointsLedger,
        ceilingPercent: Double?,
        ceilingLetter: String?,
        floorPercent: Double?,
        floorLetter: String?,
        missingLabel: String?,
        onTap: @escaping () -> Void
    ) {
        self.code = code
        self.name = name
        self.dotColor = dotColor
        self.nowPercent = nowPercent
        self.ledger = ledger
        self.ceilingPercent = ceilingPercent
        self.ceilingLetter = ceilingLetter
        self.floorPercent = floorPercent
        self.floorLetter = floorLetter
        self.missingLabel = missingLabel
        self.onTap = onTap
    }

    private var isMissing: Bool { missingLabel != nil }

    public var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.canvasRule)
                .frame(height: 1)

            HStack(spacing: 0) {
                courseCell
                barCell
                ceilingCell
                floorCell
            }
            .padding(.vertical, 11)
            .padding(.horizontal, isMissing ? 8 : 0)
        }
        .background(isMissing ? Color.rowHighlightMissing : Color.clear)
        .background(isHovering ? Color.inkPrimary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
    }

    private var courseCell: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(code)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
            if let missingLabel {
                Text(missingLabel)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.lostMissing)
            } else {
                Text(name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .frame(width: isMissing ? 176 : 184, alignment: .leading)
    }

    private var barCell: some View {
        VStack(alignment: .leading, spacing: 4) {
            PointsBar(ledger: ledger)
            Text(barCaption)
                .font(.mono(10))
                .foregroundStyle(Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 20)
    }

    private var barCaption: String {
        let nowText: String
        if let nowPercent {
            nowText = String(format: "%.1f", nowPercent)
        } else {
            nowText = "—"
        }
        return "now \(nowText)% · \(Int(ledger.inPlay)) pts in play"
    }

    private var ceilingCell: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(ceilingPercent.map { String(format: "%.1f", $0) } ?? "—")
                .font(.mono(16, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            Text(ceilingLetter ?? "—")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(width: 86, alignment: .trailing)
    }

    private var floorCell: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(floorPercent.map { String(format: "%.1f", $0) } ?? "—")
                .font(.mono(16, weight: .bold))
                .foregroundStyle(Color.lostMissing)
            Text(floorLetter ?? "—")
                .font(.system(size: 9.5))
                .foregroundStyle(Color.lostMissing)
        }
        .frame(width: 70, alignment: .trailing)
    }
}

// MARK: - Previews

#if DEBUG
private struct LedgerTablePreview: View {
    var body: some View {
        VStack(spacing: 0) {
            LedgerHeaderRow()
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            LedgerRowView(
                code: "CS 371",
                name: "Intro to Artificial Intelligence",
                dotColor: .accentHypothetical,
                nowPercent: 93.2,
                ledger: PointsLedger(earned: 466, lost: 24, inPlay: 110, total: 600),
                ceilingPercent: 98.4,
                ceilingLetter: "A+",
                floorPercent: 77.7,
                floorLetter: "C+",
                missingLabel: nil,
                onTap: {}
            )

            LedgerRowView(
                code: "REL 250",
                name: "Foundations of the Restoration",
                dotColor: .lostMissing,
                nowPercent: 81.4,
                ledger: PointsLedger(earned: 203, lost: 18, inPlay: 40, total: 261),
                ceilingPercent: 92.1,
                ceilingLetter: "A-",
                floorPercent: 77.8,
                floorLetter: "C+",
                missingLabel: "1 missing · Essay 3",
                onTap: {}
            )

            LedgerRowView(
                code: "MATH 112",
                name: "Calculus 2",
                dotColor: .earnedBar,
                nowPercent: nil,
                ledger: PointsLedger(earned: 0, lost: 0, inPlay: 500, total: 500),
                ceilingPercent: 100.0,
                ceilingLetter: "A+",
                floorPercent: 0.0,
                floorLetter: "F",
                missingLabel: nil,
                onTap: {}
            )

            LedgerRowView(
                code: "PHIL 105",
                name: "Introduction to Logic",
                dotColor: .accentHypothetical,
                nowPercent: 88.6,
                ledger: PointsLedger(earned: 310, lost: 40, inPlay: 0, total: 350),
                ceilingPercent: 88.6,
                ceilingLetter: "B+",
                floorPercent: 88.6,
                floorLetter: "B+",
                missingLabel: "2 missing · HW 6, HW 7",
                onTap: {}
            )
        }
        .padding(16)
        .background(Color.canvasBG)
    }
}

#Preview("Ledger Table - Light") {
    LedgerTablePreview()
        .preferredColorScheme(.light)
}

#Preview("Ledger Table - Dark") {
    LedgerTablePreview()
        .preferredColorScheme(.dark)
}
#endif
