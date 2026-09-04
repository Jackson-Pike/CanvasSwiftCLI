import SwiftUI
import CanvasUI

/// Presentation context for the add/edit-quick-link sheet. `link == nil` means "new".
struct QuickLinkEditor: Identifiable {
    let id = UUID()
    let courseId: Int
    var link: CourseQuickLink?
    var courseLabel: String
}

/// Small sheet to add or edit a per-course quick link: label, URL, and an SF Symbol icon.
/// The icon auto-suggests from the URL's domain until the user picks one manually.
struct AddQuickLinkSheet: View {
    let editor: QuickLinkEditor
    let settings: CourseSettingsStore
    var onSaved: (Int) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    @State private var label: String
    @State private var urlString: String
    @State private var symbol: String
    /// Once the user taps an icon we stop overriding it from the URL.
    @State private var symbolLocked: Bool

    init(editor: QuickLinkEditor, settings: CourseSettingsStore, onSaved: @escaping (Int) -> Void = { _ in }) {
        self.editor = editor
        self.settings = settings
        self.onSaved = onSaved
        _label = State(initialValue: editor.link?.label ?? "")
        _urlString = State(initialValue: editor.link?.urlString ?? "")
        _symbol = State(initialValue: editor.link?.symbol ?? "link")
        _symbolLocked = State(initialValue: editor.link != nil)
    }

    private static let symbols: [String] = [
        "terminal", "book.closed", "checkmark.seal",
        "chevron.left.forwardslash.chevron.right", "bubble.left.and.bubble.right",
        "video", "doc.text", "graduationcap", "calendar", "link",
    ]

    private var isEditing: Bool { editor.link != nil }
    private var canSave: Bool {
        !label.trimmingCharacters(in: .whitespaces).isEmpty
            && !urlString.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)

            field("Label") {
                TextField("Colab notebook", text: $label)
                    .textFieldStyle(.roundedBorder)
            }
            field("URL") {
                TextField("https://colab.research.google.com/…", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: urlString) { _, newValue in
                        if !symbolLocked { symbol = Self.suggestSymbol(for: newValue) }
                    }
            }
            field("Icon") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 8) {
                    ForEach(Self.symbols, id: \.self) { name in
                        Button {
                            symbol = name
                            symbolLocked = true
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 15))
                                .frame(width: 34, height: 30)
                                .foregroundStyle(symbol == name ? Color.accentHypothetical : Color.inkSecondary)
                                .background(
                                    symbol == name
                                        ? Color.accentHypothetical.opacity(0.16)
                                        : Color.inkSecondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(symbol == name ? Color.accentHypothetical : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help(name)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save" : "Add link") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private var title: String {
        if isEditing { return "Edit Quick Link" }
        return editor.courseLabel.isEmpty ? "Add Quick Link" : "Add Quick Link — \(editor.courseLabel)"
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(Color.inkSecondary)
            content()
        }
    }

    private func save() {
        var link = editor.link ?? CourseQuickLink(label: "", urlString: "", symbol: symbol)
        link.label = label.trimmingCharacters(in: .whitespaces)
        link.urlString = Self.normalizedURL(urlString)
        link.symbol = symbol
        if isEditing {
            settings.updateQuickLink(link, for: editor.courseId)
        } else {
            settings.addQuickLink(link, for: editor.courseId)
        }
        onSaved(editor.courseId)
        dismiss()
    }

    /// Prepends `https://` when the user omits a scheme, so bare `canvas.byuh.edu` still opens.
    static func normalizedURL(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("://") ? trimmed : "https://\(trimmed)"
    }

    /// Best-effort icon guess from the URL so most links need only a label + URL.
    static func suggestSymbol(for urlString: String) -> String {
        let s = urlString.lowercased()
        switch true {
        case s.contains("colab"), s.contains("jupyter"), s.contains("kaggle"):
            return "terminal"
        case s.contains("github"), s.contains("gitlab"), s.contains("replit"):
            return "chevron.left.forwardslash.chevron.right"
        case s.contains("gradescope"):
            return "checkmark.seal"
        case s.contains("zoom"), s.contains("meet."), s.contains("teams"):
            return "video"
        case s.contains("piazza"), s.contains("discord"), s.contains("slack"), s.contains("ed.stem"):
            return "bubble.left.and.bubble.right"
        case s.contains(".pdf"), s.contains("book"), s.contains("textbook"):
            return "book.closed"
        case s.contains("calendar"):
            return "calendar"
        default:
            return "link"
        }
    }
}
