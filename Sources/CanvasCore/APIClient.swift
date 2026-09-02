import Foundation

public enum APIError: Error, CustomStringConvertible {
    case missingToken
    case unauthorized
    case http(Int)
    case network(String)
    case rateLimited(retryAfter: TimeInterval)
    case forbidden

    public var description: String {
        switch self {
        case .missingToken:     return "CANVAS_TOKEN is not set."
        case .unauthorized:     return "Invalid token — update in Settings."
        case .http(let code):   return "Canvas API returned HTTP \(code)."
        case .network(let msg): return "Network error: \(msg)."
        case .rateLimited:      return "Canvas is rate limiting requests — retrying shortly."
        case .forbidden:        return "Canvas denied access to this resource."
        }
    }
}

public struct APIClient {
    public let credentials: Credentials
    private let session: URLSession

    var token: String { credentials.token }
    private var baseURL: String { "https://\(credentials.host)/api/v1" }

    public init(credentials: Credentials, session: URLSession = .shared) {
        self.credentials = credentials
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
                if http.statusCode == 403 {
                    let bodyText = String(data: data, encoding: .utf8) ?? ""
                    if bodyText.contains("Rate Limit Exceeded") {
                        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 10
                        throw APIError.rateLimited(retryAfter: retryAfter)
                    } else {
                        throw APIError.forbidden
                    }
                }
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
        if token == "DEMO" { return MockData.courses }
        #endif
        let data = try await getPaginated("/courses", query: [
            URLQueryItem(name: "enrollment_state", value: "active"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "include[]", value: "syllabus_body")
        ])
        return try decoder().decode([Course].self, from: data)
    }

    public func enrollments(courseId: Int) async throws -> [Enrollment] {
        #if DEBUG
        if token == "DEMO" { return MockData.enrollments[courseId].map { [$0] } ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/enrollments", query: [
            URLQueryItem(name: "user_id", value: "self"),
            URLQueryItem(name: "include[]", value: "grades")
        ])
        return try decoder().decode([Enrollment].self, from: data)
    }

    public func assignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
        #if DEBUG
        if token == "DEMO" { return MockData.assignmentGroups[courseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/assignment_groups", query: [
            URLQueryItem(name: "include[]", value: "assignments"),
            URLQueryItem(name: "include[]", value: "rubric"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([AssignmentGroup].self, from: data)
    }

    public func submissions(courseId: Int) async throws -> [Submission] {
        #if DEBUG
        if token == "DEMO" { return MockData.submissions[courseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/students/submissions", query: [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "include[]", value: "submission_comments"),
            URLQueryItem(name: "include[]", value: "rubric_assessment"),
            URLQueryItem(name: "per_page", value: "100")
        ])
        return try decoder().decode([Submission].self, from: data)
    }

    public func announcements(courseId: Int) async throws -> [Announcement] {
        #if DEBUG
        if token == "DEMO" { return MockData.announcements[courseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/discussion_topics", query: [
            URLQueryItem(name: "only_announcements", value: "true"),
            URLQueryItem(name: "per_page", value: "50"),
        ])
        return try decoder().decode([Announcement].self, from: data)
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

    public func profile() async throws -> Profile {
        #if DEBUG
        if token == "DEMO" { return MockData.profile }
        #endif
        guard let url = URL(string: baseURL + "/users/self/profile") else {
            throw APIError.network("bad URL /users/self/profile")
        }
        let (data, _) = try await getPage(url: url)
        return try decoder().decode(Profile.self, from: data)
    }

    // MARK: - Writes (form-encoded POST/PUT)

    /// URL-form-encodes `fields` and sends them as the body. Repeated keys (e.g. recipients[])
    /// are preserved by passing them as separate tuples.
    private func sendForm(path: String, method: String, fields: [(String, String)]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw APIError.network("bad URL \(path)") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")   // RFC 3986 unreserved; everything else is percent-encoded
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s }
        request.httpBody = Data(fields.map { "\(enc($0.0))=\(enc($0.1))" }.joined(separator: "&").utf8)
        print("[APIClient] \(method) \(url)")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 401 { throw APIError.unauthorized }
                if http.statusCode == 403 { throw APIError.forbidden }
                guard (200..<300).contains(http.statusCode) else { throw APIError.http(http.statusCode) }
            }
            return data
        } catch let error as APIError { throw error }
        catch { throw APIError.network(error.localizedDescription) }
    }

    // MARK: - Conversations

    public func conversations(scope: ConversationScope) async throws -> [Conversation] {
        #if DEBUG
        if token == "DEMO" {
            switch scope {
            case .inbox:    return MockData.conversations.filter { $0.workflowState != "archived" }
            case .unread:   return MockData.conversations.filter { $0.workflowState == "unread" }
            case .archived: return MockData.conversations.filter { $0.workflowState == "archived" }
            }
        }
        #endif
        var query: [URLQueryItem] = [URLQueryItem(name: "per_page", value: "50")]
        if scope != .inbox {
            query.append(URLQueryItem(name: "scope", value: scope.rawValue))
        }
        let data = try await getPaginated("/conversations", query: query)
        return try decoder().decode([Conversation].self, from: data)
    }

    public func conversation(id: Int) async throws -> Conversation {
        #if DEBUG
        if token == "DEMO" { return MockData.conversationDetails[id] ?? MockData.conversations.first { $0.id == id }! }
        #endif
        guard let url = URL(string: baseURL + "/conversations/\(id)") else {
            throw APIError.network("bad URL /conversations/\(id)")
        }
        let (data, _) = try await getPage(url: url)
        return try decoder().decode(Conversation.self, from: data)
    }

    public func createConversation(recipientIds: [Int], subject: String, body: String) async throws -> Conversation {
        #if DEBUG
        if token == "DEMO" { return MockData.demoCreateConversation(recipientIds: recipientIds, subject: subject, body: body) }
        #endif
        var fields: [(String, String)] = recipientIds.map { ("recipients[]", String($0)) }
        fields.append(("subject", subject))
        fields.append(("body", body))
        let data = try await sendForm(path: "/conversations", method: "POST", fields: fields)
        // Canvas returns an array of conversations (one per recipient batch); take the first.
        if let list = try? decoder().decode([Conversation].self, from: data), let first = list.first { return first }
        return try decoder().decode(Conversation.self, from: data)
    }

    public func replyToConversation(id: Int, body: String) async throws -> Conversation {
        #if DEBUG
        if token == "DEMO" { return MockData.demoAppendReply(id: id, body: body) }
        #endif
        let data = try await sendForm(path: "/conversations/\(id)/add_message", method: "POST", fields: [("body", body)])
        return try decoder().decode(Conversation.self, from: data)
    }

    public func markConversationRead(id: Int) async throws {
        #if DEBUG
        if token == "DEMO" { MockData.demoMarkRead(id: id); return }
        #endif
        _ = try await sendForm(path: "/conversations/\(id)", method: "PUT",
                               fields: [("conversation[workflow_state]", "read")])
    }

    // MARK: - Discussions

    public func discussionTopics(courseId: Int) async throws -> [DiscussionTopic] {
        #if DEBUG
        if token == "DEMO" { return MockData.discussionTopics[courseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/discussion_topics", query: [
            URLQueryItem(name: "per_page", value: "50"),
        ])
        return try decoder().decode([DiscussionTopic].self, from: data)
    }

    public func discussionView(courseId: Int, topicId: Int) async throws -> DiscussionView {
        #if DEBUG
        if token == "DEMO" { return MockData.discussionViews[topicId] ?? DiscussionView(view: [], participants: []) }
        #endif
        guard let url = URL(string: baseURL + "/courses/\(courseId)/discussion_topics/\(topicId)/view") else {
            throw APIError.network("bad URL discussion view")
        }
        let (data, _) = try await getPage(url: url)
        return try decoder().decode(DiscussionView.self, from: data)
    }

    // MARK: - Planner & Calendar

    public func plannerItems(start: Date? = nil, end: Date? = nil) async throws -> [PlannerItem] {
        #if DEBUG
        if token == "DEMO" { return MockData.plannerItems }
        #endif
        var query: [URLQueryItem] = [URLQueryItem(name: "per_page", value: "50")]
        let formatter = ISO8601DateFormatter()
        if let start = start {
            query.append(URLQueryItem(name: "start_date", value: formatter.string(from: start)))
        }
        if let end = end {
            query.append(URLQueryItem(name: "end_date", value: formatter.string(from: end)))
        }
        let data = try await getPaginated("/planner/items", query: query)
        return try decoder().decode([PlannerItem].self, from: data)
    }

    public func calendarEvents(contextCodes: [String]? = nil, start: Date? = nil, end: Date? = nil) async throws -> [CalendarEvent] {
        #if DEBUG
        if token == "DEMO" { return MockData.calendarEvents }
        #endif
        var query: [URLQueryItem] = [URLQueryItem(name: "per_page", value: "50")]
        let formatter = ISO8601DateFormatter()
        if let start = start {
            query.append(URLQueryItem(name: "start_date", value: formatter.string(from: start)))
        }
        if let end = end {
            query.append(URLQueryItem(name: "end_date", value: formatter.string(from: end)))
        }
        if let codes = contextCodes {
            for code in codes {
                query.append(URLQueryItem(name: "context_codes[]", value: code))
            }
        }
        let data = try await getPaginated("/calendar_events", query: query)
        return try decoder().decode([CalendarEvent].self, from: data)
    }

    // MARK: - Modules & Content

    public func modules(courseId: Int) async throws -> [Module] {
        #if DEBUG
        if token == "DEMO" { return MockData.modules[courseId] ?? MockData.modules[MockData.csCourseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/modules", query: [
            URLQueryItem(name: "include[]", value: "items"),
            URLQueryItem(name: "per_page", value: "100"),
        ])
        return try decoder().decode([Module].self, from: data)
    }

    // MARK: - Files & Folders

    public func folders(courseId: Int) async throws -> [CanvasFolder] {
        #if DEBUG
        if token == "DEMO" { return MockData.folders[courseId] ?? MockData.folders[MockData.csCourseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/folders", query: [
            URLQueryItem(name: "per_page", value: "100"),
        ])
        return try decoder().decode([CanvasFolder].self, from: data)
    }

    public func files(courseId: Int) async throws -> [CanvasFile] {
        #if DEBUG
        if token == "DEMO" { return MockData.files[courseId] ?? MockData.files[MockData.csCourseId] ?? [] }
        #endif
        let data = try await getPaginated("/courses/\(courseId)/files", query: [
            URLQueryItem(name: "per_page", value: "100"),
        ])
        return try decoder().decode([CanvasFile].self, from: data)
    }

    public func downloadFile(url: String, to destinationURL: URL) async throws {
        #if DEBUG
        if token == "DEMO" || url.contains("demo.canvas") {
            let sampleContent = "%PDF-1.4 Demo PDF Content for Canvas Grades app Quick Look preview test."
            try sampleContent.write(to: destinationURL, atomically: true, encoding: .utf8)
            return
        }
        #endif
        guard let requestURL = URL(string: url) else {
            throw APIError.network("invalid file download URL: \(url)")
        }
        let (data, response) = try await session.data(from: requestURL)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.http(http.statusCode)
        }
        try data.write(to: destinationURL)
    }
}

