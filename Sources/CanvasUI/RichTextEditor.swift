import SwiftUI
import AppKit
import CanvasCore

// MARK: - RichTextEditor

/// A WYSIWYG editor for `online_text_entry` submissions. A formatting toolbar drives an
/// `NSTextView`; every edit is serialized to sanitizer-safe HTML via `SubmissionHTML` and
/// pushed back through the `html` binding (which flows into the draft and `submission[body]`).
///
/// Authoring counterpart to the read-only `RichTextView`.
public struct RichTextEditor: View {
    @Binding var html: String
    @StateObject private var controller = RichTextController()

    public init(html: Binding<String>) {
        self._html = html
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RichTextToolbar(controller: controller)
            Divider().overlay(Color.canvasHairline)
            RichTextEditorRepresentable(html: $html, controller: controller)
                .frame(minHeight: 160)
        }
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.canvasHairline))
    }
}

// MARK: - Controller

/// Shared bridge between the SwiftUI toolbar and the underlying `NSTextView`. Publishes the
/// active formatting at the insertion point so toolbar buttons can reflect state.
@MainActor
final class RichTextController: ObservableObject {
    weak var textView: NSTextView?

    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var isCode = false
    @Published var headingLevel = 0        // 0 = body
    @Published var listKind: SubmissionHTML.ListKind?
    @Published var isBlockquote = false

    private var body: CGFloat { SubmissionHTML.bodyPointSize }

    // MARK: Inline commands

    func toggleBold() { toggleFontTrait(.bold, mask: .boldFontMask, unmask: .unboldFontMask, active: isBold) }
    func toggleItalic() { toggleFontTrait(.italic, mask: .italicFontMask, unmask: .unitalicFontMask, active: isItalic) }

    func toggleUnderline() {
        let enabling = !isUnderline
        let value = enabling ? NSUnderlineStyle.single.rawValue : 0
        mutateSelection { storage, range in
            storage.addAttribute(.underlineStyle, value: value, range: range)
        } typing: { attrs in
            attrs[.underlineStyle] = value
        }
        refresh()
    }

    private func toggleFontTrait(_ trait: NSFontDescriptor.SymbolicTraits,
                                 mask: NSFontTraitMask, unmask: NSFontTraitMask, active: Bool) {
        let fm = NSFontManager.shared
        let apply = active ? unmask : mask
        mutateSelection { storage, range in
            storage.enumerateAttribute(.font, in: range) { value, sub, _ in
                let font = (value as? NSFont) ?? NSFont.systemFont(ofSize: self.body)
                storage.addAttribute(.font, value: fm.convert(font, toHaveTrait: apply), range: sub)
            }
        } typing: { attrs in
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: self.body)
            attrs[.font] = fm.convert(font, toHaveTrait: apply)
        }
        refresh()
    }

    /// Applies `mutate` to a non-empty selection, or updates `typing` attributes at an empty
    /// insertion point, then notifies the text view so the edit is serialized.
    private func mutateSelection(_ mutate: (NSTextStorage, NSRange) -> Void,
                                 typing: (inout [NSAttributedString.Key: Any]) -> Void) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        if range.length == 0 {
            var attrs = tv.typingAttributes
            typing(&attrs)
            tv.typingAttributes = attrs
        } else {
            storage.beginEditing()
            mutate(storage, range)
            storage.endEditing()
            didEdit()
        }
    }

    func toggleCode() {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let enabling = !isCode
        if range.length == 0 {
            var attrs = tv.typingAttributes
            if enabling {
                attrs[SubmissionHTML.codeAttribute] = true
                attrs[.font] = monospaced(from: attrs[.font] as? NSFont)
            } else {
                attrs.removeValue(forKey: SubmissionHTML.codeAttribute)
                attrs[.font] = NSFont.systemFont(ofSize: body)
            }
            tv.typingAttributes = attrs
        } else {
            storage.beginEditing()
            storage.enumerateAttributes(in: range) { current, sub, _ in
                if enabling {
                    storage.addAttribute(SubmissionHTML.codeAttribute, value: true, range: sub)
                    storage.addAttribute(.font, value: monospaced(from: current[.font] as? NSFont), range: sub)
                } else {
                    storage.removeAttribute(SubmissionHTML.codeAttribute, range: sub)
                    storage.addAttribute(.font, value: NSFont.systemFont(ofSize: body), range: sub)
                }
            }
            storage.endEditing()
            didEdit()
        }
        refresh()
    }

    func applyLink(_ urlString: String) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        guard range.length > 0, let url = normalizedURL(urlString) else { return }
        storage.addAttribute(.link, value: url, range: range)
        didEdit()
        refresh()
    }

    // MARK: Block commands

    func setHeading(_ level: Int) {
        let target = headingLevel == level ? 0 : level
        applyToSelectedParagraphs { storage, para in
            let size = target == 0 ? body : SubmissionHTML.headingPointSize(target)
            let font = target == 0 ? NSFont.systemFont(ofSize: size) : NSFont.boldSystemFont(ofSize: size)
            storage.addAttribute(.font, value: font, range: para)
        }
        refresh()
    }

    func toggleBlockquote() {
        let enabling = !isBlockquote
        applyToSelectedParagraphs { storage, para in
            if enabling {
                storage.addAttribute(SubmissionHTML.blockquoteAttribute, value: true, range: para)
            } else {
                storage.removeAttribute(SubmissionHTML.blockquoteAttribute, range: para)
            }
        }
        refresh()
    }

    func toggleList(_ kind: SubmissionHTML.ListKind) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let enabling = listKind != kind
        let selection = tv.selectedRange()
        let paraRange = (tv.string as NSString).paragraphRange(for: selection)
        let lines = (storage.string as NSString).substring(with: paraRange)
            .components(separatedBy: "\n")

        let marker = kind == .ordered ? NSTextList(markerFormat: .decimal, options: 0)
                                      : NSTextList(markerFormat: .disc, options: 0)
        let rebuilt = NSMutableAttributedString()
        var itemNumber = 1
        for (idx, line) in lines.enumerated() {
            let content = strippedListPrefix(line)
            let piece = NSMutableAttributedString(string: content, attributes: [
                .font: NSFont.systemFont(ofSize: body),
            ])
            if enabling && !content.isEmpty {
                let markerText = kind == .ordered ? "\t\(itemNumber).\t" : "\t\u{2022}\t"
                itemNumber += 1
                let ps = NSMutableParagraphStyle()
                ps.textLists = [marker]
                ps.headIndent = 24
                ps.firstLineHeadIndent = 0
                let full = NSMutableAttributedString(string: markerText, attributes: [
                    .font: NSFont.systemFont(ofSize: body),
                ])
                full.append(piece)
                full.addAttributes([
                    .paragraphStyle: ps,
                    SubmissionHTML.listKindAttribute: kind.rawValue,
                ], range: NSRange(location: 0, length: full.length))
                rebuilt.append(full)
            } else {
                rebuilt.append(piece)
            }
            if idx < lines.count - 1 { rebuilt.append(NSAttributedString(string: "\n")) }
        }
        storage.replaceCharacters(in: paraRange, with: rebuilt)
        tv.setSelectedRange(NSRange(location: paraRange.location + rebuilt.length, length: 0))
        didEdit()
        refresh()
    }

    // MARK: State sync

    /// Recomputes published formatting flags from the insertion point / selection.
    func refresh() {
        guard let tv = textView else { return }
        let attrs: [NSAttributedString.Key: Any]
        let range = tv.selectedRange()
        if range.length == 0 {
            attrs = tv.typingAttributes
        } else {
            attrs = tv.textStorage?.attributes(at: range.location, effectiveRange: nil) ?? [:]
        }
        let font = attrs[.font] as? NSFont
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        isBold = traits.contains(.bold)
        isItalic = traits.contains(.italic)
        isUnderline = (attrs[.underlineStyle] as? Int).map { $0 != 0 } ?? false
        isCode = (attrs[SubmissionHTML.codeAttribute] as? Bool) == true
        isBlockquote = (attrs[SubmissionHTML.blockquoteAttribute] as? Bool) == true
        if let raw = attrs[SubmissionHTML.listKindAttribute] as? String {
            listKind = SubmissionHTML.ListKind(rawValue: raw)
        } else if let ps = attrs[.paragraphStyle] as? NSParagraphStyle, let m = ps.textLists.first?.markerFormat {
            listKind = m == .decimal ? .ordered : .unordered
        } else {
            listKind = nil
        }
        switch font?.pointSize ?? body {
        case 21...: headingLevel = 1
        case 16..<21: headingLevel = 2
        case 14..<16: headingLevel = 3
        default: headingLevel = 0
        }
    }

    private func didEdit() {
        guard let tv = textView else { return }
        tv.didChangeText()
    }

    private func applyToSelectedParagraphs(_ mutate: (NSTextStorage, NSRange) -> Void) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let paraRange = (tv.string as NSString).paragraphRange(for: tv.selectedRange())
        guard paraRange.length > 0 else { return }
        storage.beginEditing()
        mutate(storage, paraRange)
        storage.endEditing()
        didEdit()
    }

    private func monospaced(from font: NSFont?) -> NSFont {
        let size = font?.pointSize ?? body
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private func strippedListPrefix(_ line: String) -> String {
        guard line.hasPrefix("\t") else { return line }
        let afterFirst = line.dropFirst()
        guard let tab = afterFirst.firstIndex(of: "\t") else { return line }
        return String(afterFirst[afterFirst.index(after: tab)...])
    }

    private func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.contains("://") { return URL(string: trimmed) }
        return URL(string: "https://\(trimmed)")
    }
}

// MARK: - NSViewRepresentable

private struct RichTextEditorRepresentable: NSViewRepresentable {
    @Binding var html: String
    let controller: RichTextController

    func makeCoordinator() -> Coordinator { Coordinator(html: $html, controller: controller) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .systemFont(ofSize: SubmissionHTML.bodyPointSize)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.drawsBackground = false
        scroll.drawsBackground = false

        let initial = SubmissionHTML.attributed(fromHTML: html)
        if initial.length > 0 {
            textView.textStorage?.setAttributedString(rebaseFont(initial))
        }
        textView.typingAttributes = [
            .font: NSFont.systemFont(ofSize: SubmissionHTML.bodyPointSize),
            .foregroundColor: NSColor.textColor,
        ]
        controller.textView = textView
        context.coordinator.lastSerialized = html
        DispatchQueue.main.async { controller.refresh() }
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // Only reload when the binding was changed from outside (e.g. draft loaded), never on
        // our own serialization echo — that would fight the user's cursor.
        if html != context.coordinator.lastSerialized {
            let attr = SubmissionHTML.attributed(fromHTML: html)
            textView.textStorage?.setAttributedString(rebaseFont(attr))
            context.coordinator.lastSerialized = html
        }
    }

    /// Normalizes AppKit's imported fonts (Helvetica/Times at HTML default sizes) onto the
    /// app's system font while preserving bold/italic traits and heading sizes.
    private func rebaseFont(_ input: NSAttributedString) -> NSAttributedString {
        let output = NSMutableAttributedString(attributedString: input)
        let full = NSRange(location: 0, length: output.length)
        output.enumerateAttribute(.font, in: full) { value, range, _ in
            let existing = value as? NSFont
            let size = existing?.pointSize ?? SubmissionHTML.bodyPointSize
            let traits = existing?.fontDescriptor.symbolicTraits ?? []
            var font = NSFont.systemFont(ofSize: size)
            if traits.contains(.bold) { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
            if traits.contains(.italic) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            output.addAttribute(.font, value: font, range: range)
            if output.attribute(.foregroundColor, at: range.location, effectiveRange: nil) == nil {
                output.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
            }
        }
        return output
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var html: String
        let controller: RichTextController
        var lastSerialized: String = ""

        init(html: Binding<String>, controller: RichTextController) {
            self._html = html
            self.controller = controller
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  let storage = textView.textStorage else { return }
            let serialized = SubmissionHTML.html(from: storage)
            lastSerialized = serialized
            html = serialized
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller.refresh()
        }
    }
}
