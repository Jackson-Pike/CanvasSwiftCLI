# Phase 2 — Communication (Inbox, Discussions, Notifications) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

The master design spec (`docs/superpowers/specs/2026-08-01-desktop-app-design.md`, §9) defines **Phase 2 — Communication** as: Inbox (list, thread, compose, reply, mark read), Discussions read-only, `NotificationScheduler`, background refresh, and Settings for notification categories and quiet hours. Phase 0 (foundation), Phase 1a (Dashboard + Sandbox), and Phase 1b (Assignments/Announcements/Syllabus/trend chart) are merged into `main` (`0b1d949`).

This is the first phase that **writes** to Canvas (send/reply/mark-read) and the first that runs work **without a user present** (background refresh + notifications). Both are handled defensively: writes are optimistic-with-reconcile against the local store and degrade to demo-local when `token == "DEMO"`; background work is gated on power/display state and never fires notifications the user disabled.

**Current stubs this plan fills:**
- `MainWindowView.swift:80` renders `ComingSoonView(title: "Inbox", phase: "Phase 2")` — replaced by the real Inbox.
- `CourseWorkspaceView.swift:44` falls through to `ComingSoonView` for `.discussions` — replaced by the read-only Discussions tab. (`.modules`/`.files` stay stubs — Phase 4.)
- No `NotificationScheduler`, background refresh, or notification Settings exist yet.

Goal after this plan: the Inbox is a working two-pane mail client (compose/reply/mark-read, demo-walkable); Discussions render threaded read-only; the app posts local notifications for enabled change categories outside quiet hours, refreshing itself on a background timer; and Settings exposes categories, quiet hours, and the refresh interval.

## Architecture

New decode/predicate logic (conversation/discussion decoding, discussion-tree flattening, `.newMessage` detection, notification coalescing, quiet-hours math, background-gate math) lands as **pure, XCTest-covered functions** in `CanvasCore`/`CanvasData`, matching the Phase 1a/1b pattern. New sync/upsert/write logic is covered in `CanvasDataTests` against the existing in-memory `CanvasStore.container(inMemory: true)` + `DEMO` `APIClient` harness (see `AnnouncementSyncTests`). Request shaping for the new POST/PUT calls is covered in `CanvasCoreTests` with a `URLProtocol` stub (see `ProfileTests.FixedResponseStub`).

SwiftUI stays a thin consumer: value-driven `public struct … : View` components in `CanvasUI`, small per-surface `ObservableObject` view-models + composition in `CanvasApp`, following `AnnouncementsViewModel`/`AnnouncementsTabView`'s exact shape (read from store → `session.refresh(scope)` → re-read). `Router`/`AppSession` remain the only `@Observable` types.

**Data flow additions.** `SyncEngine` gains three read scopes (`.inbox`, `.conversation(id)`, `.discussion(courseId:topicId:)`) and three write methods (`markConversationRead`, `sendReply`, `compose`). Detail fetches (a thread's messages, a topic's entries) are **lazy** — issued when the user opens the item — so background ticks stay to one inbox-list request plus the existing `.all` fan-out. `NotificationScheduler` consumes unseen `ChangeRecord`s (produced exactly as today by `ChangeDetector` inside sync) and posts `UNNotificationRequest`s; `BackgroundRefreshController` drives periodic syncs and hands the resulting unseen changes to the scheduler.

**Tech stack additions:** `UserNotifications` (notifications), `Network` (`NWPathMonitor` reachability), `IOKit.ps` (battery state), `AppKit` (`NSWorkspace` sleep/wake). All available at the existing macOS 14 floor — no platform bump. `UserNotifications` and `IOKit`/`Network`/`AppKit` are used only in `CanvasData`'s `NotificationScheduler` and `CanvasApp`'s `BackgroundRefreshController`; the pure planning/gating logic they call is framework-free and lives in testable enums.

## Global Constraints

- **Test framework:** XCTest only, `@testable import`, mirroring Phase 1a/1b exactly. No app/UI test target exists — `CanvasApp`/`CanvasUI` are verified by `swift build` + demo-mode walkthrough. Every testable behavior (decoding, request shaping, tree flattening, change detection, upsert idempotency, notification coalescing, quiet-hours, background gating) goes in `CanvasCore`/`CanvasData`.
- **Demo verifiability:** every new surface must be walkable end-to-end with `CANVAS_TOKEN=DEMO`. `MockData` grows to cover conversations (read + unread + one archived), messages, discussion topics with a nested reply tree, and demo writes (compose/reply/mark-read) succeed **locally** against the mock store and never touch the network. Any write confirmation in demo shows a subtle "Demo" badge (spec §2.7).
- **Writes are optimistic + reconciled (spec §5.2):** a reply inserts a local `pending` `CachedMessage` immediately; the API call runs; on success `SyncEngine` reconciles by re-fetching the thread (real rows replace pending); on failure the pending row is removed, the draft is restored, and an inline error is shown. Writes are disabled offline and without a verified token.
- **`.newMessage` detection — documented deviation from spec §3.1:** the spec keys `.newMessage` on a `CachedMessage` ID not previously stored. The conversations **list** endpoint returns no per-message IDs (only `last_message` snippet + `last_message_at`), and fetching every thread's full messages on every background tick would cost N extra requests against rate limits. Instead, `.newMessage` is emitted (keyed on `conversationId`, `subjectId = conversationId`) when a conversation's `last_message_at` advances beyond the stored value **and** its `workflow_state == "unread"`, with baseline suppression on the first inbox sync — mirroring how `dueSoon`/submission baseline suppression already works in `syncCourse`.
- **Read tracking is local-first but round-tripped:** unlike announcement `readAt` (device-local only), conversation read state **is** a Canvas concept. `markConversationRead` sets the local `workflowState = "read"` immediately (optimistic) *and* PUTs to Canvas; a re-sync adopts Canvas's authoritative `workflow_state`. Do not treat an inbound `"unread"` as clobbering — Canvas is the source of truth for conversations (opposite of announcements).
- **Discussions are strictly read-only (spec §2.6, §5.3):** no posting, no reply composer. Each entry and the topic show a "Reply in Canvas" / "Open in Canvas" link out via `htmlURL`. `CourseTab.discussions` renders the real tab; posting endpoints are **not** added.
- **Detail fetches are lazy:** `SyncEngine.syncCourse` fetches the discussion **topics list** only (30-min TTL). A topic's entry tree (`/view`) is fetched on open via `.discussion(courseId:topicId:)`. A conversation's messages are fetched on open via `.conversation(id)`. Background ticks never fan out into per-thread/per-topic detail.
- **JSON blobs mirror the existing idiom:** `CachedConversation.participantsJSON` is a `Data?` JSON blob decoded on read, exactly like `CachedCourse.gradingSchemeJSON` / `CachedSubmission.rubricAssessmentJSON`. Scalars (`workflowState`, `depth`, `pending`) are plain stored properties.
- **No literal ports; follow existing patterns:** value-driven `public struct … : View` with `public init` in `CanvasUI`; `ObservableObject`/`@Published` view-models in `CanvasApp` (matches `AnnouncementsViewModel`, not the `@Observable` style reserved for `Router`/`AppSession`); SF Symbols only (`tray`, `tray.full`, `square.and.pencil`, `arrowshape.turn.up.left`, `bubble.left.and.bubble.right`, `bell`, `bell.badge`, `moon`, `paperplane`). No bundled images.
- **Palette/tokens:** reuse `Sources/CanvasUI/DesignTokens.swift`/`BrandColors.swift` exclusively (`inkPrimary`, `inkSecondary`, `inkTertiary`, `canvasBG`, `canvasHairline`, `byuhRed`). Do not reuse `accentHypothetical` — reserved for what-if values. Unread = `inkPrimary` bold + a `byuhRed` dot; read = `inkSecondary`.
- **Notification permission is lazy (spec §6):** never requested at launch. Requested the first time the user enables **any** notification category in Settings. Default categories: grades ON, feedback ON, messages OFF, dueSoon OFF.
- **Background refresh (spec §6):** `Timer` in the always-resident app process, default 30 min, configurable 15 min–4 h; immediate tick on wake-from-sleep and on reachability returning; suspended while on battery below 20% or while the display has been asleep > 1 h. Coalescing: > 3 changes of one kind in one course → one summary notification. Quiet hours suppress *posting* but suppressed changes still populate the change feed. The menu-bar icon shows a badge count of unseen changes.

---

## File Structure

**Create:**
- `Sources/CanvasCore/ConversationModels.swift` — `Conversation`, `ConversationParticipant`, `ConversationMessage`, `ConversationScope`.
- `Sources/CanvasCore/DiscussionModels.swift` — `DiscussionTopic`, `DiscussionView`, `DiscussionParticipant`, `DiscussionEntryNode`, `FlatDiscussionEntry`, `flattenDiscussion(_:)`.
- `Tests/CanvasCoreTests/ConversationModelsTests.swift`, `Tests/CanvasCoreTests/DiscussionModelsTests.swift`, `Tests/CanvasCoreTests/ConversationAPITests.swift`, `Tests/CanvasCoreTests/DiscussionAPITests.swift`.
- `Sources/CanvasData/Models/ConversationModels.swift` — `@Model CachedConversation`, `@Model CachedMessage`.
- `Sources/CanvasData/Models/DiscussionModels.swift` — `@Model CachedDiscussionTopic`, `@Model CachedDiscussionEntry`.
- `Sources/CanvasData/NotificationPlanner.swift` — `NotificationSettings`, `NotificationRequestSpec`, `NotificationPlanner` (pure), `NotificationRevealPayload`.
- `Sources/CanvasData/NotificationScheduler.swift` — `NotificationScheduler` (UN wrapper, `@MainActor`).
- `Sources/CanvasData/BackgroundGate.swift` — `PowerState`, `shouldRunBackgroundTick(...)` (pure).
- `Tests/CanvasDataTests/ConversationSyncTests.swift`, `Tests/CanvasDataTests/ConversationWriteTests.swift`, `Tests/CanvasDataTests/DiscussionSyncTests.swift`, `Tests/CanvasDataTests/ConversationChangeTests.swift`, `Tests/CanvasDataTests/NotificationPlannerTests.swift`, `Tests/CanvasDataTests/BackgroundGateTests.swift`.
- `Sources/CanvasUI/InboxComponents.swift` — `ConversationRow`, `MessageBubble`, `ComposeSheet`, `ReplyComposer`.
- `Sources/CanvasUI/DiscussionComponents.swift` — `DiscussionTopicRow`, `DiscussionEntryView`.
- `CanvasApp/ViewModels/InboxViewModel.swift`, `CanvasApp/ViewModels/DiscussionsViewModel.swift`.
- `CanvasApp/Views/Window/InboxView.swift`, `CanvasApp/Views/Window/DiscussionsTabView.swift`.
- `CanvasApp/App/NotificationSettingsStore.swift` — `@Observable` UserDefaults-backed store.
- `CanvasApp/App/BackgroundRefreshController.swift` — `@MainActor @Observable` timer/observer controller.

**Modify:**
- `Sources/CanvasCore/APIClient.swift` — private `sendForm(path:method:fields:)`; add `conversations(scope:)`, `conversation(id:)`, `createConversation(recipientIds:subject:body:)`, `replyToConversation(id:body:)`, `markConversationRead(id:)`, `discussionTopics(courseId:)`, `discussionView(courseId:topicId:)`, with `DEMO` short-circuits.
- `Sources/CanvasCore/MockData.swift` — `conversations`, `conversationDetails` (by id), `discussionTopics` (by course), `discussionViews` (by topic id); mutable demo write helpers.
- `Sources/CanvasData/CanvasStore.swift` — add `CachedConversation.self`, `CachedMessage.self`, `CachedDiscussionTopic.self`, `CachedDiscussionEntry.self` to `Schema([...])`.
- `Sources/CanvasData/SyncEngine.swift` — extend `SyncScope` (`.inbox`, `.conversation(Int)`, `.discussion(courseId:topicId:)`); extend `EntityKind` (`.conversations`, `.messages`, `.discussionTopics`, `.discussionEntries`) + TTLs; `perform` switch arms; `syncInbox`, `syncConversation`, `syncDiscussionEntries`; discussion-topics fetch in `syncCourse`; write methods `markConversationRead`, `sendReply`, `compose`; upsert helpers.
- `Sources/CanvasData/ChangeDetector.swift` — `conversationChanges(courseId:old:new:isBaseline:)`.
- `Sources/CanvasData/CanvasRepository.swift` — `conversations(scope:)`, `conversation(id:)`, `messages(conversationId:)`, `discussionTopics(courseId:)`, `discussionEntries(topicId:)`, `insertPendingMessage(...)`, `removePendingMessages(conversationId:)`, `markConversationReadLocal(id:)`, `unseenConversationCount()`; extend `clearStore()` + `purgeExpired()`.
- `CanvasApp/Views/Window/MainWindowView.swift` — render `InboxView` for `.inbox`; sidebar Inbox row shows `unseenConversationCount`.
- `CanvasApp/Views/Window/CourseWorkspaceView.swift` — render `DiscussionsTabView` for `.discussions`.
- `CanvasApp/Views/SettingsView.swift` — add `NotificationSettingsSection` (categories, quiet hours, interval), non-onboarding only.
- `CanvasApp/App/AppSession.swift` — expose `notificationSettings: NotificationSettingsStore`, `scheduler: NotificationScheduler`; write wrappers `markConversationRead`, `sendReply`, `compose`; `processUnseenChanges()`.
- `CanvasApp/App/CanvasApp.swift` — construct `BackgroundRefreshController`, start it, set the `UNUserNotificationCenterDelegate` for tap→reveal, badge the menu-bar item.

---

## Global test harness reference

`CanvasDataTests` sync/write tests use this exact scaffold (from `AnnouncementSyncTests`):

```swift
let container = try CanvasStore.container(inMemory: true)
let engine = SyncEngine(modelContainer: container)
let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
await engine.configure(client: client)
// … engine.refresh(scope) … then read container.mainContext on MainActor.run { … }
```

`CanvasCoreTests` request-shaping tests use a recording `URLProtocol` (a variant of `ProfileTests.FixedResponseStub` that captures the request). Each API task defines the stub it needs.

---

# GROUP A — INBOX

### Task 1: Conversation decode models (`CanvasCore`)

**Files:**
- Create: `Sources/CanvasCore/ConversationModels.swift`
- Test: `Tests/CanvasCoreTests/ConversationModelsTests.swift`

**Interfaces:**
- Produces: `Conversation`, `ConversationParticipant`, `ConversationMessage`, `enum ConversationScope: String, CaseIterable { case inbox, unread, archived }`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CanvasCore

final class ConversationModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }

    func testListRowDecodes() throws {
        let json = Data(#"""
        {"id": 5, "subject": "Lab 3", "workflow_state": "unread",
         "last_message": "See feedback", "last_message_at": "2026-08-01T10:00:00Z",
         "message_count": 4, "context_name": "BIOL 100",
         "participants": [{"id": 1, "name": "Dr. Reed"}, {"id": 77, "name": "Me"}]}
        """#.utf8)
        let c = try decoder().decode(Conversation.self, from: json)
        XCTAssertEqual(c.id, 5)
        XCTAssertEqual(c.subject, "Lab 3")
        XCTAssertEqual(c.workflowState, "unread")
        XCTAssertEqual(c.lastMessage, "See feedback")
        XCTAssertEqual(c.messageCount, 4)
        XCTAssertEqual(c.participants?.count, 2)
        XCTAssertEqual(c.participants?.first?.name, "Dr. Reed")
        XCTAssertNil(c.messages)  // list rows carry no messages
    }

    func testDetailDecodesMessages() throws {
        let json = Data(#"""
        {"id": 5, "subject": "Lab 3", "workflow_state": "read",
         "participants": [{"id": 1, "name": "Dr. Reed"}],
         "messages": [{"id": 9, "author_id": 1, "body": "Hi", "created_at": "2026-08-01T10:00:00Z"}]}
        """#.utf8)
        let c = try decoder().decode(Conversation.self, from: json)
        XCTAssertEqual(c.messages?.count, 1)
        XCTAssertEqual(c.messages?.first?.authorId, 1)
        XCTAssertEqual(c.messages?.first?.body, "Hi")
    }

    func testScopeCases() {
        XCTAssertEqual(ConversationScope.allCases.map(\.rawValue), ["inbox", "unread", "archived"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationModelsTests`
Expected: FAIL — `Conversation` undefined.

- [ ] **Step 3: Write the implementation**

```swift
import Foundation

public struct ConversationParticipant: Codable, Sendable, Equatable {
    public let id: Int
    public let name: String
    public init(id: Int, name: String) { self.id = id; self.name = name }
}

public struct ConversationMessage: Codable, Sendable, Equatable {
    public let id: Int
    public let authorId: Int
    public let body: String?
    public let createdAt: String?
    public init(id: Int, authorId: Int, body: String?, createdAt: String?) {
        self.id = id; self.authorId = authorId; self.body = body; self.createdAt = createdAt
    }
}

public struct Conversation: Codable, Sendable, Equatable {
    public let id: Int
    public let subject: String?
    public let workflowState: String            // "read" | "unread" | "archived"
    public let lastMessage: String?
    public let lastMessageAt: String?
    public let messageCount: Int?
    public let contextName: String?
    public let participants: [ConversationParticipant]?
    public let messages: [ConversationMessage]? // present only on the detail fetch

    public init(id: Int, subject: String?, workflowState: String, lastMessage: String?,
                lastMessageAt: String?, messageCount: Int?, contextName: String?,
                participants: [ConversationParticipant]?, messages: [ConversationMessage]?) {
        self.id = id; self.subject = subject; self.workflowState = workflowState
        self.lastMessage = lastMessage; self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount; self.contextName = contextName
        self.participants = participants; self.messages = messages
    }
}

public enum ConversationScope: String, Sendable, CaseIterable {
    case inbox, unread, archived
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ConversationModelsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/ConversationModels.swift Tests/CanvasCoreTests/ConversationModelsTests.swift
git commit -m "feat(core): Conversation/ConversationMessage decode models + ConversationScope"
```

---

### Task 2: Conversation API methods + form writer (`CanvasCore`)

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`
- Modify: `Sources/CanvasCore/MockData.swift`
- Test: `Tests/CanvasCoreTests/ConversationAPITests.swift`

**Interfaces:**
- Consumes: `Conversation`, `ConversationScope` (Task 1); `MockData` demo store (this task adds the members).
- Produces on `APIClient`:
  - `func conversations(scope: ConversationScope) async throws -> [Conversation]`
  - `func conversation(id: Int) async throws -> Conversation`
  - `func createConversation(recipientIds: [Int], subject: String, body: String) async throws -> Conversation`
  - `func replyToConversation(id: Int, body: String) async throws -> Conversation`
  - `func markConversationRead(id: Int) async throws`
- Produces on `MockData`: `static var conversations: [Conversation]`, `static var conversationDetails: [Int: Conversation]`, plus demo write helpers `demoCreateConversation`, `demoAppendReply`, `demoMarkRead`.

- [ ] **Step 1: Write the failing test** (request shaping + demo)

```swift
import XCTest
@testable import CanvasCore

final class ConversationAPITests: XCTestCase {
    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordingStub.self]
        RecordingStub.reset()
        return APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "T"),
                         session: URLSession(configuration: config))
    }

    func testConversationsUsesScopeQuery() async throws {
        RecordingStub.body = Data("[]".utf8)
        _ = try await client().conversations(scope: .unread)
        XCTAssertTrue(RecordingStub.lastURL!.absoluteString.contains("/conversations"))
        XCTAssertTrue(RecordingStub.lastURL!.absoluteString.contains("scope=unread"))
    }

    func testReplyPostsBodyForm() async throws {
        RecordingStub.body = Data(#"{"id":5,"workflow_state":"read"}"#.utf8)
        _ = try await client().replyToConversation(id: 5, body: "Thanks!")
        XCTAssertEqual(RecordingStub.lastMethod, "POST")
        XCTAssertTrue(RecordingStub.lastURL!.absoluteString.hasSuffix("/conversations/5/add_message"))
        let form = String(data: RecordingStub.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(form.contains("body=Thanks%21"))
    }

    func testMarkReadPutsWorkflowState() async throws {
        RecordingStub.body = Data(#"{"id":5,"workflow_state":"read"}"#.utf8)
        try await client().markConversationRead(id: 5)
        XCTAssertEqual(RecordingStub.lastMethod, "PUT")
        let form = String(data: RecordingStub.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(form.contains("conversation%5Bworkflow_state%5D=read"))  // conversation[workflow_state]=read
    }

    func testComposePostsRecipientsAndSubject() async throws {
        RecordingStub.body = Data(#"[{"id":9,"workflow_state":"read","subject":"Q"}]"#.utf8)
        let c = try await client().createConversation(recipientIds: [1, 2], subject: "Q", body: "Hello")
        XCTAssertEqual(c.id, 9)   // Canvas returns an array; we take the first
        let form = String(data: RecordingStub.lastBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(form.contains("recipients%5B%5D=1"))
        XCTAssertTrue(form.contains("recipients%5B%5D=2"))
        XCTAssertTrue(form.contains("subject=Q"))
        XCTAssertTrue(form.contains("body=Hello"))
    }

    func testDemoConversationsShortCircuit() async throws {
        let demo = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let list = try await demo.conversations(scope: .inbox)
        XCTAssertFalse(list.isEmpty)
    }
}

final class RecordingStub: URLProtocol {
    static var body = Data()
    static var lastURL: URL?
    static var lastMethod: String?
    static var lastBody: Data?
    static func reset() { body = Data(); lastURL = nil; lastMethod = nil; lastBody = nil }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastURL = request.url
        Self.lastMethod = request.httpMethod
        // URLProtocol strips httpBody into a stream for non-GET; capture whichever is set.
        Self.lastBody = request.httpBody ?? request.httpBodyStream.map(Self.drain)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
    private static func drain(_ stream: InputStream) -> Data {
        stream.open(); defer { stream.close() }
        var data = Data(); let size = 4096; var buf = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buf, maxLength: size)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationAPITests`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Add the demo store to `MockData.swift`**

Add near the existing `announcements`/`profile` members (use `studentUserId`/`teacherUserId` already defined):

```swift
    // MARK: - Phase 2 demo store (conversations)

    /// Mutable so demo writes (compose/reply/mark-read) persist for the session.
    public static var conversations: [Conversation] = [
        Conversation(id: 5001, subject: "Lab 3 feedback", workflowState: "unread",
                     lastMessage: "Nice work — see my note on part 2.",
                     lastMessageAt: "2026-08-06T18:30:00Z", messageCount: 2, contextName: "BIOL 100",
                     participants: [ConversationParticipant(id: teacherUserId, name: "Dr. Reed"),
                                    ConversationParticipant(id: studentUserId, name: "Demo Student")],
                     messages: nil),
        Conversation(id: 5002, subject: "Office hours", workflowState: "read",
                     lastMessage: "Thursday 2–4 works.",
                     lastMessageAt: "2026-08-04T09:00:00Z", messageCount: 3, contextName: "CS 220",
                     participants: [ConversationParticipant(id: teacherUserId, name: "Prof. Lang"),
                                    ConversationParticipant(id: studentUserId, name: "Demo Student")],
                     messages: nil),
        Conversation(id: 5003, subject: "Withdrawn section", workflowState: "archived",
                     lastMessage: "Archived thread.",
                     lastMessageAt: "2026-07-20T12:00:00Z", messageCount: 1, contextName: "ENGL 101",
                     participants: [ConversationParticipant(id: teacherUserId, name: "Ms. Ová"),
                                    ConversationParticipant(id: studentUserId, name: "Demo Student")],
                     messages: nil),
    ]

    public static var conversationDetails: [Int: Conversation] = [
        5001: Conversation(id: 5001, subject: "Lab 3 feedback", workflowState: "unread",
                           lastMessage: nil, lastMessageAt: "2026-08-06T18:30:00Z", messageCount: 2,
                           contextName: "BIOL 100",
                           participants: [ConversationParticipant(id: teacherUserId, name: "Dr. Reed"),
                                          ConversationParticipant(id: studentUserId, name: "Demo Student")],
                           messages: [
                            ConversationMessage(id: 6001, authorId: studentUserId,
                                                body: "I submitted Lab 3 — anything to fix?",
                                                createdAt: "2026-08-06T17:00:00Z"),
                            ConversationMessage(id: 6002, authorId: teacherUserId,
                                                body: "Nice work — see my note on part 2.",
                                                createdAt: "2026-08-06T18:30:00Z"),
                           ]),
        5002: Conversation(id: 5002, subject: "Office hours", workflowState: "read",
                           lastMessage: nil, lastMessageAt: "2026-08-04T09:00:00Z", messageCount: 3,
                           contextName: "CS 220",
                           participants: [ConversationParticipant(id: teacherUserId, name: "Prof. Lang"),
                                          ConversationParticipant(id: studentUserId, name: "Demo Student")],
                           messages: [
                            ConversationMessage(id: 6010, authorId: studentUserId,
                                                body: "Are office hours on this week?", createdAt: "2026-08-03T08:00:00Z"),
                            ConversationMessage(id: 6011, authorId: teacherUserId,
                                                body: "Thursday 2–4 works.", createdAt: "2026-08-04T09:00:00Z"),
                           ]),
        5003: Conversation(id: 5003, subject: "Withdrawn section", workflowState: "archived",
                           lastMessage: nil, lastMessageAt: "2026-07-20T12:00:00Z", messageCount: 1,
                           contextName: "ENGL 101",
                           participants: [ConversationParticipant(id: teacherUserId, name: "Ms. Ová"),
                                          ConversationParticipant(id: studentUserId, name: "Demo Student")],
                           messages: [ConversationMessage(id: 6020, authorId: teacherUserId,
                                                          body: "Archived thread.", createdAt: "2026-07-20T12:00:00Z")]),
    ]

    private static var demoNextId = 7000

    public static func demoCreateConversation(recipientIds: [Int], subject: String, body: String) -> Conversation {
        demoNextId += 1
        let id = demoNextId
        let now = ISO8601DateFormatter().string(from: Date())
        let detail = Conversation(id: id, subject: subject, workflowState: "read", lastMessage: body,
                                  lastMessageAt: now, messageCount: 1, contextName: "New Message",
                                  participants: [ConversationParticipant(id: studentUserId, name: "Demo Student"),
                                                 ConversationParticipant(id: recipientIds.first ?? teacherUserId, name: "Dr. Reed")],
                                  messages: [ConversationMessage(id: demoNextId + 100000, authorId: studentUserId,
                                                                 body: body, createdAt: now)])
        conversationDetails[id] = detail
        conversations.insert(detail, at: 0)
        return detail
    }

    public static func demoAppendReply(id: Int, body: String) -> Conversation {
        let now = ISO8601DateFormatter().string(from: Date())
        guard var detail = conversationDetails[id] else { return conversations.first! }
        var msgs = detail.messages ?? []
        demoNextId += 1
        msgs.append(ConversationMessage(id: demoNextId + 200000, authorId: studentUserId, body: body, createdAt: now))
        detail = Conversation(id: detail.id, subject: detail.subject, workflowState: "read", lastMessage: body,
                              lastMessageAt: now, messageCount: msgs.count, contextName: detail.contextName,
                              participants: detail.participants, messages: msgs)
        conversationDetails[id] = detail
        return detail
    }

    public static func demoMarkRead(id: Int) {
        guard let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        let c = conversations[idx]
        conversations[idx] = Conversation(id: c.id, subject: c.subject, workflowState: "read",
                                          lastMessage: c.lastMessage, lastMessageAt: c.lastMessageAt,
                                          messageCount: c.messageCount, contextName: c.contextName,
                                          participants: c.participants, messages: c.messages)
    }
```

- [ ] **Step 4: Add the API methods to `APIClient.swift`**

Add the shared form-writer and the five methods (after `profile()`):

```swift
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
        let data = try await getPaginated("/conversations", query: [
            URLQueryItem(name: "scope", value: scope.rawValue),
            URLQueryItem(name: "per_page", value: "50"),
        ])
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter ConversationAPITests`
Expected: PASS (all 5).

- [ ] **Step 6: Commit**

```bash
git add Sources/CanvasCore/APIClient.swift Sources/CanvasCore/MockData.swift Tests/CanvasCoreTests/ConversationAPITests.swift
git commit -m "feat(core): conversation list/detail/compose/reply/mark-read API + form writer + demo store"
```

---

### Task 3: Cached conversation models + schema + repository reads (`CanvasData`)

**Files:**
- Create: `Sources/CanvasData/Models/ConversationModels.swift`
- Modify: `Sources/CanvasData/CanvasStore.swift`
- Modify: `Sources/CanvasData/CanvasRepository.swift`
- Test: `Tests/CanvasDataTests/ConversationSyncTests.swift` (schema round-trip portion)

**Interfaces:**
- Produces: `@Model CachedConversation`, `@Model CachedMessage`; repository `conversations(scope:) -> [CachedConversation]`, `conversation(id:) -> CachedConversation?`, `messages(conversationId:) -> [CachedMessage]`.
- Consumes: `ConversationScope` (Task 1).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class ConversationSyncTests: XCTestCase {
    func testSchemaRoundTripsConversationAndMessage() throws {
        let container = try CanvasStore.container(inMemory: true)
        try MainActor.run {
            let ctx = container.mainContext
            ctx.insert(CachedConversation(id: 5, subject: "Hi", lastMessageAt: Date(),
                                          lastMessageSnippet: "yo", workflowState: "unread",
                                          participantsJSON: nil, contextName: "BIOL 100", messageCount: 1))
            ctx.insert(CachedMessage(id: 9, conversationId: 5, authorId: 1, authorName: "Dr. Reed",
                                     body: "yo", createdAt: Date(), pending: false))
            try ctx.save()
            let repo = CanvasRepository(modelContainer: container)
            XCTAssertEqual(try repo.conversation(id: 5)?.subject, "Hi")
            XCTAssertEqual(try repo.messages(conversationId: 5).count, 1)
        }
    }

    func testConversationsScopeFilter() throws {
        let container = try CanvasStore.container(inMemory: true)
        try MainActor.run {
            let ctx = container.mainContext
            ctx.insert(CachedConversation(id: 1, subject: "a", lastMessageAt: Date(), lastMessageSnippet: nil,
                                          workflowState: "unread", participantsJSON: nil, contextName: nil, messageCount: 1))
            ctx.insert(CachedConversation(id: 2, subject: "b", lastMessageAt: Date(), lastMessageSnippet: nil,
                                          workflowState: "read", participantsJSON: nil, contextName: nil, messageCount: 1))
            ctx.insert(CachedConversation(id: 3, subject: "c", lastMessageAt: Date(), lastMessageSnippet: nil,
                                          workflowState: "archived", participantsJSON: nil, contextName: nil, messageCount: 1))
            try ctx.save()
            let repo = CanvasRepository(modelContainer: container)
            XCTAssertEqual(try repo.conversations(scope: .inbox).count, 2)     // unread + read, not archived
            XCTAssertEqual(try repo.conversations(scope: .unread).count, 1)
            XCTAssertEqual(try repo.conversations(scope: .archived).count, 1)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationSyncTests`
Expected: FAIL — `CachedConversation` undefined.

- [ ] **Step 3: Create the models**

`Sources/CanvasData/Models/ConversationModels.swift`:

```swift
import Foundation
import SwiftData
import CanvasCore

@Model
public final class CachedConversation {
    @Attribute(.unique) public var id: Int
    public var subject: String?
    public var lastMessageAt: Date?
    public var lastMessageSnippet: String?
    public var workflowState: String            // Canvas is authoritative: "read"|"unread"|"archived"
    public var participantsJSON: Data?          // [ConversationParticipant] JSON blob
    public var contextName: String?
    public var messageCount: Int
    public var removedAt: Date?

    public init(id: Int, subject: String?, lastMessageAt: Date?, lastMessageSnippet: String?,
                workflowState: String, participantsJSON: Data?, contextName: String?,
                messageCount: Int, removedAt: Date? = nil) {
        self.id = id; self.subject = subject; self.lastMessageAt = lastMessageAt
        self.lastMessageSnippet = lastMessageSnippet; self.workflowState = workflowState
        self.participantsJSON = participantsJSON; self.contextName = contextName
        self.messageCount = messageCount; self.removedAt = removedAt
    }

    public var participants: [ConversationParticipant] {
        participantsJSON.flatMap { try? JSONDecoder().decode([ConversationParticipant].self, from: $0) } ?? []
    }
}

@Model
public final class CachedMessage {
    @Attribute(.unique) public var id: Int
    public var conversationId: Int
    public var authorId: Int
    public var authorName: String?
    public var body: String?
    public var createdAt: Date?
    /// Optimistically-inserted local send, not yet reconciled with Canvas (spec §5.2).
    public var pending: Bool

    public init(id: Int, conversationId: Int, authorId: Int, authorName: String?,
                body: String?, createdAt: Date?, pending: Bool = false) {
        self.id = id; self.conversationId = conversationId; self.authorId = authorId
        self.authorName = authorName; self.body = body; self.createdAt = createdAt; self.pending = pending
    }
}
```

- [ ] **Step 4: Add to schema**

In `CanvasStore.swift`, extend the `Schema([...])` array:

```swift
        CachedAnnouncement.self,
        CachedConversation.self, CachedMessage.self,
```

- [ ] **Step 5: Add repository reads**

In `CanvasRepository.swift`, after `announcements(courseId:)`:

```swift
    public func conversations(scope: ConversationScope) throws -> [CachedConversation] {
        let all = try context.fetch(FetchDescriptor<CachedConversation>())
            .filter { $0.removedAt == nil }
        let scoped: [CachedConversation]
        switch scope {
        case .inbox:    scoped = all.filter { $0.workflowState != "archived" }
        case .unread:   scoped = all.filter { $0.workflowState == "unread" }
        case .archived: scoped = all.filter { $0.workflowState == "archived" }
        }
        return scoped.sorted { ($0.lastMessageAt ?? .distantPast) > ($1.lastMessageAt ?? .distantPast) }
    }

    public func conversation(id: Int) throws -> CachedConversation? {
        let predicate = #Predicate<CachedConversation> { $0.id == id }
        return try context.fetch(FetchDescriptor(predicate: predicate)).first
    }

    public func messages(conversationId: Int) throws -> [CachedMessage] {
        let predicate = #Predicate<CachedMessage> { $0.conversationId == conversationId }
        return try context.fetch(FetchDescriptor(predicate: predicate))
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    public func unseenConversationCount() throws -> Int {
        try context.fetch(FetchDescriptor<CachedConversation>())
            .filter { $0.removedAt == nil && $0.workflowState == "unread" }.count
    }
```

Add `import CanvasCore` at the top of `CanvasRepository.swift` if not already present (it needs `ConversationScope`).

Extend `clearStore()` with:

```swift
        try context.delete(model: CachedConversation.self)
        try context.delete(model: CachedMessage.self)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter ConversationSyncTests`
Expected: PASS (both).

- [ ] **Step 7: Commit**

```bash
git add Sources/CanvasData/Models/ConversationModels.swift Sources/CanvasData/CanvasStore.swift Sources/CanvasData/CanvasRepository.swift Tests/CanvasDataTests/ConversationSyncTests.swift
git commit -m "feat(data): CachedConversation/CachedMessage models, schema, repository reads"
```

---

### Task 4: `.inbox` sync scope + upsert (`CanvasData`)

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Test: `Tests/CanvasDataTests/ConversationSyncTests.swift` (add sync cases)

**Interfaces:**
- Consumes: `APIClient.conversations(scope:)` (Task 2), `CachedConversation` (Task 3).
- Produces: `SyncScope.inbox`; `EntityKind.conversations`; `SyncEngine` upserts conversation list rows.

- [ ] **Step 1: Write the failing test** (append to `ConversationSyncTests`)

```swift
    func testInboxSyncPopulatesConversations() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        try await engine.refresh(.inbox)
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversations(scope: .inbox).count
        }
        XCTAssertEqual(count, 2)   // demo inbox = unread + read (archived excluded)
    }

    func testInboxResyncIsIdempotent() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        try await engine.refresh(.inbox)
        try await engine.refresh(.inbox, force: true)
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversations(scope: .inbox).count
        }
        XCTAssertEqual(count, 2)   // no duplicates
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationSyncTests`
Expected: FAIL — `SyncScope` has no `.inbox`.

- [ ] **Step 3: Extend `SyncScope`, `EntityKind`, TTL, `perform`**

In `SyncEngine.swift`:

```swift
public enum SyncScope: Hashable, Sendable {
    case all
    case course(Int)
    case inbox
    case conversation(Int)
    case discussion(courseId: Int, topicId: Int)
}
```

```swift
public enum EntityKind: String, Sendable {
    case courses, enrollments, assignments, submissions, announcements
    case conversations, messages, discussionTopics, discussionEntries
}
```

Extend the TTL table:

```swift
    private static let ttl: [EntityKind: TimeInterval] = [
        .courses: 300, .enrollments: 300, .assignments: 900, .submissions: 300,
        .announcements: 1800,
        .conversations: 300, .messages: 300, .discussionTopics: 1800, .discussionEntries: 1800,
    ]
```

Add arms to `perform`'s switch:

```swift
            case .inbox:
                try await syncInbox(client: client, force: force)
            case .conversation(let id):
                try await syncConversation(id, client: client, force: force)
            case .discussion(let courseId, let topicId):
                try await syncDiscussionEntries(courseId: courseId, topicId: topicId, client: client, force: force)
```

- [ ] **Step 4: Implement `syncInbox` + `upsertConversations`**

Add to `SyncEngine`:

```swift
    // MARK: - .inbox

    private func syncInbox(client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.conversations, scope: "inbox", now: now) else { return }
        let inboxMetaKey = "conversations:inbox"
        let hadPrior = fetchOne(FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == inboxMetaKey }))?.lastSyncedAt != nil

        let fetched = try await fetchWithRetry { try await client.conversations(scope: .inbox) }
        let old = conversationLastMessageDates()
        upsertConversations(fetched, now: now)
        insert(ChangeDetector.conversationChanges(old: old, new: fetched, isBaseline: !hadPrior), now: now)
        touch(.conversations, scope: "inbox", error: nil, at: now)
        try modelContext.save()
    }

    private func conversationLastMessageDates() -> [Int: Date?] {
        let rows = (try? modelContext.fetch(FetchDescriptor<CachedConversation>())) ?? []
        return Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.lastMessageAt) })
    }

    private func upsertConversations(_ items: [Conversation], now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedConversation>())) ?? []).map { ($0.id, $0) })
        let fetchedIds = Set(items.map(\.id))
        for c in items {
            let participantsJSON = c.participants.flatMap { try? JSONEncoder().encode($0) }
            let lastAt = CanvasDate.parse(c.lastMessageAt)
            if let row = existing[c.id] {
                row.subject = c.subject; row.lastMessageAt = lastAt
                row.lastMessageSnippet = c.lastMessage; row.workflowState = c.workflowState
                row.contextName = c.contextName; row.messageCount = c.messageCount ?? row.messageCount
                if let participantsJSON { row.participantsJSON = participantsJSON }
                row.removedAt = nil
            } else {
                modelContext.insert(CachedConversation(
                    id: c.id, subject: c.subject, lastMessageAt: lastAt, lastMessageSnippet: c.lastMessage,
                    workflowState: c.workflowState, participantsJSON: participantsJSON,
                    contextName: c.contextName, messageCount: c.messageCount ?? 0))
            }
        }
        // Soft-delete conversations that dropped out of the inbox scope (e.g. archived elsewhere).
        for (id, row) in existing where !fetchedIds.contains(id) && row.workflowState != "archived" && row.removedAt == nil {
            row.removedAt = now
        }
    }
```

`ChangeDetector.conversationChanges` is added in Task 6; until then this call will not compile. **To keep this task independently green, implement Task 6 as part of this commit** (they share the same test file), OR temporarily stub `insert(ChangeDetector.conversationChanges(...))` — the plan orders Task 6 immediately after and both land here. Recommended: do Task 6's `ChangeDetector` addition now so `syncInbox` compiles, then this test and Task 6's tests both pass. (Steps below assume `conversationChanges` exists.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter ConversationSyncTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CanvasData/SyncEngine.swift Tests/CanvasDataTests/ConversationSyncTests.swift
git commit -m "feat(data): .inbox sync scope, upsertConversations, EntityKind + TTLs"
```

---

### Task 5: `.newMessage` change detection (`CanvasData`)

**Files:**
- Modify: `Sources/CanvasData/ChangeDetector.swift`
- Test: `Tests/CanvasDataTests/ConversationChangeTests.swift`

**Interfaces:**
- Consumes: `Conversation` (Task 1), `ChangeKind.newMessage` (already exists).
- Produces: `ChangeDetector.conversationChanges(old: [Int: Date?], new: [Conversation], isBaseline: Bool) -> [PendingChange]`.

> Do this task's `ChangeDetector` addition together with Task 4 (the `syncInbox` call depends on it), but its dedicated tests live here.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import CanvasCore
@testable import CanvasData

final class ConversationChangeTests: XCTestCase {
    private func convo(_ id: Int, at iso: String, state: String) -> Conversation {
        Conversation(id: id, subject: "S\(id)", workflowState: state, lastMessage: "hi",
                     lastMessageAt: iso, messageCount: 1, contextName: "BIOL 100",
                     participants: nil, messages: nil)
    }

    func testBaselineSyncIsSilent() {
        let changes = ChangeDetector.conversationChanges(
            old: [:], new: [convo(1, at: "2026-08-06T10:00:00Z", state: "unread")], isBaseline: true)
        XCTAssertTrue(changes.isEmpty)
    }

    func testAdvancingUnreadFiresNewMessage() {
        let old: [Int: Date?] = [1: CanvasDate.parse("2026-08-05T10:00:00Z")]
        let changes = ChangeDetector.conversationChanges(
            old: old, new: [convo(1, at: "2026-08-06T10:00:00Z", state: "unread")], isBaseline: false)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .newMessage)
        XCTAssertEqual(changes.first?.subjectId, 1)
    }

    func testUnchangedTimestampDoesNotFire() {
        let old: [Int: Date?] = [1: CanvasDate.parse("2026-08-06T10:00:00Z")]
        let changes = ChangeDetector.conversationChanges(
            old: old, new: [convo(1, at: "2026-08-06T10:00:00Z", state: "unread")], isBaseline: false)
        XCTAssertTrue(changes.isEmpty)
    }

    func testReadStateDoesNotFireEvenIfAdvanced() {
        let old: [Int: Date?] = [1: CanvasDate.parse("2026-08-05T10:00:00Z")]
        let changes = ChangeDetector.conversationChanges(
            old: old, new: [convo(1, at: "2026-08-06T10:00:00Z", state: "read")], isBaseline: false)
        XCTAssertTrue(changes.isEmpty)   // I sent it / already read → not a new inbound message
    }

    func testBrandNewUnreadConversationFires() {
        let changes = ChangeDetector.conversationChanges(
            old: [2: CanvasDate.parse("2026-08-01T00:00:00Z")],
            new: [convo(9, at: "2026-08-06T10:00:00Z", state: "unread")], isBaseline: false)
        XCTAssertEqual(changes.first?.subjectId, 9)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationChangeTests`
Expected: FAIL — `conversationChanges` undefined.

- [ ] **Step 3: Implement `conversationChanges`**

Add to `ChangeDetector` in `ChangeDetector.swift`:

```swift
    /// .newMessage — fires when a conversation is `unread` and its `lastMessageAt` has advanced
    /// beyond the stored value (or it is newly seen). `courseId` is 0: conversations are not
    /// course-scoped in this model; `subjectId` is the conversationId so a notification tap can
    /// reveal the thread. Baseline-suppressed on the first inbox sync (spec deviation, §3.1).
    public static func conversationChanges(old: [Int: Date?], new: [Conversation],
                                           isBaseline: Bool) -> [PendingChange] {
        guard !isBaseline else { return [] }
        var changes: [PendingChange] = []
        for c in new where c.workflowState == "unread" {
            let newDate = CanvasDate.parse(c.lastMessageAt)
            let priorDate = old[c.id] ?? nil
            let advanced: Bool
            if let newDate, let priorDate { advanced = newDate > priorDate }
            else if newDate != nil, old[c.id] == nil { advanced = true }   // brand new
            else { advanced = false }
            guard advanced else { continue }
            changes.append(PendingChange(kind: .newMessage, courseId: 0, subjectId: c.id,
                                         title: c.subject ?? "New message",
                                         detail: c.lastMessage))
        }
        return changes
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ConversationChangeTests`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/ChangeDetector.swift Tests/CanvasDataTests/ConversationChangeTests.swift
git commit -m "feat(data): .newMessage detection keyed on advancing unread lastMessageAt"
```

---

### Task 6: `.conversation(id)` detail sync — thread messages (`CanvasData`)

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Test: `Tests/CanvasDataTests/ConversationSyncTests.swift` (add detail cases)

**Interfaces:**
- Consumes: `APIClient.conversation(id:)` (Task 2), `CachedMessage` (Task 3).
- Produces: `SyncEngine.syncConversation(_:client:force:)` (wired into `perform` in Task 4); populates `CachedMessage` rows and reconciles the parent `CachedConversation`.

- [ ] **Step 1: Write the failing test**

```swift
    func testConversationDetailPopulatesMessages() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        try await engine.refresh(.inbox)
        try await engine.refresh(.conversation(5001))
        let msgs = try await MainActor.run {
            try CanvasRepository(modelContainer: container).messages(conversationId: 5001)
        }
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs.first?.authorName, "Demo Student")   // resolved from participants
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationSyncTests/testConversationDetailPopulatesMessages`
Expected: FAIL — `syncConversation` unimplemented (currently referenced in `perform` but not defined).

- [ ] **Step 3: Implement `syncConversation` + `upsertMessages`**

```swift
    // MARK: - .conversation

    private func syncConversation(_ id: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.messages, scope: "\(id)", now: now) else { return }
        let detail = try await fetchWithRetry { try await client.conversation(id: id) }
        // Reconcile parent row (adopt Canvas's authoritative workflow_state).
        upsertConversations([detail], now: now)
        upsertMessages(detail, now: now)
        touch(.messages, scope: "\(id)", error: nil, at: now)
        try modelContext.save()
    }

    private func upsertMessages(_ detail: Conversation, now: Date) {
        let names = Dictionary(uniqueKeysWithValues: (detail.participants ?? []).map { ($0.id, $0.name) })
        let convId = detail.id
        // Drop reconciled pending rows: real messages have arrived.
        let priorPending = (try? modelContext.fetch(FetchDescriptor<CachedMessage>(
            predicate: #Predicate<CachedMessage> { $0.conversationId == convId && $0.pending }))) ?? []
        for row in priorPending { modelContext.delete(row) }

        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedMessage>(
                predicate: #Predicate<CachedMessage> { $0.conversationId == convId }))) ?? [])
                .map { ($0.id, $0) })
        for m in detail.messages ?? [] {
            let created = CanvasDate.parse(m.createdAt)
            if let row = existing[m.id] {
                row.authorId = m.authorId; row.authorName = names[m.authorId]
                row.body = m.body; row.createdAt = created; row.pending = false
            } else {
                modelContext.insert(CachedMessage(id: m.id, conversationId: convId, authorId: m.authorId,
                                                  authorName: names[m.authorId], body: m.body,
                                                  createdAt: created, pending: false))
            }
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ConversationSyncTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/SyncEngine.swift Tests/CanvasDataTests/ConversationSyncTests.swift
git commit -m "feat(data): .conversation(id) detail sync populates + reconciles thread messages"
```

---

### Task 7: Conversation write methods — mark-read, reply, compose (`CanvasData`)

**Files:**
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Modify: `Sources/CanvasData/CanvasRepository.swift`
- Test: `Tests/CanvasDataTests/ConversationWriteTests.swift`

**Interfaces:**
- Consumes: `APIClient.markConversationRead/replyToConversation/createConversation` (Task 2).
- Produces on `SyncEngine`:
  - `func markConversationRead(_ id: Int) async throws`
  - `func sendReply(conversationId: Int, body: String) async throws`
  - `func compose(recipientIds: [Int], subject: String, body: String) async throws -> Int`
- Produces on `CanvasRepository`: `insertPendingMessage(conversationId:body:authorId:authorName:now:) -> Int`, `removePendingMessages(conversationId:)`, `markConversationReadLocal(id:)`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class ConversationWriteTests: XCTestCase {
    private func makeEngine() async throws -> (SyncEngine, ModelContainer) {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        return (engine, container)
    }

    func testMarkReadUpdatesWorkflowState() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.inbox)
        try await engine.markConversationRead(5001)
        let state = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversation(id: 5001)?.workflowState
        }
        XCTAssertEqual(state, "read")
    }

    func testSendReplyReconcilesPendingWithReal() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.inbox)
        try await engine.refresh(.conversation(5001))
        let before = try await MainActor.run {
            try CanvasRepository(modelContainer: container).messages(conversationId: 5001).count
        }
        try await engine.sendReply(conversationId: 5001, body: "Got it, thanks!")
        let (after, anyPending) = try await MainActor.run { () -> (Int, Bool) in
            let msgs = try CanvasRepository(modelContainer: container).messages(conversationId: 5001)
            return (msgs.count, msgs.contains { $0.pending })
        }
        XCTAssertEqual(after, before + 1)
        XCTAssertFalse(anyPending)   // reconciled: no orphaned optimistic row
    }

    func testComposeReturnsNewConversationId() async throws {
        let (engine, container) = try await makeEngine()
        let newId = try await engine.compose(recipientIds: [MockData.teacherUserId], subject: "Question", body: "Hi")
        let exists = try await MainActor.run {
            try CanvasRepository(modelContainer: container).conversation(id: newId) != nil
        }
        XCTAssertTrue(exists)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ConversationWriteTests`
Expected: FAIL — write methods undefined.

- [ ] **Step 3: Add repository write helpers**

In `CanvasRepository.swift`:

```swift
    // MARK: - Conversation writes (optimistic-local)

    /// Inserts an optimistic outgoing message and returns its temporary negative id
    /// (negative so it never collides with a real Canvas id). Reconciled away on next detail sync.
    @discardableResult
    public func insertPendingMessage(conversationId: Int, body: String, authorId: Int,
                                     authorName: String?, now: Date = .init()) throws -> Int {
        let tempId = -Int(Date().timeIntervalSince1970 * 1000)
        context.insert(CachedMessage(id: tempId, conversationId: conversationId, authorId: authorId,
                                     authorName: authorName, body: body, createdAt: now, pending: true))
        try context.save()
        return tempId
    }

    public func removePendingMessages(conversationId: Int) throws {
        let predicate = #Predicate<CachedMessage> { $0.conversationId == conversationId && $0.pending }
        for row in try context.fetch(FetchDescriptor(predicate: predicate)) { context.delete(row) }
        try context.save()
    }

    public func markConversationReadLocal(id: Int) throws {
        guard let row = try conversation(id: id) else { return }
        row.workflowState = "read"
        try context.save()
    }
```

- [ ] **Step 4: Add `SyncEngine` write methods**

```swift
    // MARK: - Writes

    public func markConversationRead(_ id: Int) async throws {
        guard let client else { throw SyncError.noClient }
        try await client.markConversationRead(id: id)
        if let row = fetchOne(FetchDescriptor<CachedConversation>(
            predicate: #Predicate<CachedConversation> { $0.id == id })) {
            row.workflowState = "read"
            try modelContext.save()
        }
    }

    /// The caller inserts the optimistic pending row (via the repository) before calling this;
    /// on success we re-fetch the thread, which deletes pending rows and installs the real ones.
    public func sendReply(conversationId: Int, body: String) async throws {
        guard let client else { throw SyncError.noClient }
        let detail = try await client.replyToConversation(id: conversationId, body: body)
        upsertConversations([detail], now: Date())
        upsertMessages(detail, now: Date())
        try modelContext.save()
    }

    public func compose(recipientIds: [Int], subject: String, body: String) async throws -> Int {
        guard let client else { throw SyncError.noClient }
        let created = try await client.createConversation(recipientIds: recipientIds, subject: subject, body: body)
        let now = Date()
        upsertConversations([created], now: now)
        upsertMessages(created, now: now)   // detail from compose may include the first message
        try modelContext.save()
        return created.id
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter ConversationWriteTests`
Expected: PASS (all 3).

- [ ] **Step 6: Commit**

```bash
git add Sources/CanvasData/SyncEngine.swift Sources/CanvasData/CanvasRepository.swift Tests/CanvasDataTests/ConversationWriteTests.swift
git commit -m "feat(data): conversation write methods (mark-read, reply reconcile, compose) + optimistic repo helpers"
```

---

### Task 8: Inbox UI components (`CanvasUI`)

**Files:**
- Create: `Sources/CanvasUI/InboxComponents.swift`

**Interfaces:**
- Produces (all value-driven, no store/session deps):
  - `ConversationRow(subject:contextName:snippet:date:isUnread:isSelected:onTap:)`
  - `MessageBubble(authorName:body:date:isMine:isPending:isDemo:)`
  - `ComposeSheet(recipients:[(id:Int,name:String)], onSend:(_ recipientIds:[Int],_ subject:String,_ body:String)->Void, onCancel:()->Void)`
  - `ReplyComposer(text:Binding<String>, isSending:Bool, onSend:()->Void)`
- Consumes: `RichTextView` (Phase 1b), design tokens.

- [ ] **Step 1: Write the components** (no unit test — `CanvasUI` is build- + demo-verified per Global Constraints)

`Sources/CanvasUI/InboxComponents.swift`:

```swift
import SwiftUI
import CanvasCore

public struct ConversationRow: View {
    let subject: String
    let contextName: String?
    let snippet: String?
    let date: Date?
    let isUnread: Bool
    let isSelected: Bool
    let onTap: () -> Void

    public init(subject: String, contextName: String?, snippet: String?, date: Date?,
                isUnread: Bool, isSelected: Bool, onTap: @escaping () -> Void) {
        self.subject = subject; self.contextName = contextName; self.snippet = snippet
        self.date = date; self.isUnread = isUnread; self.isSelected = isSelected; self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(isUnread ? Color.byuhRed : .clear).frame(width: 7, height: 7).padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(subject).font(.system(size: 13, weight: isUnread ? .semibold : .regular))
                            .foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Spacer()
                        if let date {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                        }
                    }
                    if let contextName {
                        Text(contextName).font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                    }
                    if let snippet {
                        Text(snippet).font(.system(size: 11)).foregroundStyle(Color.inkSecondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.inkPrimary.opacity(0.06) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

public struct MessageBubble: View {
    let authorName: String
    let body: String
    let date: Date?
    let isMine: Bool
    let isPending: Bool
    let isDemo: Bool

    public init(authorName: String, body: String, date: Date?, isMine: Bool, isPending: Bool, isDemo: Bool) {
        self.authorName = authorName; self.body = body; self.date = date
        self.isMine = isMine; self.isPending = isPending; self.isDemo = isDemo
    }

    public var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(authorName).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.inkSecondary)
                    if let date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 9)).foregroundStyle(Color.inkTertiary)
                    }
                    if isPending {
                        Text("sending…").font(.system(size: 9)).foregroundStyle(Color.inkTertiary)
                    }
                    if isDemo {
                        Text("Demo").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.onAccent)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.inkTertiary, in: Capsule())
                    }
                }
                RichTextView(html: body)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(isMine ? Color.byuhRed.opacity(0.12) : Color.inkPrimary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 10))
                    .opacity(isPending ? 0.6 : 1)
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}

public struct ReplyComposer: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    public init(text: Binding<String>, isSending: Bool, onSend: @escaping () -> Void) {
        self._text = text; self.isSending = isSending; self.onSend = onSend
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Reply…", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...5)
            Button(action: onSend) {
                if isSending { ProgressView().controlSize(.small) }
                else { Image(systemName: "paperplane.fill") }
            }
            .buttonStyle(.borderedProminent).tint(.byuhRed)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(10)
        .background(Color.canvasBG)
    }
}

public struct ComposeSheet: View {
    let recipients: [(id: Int, name: String)]
    let onSend: (_ recipientIds: [Int], _ subject: String, _ body: String) -> Void
    let onCancel: () -> Void

    @State private var selectedRecipientId: Int?
    @State private var subject = ""
    @State private var body = ""

    public init(recipients: [(id: Int, name: String)],
                onSend: @escaping (_ recipientIds: [Int], _ subject: String, _ body: String) -> Void,
                onCancel: @escaping () -> Void) {
        self.recipients = recipients; self.onSend = onSend; self.onCancel = onCancel
    }

    private var canSend: Bool {
        selectedRecipientId != nil && !subject.trimmingCharacters(in: .whitespaces).isEmpty
            && !body.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Message").font(.headline)
            Picker("To", selection: $selectedRecipientId) {
                Text("Select…").tag(Int?.none)
                ForEach(recipients, id: \.id) { r in Text(r.name).tag(Int?.some(r.id)) }
            }
            TextField("Subject", text: $subject).textFieldStyle(.roundedBorder)
            TextEditor(text: $body).frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.canvasHairline))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Send") {
                    if let id = selectedRecipientId { onSend([id], subject, body) }
                }
                .buttonStyle(.borderedProminent).tint(.byuhRed).disabled(!canSend)
            }
        }
        .padding(20).frame(width: 420)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/CanvasUI/InboxComponents.swift
git commit -m "feat(ui): inbox components — ConversationRow, MessageBubble, ReplyComposer, ComposeSheet"
```

---

### Task 9: Inbox view-model + view, wired into the window (`CanvasApp`)

**Files:**
- Create: `CanvasApp/ViewModels/InboxViewModel.swift`
- Create: `CanvasApp/Views/Window/InboxView.swift`
- Modify: `CanvasApp/App/AppSession.swift`
- Modify: `CanvasApp/Views/Window/MainWindowView.swift`

**Interfaces:**
- Consumes: repository reads (Task 3), write methods (Task 7), `Router.selectedConversationId` (exists), `InboxComponents` (Task 8).
- Produces: `InboxViewModel`, `InboxView`; `AppSession` write wrappers `markConversationRead(_:)`, `sendReply(conversationId:body:)`, `compose(recipientIds:subject:body:) -> Int`; sidebar unread badge.

- [ ] **Step 1: Add `AppSession` write wrappers**

In `AppSession.swift` (after `refresh(_:force:)`), mirroring its error-return idiom:

```swift
    @discardableResult
    func markConversationRead(_ id: Int) async -> String? {
        do { try await syncEngine.markConversationRead(id); return nil }
        catch { return String(describing: error) }
    }

    @discardableResult
    func sendReply(conversationId: Int, body: String) async -> String? {
        do { try await syncEngine.sendReply(conversationId: conversationId, body: body); return nil }
        catch { return String(describing: error) }
    }

    func compose(recipientIds: [Int], subject: String, body: String) async -> Result<Int, String> {
        do { return .success(try await syncEngine.compose(recipientIds: recipientIds, subject: subject, body: body)) }
        catch { return .failure(String(describing: error)) }
    }
```

- [ ] **Step 2: Create `InboxViewModel`**

`CanvasApp/ViewModels/InboxViewModel.swift`:

```swift
import Foundation
import CanvasCore
import CanvasData

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var conversations: [CachedConversation] = []
    @Published var messages: [CachedMessage] = []
    @Published var selectedId: Int?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    @Published var replyText = ""

    var selected: CachedConversation? { selectedId.flatMap { id in conversations.first { $0.id == id } } }

    func load(session: AppSession, force: Bool = false) async {
        readList(session)
        guard session.hasCredentials else { return }
        isLoading = conversations.isEmpty
        error = await session.refresh(.inbox, force: force)
        readList(session)
        isLoading = false
    }

    func openThread(_ id: Int, session: AppSession) async {
        selectedId = id
        readThread(session)
        _ = await session.refresh(.conversation(id))
        readThread(session)
        // Opening an unread thread marks it read (optimistic + round-trip).
        if selected?.workflowState == "unread" {
            _ = await session.markConversationRead(id)
            readList(session)
        }
    }

    func sendReply(session: AppSession) async {
        guard let id = selectedId else { return }
        let body = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSending = true; error = nil
        let authorName = session.isDemo ? "Demo Student" : "Me"
        try? session.repository.insertPendingMessage(conversationId: id, body: body,
                                                     authorId: MockData.studentUserId, authorName: authorName)
        readThread(session)
        replyText = ""
        if let failure = await session.sendReply(conversationId: id, body: body) {
            error = failure
            try? session.repository.removePendingMessages(conversationId: id)
            replyText = body   // restore draft (spec §5.2)
        }
        readThread(session)
        isSending = false
    }

    func compose(recipientIds: [Int], subject: String, body: String, session: AppSession) async {
        switch await session.compose(recipientIds: recipientIds, subject: subject, body: body) {
        case .success(let id):
            readList(session); await openThread(id, session: session)
        case .failure(let message):
            error = message
        }
    }

    private func readList(_ session: AppSession) {
        conversations = (try? session.repository.conversations(scope: .inbox)) ?? []
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "conversations", scopeId: "inbox")
    }

    private func readThread(_ session: AppSession) {
        guard let id = selectedId else { messages = []; return }
        messages = (try? session.repository.messages(conversationId: id)) ?? []
    }
}
```

- [ ] **Step 3: Create `InboxView`**

`CanvasApp/Views/Window/InboxView.swift`:

```swift
import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct InboxView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @StateObject private var vm = InboxViewModel()
    @State private var showCompose = false

    var body: some View {
        HStack(spacing: 0) {
            listColumn.frame(width: 300)
            Divider()
            threadColumn.frame(maxWidth: .infinity)
        }
        .background(Color.canvasBG)
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem {
                Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }
                    .help("New Message").accessibilityLabel("New Message")
                    .disabled(!session.hasCredentials)
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeSheet(
                recipients: recipients,
                onSend: { ids, subject, body in
                    showCompose = false
                    Task { await vm.compose(recipientIds: ids, subject: subject, body: body, session: session) }
                },
                onCancel: { showCompose = false })
        }
        .task { await vm.load(session: session) }
        // Deep link: a notification tap / dashboard reveal sets router.selectedConversationId.
        .task(id: router.selectedConversationId) {
            if let id = router.selectedConversationId { await vm.openThread(id, session: session) }
        }
    }

    /// Recipient picker seeded from cached course participants (spec §5.2). Falls back to demo teacher.
    private var recipients: [(id: Int, name: String)] {
        var seen = Set<Int>(); var out: [(id: Int, name: String)] = []
        for convo in vm.conversations {
            for p in convo.participants where p.id != MockData.studentUserId && seen.insert(p.id).inserted {
                out.append((id: p.id, name: p.name))
            }
        }
        return out.isEmpty ? [(id: MockData.teacherUserId, name: "Instructor")] : out
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            if vm.conversations.isEmpty && vm.isLoading {
                SkeletonList()
            } else if vm.conversations.isEmpty {
                ContentUnavailableView("No Conversations", systemImage: "tray",
                                       description: Text("Your Canvas inbox is empty."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.conversations, id: \.id) { c in
                            ConversationRow(subject: c.subject ?? "(no subject)", contextName: c.contextName,
                                            snippet: c.lastMessageSnippet, date: c.lastMessageAt,
                                            isUnread: c.workflowState == "unread", isSelected: vm.selectedId == c.id,
                                            onTap: { Task { await vm.openThread(c.id, session: session) } })
                        }
                    }
                }
            }
            StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var threadColumn: some View {
        if let convo = vm.selected {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(convo.subject ?? "(no subject)").font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.inkPrimary)
                        ForEach(vm.messages, id: \.id) { m in
                            MessageBubble(authorName: m.authorName ?? "Unknown", body: m.body ?? "",
                                          date: m.createdAt, isMine: m.authorId == MockData.studentUserId,
                                          isPending: m.pending, isDemo: session.isDemo && m.pending)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(20)
                }
                if let error = vm.error {
                    Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal, 10)
                }
                ReplyComposer(text: $vm.replyText, isSending: vm.isSending,
                              onSend: { Task { await vm.sendReply(session: session) } })
                    .disabled(!session.hasCredentials)
            }
        } else {
            ContentUnavailableView("Select a Conversation", systemImage: "bubble.left.and.bubble.right",
                                   description: Text("Pick a thread to read and reply."))
        }
    }
}
```

- [ ] **Step 4: Wire into `MainWindowView`**

Replace the `.inbox` detail arm (`MainWindowView.swift:80`):

```swift
            case .inbox:     InboxView()
```

Add an unread badge to the sidebar Inbox row (replace the plain `Label("Inbox", …)`):

```swift
                    Label("Inbox", systemImage: "tray").tag(SidebarItem.inbox)
                        .badge(inboxUnread)
```

and add to `MainWindowBody`:

```swift
    private var inboxUnread: Int { (try? session.repository.unseenConversationCount()) ?? 0 }
```

- [ ] **Step 5: Verify build + demo walkthrough**

Run: `swift build`
Then run the app with `CANVAS_TOKEN=DEMO` (use the `run` skill): open the window → Inbox → confirm 2 threads, open the unread one (dot clears), reply (bubble appears, "Demo" badge, reconciles), compose a new message (lands as a thread).

- [ ] **Step 6: Commit**

```bash
git add CanvasApp/ViewModels/InboxViewModel.swift CanvasApp/Views/Window/InboxView.swift CanvasApp/App/AppSession.swift CanvasApp/Views/Window/MainWindowView.swift
git commit -m "feat(app): Inbox view — list/thread/compose/reply/mark-read, sidebar unread badge"
```

---

# GROUP B — DISCUSSIONS (read-only)

### Task 10: Discussion decode models + tree flatten (`CanvasCore`)

**Files:**
- Create: `Sources/CanvasCore/DiscussionModels.swift`
- Test: `Tests/CanvasCoreTests/DiscussionModelsTests.swift`

**Interfaces:**
- Produces: `DiscussionTopic`, `DiscussionView`, `DiscussionParticipant`, `DiscussionEntryNode`, `FlatDiscussionEntry`, `flattenDiscussion(_ view: DiscussionView) -> [FlatDiscussionEntry]`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CanvasCore

final class DiscussionModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }

    func testTopicDecodes() throws {
        let json = Data(#"""
        {"id": 30, "title": "Week 1", "message": "<p>Intro</p>", "posted_at": "2026-08-01T00:00:00Z",
         "discussion_subentry_count": 4, "html_url": "https://x/courses/1/discussion_topics/30"}
        """#.utf8)
        let t = try decoder().decode(DiscussionTopic.self, from: json)
        XCTAssertEqual(t.id, 30)
        XCTAssertEqual(t.discussionSubentryCount, 4)
        XCTAssertEqual(t.htmlUrl, "https://x/courses/1/discussion_topics/30")
    }

    func testViewFlattensPreOrderWithDepth() throws {
        let json = Data(#"""
        {"participants": [{"id": 1, "display_name": "Dr. Reed"}, {"id": 2, "display_name": "Ana"}],
         "view": [
           {"id": 100, "user_id": 1, "parent_id": null, "message": "root", "created_at": "2026-08-01T00:00:00Z",
            "replies": [
              {"id": 101, "user_id": 2, "parent_id": 100, "message": "child", "created_at": "2026-08-01T01:00:00Z",
               "replies": [
                 {"id": 102, "user_id": 1, "parent_id": 101, "message": "grandchild", "created_at": "2026-08-01T02:00:00Z"}
               ]}
            ]},
           {"id": 200, "user_id": 2, "parent_id": null, "message": "second root", "created_at": "2026-08-01T03:00:00Z"}
         ]}
        """#.utf8)
        let view = try decoder().decode(DiscussionView.self, from: json)
        let flat = flattenDiscussion(view)
        XCTAssertEqual(flat.map(\.id), [100, 101, 102, 200])       // pre-order
        XCTAssertEqual(flat.map(\.depth), [0, 1, 2, 0])
        XCTAssertEqual(flat.map(\.sortIndex), [0, 1, 2, 3])
        XCTAssertEqual(flat[1].authorName, "Ana")                   // resolved from participants
        XCTAssertEqual(flat[2].parentId, 101)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiscussionModelsTests`
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement the models + flatten**

`Sources/CanvasCore/DiscussionModels.swift`:

```swift
import Foundation

public struct DiscussionTopic: Codable, Sendable, Equatable {
    public let id: Int
    public let title: String
    public let message: String?
    public let postedAt: String?
    public let discussionSubentryCount: Int?
    public let htmlUrl: String?
    public init(id: Int, title: String, message: String?, postedAt: String?,
                discussionSubentryCount: Int?, htmlUrl: String?) {
        self.id = id; self.title = title; self.message = message; self.postedAt = postedAt
        self.discussionSubentryCount = discussionSubentryCount; self.htmlUrl = htmlUrl
    }
}

public struct DiscussionParticipant: Codable, Sendable, Equatable {
    public let id: Int
    public let displayName: String?
    public init(id: Int, displayName: String?) { self.id = id; self.displayName = displayName }
}

/// A node in Canvas's `/view` reply tree. A struct holding `[DiscussionEntryNode]` is legal —
/// Array provides the heap indirection the recursion needs.
public struct DiscussionEntryNode: Codable, Sendable, Equatable {
    public let id: Int
    public let userId: Int?
    public let parentId: Int?
    public let message: String?
    public let createdAt: String?
    public let replies: [DiscussionEntryNode]?
    public init(id: Int, userId: Int?, parentId: Int?, message: String?, createdAt: String?,
                replies: [DiscussionEntryNode]?) {
        self.id = id; self.userId = userId; self.parentId = parentId
        self.message = message; self.createdAt = createdAt; self.replies = replies
    }
}

public struct DiscussionView: Codable, Sendable, Equatable {
    public let view: [DiscussionEntryNode]?
    public let participants: [DiscussionParticipant]?
    public init(view: [DiscussionEntryNode]?, participants: [DiscussionParticipant]?) {
        self.view = view; self.participants = participants
    }
}

public struct FlatDiscussionEntry: Equatable, Sendable {
    public let id: Int
    public let parentId: Int?
    public let depth: Int
    public let authorName: String
    public let message: String?
    public let createdAt: String?
    public let sortIndex: Int
}

/// Pre-order depth-first flatten of the reply tree, resolving author names from participants.
public func flattenDiscussion(_ view: DiscussionView) -> [FlatDiscussionEntry] {
    let names = Dictionary(uniqueKeysWithValues: (view.participants ?? []).map { ($0.id, $0.displayName ?? "Unknown") })
    var out: [FlatDiscussionEntry] = []
    var index = 0
    func walk(_ nodes: [DiscussionEntryNode], depth: Int) {
        for node in nodes {
            out.append(FlatDiscussionEntry(
                id: node.id, parentId: node.parentId, depth: depth,
                authorName: node.userId.flatMap { names[$0] } ?? "Unknown",
                message: node.message, createdAt: node.createdAt, sortIndex: index))
            index += 1
            if let replies = node.replies, !replies.isEmpty { walk(replies, depth: depth + 1) }
        }
    }
    walk(view.view ?? [], depth: 0)
    return out
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DiscussionModelsTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasCore/DiscussionModels.swift Tests/CanvasCoreTests/DiscussionModelsTests.swift
git commit -m "feat(core): discussion topic/view decode + pre-order tree flatten"
```

---

### Task 11: Discussion API methods + demo store (`CanvasCore`)

**Files:**
- Modify: `Sources/CanvasCore/APIClient.swift`
- Modify: `Sources/CanvasCore/MockData.swift`
- Test: `Tests/CanvasCoreTests/DiscussionAPITests.swift`

**Interfaces:**
- Produces on `APIClient`: `func discussionTopics(courseId: Int) async throws -> [DiscussionTopic]`, `func discussionView(courseId: Int, topicId: Int) async throws -> DiscussionView`.
- Produces on `MockData`: `static let discussionTopics: [Int: [DiscussionTopic]]`, `static let discussionViews: [Int: DiscussionView]`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CanvasCore

final class DiscussionAPITests: XCTestCase {
    func testDemoTopicsAndView() async throws {
        let demo = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let topics = try await demo.discussionTopics(courseId: MockData.csCourseId)
        XCTAssertFalse(topics.isEmpty)
        let view = try await demo.discussionView(courseId: MockData.csCourseId, topicId: topics.first!.id)
        XCTAssertNotNil(view.view)
    }

    func testTopicsRequestPathAndOnlyAnnouncementsAbsent() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordingStub.self]
        RecordingStub.reset(); RecordingStub.body = Data("[]".utf8)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "T"),
                               session: URLSession(configuration: config))
        _ = try await client.discussionTopics(courseId: 42)
        let url = RecordingStub.lastURL!.absoluteString
        XCTAssertTrue(url.contains("/courses/42/discussion_topics"))
        XCTAssertFalse(url.contains("only_announcements"))   // discussions, not announcements
    }
}
```

(Reuses `RecordingStub` from `ConversationAPITests`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiscussionAPITests`
Expected: FAIL — methods undefined.

- [ ] **Step 3: Add demo data to `MockData.swift`**

```swift
    // MARK: - Phase 2 demo store (discussions)

    public static let discussionTopics: [Int: [DiscussionTopic]] = [
        csCourseId: [
            DiscussionTopic(id: 3001, title: "Week 1 — Introductions",
                            message: "<p>Post a short intro about yourself.</p>",
                            postedAt: "2026-08-01T00:00:00Z", discussionSubentryCount: 3,
                            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/discussion_topics/3001"),
            DiscussionTopic(id: 3002, title: "Project ideas",
                            message: "<p>Share your project proposal here.</p>",
                            postedAt: "2026-08-05T00:00:00Z", discussionSubentryCount: 0,
                            htmlUrl: "https://byuh.instructure.com/courses/\(csCourseId)/discussion_topics/3002"),
        ],
    ]

    public static let discussionViews: [Int: DiscussionView] = [
        3001: DiscussionView(
            view: [
                DiscussionEntryNode(id: 4001, userId: teacherUserId, parentId: nil,
                                    message: "<p>Welcome! Tell us your major.</p>", createdAt: "2026-08-01T01:00:00Z",
                                    replies: [
                                        DiscussionEntryNode(id: 4002, userId: studentUserId, parentId: 4001,
                                                            message: "<p>CS major, second year.</p>",
                                                            createdAt: "2026-08-01T02:00:00Z", replies: nil),
                                    ]),
                DiscussionEntryNode(id: 4003, userId: studentUserId, parentId: nil,
                                    message: "<p>Excited for this course.</p>", createdAt: "2026-08-01T03:00:00Z",
                                    replies: nil),
            ],
            participants: [
                DiscussionParticipant(id: teacherUserId, displayName: "Prof. Lang"),
                DiscussionParticipant(id: studentUserId, displayName: "Demo Student"),
            ]),
        3002: DiscussionView(view: [], participants: []),
    ]
```

- [ ] **Step 4: Add API methods to `APIClient.swift`**

```swift
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter DiscussionAPITests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/CanvasCore/APIClient.swift Sources/CanvasCore/MockData.swift Tests/CanvasCoreTests/DiscussionAPITests.swift
git commit -m "feat(core): discussion topics + /view API methods and demo store"
```

---

### Task 12: Cached discussion models + schema + repository + sync (`CanvasData`)

**Files:**
- Create: `Sources/CanvasData/Models/DiscussionModels.swift`
- Modify: `Sources/CanvasData/CanvasStore.swift`
- Modify: `Sources/CanvasData/CanvasRepository.swift`
- Modify: `Sources/CanvasData/SyncEngine.swift`
- Test: `Tests/CanvasDataTests/DiscussionSyncTests.swift`

**Interfaces:**
- Produces: `@Model CachedDiscussionTopic`, `@Model CachedDiscussionEntry`; repository `discussionTopics(courseId:)`, `discussionEntries(topicId:)`; `SyncEngine` topics-in-`syncCourse` + `syncDiscussionEntries` (wired into `perform` in Task 4).
- Consumes: `flattenDiscussion` (Task 10), `discussionTopics`/`discussionView` (Task 11).

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import SwiftData
import CanvasCore
@testable import CanvasData

final class DiscussionSyncTests: XCTestCase {
    private func makeEngine() async throws -> (SyncEngine, ModelContainer) {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        await engine.configure(client: APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO")))
        return (engine, container)
    }

    func testCourseSyncPopulatesDiscussionTopics() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.course(MockData.csCourseId))
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).discussionTopics(courseId: MockData.csCourseId).count
        }
        XCTAssertEqual(count, 2)
    }

    func testDiscussionEntriesSyncFlattensTree() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.course(MockData.csCourseId))
        try await engine.refresh(.discussion(courseId: MockData.csCourseId, topicId: 3001))
        let entries = try await MainActor.run {
            try CanvasRepository(modelContainer: container).discussionEntries(topicId: 3001)
        }
        XCTAssertEqual(entries.map(\.id), [4001, 4002, 4003])   // pre-order
        XCTAssertEqual(entries.map(\.depth), [0, 1, 0])
    }

    func testDiscussionEntriesResyncIsIdempotent() async throws {
        let (engine, container) = try await makeEngine()
        try await engine.refresh(.course(MockData.csCourseId))
        try await engine.refresh(.discussion(courseId: MockData.csCourseId, topicId: 3001))
        try await engine.refresh(.discussion(courseId: MockData.csCourseId, topicId: 3001), force: true)
        let count = try await MainActor.run {
            try CanvasRepository(modelContainer: container).discussionEntries(topicId: 3001).count
        }
        XCTAssertEqual(count, 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiscussionSyncTests`
Expected: FAIL — models/methods undefined.

- [ ] **Step 3: Create the models**

`Sources/CanvasData/Models/DiscussionModels.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class CachedDiscussionTopic {
    @Attribute(.unique) public var id: Int
    public var courseId: Int
    public var title: String
    public var message: String?
    public var postedAt: Date?
    public var replyCount: Int
    public var htmlURL: String?
    public var removedAt: Date?

    public init(id: Int, courseId: Int, title: String, message: String?, postedAt: Date?,
                replyCount: Int, htmlURL: String?, removedAt: Date? = nil) {
        self.id = id; self.courseId = courseId; self.title = title; self.message = message
        self.postedAt = postedAt; self.replyCount = replyCount; self.htmlURL = htmlURL; self.removedAt = removedAt
    }
}

@Model
public final class CachedDiscussionEntry {
    @Attribute(.unique) public var id: Int
    public var topicId: Int
    public var parentId: Int?
    public var depth: Int
    public var sortIndex: Int
    public var authorName: String?
    public var message: String?
    public var createdAt: Date?

    public init(id: Int, topicId: Int, parentId: Int?, depth: Int, sortIndex: Int,
                authorName: String?, message: String?, createdAt: Date?) {
        self.id = id; self.topicId = topicId; self.parentId = parentId; self.depth = depth
        self.sortIndex = sortIndex; self.authorName = authorName; self.message = message; self.createdAt = createdAt
    }
}
```

- [ ] **Step 4: Schema + repository + clearStore**

In `CanvasStore.swift`:

```swift
        CachedConversation.self, CachedMessage.self,
        CachedDiscussionTopic.self, CachedDiscussionEntry.self,
```

In `CanvasRepository.swift`:

```swift
    public func discussionTopics(courseId: Int) throws -> [CachedDiscussionTopic] {
        let predicate = #Predicate<CachedDiscussionTopic> { $0.courseId == courseId }
        return try context.fetch(FetchDescriptor(predicate: predicate))
            .filter { $0.removedAt == nil }
            .sorted { ($0.postedAt ?? .distantPast) > ($1.postedAt ?? .distantPast) }
    }

    public func discussionEntries(topicId: Int) throws -> [CachedDiscussionEntry] {
        let predicate = #Predicate<CachedDiscussionEntry> { $0.topicId == topicId }
        return try context.fetch(FetchDescriptor(predicate: predicate)).sorted { $0.sortIndex < $1.sortIndex }
    }
```

Extend `clearStore()`:

```swift
        try context.delete(model: CachedDiscussionTopic.self)
        try context.delete(model: CachedDiscussionEntry.self)
```

- [ ] **Step 5: Add discussion-topics fetch to `syncCourse` + `syncDiscussionEntries`**

In `SyncEngine.syncCourse`, add a fourth need + `async let` alongside groups/subs/announcements:

```swift
        let needDiscussions = force || !isFresh(.discussionTopics, scope: "\(courseId)", now: now)
```

Add to the `guard … else { return }`:

```swift
        guard needAssignments || needSubmissions || needAnnouncements || needDiscussions else { return }
```

Add the fetch:

```swift
        async let discussionsFetch: [DiscussionTopic] = {
            guard needDiscussions else { return [] }
            return try await fetchWithRetry { try await client.discussionTopics(courseId: courseId) }
        }()
```

Add `var discussionsSucceeded = !needDiscussions` next to the other success flags, and after the announcements block:

```swift
        if needDiscussions {
            do {
                let topics = try await discussionsFetch
                upsertDiscussionTopics(topics, courseId: courseId, now: now)
                touch(.discussionTopics, scope: "\(courseId)", error: nil, at: now)
                discussionsSucceeded = true
            } catch {
                if firstError == nil { firstError = error }
                touch(.discussionTopics, scope: "\(courseId)", error: String(describing: error), at: now)
            }
        }
```

Update the final all-failed throw guard to include the new flag:

```swift
        if let firstError, !groupsSucceeded, !submissionsSucceeded, !announcementsSucceeded, !discussionsSucceeded {
            throw firstError
        }
```

Add the upsert helpers + entries sync:

```swift
    private func upsertDiscussionTopics(_ items: [DiscussionTopic], courseId: Int, now: Date) {
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedDiscussionTopic>(
                predicate: #Predicate<CachedDiscussionTopic> { $0.courseId == courseId }))) ?? [])
                .map { ($0.id, $0) })
        let fetchedIds = Set(items.map(\.id))
        for t in items {
            let postedAt = CanvasDate.parse(t.postedAt)
            if let row = existing[t.id] {
                row.title = t.title; row.message = t.message; row.postedAt = postedAt
                row.replyCount = t.discussionSubentryCount ?? 0; row.htmlURL = t.htmlUrl; row.removedAt = nil
            } else {
                modelContext.insert(CachedDiscussionTopic(
                    id: t.id, courseId: courseId, title: t.title, message: t.message, postedAt: postedAt,
                    replyCount: t.discussionSubentryCount ?? 0, htmlURL: t.htmlUrl))
            }
        }
        for (id, row) in existing where !fetchedIds.contains(id) && row.removedAt == nil { row.removedAt = now }
    }

    // MARK: - .discussion

    private func syncDiscussionEntries(courseId: Int, topicId: Int, client: APIClient, force: Bool) async throws {
        let now = Date()
        guard force || !isFresh(.discussionEntries, scope: "\(topicId)", now: now) else { return }
        let view = try await fetchWithRetry { try await client.discussionView(courseId: courseId, topicId: topicId) }
        let flat = flattenDiscussion(view)
        let existing = Dictionary(uniqueKeysWithValues:
            ((try? modelContext.fetch(FetchDescriptor<CachedDiscussionEntry>(
                predicate: #Predicate<CachedDiscussionEntry> { $0.topicId == topicId }))) ?? [])
                .map { ($0.id, $0) })
        let fetchedIds = Set(flat.map(\.id))
        for e in flat {
            let created = CanvasDate.parse(e.createdAt)
            if let row = existing[e.id] {
                row.parentId = e.parentId; row.depth = e.depth; row.sortIndex = e.sortIndex
                row.authorName = e.authorName; row.message = e.message; row.createdAt = created
            } else {
                modelContext.insert(CachedDiscussionEntry(
                    id: e.id, topicId: topicId, parentId: e.parentId, depth: e.depth, sortIndex: e.sortIndex,
                    authorName: e.authorName, message: e.message, createdAt: created))
            }
        }
        // Hard-delete entries removed upstream (a deleted reply should vanish; no history value here).
        for (id, row) in existing where !fetchedIds.contains(id) { modelContext.delete(row) }
        touch(.discussionEntries, scope: "\(topicId)", error: nil, at: now)
        try modelContext.save()
    }
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `swift test --filter DiscussionSyncTests`
Expected: PASS (all 3).

- [ ] **Step 7: Commit**

```bash
git add Sources/CanvasData/Models/DiscussionModels.swift Sources/CanvasData/CanvasStore.swift Sources/CanvasData/CanvasRepository.swift Sources/CanvasData/SyncEngine.swift Tests/CanvasDataTests/DiscussionSyncTests.swift
git commit -m "feat(data): discussion topics in course sync + lazy .discussion entry sync + repository"
```

---

### Task 13: Discussion UI + tab wiring (`CanvasUI` + `CanvasApp`)

**Files:**
- Create: `Sources/CanvasUI/DiscussionComponents.swift`
- Create: `CanvasApp/ViewModels/DiscussionsViewModel.swift`
- Create: `CanvasApp/Views/Window/DiscussionsTabView.swift`
- Modify: `CanvasApp/Views/Window/CourseWorkspaceView.swift`

**Interfaces:**
- Produces: `DiscussionTopicRow`, `DiscussionEntryView` (`CanvasUI`); `DiscussionsViewModel`, `DiscussionsTabView` (`CanvasApp`); `.discussions` tab renders the real view.
- Consumes: repository reads (Task 12), `RichTextView`, `StalenessLabel`, `SkeletonList`.

- [ ] **Step 1: Create `DiscussionComponents.swift`**

```swift
import SwiftUI
import CanvasCore

public struct DiscussionTopicRow: View {
    let title: String
    let replyCount: Int
    let postedAt: Date?
    let isSelected: Bool
    let onTap: () -> Void

    public init(title: String, replyCount: Int, postedAt: Date?, isSelected: Bool, onTap: @escaping () -> Void) {
        self.title = title; self.replyCount = replyCount; self.postedAt = postedAt
        self.isSelected = isSelected; self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.inkPrimary).lineLimit(2)
                HStack(spacing: 6) {
                    Label("\(replyCount)", systemImage: "bubble.left")
                        .font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                    if let postedAt {
                        Text(postedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.inkPrimary.opacity(0.06) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

public struct DiscussionEntryView: View {
    let authorName: String
    let message: String
    let date: Date?
    let depth: Int

    public init(authorName: String, message: String, date: Date?, depth: Int) {
        self.authorName = authorName; self.message = message; self.date = date; self.depth = depth
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(authorName).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.inkSecondary)
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 9)).foregroundStyle(Color.inkTertiary)
                }
            }
            RichTextView(html: message)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(depth) * 20)   // indent by depth (spec §5.3)
        .overlay(alignment: .leading) {
            if depth > 0 {
                Rectangle().fill(Color.canvasHairline).frame(width: 1)
                    .padding(.leading, CGFloat(depth) * 20 - 10)
            }
        }
    }
}
```

- [ ] **Step 2: Create `DiscussionsViewModel.swift`**

```swift
import Foundation
import CanvasCore
import CanvasData

@MainActor
final class DiscussionsViewModel: ObservableObject {
    let courseId: Int
    @Published var topics: [CachedDiscussionTopic] = []
    @Published var entries: [CachedDiscussionEntry] = []
    @Published var selectedTopicId: Int?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?

    init(courseId: Int) { self.courseId = courseId }

    var selectedTopic: CachedDiscussionTopic? {
        selectedTopicId.flatMap { id in topics.first { $0.id == id } }
    }

    func load(session: AppSession, force: Bool = false) async {
        readTopics(session)
        guard session.hasCredentials else { return }
        isLoading = topics.isEmpty
        error = await session.refresh(.course(courseId), force: force)
        readTopics(session)
        isLoading = false
    }

    func openTopic(_ id: Int, session: AppSession) async {
        selectedTopicId = id
        readEntries(session)
        _ = await session.refresh(.discussion(courseId: courseId, topicId: id))
        readEntries(session)
    }

    private func readTopics(_ session: AppSession) {
        topics = (try? session.repository.discussionTopics(courseId: courseId)) ?? []
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "discussionTopics", scopeId: "\(courseId)")
    }

    private func readEntries(_ session: AppSession) {
        guard let id = selectedTopicId else { entries = []; return }
        entries = (try? session.repository.discussionEntries(topicId: id)) ?? []
    }
}
```

- [ ] **Step 3: Create `DiscussionsTabView.swift`**

```swift
import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct DiscussionsTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @StateObject private var vm: DiscussionsViewModel

    init(courseId: Int) {
        self.courseId = courseId
        _vm = StateObject(wrappedValue: DiscussionsViewModel(courseId: courseId))
    }

    var body: some View {
        Group {
            if !vm.topics.isEmpty {
                HStack(spacing: 0) {
                    listColumn.frame(width: 300)
                    Divider()
                    detailColumn.frame(maxWidth: .infinity)
                }
            } else if vm.isLoading {
                SkeletonList()
            } else if let error = vm.error {
                ContentUnavailableView { Label("Couldn't Load Discussions", systemImage: "exclamationmark.triangle") }
                    description: { Text(error) }
            } else {
                ContentUnavailableView("No Discussions", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("This course has no discussion topics."))
            }
        }
        .background(Color.canvasBG)
        .task(id: courseId) { await vm.load(session: session) }
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.topics, id: \.id) { t in
                        DiscussionTopicRow(title: t.title, replyCount: t.replyCount, postedAt: t.postedAt,
                                           isSelected: vm.selectedTopicId == t.id,
                                           onTap: { Task { await vm.openTopic(t.id, session: session) } })
                    }
                }
            }
            StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let topic = vm.selectedTopic {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(topic.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Spacer()
                        if let urlString = topic.htmlURL, let url = URL(string: urlString) {
                            Link(destination: url) { Label("Reply in Canvas", systemImage: "arrowshape.turn.up.left") }
                                .font(.system(size: 11))
                        }
                    }
                    RichTextView(html: topic.message ?? "")
                    Divider()
                    ForEach(vm.entries, id: \.id) { e in
                        DiscussionEntryView(authorName: e.authorName ?? "Unknown", message: e.message ?? "",
                                            date: e.createdAt, depth: e.depth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
        } else {
            ContentUnavailableView("Select a Topic", systemImage: "bubble.left.and.bubble.right",
                                   description: Text("Pick a discussion to read the thread."))
        }
    }
}
```

- [ ] **Step 4: Wire the tab in `CourseWorkspaceView.swift`**

Replace the `.discussions` fall-through. Change the trailing `else` block to branch discussions first:

```swift
            } else if router.courseTab == .syllabus {
                SyllabusTabView(courseId: courseId)
            } else if router.courseTab == .discussions {
                DiscussionsTabView(courseId: courseId).id(courseId)
            } else {
                // Modules/Files only — Phase 4.
                ComingSoonView(title: router.courseTab.rawValue.capitalized, phase: "a later phase")
            }
```

- [ ] **Step 5: Verify build + demo walkthrough**

Run: `swift build`
Then demo (`run` skill): open a course → Discussions tab → confirm 2 topics; open "Week 1 — Introductions" → see the root post, a depth-1 indented reply, a second root; "Reply in Canvas" is a link-out.

- [ ] **Step 6: Commit**

```bash
git add Sources/CanvasUI/DiscussionComponents.swift CanvasApp/ViewModels/DiscussionsViewModel.swift CanvasApp/Views/Window/DiscussionsTabView.swift CanvasApp/Views/Window/CourseWorkspaceView.swift
git commit -m "feat(app): read-only Discussions tab — topic list + indented threaded entries"
```

---

# GROUP C — NOTIFICATIONS & BACKGROUND REFRESH

### Task 14: Notification settings + pure planner (`CanvasData`)

**Files:**
- Create: `Sources/CanvasData/NotificationPlanner.swift`
- Test: `Tests/CanvasDataTests/NotificationPlannerTests.swift`

**Interfaces:**
- Produces: `NotificationSettings`, `NotificationRevealPayload`, `NotificationRequestSpec`, `enum NotificationPlanner` with `static func isInQuietHours(_:settings:calendar:) -> Bool` and `static func plan(changes:settings:now:calendar:) -> (post: [NotificationRequestSpec], suppressed: [NotificationRequestSpec])`.
- Consumes: `ChangeRecord`, `ChangeKind`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import CanvasCore
@testable import CanvasData

final class NotificationPlannerTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func at(_ hour: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: hour))! }

    private func settings(_ overrides: (inout NotificationSettings) -> Void = { _ in }) -> NotificationSettings {
        var s = NotificationSettings.defaults; overrides(&s); return s
    }
    private func record(_ kind: ChangeKind, courseId: Int = 1, title: String = "T") -> ChangeRecord {
        ChangeRecord(kind: kind, courseId: courseId, subjectId: nil, title: title, detail: nil, occurredAt: Date())
    }

    func testDisabledCategoryIsDropped() {
        let s = settings { $0.newGrades = false }
        let result = NotificationPlanner.plan(changes: [record(.newGrade)], settings: s, now: at(12), calendar: cal)
        XCTAssertTrue(result.post.isEmpty)
        XCTAssertTrue(result.suppressed.isEmpty)   // disabled ≠ suppressed; it never planned
    }

    func testEnabledCategoryPosts() {
        let result = NotificationPlanner.plan(changes: [record(.newGrade, title: "Lab 3")],
                                              settings: settings(), now: at(12), calendar: cal)
        XCTAssertEqual(result.post.count, 1)
        XCTAssertTrue(result.post.first!.body.contains("Lab 3"))
    }

    func testCoalescesMoreThanThreeSameKindSameCourse() {
        let changes = (0..<4).map { record(.newGrade, courseId: 1, title: "A\($0)") }
        let result = NotificationPlanner.plan(changes: changes, settings: settings(), now: at(12), calendar: cal)
        XCTAssertEqual(result.post.count, 1)                       // one summary
        XCTAssertTrue(result.post.first!.body.contains("4"))       // "4 new grades…"
    }

    func testThreeOrFewerAreIndividual() {
        let changes = (0..<3).map { record(.newGrade, courseId: 1, title: "A\($0)") }
        let result = NotificationPlanner.plan(changes: changes, settings: settings(), now: at(12), calendar: cal)
        XCTAssertEqual(result.post.count, 3)
    }

    func testQuietHoursSuppressButKeepInFeed() {
        let s = settings { $0.quietHoursEnabled = true; $0.quietStartHour = 22; $0.quietEndHour = 7 }
        let result = NotificationPlanner.plan(changes: [record(.newGrade)], settings: s, now: at(23), calendar: cal)
        XCTAssertTrue(result.post.isEmpty)
        XCTAssertEqual(result.suppressed.count, 1)   // still surfaced in change feed by caller
    }

    func testQuietHoursWrapAround() {
        let s = settings { $0.quietHoursEnabled = true; $0.quietStartHour = 22; $0.quietEndHour = 7 }
        XCTAssertTrue(NotificationPlanner.isInQuietHours(at(2), settings: s, calendar: cal))   // 02:00 inside 22→7
        XCTAssertFalse(NotificationPlanner.isInQuietHours(at(12), settings: s, calendar: cal)) // noon outside
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NotificationPlannerTests`
Expected: FAIL — types undefined.

- [ ] **Step 3: Implement the planner**

`Sources/CanvasData/NotificationPlanner.swift`:

```swift
import Foundation
import CanvasCore

public struct NotificationSettings: Sendable, Equatable {
    public var newGrades: Bool
    public var newFeedback: Bool
    public var newMessages: Bool
    public var dueSoon: Bool
    public var quietHoursEnabled: Bool
    public var quietStartHour: Int   // 0–23
    public var quietEndHour: Int     // 0–23
    public var backgroundIntervalMinutes: Int   // clamped 15…240 by the store

    public init(newGrades: Bool, newFeedback: Bool, newMessages: Bool, dueSoon: Bool,
                quietHoursEnabled: Bool, quietStartHour: Int, quietEndHour: Int, backgroundIntervalMinutes: Int) {
        self.newGrades = newGrades; self.newFeedback = newFeedback; self.newMessages = newMessages
        self.dueSoon = dueSoon; self.quietHoursEnabled = quietHoursEnabled
        self.quietStartHour = quietStartHour; self.quietEndHour = quietEndHour
        self.backgroundIntervalMinutes = backgroundIntervalMinutes
    }

    public static let defaults = NotificationSettings(
        newGrades: true, newFeedback: true, newMessages: false, dueSoon: false,
        quietHoursEnabled: false, quietStartHour: 22, quietEndHour: 7, backgroundIntervalMinutes: 30)

    public func enabled(for kind: ChangeKind) -> Bool {
        switch kind {
        case .newGrade, .gradeChanged: return newGrades
        case .newFeedback:             return newFeedback
        case .newMessage:              return newMessages
        case .dueSoon:                 return dueSoon
        case .newAnnouncement:         return false   // no announcement category in Phase 2 spec §6
        }
    }
}

/// Enough to route a notification tap back to a `RevealTarget` (spec §6). Encoded into the
/// UNNotificationRequest userInfo by the scheduler.
public struct NotificationRevealPayload: Sendable, Equatable, Codable {
    public let kind: String
    public let courseId: Int
    public let subjectId: Int?
    public init(kind: String, courseId: Int, subjectId: Int?) {
        self.kind = kind; self.courseId = courseId; self.subjectId = subjectId
    }
}

public struct NotificationRequestSpec: Sendable, Equatable {
    public let identifier: String
    public let title: String
    public let body: String
    public let payload: NotificationRevealPayload
}

public enum NotificationPlanner {
    public static func isInQuietHours(_ date: Date, settings: NotificationSettings,
                                      calendar: Calendar = .current) -> Bool {
        guard settings.quietHoursEnabled else { return false }
        let hour = calendar.component(.hour, from: date)
        let start = settings.quietStartHour, end = settings.quietEndHour
        if start == end { return false }
        if start < end { return hour >= start && hour < end }         // same-day window
        return hour >= start || hour < end                            // wrap-around (e.g. 22→7)
    }

    private static func label(_ kind: ChangeKind, count: Int) -> String {
        switch kind {
        case .newGrade:        return count == 1 ? "new grade" : "new grades"
        case .gradeChanged:    return count == 1 ? "grade change" : "grade changes"
        case .newFeedback:     return count == 1 ? "new comment" : "new comments"
        case .newMessage:      return count == 1 ? "new message" : "new messages"
        case .dueSoon:         return count == 1 ? "assignment due soon" : "assignments due soon"
        case .newAnnouncement: return count == 1 ? "announcement" : "announcements"
        }
    }

    /// Groups enabled changes by (kind, courseId). > 3 in a group → one summary spec; else one each.
    /// Returns `post` (fire now) and `suppressed` (in quiet hours — caller still keeps them in the feed).
    public static func plan(changes: [ChangeRecord], settings: NotificationSettings, now: Date,
                            calendar: Calendar = .current)
        -> (post: [NotificationRequestSpec], suppressed: [NotificationRequestSpec]) {
        let quiet = isInQuietHours(now, settings: settings, calendar: calendar)
        var specs: [NotificationRequestSpec] = []
        let enabled = changes.filter { $0.changeKind.map(settings.enabled(for:)) ?? false }

        // Preserve grouping order by first appearance.
        var order: [String] = []
        var groups: [String: [ChangeRecord]] = [:]
        for c in enabled {
            let key = "\(c.kind)#\(c.courseId)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(c)
        }

        for key in order {
            let group = groups[key]!
            guard let kind = group.first?.changeKind else { continue }
            if group.count > 3 {
                let spec = NotificationRequestSpec(
                    identifier: "summary-\(key)-\(Int(now.timeIntervalSince1970))",
                    title: group.first?.title ?? "Canvas",
                    body: "\(group.count) \(label(kind, count: group.count))",
                    payload: NotificationRevealPayload(kind: kind.rawValue, courseId: group.first!.courseId, subjectId: nil))
                specs.append(spec)
            } else {
                for c in group {
                    let spec = NotificationRequestSpec(
                        identifier: "change-\(c.id.uuidString)",
                        title: c.title,
                        body: [label(kind, count: 1).capitalized, c.detail].compactMap { $0 }.joined(separator: " · "),
                        payload: NotificationRevealPayload(kind: kind.rawValue, courseId: c.courseId, subjectId: c.subjectId))
                    specs.append(spec)
                }
            }
        }
        return quiet ? (post: [], suppressed: specs) : (post: specs, suppressed: [])
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter NotificationPlannerTests`
Expected: PASS (all 6).

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/NotificationPlanner.swift Tests/CanvasDataTests/NotificationPlannerTests.swift
git commit -m "feat(data): NotificationSettings + pure NotificationPlanner (categories, coalescing, quiet hours)"
```

---

### Task 15: Background-tick gate (pure) (`CanvasData`)

**Files:**
- Create: `Sources/CanvasData/BackgroundGate.swift`
- Test: `Tests/CanvasDataTests/BackgroundGateTests.swift`

**Interfaces:**
- Produces: `struct PowerState { onBattery: Bool; batteryPercent: Int }`, `func shouldRunBackgroundTick(power:displayAsleepSince:now:) -> Bool`.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import CanvasData

final class BackgroundGateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testRunsOnACPower() {
        XCTAssertTrue(shouldRunBackgroundTick(power: PowerState(onBattery: false, batteryPercent: 5),
                                              displayAsleepSince: nil, now: now))
    }
    func testSkipsOnLowBattery() {
        XCTAssertFalse(shouldRunBackgroundTick(power: PowerState(onBattery: true, batteryPercent: 15),
                                               displayAsleepSince: nil, now: now))
    }
    func testRunsOnBatteryAboveThreshold() {
        XCTAssertTrue(shouldRunBackgroundTick(power: PowerState(onBattery: true, batteryPercent: 55),
                                              displayAsleepSince: nil, now: now))
    }
    func testSkipsWhenDisplayAsleepOverAnHour() {
        XCTAssertFalse(shouldRunBackgroundTick(power: PowerState(onBattery: false, batteryPercent: 100),
                                               displayAsleepSince: now.addingTimeInterval(-3700), now: now))
    }
    func testRunsWhenDisplayAsleepBriefly() {
        XCTAssertTrue(shouldRunBackgroundTick(power: PowerState(onBattery: false, batteryPercent: 100),
                                              displayAsleepSince: now.addingTimeInterval(-600), now: now))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter BackgroundGateTests`
Expected: FAIL — undefined.

- [ ] **Step 3: Implement**

`Sources/CanvasData/BackgroundGate.swift`:

```swift
import Foundation

public struct PowerState: Sendable, Equatable {
    public let onBattery: Bool
    public let batteryPercent: Int
    public init(onBattery: Bool, batteryPercent: Int) {
        self.onBattery = onBattery; self.batteryPercent = batteryPercent
    }
}

/// Background refresh gate (spec §6): suspended on battery below 20%, and while the display
/// has been asleep more than one hour.
public func shouldRunBackgroundTick(power: PowerState, displayAsleepSince: Date?, now: Date) -> Bool {
    if power.onBattery && power.batteryPercent < 20 { return false }
    if let since = displayAsleepSince, now.timeIntervalSince(since) > 3600 { return false }
    return true
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter BackgroundGateTests`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/BackgroundGate.swift Tests/CanvasDataTests/BackgroundGateTests.swift
git commit -m "feat(data): pure background-tick gate (battery + display-asleep thresholds)"
```

---

### Task 16: NotificationScheduler (UN wrapper) (`CanvasData`)

**Files:**
- Create: `Sources/CanvasData/NotificationScheduler.swift`

**Interfaces:**
- Produces: `@MainActor final class NotificationScheduler` with `requestAuthorizationIfNeeded() async -> Bool`, `post(_ specs: [NotificationRequestSpec])`, `setBadge(_ count: Int)`.
- Consumes: `NotificationRequestSpec` (Task 14).

> Not unit-tested (wraps `UNUserNotificationCenter`, which needs a bundle); verified by demo. The pure planning it delegates to is covered in Task 14.

- [ ] **Step 1: Implement**

`Sources/CanvasData/NotificationScheduler.swift`:

```swift
import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(AppKit)
import AppKit
#endif

@MainActor
public final class NotificationScheduler {
    public static let revealUserInfoKey = "reveal"
    private var didRequestAuthorization = false

    public init() {}

    /// Lazy permission (spec §6): requested the first time any category is enabled, never at launch.
    @discardableResult
    public func requestAuthorizationIfNeeded() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            didRequestAuthorization = true
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
        return settings.authorizationStatus == .authorized
        #else
        return false
        #endif
    }

    public func post(_ specs: [NotificationRequestSpec]) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        for spec in specs {
            let content = UNMutableNotificationContent()
            content.title = spec.title
            content.body = spec.body
            content.sound = .default
            if let data = try? JSONEncoder().encode(spec.payload),
               let json = String(data: data, encoding: .utf8) {
                content.userInfo = [Self.revealUserInfoKey: json]
            }
            center.add(UNNotificationRequest(identifier: spec.identifier, content: content, trigger: nil))
        }
        #endif
    }

    /// Menu-bar/app badge count of unseen changes (spec §6).
    public func setBadge(_ count: Int) {
        #if canImport(AppKit)
        NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
        #endif
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 3: Commit**

```bash
git add Sources/CanvasData/NotificationScheduler.swift
git commit -m "feat(data): NotificationScheduler — lazy auth, post specs, badge count"
```

---

### Task 17: Notification settings store + AppSession wiring (`CanvasApp`)

**Files:**
- Create: `CanvasApp/App/NotificationSettingsStore.swift`
- Modify: `CanvasApp/App/AppSession.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class NotificationSettingsStore` exposing a `var settings: NotificationSettings` (UserDefaults-backed, clamped interval); `AppSession.notificationSettings`, `AppSession.scheduler`, `AppSession.processUnseenChanges()`.

- [ ] **Step 1: Create the store**

`CanvasApp/App/NotificationSettingsStore.swift`:

```swift
import Foundation
import CanvasData

@MainActor @Observable
final class NotificationSettingsStore {
    var settings: NotificationSettings { didSet { persist() } }

    private static let key = "notificationSettings.v1"

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
            settings = decoded.toSettings()
        } else {
            settings = .defaults
        }
    }

    private func persist() {
        // Clamp the interval to the spec's 15 min–4 h band before saving.
        settings.backgroundIntervalMinutes = min(max(settings.backgroundIntervalMinutes, 15), 240)
        if let data = try? JSONEncoder().encode(Stored(settings)) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    var anyCategoryEnabled: Bool {
        settings.newGrades || settings.newFeedback || settings.newMessages || settings.dueSoon
    }

    /// Codable mirror (NotificationSettings itself is not Codable to keep CanvasData framework-free).
    private struct Stored: Codable {
        var newGrades, newFeedback, newMessages, dueSoon, quietHoursEnabled: Bool
        var quietStartHour, quietEndHour, backgroundIntervalMinutes: Int
        init(_ s: NotificationSettings) {
            newGrades = s.newGrades; newFeedback = s.newFeedback; newMessages = s.newMessages; dueSoon = s.dueSoon
            quietHoursEnabled = s.quietHoursEnabled; quietStartHour = s.quietStartHour
            quietEndHour = s.quietEndHour; backgroundIntervalMinutes = s.backgroundIntervalMinutes
        }
        func toSettings() -> NotificationSettings {
            NotificationSettings(newGrades: newGrades, newFeedback: newFeedback, newMessages: newMessages,
                                 dueSoon: dueSoon, quietHoursEnabled: quietHoursEnabled,
                                 quietStartHour: quietStartHour, quietEndHour: quietEndHour,
                                 backgroundIntervalMinutes: backgroundIntervalMinutes)
        }
    }
}
```

- [ ] **Step 2: Wire into `AppSession`**

Add stored properties + processing. In `AppSession.swift`:

```swift
    let notificationSettings = NotificationSettingsStore()
    let scheduler = NotificationScheduler()
```

Add a method to plan + post from unseen changes and update the badge:

```swift
    /// Reads unseen changes, posts notifications for enabled categories outside quiet hours,
    /// and badges the dock with the unseen count. Quiet-suppressed changes stay unseen (in the feed).
    func processUnseenChanges(now: Date = .init()) {
        let unseen = (try? repository.unseenChanges()) ?? []
        let result = NotificationPlanner.plan(changes: unseen, settings: notificationSettings.settings, now: now)
        scheduler.post(result.post)
        scheduler.setBadge(unseen.count)
    }
```

Add `import CanvasData` is already present. Ensure `NotificationPlanner` resolves (it's in `CanvasData`).

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: builds clean.

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/App/NotificationSettingsStore.swift CanvasApp/App/AppSession.swift
git commit -m "feat(app): notification settings store + AppSession scheduler wiring + processUnseenChanges"
```

---

### Task 18: BackgroundRefreshController + app wiring + tap→reveal (`CanvasApp`)

**Files:**
- Create: `CanvasApp/App/BackgroundRefreshController.swift`
- Modify: `CanvasApp/App/CanvasApp.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class BackgroundRefreshController` with `start()`, `tick() async`, `stop()`; a `UNUserNotificationCenterDelegate` that routes taps to `router.reveal`.
- Consumes: `shouldRunBackgroundTick` (Task 15), `AppSession.processUnseenChanges` (Task 17), `NotificationRevealPayload` (Task 14), `Router`.

- [ ] **Step 1: Create the controller**

`CanvasApp/App/BackgroundRefreshController.swift`:

```swift
import Foundation
import SwiftUI
import CanvasCore
import CanvasData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(IOKit)
import IOKit.ps
#endif
#if canImport(Network)
import Network
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor @Observable
final class BackgroundRefreshController: NSObject {
    private let session: AppSession
    private let router: Router
    private var timer: Timer?
    private var displayAsleepSince: Date?
    private let pathMonitor = NWPathMonitor()
    private var lastPathSatisfied = true

    init(session: AppSession, router: Router) {
        self.session = session; self.router = router
        super.init()
    }

    func start() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().delegate = self
        #endif
        observeSleepWake()
        observeReachability()
        scheduleTimer()
    }

    func stop() { timer?.invalidate(); timer = nil; pathMonitor.cancel() }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(session.notificationSettings.settings.backgroundIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.tick() }
        }
    }

    /// Re-read the interval (Settings may have changed it) and reschedule.
    func rescheduleForSettingsChange() { scheduleTimer() }

    func tick() async {
        guard session.hasCredentials else { return }
        guard shouldRunBackgroundTick(power: currentPowerState(), displayAsleepSince: displayAsleepSince, now: Date())
        else { return }
        _ = await session.refresh(.all)
        _ = await session.refresh(.inbox)
        session.processUnseenChanges()
    }

    private func currentPowerState() -> PowerState {
        #if canImport(IOKit)
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(blob, first)?.takeUnretainedValue() as? [String: Any]
        else { return PowerState(onBattery: false, batteryPercent: 100) }
        let state = desc[kIOPSPowerSourceStateKey] as? String
        let onBattery = state == kIOPSBatteryPowerValue
        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
        let percent = max > 0 ? Int(Double(capacity) / Double(max) * 100) : 100
        return PowerState(onBattery: onBattery, batteryPercent: percent)
        #else
        return PowerState(onBattery: false, batteryPercent: 100)
        #endif
    }

    private func observeSleepWake() {
        #if canImport(AppKit)
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAsleepSince = Date() }
        }
        nc.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.displayAsleepSince = nil }
        }
        nc.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.tick() }   // immediate sync on wake (spec §6)
        }
        #endif
    }

    private func observeReachability() {
        #if canImport(Network)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let satisfied = path.status == .satisfied
                if satisfied && !self.lastPathSatisfied { await self.tick() }  // reachability returned
                self.lastPathSatisfied = satisfied
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "bg.reachability"))
        #endif
    }
}

#if canImport(UserNotifications)
extension BackgroundRefreshController: UNUserNotificationCenterDelegate {
    // Foreground presentation.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound, .badge] }

    // Tap → reveal (spec §6).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let json = userInfo[NotificationScheduler.revealUserInfoKey] as? String,
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(NotificationRevealPayload.self, from: data) else { return }
        await MainActor.run { self.reveal(payload) }
    }

    private func reveal(_ payload: NotificationRevealPayload) {
        switch ChangeKind(rawValue: payload.kind) {
        case .newMessage:
            if let id = payload.subjectId { router.reveal(.conversation(id: id)) }
            else { router.reveal(.section(.inbox)) }
        case .newGrade, .gradeChanged, .newFeedback, .dueSoon:
            if let assignmentId = payload.subjectId {
                router.reveal(.assignment(courseId: payload.courseId, assignmentId: assignmentId))
            } else {
                router.reveal(.course(id: payload.courseId, tab: .grades))
            }
        default:
            router.reveal(.section(.dashboard))
        }
    }
}
#endif
```

- [ ] **Step 2: Wire into `CanvasApp.swift`**

Add the controller and open/badge on launch. In `CanvasGradesApp`:

```swift
    @State private var session = AppSession()
    @State private var router = Router()
    @State private var background: BackgroundRefreshController?
```

Attach a `.task` to the `Window` scene's content to construct + start the controller once (opening the window is the natural start point; the menu-bar scene keeps the process resident):

```swift
        Window("Canvas", id: "main") {
            MainWindowView()
                .environment(session)
                .environment(router)
                .preferredColorScheme(preferredColorScheme)
                .task {
                    if background == nil {
                        let controller = BackgroundRefreshController(session: session, router: router)
                        background = controller
                        controller.start()
                    }
                }
        }
        .defaultSize(width: 1000, height: 700)
```

Also open the window on a notification tap: the delegate's `router.reveal` sets `router.sidebar`; add an `openWindow` trigger by observing `router` from the menu-bar scene. Simplest reliable path — in `PopoverContent` or the app body, add an `@Environment(\.openWindow)` and a `.onChange(of: router.selectedConversationId)`/`sidebar` to `openWindow(id: "main")`. Add to the `Window` scene content:

```swift
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in }
```

(No-op placeholder is unnecessary; the tap already routes because the window is the default scene. If the window is closed, macOS reopens `id: "main"` when the delegate activates the app. Verify in demo; if it does not reopen, add `@Environment(\.openWindow)` in a small wrapper and call `openWindow(id:"main")` inside `reveal`.)

- [ ] **Step 3: Verify build + demo walkthrough**

Run: `swift build`
Then demo: enable a category in Settings (Task 19) → grant permission → force a change (demo grade) via a refresh → confirm a banner appears and its tap navigates. Confirm the dock badge shows the unseen count.

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/App/BackgroundRefreshController.swift CanvasApp/App/CanvasApp.swift
git commit -m "feat(app): background refresh timer + sleep/wake/reachability triggers + notification tap→reveal"
```

---

# GROUP D — SETTINGS & DEMO POLISH

### Task 19: Notification Settings section (`CanvasApp`)

**Files:**
- Modify: `CanvasApp/Views/SettingsView.swift`

**Interfaces:**
- Consumes: `AppSession.notificationSettings` (Task 17), `AppSession.scheduler` (lazy auth), `BackgroundRefreshController.rescheduleForSettingsChange` (via a callback — see below).
- Produces: a `NotificationSettingsSection` shown in the non-onboarding Settings body.

- [ ] **Step 1: Add the section view**

At the end of `SettingsView.swift`, add:

```swift
/// Notification categories, quiet hours, and background-refresh interval (spec §6).
/// Requesting permission is lazy — deferred until the first category is switched on.
private struct NotificationSettingsSection: View {
    let session: AppSession
    @State private var store: NotificationSettingsStore

    init(session: AppSession) {
        self.session = session
        _store = State(initialValue: session.notificationSettings)
    }

    var body: some View {
        @Bindable var store = store
        Divider()
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications").font(.subheadline).foregroundStyle(.secondary)

            categoryToggle("New grades", isOn: $store.settings.newGrades)
            categoryToggle("New feedback", isOn: $store.settings.newFeedback)
            categoryToggle("New inbox messages", isOn: $store.settings.newMessages)
            categoryToggle("Assignment due soon", isOn: $store.settings.dueSoon)

            Toggle("Quiet hours", isOn: $store.settings.quietHoursEnabled).font(.caption)
            if store.settings.quietHoursEnabled {
                HStack {
                    Picker("From", selection: $store.settings.quietStartHour) { hourOptions }.frame(width: 110)
                    Picker("To", selection: $store.settings.quietEndHour) { hourOptions }.frame(width: 110)
                }
                .font(.caption)
            }

            Stepper("Background refresh: every \(store.settings.backgroundIntervalMinutes) min",
                    value: $store.settings.backgroundIntervalMinutes, in: 15...240, step: 15)
                .font(.caption)
        }
    }

    private func categoryToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                isOn.wrappedValue = newValue
                if newValue { Task { await session.scheduler.requestAuthorizationIfNeeded() } }
            }))
            .font(.caption)
    }

    private var hourOptions: some View {
        ForEach(0..<24, id: \.self) { h in
            Text(String(format: "%02d:00", h)).tag(h)
        }
    }
}
```

- [ ] **Step 2: Show it in the Settings body**

In `SettingsView.body`, inside the `if !isOnboarding {` block (right after `CustomizationSection(...)`):

```swift
                if !isOnboarding {
                    CustomizationSection(vm: vm, session: session, courseSettings: courseSettings)
                    NotificationSettingsSection(session: session)
                }
```

- [ ] **Step 3: Verify build + demo walkthrough**

Run: `swift build`
Then demo: open Settings → toggle "New inbox messages" on → confirm the macOS permission prompt appears (first enable only) → enable quiet hours → pickers appear → change interval → value clamps within 15–240.

- [ ] **Step 4: Commit**

```bash
git add CanvasApp/Views/SettingsView.swift
git commit -m "feat(app): Settings — notification categories, quiet hours, background interval (lazy permission)"
```

---

### Task 20: Purge/TTL housekeeping + full demo walkthrough + green suite

**Files:**
- Modify: `Sources/CanvasData/CanvasRepository.swift` (`purgeExpired` covers new soft-deletes)
- Test: (uses existing suites; add one purge assertion)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Extend `purgeExpired` for new soft-deleted rows**

In `CanvasRepository.purgeExpired`, add (alongside the existing course/assignment purges):

```swift
        for convo in try context.fetch(FetchDescriptor<CachedConversation>())
        where convo.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(convo)
        }
        for topic in try context.fetch(FetchDescriptor<CachedDiscussionTopic>())
        where topic.removedAt.map({ $0 < courseThreshold }) ?? false {
            context.delete(topic)
        }
```

- [ ] **Step 2: Add a purge regression test** to `ConversationSyncTests`

```swift
    func testPurgeRemovesLongDeadConversation() throws {
        let container = try CanvasStore.container(inMemory: true)
        try MainActor.run {
            let ctx = container.mainContext
            let old = CachedConversation(id: 1, subject: "old", lastMessageAt: Date(), lastMessageSnippet: nil,
                                         workflowState: "read", participantsJSON: nil, contextName: nil, messageCount: 1)
            old.removedAt = Date().addingTimeInterval(-100 * 86400)   // 100 days ago > 90-day threshold
            ctx.insert(old); try ctx.save()
            let repo = CanvasRepository(modelContainer: container)
            try repo.purgeExpired()
            XCTAssertNil(try repo.conversation(id: 1))
        }
    }
```

- [ ] **Step 3: Run the whole suite**

Run: `swift test`
Expected: all tests pass (existing Phase 0/1 suites + every Phase 2 suite added above). If anything is red, fix before proceeding — the suite must be green (Global Constraints).

- [ ] **Step 4: Full demo walkthrough (spec §2.7 — the phase's acceptance gate)**

With `CANVAS_TOKEN=DEMO`, in **both** scenes where applicable, verify:
- Inbox: 2 threads; open unread (dot clears, marked read); reply (bubble + Demo badge, reconciles, no orphan pending); compose new (new thread appears and opens); offline (disable network) → reply/compose disabled.
- Discussions: 2 topics; open the threaded one (root + indented reply + second root); "Reply in Canvas" links out; empty topic shows empty state.
- Notifications: enable a category (permission prompt once); trigger changes via a forced refresh; banner posts; tap navigates; quiet hours suppress posting but the change feed still shows the change; dock badge reflects unseen count.
- Settings: toggles persist across relaunch; interval clamps 15–240.

- [ ] **Step 5: Commit**

```bash
git add Sources/CanvasData/CanvasRepository.swift Tests/CanvasDataTests/ConversationSyncTests.swift
git commit -m "chore(data): purge dead conversations/discussion topics; Phase 2 suite green + demo-walkable"
```

---

## Self-Review

**Spec §9 Phase 2 coverage:**
- Inbox — list (Task 3/4/9), thread (Task 6/9), compose (Task 2/7/8/9), reply (Task 7/8/9), mark read (Task 7/9). ✅
- Discussions read-only — Task 10–13; "Reply in Canvas" link-out, no composer. ✅
- `NotificationScheduler` — Task 14 (planner) + Task 16 (UN wrapper) + Task 17 (wiring). ✅
- Background refresh — Task 15 (gate) + Task 18 (controller: timer, wake, reachability, battery/display gating). ✅
- Settings for notification categories + quiet hours — Task 19 (plus interval). ✅
- Notification categories/coalescing/quiet hours/lazy permission/badge/tap-reveal (§6) — Tasks 14, 16, 17, 18, 19. ✅
- Canvas quirks (§3.1): `.newMessage` deviation is documented in Global Constraints and implemented in Task 5. ✅
- Demo verifiability (§2.7): Tasks 2, 11 add demo data; Task 20 is the walkthrough gate. ✅
- Optimistic write + reconcile + draft restore (§5.2): Task 7 (reconcile) + Task 9 (draft restore). ✅

**Type consistency check:** `SyncScope` cases (`.inbox`/`.conversation(Int)`/`.discussion(courseId:topicId:)`) are defined in Task 4 and consumed in Tasks 6, 9, 12, 13, 18. `EntityKind` raw strings used in repository `lastSyncedAt` calls (`"conversations"`, `"discussionTopics"`) match the enum cases' `rawValue`. `NotificationSettings.enabled(for:)` covers every `ChangeKind` case (compiler-exhaustive). `MockData.studentUserId`/`teacherUserId`/`csCourseId` are pre-existing. `RecordingStub` is defined once in Task 2 and reused in Task 11.

**Placeholder scan:** every code step carries full code; Task 18's window-reopen note is an explicit demo-time verification with a concrete fallback (`@Environment(\.openWindow)`), not a TODO.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-08-phase2-communication.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
