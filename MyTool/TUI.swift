import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum Key {
    case up, down, enter, escape, char(Character), other
}

/// Enters raw mode on init, restores the previous termios on deinit.
final class RawMode {
    private var original = termios()

    init() {
        tcgetattr(STDIN_FILENO, &original)
        enter()
    }

    /// (Re-)applies raw mode based on the saved original termios.
    func enter() {
        var raw = original
        raw.c_lflag &= ~(UInt(ECHO | ICANON))
        raw.c_cc.16 = 1  // VMIN  (Darwin cc_t index)
        raw.c_cc.17 = 0  // VTIME (Darwin cc_t index)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
    }

    func restore() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
    }

    deinit { restore() }
}

func readKey() -> Key {
    var byte: UInt8 = 0
    guard read(STDIN_FILENO, &byte, 1) == 1 else { return .other }
    switch byte {
    case 0x0A, 0x0D: return .enter
    case 0x1B:       // ESC — could be a bare escape or an arrow sequence
        var seq: [UInt8] = [0, 0]
        guard read(STDIN_FILENO, &seq[0], 1) == 1, seq[0] == 0x5B,  // '['
              read(STDIN_FILENO, &seq[1], 1) == 1 else { return .escape }
        switch seq[1] {
        case 0x41: return .up
        case 0x42: return .down
        default:   return .other
        }
    default:
        return .char(Character(UnicodeScalar(byte)))
    }
}

private let CLEAR = "\u{001B}[2J\u{001B}[H"

func runTUI(client: APIClient) async throws {
    let courses: [Course]
    do {
        courses = try await client.courses()
    } catch let error as APIError {
        print(error.description)
        return
    }
    guard !courses.isEmpty else { print("No active courses found."); return }

    let raw = RawMode()
    defer { raw.restore(); print(RESET) }

    var selected = 0
    while true {
        renderCourseList(courses, selected: selected)
        switch readKey() {
        case .up:    selected = max(0, selected - 1)
        case .down:  selected = min(courses.count - 1, selected + 1)
        case .enter:
            raw.restore()
            try await showCourseDetail(courses[selected], client: client)  // Task 10
            raw.enter()
        case .escape, .char("q"): return
        default: break
        }
    }
}

private func renderCourseList(_ courses: [Course], selected: Int) {
    print(CLEAR, terminator: "")
    print("\(BOLD)\(RED)Canvas — Courses\(RESET)   (↑/↓ move · Enter open · q quit)\n")
    for (i, course) in courses.enumerated() {
        let marker = i == selected ? "\(GOLD)❯ \(RESET)" : "  "
        let name = i == selected ? "\(BOLD)\(course.name)\(RESET)" : course.name
        print("\(marker)\(course.courseCode)  \(name)")
    }
}

// Temporary stub — replaced in Task 10.
func showCourseDetail(_ course: Course, client: APIClient) async throws {
    print(CLEAR, terminator: "")
    print("Detail for \(course.name) — press any key to return.")
    _ = readKey()
}
