import SwiftUI
import AppKit
import WebKit
import CanvasCore

// MARK: - RichTextView

/// Renders Canvas-authored HTML (assignment descriptions, announcement messages,
/// syllabus bodies) inside the app's panel chrome.
///
/// Two rendering strategies, chosen by `CanvasCore.htmlNeedsWebView(_:)`:
///
/// - **Simple markup** → `NSAttributedString(data:options:documentAttributes:)` bridged
///   into `AttributedString`. Cheap, fully native, participates in SwiftUI layout and
///   selection. The HTML's own font/color attributes are stripped so the design tokens
///   win — inline HTML styling can't track light/dark appearance.
/// - **Complex markup** (tables, iframes, embedded media, LaTeX) → a sandboxed
///   `WKWebView`. `AttributedString` silently drops those constructs, which would
///   render a table as an unreadable text dump.
///
/// Both branches share the same `padding(16)` / `Color.canvasPanel` container so the
/// three call sites (Assignment detail, Announcement detail, Syllabus) don't each
/// reimplement the chrome.
/// How `RichTextView` frames its content.
///
/// - `panel` — the padded, filled, hairline-bordered card used by detail panes
///   (Assignment detail, Announcement detail, Syllabus).
/// - `bare` — no chrome: content sits flush on whatever background hosts it. Used
///   by the conversation thread, where every message otherwise became a floating box.
public enum RichTextChrome: Sendable { case panel, bare }

public struct RichTextView: View {
    private let html: String
    private let linkBaseURL: URL?
    private let chrome: RichTextChrome
    private let fontSize: CGFloat

    public init(html: String, linkBaseURL: URL? = nil,
                chrome: RichTextChrome = .panel, fontSize: CGFloat = 15) {
        self.html = html
        self.linkBaseURL = linkBaseURL
        self.chrome = chrome
        self.fontSize = fontSize
    }

    private var needsWebView: Bool { htmlNeedsWebView(html) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if needsWebView {
                RichTextWebView(html: html, linkBaseURL: linkBaseURL, fontSize: fontSize)
            } else {
                AttributedHTMLText(html: html, fontSize: fontSize)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RichTextChromeModifier(chrome: chrome))
    }
}

/// Applies (or omits) the panel card treatment. Kept as a modifier so the two
/// render branches above stay identical across chrome modes.
private struct RichTextChromeModifier: ViewModifier {
    let chrome: RichTextChrome

    func body(content: Content) -> some View {
        switch chrome {
        case .bare:
            content
        case .panel:
            content
                .padding(16)
                .background(Color.canvasPanel)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.canvasHairline, lineWidth: 1)
                )
        }
    }
}

// MARK: - AttributedString branch

/// The lightweight branch. Parses once per `html` value and caches the result so
/// SwiftUI re-renders don't re-run the (surprisingly expensive) HTML importer.
private struct AttributedHTMLText: View {
    let html: String
    var fontSize: CGFloat = 15

    @State private var cache: (source: String, text: AttributedString)?

    private var attributed: AttributedString {
        if let cache, cache.source == html { return cache.text }
        return AttributedHTMLText.parse(html)
    }

    var body: some View {
        Text(attributed)
            .font(.system(size: fontSize))
            .foregroundStyle(Color.inkPrimary)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: html) {
                cache = (html, AttributedHTMLText.parse(html))
            }
    }

    /// Bridges HTML → `AttributedString`, dropping the document's own font and color
    /// runs. Those are baked-in static values from Canvas's editor; leaving them in
    /// place would pin the text to black on a dark background.
    static func parse(_ html: String) -> AttributedString {
        guard let data = html.data(using: .utf8) else {
            return AttributedString(html)
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let ns = try? NSAttributedString(
            data: data,
            options: options,
            documentAttributes: nil
        ) else {
            return AttributedString(html)
        }

        var attributed = AttributedString(ns)
        for run in attributed.runs {
            // Strip both the SwiftUI *and* AppKit attribute scopes. The HTML importer
            // stamps every run with a concrete `NSFont` (Times ~12pt) under the AppKit
            // scope; clearing only the SwiftUI `.font` leaves that NSFont in place, and
            // an explicit per-run AppKit font wins over the `.font(.system(size:))`
            // view modifier — so the caller's font/size would silently do nothing.
            attributed[run.range].font = nil
            attributed[run.range].foregroundColor = nil
            attributed[run.range].backgroundColor = nil
            attributed[run.range].appKit.font = nil
            attributed[run.range].appKit.foregroundColor = nil
            attributed[run.range].appKit.backgroundColor = nil
        }

        // Trim the trailing newline the HTML importer appends to block-level content.
        while let last = attributed.characters.last, last.isNewline {
            attributed.removeSubrange(attributed.index(beforeCharacter: attributed.endIndex)..<attributed.endIndex)
        }
        return attributed
    }
}

private extension AttributedString {
    func index(beforeCharacter i: AttributedString.Index) -> AttributedString.Index {
        characters.index(before: i)
    }
}

// MARK: - WKWebView branch

/// SwiftUI wrapper that owns the measured content height so the web view can size
/// itself intrinsically inside a scrolling detail pane (no nested scroll views).
private struct RichTextWebView: View {
    let html: String
    let linkBaseURL: URL?
    var fontSize: CGFloat = 15

    @Environment(\.colorScheme) private var colorScheme
    @State private var contentHeight: CGFloat = 80

    var body: some View {
        RichTextWebViewRepresentable(
            html: html,
            linkBaseURL: linkBaseURL,
            colorScheme: colorScheme,
            fontSize: fontSize,
            contentHeight: $contentHeight
        )
        .frame(height: contentHeight)
        .frame(maxWidth: .infinity)
    }
}

private struct RichTextWebViewRepresentable: NSViewRepresentable {
    let html: String
    let linkBaseURL: URL?
    let colorScheme: ColorScheme
    let fontSize: CGFloat
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight, fontSize: fontSize)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Blocks <script> inside the *loaded* Canvas HTML. Our own
        // `evaluateJavaScript` height probe is unaffected by this flag.
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = false
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        webView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        webView.allowsMagnification = false

        context.coordinator.load(html: html, baseURL: linkBaseURL, into: webView, colorScheme: colorScheme)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        context.coordinator.load(html: html, baseURL: linkBaseURL, into: webView, colorScheme: colorScheme)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var contentHeight: CGFloat
        private let fontSize: CGFloat

        /// Identity of the content currently loaded, so `updateNSView` (which SwiftUI
        /// calls freely) doesn't reload — and thus re-flash — unchanged HTML.
        private var loadedKey: String?

        /// The initial `loadHTMLString` is the one and only navigation we permit into
        /// the main frame. Everything after it is a user-initiated link and gets
        /// handed to the browser instead.
        private var hasAllowedInitialLoad = false

        init(contentHeight: Binding<CGFloat>, fontSize: CGFloat) {
            self._contentHeight = contentHeight
            self.fontSize = fontSize
        }

        func load(html: String, baseURL: URL?, into webView: WKWebView, colorScheme: ColorScheme) {
            let key = "\(colorScheme)|\(baseURL?.absoluteString ?? "")|\(html)"
            guard key != loadedKey else { return }
            loadedKey = key
            hasAllowedInitialLoad = false
            webView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
            webView.loadHTMLString(Coordinator.document(wrapping: html, fontSize: fontSize), baseURL: baseURL)
        }

        // MARK: Navigation policy

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Sub-frames (legitimate <iframe> embeds — the very reason this branch
            // exists) load normally; only main-frame navigation is intercepted.
            if let frame = navigationAction.targetFrame, !frame.isMainFrame {
                decisionHandler(.allow)
                return
            }

            if !hasAllowedInitialLoad {
                hasAllowedInitialLoad = true
                decisionHandler(.allow)
                return
            }

            if let url = navigationAction.request.url, url.scheme?.lowercased() != "about" {
                NSWorkspace.shared.open(url)
            }
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // target="_blank" links arrive here with no target frame.
            if let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
            }
            return nil
        }

        // MARK: Intrinsic height

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measure(webView)
            // Images and web fonts settle after `didFinish`; re-measure once so tall
            // content isn't clipped to its pre-layout height.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak webView] in
                guard let webView else { return }
                self.measure(webView)
            }
        }

        private func measure(_ webView: WKWebView) {
            webView.evaluateJavaScript(
                "Math.ceil(document.body.scrollHeight)"
            ) { [weak self] result, _ in
                guard let self, let height = result as? CGFloat, height > 0 else { return }
                let clamped = max(24, min(height, 20_000))
                if abs(clamped - self.contentHeight) > 1 {
                    self.contentHeight = clamped
                }
            }
        }

        // MARK: Document shell

        /// Wraps Canvas HTML in a minimal shell. `color-scheme: light dark` plus the
        /// `prefers-color-scheme` block is what keeps a dark-mode window from showing
        /// a glaring white rectangle: WebKit inherits the host `NSView`'s appearance,
        /// so the media query flips in lockstep with the SwiftUI environment, and the
        /// hard-coded hex values mirror the `canvasPanel` / `inkPrimary` tokens.
        static func document(wrapping body: String, fontSize: CGFloat = 15) -> String {
            """
            <!DOCTYPE html>
            <html>
            <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
              :root {
                color-scheme: light dark;
                --panel: #F2EFEA;
                --ink: #1B1A17;
                --ink-secondary: #5A554E;
                --hairline: rgba(40, 34, 26, 0.11);
                --link: #8C43B0;
              }
              @media (prefers-color-scheme: dark) {
                :root {
                  --panel: #141311;
                  --ink: #EDEBE6;
                  --ink-secondary: #B7B1A8;
                  --hairline: rgba(245, 240, 233, 0.10);
                  --link: #C089E0;
                }
              }
              html, body {
                margin: 0;
                padding: 0;
                background: var(--panel);
                color: var(--ink);
              }
              body {
                font: \(String(format: "%.1f", fontSize))px -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
                line-height: 1.6;
                overflow-x: auto;
                -webkit-text-size-adjust: 100%;
              }
              body > *:first-child { margin-top: 0; }
              body > *:last-child { margin-bottom: 0; }
              a { color: var(--link); }
              h1, h2, h3, h4 { line-height: 1.25; }
              p { margin: 0 0 0.85em; }
              img, video, iframe { max-width: 100%; height: auto; }
              table {
                border-collapse: collapse;
                width: 100%;
                margin: 0 0 1em;
                font-size: 13.5px;
              }
              th, td {
                border: 1px solid var(--hairline);
                padding: 6px 9px;
                text-align: left;
                vertical-align: top;
              }
              th { font-weight: 600; }
              code, pre {
                font-family: ui-monospace, "SF Mono", Menlo, monospace;
                font-size: 13px;
              }
              pre {
                overflow-x: auto;
                padding: 10px;
                border: 1px solid var(--hairline);
                border-radius: 6px;
              }
              blockquote {
                margin: 0 0 1em;
                padding-left: 12px;
                border-left: 2px solid var(--hairline);
                color: var(--ink-secondary);
              }
              hr { border: 0; border-top: 1px solid var(--hairline); }
            </style>
            </head>
            <body>
            \(body)
            </body>
            </html>
            """
        }
    }
}

// MARK: - Previews

#if DEBUG
private let simpleHTMLSample = """
<h3>Reading Response 4</h3>
<p>Read chapter 7 and write a <strong>400-word</strong> response. Focus on the
author's treatment of <em>reciprocity</em> and cite at least one outside source.</p>
<ul>
  <li>Due Friday at 11:59pm</li>
  <li>Submit as a PDF</li>
  <li>Late work loses 10% per day</li>
</ul>
<p>Questions? <a href="https://example.edu/office-hours">Office hours</a>.</p>
"""

private let tableHTMLSample = """
<h3>Grading Breakdown</h3>
<p>Weights are fixed for the term.</p>
<table>
  <thead>
    <tr><th>Category</th><th>Weight</th><th>Drops</th></tr>
  </thead>
  <tbody>
    <tr><td>Reading Responses</td><td>20%</td><td>2 lowest</td></tr>
    <tr><td>Projects</td><td>35%</td><td>none</td></tr>
    <tr><td>Midterm</td><td>20%</td><td>none</td></tr>
    <tr><td>Final</td><td>25%</td><td>none</td></tr>
  </tbody>
</table>
<p>See the <a href="https://example.edu/syllabus">full syllabus</a> for details.</p>
"""

private struct RichTextViewPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Simple — AttributedString branch")
                    .font(.sectionLabel)
                    .foregroundStyle(Color.inkTertiary)
                RichTextView(html: simpleHTMLSample)

                Text("Table — WKWebView branch")
                    .font(.sectionLabel)
                    .foregroundStyle(Color.inkTertiary)
                RichTextView(html: tableHTMLSample)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
        .background(Color.canvasBG)
    }
}

#Preview("Rich Text - Light") {
    RichTextViewPreview()
        .preferredColorScheme(.light)
}

#Preview("Rich Text - Dark") {
    RichTextViewPreview()
        .preferredColorScheme(.dark)
}
#endif
