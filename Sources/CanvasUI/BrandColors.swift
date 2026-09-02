import SwiftUI

extension Color {
    public static let byuhRed  = Color(red: 186/255, green: 12/255,  blue: 47/255)
    public static let byuhGold = Color(red: 198/255, green: 146/255, blue: 20/255)

    /// Letter → muted/warm grade color. Values live as light/dark tokens in DesignTokens.
    public static func letterGradeColor(_ letter: String) -> Color {
        switch letter.prefix(1) {
        case "A": return .gradeA
        case "B": return .gradeB
        case "C": return .gradeC
        default:  return .gradeDF
        }
    }

    /// Ordered accent palette used to distinguish courses on the Calendar and To-Do surfaces.
    /// Muted/warm set (no system primaries) so course chroma never competes with the orchid signal.
    public static let courseAccentPalette: [Color] = [
        Color(red: 78/255,  green: 124/255, blue: 168/255), // muted blue
        Color(red: 62/255,  green: 138/255, blue: 134/255), // teal
        Color(red: 176/255, green: 131/255, blue: 36/255),  // ochre
        Color(red: 180/255, green: 85/255,  blue: 58/255),  // clay
        Color(red: 122/255, green: 78/255,  blue: 134/255), // muted purple
        Color(red: 90/255,  green: 106/255, blue: 207/255), // periwinkle
    ]

    /// Builds a stable `courseId → accent color` map by enumeration order, matching the palette
    /// shared across the Calendar and To-Do surfaces. Pass course IDs in display order.
    public static func courseAccentMap(courseIDs: [Int]) -> [Int: Color] {
        var map: [Int: Color] = [:]
        for (index, id) in courseIDs.enumerated() {
            map[id] = courseAccentPalette[index % courseAccentPalette.count]
        }
        return map
    }

    // Platform-appropriate system colors
    public static var secondaryLabel: Color {
        #if os(macOS)
        Color(nsColor: .secondaryLabelColor)
        #else
        Color(.secondaryLabel)
        #endif
    }

    public static var systemBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }

    public static var systemGroupedBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(.systemGroupedBackground)
        #endif
    }
}
