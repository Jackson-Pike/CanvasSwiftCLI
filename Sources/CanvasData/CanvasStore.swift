import Foundation
import SwiftData

public enum CanvasStore {
    public static let schema = Schema([
        CachedCourse.self, CachedEnrollment.self, CachedAssignmentGroup.self,
        CachedAssignment.self, CachedSubmission.self, CachedComment.self,
        GradeSnapshot.self, ChangeRecord.self, SyncMetadata.self,
        CachedAnnouncement.self,
        CachedConversation.self, CachedMessage.self,
        CachedDiscussionTopic.self, CachedDiscussionEntry.self,
        CachedPlannerItem.self, CachedCalendarEvent.self,
        CachedModule.self, CachedModuleItem.self,
        CachedFolder.self, CachedFile.self,
    ])

    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
