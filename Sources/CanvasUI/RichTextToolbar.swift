import SwiftUI

// MARK: - RichTextToolbar

/// Formatting controls for `RichTextEditor`. Buttons reflect the active formatting at the
/// insertion point (published by `RichTextController`) and issue commands back to it.
struct RichTextToolbar: View {
    @ObservedObject var controller: RichTextController
    @State private var showLinkField = false
    @State private var linkURL = ""

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                Button("Body") { controller.setHeading(0) }
                Button("Heading 1") { controller.setHeading(1) }
                Button("Heading 2") { controller.setHeading(2) }
                Button("Heading 3") { controller.setHeading(3) }
            } label: {
                Text(headingLabel).font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .frame(width: 82)

            divider

            button("bold", active: controller.isBold) { controller.toggleBold() }
            button("italic", active: controller.isItalic) { controller.toggleItalic() }
            button("underline", active: controller.isUnderline) { controller.toggleUnderline() }
            button("chevron.left.forwardslash.chevron.right", active: controller.isCode) { controller.toggleCode() }

            divider

            button("list.bullet", active: controller.listKind == .unordered) { controller.toggleList(.unordered) }
            button("list.number", active: controller.listKind == .ordered) { controller.toggleList(.ordered) }
            button("text.quote", active: controller.isBlockquote) { controller.toggleBlockquote() }

            divider

            button("link", active: false) { showLinkField.toggle() }
                .popover(isPresented: $showLinkField, arrowEdge: .bottom) {
                    linkPopover
                }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private var headingLabel: String {
        switch controller.headingLevel {
        case 1: "Heading 1"; case 2: "Heading 2"; case 3: "Heading 3"; default: "Body"
        }
    }

    private var divider: some View {
        Rectangle().fill(Color.canvasHairline).frame(width: 1, height: 16).padding(.horizontal, 2)
    }

    private func button(_ systemName: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12.5))
                .frame(width: 26, height: 22)
                .foregroundStyle(active ? Color.accentHypothetical : Color.inkSecondary)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(active ? Color.accentHypothetical.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var linkPopover: some View {
        HStack(spacing: 6) {
            TextField("https://…", text: $linkURL)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
                .onSubmit(applyLink)
            Button("Add", action: applyLink)
                .disabled(linkURL.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(10)
    }

    private func applyLink() {
        controller.applyLink(linkURL)
        linkURL = ""
        showLinkField = false
    }
}
