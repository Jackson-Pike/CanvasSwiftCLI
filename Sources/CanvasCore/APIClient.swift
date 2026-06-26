import Foundation

public enum APIError: Error, CustomStringConvertible {
    case missingToken
    case unauthorized
    case http(Int)
    case network(String)

    public var description: String {
        switch self {
        case .missingToken:     return "CANVAS_TOKEN is not set."
        case .unauthorized:     return "Invalid token — update in Settings."
        case .http(let code):   return "Canvas API returned HTTP \(code)."
        case .network(let msg): return "Network error: \(msg)."
        }
    }
}

public struct APIClient {
    let token: String
    private let baseURL = "https://byuh.instructure.com/api/v1"

    public init(token: String) { self.token = token }

    private func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.network("bad URL \(path)")
        }
        components.queryItems = query
        guard let url = components.url else { throw APIError.network("bad query for \(path)") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 { throw APIError.unauthorized }
                guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
            }
            return data
        } catch let error as APIError { throw error }
        catch { throw APIError.network(error.localizedDescription) }
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    public func courses() async throws -> [Course] {
        let data = try await get("/courses", query: [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "50")
        ])
        return try decoder().decode([Course].self, from: data)
    }

    public func enrollments(courseId: Int) async throws -> [Enrollment] {
        let data = try await get("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "user_id", value: "self"),
            URLQueryItem(name: "include[]", value: "grades")
        ])
        return try decoder().decode([Enrollment].self, from: data)
    }

    public func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
        let data = try await get("/courses/\(courseId)/assignment_groups", query: [
            URLQueryItem(name: "include[]", value: "assignments"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([AssignmentGroup].self, from: data)
    }

    public func submissions(courseId: Int) async throws -> [Submission] {
        let data = try await get("/courses/\(courseId)/students/submissions", query: [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([Submission].self, from: data)
    }
}
