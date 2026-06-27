# Instructor Messaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a mail-icon toolbar button to `CourseDetailView` that opens a sheet where students can compose and send a Canvas Conversation message to their instructor(s).

**Architecture:** `APIClient` gains two new methods (`courseTeachers` GET, `sendConversation` POST). `CourseDetailViewModel` fetches teacher IDs in parallel with grades and caches them. A new `ComposeMessageViewModel` owns compose state; a new `ComposeMessageSheet` presents the form in a sheet triggered by the toolbar button in `CourseDetailView`.

**Tech Stack:** Swift 6, SwiftUI, async/await, Canvas REST API, XCTest + URLProtocol stubs

## Global Constraints

- macOS only — iOS deferred; no `#if os(iOS)` guards needed for new code
- Base URL is `https://byuh.instructure.com/api/v1` (defined in `APIClient`)
- Authorization: `Bearer <token>` header on every request
- `APIClient` uses `convertFromSnakeCase` JSON decoding
- New `CanvasCore` types must be `public`; new app-layer types are internal
- `swift build` must pass after every task; `swift test` must pass after Task 1

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `Sources/CanvasCore/Models.swift` | Modify | Add `TeacherEnrollment` struct |
| `Sources/CanvasCore/APIClient.swift` | Modify | Add `courseTeachers()` + `sendConversation()` |
| `Tests/CanvasCoreTests/GradeCalculatorTests.swift` | Modify | Fix pre-existing `Submission` init call (missing args) |
| `Tests/CanvasCoreTests/APIClientMessagingTests.swift` | Create | Tests for new API methods |
| `CanvasApp/ViewModels/CourseDetailViewModel.swift` | Modify | Add `instructorIds`, parallel teacher fetch |
| `CanvasApp/ViewModels/ComposeMessageViewModel.swift` | Create | Compose state + send logic |
| `CanvasApp/Views/ComposeMessageSheet.swift` | Create | Sheet UI for compose form |
| `CanvasApp/Views/CourseDetailView.swift` | Modify | Toolbar button + sheet presentation |

---

### Task 1: Fix pre-existing test breakage + add `TeacherEnrollment` model and `courseTeachers()` to `APIClient`

**Files:**
- Modify: `Sources/CanvasCore/Models.swift`
- Modify: `Sources/CanvasCore/APIClient.swift`
- Modify: `Tests/CanvasCoreTests/GradeCalculatorTests.swift`
- Create: `Tests/CanvasCoreTests/APIClientMessagingTests.swift`

**Interfaces:**
- Produces: `public struct TeacherEnrollment: Decodable { public let userId: Int }`
- Produces: `public func courseTeachers(courseId: Int) async throws -> [Int]`

---

- [ ] **Step 1: Fix the pre-existing test breakage in `GradeCalculatorTests.swift`**

`Submission` gained `userId`, `gradedAt`, `submittedAt`, `submissionComments` fields but the test was not updated. Open `Tests/CanvasCoreTests/GradeCalculatorTests.swift` and change line 12:

```swift
// Before:
let subs = [Submission(id: 1, assignmentId: 100, score: 8, workflowState: "graded")]

// After:
let subs = [Submission(id: 1, userId: 0, assignmentId: 100, score: 8,
                       workflowState: "graded", gradedAt: nil,
                       submittedAt: nil, submissionComments: nil)]
```

- [ ] **Step 2: Verify tests now compile and pass**

```bash
swift test --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Build complete!` and all existing tests pass. If other `Submission(...)` calls fail elsewhere, apply the same fix pattern.

- [ ] **Step 3: Add `TeacherEnrollment` to `Models.swift`**

At the bottom of `Sources/CanvasCore/Models.swift`, add:

```swift
public struct TeacherEnrollment: Decodable {
    public let userId: Int
}
```

- [ ] **Step 4: Add `courseTeachers()` to `APIClient.swift`**

Inside the `APIClient` struct in `Sources/CanvasCore/APIClient.swift`, add after the `submissions()` method:

```swift
public func courseTeachers(courseId: Int) async throws -> [Int] {
    let data = try await getPaginated("/courses/\(courseId)/enrollments", query: [
        URLQueryItem(name: "type[]", value: "TeacherEnrollment"),
        URLQueryItem(name: "per_page", value: "50")
    ])
    let enrollments = try decoder().decode([TeacherEnrollment].self, from: data)
    return enrollments.map { $0.userId }
}
```

- [ ] **Step 5: Write the failing test for `courseTeachers()`**

Create `Tests/CanvasCoreTests/APIClientMessagingTests.swift`:

```swift
import XCTest
@testable import CanvasCore

final class APIClientMessagingTests: XCTestCase {

    var session: URLSession!
    var client: APIClient!

    override func setUp() {
        super.setUp()
        PaginationStub.pages = [:]
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PaginationStub.self]
        session = URLSession(configuration: config)
        client = APIClient(token: "test-token", session: session)
    }

    func testCourseTeachersReturnsUserIds() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/5/enrollments?type%5B%5D=TeacherEnrollment&per_page=50"
        PaginationStub.pages[url] = (
            """
            [{"id":99,"user_id":42,"type":"TeacherEnrollment"},
             {"id":100,"user_id":43,"type":"TeacherEnrollment"}]
            """.data(using: .utf8)!,
            nil
        )

        let ids = try await client.courseTeachers(courseId: 5)
        XCTAssertEqual(ids, [42, 43])
    }

    func testCourseTeachersEmptyWhenNoTeachers() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/5/enrollments?type%5B%5D=TeacherEnrollment&per_page=50"
        PaginationStub.pages[url] = ("[]".data(using: .utf8)!, nil)

        let ids = try await client.courseTeachers(courseId: 5)
        XCTAssertEqual(ids, [])
    }
}
```

- [ ] **Step 6: Run the new test to verify it fails (method exists but URL encoding may differ)**

```bash
swift test --package-path /Users/kahuku-air/Developer/CanvasCLISwift --filter APIClientMessagingTests 2>&1 | tail -15
```

If the test fails due to URL query parameter ordering, inspect the printed URL in the output and adjust the `url` constant in the test to match exactly. Re-run until the test passes.

- [ ] **Step 7: Verify all tests pass**

```bash
swift test --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Test Suite 'All tests' passed`

- [ ] **Step 8: Commit**

```bash
git add Sources/CanvasCore/Models.swift Sources/CanvasCore/APIClient.swift \
        Tests/CanvasCoreTests/GradeCalculatorTests.swift \
        Tests/CanvasCoreTests/APIClientMessagingTests.swift
git commit -m "feat: add TeacherEnrollment model and courseTeachers() to APIClient"
```

---

### Task 2: Add `sendConversation()` to `APIClient`

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`
- Modify: `Tests/CanvasCoreTests/APIClientMessagingTests.swift`

**Interfaces:**
- Consumes: existing `session: URLSession`, `token: String`, `baseURL` from `APIClient`
- Produces: `public func sendConversation(recipientIds: [Int], subject: String, body: String) async throws`

---

- [ ] **Step 1: Write the failing test for `sendConversation()`**

Add a `RequestCapturingStub` and tests to `Tests/CanvasCoreTests/APIClientMessagingTests.swift`. Append after the existing class (not inside it):

```swift
final class RequestCapturingStub: URLProtocol {
    static var capturedRequest: URLRequest?
    static var capturedBody: Data?
    static var statusCode: Int = 201

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        RequestCapturingStub.capturedRequest = request
        RequestCapturingStub.capturedBody = request.httpBody
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: RequestCapturingStub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class SendConversationTests: XCTestCase {

    var session: URLSession!
    var client: APIClient!

    override func setUp() {
        super.setUp()
        RequestCapturingStub.capturedRequest = nil
        RequestCapturingStub.capturedBody = nil
        RequestCapturingStub.statusCode = 201
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RequestCapturingStub.self]
        session = URLSession(configuration: config)
        client = APIClient(token: "test-token", session: session)
    }

    func testSendConversationPostsToCorrectEndpoint() async throws {
        try await client.sendConversation(recipientIds: [42], subject: "Hello", body: "Hi there")

        let req = try XCTUnwrap(RequestCapturingStub.capturedRequest)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertTrue(req.url?.absoluteString.contains("/conversations") == true)
    }

    func testSendConversationIncludesRecipientsAndBody() async throws {
        try await client.sendConversation(recipientIds: [42, 43], subject: "Test", body: "Message")

        let bodyData = try XCTUnwrap(RequestCapturingStub.capturedBody)
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        let recipients = json?["recipients"] as? [String]
        XCTAssertEqual(Set(recipients ?? []), Set(["42", "43"]))
        XCTAssertEqual(json?["subject"] as? String, "Test")
        XCTAssertEqual(json?["body"] as? String, "Message")
        XCTAssertEqual(json?["group_conversation"] as? Bool, false)
    }

    func testSendConversationThrowsOnErrorStatus() async {
        RequestCapturingStub.statusCode = 422
        do {
            try await client.sendConversation(recipientIds: [1], subject: "s", body: "b")
            XCTFail("Expected throw")
        } catch APIError.http(let code) {
            XCTAssertEqual(code, 422)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}
```

- [ ] **Step 2: Run to verify tests fail**

```bash
swift test --package-path /Users/kahuku-air/Developer/CanvasCLISwift --filter SendConversationTests 2>&1 | tail -10
```

Expected: compile error — `sendConversation` not yet defined.

- [ ] **Step 3: Implement `sendConversation()` in `APIClient.swift`**

Add after `courseTeachers()` in `Sources/CanvasCore/APIClient.swift`:

```swift
public func sendConversation(recipientIds: [Int], subject: String, body: String) async throws {
    guard let url = URL(string: baseURL + "/conversations") else {
        throw APIError.network("bad URL for /conversations")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload: [String: Any] = [
        "recipients": recipientIds.map { String($0) },
        "subject": subject,
        "body": body,
        "group_conversation": false
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (_, response) = try await session.data(for: request)
    if let http = response as? HTTPURLResponse {
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }
    }
}
```

- [ ] **Step 4: Run all tests**

```bash
swift test --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Test Suite 'All tests' passed`

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/APIClient.swift Tests/CanvasCoreTests/APIClientMessagingTests.swift
git commit -m "feat: add sendConversation() POST method to APIClient"
```

---

### Task 3: Add `instructorIds` to `CourseDetailViewModel` with parallel teacher fetch

**Files:**
- Modify: `CanvasApp/ViewModels/CourseDetailViewModel.swift`

**Interfaces:**
- Consumes: `client.courseTeachers(courseId:) async throws -> [Int]` from Task 1
- Produces: `@Published var instructorIds: [Int] = []` on `CourseDetailViewModel`

---

- [ ] **Step 1: Add `instructorIds` published property**

In `CanvasApp/ViewModels/CourseDetailViewModel.swift`, add after `@Published var error: String?`:

```swift
@Published var instructorIds: [Int] = []
```

- [ ] **Step 2: Fetch teachers in parallel inside `fetch()`**

Replace the existing `async let` block at the top of `fetch(client:force:)`:

```swift
// Before:
async let groups = client.assignmentGroups(courseId: course.id)
async let subs   = client.submissions(courseId: course.id)
let (fetchedGroups, fetchedSubs) = try await (groups, subs)

// After:
async let teachersFetch = client.courseTeachers(courseId: course.id)
async let groups        = client.assignmentGroups(courseId: course.id)
async let subs          = client.submissions(courseId: course.id)

let fetchedTeachers             = (try? await teachersFetch) ?? []
let (fetchedGroups, fetchedSubs) = try await (groups, subs)
```

- [ ] **Step 3: Assign the result after the parallel fetch**

After the `let (fetchedGroups, fetchedSubs)` line, add:

```swift
instructorIds = fetchedTeachers
```

Place it before `let info = Dictionary(...)` to keep the assignment close to the fetch.

- [ ] **Step 4: Verify it builds**

```bash
swift build --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add CanvasApp/ViewModels/CourseDetailViewModel.swift
git commit -m "feat: fetch and cache instructor IDs alongside grade data in CourseDetailViewModel"
```

---

### Task 4: Create `ComposeMessageViewModel`

**Files:**
- Create: `CanvasApp/ViewModels/ComposeMessageViewModel.swift`

**Interfaces:**
- Consumes: `APIClient.sendConversation(recipientIds:subject:body:)` from Task 2
- Produces:
  - `@Published var subject: String`
  - `@Published var body: String`
  - `@Published var isSending: Bool`
  - `@Published var sendError: String?`
  - `@Published var didSend: Bool`
  - `func send(client: APIClient, recipientIds: [Int]) async`

---

- [ ] **Step 1: Create the file**

Create `CanvasApp/ViewModels/ComposeMessageViewModel.swift`:

```swift
import Foundation
import CanvasCore

@MainActor
final class ComposeMessageViewModel: ObservableObject {
    @Published var subject: String = ""
    @Published var body: String = ""
    @Published var isSending = false
    @Published var sendError: String?
    @Published var didSend = false

    func send(client: APIClient, recipientIds: [Int]) async {
        guard !body.isEmpty else { return }
        isSending = true
        sendError = nil
        do {
            try await client.sendConversation(
                recipientIds: recipientIds,
                subject: subject,
                body: body
            )
            didSend = true
        } catch {
            sendError = error.localizedDescription
            isSending = false
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
swift build --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/ViewModels/ComposeMessageViewModel.swift
git commit -m "feat: add ComposeMessageViewModel with send() logic"
```

---

### Task 5: Create `ComposeMessageSheet`

**Files:**
- Create: `CanvasApp/Views/ComposeMessageSheet.swift`

**Interfaces:**
- Consumes: `ComposeMessageViewModel` (Task 4), `APIClient` (from `AppState.makeClient()`)
- Produces: `struct ComposeMessageSheet: View` with init `(instructorIds: [Int], client: APIClient, isPresented: Binding<Bool>)`

---

- [ ] **Step 1: Create the sheet view**

Create `CanvasApp/Views/ComposeMessageSheet.swift`:

```swift
import SwiftUI
import CanvasCore

struct ComposeMessageSheet: View {
    let instructorIds: [Int]
    let client: APIClient
    @Binding var isPresented: Bool

    @StateObject private var vm = ComposeMessageViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Subject") {
                    TextField("Subject", text: $vm.subject)
                }
                Section("Message") {
                    TextEditor(text: $vm.body)
                        .frame(minHeight: 120)
                }
                if let error = vm.sendError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Message Instructor")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSending {
                        ProgressView()
                    } else {
                        Button("Send") {
                            Task { await vm.send(client: client, recipientIds: instructorIds) }
                        }
                        .disabled(vm.body.isEmpty)
                    }
                }
            }
        }
        .onChange(of: vm.didSend) { _, sent in
            if sent { isPresented = false }
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

```bash
swift build --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/Views/ComposeMessageSheet.swift
git commit -m "feat: add ComposeMessageSheet view"
```

---

### Task 6: Wire toolbar button and sheet into `CourseDetailView`

**Files:**
- Modify: `CanvasApp/Views/CourseDetailView.swift`

**Interfaces:**
- Consumes: `vm.instructorIds: [Int]` (Task 3), `ComposeMessageSheet(instructorIds:client:isPresented:)` (Task 5), `appState.makeClient() -> APIClient?`

---

- [ ] **Step 1: Add `showingCompose` state property**

In `CourseDetailView`, add after the existing property declarations (after `@EnvironmentObject var appState: AppState`):

```swift
@State private var showingCompose = false
```

- [ ] **Step 2: Add toolbar modifier and sheet**

Add `.toolbar` and `.sheet` modifiers after the existing `.task { await refresh() }` modifier on the `Group`:

```swift
.toolbar {
    if !vm.instructorIds.isEmpty {
        ToolbarItem(placement: .primaryAction) {
            Button { showingCompose = true } label: {
                Label("Message Instructor", systemImage: "envelope")
            }
        }
    }
}
.sheet(isPresented: $showingCompose) {
    if let client = appState.makeClient() {
        ComposeMessageSheet(
            instructorIds: vm.instructorIds,
            client: client,
            isPresented: $showingCompose
        )
    }
}
```

- [ ] **Step 3: Verify full build**

```bash
swift build --package-path /Users/kahuku-air/Developer/CanvasCLISwift 2>&1 | tail -5
```

Expected: `Build complete!`

- [ ] **Step 4: Manual smoke test**

Launch the app in Xcode (open `CanvasCLISwift.xcodeproj`, run the `CanvasApp` scheme on macOS).

1. Navigate to any course — confirm an envelope icon appears in the toolbar.
2. Tap the envelope — confirm the sheet opens with Subject and Message fields.
3. Leave body empty — confirm Send button is disabled.
4. Type a message body — confirm Send becomes enabled.
5. Tap Cancel — confirm sheet dismisses cleanly with no state leaked.
6. Re-open sheet — confirm fields are empty (fresh VM).
7. Fill subject + body and tap Send — confirm the sheet dismisses (success) or shows an inline error (failure).
8. In Canvas web, check Sent messages — confirm the conversation appears.

- [ ] **Step 5: Commit**

```bash
git add CanvasApp/Views/CourseDetailView.swift
git commit -m "feat: add instructor message button and compose sheet to CourseDetailView"
```
