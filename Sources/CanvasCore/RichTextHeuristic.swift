/// True when `html` needs the sandboxed WKWebView fallback (tables, iframes, embedded
/// media, LaTeX/MathJax) rather than `AttributedString(html:)`, which only renders
/// simple inline markup and silently drops anything else.
public func htmlNeedsWebView(_ html: String) -> Bool {
    let lower = html.lowercased()
    let complexTags = ["<table", "<iframe", "<script", "<video", "<audio", "<embed", "<object"]
    if complexTags.contains(where: lower.contains) { return true }
    if lower.contains("\\(") || lower.contains("\\[") || lower.contains("class=\"math") { return true }
    return false
}
