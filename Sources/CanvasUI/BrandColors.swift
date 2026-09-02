import SwiftUI

extension Color {
    public static let byuhRed  = Color(red: 186/255, green: 12/255,  blue: 47/255)
    public static let byuhGold = Color(red: 198/255, green: 146/255, blue: 20/255)

    public static func letterGradeColor(_ letter: String) -> Color {
        switch letter.prefix(1) {
        case "A": return Color(red: 52/255, green: 168/255, blue: 83/255)   // green
        case "B": return Color(red: 66/255, green: 133/255, blue: 244/255)  // blue
        case "C": return Color(red: 251/255, green: 188/255, blue: 4/255)   // yellow
        default:  return .byuhRed
        }
    }

    /// Ordered accent palette used to distinguish courses on the Calendar and To-Do surfaces.
    public static let courseAccentPalette: [Color] = [.blue, .purple, .orange, .green, .indigo, .pink]

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
