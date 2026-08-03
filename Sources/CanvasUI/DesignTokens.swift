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
        dark: NSColor(hex: "#17161A")
    )

    static let canvasPanel = dynamic(
        light: NSColor(hex: "#F1EFEB"),
        dark: NSColor(hex: "#131217")
    )

    /// Hairline / rule tokens (rgba-alpha based)
    static let canvasHairline = dynamic(
        light: NSColor(hex: "#000000", alpha: 0.07),
        dark: NSColor(hex: "#FFFFFF", alpha: 0.07)
    )

    static let canvasHairlineStrong = dynamic(
        light: NSColor(hex: "#000000", alpha: 0.09),
        dark: NSColor(hex: "#FFFFFF", alpha: 0.09)
    )

    static let canvasRule = dynamic(
        light: NSColor(hex: "#000000", alpha: 0.13),
        dark: NSColor(hex: "#FFFFFF", alpha: 0.12)
    )

    /// Ink (text) tokens
    static let inkPrimary = dynamic(
        light: NSColor(hex: "#17161A"),
        dark: NSColor(hex: "#EDEBF2")
    )

    static let inkSecondary = dynamic(
        light: NSColor(hex: "#57545E"),
        dark: NSColor(hex: "#C6C2D2")
    )

    static let inkTertiary = dynamic(
        light: NSColor(hex: "#8B8894"),
        dark: NSColor(hex: "#9C98A8")
    )

    static let inkQuaternary = dynamic(
        light: NSColor(hex: "#8B8894"),
        dark: NSColor(hex: "#6B6878")
    )

    /// Accent / semantic tokens
    static let accentHypothetical = dynamic(
        light: NSColor(hex: "#5A4FCF"),
        dark: NSColor(hex: "#7A6EFF")
    )

    static let onAccent = dynamic(
        light: NSColor(hex: "#FFFFFF"),
        dark: NSColor(hex: "#0F0E12")
    )

    static let lostMissing = dynamic(
        light: NSColor(hex: "#C2410C"),
        dark: NSColor(hex: "#E2703A")
    )

    static let earnedBar = dynamic(
        light: NSColor(hex: "#2B2833"),
        dark: NSColor(hex: "#EDEBF2")
    )

    static let barTrack = dynamic(
        light: NSColor(hex: "#ECE9E3"),
        dark: NSColor(hex: "#2A2833")
    )

    static let rowHighlightMissing = dynamic(
        light: NSColor(hex: "#C2410C", alpha: 0.06),
        dark: NSColor(hex: "#E2703A", alpha: 0.09)
    )

    /// Course codes / big GPA numeral — pure white on dark, near-black on light.
    static let gpaCodeWhite = dynamic(
        light: NSColor(hex: "#17161A"),
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
    /// Large numeral / headline display type. Callers apply `.tracking(-0.03 * size)`.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Monospaced-digit numeral type for tabular figures (scores, percentages).
    static func mono(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }

    /// Small uppercase section label type. Callers apply `.tracking(...)` and
    /// `.textCase(.uppercase)`.
    static var sectionLabel: Font {
        .system(size: 10.5, weight: .bold)
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
            Text("DESIGN TOKENS")
                .font(.sectionLabel)
                .tracking(0.6)
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
