import XCTest
import AppKit
@testable import CanvasUI

/// The serializer converts the editor's `NSAttributedString` into a clean, semantic
/// HTML fragment safe to send as Canvas `submission[body]`. These tests pin the
/// export contract; the editor is responsible for producing attributed strings that
/// match the conventions exercised here (see `SubmissionHTML` attribute keys).
final class SubmissionHTMLTests: XCTestCase {

    private let body = SubmissionHTML.bodyPointSize

    private func run(_ text: String, _ attrs: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var a = attrs
        if a[.font] == nil { a[.font] = NSFont.systemFont(ofSize: body) }
        return NSAttributedString(string: text, attributes: a)
    }

    // MARK: - Inline formatting

    func testPlainParagraphExportsAsParagraph() {
        let s = run("Hello world", [:])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<p>Hello world</p>")
    }

    func testBoldExportsStrong() {
        let s = run("Hello", [.font: NSFont.boldSystemFont(ofSize: body)])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<p><strong>Hello</strong></p>")
    }

    func testItalicExportsEm() {
        let font = NSFontManager.shared.convert(NSFont.systemFont(ofSize: body), toHaveTrait: .italicFontMask)
        let s = run("Hello", [.font: font])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<p><em>Hello</em></p>")
    }

    func testUnderlineExportsU() {
        let s = run("Hello", [.underlineStyle: NSUnderlineStyle.single.rawValue])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<p><u>Hello</u></p>")
    }

    func testLinkExportsAnchor() {
        let s = run("click", [.link: URL(string: "https://example.com")!])
        XCTAssertEqual(SubmissionHTML.html(from: s), #"<p><a href="https://example.com">click</a></p>"#)
    }

    func testInlineCodeExportsCode() {
        let s = run("x = 1", [SubmissionHTML.codeAttribute: true])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<p><code>x = 1</code></p>")
    }

    func testMixedRunsWithinParagraph() {
        let m = NSMutableAttributedString()
        m.append(run("normal ", [:]))
        m.append(run("bold", [.font: NSFont.boldSystemFont(ofSize: body)]))
        XCTAssertEqual(SubmissionHTML.html(from: m), "<p>normal <strong>bold</strong></p>")
    }

    // MARK: - Escaping

    func testEscapesHTMLSpecialCharacters() {
        let s = run("a < b & c > d \"e\"", [:])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<p>a &lt; b &amp; c &gt; d &quot;e&quot;</p>")
    }

    // MARK: - Blocks

    func testNewlineSeparatesParagraphs() {
        let m = NSMutableAttributedString()
        m.append(run("one\ntwo", [:]))
        XCTAssertEqual(SubmissionHTML.html(from: m), "<p>one</p>\n<p>two</p>")
    }

    func testHeadingLevelsFromFontSize() {
        XCTAssertEqual(SubmissionHTML.html(from: run("Big", [.font: NSFont.boldSystemFont(ofSize: SubmissionHTML.headingPointSize(1))])), "<h1>Big</h1>")
        XCTAssertEqual(SubmissionHTML.html(from: run("Mid", [.font: NSFont.boldSystemFont(ofSize: SubmissionHTML.headingPointSize(2))])), "<h2>Mid</h2>")
        XCTAssertEqual(SubmissionHTML.html(from: run("Small", [.font: NSFont.boldSystemFont(ofSize: SubmissionHTML.headingPointSize(3))])), "<h3>Small</h3>")
    }

    func testBlockquoteExports() {
        let ps = NSMutableParagraphStyle()
        let s = run("Quoted", [SubmissionHTML.blockquoteAttribute: true, .paragraphStyle: ps])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<blockquote>Quoted</blockquote>")
    }

    func testUnorderedListGroupsConsecutiveItems() {
        let m = NSMutableAttributedString()
        m.append(run("one", [SubmissionHTML.listKindAttribute: SubmissionHTML.ListKind.unordered.rawValue]))
        m.append(run("\n", [:]))
        m.append(run("two", [SubmissionHTML.listKindAttribute: SubmissionHTML.ListKind.unordered.rawValue]))
        XCTAssertEqual(SubmissionHTML.html(from: m), "<ul>\n<li>one</li>\n<li>two</li>\n</ul>")
    }

    func testOrderedListUsesOl() {
        let m = NSMutableAttributedString()
        m.append(run("one", [SubmissionHTML.listKindAttribute: SubmissionHTML.ListKind.ordered.rawValue]))
        m.append(run("\n", [:]))
        m.append(run("two", [SubmissionHTML.listKindAttribute: SubmissionHTML.ListKind.ordered.rawValue]))
        XCTAssertEqual(SubmissionHTML.html(from: m), "<ol>\n<li>one</li>\n<li>two</li>\n</ol>")
    }

    func testNativeListMarkerStrippedFromItems() {
        // NSTextView stores list items as "\t<marker>\t<text>"; the marker must not leak into <li>.
        let m = NSMutableAttributedString()
        m.append(run("\t•\tone", [SubmissionHTML.listKindAttribute: SubmissionHTML.ListKind.unordered.rawValue]))
        m.append(run("\n", [:]))
        m.append(run("\t1.\ttwo", [SubmissionHTML.listKindAttribute: SubmissionHTML.ListKind.unordered.rawValue]))
        XCTAssertEqual(SubmissionHTML.html(from: m), "<ul>\n<li>one</li>\n<li>two</li>\n</ul>")
    }

    func testNativeParagraphStyleListDetected() {
        // A reloaded draft carries lists as paragraphStyle.textLists, not the custom attribute.
        let disc = NSTextList(markerFormat: .disc, options: 0)
        let ps = NSMutableParagraphStyle(); ps.textLists = [disc]
        let s = run("\t•\tone", [.paragraphStyle: ps])
        XCTAssertEqual(SubmissionHTML.html(from: s), "<ul>\n<li>one</li>\n</ul>")
    }

    func testEmptyParagraphsAreDropped() {
        let m = NSMutableAttributedString()
        m.append(run("one\n\ntwo", [:]))
        XCTAssertEqual(SubmissionHTML.html(from: m), "<p>one</p>\n<p>two</p>")
    }

    // MARK: - Plain text & emptiness

    func testPlainTextFromHTMLStripsTags() {
        XCTAssertEqual(SubmissionHTML.plainText(fromHTML: "<p>Hello <strong>world</strong></p>"), "Hello world")
    }

    func testIsEffectivelyEmpty() {
        XCTAssertTrue(SubmissionHTML.isEffectivelyEmpty("<p></p>"))
        XCTAssertTrue(SubmissionHTML.isEffectivelyEmpty("   \n  "))
        XCTAssertTrue(SubmissionHTML.isEffectivelyEmpty(""))
        XCTAssertFalse(SubmissionHTML.isEffectivelyEmpty("<p>hi</p>"))
    }

    // MARK: - Round trip through draft reload (AppKit import)

    func testRoundTripPreservesBoldAndLink() {
        let m = NSMutableAttributedString()
        m.append(run("see ", [:]))
        m.append(run("bold", [.font: NSFont.boldSystemFont(ofSize: body)]))
        let html = SubmissionHTML.html(from: m)
        let reloaded = SubmissionHTML.attributed(fromHTML: html)
        XCTAssertEqual(SubmissionHTML.html(from: reloaded), html)
    }
}
