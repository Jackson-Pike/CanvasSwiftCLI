import Foundation
import CanvasCore
import CanvasData

@MainActor
final class AnnouncementsViewModel: ObservableObject {
    let courseId: Int
    @Published var announcements: [CachedAnnouncement] = []
    @Published var selectedId: Int?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?

    init(courseId: Int) {
        self.courseId = courseId
    }

    var selected: CachedAnnouncement? {
        selectedId.flatMap { id in announcements.first { $0.id == id } }
    }

    func load(session: AppSession, force: Bool = false) async {
        readFromStore(session)                       // instant render from disk
        guard session.hasCredentials else { return }
        isLoading = announcements.isEmpty            // skeleton only when cold
        error = nil
        error = await session.refresh(.course(courseId), force: force)
        readFromStore(session)                       // re-read after sync
        isLoading = false
    }

    /// Viewing an announcement marks it read (spec §5.3) — device-local, never a
    /// round-trip to Canvas, and the repository refuses to overwrite an earlier stamp.
    func markSelectedRead(session: AppSession) {
        guard let selectedId else { return }
        try? session.repository.markAnnouncementRead(selectedId)
        readFromStore(session)
    }

    private func readFromStore(_ session: AppSession) {
        announcements = (try? session.repository.announcements(courseId: courseId)) ?? []
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "announcements", scopeId: "\(courseId)")
    }
}
