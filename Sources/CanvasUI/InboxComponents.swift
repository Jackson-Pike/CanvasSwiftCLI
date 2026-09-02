import SwiftUI
import CanvasCore

public struct ConversationRow: View {
    let subject: String
    let contextName: String?
    let snippet: String?
    let date: Date?
    let isUnread: Bool
    let isSelected: Bool
    let onTap: () -> Void

    public init(subject: String, contextName: String?, snippet: String?, date: Date?,
                isUnread: Bool, isSelected: Bool, onTap: @escaping () -> Void) {
        self.subject = subject; self.contextName = contextName; self.snippet = snippet
        self.date = date; self.isUnread = isUnread; self.isSelected = isSelected; self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 9) {
                Circle().fill(isUnread ? Color.accentHypothetical : .clear).frame(width: 7, height: 7).padding(.top, 6)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(subject).font(.system(size: 14, weight: isUnread ? .semibold : .regular))
                            .foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Spacer(minLength: 6)
                        if let date {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                        }
                    }
                    if let contextName {
                        Text(contextName).font(.system(size: 11)).foregroundStyle(Color.inkTertiary).lineLimit(1)
                    }
                    if let snippet {
                        Text(snippet).font(.system(size: 12)).foregroundStyle(Color.inkSecondary).lineLimit(2)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(isSelected ? Color.accentHypothetical.opacity(0.10) : .clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.canvasHairline).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

public struct MessageBubble: View {
    let authorName: String
    let messageBody: String
    let date: Date?
    let isMine: Bool
    let isPending: Bool
    let isDemo: Bool

    public init(authorName: String, body: String, date: Date?, isMine: Bool, isPending: Bool, isDemo: Bool) {
        self.authorName = authorName; self.messageBody = body; self.date = date
        self.isMine = isMine; self.isPending = isPending; self.isDemo = isDemo
    }

    public var body: some View {
        // Desktop mail layout: full-width chronological messages with an author header,
        // separated by a hairline — not iMessage-style left/right bubbles.
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(authorName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.inkPrimary)
                if isMine {
                    Text("You").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.accentHypothetical)
                }
                Spacer(minLength: 8)
                if isPending {
                    Text("sending…").font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                }
                if isDemo {
                    Text("Demo").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.inkTertiary, in: Capsule())
                }
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11)).foregroundStyle(Color.inkTertiary)
                }
            }
            RichTextView(html: messageBody)
                .opacity(isPending ? 0.6 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct ReplyComposer: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    public init(text: Binding<String>, isSending: Bool, onSend: @escaping () -> Void) {
        self._text = text; self.isSending = isSending; self.onSend = onSend
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Reply…", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(1...5)
            Button(action: onSend) {
                if isSending { ProgressView().controlSize(.small) }
                else { Image(systemName: "paperplane.fill") }
            }
            .buttonStyle(.borderedProminent).tint(Color.accentHypothetical)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(10)
        .background(Color.canvasBG)
    }
}

public struct ComposeSheet: View {
    let recipients: [(id: Int, name: String)]
    let onSend: (_ recipientIds: [Int], _ subject: String, _ body: String) -> Void
    let onCancel: () -> Void

    @State private var selectedRecipientId: Int?
    @State private var subject = ""
    @State private var bodyText = ""

    public init(recipients: [(id: Int, name: String)],
                onSend: @escaping (_ recipientIds: [Int], _ subject: String, _ body: String) -> Void,
                onCancel: @escaping () -> Void) {
        self.recipients = recipients; self.onSend = onSend; self.onCancel = onCancel
    }

    private var canSend: Bool {
        selectedRecipientId != nil && !subject.trimmingCharacters(in: .whitespaces).isEmpty
            && !bodyText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Message").font(.headline)
            Picker("To", selection: $selectedRecipientId) {
                Text("Select…").tag(Int?.none)
                ForEach(recipients, id: \.id) { r in Text(r.name).tag(Int?.some(r.id)) }
            }
            TextField("Subject", text: $subject).textFieldStyle(.roundedBorder)
            TextEditor(text: $bodyText).frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.canvasHairline))
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Send") {
                    if let id = selectedRecipientId { onSend([id], subject, bodyText) }
                }
                .buttonStyle(.borderedProminent).tint(Color.accentHypothetical).disabled(!canSend)
            }
        }
        .padding(20).frame(width: 420)
    }
}
