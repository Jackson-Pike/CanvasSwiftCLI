import XCTest
import AppKit
@testable import CanvasUI

/// Exercises the toolbar command path end-to-end: a real `NSTextView` driven by the
/// controller, then serialized through `SubmissionHTML`. Guards the integration that the
/// pure serializer tests can't reach (typing attributes, list toggling, heading spans).
@MainActor
final class RichTextControllerTests: XCTestCase {

    private func makeController() -> (RichTextController, NSTextView) {
        let tv = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        tv.isRichText = true
        tv.font = .systemFont(ofSize: SubmissionHTML.bodyPointSize)
        let controller = RichTextController()
        controller.textView = tv
        return (controller, tv)
    }

    private func html(_ tv: NSTextView) -> String {
        SubmissionHTML.html(from: tv.textStorage!)
    }

    func testBoldOnSelectionProducesStrong() {
        let (c, tv) = makeController()
        tv.string = "Hello world"
        tv.setSelectedRange(NSRange(location: 6, length: 5))
        c.refresh()
        c.toggleBold()
        XCTAssertEqual(html(tv), "<p>Hello <strong>world</strong></p>")
        XCTAssertTrue(c.isBold)
    }

    func testHeadingWrapsParagraph() {
        let (c, tv) = makeController()
        tv.string = "Title here"
        tv.setSelectedRange(NSRange(location: 0, length: 10))
        c.setHeading(2)
        XCTAssertEqual(html(tv), "<h2>Title here</h2>")
        XCTAssertEqual(c.headingLevel, 2)
    }

    func testUnorderedListRoundTrips() {
        let (c, tv) = makeController()
        tv.string = "apple\nbanana"
        tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        c.refresh()
        c.toggleList(.unordered)
        XCTAssertEqual(html(tv), "<ul>\n<li>apple</li>\n<li>banana</li>\n</ul>")
        XCTAssertEqual(c.listKind, .unordered)
    }

    func testOrderedListUsesOl() {
        let (c, tv) = makeController()
        tv.string = "first\nsecond"
        tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        c.refresh()
        c.toggleList(.ordered)
        XCTAssertEqual(html(tv), "<ol>\n<li>first</li>\n<li>second</li>\n</ol>")
    }

    func testListTogglesBackToParagraphs() {
        let (c, tv) = makeController()
        tv.string = "apple\nbanana"
        tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        c.refresh()
        c.toggleList(.unordered)
        tv.setSelectedRange(NSRange(location: 0, length: (tv.string as NSString).length))
        c.refresh()
        c.toggleList(.unordered)
        XCTAssertEqual(html(tv), "<p>apple</p>\n<p>banana</p>")
        XCTAssertNil(c.listKind)
    }

    func testLinkAppliesAnchor() {
        let (c, tv) = makeController()
        tv.string = "click"
        tv.setSelectedRange(NSRange(location: 0, length: 5))
        c.applyLink("example.com")
        XCTAssertEqual(html(tv), #"<p><a href="https://example.com">click</a></p>"#)
    }
}
