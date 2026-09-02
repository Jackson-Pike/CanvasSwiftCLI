import XCTest
@testable import CanvasCore

final class ModuleModelsTests: XCTestCase {
    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func testModuleAndModuleItemsDecode() throws {
        let json = Data(#"""
        {
            "id": 10101,
            "name": "Week 1: Introduction to Biology",
            "position": 1,
            "state": "completed",
            "unlock_at": "2026-08-01T00:00:00Z",
            "items_count": 2,
            "items": [
                {
                    "id": 1001,
                    "module_id": 10101,
                    "title": "Welcome Page",
                    "position": 1,
                    "type": "Page",
                    "indent": 0,
                    "html_url": "https://byuh.instructure.com/courses/101/modules/items/1001",
                    "page_url": "welcome-page",
                    "completion_requirement": {
                        "type": "must_view",
                        "completed": true
                    }
                },
                {
                    "id": 1002,
                    "module_id": 10101,
                    "title": "Lab 1 Assignment",
                    "position": 2,
                    "type": "Assignment",
                    "indent": 1,
                    "content_id": 55,
                    "html_url": "https://byuh.instructure.com/courses/101/modules/items/1002",
                    "completion_requirement": {
                        "type": "must_submit",
                        "completed": false
                    }
                }
            ]
        }
        """#.utf8)

        let module = try decoder().decode(Module.self, from: json)
        XCTAssertEqual(module.id, 10101)
        XCTAssertEqual(module.name, "Week 1: Introduction to Biology")
        XCTAssertEqual(module.position, 1)
        XCTAssertEqual(module.state, "completed")
        XCTAssertEqual(module.items?.count, 2)

        let item1 = module.items?[0]
        XCTAssertEqual(item1?.id, 1001)
        XCTAssertEqual(item1?.moduleId, 10101)
        XCTAssertEqual(item1?.title, "Welcome Page")
        XCTAssertEqual(item1?.type, "Page")
        XCTAssertEqual(item1?.indent, 0)
        XCTAssertEqual(item1?.pageUrl, "welcome-page")
        XCTAssertEqual(item1?.completionRequirement?.type, "must_view")
        XCTAssertEqual(item1?.completionRequirement?.completed, true)

        let item2 = module.items?[1]
        XCTAssertEqual(item2?.contentId, 55)
        XCTAssertEqual(item2?.type, "Assignment")
        XCTAssertEqual(item2?.completionRequirement?.completed, false)
    }
}
