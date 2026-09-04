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

extension SubmissionRequestTests {
    func testUploadTicketDecodesURLAndParams() throws {
        let json = """
        {"upload_url":"https://uploads.example.com/put",
         "upload_params":{"key":"abc","content_type":"application/pdf","success_action_status":"201"}}
        """.data(using: .utf8)!
        let ticket = try JSONDecoder().decode(UploadTicket.self, from: json)
        XCTAssertEqual(ticket.uploadURL, "https://uploads.example.com/put")
        // stored as ordered (String,String) pairs; assert as a dictionary for order-independence
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: ticket.uploadParams),
                       ["key": "abc", "content_type": "application/pdf", "success_action_status": "201"])
    }

    func testUploadTicketCoercesScalarParamValues() throws {
        let json = """
        {"upload_url":"https://u/x","upload_params":{"max_size":10485760,"flag":true,"skip":null}}
        """.data(using: .utf8)!
        let ticket = try JSONDecoder().decode(UploadTicket.self, from: json)
        let dict = Dictionary(uniqueKeysWithValues: ticket.uploadParams)
        XCTAssertEqual(dict["max_size"], "10485760")
        XCTAssertEqual(dict["flag"], "true")
        XCTAssertNil(dict["skip"]) // null dropped
    }

    func testUploadedFileDecodesId() throws {
        let json = #"{"id":55123,"display_name":"essay.pdf"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(UploadedFile.self, from: json).id, 55123)
    }
}
