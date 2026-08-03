import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct AnnouncementsTabView: View {
    let courseId: Int
    @Environment(AppSession.self) private var session
    @StateObject private var vm: AnnouncementsViewModel

    init(courseId: Int) {
        self.courseId = courseId
        _vm = StateObject(wrappedValue: AnnouncementsViewModel(courseId: courseId))
    }

    var body: some View {
        Group {
            if !vm.announcements.isEmpty {
                HStack(spacing: 0) {
                    listColumn
                        .frame(width: 300)
                    Divider()
                    detailColumn
                        .frame(maxWidth: .infinity)
                }
            } else if vm.isLoading {
                SkeletonList()
            } else if let error = vm.error {
                ContentUnavailableView {
                    Label("Couldn't Load Announcements", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView {
                    Label("No Announcements", systemImage: "megaphone")
                } description: {
                    Text("This course hasn't posted any announcements.")
                }
            }
        }
        .background(Color.canvasBG)
        .task(id: courseId) { await vm.load(session: session) }
        .task(id: vm.selectedId) { vm.markSelectedRead(session: session) }
    }

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.announcements, id: \.id) { item in
                        AnnouncementListRow(title: item.title,
                                            authorName: item.authorName,
                                            postedAt: item.postedAt,
                                            isUnread: item.readAt == nil,
                                            isSelected: vm.selectedId == item.id,
                                            onTap: { vm.selectedId = item.id })
                    }
                }
            }
            StalenessLabel(lastSyncedAt: vm.lastSyncedAt)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let item = vm.selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle(for: item))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                    RichTextView(html: item.message ?? "<p>No content.</p>")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        } else {
            ContentUnavailableView {
                Label("Select an Announcement", systemImage: "megaphone")
            } description: {
                Text("Pick an announcement from the list to read it.")
            }
        }
    }

    private func subtitle(for item: CachedAnnouncement) -> String {
        let author = item.authorName ?? "Unknown"
        guard let postedAt = item.postedAt else { return author }
        return "\(author) · \(postedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
