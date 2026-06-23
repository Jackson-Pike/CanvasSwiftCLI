import Foundation

let RED   = "\u{001B}[38;2;186;12;47m"   // #ba0c2f
let GOLD  = "\u{001B}[38;2;198;146;20m"  // #c69214
let BOLD  = "\u{001B}[1m"
let RESET = "\u{001B}[0m"

let banner = """
\(BOLD)\(RED) ██████╗ █████╗ ███╗   ██╗██╗   ██╗ █████╗ ███████╗\(RESET)
\(BOLD)\(RED)██╔════╝██╔══██╗████╗  ██║██║   ██║██╔══██╗██╔════╝\(RESET)
\(BOLD)\(RED)██║     ███████║██╔██╗ ██║██║   ██║███████║███████╗\(RESET)
\(BOLD)\(RED)██║     ██╔══██║██║╚██╗██║╚██╗ ██╔╝██╔══██║╚════██║\(RESET)
\(BOLD)\(RED)╚██████╗██║  ██║██║ ╚████║ ╚████╔╝ ██║  ██║███████║\(RESET)
\(BOLD)\(RED) ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝  ╚═══╝  ╚═╝  ╚═╝╚══════╝\(RESET)
"""

func letterGrade(for percent: Double) -> String {
    switch percent {
    case 93...:      return "A"
    case 90..<93:    return "A-"
    case 87..<90:    return "B+"
    case 83..<87:    return "B"
    case 80..<83:    return "B-"
    case 77..<80:    return "C+"
    case 73..<77:    return "C"
    case 70..<73:    return "C-"
    case 67..<70:    return "D+"
    case 63..<67:    return "D"
    case 60..<63:    return "D-"
    default:         return "F"
    }
}

func progressBar(percent: Double, width: Int) -> String {
    let clamped = max(0, min(100, percent))
    let filled = Int((clamped / 100 * Double(width)).rounded())
    return String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
}

func formatPercent(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.1f%%", value)
}
