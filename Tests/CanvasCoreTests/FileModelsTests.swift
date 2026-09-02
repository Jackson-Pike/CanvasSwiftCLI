import XCTest
@testable import CanvasCore

final class FileModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func testCanvasFolderAndFileDecode() throws {
        let folderJSON = Data(#"""
        {
            "id": 5001,
            "name": "Lecture Slides",
            "full_name": "course files/Lecture Slides",
            "context_id": 101,
            "context_type": "Course",
            "parent_folder_id": null,
            "files_count": 5,
            "folders_count": 0,
            "updated_at": "2026-08-10T12:00:00Z"
        }
        """#.utf8)

        let folder = try decoder().decode(CanvasFolder.self, from: folderJSON)
        XCTAssertEqual(folder.id, 5001)
        XCTAssertEqual(folder.name, "Lecture Slides")
        XCTAssertEqual(folder.fullName, "course files/Lecture Slides")
        XCTAssertNil(folder.parentFolderId)
        XCTAssertEqual(folder.filesCount, 5)

        let fileJSON = Data(#"""
        {
            "id": 8001,
            "folder_id": 5001,
            "display_name": "Syllabus_Fall2026.pdf",
            "filename": "Syllabus_Fall2026.pdf",
            "content_type": "application/pdf",
            "url": "https://byuh.instructure.com/files/8001/download",
            "size": 1048576,
            "created_at": "2026-08-01T10:00:00Z",
            "updated_at": "2026-08-05T14:30:00Z",
            "locked": false
        }
        """#.utf8)

        let file = try decoder().decode(CanvasFile.self, from: fileJSON)
        XCTAssertEqual(file.id, 8001)
        XCTAssertEqual(file.folderId, 5001)
        XCTAssertEqual(file.displayName, "Syllabus_Fall2026.pdf")
        XCTAssertEqual(file.contentType, "application/pdf")
        XCTAssertEqual(file.size, 1048576)
        XCTAssertEqual(file.url, "https://byuh.instructure.com/files/8001/download")
    }
}
