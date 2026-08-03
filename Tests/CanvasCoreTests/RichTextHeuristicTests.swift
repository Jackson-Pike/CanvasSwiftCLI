import XCTest
@testable import CanvasCore

final class RichTextHeuristicTests: XCTestCase {

    func testPlainMarkupDoesNotNeedWebView() {
        // plain <p><strong> markup → false
        let html = "<p><strong>Hello</strong> world</p>"
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testPlainParagraphs() {
        // simple paragraphs → false
        let html = "<p>This is a paragraph</p><p>Another paragraph</p>"
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testPlainEmphasis() {
        // <em>, <strong>, <b>, <i> → false
        let html = "<p>This is <em>emphasized</em> and <strong>bold</strong> and <b>also bold</b></p>"
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testTableNeedsWebView() {
        // <table> → true
        let html = "<table><tr><td>Cell</td></tr></table>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testTableCapitalNeedsWebView() {
        // uppercase <TABLE> → true (case-insensitive)
        let html = "<TABLE><TR><TD>Cell</TD></TR></TABLE>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testIframeNeedsWebView() {
        // <iframe> → true
        let html = "<iframe src=\"https://example.com\"></iframe>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testVideoNeedsWebView() {
        // <video> → true
        let html = "<video><source src=\"video.mp4\"></video>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testAudioNeedsWebView() {
        // <audio> → true
        let html = "<audio><source src=\"audio.mp3\"></audio>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testEmbedNeedsWebView() {
        // <embed> → true
        let html = "<embed src=\"file.swf\">"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testObjectNeedsWebView() {
        // <object> → true
        let html = "<object data=\"file.pdf\"></object>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testScriptNeedsWebView() {
        // <script> → true (for safety)
        let html = "<script>alert('hi')</script>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testLatexRoundBracketsNeedsWebView() {
        // \( ... \) LaTeX syntax → true
        let html = "<p>The equation is \\(x^2 + y^2 = z^2\\)</p>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testLatexSquareBracketsNeedsWebView() {
        // \[ ... \] LaTeX syntax → true
        let html = "<p>The equation is \\[x^2 + y^2 = z^2\\]</p>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testMathClassNeedsWebView() {
        // class="math" → true
        let html = "<span class=\"math\">x^2</span>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testMathClassCaseSensitive() {
        // class="Math" (uppercase) → true (case-insensitive lowercased)
        let html = "<span class=\"Math\">x^2</span>"
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testComplexHtmlWithTable() {
        // Complex HTML with table → true
        let html = """
        <div>
        <p>Here's a table:</p>
        <table>
        <tr><td>A</td><td>B</td></tr>
        <tr><td>1</td><td>2</td></tr>
        </table>
        </div>
        """
        XCTAssertTrue(htmlNeedsWebView(html))
    }

    func testSimpleListNeedsWebView() {
        // Lists are simple markup that AttributedString can handle, but let's test edge cases
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testLinksDoNotNeedWebView() {
        // <a> tags don't require WebView
        let html = "<p>Click <a href=\"https://example.com\">here</a></p>"
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testImageTagDoesNotNeedWebView() {
        // <img> is simple and can be handled by AttributedString
        let html = "<p><img src=\"image.jpg\"></p>"
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testEmptyHtmlDoesNotNeedWebView() {
        let html = ""
        XCTAssertFalse(htmlNeedsWebView(html))
    }

    func testWhitespaceOnlyDoesNotNeedWebView() {
        let html = "   \n\t  "
        XCTAssertFalse(htmlNeedsWebView(html))
    }
}
