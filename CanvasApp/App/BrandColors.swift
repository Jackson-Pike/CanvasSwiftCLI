import SwiftUI

extension Color {
    static let byuhRed  = Color(red: 186/255, green: 12/255,  blue: 47/255)
    static let byuhGold = Color(red: 198/255, green: 146/255, blue: 20/255)

    static func letterGradeColor(_ letter: String) -> Color {
        switch letter.prefix(1) {
        case "A": return Color(red: 52/255, green: 168/255, blue: 83/255)   // green
        case "B": return Color(red: 66/255, green: 133/255, blue: 244/255)  // blue
        case "C": return Color(red: 251/255, green: 188/255, blue: 4/255)   // yellow
        default:  return .byuhRed
        }
    }
}
