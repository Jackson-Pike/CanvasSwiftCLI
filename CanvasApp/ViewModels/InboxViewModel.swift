import Foundation
import CanvasCore
import CanvasData

@MainActor
final class InboxViewModel: ObservableObject {
    @Published var conversations: [CachedConversation] = []
    @Published var messages: [CachedMessage] = []
    @Published var selectedId: Int?
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    @Published var replyText = ""

    var selected: CachedConversation? { selectedId.flatMap { id in conversations.first { $0.id == id } } }

    func load(session: AppSession, force: Bool = false) async {
        readList(session)
        guard session.hasCredentials else { return }
        isLoading = conversations.isEmpty
        error = await session.refresh(.inbox, force: force)
        readList(session)
        isLoading = false
    }

    func openThread(_ id: Int, session: AppSession) async {
        selectedId = id
        readThread(session)
        _ = await session.refresh(.conversation(id))
        readThread(session)
        // Opening an unread thread marks it read (optimistic + round-trip).
        if selected?.workflowState == "unread" {
            _ = await session.markConversationRead(id)
            readList(session)
        }
    }

    func sendReply(session: AppSession) async {
        guard let id = selectedId else { return }
        let body = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isSending = true; error = nil
        let authorName = session.isDemo ? "Demo Student" : "Me"
        try? session.repository.insertPendingMessage(conversationId: id, body: body,
                                                     authorId: MockData.studentUserId, authorName: authorName)
        readThread(session)
        replyText = ""
        if let failure = await session.sendReply(conversationId: id, body: body) {
            error = failure
            try? session.repository.removePendingMessages(conversationId: id)
            replyText = body   // restore draft (spec §5.2)
        }
        readThread(session)
        isSending = false
    }

    func compose(recipientIds: [Int], subject: String, body: String, session: AppSession) async {
        switch await session.compose(recipientIds: recipientIds, subject: subject, body: body) {
        case .success(let id):
            readList(session); await openThread(id, session: session)
        case .failure(let failure):
            error = String(describing: failure)
        }
    }

    private func readList(_ session: AppSession) {
        conversations = (try? session.repository.conversations(scope: .inbox)) ?? []
        lastSyncedAt = try? session.repository.lastSyncedAt(entityKind: "conversations", scopeId: "inbox")
    }

    private func readThread(_ session: AppSession) {
        guard let id = selectedId else { messages = []; return }
        messages = (try? session.repository.messages(conversationId: id)) ?? []
    }
}
