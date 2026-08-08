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
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(isUnread ? Color.byuhRed : .clear).frame(width: 7, height: 7).padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(subject).font(.system(size: 13, weight: isUnread ? .semibold : .regular))
                            .foregroundStyle(Color.inkPrimary).lineLimit(1)
                        Spacer()
                        if let date {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                        }
                    }
                    if let contextName {
                        Text(contextName).font(.system(size: 10)).foregroundStyle(Color.inkTertiary)
                    }
                    if let snippet {
                        Text(snippet).font(.system(size: 11)).foregroundStyle(Color.inkSecondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isSelected ? Color.inkPrimary.opacity(0.06) : .clear)
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
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(authorName).font(.system(size: 10, weight: .semibold)).foregroundStyle(Color.inkSecondary)
                    if let date {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 9)).foregroundStyle(Color.inkTertiary)
                    }
                    if isPending {
                        Text("sending…").font(.system(size: 9)).foregroundStyle(Color.inkTertiary)
                    }
                    if isDemo {
                        Text("Demo").font(.system(size: 8, weight: .bold)).foregroundStyle(Color.onAccent)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.inkTertiary, in: Capsule())
                    }
                }
                RichTextView(html: messageBody)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(isMine ? Color.byuhRed.opacity(0.12) : Color.inkPrimary.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: 10))
                    .opacity(isPending ? 0.6 : 1)
            }
            if !isMine { Spacer(minLength: 40) }
        }
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
            .buttonStyle(.borderedProminent).tint(.byuhRed)
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
                .buttonStyle(.borderedProminent).tint(.byuhRed).disabled(!canSend)
            }
        }
        .padding(20).frame(width: 420)
    }
}
