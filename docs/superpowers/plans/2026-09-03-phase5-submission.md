# Phase 5 — Submission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a student submit an assignment (`online_upload` files, `online_text_entry`, or `online_url`) from the assignment detail pane, with a confirmation sheet, a verification round-trip, and text/URL draft preservation — walkable end-to-end in `DEMO` mode.

**Architecture:** Follows the app's established write path exactly — `SubmissionViewModel` → `AppSession.submit(...)` → `SyncEngine.submit(...)` (the sole store writer) → `APIClient` upload/submit/verify calls → upsert `CachedSubmission`. All request-body construction (multipart, form fields, extension checks) is factored into **pure functions in `CanvasCore`** and unit-tested directly (URLProtocol stubs cannot see streamed request bodies). The submit UI is an inline "Submission" section in the existing `AssignmentsTabView` detail column. Text/URL drafts persist in a new `@Model CachedSubmissionDraft`; file selections are session-only.

**Tech Stack:** Swift 5.9+ (Swift 6.3 toolchain), SwiftUI, SwiftData, XCTest, `URLSession`. No third-party dependencies. macOS 14+.

**Spec:** [`docs/superpowers/specs/2026-08-01-desktop-app-design.md`](file:///Users/kahuku-air/Developer/CanvasCLISwift/docs/superpowers/specs/2026-08-01-desktop-app-design.md) §7 (Assignment submission), §8 (Testing), §9 (Phasing).

## Global Constraints

- **Test framework:** XCTest only, `@testable import`. Every model, pure function, API endpoint, and orchestration path gets automated tests. CanvasUI/CanvasApp views are verified by manual DEMO walk (project convention — UI/App layers have no automated tests).
- **Full-suite `swift test` hangs** on this toolchain (deadlocks at the first SwiftData suite). **Run per-suite with `--filter`** — never wait on a bare `swift test`. (See `docs/superpowers/PROJECT-STATUS.md`.)
- **Demo verifiability:** the entire flow runs against the mutable `MockData` store with `CANVAS_TOKEN=DEMO` and is visibly labeled a demo.
- **Supported submission types (spec §7):** `online_upload`, `online_text_entry`, `online_url`. Every other type shows a "Submit in Canvas" link out — no in-app editor.
- **Verification is mandatory (spec §7):** a submit is NOT reported successful until a re-fetch of the submission returns the new `attempt`/`submitted_at`. On any failure, preserve the draft and offer retry + "Open in Canvas".
- **Disabled offline / token-less (spec §7):** the submit button is disabled when `session.apiClient == nil`.
- **Layer rule:** views read through `CanvasRepository`, never call `APIClient`. `SyncEngine` (`@ModelActor`) is the only thing that fetches and the only thing that writes the store. Mutations flow ViewModel → `AppSession.<action>` (thin async wrapper) → `SyncEngine.<action>` → `APIClient`.
- **DEMO short-circuit pattern:** every mutating/fetching `APIClient` method wraps its network body in `#if DEBUG … if token == "DEMO" { return MockData.demo…() } #endif`.
- **SF Symbols:** `paperclip`, `doc.badge.plus`, `textformat`, `link`, `arrow.up.circle.fill`, `checkmark.seal.fill`, `exclamationmark.triangle.fill`, `xmark.circle`, `clock.badge.exclamationmark`.

---

## File Structure

**Create — CanvasCore:**
- `Sources/CanvasCore/SubmissionRequest.swift` — `SubmissionType` enum, `UploadTicket` + `UploadedFile` decode models, `MultipartBody` pure builder, `SubmissionValidator` (extension check). One file: these are the small, pure request-shaping types that change together.

**Create — CanvasData:**
- `Sources/CanvasData/Models/SubmissionDraftModels.swift` — `@Model CachedSubmissionDraft`.

**Create — CanvasUI:**
- `Sources/CanvasUI/SubmissionComponents.swift` — `SubmissionEditor`, `SubmissionConfirmationSheet`, `SubmissionStatusView`.

**Create — CanvasApp:**
- `CanvasApp/ViewModels/SubmissionViewModel.swift` — the upload→submit→verify state machine.

**Create — Tests:**
- `Tests/CanvasCoreTests/SubmissionRequestTests.swift`
- `Tests/CanvasCoreTests/SubmissionAPITests.swift`
- `Tests/CanvasCoreTests/MockDataSubmitTests.swift`
- `Tests/CanvasDataTests/SubmissionDraftTests.swift`
- `Tests/CanvasDataTests/SubmitOrchestrationTests.swift`

**Modify:**
- `Sources/CanvasCore/Models.swift` — add `allowedExtensions` to `Assignment`.
- `Sources/CanvasCore/APIClient.swift` — add `requestUploadSlot`, `uploadFileBytes`, `submitAssignment`, `submissionSelf`.
- `Sources/CanvasCore/MockData.swift` — mutable submissions store + `demoSubmit`, `demoUploadSlot`.
- `Sources/CanvasData/CanvasStore.swift` — add `CachedSubmissionDraft.self` to schema.
- `Sources/CanvasData/CanvasRepository.swift` — `submissionDraft(assignmentId:)`, `submission(assignmentId:)`.
- `Sources/CanvasData/SyncEngine.swift` — `submit(...)`, `saveDraft(...)`, `deleteDraft(...)`; `SubmissionFile` payload struct.
- `CanvasApp/App/AppSession.swift` — `submit(...)`, `saveSubmissionDraft(...)` wrappers.
- `CanvasApp/Views/Window/AssignmentsTabView.swift` — inline "Submission" section in `detailColumn`.

---

# GROUP A — CORE MODELS, PURE BUILDERS & API CLIENT (`CanvasCore`)

### Task 1: `SubmissionType`, extension validation, and `Assignment.allowedExtensions`

**Files:**
- Modify: `Sources/CanvasCore/Models.swift` (Assignment struct, L63-99)
- Create: `Sources/CanvasCore/SubmissionRequest.swift`
- Test: `Tests/CanvasCoreTests/SubmissionRequestTests.swift`

**Interfaces:**
- Produces:
  - `Assignment.allowedExtensions: [String]?` (new stored property + init param).
  - `enum SubmissionType: String, Sendable, CaseIterable { case onlineUpload = "online_upload"; case onlineText = "online_text_entry"; case onlineURL = "online_url" }`
  - `static func SubmissionType.supported(from raw: [String]?) -> [SubmissionType]` — the app-supported subset, in a stable display order (upload, text, url).
  - `enum SubmissionValidator { static func isExtensionAllowed(_ filename: String, allowed: [String]?) -> Bool }` — `nil`/empty allowed ⇒ everything allowed; comparison is case-insensitive on the extension without the dot.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/CanvasCoreTests/SubmissionRequestTests.swift
import XCTest
@testable import CanvasCore

final class SubmissionRequestTests: XCTestCase {

    func testSupportedFiltersAndOrders() {
        let raw = ["online_url", "online_quiz", "online_upload", "online_text_entry", "on_paper"]
        XCTAssertEqual(SubmissionType.supported(from: raw),
                       [.onlineUpload, .onlineText, .onlineURL])
    }

    func testSupportedNilIsEmpty() {
        XCTAssertEqual(SubmissionType.supported(from: nil), [])
    }

    func testExtensionAllowedWhenListNilOrEmpty() {
        XCTAssertTrue(SubmissionValidator.isExtensionAllowed("essay.pdf", allowed: nil))
        XCTAssertTrue(SubmissionValidator.isExtensionAllowed("essay.pdf", allowed: []))
    }

    func testExtensionAllowedCaseInsensitive() {
        XCTAssertTrue(SubmissionValidator.isExtensionAllowed("Report.PDF", allowed: ["pdf", "docx"]))
        XCTAssertFalse(SubmissionValidator.isExtensionAllowed("virus.exe", allowed: ["pdf", "docx"]))
    }

    func testExtensionAllowedHandlesNoExtension() {
        XCTAssertFalse(SubmissionValidator.isExtensionAllowed("README", allowed: ["pdf"]))
    }

    func testAssignmentDecodesAllowedExtensions() throws {
        let json = """
        {"id":1,"name":"Essay","points_possible":100,"assignment_group_id":9,
         "submission_types":["online_upload"],"allowed_extensions":["pdf","docx"]}
        """.data(using: .utf8)!
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        let a = try d.decode(Assignment.self, from: json)
        XCTAssertEqual(a.allowedExtensions, ["pdf", "docx"])
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter SubmissionRequestTests`
Expected: FAIL (`SubmissionType` / `SubmissionValidator` undefined; `allowedExtensions` missing).

- [ ] **Step 3: Add `allowedExtensions` to `Assignment`**

In `Sources/CanvasCore/Models.swift`, add `case allowedExtensions` to `Assignment.CodingKeys`, add the stored property, and thread it through `init`:

```swift
// in CodingKeys, after submissionTypes:
case submissionTypes, unlockAt, lockAt, allowedExtensions
// after `public let submissionTypes: [String]?`:
public let allowedExtensions: [String]?
// init: add parameter `allowedExtensions: [String]? = nil,` (place after submissionTypes)
// and `self.allowedExtensions = allowedExtensions`
```

- [ ] **Step 4: Create `SubmissionRequest.swift` with the enum + validator**

```swift
// Sources/CanvasCore/SubmissionRequest.swift
import Foundation

public enum SubmissionType: String, Sendable, CaseIterable {
    case onlineUpload = "online_upload"
    case onlineText   = "online_text_entry"
    case onlineURL    = "online_url"

    /// The app-supported subset of an assignment's raw `submission_types`, in display order.
    public static func supported(from raw: [String]?) -> [SubmissionType] {
        guard let raw else { return [] }
        let set = Set(raw)
        return [.onlineUpload, .onlineText, .onlineURL].filter { set.contains($0.rawValue) }
    }
}

public enum SubmissionValidator {
    /// `allowed` nil/empty ⇒ any file accepted. Otherwise the file's extension (sans dot,
    /// case-insensitive) must appear in the list. A file with no extension is rejected when a
    /// non-empty allow-list is present.
    public static func isExtensionAllowed(_ filename: String, allowed: [String]?) -> Bool {
        guard let allowed, !allowed.isEmpty else { return true }
        let ext = (filename as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return false }
        return allowed.map { $0.lowercased() }.contains(ext)
    }
}
```

- [ ] **Step 5: Run and verify pass**

Run: `swift test --filter SubmissionRequestTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CanvasCore/Models.swift Sources/CanvasCore/SubmissionRequest.swift Tests/CanvasCoreTests/SubmissionRequestTests.swift
git commit -m "feat(core): SubmissionType, extension validator, Assignment.allowedExtensions"
```

---

### Task 2: `UploadTicket` & `UploadedFile` decode models

**Files:**
- Modify: `Sources/CanvasCore/SubmissionRequest.swift`
- Test: `Tests/CanvasCoreTests/SubmissionRequestTests.swift` (extend)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `struct UploadTicket: Sendable, Equatable { let uploadURL: String; let uploadParams: [(String, String)] }` — decoded from Canvas step-1 response (`upload_url` + `upload_params` object). Params keep insertion order and are stored as ordered pairs because the multipart POST must send them **before** the file part. Scalar JSON values (string/number/bool) are coerced to their string form; nulls are dropped.
  - `struct UploadedFile: Codable, Sendable, Equatable { let id: Int }` — decoded from the step-3 confirm response.
  - `UploadTicket` conforms to `Decodable` via a custom initializer.

- [ ] **Step 1: Write the failing tests (append to `SubmissionRequestTests`)**

```swift
extension SubmissionRequestTests {
    func testUploadTicketDecodesURLAndParams() throws {
        let json = """
        {"upload_url":"https://uploads.example.com/put",
         "upload_params":{"key":"abc","content_type":"application/pdf","success_action_status":"201"}}
        """.data(using: .utf8)!
        let ticket = try JSONDecoder().decode(UploadTicket.self, from: json)
        XCTAssertEqual(ticket.uploadURL, "https://uploads.example.com/put")
        // stored as ordered (String,String) pairs; assert as a dictionary for order-independence
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: ticket.uploadParams),
                       ["key": "abc", "content_type": "application/pdf", "success_action_status": "201"])
    }

    func testUploadTicketCoercesScalarParamValues() throws {
        let json = """
        {"upload_url":"https://u/x","upload_params":{"max_size":10485760,"flag":true,"skip":null}}
        """.data(using: .utf8)!
        let ticket = try JSONDecoder().decode(UploadTicket.self, from: json)
        let dict = Dictionary(uniqueKeysWithValues: ticket.uploadParams)
        XCTAssertEqual(dict["max_size"], "10485760")
        XCTAssertEqual(dict["flag"], "true")
        XCTAssertNil(dict["skip"]) // null dropped
    }

    func testUploadedFileDecodesId() throws {
        let json = #"{"id":55123,"display_name":"essay.pdf"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(UploadedFile.self, from: json).id, 55123)
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter SubmissionRequestTests`
Expected: FAIL (`UploadTicket` / `UploadedFile` undefined).

- [ ] **Step 3: Implement the models (append to `SubmissionRequest.swift`)**

```swift
public struct UploadedFile: Codable, Sendable, Equatable {
    public let id: Int
}

public struct UploadTicket: Sendable, Equatable, Decodable {
    public let uploadURL: String
    public let uploadParams: [(String, String)]

    public init(uploadURL: String, uploadParams: [(String, String)]) {
        self.uploadURL = uploadURL
        self.uploadParams = uploadParams
    }

    public static func == (l: UploadTicket, r: UploadTicket) -> Bool {
        l.uploadURL == r.uploadURL
            && Dictionary(uniqueKeysWithValues: l.uploadParams) == Dictionary(uniqueKeysWithValues: r.uploadParams)
    }

    private enum CodingKeys: String, CodingKey { case uploadURL = "upload_url", uploadParams = "upload_params" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        uploadURL = try c.decode(String.self, forKey: .uploadURL)
        // upload_params is an object of scalar values; preserve order and coerce scalars to strings.
        let paramsContainer = try c.nestedContainer(keyedBy: DynamicKey.self, forKey: .uploadParams)
        var pairs: [(String, String)] = []
        for key in paramsContainer.allKeys {
            if let s = try? paramsContainer.decode(String.self, forKey: key) { pairs.append((key.stringValue, s)) }
            else if let i = try? paramsContainer.decode(Int.self, forKey: key) { pairs.append((key.stringValue, String(i))) }
            else if let d = try? paramsContainer.decode(Double.self, forKey: key) { pairs.append((key.stringValue, String(d))) }
            else if let b = try? paramsContainer.decode(Bool.self, forKey: key) { pairs.append((key.stringValue, String(b))) }
            // null / unsupported → dropped
        }
        uploadParams = pairs
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String; var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
        init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
    }
}
```

> Note: this decoder does not use `.convertFromSnakeCase`; `CodingKeys` map the snake-case JSON directly, so `UploadTicket` decodes correctly regardless of the caller's decoder strategy.

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter SubmissionRequestTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/SubmissionRequest.swift Tests/CanvasCoreTests/SubmissionRequestTests.swift
git commit -m "feat(core): UploadTicket and UploadedFile decode models"
```

---

### Task 3: `MultipartBody` pure builder

**Files:**
- Modify: `Sources/CanvasCore/SubmissionRequest.swift`
- Test: `Tests/CanvasCoreTests/SubmissionRequestTests.swift` (extend)

**Interfaces:**
- Produces:
  - `enum MultipartBody { static func build(params: [(String, String)], fileField: String, filename: String, contentType: String, fileData: Data, boundary: String) -> Data }` — RFC-2388 multipart. **Every param field is emitted before the file part** (Canvas/S3 requirement), the file part is last, each part is `\r\n`-delimited, and the body ends with the closing `--boundary--`.
  - `static func MultipartBody.contentTypeHeader(boundary: String) -> String` → `"multipart/form-data; boundary=\(boundary)"`.

- [ ] **Step 1: Write the failing tests**

```swift
extension SubmissionRequestTests {
    func testMultipartBodyOrdersParamsBeforeFile() {
        let body = MultipartBody.build(
            params: [("key", "abc"), ("content_type", "text/plain")],
            fileField: "file", filename: "note.txt", contentType: "text/plain",
            fileData: Data("hello".utf8), boundary: "BOUND")
        let text = String(decoding: body, as: UTF8.self)

        // params appear, file part is last and carries the bytes
        XCTAssertTrue(text.contains("name=\"key\"\r\n\r\nabc\r\n"))
        XCTAssertTrue(text.contains("name=\"content_type\"\r\n\r\ntext/plain\r\n"))
        let keyIdx = text.range(of: "name=\"key\"")!.lowerBound
        let fileIdx = text.range(of: "name=\"file\"")!.lowerBound
        XCTAssertLessThan(keyIdx, fileIdx, "params must precede the file part")
        XCTAssertTrue(text.contains("filename=\"note.txt\""))
        XCTAssertTrue(text.contains("Content-Type: text/plain"))
        XCTAssertTrue(text.contains("\r\nhello\r\n"))
        XCTAssertTrue(text.hasSuffix("--BOUND--\r\n"))
    }

    func testContentTypeHeader() {
        XCTAssertEqual(MultipartBody.contentTypeHeader(boundary: "X"),
                       "multipart/form-data; boundary=X")
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter SubmissionRequestTests`
Expected: FAIL (`MultipartBody` undefined).

- [ ] **Step 3: Implement `MultipartBody` (append to `SubmissionRequest.swift`)**

```swift
public enum MultipartBody {
    public static func contentTypeHeader(boundary: String) -> String {
        "multipart/form-data; boundary=\(boundary)"
    }

    public static func build(params: [(String, String)], fileField: String, filename: String,
                             contentType: String, fileData: Data, boundary: String) -> Data {
        var body = Data()
        func append(_ s: String) { body.append(Data(s.utf8)) }

        for (name, value) in params {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(contentType)\r\n\r\n")
        body.append(fileData)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
```

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter SubmissionRequestTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/SubmissionRequest.swift Tests/CanvasCoreTests/SubmissionRequestTests.swift
git commit -m "feat(core): RFC-2388 MultipartBody pure builder"
```

---

### Task 4: `APIClient` upload / submit / verify methods

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`
- Test: `Tests/CanvasCoreTests/SubmissionAPITests.swift`

**Interfaces:**
- Consumes: `UploadTicket`, `UploadedFile`, `SubmissionType`, `MultipartBody`, `sendForm` (existing, L203), `decoder()` (existing, L111), `Submission` (existing).
- Produces (all `public` on `APIClient`):
  - `func requestUploadSlot(courseId: Int, assignmentId: Int, name: String, size: Int, contentType: String) async throws -> UploadTicket`
  - `func uploadFileBytes(ticket: UploadTicket, filename: String, contentType: String, fileData: Data) async throws -> Int` — POSTs the multipart body to `ticket.uploadURL`, follows the redirect (URLSession default), decodes `UploadedFile`, returns its `id`.
  - `func submitAssignment(courseId: Int, assignmentId: Int, type: SubmissionType, text: String?, url: String?, fileIds: [Int]) async throws -> Submission`
  - `func submissionSelf(courseId: Int, assignmentId: Int) async throws -> Submission`

> Testing note: URLProtocol stubs cannot observe streamed request bodies, so these tests assert **response decoding and return values** through `PaginationStub` (keyed by URL). Request-body shaping is already covered by Task 3's pure tests. `requestUploadSlot`/`submissionSelf` are GET/POST-with-decodable-response, straightforward to stub; `uploadFileBytes` is exercised end-to-end in DEMO mode (Task 5 + Task 14).

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/CanvasCoreTests/SubmissionAPITests.swift
import XCTest
@testable import CanvasCore

final class SubmissionAPITests: XCTestCase {
    var session: URLSession!
    var client: APIClient!

    override func setUp() {
        super.setUp()
        PaginationStub.pages = [:]
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PaginationStub.self]
        session = URLSession(configuration: config)
        client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "test-token"), session: session)
    }

    func testRequestUploadSlotDecodesTicket() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/42/assignments/7/submissions/self/files"
        PaginationStub.pages[url] = (
            #"{"upload_url":"https://up/x","upload_params":{"key":"k1"}}"#.data(using: .utf8)!, nil)
        let ticket = try await client.requestUploadSlot(courseId: 42, assignmentId: 7,
                                                        name: "essay.pdf", size: 1024, contentType: "application/pdf")
        XCTAssertEqual(ticket.uploadURL, "https://up/x")
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: ticket.uploadParams), ["key": "k1"])
    }

    func testSubmissionSelfDecodes() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/42/assignments/7/submissions/self"
        PaginationStub.pages[url] = (
            #"{"id":9,"user_id":1,"assignment_id":7,"workflow_state":"submitted","attempt":2,"submitted_at":"2026-09-03T10:00:00Z"}"#
                .data(using: .utf8)!, nil)
        let sub = try await client.submissionSelf(courseId: 42, assignmentId: 7)
        XCTAssertEqual(sub.attempt, 2)
        XCTAssertEqual(sub.workflowState, "submitted")
    }

    func testSubmitAssignmentDecodesReturnedSubmission() async throws {
        let url = "https://byuh.instructure.com/api/v1/courses/42/assignments/7/submissions"
        PaginationStub.pages[url] = (
            #"{"id":9,"user_id":1,"assignment_id":7,"workflow_state":"submitted","attempt":1}"#.data(using: .utf8)!, nil)
        let sub = try await client.submitAssignment(courseId: 42, assignmentId: 7,
                                                    type: .onlineText, text: "hi", url: nil, fileIds: [])
        XCTAssertEqual(sub.id, 9)
        XCTAssertEqual(sub.workflowState, "submitted")
    }
}
```

> `PaginationStub` responds to any method (its `canInit` returns `true`) and ignores the request body, so a POST whose response is the stubbed JSON decodes fine.

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter SubmissionAPITests`
Expected: FAIL (methods undefined).

- [ ] **Step 3: Implement the methods**

Add to `APIClient` (after the Conversations section, before `sendForm`'s section or alongside the other `public func`s). Note `requestUploadSlot` uses the existing `sendForm` then decodes with a plain decoder (its `CodingKeys` handle snake-case):

```swift
    // MARK: - Submission

    public func requestUploadSlot(courseId: Int, assignmentId: Int,
                                  name: String, size: Int, contentType: String) async throws -> UploadTicket {
        #if DEBUG
        if token == "DEMO" { return MockData.demoUploadSlot(name: name, contentType: contentType) }
        #endif
        let data = try await sendForm(
            path: "/courses/\(courseId)/assignments/\(assignmentId)/submissions/self/files",
            method: "POST",
            fields: [("name", name), ("size", String(size)), ("content_type", contentType)])
        return try JSONDecoder().decode(UploadTicket.self, from: data)
    }

    public func uploadFileBytes(ticket: UploadTicket, filename: String,
                                contentType: String, fileData: Data) async throws -> Int {
        #if DEBUG
        if token == "DEMO" { return MockData.demoUploadedFileId() }
        #endif
        guard let url = URL(string: ticket.uploadURL) else { throw APIError.network("bad upload URL") }
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(MultipartBody.contentTypeHeader(boundary: boundary), forHTTPHeaderField: "Content-Type")
        // The upload endpoint is pre-authorized by upload_params; do NOT send the Canvas bearer token here.
        let body = MultipartBody.build(params: ticket.uploadParams, fileField: "file",
                                       filename: filename, contentType: contentType,
                                       fileData: fileData, boundary: boundary)
        do {
            // URLSession follows the 3xx to the confirm URL automatically; the final body is the file object.
            let (data, response) = try await session.upload(for: request, from: body)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.http(http.statusCode)
            }
            return try JSONDecoder().decode(UploadedFile.self, from: data).id
        } catch let error as APIError { throw error }
        catch { throw APIError.network(error.localizedDescription) }
    }

    public func submitAssignment(courseId: Int, assignmentId: Int, type: SubmissionType,
                                 text: String?, url: String?, fileIds: [Int]) async throws -> Submission {
        #if DEBUG
        if token == "DEMO" {
            return MockData.demoSubmit(courseId: courseId, assignmentId: assignmentId,
                                       type: type, text: text, url: url, fileIds: fileIds)
        }
        #endif
        var fields: [(String, String)] = [("submission[submission_type]", type.rawValue)]
        switch type {
        case .onlineText:   if let text { fields.append(("submission[body]", text)) }
        case .onlineURL:    if let url { fields.append(("submission[url]", url)) }
        case .onlineUpload: fields.append(contentsOf: fileIds.map { ("submission[file_ids][]", String($0)) })
        }
        let data = try await sendForm(path: "/courses/\(courseId)/assignments/\(assignmentId)/submissions",
                                      method: "POST", fields: fields)
        return try decoder().decode(Submission.self, from: data)
    }

    public func submissionSelf(courseId: Int, assignmentId: Int) async throws -> Submission {
        #if DEBUG
        if token == "DEMO" { return MockData.demoCurrentSubmission(courseId: courseId, assignmentId: assignmentId) }
        #endif
        guard let url = URL(string: baseURL + "/courses/\(courseId)/assignments/\(assignmentId)/submissions/self") else {
            throw APIError.network("bad URL")
        }
        let (data, _) = try await getPage(url: url)
        return try decoder().decode(Submission.self, from: data)
    }
```

> The `MockData.demo…` calls are added in Task 5. Until then this file will not compile in `DEBUG`; that is expected — Task 5 is a prerequisite for the DEMO branches. To keep Task 4's tests green in isolation (they use a real token, not `DEMO`), you may temporarily stub the four `MockData.demo…` calls with `fatalError("added in Task 5")` **only if** compilation blocks the test run; otherwise implement Task 5 immediately after and run both suites together.

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter SubmissionAPITests`
Expected: PASS. (If DEBUG compilation blocks on missing `MockData.demo…`, complete Task 5 first, then run.)

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/APIClient.swift Tests/CanvasCoreTests/SubmissionAPITests.swift
git commit -m "feat(core): APIClient upload slot, multipart upload, submit, and verify fetch"
```

---

### Task 5: Mutable demo submissions + `demoSubmit`

**Files:**
- Modify: `Sources/CanvasCore/MockData.swift`
- Test: `Tests/CanvasCoreTests/MockDataSubmitTests.swift`

**Interfaces:**
- Consumes: `SubmissionType`, `UploadTicket`, existing `MockData.submissions` (currently `let [Int: [Submission]]`, L362), `MockData.studentUserId` (L6), `demoNextId` (L491).
- Produces (all `static` on `MockData`):
  - Change `public static let submissions` → `public static var submissions` (mutable) so demo submits mutate it.
  - `static func demoUploadSlot(name: String, contentType: String) -> UploadTicket`
  - `static func demoUploadedFileId() -> Int`
  - `static func demoCurrentSubmission(courseId: Int, assignmentId: Int) -> Submission`
  - `static func demoSubmit(courseId: Int, assignmentId: Int, type: SubmissionType, text: String?, url: String?, fileIds: [Int]) -> Submission` — increments `attempt`, sets `workflowState = "submitted"`, `submittedAt = now`, upserts into `submissions[courseId]`, returns the new `Submission`.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/CanvasCoreTests/MockDataSubmitTests.swift
import XCTest
@testable import CanvasCore

final class MockDataSubmitTests: XCTestCase {
    // MockData.submissions is process-global mutable state; capture and restore around each test.
    var saved: [Int: [Submission]] = [:]
    override func setUp() { super.setUp(); saved = MockData.submissions }
    override func tearDown() { MockData.submissions = saved; super.tearDown() }

    func testDemoSubmitIncrementsAttemptAndMarksSubmitted() {
        // Pick a real demo assignment id from the CS course (hwId = 1001, csCourseId = 99999).
        let before = MockData.submissions[99999]?.first { $0.assignmentId == 1001 }?.attempt ?? 0
        let sub = MockData.demoSubmit(courseId: 99999, assignmentId: 1001,
                                      type: .onlineText, text: "my answer", url: nil, fileIds: [])
        XCTAssertEqual(sub.workflowState, "submitted")
        XCTAssertEqual(sub.attempt, before + 1)
        XCTAssertNotNil(sub.submittedAt)
        // and the store now reflects it
        let stored = MockData.submissions[99999]?.first { $0.assignmentId == 1001 }
        XCTAssertEqual(stored?.attempt, before + 1)
    }

    func testDemoCurrentSubmissionReflectsLatestSubmit() {
        _ = MockData.demoSubmit(courseId: 99999, assignmentId: 1001, type: .onlineURL,
                                text: nil, url: "https://example.com", fileIds: [])
        let current = MockData.demoCurrentSubmission(courseId: 99999, assignmentId: 1001)
        XCTAssertEqual(current.workflowState, "submitted")
    }

    func testDemoUploadSlotAndFileId() {
        let ticket = MockData.demoUploadSlot(name: "a.pdf", contentType: "application/pdf")
        XCTAssertFalse(ticket.uploadURL.isEmpty)
        XCTAssertTrue(MockData.demoUploadedFileId() > 0)
    }
}
```

> Confirm `hwId`/`csCourseId` values against `MockData.swift` (L11, L44) before finalizing the test; if the CS homework isn't `online_text_entry`-eligible in the mock, pick any assignment id present in `submissions[99999]`.

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter MockDataSubmitTests`
Expected: FAIL.

- [ ] **Step 3: Make `submissions` mutable and add the demo helpers**

Change `public static let submissions:` to `public static var submissions:` (L362). Then append near the other `demo…` helpers (after `demoMarkRead`, ~L521):

```swift
    private static var demoFileId = 60000

    public static func demoUploadSlot(name: String, contentType: String) -> UploadTicket {
        UploadTicket(uploadURL: "https://demo.instructure.local/files/upload",
                     uploadParams: [("filename", name), ("content_type", contentType)])
    }

    public static func demoUploadedFileId() -> Int {
        demoFileId += 1
        return demoFileId
    }

    public static func demoCurrentSubmission(courseId: Int, assignmentId: Int) -> Submission {
        if let existing = submissions[courseId]?.first(where: { $0.assignmentId == assignmentId }) {
            return existing
        }
        return Submission(id: demoNextId, userId: studentUserId, assignmentId: assignmentId,
                          score: nil, workflowState: "unsubmitted", gradedAt: nil, submittedAt: nil,
                          submissionComments: nil, attempt: nil)
    }

    public static func demoSubmit(courseId: Int, assignmentId: Int, type: SubmissionType,
                                  text: String?, url: String?, fileIds: [Int]) -> Submission {
        let prior = submissions[courseId]?.first { $0.assignmentId == assignmentId }
        let nextAttempt = (prior?.attempt ?? 0) + 1
        let iso = ISO8601DateFormatter().string(from: Date())
        let updated = Submission(
            id: prior?.id ?? { demoNextId += 1; return demoNextId }(),
            userId: studentUserId, assignmentId: assignmentId,
            score: prior?.score, workflowState: "submitted",
            gradedAt: prior?.gradedAt, submittedAt: iso,
            submissionComments: prior?.submissionComments,
            late: false, missing: false, excused: false, attempt: nextAttempt)
        var list = submissions[courseId] ?? []
        if let idx = list.firstIndex(where: { $0.assignmentId == assignmentId }) { list[idx] = updated }
        else { list.append(updated) }
        submissions[courseId] = list
        return updated
    }
```

> `demoNextId` is `private static var demoNextId = 7000` (L491). The inline closure bumps it only when creating a brand-new submission; reuse the existing id otherwise so the cache upsert stays stable.

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter MockDataSubmitTests`
Then re-run: `swift test --filter SubmissionAPITests` (DEBUG branches now compile).
Expected: PASS for both.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/MockData.swift Tests/CanvasCoreTests/MockDataSubmitTests.swift
git commit -m "feat(core): mutable demo submissions with demoSubmit/upload helpers"
```

---

# GROUP B — DATA PERSISTENCE & ORCHESTRATION (`CanvasData`)

### Task 6: `CachedSubmissionDraft` model + schema

**Files:**
- Create: `Sources/CanvasData/Models/SubmissionDraftModels.swift`
- Modify: `Sources/CanvasData/CanvasStore.swift` (schema, L5-14)
- Test: `Tests/CanvasDataTests/SubmissionDraftTests.swift` (creation asserted here; round-trip in Task 7)

**Interfaces:**
- Produces:
  - `@Model final class CachedSubmissionDraft` with `@Attribute(.unique) var assignmentId: Int`, `var courseId: Int`, `var submissionTypeRaw: String`, `var text: String?`, `var url: String?`, `var updatedAt: Date`.
  - Added to `CanvasStore.schema`.

- [ ] **Step 1: Create the model**

```swift
// Sources/CanvasData/Models/SubmissionDraftModels.swift
import Foundation
import SwiftData

/// A locally-persisted, unsent submission draft for one assignment. Text/URL only — file
/// selections are session-only (spec §7 draft scope decision). Keyed uniquely by assignmentId:
/// a student has at most one in-progress draft per assignment.
@Model
public final class CachedSubmissionDraft {
    @Attribute(.unique) public var assignmentId: Int
    public var courseId: Int
    public var submissionTypeRaw: String
    public var text: String?
    public var url: String?
    public var updatedAt: Date

    public init(assignmentId: Int, courseId: Int, submissionTypeRaw: String,
                text: String? = nil, url: String? = nil, updatedAt: Date = Date()) {
        self.assignmentId = assignmentId
        self.courseId = courseId
        self.submissionTypeRaw = submissionTypeRaw
        self.text = text
        self.url = url
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 2: Add to schema**

In `Sources/CanvasData/CanvasStore.swift`, add `CachedSubmissionDraft.self,` to the `Schema([...])` array (e.g. on the line with `CachedSubmission.self`).

- [ ] **Step 3: Write a smoke test that the model is in the container schema**

```swift
// Tests/CanvasDataTests/SubmissionDraftTests.swift
import XCTest
import SwiftData
@testable import CanvasData
@testable import CanvasCore

final class SubmissionDraftTests: XCTestCase {
    func testDraftModelInsertsAndFetches() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = ModelContext(container)
        ctx.insert(CachedSubmissionDraft(assignmentId: 7, courseId: 42,
                                         submissionTypeRaw: "online_text_entry", text: "wip"))
        try ctx.save()
        let all = try ctx.fetch(FetchDescriptor<CachedSubmissionDraft>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.text, "wip")
    }
}
```

> Confirm the in-memory container factory signature against `CanvasStore` (the plan for Phase 4 used `CanvasStore.container(inMemory: true)`); match whatever the codebase actually exposes.

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter SubmissionDraftTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/Models/SubmissionDraftModels.swift Sources/CanvasData/CanvasStore.swift Tests/CanvasDataTests/SubmissionDraftTests.swift
git commit -m "feat(data): CachedSubmissionDraft model + schema registration"
```

---

### Task 7: Repository draft + submission reads

**Files:**
- Modify: `Sources/CanvasData/CanvasRepository.swift`
- Test: `Tests/CanvasDataTests/SubmissionDraftTests.swift` (extend)

**Interfaces:**
- Consumes: `CachedSubmissionDraft`, `CachedSubmission`, the repository's existing `modelContainer`/context accessor (follow the pattern of an existing read like `submission`/`unseenChanges`).
- Produces (on `CanvasRepository`):
  - `func submissionDraft(assignmentId: Int) throws -> CachedSubmissionDraft?`
  - `func submission(assignmentId: Int) throws -> CachedSubmission?` — the student's cached submission for one assignment (if not already present; check first — a similar accessor may exist).

- [ ] **Step 1: Write the failing tests (extend `SubmissionDraftTests`)**

```swift
extension SubmissionDraftTests {
    func testRepositoryReadsDraft() throws {
        let container = try CanvasStore.container(inMemory: true)
        let ctx = ModelContext(container)
        ctx.insert(CachedSubmissionDraft(assignmentId: 7, courseId: 42,
                                         submissionTypeRaw: "online_url", url: "https://x"))
        try ctx.save()
        let repo = CanvasRepository(modelContainer: container)
        let draft = try repo.submissionDraft(assignmentId: 7)
        XCTAssertEqual(draft?.url, "https://x")
        XCTAssertNil(try repo.submissionDraft(assignmentId: 999))
    }
}
```

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter SubmissionDraftTests`
Expected: FAIL (`submissionDraft` undefined).

- [ ] **Step 3: Implement the reads**

Add to `CanvasRepository` (mirror an existing single-fetch method for the exact context/fetch idiom used in this file):

```swift
    public func submissionDraft(assignmentId: Int) throws -> CachedSubmissionDraft? {
        try context.fetch(FetchDescriptor<CachedSubmissionDraft>(
            predicate: #Predicate { $0.assignmentId == assignmentId })).first
    }

    public func submission(assignmentId: Int) throws -> CachedSubmission? {
        try context.fetch(FetchDescriptor<CachedSubmission>(
            predicate: #Predicate { $0.assignmentId == assignmentId })).first
    }
```

> Replace `context` with whatever the repository actually names its `ModelContext` (check the top of `CanvasRepository.swift`). If a `submission(assignmentId:)` accessor already exists, keep the existing one and add only `submissionDraft`.

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter SubmissionDraftTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/CanvasRepository.swift Tests/CanvasDataTests/SubmissionDraftTests.swift
git commit -m "feat(data): repository reads for submission draft and cached submission"
```

---

### Task 8: `SyncEngine.submit` orchestration + draft writes

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift` (Writes section, ~L907)
- Test: `Tests/CanvasDataTests/SubmitOrchestrationTests.swift`

**Interfaces:**
- Consumes: `client` (`APIClient?`), `upsertSubmissions([Submission], courseId:)` (existing, L461), `modelContext`, `SyncError.noClient`, the new `APIClient` methods, `SubmissionType`.
- Produces (on `SyncEngine`):
  - `public struct SubmissionFile: Sendable { public let filename: String; public let contentType: String; public let data: Data; public init(...) }`
  - `public func submit(courseId: Int, assignmentId: Int, type: SubmissionType, text: String?, url: String?, files: [SubmissionFile]) async throws -> Submission` — for `.onlineUpload`, loops files through `requestUploadSlot` → `uploadFileBytes` collecting ids; then `submitAssignment`; then **verify** via `submissionSelf`; upserts the verified submission; deletes any draft for this assignment; returns the verified `Submission`.
  - `public func saveDraft(assignmentId: Int, courseId: Int, type: SubmissionType, text: String?, url: String?) async throws`
  - `public func deleteDraft(assignmentId: Int) async throws`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/CanvasDataTests/SubmitOrchestrationTests.swift
import XCTest
import SwiftData
@testable import CanvasData
@testable import CanvasCore

final class SubmitOrchestrationTests: XCTestCase {
    var savedSubs: [Int: [Submission]] = [:]
    override func setUp() { super.setUp(); savedSubs = MockData.submissions }
    override func tearDown() { MockData.submissions = savedSubs; super.tearDown() }

    private func makeEngine() async throws -> SyncEngine {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        return engine
    }

    func testSubmitTextVerifiesAndUpsertsSubmission() async throws {
        let engine = try await makeEngine()
        let before = MockData.submissions[99999]?.first { $0.assignmentId == 1001 }?.attempt ?? 0
        let verified = try await engine.submit(courseId: 99999, assignmentId: 1001,
                                               type: .onlineText, text: "answer", url: nil, files: [])
        XCTAssertEqual(verified.workflowState, "submitted")
        XCTAssertEqual(verified.attempt, before + 1)
    }

    func testSubmitClearsDraft() async throws {
        let engine = try await makeEngine()
        try await engine.saveDraft(assignmentId: 1001, courseId: 99999,
                                   type: .onlineText, text: "draft", url: nil)
        _ = try await engine.submit(courseId: 99999, assignmentId: 1001,
                                    type: .onlineText, text: "final", url: nil, files: [])
        let ctx = ModelContext(try CanvasStore.container(inMemory: true))
        _ = ctx // draft lives in the engine's own container; assert via a repository on the same container instead
    }

    func testSaveDraftIsIdempotentPerAssignment() async throws {
        let engine = try await makeEngine()
        try await engine.saveDraft(assignmentId: 1001, courseId: 99999, type: .onlineText, text: "a", url: nil)
        try await engine.saveDraft(assignmentId: 1001, courseId: 99999, type: .onlineText, text: "b", url: nil)
        let count = try await engine.draftCountForTest(assignmentId: 1001)
        XCTAssertEqual(count, 1)   // upsert, not duplicate
    }
}
```

> The container-per-engine boundary makes cross-context assertions awkward. Add a tiny `#if DEBUG`-gated test accessor on `SyncEngine` — `func draftCountForTest(assignmentId: Int) throws -> Int` — that fetches from the engine's own context. Keep the two clean assertions (verify/upsert; save idempotency); drop `testSubmitClearsDraft`'s cross-container check or fold it into the same-context accessor (`draftCountForTest` should return 0 after submit).

- [ ] **Step 2: Run and verify failure**

Run: `swift test --filter SubmitOrchestrationTests`
Expected: FAIL.

- [ ] **Step 3: Implement `submit`, `saveDraft`, `deleteDraft` (in the `// MARK: - Writes` section)**

```swift
    public struct SubmissionFile: Sendable {
        public let filename: String
        public let contentType: String
        public let data: Data
        public init(filename: String, contentType: String, data: Data) {
            self.filename = filename; self.contentType = contentType; self.data = data
        }
    }

    public func submit(courseId: Int, assignmentId: Int, type: SubmissionType,
                       text: String?, url: String?, files: [SubmissionFile]) async throws -> Submission {
        guard let client else { throw SyncError.noClient }

        var fileIds: [Int] = []
        if type == .onlineUpload {
            for file in files {
                let ticket = try await client.requestUploadSlot(
                    courseId: courseId, assignmentId: assignmentId,
                    name: file.filename, size: file.data.count, contentType: file.contentType)
                let id = try await client.uploadFileBytes(ticket: ticket, filename: file.filename,
                                                          contentType: file.contentType, fileData: file.data)
                fileIds.append(id)
            }
        }

        // POST the submission, then VERIFY with a fresh fetch — success is only reported after this.
        _ = try await client.submitAssignment(courseId: courseId, assignmentId: assignmentId,
                                              type: type, text: text, url: url, fileIds: fileIds)
        let verified = try await client.submissionSelf(courseId: courseId, assignmentId: assignmentId)

        upsertSubmissions([verified], courseId: courseId)
        deleteDraftRow(assignmentId: assignmentId)   // success ⇒ clear the preserved draft
        try modelContext.save()
        return verified
    }

    public func saveDraft(assignmentId: Int, courseId: Int, type: SubmissionType,
                          text: String?, url: String?) async throws {
        if let row = fetchDraftRow(assignmentId: assignmentId) {
            row.submissionTypeRaw = type.rawValue; row.text = text; row.url = url; row.updatedAt = Date()
        } else {
            modelContext.insert(CachedSubmissionDraft(assignmentId: assignmentId, courseId: courseId,
                                                      submissionTypeRaw: type.rawValue, text: text, url: url))
        }
        try modelContext.save()
    }

    public func deleteDraft(assignmentId: Int) async throws {
        deleteDraftRow(assignmentId: assignmentId)
        try modelContext.save()
    }

    private func fetchDraftRow(assignmentId: Int) -> CachedSubmissionDraft? {
        (try? modelContext.fetch(FetchDescriptor<CachedSubmissionDraft>(
            predicate: #Predicate { $0.assignmentId == assignmentId })))?.first
    }

    private func deleteDraftRow(assignmentId: Int) {
        if let row = fetchDraftRow(assignmentId: assignmentId) { modelContext.delete(row) }
    }

    #if DEBUG
    public func draftCountForTest(assignmentId: Int) throws -> Int {
        try modelContext.fetch(FetchDescriptor<CachedSubmissionDraft>(
            predicate: #Predicate { $0.assignmentId == assignmentId })).count
    }
    #endif
```

> `submit` does NOT catch errors — any failure propagates to the caller with the draft left intact (the ViewModel autosaves the draft before calling `submit`, so a throw naturally preserves it). Draft deletion happens only on the success path, after verification.

- [ ] **Step 4: Run and verify pass**

Run: `swift test --filter SubmitOrchestrationTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/SyncEngine.swift Tests/CanvasDataTests/SubmitOrchestrationTests.swift
git commit -m "feat(data): SyncEngine submit orchestration with verify + draft persistence"
```

---

# GROUP C — SUBMISSION UI (`CanvasUI`)

### Task 9: `SubmissionEditor` + `SubmissionStatusView`

**Files:**
- Create: `Sources/CanvasUI/SubmissionComponents.swift`

No automated tests (CanvasUI convention). Deliverable compiles and is driven by Task 13's DEMO walk.

**Interfaces:**
- Produces:
  - `public enum SubmissionUIType: String, Sendable { case upload, text, url }` — a UI-local mirror so CanvasUI need not import the picked `SubmissionType` semantics beyond display. (Alternatively re-export `SubmissionType` from CanvasCore, which CanvasUI already imports — prefer that: use `CanvasCore.SubmissionType` directly and delete this enum.)
  - `public struct SubmissionEditor: View` — `init(types: [SubmissionType], selection: Binding<SubmissionType>, text: Binding<String>, url: Binding<String>, files: [SubmissionEditor.PickedFile], allowedExtensions: [String]?, onAddFiles: @escaping () -> Void, onRemoveFile: (UUID) -> Void)`.
    - `public struct PickedFile: Identifiable, Sendable { public let id: UUID; public let filename: String; public let sizeBytes: Int; public var isAllowed: Bool }`
    - Segmented `Picker` over `types` (only when >1); a `TextEditor` for `.onlineText`; a `TextField` for `.onlineURL`; a file list + "Add files…" button for `.onlineUpload`, with disallowed files flagged in `Color.lostMissing`.
  - `public struct SubmissionStatusView: View` — `init(phase: Phase)` where `public enum Phase: Equatable { case idle, uploading(current: Int, total: Int), submitting, verifying, success(attempt: Int, submittedAt: String?), failed(String) }`. Renders a progress row (spinner + "Uploading file 1 of 3…", "Verifying…"), a success seal ("Submitted — attempt N"), or a failure row with the message.

- [ ] **Step 1: Implement the components**

```swift
// Sources/CanvasUI/SubmissionComponents.swift
import SwiftUI
import CanvasCore

public struct SubmissionEditor: View {
    public struct PickedFile: Identifiable, Sendable {
        public let id: UUID
        public let filename: String
        public let sizeBytes: Int
        public var isAllowed: Bool
        public init(id: UUID = UUID(), filename: String, sizeBytes: Int, isAllowed: Bool) {
            self.id = id; self.filename = filename; self.sizeBytes = sizeBytes; self.isAllowed = isAllowed
        }
    }

    let types: [SubmissionType]
    @Binding var selection: SubmissionType
    @Binding var text: String
    @Binding var url: String
    let files: [PickedFile]
    let allowedExtensions: [String]?
    let onAddFiles: () -> Void
    let onRemoveFile: (UUID) -> Void

    public init(types: [SubmissionType], selection: Binding<SubmissionType>,
                text: Binding<String>, url: Binding<String>, files: [PickedFile],
                allowedExtensions: [String]?, onAddFiles: @escaping () -> Void,
                onRemoveFile: @escaping (UUID) -> Void) {
        self.types = types; self._selection = selection; self._text = text; self._url = url
        self.files = files; self.allowedExtensions = allowedExtensions
        self.onAddFiles = onAddFiles; self.onRemoveFile = onRemoveFile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if types.count > 1 {
                Picker("Submission type", selection: $selection) {
                    ForEach(types, id: \.self) { Text(label(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            switch selection {
            case .onlineText:
                TextEditor(text: $text)
                    .frame(minHeight: 120)
                    .font(.system(size: 13))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.canvasHairline))
            case .onlineURL:
                TextField("https://…", text: $url)
                    .textFieldStyle(.roundedBorder)
            case .onlineUpload:
                fileList
            }
            if selection == .onlineUpload, let exts = allowedExtensions, !exts.isEmpty {
                Text("Allowed: \(exts.joined(separator: ", "))")
                    .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(files) { file in
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                    Text(file.filename).font(.system(size: 12.5))
                        .foregroundStyle(file.isAllowed ? Color.inkPrimary : Color.lostMissing)
                    if !file.isAllowed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.lostMissing).font(.system(size: 11))
                    }
                    Spacer()
                    Button { onRemoveFile(file.id) } label: { Image(systemName: "xmark.circle") }
                        .buttonStyle(.plain).foregroundStyle(Color.inkTertiary)
                }
            }
            Button(action: onAddFiles) { Label("Add files…", systemImage: "doc.badge.plus") }
                .buttonStyle(.plain).foregroundStyle(Color.accentHypothetical)
        }
    }

    private func label(for t: SubmissionType) -> String {
        switch t { case .onlineUpload: "File"; case .onlineText: "Text"; case .onlineURL: "URL" }
    }
}

public struct SubmissionStatusView: View {
    public enum Phase: Equatable {
        case idle
        case uploading(current: Int, total: Int)
        case submitting
        case verifying
        case success(attempt: Int, submittedAt: String?)
        case failed(String)
    }
    let phase: Phase
    public init(phase: Phase) { self.phase = phase }

    public var body: some View {
        switch phase {
        case .idle: EmptyView()
        case .uploading(let c, let t): progress("Uploading file \(c) of \(t)…")
        case .submitting: progress("Submitting…")
        case .verifying: progress("Verifying…")
        case .success(let attempt, _):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                Text("Submitted — attempt \(attempt)").font(.system(size: 12.5, weight: .medium))
            }
        case .failed(let msg):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.lostMissing)
                Text(msg).font(.system(size: 12.5)).foregroundStyle(Color.lostMissing)
            }
        }
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 8) { ProgressView().controlSize(.small); Text(text).font(.system(size: 12.5)) }
    }
}
```

> Verify the design-token names (`Color.canvasHairline`, `Color.inkPrimary/Secondary/Tertiary`, `Color.lostMissing`, `Color.accentHypothetical`) exist in `CanvasUI` (they are used throughout `AssignmentsTabView`/`MainWindowView`). Use whatever the token file actually defines.

- [ ] **Step 2: Build to verify it compiles**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/CanvasUI/SubmissionComponents.swift
git commit -m "feat(ui): SubmissionEditor and SubmissionStatusView components"
```

---

### Task 10: `SubmissionConfirmationSheet`

**Files:**
- Modify: `Sources/CanvasUI/SubmissionComponents.swift`

**Interfaces:**
- Produces:
  - `public struct SubmissionConfirmationSheet: View` — `init(assignmentName: String, dueAt: Date?, isLate: Bool, attempt: Int, payloadLines: [String], isDemo: Bool, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void)`. Shows the name, due date, a red "This submission will be late" badge when `isLate`, "Attempt N", the exact payload (`payloadLines` — e.g. `["essay.pdf (2.1 MB)"]` or `["Text: 340 characters"]`), a demo banner when `isDemo`, and Cancel / Submit buttons.

- [ ] **Step 1: Implement the sheet**

```swift
public struct SubmissionConfirmationSheet: View {
    let assignmentName: String
    let dueAt: Date?
    let isLate: Bool
    let attempt: Int
    let payloadLines: [String]
    let isDemo: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    public init(assignmentName: String, dueAt: Date?, isLate: Bool, attempt: Int,
                payloadLines: [String], isDemo: Bool,
                onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.assignmentName = assignmentName; self.dueAt = dueAt; self.isLate = isLate
        self.attempt = attempt; self.payloadLines = payloadLines; self.isDemo = isDemo
        self.onConfirm = onConfirm; self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Submit “\(assignmentName)”?").font(.system(size: 15, weight: .bold))
            if isDemo {
                Text("Demo mode — this submission is simulated.")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(Color.accentHypothetical)
            }
            VStack(alignment: .leading, spacing: 4) {
                if let dueAt {
                    Text("Due \(dueAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 12)).foregroundStyle(Color.inkSecondary)
                }
                if isLate {
                    Label("This submission will be late", systemImage: "clock.badge.exclamationmark")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Color.lostMissing)
                }
                Text("Attempt \(attempt)").font(.system(size: 12)).foregroundStyle(Color.inkSecondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Sending").font(.sectionLabel).foregroundStyle(Color.inkTertiary)
                ForEach(payloadLines, id: \.self) {
                    Text($0).font(.system(size: 12.5)).foregroundStyle(Color.inkPrimary)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Submit", action: onConfirm).keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/CanvasUI/SubmissionComponents.swift
git commit -m "feat(ui): SubmissionConfirmationSheet with late/attempt/payload summary"
```

---

# GROUP D — APP INTEGRATION (`CanvasApp`)

### Task 11: `SubmissionViewModel` state machine

**Files:**
- Create: `CanvasApp/ViewModels/SubmissionViewModel.swift`

**Interfaces:**
- Consumes: `AppSession` (`submit`, `saveSubmissionDraft`, `apiClient`, `repository`), `CanvasCore.SubmissionType`, `SubmissionEditor.PickedFile`, `SubmissionStatusView.Phase`, `SyncEngine.SubmissionFile`.
- Produces: `@MainActor @Observable final class SubmissionViewModel` with published state:
  - `var availableTypes: [SubmissionType]`, `var selection: SubmissionType`, `var text: String`, `var url: String`, `var pickedFiles: [PickedFileEntry]`, `var phase: SubmissionStatusView.Phase`, `var showConfirmation: Bool`.
  - `struct PickedFileEntry { let ui: SubmissionEditor.PickedFile; let data: Data; let contentType: String }`
  - `func load(session:assignment:courseId:)`, `func addFiles(urls: [URL])`, `func removeFile(_ id: UUID)`, `func autosaveDraft(session:courseId:assignmentId:)`, `func confirmSubmit(session:courseId:assignment:)`, `func cancel()` (cancels the in-flight submit Task — satisfies spec §7 "cancellable up to the final POST"), `var isSubmitting: Bool`.
  - `var canSubmit: Bool` (token present + payload non-empty + no disallowed files), `func payloadLines() -> [String]`, `func isLate(dueAt:) -> Bool`, `var attemptNumber: Int`.

- [ ] **Step 1: Implement the view model**

```swift
// CanvasApp/ViewModels/SubmissionViewModel.swift
import Foundation
import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

@MainActor
@Observable
final class SubmissionViewModel {
    var availableTypes: [SubmissionType] = []
    var selection: SubmissionType = .onlineText
    var text: String = ""
    var url: String = ""
    var pickedFiles: [PickedFileEntry] = []
    var phase: SubmissionStatusView.Phase = .idle
    var showConfirmation = false
    var allowedExtensions: [String]?
    private var currentAttempt = 0
    private var submitTask: Task<Void, Never>?

    var isSubmitting: Bool {
        switch phase { case .uploading, .submitting, .verifying: return true; default: return false }
    }

    struct PickedFileEntry: Identifiable {
        var id: UUID { ui.id }
        let ui: SubmissionEditor.PickedFile
        let data: Data
        let contentType: String
    }

    var uiFiles: [SubmissionEditor.PickedFile] { pickedFiles.map(\.ui) }
    var attemptNumber: Int { currentAttempt + 1 }

    func load(session: AppSession, assignment: Assignment, courseId: Int) {
        availableTypes = SubmissionType.supported(from: assignment.submissionTypes)
        selection = availableTypes.first ?? .onlineText
        allowedExtensions = assignment.allowedExtensions
        currentAttempt = (try? session.repository.submission(assignmentId: assignment.id))?.attempt ?? 0
        if let draft = try? session.repository.submissionDraft(assignmentId: assignment.id) {
            text = draft.text ?? ""
            url = draft.url ?? ""
            if let t = SubmissionType(rawValue: draft.submissionTypeRaw), availableTypes.contains(t) { selection = t }
        }
    }

    func addFiles(urls: [URL]) {
        for fileURL in urls {
            let didAccess = fileURL.startAccessingSecurityScopedResource()
            defer { if didAccess { fileURL.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            let name = fileURL.lastPathComponent
            let allowed = SubmissionValidator.isExtensionAllowed(name, allowed: allowedExtensions)
            let ui = SubmissionEditor.PickedFile(filename: name, sizeBytes: data.count, isAllowed: allowed)
            let ctype = contentType(for: fileURL)
            pickedFiles.append(PickedFileEntry(ui: ui, data: data, contentType: ctype))
        }
    }

    func removeFile(_ id: UUID) { pickedFiles.removeAll { $0.id == id } }

    var canSubmit: Bool {
        switch selection {
        case .onlineText:   return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .onlineURL:    return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .onlineUpload: return !pickedFiles.isEmpty && pickedFiles.allSatisfy { $0.ui.isAllowed }
        }
    }

    func payloadLines() -> [String] {
        switch selection {
        case .onlineText:   return ["Text: \(text.count) characters"]
        case .onlineURL:    return [url]
        case .onlineUpload: return pickedFiles.map { "\($0.ui.filename) (\(byteString($0.ui.sizeBytes)))" }
        }
    }

    func isLate(dueAt: Date?) -> Bool { dueAt.map { Date() > $0 } ?? false }

    func autosaveDraft(session: AppSession, courseId: Int, assignmentId: Int) async {
        // Only text/URL persist (spec §7 decision). Skip pure-file drafts.
        guard selection != .onlineUpload else { return }
        await session.saveSubmissionDraft(assignmentId: assignmentId, courseId: courseId,
                                          type: selection, text: text, url: url)
    }

    func confirmSubmit(session: AppSession, courseId: Int, assignment: Assignment) async {
        showConfirmation = false
        let files = pickedFiles.map {
            SyncEngine.SubmissionFile(filename: $0.ui.filename, contentType: $0.contentType, data: $0.data)
        }
        phase = selection == .onlineUpload ? .uploading(current: 1, total: max(files.count, 1)) : .submitting

        // Run inside a cancellable Task so the user can back out during uploads (before the final POST).
        let sel = selection, t = text, u = url
        submitTask = Task { [weak self] in
            let result = await session.submit(courseId: courseId, assignmentId: assignment.id,
                                              type: sel, text: t, url: u, files: files)
            guard let self, !Task.isCancelled else { return }
            switch result {
            case .success(let sub):
                self.phase = .success(attempt: sub.attempt ?? self.attemptNumber, submittedAt: sub.submittedAt)
            case .failure(let message):
                self.phase = .failed(message)   // draft already persisted via autosave; retry stays available
            }
        }
        await submitTask?.value
    }

    /// Cancels an in-flight submit. The engine's per-file upload uses URLSession, which throws on
    /// cancellation before the submission POST — so a cancel here leaves the assignment unsubmitted
    /// with the draft intact. No effect once verification has returned success.
    func cancel() {
        guard isSubmitting else { return }
        submitTask?.cancel()
        phase = .idle
    }

    private func byteString(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func contentType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension),
           let mime = type.preferredMIMEType { return mime }
        return "application/octet-stream"
    }
}
```

> Add `import UniformTypeIdentifiers` for `UTType`. `AppSession.submit` returns `Result<Submission, String>` (Task 12). Per-byte upload progress is out of scope; the phase advances coarsely (`.uploading` → `.submitting`/`.verifying` handled by the engine call, shown as a spinner). If finer progress is wanted later, thread a progress closure through `SyncEngine.submit`/`APIClient.uploadFileBytes`.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean (after Task 12 adds `AppSession.submit`; if building this task alone, expect the missing-method error and complete Task 12 next).

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/ViewModels/SubmissionViewModel.swift
git commit -m "feat(app): SubmissionViewModel upload/submit/verify state machine"
```

---

### Task 12: `AppSession` submit + draft wrappers

**Files:**
- Modify: `CanvasApp/App/AppSession.swift`

**Interfaces:**
- Consumes: `syncEngine.submit`, `syncEngine.saveDraft`, `SubmissionType`, `SyncEngine.SubmissionFile`, `Submission`.
- Produces (on `AppSession`, matching the existing thin-wrapper style, e.g. `compose` L134):
  - `func submit(courseId: Int, assignmentId: Int, type: SubmissionType, text: String?, url: String?, files: [SyncEngine.SubmissionFile]) async -> Result<Submission, String>`
  - `func saveSubmissionDraft(assignmentId: Int, courseId: Int, type: SubmissionType, text: String?, url: String?) async`

- [ ] **Step 1: Implement the wrappers**

```swift
    func submit(courseId: Int, assignmentId: Int, type: SubmissionType,
                text: String?, url: String?, files: [SyncEngine.SubmissionFile]) async -> Result<Submission, String> {
        do {
            let verified = try await syncEngine.submit(courseId: courseId, assignmentId: assignmentId,
                                                       type: type, text: text, url: url, files: files)
            return .success(verified)
        } catch {
            return .failure(String(describing: error))
        }
    }

    func saveSubmissionDraft(assignmentId: Int, courseId: Int, type: SubmissionType,
                             text: String?, url: String?) async {
        try? await syncEngine.saveDraft(assignmentId: assignmentId, courseId: courseId,
                                        type: type, text: text, url: url)
    }
```

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/App/AppSession.swift
git commit -m "feat(app): AppSession submit and saveSubmissionDraft wrappers"
```

---

### Task 13: Wire the "Submission" section into `AssignmentsTabView`

**Files:**
- Modify: `CanvasApp/Views/Window/AssignmentsTabView.swift` (`detailColumn`, L93-116)

**Interfaces:**
- Consumes: `SubmissionViewModel`, `SubmissionEditor`, `SubmissionConfirmationSheet`, `SubmissionStatusView`, `SubmissionType.supported`, `AppSession`, `Router`.
- Produces: a `submissionSection(_ row:)` view inserted into the detail `VStack` (after `metadataBlock`, before or after the description). Supported types → inline editor + Submit button + status; unsupported-only → "Submit in Canvas" link.

- [ ] **Step 1: Add state + the section, and a `.fileImporter`**

At the top of `AssignmentsTabView` (near `@Environment`), add:

```swift
    @State private var submissionVM = SubmissionViewModel()
    @State private var showFileImporter = false
    @Environment(AppSession.self) private var session   // if not already present
```

In `detailColumn`, insert `submissionSection(row)` into the `VStack` (e.g. right after `metadataBlock(row)`), and attach the sheet + importer to the `ScrollView`:

```swift
    @ViewBuilder
    private func submissionSection(_ row: AssignmentsViewModel.Row) -> some View {
        let supported = SubmissionType.supported(from: row.assignment.submissionTypes)
        VStack(alignment: .leading, spacing: 10) {
            Text("Submission").font(.sectionLabel).foregroundStyle(Color.inkSecondary)
            if supported.isEmpty {
                // Unsupported type (quiz, external tool, on-paper) — link out.
                if let html = row.assignment.htmlURL, let url = URL(string: html) {
                    Link(destination: url) { Label("Submit in Canvas", systemImage: "arrow.up.forward.square") }
                } else {
                    Text("This assignment can't be submitted here.")
                        .font(.system(size: 12)).foregroundStyle(Color.inkTertiary)
                }
            } else {
                SubmissionEditor(
                    types: supported,
                    selection: Binding(get: { submissionVM.selection }, set: { submissionVM.selection = $0 }),
                    text: Binding(get: { submissionVM.text }, set: { submissionVM.text = $0 }),
                    url: Binding(get: { submissionVM.url }, set: { submissionVM.url = $0 }),
                    files: submissionVM.uiFiles,
                    allowedExtensions: submissionVM.allowedExtensions,
                    onAddFiles: { showFileImporter = true },
                    onRemoveFile: { submissionVM.removeFile($0) })

                SubmissionStatusView(phase: submissionVM.phase)

                HStack(spacing: 10) {
                    Button("Submit") { submissionVM.showConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!submissionVM.canSubmit || session.apiClient == nil || submissionVM.isSubmitting)
                    if submissionVM.isSubmitting {
                        // Spec §7: the flow is cancellable up to the final POST.
                        Button("Cancel") { submissionVM.cancel() }
                    }
                    if session.apiClient == nil {
                        Text("Sign in to submit").font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                    }
                    // Failure escape hatch (spec §7): always offer "Open in Canvas" after a failed submit.
                    if case .failed = submissionVM.phase, let html = row.assignment.htmlURL, let url = URL(string: html) {
                        Link("Open in Canvas", destination: url).font(.system(size: 12))
                    }
                }
            }
        }
        .task(id: row.assignment.id) {
            submissionVM.load(session: session, assignment: row.assignment, courseId: courseId)
        }
        // Autosave text/URL drafts as the user types.
        .onChange(of: submissionVM.text) { _, _ in autosave(row) }
        .onChange(of: submissionVM.url) { _, _ in autosave(row) }
        .sheet(isPresented: Binding(get: { submissionVM.showConfirmation },
                                    set: { submissionVM.showConfirmation = $0 })) {
            SubmissionConfirmationSheet(
                assignmentName: row.assignment.name,
                dueAt: row.assignment.dueAt.flatMap(ISO8601DateFormatter().date),
                isLate: submissionVM.isLate(dueAt: row.assignment.dueAt.flatMap(ISO8601DateFormatter().date)),
                attempt: submissionVM.attemptNumber,
                payloadLines: submissionVM.payloadLines(),
                isDemo: session.isDemo,
                onConfirm: { Task { await submissionVM.confirmSubmit(session: session, courseId: courseId, assignment: row.assignment) } },
                onCancel: { submissionVM.showConfirmation = false })
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { submissionVM.addFiles(urls: urls) }
        }
    }

    private func autosave(_ row: AssignmentsViewModel.Row) {
        Task { await submissionVM.autosaveDraft(session: session, courseId: courseId, assignmentId: row.assignment.id) }
    }
```

> Check three things against the codebase: (1) how `row.assignment.dueAt` (a `String?`) is parsed to `Date` elsewhere in this file — reuse that helper instead of a fresh `ISO8601DateFormatter` if one exists (the metadata block already renders dates, so a parser is nearby). (2) whether `AppSession` exposes `isDemo` — if not, add `var isDemo: Bool { credentials?.token == "DEMO" }`. (3) that `courseId` is in scope in `AssignmentsTabView` (it is — used by sibling `.id(courseId)` calls).

- [ ] **Step 2: Build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add CanvasApp/Views/Window/AssignmentsTabView.swift
git commit -m "feat(app): inline Submission section in assignment detail with confirm + file import"
```

---

# GROUP E — VERIFICATION

### Task 14: Full per-suite tests + DEMO walk

- [ ] **Step 1: Run each new/affected suite (never a bare `swift test` — it hangs)**

```bash
swift test --filter SubmissionRequestTests
swift test --filter SubmissionAPITests
swift test --filter MockDataSubmitTests
swift test --filter SubmissionDraftTests
swift test --filter SubmitOrchestrationTests
```
Expected: all PASS.

- [ ] **Step 2: Confirm the pre-existing Core suite still passes (no regressions from the `Assignment`/`MockData` changes)**

```bash
swift test --filter ModelsTests
swift test --filter APIClientPaginationTests
```
Expected: PASS.

- [ ] **Step 3: DEMO walk (manual)**

Launch the app target with `CANVAS_TOKEN=DEMO`. In a course workspace → **Assignments** → pick an assignment:
- **Text**: type an answer → Submit → confirmation sheet shows attempt #, payload "Text: N characters", demo banner → Submit → status shows "Submitted — attempt N". Re-open: the graded/submitted state reflects it.
- **URL**: switch the segmented control to URL → enter a URL → Submit → verify.
- **File**: switch to File → "Add files…" → pick a file → confirm the size shows, a disallowed extension is flagged red and blocks Submit → pick an allowed file → Submit → verify.
- **Draft**: type text, navigate away to another assignment and back → text is restored. Submit → draft cleared (navigating back shows an empty editor).
- **Unsupported**: pick a quiz/on-paper assignment → only "Submit in Canvas" link shows.
- **Token-less**: (if reachable) confirm Submit is disabled with "Sign in to submit".

- [ ] **Step 4: Update PROJECT-STATUS.md**

Mark Phase 5 ✅ landed in the phase table and remove it from "Next up". Commit:

```bash
git add docs/superpowers/PROJECT-STATUS.md docs/superpowers/plans/2026-09-03-phase5-submission.md
git commit -m "docs: mark Phase 5 (Submission) landed"
```

- [ ] **Step 5: Refresh the knowledge graph (AST-only, per CLAUDE.md)**

```bash
graphify update .
git add graphify-out
git commit -m "chore(graphify): refresh graph after Phase 5 submission"
```

---

## Summary of Deliverables

| Component | Location | Description |
|---|---|---|
| `SubmissionType`, `SubmissionValidator` | `CanvasCore` | Supported-type filter + client-side extension check |
| `UploadTicket`, `UploadedFile`, `MultipartBody` | `CanvasCore` | Pure request-shaping for Canvas's 3-step upload |
| API methods | `CanvasCore` | `requestUploadSlot`, `uploadFileBytes`, `submitAssignment`, `submissionSelf` |
| Demo submit | `CanvasCore` | Mutable `submissions` + `demoSubmit`/`demoUploadSlot` |
| `CachedSubmissionDraft` | `CanvasData` | Text/URL draft persistence (files session-only) |
| `SyncEngine.submit` | `CanvasData` | Upload→submit→**verify** orchestration + draft clear |
| `SubmissionEditor`, `ConfirmationSheet`, `StatusView` | `CanvasUI` | Inline editor, confirmation, progress/result |
| `SubmissionViewModel` | `CanvasApp` | Upload/submit/verify state machine + draft autosave |
| Detail-column wiring | `CanvasApp` | "Submission" section in `AssignmentsTabView` |
