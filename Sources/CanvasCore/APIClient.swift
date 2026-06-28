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
    private let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    // Fetches a single page; returns (body, nextURL)
    private func getPage(url: URL) async throws -> (Data, URL?) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        print("[APIClient] GET \(url)")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[APIClient] \(http.statusCode) \(url)")
                if http.statusCode == 401 { throw APIError.unauthorized }
                guard (200..<300).contains(http.statusCode) else {
                    if let body = String(data: data, encoding: .utf8) {
                        print("[APIClient] Error body: \(body.prefix(500))")
                    }
                    throw APIError.http(http.statusCode)
                }
                let nextURL = Self.nextPageURL(from: http)
                return (data, nextURL)
            }
            return (data, nil)
        } catch let error as APIError { throw error }
        catch let urlError as URLError where urlError.code == .cancelled { throw urlError }
        catch { throw APIError.network(error.localizedDescription) }
    }

    // Parses the `Link: <url>; rel="next"` header
    private static func nextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let link = response.value(forHTTPHeaderField: "Link") else { return nil }
        // Link header can contain multiple entries separated by ", "
        for part in link.components(separatedBy: ",") {
            let segments = part.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard segments.count >= 2 else { continue }
            let isNext = segments.dropFirst().contains(where: { $0 == "rel=\"next\"" })
            guard isNext else { continue }
            // Extract URL from angle brackets: <https://...>
            let urlPart = segments[0]
            guard urlPart.hasPrefix("<"), urlPart.hasSuffix(">") else { continue }
            let urlString = String(urlPart.dropFirst().dropLast())
            return URL(string: urlString)
        }
        return nil
    }

    // Follows Link pages and returns a single JSON array combining all pages
    private func getPaginated(_ path: String, query: [URLQueryItem]) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.network("bad URL \(path)")
        }
        components.queryItems = query
        guard let firstURL = components.url else { throw APIError.network("bad query for \(path)") }

        var allItems: [[String: Any]] = []
        var nextURL: URL? = firstURL

        while let currentURL = nextURL {
            let (pageData, pageNext) = try await getPage(url: currentURL)
            guard let pageItems = try JSONSerialization.jsonObject(with: pageData) as? [[String: Any]] else {
                throw APIError.network("Expected JSON array from Canvas API")
            }
            allItems.append(contentsOf: pageItems)
            nextURL = pageNext
        }

        return try JSONSerialization.data(withJSONObject: allItems)
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    public func courses() async throws -> [Course] {
        #if DEBUG
        if token == "DEMO" { return [MockData.course] }
        #endif
        let data = try await getPaginated("/courses", query: [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "50")
        ])
        return try decoder().decode([Course].self, from: data)
    }

    public func enrollments(courseId: Int) async throws -> [Enrollment] {
        #if DEBUG
        if token == "DEMO" { return [MockData.enrollment] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "user_id", value: "self"),
            URLQueryItem(name: "include[]", value: "grades")
        ])
        return try decoder().decode([Enrollment].self, from: data)
    }

    public func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
        #if DEBUG
        if token == "DEMO" { return MockData.assignmentGroups }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/assignment_groups", query: [
            URLQueryItem(name: "include[]", value: "assignments"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([AssignmentGroup].self, from: data)
    }

    public func submissions(courseId: Int) async throws -> [Submission] {
        #if DEBUG
        if token == "DEMO" { return MockData.submissions }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/students/submissions", query: [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "include[]", value: "submission_comments"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([Submission].self, from: data)
    }

    public func courseTeachers(courseId: Int) async throws -> [Int] {
        #if DEBUG
        if token == "DEMO" { return MockData.teacherIds }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "type[]", value: "TeacherEnrollment"),
            URLQueryItem(name: "per_page", value: "50")
        ])
        let enrollments = try decoder().decode([TeacherEnrollment].self, from: data)
        return enrollments.map { $0.userId }
    }
}
