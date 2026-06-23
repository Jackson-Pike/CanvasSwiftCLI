import ArgumentParser
import Foundation

func requireToken() throws -> String {
    let token = ProcessInfo.processInfo.environment["CANVAS_TOKEN"] ?? ""
    guard !token.isEmpty else { throw APIError.missingToken }
    return token
}

struct Canvas: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "canvas",
        abstract: "Canvas CLI for BYU–Hawaii.",
        subcommands: [Courses.self, Grades.self],
        defaultSubcommand: nil
    )

    func run() async throws {
        // No subcommand → interactive TUI (wired in Task 9). For now, list courses.
        print(banner)
        try await Courses().run()
    }
}

extension Canvas {
    struct Courses: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List active courses with current grade.")

        func run() async throws {
            let client = APIClient(token: try requireToken())
            do {
                let courses = try await client.courses()
                for course in courses {
                    let enrollments = try await client.enrollments(courseId: course.id)
                    let score = enrollments.first?.grades?.currentScore
                    print("\(BOLD)\(course.courseCode)\(RESET) — \(course.name)  \(GOLD)\(formatPercent(score))\(RESET)")
                }
            } catch let error as APIError {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
                throw ExitCode(1)
            }
        }
    }

    struct Grades: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Full grade breakdown for one course.")

        @Argument(help: "Canvas course id.") var courseId: Int

        func run() async throws {
            let client = APIClient(token: try requireToken())
            do {
                let groups = try await client.assignmentGroups(courseId: courseId)
                let submissions = try await client.submissions(courseId: courseId)
                let course = try await client.courses().first { $0.id == courseId }

                let items = buildGradedItems(groups: groups, submissions: submissions)
                let groupInfo = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight)) })
                let weighted = course?.applyAssignmentGroupWeights ?? false
                let calc = GradeCalculator(items: items, groups: groupInfo, weighted: weighted)

                let title = course.map { "\($0.courseCode) — \($0.name)" } ?? "Course \(courseId)"
                let overall = calc.currentGrade()
                let letter = overall.map { " " + letterGrade(for: $0) } ?? ""
                print("\(BOLD)\(title)\(RESET)   \(formatPercent(overall))\(letter)")
                print(String(repeating: "─", count: 53))

                for result in calc.groupBreakdown().sorted(by: { $0.weight > $1.weight }) {
                    let weightLabel = weighted ? String(format: "(%.0f%%)", result.weight) : "     "
                    if let pct = result.percent {
                        let bar = progressBar(percent: pct, width: 14)
                        print(" \(result.name.padding(toLength: 16, withPad: " ", startingAt: 0)) \(weightLabel)  \(formatPercent(pct))  \(bar)  \(letterGrade(for: pct))")
                    } else {
                        print(" \(result.name.padding(toLength: 16, withPad: " ", startingAt: 0)) \(weightLabel)  not yet graded")
                    }
                }
            } catch let error as APIError {
                FileHandle.standardError.write(Data((error.description + "\n").utf8))
                throw ExitCode(1)
            }
        }
    }
}

// Swift 6.3.2 @MainActor top-level code selects ParsableCommand.main() (sync) over
// AsyncParsableCommand.main() async via overload resolution. Dispatching through a
// detached Task forces the async overload to be selected.
let sema = DispatchSemaphore(value: 0)
Task.detached {
    await Canvas.main()
    sema.signal()
}
sema.wait()
