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

func showCourseDetail(_ course: Course, client: APIClient) async throws {
    let groups: [AssignmentGroup]
    let submissions: [Submission]
    do {
        groups = try await client.assignmentGroups(courseId: course.id)
        submissions = try await client.submissions(courseId: course.id)
    } catch let error as APIError {
        print(CLEAR, terminator: ""); print(error.description); _ = readKey(); return
    }

    let items = buildGradedItems(groups: groups, submissions: submissions)
    let groupInfo = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) })
    let calc = GradeCalculator(items: items, groups: groupInfo, weighted: course.applyAssignmentGroupWeights)

    let raw = RawMode()
    defer { raw.restore() }
    while true {
        renderDashboard(course: course, calc: calc, weighted: course.applyAssignmentGroupWeights)
        switch readKey() {
        case .char("c"):
            raw.restore()
            try await runCalculator(course: course, items: items, groupInfo: groupInfo,
                                    weighted: course.applyAssignmentGroupWeights)
            raw.enter()
        case .escape, .char("b"): return
        default: break
        }
    }
}

private func renderDashboard(course: Course, calc: GradeCalculator, weighted: Bool) {
    print(CLEAR, terminator: "")
    let overall = calc.currentGrade()
    let letter = overall.map { " " + letterGrade(for: $0) } ?? ""
    print("\(BOLD)\(course.courseCode) — \(course.name)\(RESET)   \(GOLD)\(formatPercent(overall))\(letter)\(RESET)")
    print(String(repeating: "─", count: 53))
    for result in calc.groupBreakdown().sorted(by: { $0.weight > $1.weight }) {
        let name = result.name.padding(toLength: 16, withPad: " ", startingAt: 0)
        let weightLabel = weighted ? String(format: "(%.0f%%)", result.weight) : "     "
        if let pct = result.percent {
            print(" \(name) \(weightLabel)  \(formatPercent(pct))  \(progressBar(percent: pct, width: 14))  \(letterGrade(for: pct))")
        } else {
            print(" \(name) \(weightLabel)  \(GOLD)not yet graded\(RESET)")
        }
    }
    print("\n(c calculator · b back)")
}

func runCalculator(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], weighted: Bool) async throws {
    guard !items.isEmpty else {
        print(CLEAR, terminator: ""); print("No assignments found."); _ = readKey(); return
    }

    var working = items          // mutated by what-if actions
    var selected = 0
    let raw = RawMode()
    defer { raw.restore() }

    while true {
        renderCalculator(course: course, items: working, groupInfo: groupInfo, weighted: weighted, selected: selected)
        switch readKey() {
        case .up:   selected = max(0, selected - 1)
        case .down: selected = min(working.count - 1, selected + 1)
        case .enter:
            raw.restore()
            if let pct = promptPercent("What-if score for \(working[selected].name) (0–100): ") {
                working = working.applyingWhatIf(percent: pct, toAssignmentIds: [working[selected].assignmentId])
            }
            raw.enter()
        case .char("b"):
            raw.restore()
            if let pct = promptPercent("Blanket score for all ungraded (0–100): ") {
                working = working.applyingBlanketToUngraded(percent: pct)
            }
            raw.enter()
        case .char("p"):
            working = working.applyingPerfectRemaining()
        case .char("r"):
            working = items      // reset to real scores
        case .escape, .char("q"): return
        default: break
        }
    }
}

private func renderCalculator(course: Course, items: [GradedItem], groupInfo: [Int: GroupInfo], weighted: Bool, selected: Int) {
    print(CLEAR, terminator: "")
    let calc = GradeCalculator(items: items, groups: groupInfo, weighted: weighted)
    print("\(BOLD)What-if — \(course.courseCode)\(RESET)   projected \(GOLD)\(formatPercent(calc.currentGrade()))\(RESET)")
    print(String(repeating: "─", count: 53))
    for (i, item) in items.enumerated() {
        let marker = i == selected ? "\(GOLD)❯\(RESET)" : " "
        let effective = item.whatIfPoints ?? item.earnedPoints
        let pct = effective.map { item.pointsPossible > 0 ? $0 / item.pointsPossible * 100 : 0 }
        let tag = item.whatIfPoints != nil ? "\(GOLD)*\(RESET)" : " "
        print("\(marker)\(tag)\(item.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(formatPercent(pct))")
    }
    print("\n(↑/↓ select · Enter what-if · b blanket · p perfect · r reset · q exit)")
}

/// Reads a 0–100 percentage from a normal (cooked) terminal line; nil on invalid/empty.
private func promptPercent(_ message: String) -> Double? {
    print(CLEAR, terminator: "")
    print(message, terminator: "")
    guard let line = readLine(), let value = Double(line.trimmingCharacters(in: .whitespaces)) else { return nil }
    return max(0, min(100, value))
}
