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
        config.protocolClasses = [FormRecordingStub.self]
        FormRecordingStub.reset(); FormRecordingStub.body = Data("[]".utf8)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "T"),
                               session: URLSession(configuration: config))
        _ = try await client.discussionTopics(courseId: 42)
        let url = FormRecordingStub.lastURL!.absoluteString
        XCTAssertTrue(url.contains("/courses/42/discussion_topics"))
        XCTAssertFalse(url.contains("only_announcements"))   // discussions, not announcements
    }
}
