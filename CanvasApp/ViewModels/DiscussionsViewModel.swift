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
