import XCTest
@testable import CanvasCore

final class SubmissionRequestTests: XCTestCase {

    func testSupportedFiltersAndOrders() {
        let raw = ["online_url", "online_quiz", "online_upload", "online_text_entry", "on_paper"]
        XCTAssertEqual(SubmissionType.supported(from: raw),
                       [.onlineUpload, .onlineText, .onlineURL])
    }

    func testSupportedNilIsEmpty() {
        XCTAssertEqual(SubmissionType.supported(from: nil), [])
    }

    func testExtensionAllowedWhenListNilOrEmpty() {
        XCTAssertTrue(SubmissionValidator.isExtensionAllowed("essay.pdf", allowed: nil))
        XCTAssertTrue(SubmissionValidator.isExtensionAllowed("essay.pdf", allowed: []))
    }

    func testExtensionAllowedCaseInsensitive() {
        XCTAssertTrue(SubmissionValidator.isExtensionAllowed("Report.PDF", allowed: ["pdf", "docx"]))
        XCTAssertFalse(SubmissionValidator.isExtensionAllowed("virus.exe", allowed: ["pdf", "docx"]))
    }

    func testExtensionAllowedHandlesNoExtension() {
        XCTAssertFalse(SubmissionValidator.isExtensionAllowed("README", allowed: ["pdf"]))
    }

    func testAssignmentDecodesAllowedExtensions() throws {
        let json = """
        {"id":1,"name":"Essay","points_possible":100,"assignment_group_id":9,
         "submission_types":["online_upload"],"allowed_extensions":["pdf","docx"]}
        """.data(using: .utf8)!
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase
        let a = try d.decode(Assignment.self, from: json)
        XCTAssertEqual(a.allowedExtensions, ["pdf", "docx"])
    }
}
