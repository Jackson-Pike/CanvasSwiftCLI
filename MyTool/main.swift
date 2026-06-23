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
    let url = URL(string: "https://byuh.instructure.com/api/v1/courses")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, _) = try await URLSession.shared.data(for: request)
    return data
}

let data = try await fetchCourses()
let json = String(data: data, encoding: .utf8)!
print(json)



