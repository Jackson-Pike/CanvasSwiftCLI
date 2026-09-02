import XCTest
import SwiftData
@testable import CanvasCore
@testable import CanvasData

final class FileSyncTests: XCTestCase {
    @MainActor
    func testSyncFilesUpsertsFoldersAndFilesAndPreservesLocalPath() async throws {
        let container = try CanvasStore.container(inMemory: true)
        let engine = SyncEngine(modelContainer: container)
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        await engine.configure(client: client)

        // Seed a localPath on file 8001
        let context = container.mainContext
        let seededFile = CachedFile(id: 8001, courseId: MockData.csCourseId, displayName: "Old Name", localPath: "/Users/test/Downloads/CS101_Syllabus.pdf")
        context.insert(seededFile)
        try context.save()

        try await engine.refresh(.files(courseId: MockData.csCourseId))

        let folders = try context.fetch(FetchDescriptor<CachedFolder>())
        let files = try context.fetch(FetchDescriptor<CachedFile>())

        XCTAssertFalse(folders.isEmpty)
        XCTAssertFalse(files.isEmpty)

        let file8001 = files.first { $0.id == 8001 }
        XCTAssertNotNil(file8001)
        XCTAssertEqual(file8001?.displayName, "CS101_Syllabus.pdf")
        XCTAssertEqual(file8001?.localPath, "/Users/test/Downloads/CS101_Syllabus.pdf")
    }
}
