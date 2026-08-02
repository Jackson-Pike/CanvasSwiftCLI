# Desktop App — Phase 0 (Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-08-01-desktop-app-design.md` (§9 Phase 0). Later phases get their own plan docs.

**Goal:** Restructure the app into four packages with a SwiftData store, a `SyncEngine` as the single writer, and two scenes (popover + window) over one shared session — shipping today's feature set in a resizable window that opens instantly from disk and works offline.

**Architecture:** `CanvasCore` (models/API, UI-free) → `CanvasData` (SwiftData schema, `CanvasRepository`, `SyncEngine`, `ChangeDetector`) → `CanvasUI` (value-driven shared components) → `CanvasApp` (`@main`, both scenes, `AppSession`, `Router`). Views read only from the store; only `SyncEngine` fetches and writes.

**Tech Stack:** Swift 5.9 SPM, SwiftData, SwiftUI (`MenuBarExtra` + `Window`), `@Observable` / `@ModelActor`, XCTest.

## Global Constraints

- macOS 14+ (`platforms: [.macOS(.v14)]`), swift-tools-version 5.9. No new third-party dependencies.
- `GradeCalculator` is **not modified** (spec §8). Existing `CanvasCoreTests` must stay green after every task.
- Default host is exactly `byuh.instructure.com`. Demo token is the literal string `DEMO`.
- Demo mode must remain fully walkable at every commit; Phase 0 is incomplete until walkable with `DEMO` in **both** scenes (spec §2.7).
- `DEBUG` conditionals use full `#if DEBUG / #else / #endif` blocks, never early-return inside `#if` (avoids SourceKit warnings — user preference).
- Views never call `APIClient`; all writes go through `SyncEngine`, all reads through `CanvasRepository` (spec §2, principle 2).
- Verify with `swift build && swift test` before every commit. After each task's code changes, run `graphify update .` before committing (project CLAUDE.md).
- Commit after every task (small, frequent commits).

## Deviations from spec (flagged for reviewer)

1. **Foreign-key integers instead of SwiftData cascade relationships.** Spec §3 says `CachedCourse` holds cascade-delete relationships. Because deletion is *soft* (`removedAt`), cascades would never fire in practice; explicit `courseId`/`groupId` columns make `@ModelActor` upserts far simpler and identity-stable. Hard deletion paths (`clearStore`, 90-day purge) delete explicitly.
2. **`CanvasRepository` is a concrete `@MainActor` class**, not a protocol (spec §2.4 sketches a protocol). One implementation exists; protocol extraction is deferred until a second one does (YAGNI). Method names/signatures match the spec where the entity exists in Phase 0.
3. **`SyncScope` ships with only `.all` and `.course(Int)`.** `.tab/.inbox/.planner` are added in their phases (additive enum change).
4. **Cached models carry only Phase 0 fields** (the five existing endpoints + profile). Later-phase fields/models (announcements, files, etc.) are added additively in their phases; SwiftData handles additive schema changes without a custom migration.
5. **First-sync baseline suppression** for `ChangeRecord`s: a course's very first sync emits no records (otherwise every historical grade floods the feed). Not in the spec, but implied by "what changed since you last looked."
6. `SubmissionComment` gains an optional `id` (Canvas returns one) so `.newFeedback` has identity. Comments without an id are cached-skipped for change detection.
7. **Router lives in `CanvasApp`** per spec §2.2, which the executable target can't unit-test; its `reveal` logic is verified manually in Task 16.

## File structure (end state)

```
Package.swift                              4 targets + 2 test targets
Sources/CanvasCore/                        (existing) + Credentials.swift, Profile in Models.swift
Sources/CanvasData/
    ChangeKind.swift                       ChangeKind enum
    CanvasDate.swift                       ISO8601 parsing helper
    Models/CourseModels.swift              CachedCourse, CachedEnrollment, CachedAssignmentGroup, CachedAssignment
    Models/SubmissionModels.swift          CachedSubmission, CachedComment
    Models/TrackingModels.swift            GradeSnapshot, ChangeRecord, SyncMetadata
    CanvasStore.swift                      schema list + container factory
    CanvasRepository.swift                 reads, setHidden/setPinned, purge, clearStore
    DerivedReads.swift                     CalculatorInputs, StreamItem, repository extensions
    ChangeDetector.swift                   pure diff functions + SubmissionSnapshot
    SyncEngine.swift                       @ModelActor actor, SyncScope/SyncState/EntityKind
    LegacyHiddenCourses.swift              one-time UserDefaults migration helper
Sources/CanvasUI/
    BrandColors.swift                      moved from CanvasApp, public
    CourseCard.swift, LetterBadge.swift, GradeDashboard.swift (+GroupBreakdownRow),
    StreamSection.swift (+StreamRow), CalculatorView.swift (+CalculatorViewModel),
    StalenessLabel.swift, SkeletonList.swift
CanvasApp/
    App/CanvasApp.swift                    @main, two scenes
    App/AppSession.swift                   replaces AppState (deleted)
    App/Router.swift                       Router, SidebarItem, CourseTab, RevealTarget
    App/KeychainHelper.swift               host-scoped
    ViewModels/CoursesViewModel.swift      repointed at repository
    ViewModels/CourseDetailViewModel.swift repointed at repository
    Views/ (popover views, migrated)       + Window/MainWindowView.swift, Window/CourseWorkspaceView.swift
Tests/CanvasCoreTests/                     existing + CredentialsTests, ProfileTests
Tests/CanvasDataTests/                     new suite
```

---

### Task 1: Package split

**Files:**
- Modify: `Package.swift`
- Create: `Sources/CanvasData/ChangeKind.swift`, `Sources/CanvasUI/BrandColors.swift` (moved), `Tests/CanvasDataTests/SmokeTests.swift`
- Delete: `CanvasApp/App/BrandColors.swift` (moved to CanvasUI)

**Interfaces:**
- Produces: targets `CanvasData` (depends `CanvasCore`), `CanvasUI` (depends `CanvasCore`, `CanvasData`), `CanvasDataTests`; `public enum ChangeKind: String, Codable, Sendable` with cases `newGrade, gradeChanged, newFeedback, newAnnouncement, newMessage, dueSoon`; brand colors public in `CanvasUI`.

- [ ] **Step 1: Rewrite `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CanvasCLISwift",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CanvasCore", targets: ["CanvasCore"]),
        .library(name: "CanvasData", targets: ["CanvasData"]),
        .library(name: "CanvasUI", targets: ["CanvasUI"]),
        .executable(name: "CanvasApp", targets: ["CanvasApp"]),
    ],
    targets: [
        .target(name: "CanvasCore", path: "Sources/CanvasCore"),
        .target(name: "CanvasData", dependencies: ["CanvasCore"], path: "Sources/CanvasData"),
        .target(name: "CanvasUI", dependencies: ["CanvasCore", "CanvasData"], path: "Sources/CanvasUI"),
        .executableTarget(
            name: "CanvasApp",
            dependencies: ["CanvasCore", "CanvasData", "CanvasUI"],
            path: "CanvasApp",
            exclude: ["App/Info.plist"]
        ),
        .testTarget(name: "CanvasCoreTests", dependencies: ["CanvasCore"], path: "Tests/CanvasCoreTests"),
        .testTarget(name: "CanvasDataTests", dependencies: ["CanvasData", "CanvasCore"], path: "Tests/CanvasDataTests"),
    ]
)
```

- [ ] **Step 2: Seed the new targets**

`Sources/CanvasData/ChangeKind.swift`:

```swift
import Foundation

public enum ChangeKind: String, Codable, Sendable, CaseIterable {
    case newGrade, gradeChanged, newFeedback, newAnnouncement, newMessage, dueSoon
}
```

Move `CanvasApp/App/BrandColors.swift` → `Sources/CanvasUI/BrandColors.swift` (`git mv`). Mark every member `public` (the extension members on `Color` such as `byuhRed`, `byuhGold`, `letterGradeColor(_:)`, `systemBackground`, `systemGroupedBackground`, `secondaryLabel`). All popover views that use them are in `CanvasApp`, which now depends on `CanvasUI` — add `import CanvasUI` to `CourseListView.swift`, `CourseDetailView.swift`, `CalculatorView.swift`, `SettingsView.swift`, `WelcomeView.swift`, `KeychainWarningView.swift` (any file the compiler flags).

`Tests/CanvasDataTests/SmokeTests.swift`:

```swift
import XCTest
@testable import CanvasData

final class SmokeTests: XCTestCase {
    func testChangeKindRoundTrip() throws {
        for kind in ChangeKind.allCases {
            XCTAssertEqual(ChangeKind(rawValue: kind.rawValue), kind)
        }
    }
}
```

- [ ] **Step 3: Verify**

Run: `swift build && swift test`
Expected: builds; all existing `CanvasCoreTests` pass; `SmokeTests` passes.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "refactor: split package into CanvasCore/CanvasData/CanvasUI/CanvasApp targets"
```

---

### Task 2: `Credentials` + host-configurable `APIClient` + host-scoped Keychain

**Files:**
- Create: `Sources/CanvasCore/Credentials.swift`, `Tests/CanvasCoreTests/CredentialsTests.swift`
- Modify: `Sources/CanvasCore/APIClient.swift`, `CanvasApp/App/AppState.swift:48-51`, `CanvasApp/App/KeychainHelper.swift`, every test constructing `APIClient(token:)`

**Interfaces:**
- Produces: `Credentials(host:token:)`, `Credentials.normalizeHost(_ raw: String) -> String?`, `APIClient.init(credentials: Credentials, session: URLSession = .shared)`, `APIClient.credentials`; `KeychainHelper.save(token:host:)`, `.load(host:) -> String?`, `.delete(host:)`.
- Consumes: nothing new.

- [ ] **Step 1: Write failing tests**

`Tests/CanvasCoreTests/CredentialsTests.swift`:

```swift
import XCTest
@testable import CanvasCore

final class CredentialsTests: XCTestCase {
    func testNormalizeHost() {
        XCTAssertEqual(Credentials.normalizeHost("byuh.instructure.com"), "byuh.instructure.com")
        XCTAssertEqual(Credentials.normalizeHost("  https://byuh.instructure.com/  "), "byuh.instructure.com")
        XCTAssertEqual(Credentials.normalizeHost("https://canvas.school.edu/api/v1"), "canvas.school.edu")
        XCTAssertEqual(Credentials.normalizeHost("HTTP://Canvas.School.EDU"), "canvas.school.edu")
        XCTAssertNil(Credentials.normalizeHost(""))
        XCTAssertNil(Credentials.normalizeHost("not a host name"))
        XCTAssertNil(Credentials.normalizeHost("https://"))
    }

    func testAPIClientBuildsURLsFromHost() async throws {
        // Reuse the PaginationStub pattern: a stub that records the request URL.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordingStub.self]
        RecordingStub.lastURL = nil
        RecordingStub.body = Data("[]".utf8)
        let client = APIClient(
            credentials: Credentials(host: "canvas.other.edu", token: "T"),
            session: URLSession(configuration: config)
        )
        _ = try await client.courses()
        XCTAssertEqual(RecordingStub.lastURL?.host, "canvas.other.edu")
        XCTAssertEqual(RecordingStub.lastURL?.path, "/api/v1/courses")
    }
}

final class RecordingStub: URLProtocol {
    static var lastURL: URL?
    static var body = Data()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastURL = request.url
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter CredentialsTests` → FAIL (`Credentials` not defined).

- [ ] **Step 3: Implement**

`Sources/CanvasCore/Credentials.swift`:

```swift
import Foundation

public struct Credentials: Sendable, Equatable {
    public let host: String   // host only — no scheme, no path
    public let token: String

    public init(host: String, token: String) {
        self.host = host
        self.token = token
    }

    /// Trims whitespace, strips a leading scheme and any trailing path,
    /// lowercases, and validates. Returns nil for anything that isn't a hostname.
    public static func normalizeHost(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        guard !s.isEmpty, !s.contains(" "), s.contains("."),
              s.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" })
        else { return nil }
        return s
    }
}
```

In `APIClient.swift` replace the stored `token`/`baseURL`:

```swift
public struct APIClient {
    public let credentials: Credentials
    private let session: URLSession

    var token: String { credentials.token }
    private var baseURL: String { "https://\(credentials.host)/api/v1" }

    public init(credentials: Credentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session
    }
}
```

Update every call site: `AppState.makeClient()` becomes `APIClient(credentials: Credentials(host: "byuh.instructure.com", token: token))` (temporary — AppSession replaces this in Task 12), and each test file constructing `APIClient(token:...)` switches to `APIClient(credentials: Credentials(host: "byuh.instructure.com", token: ...), session: ...)`.

`KeychainHelper`: change signatures to `save(token: String, host: String)`, `load(host: String) -> String?`, `delete(host: String)`. The account becomes `"canvas_token.\(host)"` (and the DEBUG UserDefaults key `"dev_canvas_token.\(host)"`). In `load(host:)`, if the host-scoped item is missing **and** `host == "byuh.instructure.com"`, fall back to reading the legacy account `"canvas_token"` (legacy key `"dev_canvas_token"` in DEBUG); if found, re-save under the new account and delete the legacy one — this migrates existing users. Use `#if DEBUG / #else / #endif` blocks as the file already does.

- [ ] **Step 4: Run full suite** — `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: configurable Canvas host via Credentials; host-scoped keychain"`

---

### Task 3: `profile()` endpoint, `APIError.rateLimited`/`.forbidden`, `SubmissionComment.id`

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`, `Sources/CanvasCore/Models.swift`, `Sources/CanvasCore/MockData.swift`
- Create: `Tests/CanvasCoreTests/ProfileTests.swift`

**Interfaces:**
- Produces: `public struct Profile: Codable, Sendable { let id: Int; let name: String; let primaryEmail: String? }`; `APIClient.profile() async throws -> Profile`; `APIError.rateLimited(retryAfter: TimeInterval)` and `.forbidden`; `SubmissionComment.id: Int?`; `MockData.profile: Profile`.
- Consumes: `Credentials` (Task 2).

- [ ] **Step 1: Write failing tests**

`Tests/CanvasCoreTests/ProfileTests.swift`:

```swift
import XCTest
@testable import CanvasCore

final class ProfileTests: XCTestCase {
    private func client(stub: (Int, Data, [String: String])) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixedResponseStub.self]
        FixedResponseStub.status = stub.0
        FixedResponseStub.body = stub.1
        FixedResponseStub.headers = stub.2
        return APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "T"),
                         session: URLSession(configuration: config))
    }

    func testProfileDecodes() async throws {
        let json = Data(#"{"id": 42, "name": "Jackson Pike", "primary_email": "x@byuh.edu"}"#.utf8)
        let profile = try await client(stub: (200, json, [:])).profile()
        XCTAssertEqual(profile.id, 42)
        XCTAssertEqual(profile.name, "Jackson Pike")
        XCTAssertEqual(profile.primaryEmail, "x@byuh.edu")
    }

    func testDemoProfile() async throws {
        let profile = try await APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")).profile()
        XCTAssertEqual(profile.name, MockData.profile.name)
    }

    func testRateLimitedMapsToBackoffError() async throws {
        let body = Data("403 Forbidden (Rate Limit Exceeded)".utf8)
        do {
            _ = try await client(stub: (403, body, ["Retry-After": "7"])).profile()
            XCTFail("expected throw")
        } catch let APIError.rateLimited(retryAfter) {
            XCTAssertEqual(retryAfter, 7, accuracy: 0.01)
        }
    }

    func testPlainForbidden() async throws {
        do {
            _ = try await client(stub: (403, Data("nope".utf8), [:])).profile()
            XCTFail("expected throw")
        } catch APIError.forbidden {
            // pass
        }
    }

    func testSubmissionCommentDecodesId() throws {
        let json = Data(#"{"id": 9, "author_id": 1, "author_name": "T", "comment": "hi", "created_at": null}"#.utf8)
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        XCTAssertEqual(try d.decode(SubmissionComment.self, from: json).id, 9)
    }
}

final class FixedResponseStub: URLProtocol {
    static var status = 200
    static var body = Data()
    static var headers: [String: String] = [:]
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var h = Self.headers; h["Content-Type"] = "application/json"
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                       httpVersion: nil, headerFields: h)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter ProfileTests` → FAIL.

- [ ] **Step 3: Implement**

In `Models.swift`: add `public let id: Int?` as the first field of `SubmissionComment`; add

```swift
public struct Profile: Codable, Sendable {
    public let id: Int
    public let name: String
    public let primaryEmail: String?
}
```

In `APIError`: add cases + descriptions:

```swift
case rateLimited(retryAfter: TimeInterval)   // "Canvas is rate limiting requests — retrying shortly."
case forbidden                               // "Canvas denied access to this resource."
```

In `APIClient.getPage`, before the generic `guard (200..<300)` check:

```swift
if http.statusCode == 403 {
    let bodyText = String(data: data, encoding: .utf8) ?? ""
    if bodyText.contains("Rate Limit Exceeded") {
        let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init) ?? 10
        throw APIError.rateLimited(retryAfter: retryAfter)
    } else {
        throw APIError.forbidden
    }
}
```

Add `profile()` (single-object GET — it can't use `getPaginated`, which expects arrays; call `getPage` directly):

```swift
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
```

In `MockData.swift`: add `public static let profile = Profile(id: studentUserId, name: "Demo Student", primaryEmail: "demo.student@example.edu")`, and give every `SubmissionComment` a unique `id:` (e.g. 9001, 9002, …).

- [ ] **Step 4: Run full suite** — `swift test` → all PASS (fix any `SubmissionComment` construction the compiler flags).

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: profile endpoint, rate-limit/forbidden errors, comment ids"`

---

### Task 4: SwiftData schema + container factory

**Files:**
- Create: `Sources/CanvasData/CanvasDate.swift`, `Sources/CanvasData/Models/CourseModels.swift`, `Sources/CanvasData/Models/SubmissionModels.swift`, `Sources/CanvasData/Models/TrackingModels.swift`, `Sources/CanvasData/CanvasStore.swift`, `Tests/CanvasDataTests/SchemaTests.swift`

**Interfaces:**
- Produces: the nine `@Model` classes below (exact property names matter — later tasks use them), `CanvasStore.container(inMemory:)`, `CanvasDate.parse(_:)`, `SchemePair`, `CachedCourse.gradingScale`.
- Consumes: `ChangeKind` (Task 1), `byuhDefaultScale` from `CanvasCore`.

- [ ] **Step 1: Write failing test**

`Tests/CanvasDataTests/SchemaTests.swift`:

```swift
import XCTest
import SwiftData
@testable import CanvasData

final class SchemaTests: XCTestCase {
    @MainActor
    func testInsertAndFetchEveryModel() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = container.mainContext
        ctx.insert(CachedCourse(id: 1, name: "BIOL 100", courseCode: "BIOL100",
                                applyGroupWeights: true, gradingSchemeJSON: nil, sortIndex: 0))
        ctx.insert(CachedEnrollment(courseId: 1, currentScore: 87.4, currentGrade: "B+"))
        ctx.insert(CachedAssignmentGroup(id: 10, courseId: 1, name: "Exams", groupWeight: 30,
                                         dropLowest: 0, dropHighest: 0, neverDrop: []))
        ctx.insert(CachedAssignment(id: 100, courseId: 1, groupId: 10, name: "Midterm",
                                    pointsPossible: 100, dueAt: .now, sortIndex: 0))
        ctx.insert(CachedSubmission(id: 1000, assignmentId: 100, courseId: 1, userId: 7,
                                    score: 92, workflowState: "graded", gradedAt: .now, submittedAt: nil))
        ctx.insert(CachedComment(id: 5, submissionId: 1000, assignmentId: 100,
                                 authorId: 8, authorName: "Prof", body: "Nice", createdAt: .now))
        ctx.insert(GradeSnapshot(courseId: 1, capturedAt: .now, percent: 87.4, letter: "B+"))
        ctx.insert(ChangeRecord(kind: .newGrade, courseId: 1, subjectId: 100,
                                title: "Midterm", detail: "92 / 100", occurredAt: .now))
        ctx.insert(SyncMetadata(entityKind: "submissions", scopeId: "1"))
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CachedCourse>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<ChangeRecord>()).first?.changeKind, .newGrade)
    }

    func testCanvasDateParsesISO8601() {
        XCTAssertNotNil(CanvasDate.parse("2026-08-01T12:00:00Z"))
        XCTAssertNotNil(CanvasDate.parse("2026-08-01T12:00:00.123Z"))
        XCTAssertNil(CanvasDate.parse(nil))
        XCTAssertNil(CanvasDate.parse("garbage"))
    }

    @MainActor
    func testGradingScaleFallsBackToBYUHDefault() throws {
        let course = CachedCourse(id: 2, name: "X", courseCode: "X",
                                  applyGroupWeights: false, gradingSchemeJSON: nil, sortIndex: 0)
        XCTAssertEqual(course.gradingScale.first?.0, "A")
        let pairs = [SchemePair(name: "P", value: 0.5), SchemePair(name: "F", value: 0.0)]
        course.gradingSchemeJSON = try JSONEncoder().encode(pairs)
        XCTAssertEqual(course.gradingScale.map(\.0), ["P", "F"])
        XCTAssertEqual(course.gradingScale.first?.1 ?? 0, 50, accuracy: 0.001)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter SchemaTests` → FAIL.

- [ ] **Step 3: Implement**

`Sources/CanvasData/CanvasDate.swift`:

```swift
import Foundation

public enum CanvasDate {
    private static let plain = ISO8601DateFormatter()
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    public static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        return plain.date(from: s) ?? fractional.date(from: s)
    }
}
```

`Sources/CanvasData/Models/CourseModels.swift`:

```swift
import Foundation
import SwiftData
import CanvasCore

public struct SchemePair: Codable, Sendable {
    public let name: String
    public let value: Double   // 0.0–1.0 lower-bound fraction
    public init(name: String, value: Double) { self.name = name; self.value = value }
}

@Model
public final class CachedCourse {
    @Attribute(.unique) public var id: Int
    public var name: String
    public var courseCode: String
    public var applyGroupWeights: Bool
    public var gradingSchemeJSON: Data?
    public var hidden: Bool
    public var pinned: Bool
    public var sortIndex: Int
    public var accentColorHex: String?
    public var syllabusBody: String?
    public var removedAt: Date?

    public init(id: Int, name: String, courseCode: String, applyGroupWeights: Bool,
                gradingSchemeJSON: Data?, hidden: Bool = false, pinned: Bool = false,
                sortIndex: Int, accentColorHex: String? = nil,
                syllabusBody: String? = nil, removedAt: Date? = nil) {
        self.id = id; self.name = name; self.courseCode = courseCode
        self.applyGroupWeights = applyGroupWeights; self.gradingSchemeJSON = gradingSchemeJSON
        self.hidden = hidden; self.pinned = pinned; self.sortIndex = sortIndex
        self.accentColorHex = accentColorHex; self.syllabusBody = syllabusBody
        self.removedAt = removedAt
    }

    /// Sorted (name, percent-lower-bound) pairs; falls back to the BYUH default scale.
    public var gradingScale: [(String, Double)] {
        guard let data = gradingSchemeJSON,
              let pairs = try? JSONDecoder().decode([SchemePair].self, from: data),
              !pairs.isEmpty
        else { return byuhDefaultScale }
        return pairs.map { ($0.name, $0.value * 100) }.sorted { $0.1 > $1.1 }
    }
}

@Model
public final class CachedEnrollment {
    @Attribute(.unique) public var courseId: Int
    public var currentScore: Double?
    public var currentGrade: String?

    public init(courseId: Int, currentScore: Double?, currentGrade: String?) {
        self.courseId = courseId; self.currentScore = currentScore; self.currentGrade = currentGrade
    }
}

@Model
public final class CachedAssignmentGroup {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var name: String
    public var groupWeight: Double
    public var dropLowest: Int
    public var dropHighest: Int
    public var neverDrop: [Int]
    public var removedAt: Date?

    public init(id: Int, courseId: Int, name: String, groupWeight: Double,
                dropLowest: Int, dropHighest: Int, neverDrop: [Int], removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.name = name; self.groupWeight = groupWeight
        self.dropLowest = dropLowest; self.dropHighest = dropHighest
        self.neverDrop = neverDrop; self.removedAt = removedAt
    }
}

@Model
public final class CachedAssignment {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var groupId: Int
    public var name: String
    public var pointsPossible: Double?
    public var dueAt: Date?
    public var sortIndex: Int
    public var removedAt: Date?

    public init(id: Int, courseId: Int, groupId: Int, name: String,
                pointsPossible: Double?, dueAt: Date?, sortIndex: Int, removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.groupId = groupId; self.name = name
        self.pointsPossible = pointsPossible; self.dueAt = dueAt
        self.sortIndex = sortIndex; self.removedAt = removedAt
    }
}
```

`Sources/CanvasData/Models/SubmissionModels.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class CachedSubmission {
    @Attribute(.unique) public var id: Int
    public var assignmentId: Int
    public var courseId: Int
    public var userId: Int
    public var score: Double?
    public var workflowState: String
    public var gradedAt: Date?
    public var submittedAt: Date?

    public init(id: Int, assignmentId: Int, courseId: Int, userId: Int, score: Double?,
                workflowState: String, gradedAt: Date?, submittedAt: Date?) {
        self.id = id; self.assignmentId = assignmentId; self.courseId = courseId
        self.userId = userId; self.score = score; self.workflowState = workflowState
        self.gradedAt = gradedAt; self.submittedAt = submittedAt
    }
}

@Model
public final class CachedComment {
    @Attribute(.unique) public var id: Int
    public var submissionId: Int
    public var assignmentId: Int
    public var authorId: Int
    public var authorName: String
    public var body: String
    public var createdAt: Date?

    public init(id: Int, submissionId: Int, assignmentId: Int, authorId: Int,
                authorName: String, body: String, createdAt: Date?) {
        self.id = id; self.submissionId = submissionId; self.assignmentId = assignmentId
        self.authorId = authorId; self.authorName = authorName
        self.body = body; self.createdAt = createdAt
    }
}
```

`Sources/CanvasData/Models/TrackingModels.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class GradeSnapshot {
    public var courseId: Int
    public var capturedAt: Date
    public var percent: Double
    public var letter: String

    public init(courseId: Int, capturedAt: Date, percent: Double, letter: String) {
        self.courseId = courseId; self.capturedAt = capturedAt
        self.percent = percent; self.letter = letter
    }
}

@Model
public final class ChangeRecord {
    @Attribute(.unique) public var id: UUID
    public var kind: String            // ChangeKind.rawValue (SwiftData predicates want plain types)
    public var courseId: Int
    public var subjectId: Int?
    public var title: String
    public var detail: String?
    public var occurredAt: Date
    public var seenAt: Date?

    public var changeKind: ChangeKind? { ChangeKind(rawValue: kind) }

    public init(kind: ChangeKind, courseId: Int, subjectId: Int?, title: String,
                detail: String?, occurredAt: Date, seenAt: Date? = nil) {
        self.id = UUID(); self.kind = kind.rawValue; self.courseId = courseId
        self.subjectId = subjectId; self.title = title; self.detail = detail
        self.occurredAt = occurredAt; self.seenAt = seenAt
    }
}

@Model
public final class SyncMetadata {
    @Attribute(.unique) public var key: String     // "\(entityKind):\(scopeId)"
    public var entityKind: String
    public var scopeId: String
    public var lastSyncedAt: Date?
    public var lastErrorDescription: String?

    public init(entityKind: String, scopeId: String) {
        self.key = "\(entityKind):\(scopeId)"
        self.entityKind = entityKind; self.scopeId = scopeId
    }
}
```

`Sources/CanvasData/CanvasStore.swift`:

```swift
import Foundation
import SwiftData

public enum CanvasStore {
    public static let schema = Schema([
        CachedCourse.self, CachedEnrollment.self, CachedAssignmentGroup.self,
        CachedAssignment.self, CachedSubmission.self, CachedComment.self,
        GradeSnapshot.self, ChangeRecord.self, SyncMetadata.self,
    ])

    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
```

- [ ] **Step 4: Run** — `swift test --filter SchemaTests` → PASS; then `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: SwiftData schema and container for CanvasData"`

---

### Task 5: `CanvasRepository` (reads, flags, purge, clearStore)

**Files:**
- Create: `Sources/CanvasData/CanvasRepository.swift`, `Tests/CanvasDataTests/RepositoryTests.swift`

**Interfaces:**
- Consumes: all Task 4 models, `CanvasStore.container`.
- Produces (exact — later tasks call these):

```swift
@MainActor
public final class CanvasRepository {
    public let modelContainer: ModelContainer
    public init(modelContainer: ModelContainer)

    public func courses(includeHidden: Bool = false) throws -> [CachedCourse]
    public func course(id: Int) throws -> CachedCourse?
    public func enrollment(courseId: Int) throws -> CachedEnrollment?
    public func assignmentGroups(courseId: Int) throws -> [CachedAssignmentGroup]
    public func assignments(courseId: Int) throws -> [CachedAssignment]     // removedAt == nil, sorted by sortIndex
    public func submissions(courseId: Int) throws -> [CachedSubmission]
    public func comments(assignmentId: Int) throws -> [CachedComment]
    public func changes(since: Date) throws -> [ChangeRecord]
    public func unseenChanges() throws -> [ChangeRecord]                    // seenAt == nil, newest first
    public func markChangesSeen(now: Date = .init()) throws
    public func gradeSnapshots(courseId: Int) throws -> [GradeSnapshot]     // oldest first
    public func lastSyncedAt(entityKind: String, scopeId: String) throws -> Date?
    public func setHidden(_ hidden: Bool, courseId: Int) throws
    public func setPinned(_ pinned: Bool, courseId: Int) throws
    public func purgeExpired(now: Date = .init()) throws                    // soft-deleted > 90d, ChangeRecords > 30d
    public func clearStore() throws                                         // deletes every row of every model
}
```

- [ ] **Step 1: Write failing tests** — `Tests/CanvasDataTests/RepositoryTests.swift`. Every test builds `CanvasRepository(modelContainer: try CanvasStore.container(inMemory: true))` on `@MainActor`. Cover:

```swift
func testCoursesSortPinnedFirstThenSortIndexAndExcludeHiddenAndRemoved()
// insert 4 courses: (a sortIndex 1), (b sortIndex 0, pinned), (c hidden), (d removedAt set)
// courses() == [b, a]; courses(includeHidden: true) == [b, a, c]

func testSetHiddenAndSetPinnedPersist()
// setHidden(true, courseId:) flips the flag; setPinned likewise; unknown id doesn't throw

func testUnseenChangesAndMarkSeen()
// 2 unseen + 1 seen → unseenChanges() count 2 newest-first; markChangesSeen() → 0 unseen

func testPurgeExpired()
// course removedAt 91 days ago → deleted; removedAt 5 days ago → kept
// ChangeRecord occurredAt 31 days ago → deleted; 5 days ago → kept
// same for CachedAssignment/CachedSubmission soft-deletes (assignment removedAt 91d → gone)

func testClearStoreEmptiesEveryModel()
// insert one of everything, clearStore(), fetch counts all 0
```

Write them fully (they are straightforward inserts + assertions following the SchemaTests style).

- [ ] **Step 2: Run to verify failure** — `swift test --filter RepositoryTests` → FAIL.

- [ ] **Step 3: Implement** `CanvasRepository`. Notes for the implementer:

- Hold `private var context: ModelContext { modelContainer.mainContext }`.
- Use `FetchDescriptor` with `#Predicate` for id/courseId equality and `seenAt == nil`; do the `removedAt == nil` + hidden filtering and pinned/sortIndex sorting **in memory** after fetch (SwiftData optional-date predicates are unreliable; volumes here are tiny).
- Sorting rule for `courses()`: `pinned` first, then `sortIndex` ascending, then `name`.
- `purgeExpired`: fetch each soft-deletable type, filter `removedAt != nil && removedAt! < now - 90*86400`, `context.delete` each; fetch `ChangeRecord` filter `occurredAt < now - 30*86400`, delete; `try context.save()`.
- `clearStore`: `try context.delete(model: CachedCourse.self)` … one line per model type in `CanvasStore.schema`, then save.

- [ ] **Step 4: Run** — `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: CanvasRepository reads, course flags, purge, clearStore"`

---

### Task 6: `ChangeDetector`

**Files:**
- Create: `Sources/CanvasData/ChangeDetector.swift`, `Tests/CanvasDataTests/ChangeDetectorTests.swift`

**Interfaces:**
- Consumes: `Submission`, `SubmissionComment` from `CanvasCore`; `ChangeKind`.
- Produces:

```swift
public struct SubmissionSnapshot: Equatable, Sendable {
    public let score: Double?
    public let workflowState: String
    public let commentIds: Set<Int>
    public init(score: Double?, workflowState: String, commentIds: Set<Int>)
}

public struct PendingChange: Equatable, Sendable {
    public let kind: ChangeKind
    public let courseId: Int
    public let subjectId: Int?
    public let title: String
    public let detail: String?
    public init(kind: ChangeKind, courseId: Int, subjectId: Int?, title: String, detail: String?)
}

public enum ChangeDetector {
    /// .newGrade and .newFeedback. `old` is keyed by assignmentId.
    /// Returns [] when `old` is empty (first sync for this course = baseline, no flood).
    public static func submissionChanges(courseId: Int,
                                         old: [Int: SubmissionSnapshot],
                                         new: [Submission],
                                         assignmentNames: [Int: String]) -> [PendingChange]

    /// .gradeChanged — nil unless both non-nil and |new-old| >= 0.01.
    public static func gradeChange(courseId: Int, courseName: String,
                                   oldPercent: Double?, newPercent: Double?) -> PendingChange?

    /// .dueSoon — dueAt within (now, now+24h], not submitted, not already notified.
    public static func dueSoonChanges(courseId: Int,
                                      assignments: [(id: Int, name: String, dueAt: Date?)],
                                      submittedAssignmentIds: Set<Int>,
                                      alreadyNotified: Set<Int>,
                                      now: Date) -> [PendingChange]
}
```

- [ ] **Step 1: Write failing table-driven tests** covering, at minimum (spec §3.1 + §8):

```swift
// .newGrade positives
func testNewGradeFiresOnNilToScore()          // old score nil → new score 92, state "graded"
func testNewGradeFiresOnScoreChange()         // 80 → 85
// .newGrade negatives — the Canvas quirks
func testMutedGradeDoesNotFireNewGrade()      // workflowState "graded", score nil → NO record
func testIdenticalResyncProducesZeroRecords() // old == new exactly → []
func testFirstSyncBaselineProducesZeroRecords() // old empty, new has graded items → []
// .newFeedback
func testNewInstructorCommentFires()          // comment id not in old.commentIds, authorId != userId
func testOwnCommentDoesNotFire()              // authorId == submission.userId
func testExistingCommentDoesNotFire()         // id already in commentIds
func testCommentWithoutIdIsIgnored()          // id nil → no record, no crash
// .gradeChanged
func testGradeChangedThreshold()              // 87.400 → 87.405 no; 87.4 → 87.42 yes; nil→x no
// .dueSoon
func testDueSoonFiresInsideWindow()           // due in 3h, unsubmitted, not notified
func testDueSoonRespectsSubmittedAndNotifiedAndWindow()
                                              // submitted → no; alreadyNotified → no; due in 30h → no; past due → no
```

Constructing `Submission` values: `Submission` is `Codable` with no public memberwise init, so build fixtures by decoding JSON with a `convertFromSnakeCase` decoder — add a test helper:

```swift
func makeSubmission(assignmentId: Int, userId: Int = 7, score: Double?, workflowState: String,
                    comments: [(id: Int?, authorId: Int, authorName: String, comment: String)] = []) -> Submission {
    // build a [String: Any] dict, JSONSerialization → decode(Submission.self)
}
```

- [ ] **Step 2: Run to verify failure** — `swift test --filter ChangeDetectorTests` → FAIL.

- [ ] **Step 3: Implement** — pure functions, no SwiftData imports:

```swift
public static func submissionChanges(courseId: Int, old: [Int: SubmissionSnapshot],
                                     new: [Submission], assignmentNames: [Int: String]) -> [PendingChange] {
    guard !old.isEmpty else { return [] }   // baseline sync
    var changes: [PendingChange] = []
    for sub in new {
        let prior = old[sub.assignmentId]
        let name = assignmentNames[sub.assignmentId] ?? "Assignment"
        // Muted grade (graded + nil score) never fires — the `if let score` guard enforces it.
        if let score = sub.score, sub.workflowState == "graded", prior?.score != score {
            changes.append(PendingChange(kind: .newGrade, courseId: courseId,
                                         subjectId: sub.assignmentId, title: name,
                                         detail: String(format: "%.1f", score)))
        }
        for comment in sub.submissionComments ?? [] where comment.authorId != sub.userId {
            guard let cid = comment.id else { continue }
            if !(prior?.commentIds.contains(cid) ?? false) {
                changes.append(PendingChange(kind: .newFeedback, courseId: courseId,
                                             subjectId: sub.assignmentId, title: name,
                                             detail: "\(comment.authorName): \(comment.comment)"))
            }
        }
    }
    return changes
}
```

`gradeChange`: `guard let o = oldPercent, let n = newPercent, abs(n - o) >= 0.01 else { return nil }`, detail `String(format: "%.1f%% → %.1f%%", o, n)`, subjectId nil, title = courseName.

`dueSoonChanges`: `assignments.compactMap` — `guard let due = a.dueAt, due > now, due <= now.addingTimeInterval(86_400), !submittedAssignmentIds.contains(a.id), !alreadyNotified.contains(a.id)`.

- [ ] **Step 4: Run** — `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: ChangeDetector with Canvas muted-grade quirks"`

---

### Task 7: `SyncEngine` — scope `.all` (courses + enrollments, snapshots, hidden migration, soft delete)

**Files:**
- Create: `Sources/CanvasData/SyncEngine.swift`, `Sources/CanvasData/LegacyHiddenCourses.swift`, `Tests/CanvasDataTests/SyncEngineAllTests.swift`

**Interfaces:**
- Consumes: `APIClient`, `Credentials`, models, `ChangeDetector.gradeChange`, `CanvasRepository` (in tests), `letterGrade(for:scale:)` from `CanvasCore`.
- Produces:

```swift
public enum SyncScope: Equatable, Sendable { case all; case course(Int) }
public enum SyncState: Equatable, Sendable { case idle; case syncing(SyncScope); case failed(String, Date) }
public enum SyncError: Error { case noClient }
public enum EntityKind: String, Sendable { case courses, enrollments, assignments, submissions }

@ModelActor
public actor SyncEngine {
    public func configure(client: APIClient?)
    public func setStateHandler(_ handler: @escaping @Sendable (SyncState) -> Void)
    public private(set) var state: SyncState  // default .idle
    public func refresh(_ scope: SyncScope, force: Bool = false) async throws
}
```

`LegacyHiddenCourses`: `static func ids() -> Set<Int>` (reads UserDefaults key `"hiddenCourseIDs"`), `static func clear()`.

- [ ] **Step 1: Write failing tests** — all against `try CanvasStore.container(inMemory: true)` and `APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))` (the DEMO short-circuit returns `MockData` in DEBUG test builds — no network):

```swift
func testRefreshAllPopulatesCoursesAndEnrollments() async throws
// refresh(.all) → CachedCourse count == MockData.courses.count;
// enrollment for MockData.csCourseId has the MockData score

func testRefreshAllIsIdempotent() async throws
// refresh(.all) twice (force: true) → same course count, zero ChangeRecords,
// exactly one GradeSnapshot per course with a score (values identical on resync)

func testLegacyHiddenIdsMigrate() async throws
// UserDefaults set "hiddenCourseIDs" = [MockData.mathCourseId]; refresh(.all)
// → that course's hidden == true, others false, and the defaults key is now nil

func testSnapshotAndGradeChangedOnScoreMove() async throws
// refresh(.all); then directly edit the CachedEnrollment score by -2.0 (simulating an
// older stored value); refresh(.all, force: true) →
// a second GradeSnapshot row for that course AND one ChangeRecord kind "gradeChanged"

func testCourseMissingFromFullFetchIsSoftDeleted() async throws
// refresh(.all); insert an extra CachedCourse(id: 424242) by hand; refresh(.all, force: true)
// → course 424242 has removedAt != nil, still present in store (not hard-deleted)
```

(Tests that mutate UserDefaults must clean up in `tearDown`.)

- [ ] **Step 2: Run to verify failure** — `swift test --filter SyncEngineAllTests` → FAIL.

- [ ] **Step 3: Implement**

`LegacyHiddenCourses.swift`:

```swift
import Foundation

enum LegacyHiddenCourses {
    private static let key = "hiddenCourseIDs"
    static func ids() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key) as? [Int] ?? [])
    }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
```

`SyncEngine.swift` skeleton (Tasks 8–9 extend it — keep these exact private helper names):

```swift
import Foundation
import SwiftData
import CanvasCore

// SyncScope / SyncState / SyncError / EntityKind as declared above.

@ModelActor
public actor SyncEngine {
    private var client: APIClient?
    private var stateHandler: (@Sendable (SyncState) -> Void)?
    public private(set) var state: SyncState = .idle

    public func configure(client: APIClient?) { self.client = client }
    public func setStateHandler(_ handler: @escaping @Sendable (SyncState) -> Void) {
        self.stateHandler = handler
    }

    private func setState(_ s: SyncState) {
        state = s
        stateHandler?(s)
    }

    public func refresh(_ scope: SyncScope, force: Bool = false) async throws {
        guard let client else { throw SyncError.noClient }
        setState(.syncing(scope))
        do {
            switch scope {
            case .all:             try await syncAll(client: client, force: force)
            case .course(let id):  try await syncCourse(id, client: client, force: force)
            }
            setState(.idle)
        } catch {
            setState(.failed(String(describing: error), Date()))
            throw error
        }
    }

    // MARK: - .all

    private func syncAll(client: APIClient, force: Bool) async throws {
        let now = Date()
        let fetched = try await fetchWithRetry { try await client.courses() }
        upsertCourses(fetched, now: now)
        touch(.courses, scope: "all", error: nil, at: now)
        try modelContext.save()
        LegacyHiddenCourses.clear()

        let ids = activeCourseIds()
        await withTaskGroup(of: (Int, Result<[Enrollment], any Error>).self) { group in
            var index = 0
            func addNext() {
                guard index < ids.count else { return }
                let id = ids[index]; index += 1
                group.addTask {
                    do { return (id, .success(try await client.enrollments(courseId: id))) }
                    catch { return (id, .failure(error)) }
                }
            }
            for _ in 0..<min(4, ids.count) { addNext() }   // spec §2.5: fan-out cap 4
            for await (id, result) in group {
                applyEnrollment(result, courseId: id, now: Date())
                addNext()
            }
        }
        try modelContext.save()
    }

    private func upsertCourses(_ fetched: [Course], now: Date) {
        let legacy = LegacyHiddenCourses.ids()
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedCourse>())) ?? []).map { ($0.id, $0) })
        let fetchedIds = Set(fetched.map(\.id))
        for (i, c) in fetched.enumerated() {
            let schemeJSON = c.gradingScheme.flatMap {
                try? JSONEncoder().encode($0.map { SchemePair(name: $0.name, value: $0.value) })
            }
            if let row = existing[c.id] {
                row.name = c.name; row.courseCode = c.courseCode
                row.applyGroupWeights = c.applyAssignmentGroupWeights ?? false
                row.gradingSchemeJSON = schemeJSON
                row.sortIndex = i; row.removedAt = nil
            } else {
                modelContext.insert(CachedCourse(
                    id: c.id, name: c.name, courseCode: c.courseCode,
                    applyGroupWeights: c.applyAssignmentGroupWeights ?? false,
                    gradingSchemeJSON: schemeJSON,
                    hidden: legacy.contains(c.id), sortIndex: i))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil {
            row.removedAt = now   // soft delete (spec §2.5)
        }
    }

    private func applyEnrollment(_ result: Result<[Enrollment], any Error>, courseId: Int, now: Date) {
        switch result {
        case .failure(let error):
            touch(.enrollments, scope: "\(courseId)", error: String(describing: error), at: now)
        case .success(let enrollments):
            let newScore = enrollments.first?.grades?.currentScore
            let newGradeLetter = enrollments.first?.grades?.currentGrade
            let existing = fetchOne(FetchDescriptor<CachedEnrollment>(
                predicate: #Predicate { $0.courseId == courseId }))
            let oldScore = existing?.currentScore
            let hadPrior = existing != nil
            if let row = existing {
                row.currentScore = newScore; row.currentGrade = newGradeLetter
            } else {
                modelContext.insert(CachedEnrollment(courseId: courseId,
                                                     currentScore: newScore, currentGrade: newGradeLetter))
            }
            if let score = newScore, oldScore != score {
                let scale = fetchOne(FetchDescriptor<CachedCourse>(
                    predicate: #Predicate { $0.id == courseId }))?.gradingScale ?? byuhDefaultScale
                modelContext.insert(GradeSnapshot(courseId: courseId, capturedAt: now,
                                                  percent: score,
                                                  letter: letterGrade(for: score, scale: scale)))
            }
            if hadPrior {
                let courseName = fetchOne(FetchDescriptor<CachedCourse>(
                    predicate: #Predicate { $0.id == courseId }))?.name ?? "Course"
                if let change = ChangeDetector.gradeChange(courseId: courseId, courseName: courseName,
                                                           oldPercent: oldScore, newPercent: newScore) {
                    insert([change], now: now)
                }
            }
            touch(.enrollments, scope: "\(courseId)", error: nil, at: now)
        }
    }

    // MARK: - shared helpers

    private func activeCourseIds() -> [Int] {
        ((try? modelContext.fetch(FetchDescriptor<CachedCourse>())) ?? [])
            .filter { $0.removedAt == nil }
            .map(\.id)
    }

    private func fetchOne<T: PersistentModel>(_ d: FetchDescriptor<T>) -> T? {
        var d = d; d.fetchLimit = 1
        return (try? modelContext.fetch(d))?.first
    }

    private func insert(_ changes: [PendingChange], now: Date) {
        for c in changes {
            modelContext.insert(ChangeRecord(kind: c.kind, courseId: c.courseId,
                                             subjectId: c.subjectId, title: c.title,
                                             detail: c.detail, occurredAt: now))
        }
    }

    private func touch(_ kind: EntityKind, scope: String, error: String?, at date: Date) {
        let key = "\(kind.rawValue):\(scope)"
        let row = fetchOne(FetchDescriptor<SyncMetadata>(predicate: #Predicate { $0.key == key }))
            ?? { let m = SyncMetadata(entityKind: kind.rawValue, scopeId: scope)
                 modelContext.insert(m); return m }()
        if error == nil { row.lastSyncedAt = date }
        row.lastErrorDescription = error
    }

    // Task 9 replaces this passthrough with rate-limit backoff.
    private func fetchWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
        try await operation()
    }

    // Task 8 fills this in.
    private func syncCourse(_ courseId: Int, client: APIClient, force: Bool) async throws {}
}
```

Note: `snapshot on resync` — `oldScore != score` is false on an identical resync, so idempotency holds.

- [ ] **Step 4: Run** — `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: SyncEngine .all scope with snapshots, soft delete, hidden migration"`

---

### Task 8: `SyncEngine` — scope `.course` (groups, assignments, submissions, comments, detector wiring)

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Create: `Tests/CanvasDataTests/SyncEngineCourseTests.swift`

**Interfaces:**
- Consumes: `ChangeDetector.submissionChanges` / `.dueSoonChanges` (Task 6), helpers from Task 7.
- Produces: working `refresh(.course(id))`; rows for `CachedAssignmentGroup`, `CachedAssignment` (with `dueAt` parsed via `CanvasDate`), `CachedSubmission`, `CachedComment`; `ChangeRecord`s.

- [ ] **Step 1: Write failing tests** (DEMO client again):

```swift
func testCourseSyncPopulatesGroupsAssignmentsSubmissionsComments() async throws
// refresh(.course(MockData.csCourseId)) → counts match MockData for that course;
// a CachedAssignment has dueAt parsed to a real Date; comments only for ids present

func testCourseResyncIsIdempotentAndBaselineSilent() async throws
// refresh(.course(id)) twice → same row counts both times, zero ChangeRecords
// (first sync = baseline; second sync = identical data)

func testGradeTransitionEmitsNewGradeRecord() async throws
// refresh(.course(id)); pick a graded CachedSubmission, set its score to nil in the store
// (simulating "previously ungraded"); refresh(.course(id), force: true)
// → exactly one ChangeRecord kind "newGrade" for that assignmentId

func testMutedGradeNeverEmitsNewGrade() async throws
// MockData includes a workflowState "graded" score nil submission (add one if missing);
// two syncs → zero newGrade records for it

func testAssignmentMissingFromFetchIsSoftDeleted() async throws
// refresh(.course(id)); insert CachedAssignment(id: 555555, courseId: id, ...) by hand;
// refresh(.course(id), force: true) → removedAt != nil on it
```

- [ ] **Step 2: Run to verify failure** — FAIL (`syncCourse` is a stub).

- [ ] **Step 3: Implement** `syncCourse` (replacing the Task 7 stub):

```swift
private func syncCourse(_ courseId: Int, client: APIClient, force: Bool) async throws {
    let now = Date()
    async let groupsFetch = fetchWithRetry { try await client.assignmentGroups(courseId: courseId) }
    async let subsFetch = fetchWithRetry { try await client.submissions(courseId: courseId) }

    var firstError: (any Error)?

    do {
        let groups = try await groupsFetch
        upsertGroups(groups, courseId: courseId, now: now)
        touch(.assignments, scope: "\(courseId)", error: nil, at: now)
    } catch {
        firstError = error
        touch(.assignments, scope: "\(courseId)", error: String(describing: error), at: now)
    }

    do {
        let subs = try await subsFetch
        let old = submissionSnapshots(courseId: courseId)
        upsertSubmissions(subs, courseId: courseId)
        let names = assignmentNames(courseId: courseId)
        insert(ChangeDetector.submissionChanges(courseId: courseId, old: old,
                                                new: subs, assignmentNames: names), now: now)
        if !old.isEmpty {   // baseline suppression applies to dueSoon too
            insert(dueSoonPending(courseId: courseId, subs: subs, now: now), now: now)
        }
        touch(.submissions, scope: "\(courseId)", error: nil, at: now)
    } catch {
        if firstError == nil { firstError = error }
        touch(.submissions, scope: "\(courseId)", error: String(describing: error), at: now)
    }

    try modelContext.save()
    // Partial failure is normal (spec §2.5): throw only if *everything* failed.
    if let firstError, fetchCount(FetchDescriptor<CachedAssignmentGroup>(
        predicate: #Predicate { $0.courseId == courseId })) == 0 {
        throw firstError
    }
}
```

Supporting private helpers (same file):

```swift
private func upsertGroups(_ groups: [AssignmentGroup], courseId: Int, now: Date) {
    // Upsert CachedAssignmentGroup by id (name, groupWeight, rules → dropLowest/dropHighest/neverDrop).
    // Flatten groups → assignments; upsert CachedAssignment by id with
    // groupId = a.assignmentGroupId, dueAt = CanvasDate.parse(a.dueAt),
    // sortIndex = running counter across the flattened order (matches buildGradedItems order).
    // Soft-delete: any stored CachedAssignment/CachedAssignmentGroup for this courseId
    // whose id is absent from the fetch and removedAt == nil → removedAt = now.
}

private func upsertSubmissions(_ subs: [Submission], courseId: Int) {
    // Upsert CachedSubmission by id (score, workflowState,
    // gradedAt/submittedAt via CanvasDate.parse, userId, assignmentId, courseId).
    // For each submissionComments entry with a non-nil id: upsert CachedComment
    // (submissionId = sub.id, assignmentId = sub.assignmentId, body = comment.comment).
}

private func submissionSnapshots(courseId: Int) -> [Int: SubmissionSnapshot] {
    // Fetch CachedSubmission for courseId; for each, gather comment ids via
    // CachedComment where submissionId == sub.id; key by assignmentId.
}

private func assignmentNames(courseId: Int) -> [Int: String] { /* CachedAssignment id → name */ }

private func dueSoonPending(courseId: Int, subs: [Submission], now: Date) -> [PendingChange] {
    let assignments = /* CachedAssignment rows for courseId, removedAt == nil */
        .map { (id: $0.id, name: $0.name, dueAt: $0.dueAt) }
    let submitted = Set(subs.filter { $0.submittedAt != nil || ($0.workflowState == "graded") }
        .map(\.assignmentId))
    let notified = Set(/* ChangeRecord rows kind == "dueSoon" && courseId == courseId */
        .compactMap(\.subjectId))
    return ChangeDetector.dueSoonChanges(courseId: courseId, assignments: assignments,
                                         submittedAssignmentIds: submitted,
                                         alreadyNotified: notified, now: now)
}

private func fetchCount<T: PersistentModel>(_ d: FetchDescriptor<T>) -> Int {
    (try? modelContext.fetchCount(d)) ?? 0
}
```

Write the bodies fully (each is a fetch-dict-loop like `upsertCourses` in Task 7). BYUH quirk reminder: treat `workflowState == "graded" && submittedAt == nil` as submitted for dueSoon purposes — BYUH never returns `"submitted"` (spec §3.1).

- [ ] **Step 4: Run** — `swift test` → all PASS. If MockData lacks a muted-grade submission (`workflow_state: "graded"`, `score: nil`), add one to `MockData.submissions` and update `MockDataTests` expectations accordingly.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: SyncEngine per-course sync with change detection"`

---

### Task 9: `SyncEngine` — TTL freshness gate, rate-limit backoff, partial-failure isolation

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Create: `Tests/CanvasDataTests/SyncEnginePolicyTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 7–8.
- Produces: TTL-gated `refresh` (courses 300s, enrollments 300s, assignments 900s, submissions 300s — spec §2.5); `fetchWithRetry` with one backoff retry on `.rateLimited`.

- [ ] **Step 1: Write failing tests**

```swift
func testTTLGateSkipsFreshData() async throws
// refresh(.all); capture SyncMetadata "courses:all".lastSyncedAt;
// sleep 0.05s; refresh(.all) WITHOUT force → lastSyncedAt unchanged (fetch skipped)

func testForceBypassesTTL() async throws
// same setup; refresh(.all, force: true) → lastSyncedAt advanced

func testPartialFailureIsolation() async throws
// URLProtocol stub (CanvasDataTests copy of the PaginationStub pattern) serving:
//   /courses → 200 with 2 courses; /courses/1/enrollments → 200; /courses/2/enrollments → 500
// refresh(.all) with a real-token client on the stub session →
// does NOT throw; course 1 enrollment stored; SyncMetadata "enrollments:2".lastErrorDescription != nil,
// "enrollments:1".lastErrorDescription == nil

func testRateLimitedRetriesOnceThenSucceeds() async throws
// stub returns 403 "Rate Limit Exceeded" + Retry-After: 0 on first /courses hit, 200 on second
// refresh(.all) succeeds; request count == 2
```

For the stubs, create `Tests/CanvasDataTests/SyncStub.swift`: a `URLProtocol` with `static var responses: [String: [(status: Int, body: Data, headers: [String: String])]]` keyed by URL path, popping sequentially, plus `static var hitCount: [String: Int]`. Fixture JSON: hand-write minimal snake_case arrays matching `Course`/`Enrollment` fields.

- [ ] **Step 2: Run to verify failure** — FAIL (no TTL gate; no retry).

- [ ] **Step 3: Implement**

TTL table + gate:

```swift
private static let ttl: [EntityKind: TimeInterval] = [
    .courses: 300, .enrollments: 300, .assignments: 900, .submissions: 300,
]

private func isFresh(_ kind: EntityKind, scope: String, now: Date) -> Bool {
    let key = "\(kind.rawValue):\(scope)"
    guard let last = fetchOne(FetchDescriptor<SyncMetadata>(
        predicate: #Predicate { $0.key == key }))?.lastSyncedAt else { return false }
    return now.timeIntervalSince(last) < (Self.ttl[kind] ?? 0)
}
```

Wire into `syncAll` (wrap the courses fetch+upsert in `if force || !isFresh(.courses, scope: "all", now: now)`, and filter the enrollment fan-out ids by `force || !isFresh(.enrollments, scope: "\(id)", now: now)`) and into `syncCourse` (compute `needAssignments` / `needSubmissions`; skip the corresponding fetch when fresh; `guard needAssignments || needSubmissions else { return }`).

Replace `fetchWithRetry`:

```swift
private func fetchWithRetry<T>(_ operation: () async throws -> T) async throws -> T {
    do {
        return try await operation()
    } catch let APIError.rateLimited(retryAfter) {
        try await Task.sleep(nanoseconds: UInt64(min(retryAfter, 30) * 1_000_000_000))
        return try await operation()
    }
}
```

Also wrap the enrollment fan-out task bodies in `fetchWithRetry`.

- [ ] **Step 4: Run** — `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: SyncEngine TTL gate, rate-limit backoff, partial-failure isolation"`

---

### Task 10: Derived reads — `CalculatorInputs` and course stream from the store

**Files:**
- Create: `Sources/CanvasData/DerivedReads.swift`, `Tests/CanvasDataTests/DerivedReadsTests.swift`
- Modify: `CanvasApp/ViewModels/CourseDetailViewModel.swift` (delete `StreamItem`/`StreamAssignment` definitions only — the rest of the file changes in Task 14; add `import CanvasData` so it still compiles)

**Interfaces:**
- Consumes: repository (Task 5), `GradedItem`, `GroupInfo`, `buildGradedItems` (for the equivalence test) from `CanvasCore`.
- Produces:

```swift
public struct CalculatorInputs {
    public let items: [GradedItem]
    public let groups: [Int: GroupInfo]
    public let weighted: Bool
    public let scale: [(String, Double)]
}

public struct StreamAssignment: Sendable {
    public let id: Int
    public let name: String
    public let pointsPossible: Double?
    public let dueAt: Date?
    public init(id: Int, name: String, pointsPossible: Double?, dueAt: Date?)
}

public struct StreamItem: Sendable {
    public enum Kind: Sendable {
        case awaitingGrade
        case upcoming(due: Date)
        case recentlyGraded(score: Double?, possible: Double?, gradedAt: Date?)
        case feedback(authorName: String, comment: String, createdAt: Date?)
    }
    public let assignment: StreamAssignment
    public let kind: Kind
    public init(assignment: StreamAssignment, kind: Kind)
}

extension CanvasRepository {
    public func calculatorInputs(courseId: Int) throws -> CalculatorInputs?  // nil if course unknown
    public func stream(courseId: Int, now: Date = .init()) throws -> [StreamItem]
}
```

- [ ] **Step 1: Write failing tests**

```swift
func testCalculatorInputsMatchBuildGradedItems() async throws
// DEMO sync .all + .course(MockData.csCourseId); then:
// expected = buildGradedItems(groups: MockData.assignmentGroups[id]!, submissions: MockData.submissions[id]!)
// actual = repository.calculatorInputs(courseId: id)!.items
// assert same count, and element-wise equal (assignmentId, name, groupId, pointsPossible, earnedPoints)
// assert groups dict matches MockData group rules; weighted matches the course flag

func testStreamRulesOverCache() async throws
// After the same sync: repository.stream(courseId:) reproduces the CourseDetailViewModel rules:
//  - muted grade (graded, score nil) → .awaitingGrade (NOT .recentlyGraded)
//  - future-due unsubmitted → .upcoming, soonest first, max 2
//  - graded with score → .recentlyGraded, newest gradedAt first, max 2
//  - instructor comments (authorId != userId) → .feedback, newest first, max 3
//  - awaitingGrade capped at 2
```

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement**

`calculatorInputs` mirrors `buildGradedItems` (`GradeCalculator.swift:38`) over cached rows:

```swift
public func calculatorInputs(courseId: Int) throws -> CalculatorInputs? {
    guard let course = try course(id: courseId) else { return nil }
    let subs = try submissions(courseId: courseId)
    let scoreByAssignment = Dictionary(subs.map { ($0.assignmentId, $0.score) },
                                       uniquingKeysWith: { first, _ in first })
    let items: [GradedItem] = try assignments(courseId: courseId).compactMap { a in
        guard let pts = a.pointsPossible else { return nil }
        return GradedItem(assignmentId: a.id, name: a.name, groupId: a.groupId,
                          pointsPossible: pts, earnedPoints: scoreByAssignment[a.id] ?? nil)
    }
    let groupInfo = Dictionary(uniqueKeysWithValues: try assignmentGroups(courseId: courseId).map {
        ($0.id, GroupInfo(name: $0.name, weight: $0.groupWeight,
                          dropLowest: $0.dropLowest, dropHighest: $0.dropHighest,
                          neverDrop: Set($0.neverDrop)))
    })
    return CalculatorInputs(items: items, groups: groupInfo,
                            weighted: course.applyGroupWeights, scale: course.gradingScale)
}
```

`stream(courseId:now:)` ports `CourseDetailViewModel.buildStream` (`CourseDetailViewModel.swift:72`) 1:1, reading `CachedAssignment`/`CachedSubmission`/`CachedComment` (dates already `Date`, so drop the `ISO8601DateFormatter` plumbing). Keep the exact filters, sort orders, and prefix caps (2/2/2/3), including the awaiting-grade predicate `workflowState == "submitted" || workflowState == "pending_review" || (workflowState == "graded" && score == nil)`. Feedback uses `CachedComment` joined via `submissionId`, filtered `authorId != submission.userId`.

Move `StreamItem`/`StreamAssignment` out of `CourseDetailViewModel.swift` (now defined in CanvasData); update `CourseDetailView.swift` and `CourseDetailViewModel.swift` with `import CanvasData`.

- [ ] **Step 4: Run** — `swift test` → all PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: calculator inputs and course stream derived from the store"`

---

### Task 11: `CanvasUI` shared components

**Files:**
- Create in `Sources/CanvasUI/`: `CourseCard.swift`, `LetterBadge.swift`, `GradeDashboard.swift`, `StreamSection.swift`, `CalculatorView.swift`, `StalenessLabel.swift`, `SkeletonList.swift`
- Modify: `CanvasApp/Views/CourseListView.swift`, `CanvasApp/Views/CourseDetailView.swift`
- Delete: `CanvasApp/Views/CalculatorView.swift`, `CanvasApp/ViewModels/CalculatorViewModel.swift` (both move to CanvasUI)

**Interfaces:**
- Consumes: `GroupResult`, `GradeCalculator`, `GradedItem`, `GroupInfo`, `letterGrade(for:scale:)` (CanvasCore); `StreamItem` (CanvasData, Task 10); brand colors (Task 1).
- Produces (all `public`, value inputs only — no session/repository dependencies, spec §5.5):

```swift
public struct LetterBadge: View { public init(letter: String) }
public struct CourseCard: View {
    public init(name: String, courseCode: String, score: Double?, letter: String?)
}
public struct GradeDashboard: View {   // was GradeDashboardView; takes values, not a calculator
    public init(breakdown: [GroupResult], overall: Double?, gradingScale: [(String, Double)])
}
public struct GroupBreakdownRow: View {   // was GroupRowView
    public init(result: GroupResult, gradingScale: [(String, Double)])
}
public struct StreamSection: View { public init(items: [StreamItem]) }   // was CourseStreamView
public struct StreamRow: View { public init(item: StreamItem) }          // was StreamRowView
public struct CalculatorView: View {
    public init(items: [GradedItem], groupInfo: [Int: GroupInfo],
                gradingScale: [(String, Double)], weighted: Bool)
}
public struct StalenessLabel: View { public init(lastSyncedAt: Date?) }
public struct SkeletonList: View { public init(rows: Int = 6) }
```

- [ ] **Step 1: Move and genericize** (mechanical; the compiler drives it):

1. `LetterBadge` — extract the repeated letter-capsule (`.foregroundStyle(.white).padding(...).background(Color.letterGradeColor(letter), in: Capsule())`) used in `GradeDashboardView`/`GroupRowView` into one component; use it in both.
2. `CourseCard` — from `CourseCardView` (`CourseListView.swift:116`). Replace `course: Course, gradingScale:` inputs with `name/courseCode/score/letter` values; the caller computes `letter` (via `letterGrade(for:scale:)`).
3. `GradeDashboard` + `GroupBreakdownRow` — from `CourseDetailView.swift:56-126`. `GradeDashboard` takes `breakdown`/`overall` values instead of `calc: GradeCalculator` (caller calls `calc.groupBreakdown()`/`calc.currentGrade()`).
4. `StreamSection`/`StreamRow`/`StreamSectionHeader` — from `CourseDetailView.swift:130-274`, renamed, `import CanvasData` for `StreamItem`.
5. `CalculatorView` + `CalculatorViewModel` — `git mv` both files into `Sources/CanvasUI/`. Make both `public` (including `WhatIfEntry`, `TargetMode`, `SolveScope`, and the subviews used internally). Change `CalculatorViewModel.init` from `(course: Course, items:, groupInfo:, gradingScale:)` to `(items: [GradedItem], groupInfo: [Int: GroupInfo], gradingScale: [(String, Double)], weighted: Bool)` — the only `Course` usage is `course.applyAssignmentGroupWeights ?? false` in `liveCalculator`; store `weighted` instead. Update `CalculatorView.init` to match and pass through.
6. New `StalenessLabel`: `Text` showing `"Updated \(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: .now))"` in `.caption`/`.secondary`, or `"Not synced yet"` when nil.
7. New `SkeletonList`: `VStack` of `rows` gray `RoundedRectangle` bars, `.redacted(reason: .placeholder)` styling, for cold-cache loading (spec §5.8).
8. Add a `#Preview` with hard-coded sample values to every component file (no store needed — the point of value inputs).
9. Update the popover call sites in `CourseListView.swift` / `CourseDetailView.swift` to the new names/signatures (`import CanvasUI`). Keep behavior identical.

- [ ] **Step 2: Verify** — `swift build && swift test` → green. Launch check deferred to Task 14 (popover still compiles against old VMs).

- [ ] **Step 3: Commit** — `git add -A && git commit -m "refactor: extract shared value-driven components into CanvasUI"`

---

### Task 12: `AppSession` + `Router`

**Files:**
- Create: `CanvasApp/App/AppSession.swift`, `CanvasApp/App/Router.swift`
- Delete: nothing yet (AppState dies in Task 14)

**Interfaces:**
- Consumes: `CanvasStore`, `CanvasRepository`, `SyncEngine`, `Credentials`, `Profile`, `KeychainHelper` (host-scoped, Task 2).
- Produces (exact — Tasks 13–15 depend on these):

```swift
@MainActor @Observable final class AppSession {
    var credentials: Credentials?
    var hasSeenIntro: Bool
    var hasAcknowledgedKeychain: Bool
    var syncState: SyncState
    var host: String                       // UserDefaults "canvasHost", default "byuh.instructure.com"
    let repository: CanvasRepository
    let syncEngine: SyncEngine
    var isDemo: Bool { credentials?.token == "DEMO" }
    var hasCredentials: Bool { credentials != nil }

    init()
    func completeIntro()
    func acknowledgeKeychain()
    func saveCredentials(host: String, token: String)
    func replaceCredentials(host: String, token: String)   // clears store first
    func testConnection(host: String, token: String) async -> Result<Profile, any Error>
    func refresh(_ scope: SyncScope, force: Bool = false) async
    func detailViewModel(courseId: Int) -> CourseDetailViewModel
}

enum SidebarItem: Hashable { case dashboard, inbox, calendar, todo; case course(Int) }
enum CourseTab: String, CaseIterable, Hashable {
    case grades, assignments, announcements, discussions, modules, files, syllabus
}
enum RevealTarget {
    case section(SidebarItem)
    case course(id: Int, tab: CourseTab)
    case assignment(courseId: Int, assignmentId: Int)
    case conversation(id: Int)
}
@MainActor @Observable final class Router {
    var sidebar: SidebarItem       // persisted to UserDefaults "router.sidebar"
    var courseTab: CourseTab       // persisted to UserDefaults "router.courseTab"
    var selectedAssignmentId: Int?  // not persisted (spec §2.2)
    var selectedConversationId: Int?
    init()
    func reveal(_ target: RevealTarget)
}
```

- [ ] **Step 1: Implement `AppSession`**

```swift
import Foundation
import SwiftUI
import CanvasCore
import CanvasData

@MainActor @Observable
final class AppSession {
    var credentials: Credentials?
    var hasSeenIntro: Bool = UserDefaults.standard.bool(forKey: "hasSeenIntro")
    var hasAcknowledgedKeychain: Bool = UserDefaults.standard.bool(forKey: "hasAcknowledgedKeychain")
    var syncState: SyncState = .idle
    var host: String = UserDefaults.standard.string(forKey: "canvasHost") ?? "byuh.instructure.com"

    let repository: CanvasRepository
    let syncEngine: SyncEngine
    private var detailVMs: [Int: CourseDetailViewModel] = [:]

    var isDemo: Bool { credentials?.token == "DEMO" }
    var hasCredentials: Bool { credentials != nil }

    init() {
        let container: ModelContainer
        do {
            container = try CanvasStore.container()
        } catch {
            // A corrupt store must not brick the app: fall back to in-memory for this run.
            container = try! CanvasStore.container(inMemory: true)
        }
        repository = CanvasRepository(modelContainer: container)
        syncEngine = SyncEngine(modelContainer: container)
        try? repository.purgeExpired()
        if hasAcknowledgedKeychain, let token = KeychainHelper.load(host: host) {
            credentials = Credentials(host: host, token: token)
        }
        Task { await wireEngine() }
    }

    private func wireEngine() async {
        await syncEngine.setStateHandler { [weak self] state in
            Task { @MainActor in self?.syncState = state }
        }
        await syncEngine.configure(client: credentials.map { APIClient(credentials: $0) })
    }

    func completeIntro() {
        UserDefaults.standard.set(true, forKey: "hasSeenIntro")
        hasSeenIntro = true
    }

    func acknowledgeKeychain() {
        UserDefaults.standard.set(true, forKey: "hasAcknowledgedKeychain")
        hasAcknowledgedKeychain = true
        if let token = KeychainHelper.load(host: host) {
            credentials = Credentials(host: host, token: token)
            Task { await wireEngine() }
        }
    }

    func saveCredentials(host newHost: String, token rawToken: String) {
        var token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.lowercased().hasPrefix("bearer ") {
            token = String(token.dropFirst(7)).trimmingCharacters(in: .whitespaces)
        }
        guard !token.isEmpty else { return }
        KeychainHelper.save(token: token, host: newHost)
        UserDefaults.standard.set(newHost, forKey: "canvasHost")
        host = newHost
        credentials = Credentials(host: newHost, token: token)
        detailVMs = [:]
        Task {
            await wireEngine()
            await refresh(.all, force: true)
        }
    }

    func replaceCredentials(host newHost: String, token: String) {
        try? repository.clearStore()
        saveCredentials(host: newHost, token: token)
    }

    func testConnection(host testHost: String, token: String) async -> Result<Profile, any Error> {
        let client = APIClient(credentials: Credentials(host: testHost, token: token))
        do { return .success(try await client.profile()) }
        catch { return .failure(error) }
    }

    func refresh(_ scope: SyncScope, force: Bool = false) async {
        do { try await syncEngine.refresh(scope, force: force) }
        catch { /* state handler already carries .failed; VMs surface per-section errors */ }
    }

    func detailViewModel(courseId: Int) -> CourseDetailViewModel {
        if let existing = detailVMs[courseId] { return existing }
        let vm = CourseDetailViewModel(courseId: courseId)
        detailVMs[courseId] = vm
        return vm
    }
}
```

(`CourseDetailViewModel(courseId:)` doesn't exist until Task 14 — implement Tasks 12–14 on one branch-of-work and only expect a green build at Task 14's verify step, or temporarily keep the old initializer overload. Recommended: do Task 12 and 13 with `detailViewModel` commented `// wired in Task 14`, compile-gated with a temporary stub `CourseDetailViewModel(courseId:)` initializer added alongside the old one.)

- [ ] **Step 2: Implement `Router`**

```swift
import Foundation
import SwiftUI

enum SidebarItem: Hashable {
    case dashboard, inbox, calendar, todo
    case course(Int)

    var storageKey: String {
        switch self {
        case .dashboard: return "dashboard"
        case .inbox: return "inbox"
        case .calendar: return "calendar"
        case .todo: return "todo"
        case .course(let id): return "course:\(id)"
        }
    }

    init(storageKey: String) {
        switch storageKey {
        case "inbox": self = .inbox
        case "calendar": self = .calendar
        case "todo": self = .todo
        case let key where key.hasPrefix("course:"):
            self = Int(key.dropFirst(7)).map(SidebarItem.course) ?? .dashboard
        default: self = .dashboard
        }
    }
}

enum CourseTab: String, CaseIterable, Hashable {
    case grades, assignments, announcements, discussions, modules, files, syllabus
}

enum RevealTarget {
    case section(SidebarItem)
    case course(id: Int, tab: CourseTab)
    case assignment(courseId: Int, assignmentId: Int)
    case conversation(id: Int)
}

@MainActor @Observable
final class Router {
    var sidebar: SidebarItem {
        didSet { UserDefaults.standard.set(sidebar.storageKey, forKey: "router.sidebar") }
    }
    var courseTab: CourseTab {
        didSet { UserDefaults.standard.set(courseTab.rawValue, forKey: "router.courseTab") }
    }
    var selectedAssignmentId: Int?
    var selectedConversationId: Int?

    init() {
        sidebar = SidebarItem(storageKey: UserDefaults.standard.string(forKey: "router.sidebar") ?? "dashboard")
        courseTab = CourseTab(rawValue: UserDefaults.standard.string(forKey: "router.courseTab") ?? "grades") ?? .grades
    }

    func reveal(_ target: RevealTarget) {
        switch target {
        case .section(let item):
            sidebar = item
        case .course(let id, let tab):
            sidebar = .course(id); courseTab = tab; selectedAssignmentId = nil
        case .assignment(let courseId, let assignmentId):
            sidebar = .course(courseId); courseTab = .assignments; selectedAssignmentId = assignmentId
        case .conversation(let id):
            sidebar = .inbox; selectedConversationId = id
        }
    }
}
```

- [ ] **Step 3: Verify** — `swift build` succeeds (AppSession/Router are not yet referenced by scenes).

- [ ] **Step 4: Commit** — `git add -A && git commit -m "feat: AppSession and Router shared observable state"`

---

### Task 13: Two scenes + window shell

**Files:**
- Modify: `CanvasApp/App/CanvasApp.swift`
- Create: `CanvasApp/Views/Window/MainWindowView.swift`, `CanvasApp/Views/Window/CourseWorkspaceView.swift`

**Interfaces:**
- Consumes: `AppSession`, `Router`, `SidebarItem`, `CourseTab` (Task 12); `CoursesViewModel`/`CourseDetailViewModel` (new shapes, Task 14); `CanvasUI` components (Task 11); `StalenessLabel`.
- Produces: `Window` scene id `"main"`; `MainWindowView`; `CourseWorkspaceView(courseId:)`.

- [ ] **Step 1: Rewrite `CanvasApp.swift`**

```swift
import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

@main
struct CanvasGradesApp: App {
    @State private var session = AppSession()
    @State private var router = Router()

    var body: some Scene {
        MenuBarExtra("Canvas", systemImage: "graduationcap.fill") {
            PopoverContent()
                .environment(session)
                .environment(router)
                .frame(width: 380, height: 520)
        }
        .menuBarExtraStyle(.window)

        Window("Canvas", id: "main") {
            MainWindowView()
                .environment(session)
                .environment(router)
        }
        .defaultSize(width: 1000, height: 700)
    }
}
```

`PopoverContent` stays in this file; its body is migrated in Task 14 (until then it still compiles against whatever remains — do Tasks 13 and 14 back-to-back; the build gate is Task 14 Step 4).

- [ ] **Step 2: `MainWindowView`**

```swift
import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct MainWindowView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @StateObject private var coursesVM = CoursesViewModel()

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(selection: Binding(get: { Optional(router.sidebar) },
                                    set: { router.sidebar = $0 ?? .dashboard })) {
                Section {
                    Label("Dashboard", systemImage: "square.grid.2x2").tag(SidebarItem.dashboard)
                    Label("Inbox", systemImage: "tray").tag(SidebarItem.inbox)
                    Label("Calendar", systemImage: "calendar").tag(SidebarItem.calendar)
                    Label("To-Do", systemImage: "checklist").tag(SidebarItem.todo)
                }
                Section("Courses") {
                    ForEach(coursesVM.courses, id: \.id) { course in
                        HStack {
                            Circle().fill(accentColor(for: course.courseCode)).frame(width: 8, height: 8)
                            Text(course.courseCode)
                            Spacer()
                            if let letter = coursesVM.letter(for: course.id) {
                                LetterBadge(letter: letter)
                            }
                        }
                        .tag(SidebarItem.course(course.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            switch router.sidebar {
            case .dashboard: ComingSoonView(title: "Dashboard", phase: "Phase 1")
            case .inbox:     ComingSoonView(title: "Inbox", phase: "Phase 2")
            case .calendar:  ComingSoonView(title: "Calendar", phase: "Phase 3")
            case .todo:      ComingSoonView(title: "To-Do", phase: "Phase 3")
            case .course(let id): CourseWorkspaceView(courseId: id)
            }
        }
        .frame(minWidth: 900, minHeight: 600)   // spec §5.1
        .toolbar {
            ToolbarItem(placement: .status) {
                StalenessLabel(lastSyncedAt: coursesVM.lastSyncedAt)
            }
            ToolbarItem {
                Button {
                    Task { await coursesVM.load(session: session, force: true) }
                } label: {
                    if case .syncing = session.syncState { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .help("Refresh")
            }
        }
        .task { await coursesVM.load(session: session) }
    }

    /// Phase 0 accent: stable hash of the course code (spec §5.1 fallback;
    /// /users/self/colors arrives in Phase 1).
    private func accentColor(for code: String) -> Color {
        let hues: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .red]
        return hues[abs(code.hashValue) % hues.count]
    }
}

struct ComingSoonView: View {
    let title: String
    let phase: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer",
                               description: Text("Coming in \(phase)."))
    }
}
```

- [ ] **Step 3: `CourseWorkspaceView`** — tab picker over `Router.courseTab`; only Grades has content in Phase 0:

```swift
import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct CourseWorkspaceView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @State private var showCalculator = false

    var body: some View {
        @Bindable var router = router
        let vm = session.detailViewModel(courseId: courseId)
        VStack(spacing: 0) {
            Picker("Tab", selection: $router.courseTab) {
                ForEach(CourseTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue.capitalized).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            Divider()
            if router.courseTab == .grades {
                GradesTabView(vm: vm, showCalculator: $showCalculator)
            } else {
                ComingSoonView(title: router.courseTab.rawValue.capitalized, phase: "a later phase")
            }
        }
        .navigationTitle(vm.courseCode ?? "Course")
        .toolbar {
            ToolbarItem {
                Toggle(isOn: $showCalculator) { Image(systemName: "function") }
                    .help("What-If Calculator")
            }
        }
        .task(id: courseId) { await vm.load(session: session) }
    }
}

struct GradesTabView: View {
    @ObservedObject var vm: CourseDetailViewModel
    @Binding var showCalculator: Bool

    var body: some View {
        Group {
            if let calc = vm.calculator {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        GradeDashboard(breakdown: calc.groupBreakdown().sorted { $0.weight > $1.weight },
                                       overall: calc.currentGrade(),
                                       gradingScale: calc.gradingScale)
                        if !vm.streamItems.isEmpty {
                            StreamSection(items: vm.streamItems)
                        }
                        StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding()
                    }
                }
            } else if vm.isLoading {
                SkeletonList()                       // cold, no cache (spec §5.8)
            } else if let error = vm.error {
                ContentUnavailableView { Label("Couldn't Load Grades", systemImage: "exclamationmark.triangle") }
                    description: { Text(error) }
            } else {
                Text("No grade data available.").foregroundStyle(.secondary)
            }
        }
        .inspector(isPresented: $showCalculator) {
            if let inputs = vm.inputs {
                CalculatorView(items: inputs.items, groupInfo: inputs.groups,
                               gradingScale: inputs.scale, weighted: inputs.weighted)
                    .inspectorColumnWidth(min: 300, ideal: 340)
            }
        }
    }
}
```

- [ ] **Step 4: Verify** — compiles once Task 14 lands (the VM shapes referenced here are Task 14's deliverable). Commit together with Task 14 if needed, or stub minimally to keep the build green.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: Window scene with NavigationSplitView shell and course workspace"`

---

### Task 14: Popover migration — repository-backed VMs, change feed, cross-scene reveal

**Files:**
- Modify: `CanvasApp/ViewModels/CoursesViewModel.swift`, `CanvasApp/ViewModels/CourseDetailViewModel.swift`, `CanvasApp/App/CanvasApp.swift` (PopoverContent), `CanvasApp/Views/CourseListView.swift`, `CanvasApp/Views/CourseDetailView.swift`, `CanvasApp/Views/SettingsView.swift`, `CanvasApp/Views/WelcomeView.swift`, `CanvasApp/Views/KeychainWarningView.swift`
- Delete: `CanvasApp/App/AppState.swift`, `CanvasApp/App/HiddenCoursesStore.swift`

**Interfaces:**
- Consumes: `AppSession`, `Router`, repository methods (Tasks 5, 10), `CanvasUI` components.
- Produces (Task 13 and 15 depend on these VM shapes):

```swift
@MainActor final class CoursesViewModel: ObservableObject {
    @Published var courses: [CachedCourse]
    @Published var isLoading: Bool          // true only while syncing with an empty cache
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    @Published var unseenChanges: [ChangeRecord]
    init()
    func load(session: AppSession, force: Bool = false) async
    func currentScore(for courseId: Int) -> Double?
    func letter(for courseId: Int) -> String?
    func hide(courseId: Int, session: AppSession)
    func restore(courseId: Int, session: AppSession)
    func hiddenCourses(session: AppSession) -> [CachedCourse]
    func markChangesSeen(session: AppSession)
}

@MainActor final class CourseDetailViewModel: ObservableObject {
    let courseId: Int
    @Published var inputs: CalculatorInputs?
    @Published var streamItems: [StreamItem]
    @Published var isLoading: Bool
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    var courseCode: String?                  // from the cached course row
    var calculator: GradeCalculator? {
        inputs.map { GradeCalculator(items: $0.items, groups: $0.groups,
                                     weighted: $0.weighted, gradingScale: $0.scale) }
    }
    init(courseId: Int)
    func load(session: AppSession, force: Bool = false) async
}
```

- [ ] **Step 1: Rewrite the VMs.** Pattern for both (spec §5.6: "fetch bodies are replaced with repository reads and `syncEngine.refresh` calls"):

```swift
func load(session: AppSession, force: Bool = false) async {
    readFromStore(session)                       // instant render from disk
    guard session.hasCredentials else { return }
    isLoading = (courses.isEmpty)                // skeleton only when cold (spec §5.8)
    error = nil
    await session.refresh(.all, force: force)    // .course(courseId) in the detail VM
    if case .failed(let message, _) = session.syncState { error = message }
    readFromStore(session)                       // re-read after sync
    isLoading = false
}
```

`CoursesViewModel.readFromStore`: `courses = (try? session.repository.courses()) ?? []`; per-course scores from `session.repository.enrollment(courseId:)` into a private `[Int: Double]`; `letter(for:)` computes via `letterGrade(for:scale:)` with the course's `gradingScale`; `lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "courses", scopeId: "all")`; `unseenChanges = (try? session.repository.unseenChanges()) ?? []`. `hide/restore` call `session.repository.setHidden(_:courseId:)` then re-read. Delete the old `HiddenCoursesStore` sink, `fetch(client:)`, TTL fields, and the `DecodingError` switch (decode errors now live inside SyncEngine metadata).

`CourseDetailViewModel.readFromStore`: `inputs = try? session.repository.calculatorInputs(courseId: courseId) ?? nil`; `streamItems = (try? session.repository.stream(courseId: courseId)) ?? []`; `courseCode = try? session.repository.course(id: courseId)?.courseCode`; `lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "submissions", scopeId: "\(courseId)")`. Remove `buildStream` (moved to CanvasData in Task 10) and the old `fetch(client:)`.

- [ ] **Step 2: Migrate the views.**

- `PopoverContent`: swap `@EnvironmentObject var appState: AppState` for `@Environment(AppSession.self) private var session`; same onboarding chain (`hasSeenIntro` → `hasAcknowledgedKeychain` → `hasCredentials` → main). The `NavigationStack` keeps a local `@State private var path = NavigationPath()`; `SettingsView` closes itself with `@Environment(\.dismiss)` instead of `appState.navigationPath.removeLast()`.
- `WelcomeView`/`KeychainWarningView`: `appState.completeIntro()` → `session.completeIntro()`, etc.
- `CourseListView`: rows use `CourseCard(name:courseCode:score:letter:)`; context menu Hide → `vm.hide(courseId:session:)`; `.task { await vm.load(session: session) }`; refresh button `Task { await vm.load(session: session, force: true) }`. Add at the top of the scroll, when `!vm.unseenChanges.isEmpty`, a **"Since you last looked"** section (spec §5.6): one compact row per record (`Image(systemName:)` per kind, `title`, `detail`), a "Mark all seen" button calling `vm.markChangesSeen(session:)`. Add to each course row a context-menu item **"Open in Window"**:

```swift
Button("Open in Window") {
    router.reveal(.course(id: course.id, tab: .grades))
    openWindow(id: "main")
    NSApp.activate(ignoringOtherApps: true)
}
.keyboardShortcut(.return, modifiers: .command)
```

  (`@Environment(\.openWindow) private var openWindow`, `@Environment(Router.self) private var router`.) Also add a toolbar button next to Settings: `Image(systemName: "macwindow")` doing `openWindow(id: "main")` + activate — the popover's "Open Window" affordance.
- `CourseDetailView`: `init(courseId:)`; body uses `vm.calculator` / `GradeDashboard` / `StreamSection` exactly as `GradesTabView` does; "Open Calculator" `NavigationLink` passes `vm.inputs` values into the new `CalculatorView(items:groupInfo:gradingScale:weighted:)`; add toolbar "Open in Window" (`router.reveal(.course(id: courseId, tab: .grades))` + `openWindow` + activate, `⌘↩` shortcut). Error state: if `error` contains "Invalid token", show the existing "Update Token…" affordance (dedicated re-auth screen is a later phase).
- `SettingsView`: replace `hiddenStore` with `vm.hiddenCourses(session:)` + `vm.restore(courseId:session:)` (pass the popover's `CoursesViewModel` in, or give SettingsView its own lightweight reads via `session.repository.courses(includeHidden: true)` — implementer's choice; repository reads are the source of truth). Token save now `session.saveCredentials(host: session.host, token: tokenInput)` (host field arrives in Task 15).
- Delete `AppState.swift` and `HiddenCoursesStore.swift`; fix any straggler references.

- [ ] **Step 3: Wire the temporary stubs out** — remove any Task 12/13 compile stubs; `session.detailViewModel(courseId:)` now returns the real VM.

- [ ] **Step 4: Verify**

Run: `swift build && swift test` → green.
Run the app (`swift run CanvasApp` or via Xcode): with token `DEMO` —
1. Popover: onboarding → course list renders **instantly on second launch** (from disk, before any sync), course detail + stream + calculator work, hide/restore works.
2. "Open in Window" from a course lands the window on that course's Grades tab (cross-scene reveal).
3. Window: sidebar lists demo courses with letter badges; Grades tab + inspector calculator work; global sections show Coming Soon; relaunch restores last sidebar selection.
4. Quit and relaunch with networking off (Wi-Fi disabled): everything still renders from cache with "Updated … ago" labels.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat: popover on repository, change feed, cross-scene reveal; retire AppState"`

---

### Task 15: Onboarding — host field, connection test, host-change store clear

**Files:**
- Modify: `CanvasApp/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `Credentials.normalizeHost`, `session.testConnection`, `session.saveCredentials`, `session.replaceCredentials`, `repository.courses`.

- [ ] **Step 1: Implement** (spec §2.6). Add to `SettingsView`:

```swift
@State private var hostInput: String = ""      // seeded from session.host in .onAppear
@State private var tokenInput = ""
@State private var testState: TestState = .idle
@State private var confirmHostChange = false

enum TestState: Equatable {
    case idle, testing
    case success(name: String)
    case failure(message: String)
}
```

Form fields: a "Canvas Host" `TextField` above the token field with caption "Your school's Canvas domain", then the existing token `SecureField`. Buttons:

- **Test Connection** — enabled when `Credentials.normalizeHost(hostInput) != nil && !tokenInput.isEmpty`. Action: `testState = .testing`; `await session.testConnection(host: normalized, token: trimmedToken)`; on success `testState = .success(name: profile.name)` ("Connected as **Demo Student**" for DEMO — the short-circuit makes demo pass automatically); on failure `.failure(message:)` with the `APIError` description. Show the result inline with a checkmark/warning icon.
- **Save** — enabled only when `testState` is `.success`. Action:

```swift
let normalized = Credentials.normalizeHost(hostInput)!
let hostChanged = normalized != session.host
let hasData = !((try? session.repository.courses(includeHidden: true)) ?? []).isEmpty
if hostChanged && hasData {
    confirmHostChange = true          // .confirmationDialog below
} else {
    session.saveCredentials(host: normalized, token: tokenInput)
    if !isOnboarding { dismiss() }
}
```

`.confirmationDialog("Switching schools clears the local cache. Your data re-syncs from \(hostInput).", isPresented: $confirmHostChange)` with a destructive "Switch & Clear" button calling `session.replaceCredentials(host: normalized, token: tokenInput)` then dismiss. Show inline validation ("Not a valid hostname") when `normalizeHost` returns nil and the field is non-empty.

- [ ] **Step 2: Verify manually** — DEMO: test connection shows "Demo Student", save syncs and lands on courses. Change host to `canvas.other.edu` with existing demo data → confirmation appears → confirming clears and re-syncs. Invalid host string shows inline error. `swift build && swift test` green.

- [ ] **Step 3: Commit** — `git add -A && git commit -m "feat: onboarding host field with connection test and host-change clear"`

---

### Task 16: Concurrency stress test + full Phase 0 verification

**Files:**
- Create: `Tests/CanvasDataTests/ConcurrencyStressTests.swift`

- [ ] **Step 1: Write the stress test** (spec §10 risk 1 — validate `@ModelActor` writes vs main-actor reads *now*, not in Phase 3):

```swift
import XCTest
import SwiftData
@testable import CanvasData
import CanvasCore

final class ConcurrencyStressTests: XCTestCase {
    @MainActor
    func testConcurrentSyncAndReads() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let repository = CanvasRepository(modelContainer: container)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(
            credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))

        let writer = Task {
            for _ in 0..<10 {
                try await engine.refresh(.all, force: true)
                for id in [MockData.csCourseId, MockData.mathCourseId] {
                    try await engine.refresh(.course(id), force: true)
                }
            }
        }
        for _ in 0..<500 {
            _ = try repository.courses()
            _ = try repository.calculatorInputs(courseId: MockData.csCourseId)
            _ = try repository.stream(courseId: MockData.csCourseId)
            await Task.yield()
        }
        try await writer.value
        XCTAssertEqual(try repository.courses(includeHidden: true).count, MockData.courses.count)
    }
}
```

- [ ] **Step 2: Run it** — `swift test --filter ConcurrencyStressTests` → PASS with no crash. Optionally once with TSan: `swift test --filter ConcurrencyStressTests -Xswiftc -sanitize=thread`.

- [ ] **Step 3: Full verification (spec §8 "manual verification per phase")**

1. `swift build && swift test` — entire suite green; confirm `GradeCalculator.swift` has no diff (`git diff main -- Sources/CanvasCore/GradeCalculator.swift` is empty).
2. Demo walkthrough, both scenes: onboarding (welcome → keychain → host+token test with `DEMO`) → popover list/detail/stream/calculator/hide-restore/change-feed → window sidebar/grades/inspector/coming-soon sections → cross-scene reveal → relaunch restores window section → offline relaunch renders everything from cache.
3. Live account walkthrough (user's real token): same path; verify muted grades appear as awaiting-grade, not recently-graded; verify a stale/revoked token surfaces the invalid-token affordance in both scenes.
4. `graphify update .`

- [ ] **Step 4: Final commit** — `git add -A && git commit -m "test: SwiftData concurrency stress test; Phase 0 verification complete"`

---

## Spec coverage map (Phase 0 items → tasks)

| Spec §9 Phase 0 item | Task(s) |
|---|---|
| Package split | 1 |
| `Credentials` + configurable host + connection test | 2, 3, 15 |
| SwiftData schema | 4 |
| `CanvasRepository` | 5, 10 |
| `SyncEngine` + `ChangeDetector` over the five existing endpoints | 6, 7, 8, 9 |
| `HiddenCoursesStore` migration | 7 (engine) + 14 (UI) |
| `AppSession`, `Router` | 12 |
| `Window` scene with sidebar shell | 13 |
| Popover re-pointed at repository (+ change feed, instant open, offline) | 14 |
| Cross-scene reveal | 14 |
| SwiftData concurrency validation (spec §10) | 16 |
| Demo fully walkable (spec §2.7) | every task; gated in 14–16 |

**Deferred beyond Phase 0** (per spec §9): re-auth dedicated screen (§5.8, Phase 1-adjacent — Phase 0 keeps the existing invalid-token affordance), `/users/self/colors` accents (Phase 1 — Phase 0 uses hash fallback), all remaining `APIClient` endpoints, remaining `SyncScope` cases, menu-bar badge + `NotificationScheduler` + background timer (Phase 2), `searchBlob` (Phase 4).
