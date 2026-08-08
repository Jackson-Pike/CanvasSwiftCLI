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
