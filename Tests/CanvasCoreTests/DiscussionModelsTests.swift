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
