import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct InboxView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @StateObject private var vm = InboxViewModel()
    @State private var showCompose = false

    var body: some View {
        HStack(spacing: 0) {
            listColumn.frame(width: 300)
            Divider()
            threadColumn.frame(maxWidth: .infinity)
        }
        .background(Color.canvasBG)
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem {
                Button { showCompose = true } label: { Image(systemName: "square.and.pencil") }
                    .help("New Message").accessibilityLabel("New Message")
                    .disabled(!session.hasCredentials)
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeSheet(
                recipients: recipients,
                onSend: { ids, subject, body in
                    showCompose = false
                    Task { await vm.compose(recipientIds: ids, subject: subject, body: body, session: session) }
                },
                onCancel: { showCompose = false })
        }
        .task { await vm.load(session: session) }
        // Deep link: a notification tap / dashboard reveal sets router.selectedConversationId.
        .task(id: router.selectedConversationId) {
            if let id = router.selectedConversationId { await vm.openThread(id, session: session) }
        }
    }

    /// Recipient picker seeded from cached course participants (spec §5.2). Falls back to demo teacher.
    private var recipients: [(id: Int, name: String)] {
        var seen = Set<Int>(); var out: [(id: Int, name: String)] = []
        for convo in vm.conversations {
            for p in convo.participants where p.id != MockData.studentUserId && seen.insert(p.id).inserted {
                if let name = p.name {
                    out.append((id: p.id, name: name))
                }
            }
        }
        return out.isEmpty ? [(id: MockData.teacherUserId, name: "Instructor")] : out
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            if vm.conversations.isEmpty && vm.isLoading {
                SkeletonList()
            } else if let error = vm.error, vm.conversations.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load Inbox", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await vm.load(session: session, force: true) } }
                        .buttonStyle(.bordered)
                }
            } else if vm.conversations.isEmpty {
                ContentUnavailableView("No Conversations", systemImage: "tray",
                                       description: Text("Your Canvas inbox is empty."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.conversations, id: \.id) { c in
                            ConversationRow(subject: c.subject ?? "(no subject)", contextName: c.contextName,
                                            snippet: c.lastMessageSnippet, date: c.lastMessageAt,
                                            isUnread: c.workflowState == "unread", isSelected: vm.selectedId == c.id,
                                            onTap: { Task { await vm.openThread(c.id, session: session) } })
                        }
                    }
                }
            }
            StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var threadColumn: some View {
        if let convo = vm.selected {
            VStack(spacing: 0) {
                // Thread header — fills the top of the pane so short threads don't read as empty.
                VStack(alignment: .leading, spacing: 3) {
                    Text(convo.subject ?? "(no subject)")
                        .font(.display(21)).tracking(-0.63)
                        .foregroundStyle(Color.inkPrimary)
                        .lineLimit(2)
                    if let contextName = convo.contextName {
                        Text(contextName)
                            .font(.system(size: 12.5)).foregroundStyle(Color.inkTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 14)
                Divider().overlay(Color.canvasHairline)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(vm.messages, id: \.id) { m in
                            MessageBubble(authorName: m.authorName ?? "Unknown", body: m.body ?? "",
                                          date: m.createdAt, isMine: m.authorId == MockData.studentUserId,
                                          isPending: m.pending, isDemo: session.isDemo && m.pending)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                }
                if let error = vm.error {
                    Text(error).font(.caption).foregroundStyle(.orange).padding(.horizontal, 10)
                }
                ReplyComposer(text: $vm.replyText, isSending: vm.isSending,
                              onSend: { Task { await vm.sendReply(session: session) } })
                    .disabled(!session.hasCredentials)
            }
        } else {
            ContentUnavailableView("Select a Conversation", systemImage: "bubble.left.and.bubble.right",
                                   description: Text("Pick a thread to read and reply."))
        }
    }
}
