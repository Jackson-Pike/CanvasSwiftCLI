import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct DiscussionsTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @StateObject private var vm: DiscussionsViewModel

    init(courseId: Int) {
        self.courseId = courseId
        _vm = StateObject(wrappedValue: DiscussionsViewModel(courseId: courseId))
    }

    var body: some View {
        Group {
            if !vm.topics.isEmpty {
                HStack(spacing: 0) {
                    listColumn.frame(width: 300)
                    Divider()
                    detailColumn.frame(maxWidth: .infinity)
                }
            } else if vm.isLoading {
                SkeletonList()
            } else if let error = vm.error {
                ContentUnavailableView { Label("Couldn't Load Discussions", systemImage: "exclamationmark.triangle") }
                    description: { Text(error) }
            } else {
                ContentUnavailableView("No Discussions", systemImage: "bubble.left.and.bubble.right",
                                       description: Text("This course has no discussion topics."))
            }
        }
        .background(Color.canvasBG)
        .task(id: courseId) { await vm.load(session: session) }
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.topics, id: \.id) { t in
                        DiscussionTopicRow(title: t.title, replyCount: t.replyCount, postedAt: t.postedAt,
                                           isSelected: vm.selectedTopicId == t.id,
                                           onTap: { Task { await vm.openTopic(t.id, session: session) } })
                    }
                }
            }
            StalenessLabel(lastSyncedAt: vm.lastSyncedAt).padding(.horizontal, 12).padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let topic = vm.selectedTopic {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(topic.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.inkPrimary)
                        Spacer()
                        if let urlString = topic.htmlURL, let url = URL(string: urlString) {
                            Link(destination: url) { Label("Reply in Canvas", systemImage: "arrowshape.turn.up.left") }
                                .font(.system(size: 11))
                        }
                    }
                    RichTextView(html: topic.message ?? "")
                    Divider()
                    ForEach(vm.entries, id: \.id) { e in
                        DiscussionEntryView(authorName: e.authorName ?? "Unknown", message: e.message ?? "",
                                            date: e.createdAt, depth: e.depth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
        } else {
            ContentUnavailableView("Select a Topic", systemImage: "bubble.left.and.bubble.right",
                                   description: Text("Pick a discussion to read the thread."))
        }
    }
}
