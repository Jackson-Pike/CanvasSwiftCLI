import SwiftUI
import AppKit

// MARK: - Dynamic color helper

private func dynamic(light: NSColor, dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    })
}

// MARK: - NSColor hex convenience

private extension NSColor {
    /// Parses a `#RRGGBB` hex string. Alpha is supplied separately since several
    /// design tokens are expressed as `rgba(r,g,b,a)` rather than 8-digit hex.
    convenience init(hex: String, alpha: CGFloat = 1.0) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexString = hexString.replacingOccurrences(of: "#", with: "")

        var rgbValue: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgbValue)

        let red   = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue  = CGFloat(rgbValue & 0x0000FF) / 255.0

        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }
}

// MARK: - Design tokens

public extension Color {
    /// Surface / background tokens
    static let canvasBG = dynamic(
        light: NSColor(hex: "#FBFAF8"),
        dark: NSColor(hex: "#1A1917")
    )

    static let canvasPanel = dynamic(
        light: NSColor(hex: "#F2EFEA"),
        dark: NSColor(hex: "#141311")
    )

    /// Raised surface — one step up from the ground, for row separation without cards.
    static let canvasRaised = dynamic(
        light: NSColor(hex: "#FFFFFF"),
        dark: NSColor(hex: "#232120")
    )

    /// Hairline / rule tokens (warm-tinted, rgba-alpha based)
    static let canvasHairline = dynamic(
        light: NSColor(hex: "#28221A", alpha: 0.11),
        dark: NSColor(hex: "#F5F0E9", alpha: 0.10)
    )

    static let canvasHairlineStrong = dynamic(
        light: NSColor(hex: "#28221A", alpha: 0.18),
        dark: NSColor(hex: "#F5F0E9", alpha: 0.18)
    )

    static let canvasRule = dynamic(
        light: NSColor(hex: "#28221A", alpha: 0.22),
        dark: NSColor(hex: "#F5F0E9", alpha: 0.24)
    )

    /// Ink (text) tokens — warm-neutral; the lavender tint is retired so orchid is the only chroma.
    static let inkPrimary = dynamic(
        light: NSColor(hex: "#1B1A17"),
        dark: NSColor(hex: "#EDEBE6")
    )

    static let inkSecondary = dynamic(
        light: NSColor(hex: "#5A554E"),
        dark: NSColor(hex: "#B7B1A8")
    )

    static let inkTertiary = dynamic(
        light: NSColor(hex: "#8E887E"),
        dark: NSColor(hex: "#857F76")
    )

    static let inkQuaternary = dynamic(
        light: NSColor(hex: "#A7A196"),
        dark: NSColor(hex: "#6E6960")
    )

    /// Accent / semantic tokens
    static let accentHypothetical = dynamic(
        light: NSColor(hex: "#8C43B0"),
        dark: NSColor(hex: "#C089E0")
    )

    static let onAccent = dynamic(
        light: NSColor(hex: "#FFFFFF"),
        dark: NSColor(hex: "#100F14")
    )

    /// Letter-grade spectrum — muted / warm, replacing Google Material.
    static let gradeA = dynamic(
        light: NSColor(hex: "#3F7A5C"),
        dark: NSColor(hex: "#6FB58F")
    )

    static let gradeB = dynamic(
        light: NSColor(hex: "#4E7CA8"),
        dark: NSColor(hex: "#7FA9CE")
    )

    static let gradeC = dynamic(
        light: NSColor(hex: "#B08324"),
        dark: NSColor(hex: "#D6A544")
    )

    static let gradeDF = dynamic(
        light: NSColor(hex: "#B23A2A"),
        dark: NSColor(hex: "#E0705A")
    )

    static let lostMissing = dynamic(
        light: NSColor(hex: "#B23A2A"),
        dark: NSColor(hex: "#E0705A")
    )

    static let earnedBar = dynamic(
        light: NSColor(hex: "#2A2723"),
        dark: NSColor(hex: "#EDEBE6")
    )

    static let barTrack = dynamic(
        light: NSColor(hex: "#ECE7DF"),
        dark: NSColor(hex: "#26231F")
    )

    static let rowHighlightMissing = dynamic(
        light: NSColor(hex: "#B23A2A", alpha: 0.06),
        dark: NSColor(hex: "#E0705A", alpha: 0.09)
    )

    /// Course codes / big GPA numeral — pure white on dark, near-black on light.
    static let gpaCodeWhite = dynamic(
        light: NSColor(hex: "#1B1A17"),
        dark: .white
    )
}

// MARK: - In-play hatch pattern

/// Diagonal 135° hatch (5pt on / 5pt off) used as a bar-segment background to
/// indicate "in-play" / hypothetical values that haven't landed yet.
public struct InPlayHatch: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        Canvas { context, size in
            let lineColor: Color = colorScheme == .dark
                ? Color.white.opacity(0.14)
                : Color(nsColor: NSColor(hex: "#D9D5CC"))
            let backgroundTint: Color = colorScheme == .dark
                ? Color.white.opacity(0.04)
                : Color(nsColor: NSColor(hex: "#F3F1EC"))

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(backgroundTint))

            // Perpendicular period (measured across the stripe direction) should be
            // 10pt (5pt stroke + 5pt gap). Because lines are offset purely along the
            // x-axis at a 45° angle, the x-axis increment must be the perpendicular
            // period divided by sin(45°) to yield the correct perpendicular spacing.
            let perpendicularPeriod: CGFloat = 10 // 5pt on, 5pt off
            let stripeSpacing: CGFloat = perpendicularPeriod * 1.41421356237 // / sin(45°)
            let lineWidth: CGFloat = 5
            let diagonal = size.width + size.height

            var path = Path()
            var offset: CGFloat = -diagonal
            while offset < diagonal {
                // 135° diagonal stripe: from top-left-ish to bottom-right-ish, shifted along x.
                let start = CGPoint(x: offset, y: 0)
                let end = CGPoint(x: offset + size.height, y: size.height)
                path.move(to: start)
                path.addLine(to: end)
                offset += stripeSpacing
            }

            context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

// MARK: - Typography

public extension Font {
    /// Large numeral / headline display type — New York (serif). Callers apply `.tracking(-0.03 * size)`.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    /// Monospaced-digit numeral type for tabular figures (scores, percentages).
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// Section-label / eyebrow type — New York (serif) small-caps. Feed it title-case text
    /// (e.g. `"Term GPA"`); small-caps renders the editorial caps and acronyms stay full-cap.
    /// No `.textCase(.uppercase)` or heavy `.tracking(...)` needed at call sites.
    static var sectionLabel: Font {
        .system(size: 11.5, weight: .semibold, design: .serif).smallCaps()
    }
}

// MARK: - Layout helpers

public extension View {
    /// Flat list row: content sits on the ground and is separated by a single bottom
    /// hairline instead of a bordered card. Selection paints a subtle orchid wash.
    /// "Paper & Signal" prefers hairlines over per-row cards.
    func hairlineRow(selected: Bool = false) -> some View {
        self
            .background(selected ? Color.accentHypothetical.opacity(0.10) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.canvasHairline).frame(height: 1)
            }
    }
}

// MARK: - Previews

#if DEBUG
private struct SwatchRow: View {
    let name: String
    let color: Color

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 32, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.canvasRule, lineWidth: 1)
                )
            Text(name)
                .font(.mono(11))
                .foregroundStyle(Color.inkPrimary)
            Spacer()
        }
    }
}

private struct DesignTokenSwatches: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Design Tokens")
                .font(.sectionLabel)
                .foregroundStyle(Color.inkSecondary)

            SwatchRow(name: "canvasBG", color: .canvasBG)
            SwatchRow(name: "canvasPanel", color: .canvasPanel)
            SwatchRow(name: "canvasHairline", color: .canvasHairline)
            SwatchRow(name: "canvasHairlineStrong", color: .canvasHairlineStrong)
            SwatchRow(name: "canvasRule", color: .canvasRule)
            SwatchRow(name: "inkPrimary", color: .inkPrimary)
            SwatchRow(name: "inkSecondary", color: .inkSecondary)
            SwatchRow(name: "inkTertiary", color: .inkTertiary)
            SwatchRow(name: "inkQuaternary", color: .inkQuaternary)
            SwatchRow(name: "accentHypothetical", color: .accentHypothetical)
            SwatchRow(name: "onAccent", color: .onAccent)
            SwatchRow(name: "lostMissing", color: .lostMissing)
            SwatchRow(name: "earnedBar", color: .earnedBar)
            SwatchRow(name: "barTrack", color: .barTrack)
            SwatchRow(name: "rowHighlightMissing", color: .rowHighlightMissing)
            SwatchRow(name: "gpaCodeWhite", color: .gpaCodeWhite)

            Text("InPlayHatch")
                .font(.mono(11))
                .foregroundStyle(Color.inkPrimary)
            InPlayHatch()
                .frame(width: 120, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(16)
        .background(Color.canvasBG)
    }
}

#Preview("Design Tokens - Light") {
    DesignTokenSwatches()
        .preferredColorScheme(.light)
}

#Preview("Design Tokens - Dark") {
    DesignTokenSwatches()
        .preferredColorScheme(.dark)
}
#endif
