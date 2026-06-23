import Foundation


let token = ProcessInfo.processInfo.environment["CANVAS_TOKEN"] ?? ""


let RED   = "\u{001B}[38;2;186;12;47m"   // #ba0c2f in RGB
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

print(banner)


func fetchCourses() async throws -> Data {    

    var components = URLComponents(string: "https://byuh.instructure.com/api/v1/courses")!
    components.queryItems = [
        URLQueryItem(name: "enrollment_state", value: "active"),
        URLQueryItem(name: "per_page", value: "10")
    ]
    let url = components.url!

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}

func fetchGrades(courseId: Int) async throws -> Data {    

    var components = URLComponents(string: "https://byuh.instructure.com/api/v1/courses/\(courseId)/enrollments")!
    components.queryItems = [
        URLQueryItem(name: "user_id", value: "self"),
        URLQueryItem(name: "include[]", value: "grades")
    ]
    let url = components.url!

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}

struct Course: Codable {
    let id: Int
    let name: String
    let courseCode: String
}

struct Enrollment: Codable {
    let grades: Grades
}
struct Grades: Codable {
    let currentScore: Double?
    let currentGrade: String?
}


Task {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let data = try await fetchCourses()
    let courses = try decoder.decode([Course].self, from: data)

    for course in courses {
        print("\(course.id) — \(course.name)")
        let raw_grades = try await fetchGrades(courseId: course.id)
        let enrollments = try decoder.decode([Enrollment].self, from: raw_grades)
        for enrollment in enrollments {
            print("  Score: \(enrollment.grades.currentScore ?? 0)")
            print("  Grade: \(enrollment.grades.currentGrade ?? "N/A")")
        }
    }
}

RunLoop.main.run()



