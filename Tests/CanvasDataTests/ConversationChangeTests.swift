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
