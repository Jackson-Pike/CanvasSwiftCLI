import XCTest
@testable import CanvasCore

final class FileAPITests: XCTestCase {
    func testDemoFoldersAndFilesReturnsMockData() async throws {
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let folders = try await client.folders(courseId: 101)
        XCTAssertFalse(folders.isEmpty)

        let files = try await client.files(courseId: 101)
        XCTAssertFalse(files.isEmpty)
    }

    func testDemoDownloadFileWritesLocalFile() async throws {
        let client = APIClient(credentials: Credentials(host: "byuh.instructure.com", token: "DEMO"))
        let tempDir = FileManager.default.temporaryDirectory
        let destURL = tempDir.appendingPathComponent("test_demo_download.pdf")

        defer { try? FileManager.default.removeItem(at: destURL) }

        try await client.downloadFile(url: "https://demo.canvas/test.pdf", to: destURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
    }
}
