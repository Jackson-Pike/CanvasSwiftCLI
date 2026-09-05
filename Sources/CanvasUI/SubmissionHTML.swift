import AppKit

// MARK: - SubmissionHTML

/// Bridges the rich-text `NSTextView` used for `online_text_entry` submissions to and
/// from HTML.
///
/// Canvas stores `submission[body]` as HTML and runs it through a sanitizer that drops
/// `<style>` blocks and `class` attributes. AppKit's own HTML writer expresses underline
/// and heading sizes *only* through such a `<style>` block, so those would silently
/// vanish on Canvas. `html(from:)` therefore serializes a small, sanitizer-safe subset
/// with semantic tags (`<strong> <em> <u> <h1-3> <ul>/<ol> <blockquote> <code> <a>`).
///
/// The reverse direction (`attributed(fromHTML:)`, used only to reload a saved draft)
/// leans on AppKit's HTML *reader*, which handles those standard tags. Blockquote and
/// inline-code styling are not reconstructed on reload — the text survives, its block/inline
/// styling reverts to plain — which is an accepted limitation for the draft round trip.
public enum SubmissionHTML {

    // MARK: Editor conventions

    /// Base font size for body text; headings are sized relative to this.
    public static let bodyPointSize: CGFloat = 13

    /// Point size the editor applies for heading level 1...3. Chosen to match the sizes
    /// AppKit's HTML reader assigns to `<h1>/<h2>/<h3>` so imported drafts re-export cleanly.
    public static func headingPointSize(_ level: Int) -> CGFloat {
        switch level { case 1: 24; case 2: 18; default: 14 }
    }

    /// Paragraph-level flag marking a `<blockquote>`.
    public static let blockquoteAttribute = NSAttributedString.Key("submissionBlockquote")
    /// Inline flag marking a `<code>` span.
    public static let codeAttribute = NSAttributedString.Key("submissionCode")
    /// Paragraph-level flag marking a list item; value is a `ListKind.rawValue`.
    public static let listKindAttribute = NSAttributedString.Key("submissionListKind")

    public enum ListKind: String { case unordered, ordered }

    // MARK: - Export

    /// Serializes the editor's attributed string to a sanitizer-safe HTML fragment.
    public static func html(from attributed: NSAttributedString) -> String {
        let paragraphs = paragraphRanges(in: attributed)
        var blocks: [String] = []
        var i = 0
        while i < paragraphs.count {
            let range = paragraphs[i]

            // Group consecutive list items of the same kind into one <ul>/<ol>.
            if let kind = listKind(of: attributed, at: range) {
                var items: [String] = []
                while i < paragraphs.count, listKind(of: attributed, at: paragraphs[i]) == kind {
                    let content = listContentRange(of: attributed, in: paragraphs[i])
                    items.append("<li>\(inlineHTML(of: attributed, in: content, suppressBold: false))</li>")
                    i += 1
                }
                let tag = kind == .ordered ? "ol" : "ul"
                blocks.append("<\(tag)>\n\(items.joined(separator: "\n"))\n</\(tag)>")
                continue
            }

            i += 1

            // Drop blank lines — they only add stray empty paragraphs to Canvas.
            if attributed.attributedSubstring(from: range).string.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            if isBlockquote(attributed, at: range) {
                blocks.append("<blockquote>\(inlineHTML(of: attributed, in: range, suppressBold: false))</blockquote>")
            } else if let level = headingLevel(of: attributed, at: range) {
                blocks.append("<h\(level)>\(inlineHTML(of: attributed, in: range, suppressBold: true))</h\(level)>")
            } else {
                blocks.append("<p>\(inlineHTML(of: attributed, in: range, suppressBold: false))</p>")
            }
        }
        return blocks.joined(separator: "\n")
    }

    // MARK: - Import (draft reload)

    /// Parses stored HTML (or legacy plain text) back into an attributed string for editing.
    public static func attributed(fromHTML html: String) -> NSAttributedString {
        let data = Data(html.utf8)
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        return (try? NSAttributedString(data: data, options: options, documentAttributes: nil)) ?? NSAttributedString(string: html)
    }

    /// The rendered text with all markup removed — used for character counts and emptiness.
    public static func plainText(fromHTML html: String) -> String {
        attributed(fromHTML: html).string.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the stored HTML carries no visible text (empty draft, `<p></p>`, whitespace).
    public static func isEffectivelyEmpty(_ html: String) -> Bool {
        plainText(fromHTML: html).isEmpty
    }

    // MARK: - Paragraph analysis

    private static func paragraphRanges(in attributed: NSAttributedString) -> [NSRange] {
        let ns = attributed.string as NSString
        var ranges: [NSRange] = []
        var start = 0
        let length = ns.length
        while start <= length {
            let searchRange = NSRange(location: start, length: length - start)
            let nl = ns.range(of: "\n", options: [], range: searchRange)
            if nl.location == NSNotFound {
                ranges.append(NSRange(location: start, length: length - start))
                break
            }
            ranges.append(NSRange(location: start, length: nl.location - start))
            start = nl.location + 1
        }
        return ranges
    }

    private static func attribute(_ key: NSAttributedString.Key, in attributed: NSAttributedString, at range: NSRange) -> Any? {
        guard range.length > 0 else {
            return range.location < attributed.length ? attributed.attribute(key, at: range.location, effectiveRange: nil) : nil
        }
        return attributed.attribute(key, at: range.location, effectiveRange: nil)
    }

    private static func listKind(of attributed: NSAttributedString, at range: NSRange) -> ListKind? {
        if let raw = attribute(listKindAttribute, in: attributed, at: range) as? String,
           let kind = ListKind(rawValue: raw) {
            return kind
        }
        // A reloaded draft expresses lists through the native paragraph style instead.
        if let ps = attribute(.paragraphStyle, in: attributed, at: range) as? NSParagraphStyle,
           let marker = ps.textLists.first?.markerFormat {
            return marker == .decimal ? .ordered : .unordered
        }
        return nil
    }

    /// A list item paragraph is stored by NSTextView as `\t<marker>\t<text>`; return the
    /// range covering just `<text>`. Paragraphs without that prefix are returned unchanged.
    private static func listContentRange(of attributed: NSAttributedString, in range: NSRange) -> NSRange {
        let text = (attributed.string as NSString).substring(with: range)
        guard text.hasPrefix("\t") else { return range }
        // Drop everything up to and including the second tab.
        let afterFirst = text.dropFirst()
        guard let tabIdx = afterFirst.firstIndex(of: "\t") else { return range }
        let markerLength = text.distance(from: text.startIndex, to: tabIdx) + 1  // include the second tab
        return NSRange(location: range.location + markerLength, length: range.length - markerLength)
    }

    private static func isBlockquote(_ attributed: NSAttributedString, at range: NSRange) -> Bool {
        (attribute(blockquoteAttribute, in: attributed, at: range) as? Bool) == true
    }

    private static func headingLevel(of attributed: NSAttributedString, at range: NSRange) -> Int? {
        guard range.length > 0 else { return nil }
        var maxSize: CGFloat = 0
        attributed.enumerateAttribute(.font, in: range) { value, _, _ in
            if let font = value as? NSFont { maxSize = max(maxSize, font.pointSize) }
        }
        switch maxSize {
        case 21...: return 1
        case 16..<21: return 2
        case 14..<16: return 3
        default: return nil
        }
    }

    // MARK: - Inline rendering

    private static func inlineHTML(of attributed: NSAttributedString, in range: NSRange, suppressBold: Bool) -> String {
        guard range.length > 0 else { return "" }
        var out = ""
        attributed.enumerateAttributes(in: range) { attrs, runRange, _ in
            let text = escape((attributed.string as NSString).substring(with: runRange))
            var openers: [String] = []
            var closers: [String] = []

            if let link = href(from: attrs[.link]) {
                openers.append(#"<a href="\#(escape(link))">"#); closers.insert("</a>", at: 0)
            }
            if let font = attrs[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                if traits.contains(.bold) && !suppressBold { openers.append("<strong>"); closers.insert("</strong>", at: 0) }
                if traits.contains(.italic) { openers.append("<em>"); closers.insert("</em>", at: 0) }
            }
            if let u = attrs[.underlineStyle] as? Int, u != 0 {
                openers.append("<u>"); closers.insert("</u>", at: 0)
            }
            if (attrs[codeAttribute] as? Bool) == true {
                openers.append("<code>"); closers.insert("</code>", at: 0)
            }
            out += openers.joined() + text + closers.joined()
        }
        return out
    }

    private static func href(from value: Any?) -> String? {
        switch value {
        case let url as URL: url.absoluteString
        case let str as String: str
        default: nil
        }
    }

    private static func escape(_ s: String) -> String {
        var r = s.replacingOccurrences(of: "&", with: "&amp;")
        r = r.replacingOccurrences(of: "<", with: "&lt;")
        r = r.replacingOccurrences(of: ">", with: "&gt;")
        r = r.replacingOccurrences(of: "\"", with: "&quot;")
        return r
    }
}
