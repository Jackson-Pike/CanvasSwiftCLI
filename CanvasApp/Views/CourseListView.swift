import SwiftUI
import AppKit
import CanvasCore
import CanvasData
import CanvasUI

struct CourseListView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var vm: CoursesViewModel
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Canvas")
                    .font(.headline.bold())
                    .foregroundStyle(Color.byuhRed)
                Spacer()
                HStack(spacing: 4) {
                    Button { refresh(force: true) } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                    .accessibilityLabel("Refresh courses")
                    .help("Refresh courses")
                    Button {
                        openWindow(id: "main")
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        Image(systemName: "macwindow")
                    }
                    .accessibilityLabel("Open in Window")
                    .help("Open in Window")
                    Button { path.append("settings") } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                    .help("Settings")
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            Group {
                if vm.isLoading {
                    Color.clear.overlay(SkeletonList())
                } else if let error = vm.error {
                    Color.clear.overlay(
                        ContentUnavailableView {
                            Label("Couldn't Load Courses", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Retry") { refresh(force: true) }
                                .buttonStyle(.bordered)
                            if error.contains("Invalid token") || error.contains("unauthorized") {
                                Button("Update Token…") { path.append("settings") }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.byuhRed)
                            }
                        }
                    )
                } else if vm.courses.isEmpty {
                    Color.clear.overlay(
                        ContentUnavailableView {
                            Label("No Active Courses", systemImage: "graduationcap")
                        } description: {
                            Text("Courses you're enrolled in this term will appear here.")
                        } actions: {
                            Button("Refresh") { refresh(force: true) }
                                .buttonStyle(.bordered)
                        }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if !vm.unseenChanges.isEmpty {
                                sinceYouLastLooked
                            }
                            ForEach(vm.courses, id: \.id) { course in
                                NavigationLink(destination: CourseDetailView(courseId: course.id)) {
                                    CourseCard(
                                        name: course.name,
                                        courseCode: course.courseCode,
                                        score: vm.currentScore(for: course.id),
                                        letter: vm.letter(for: course.id)
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        router.reveal(.course(id: course.id, tab: .grades))
                                        openWindow(id: "main")
                                        NSApp.activate(ignoringOtherApps: true)
                                    } label: {
                                        Label("Open in Window", systemImage: "macwindow")
                                    }
                                    .keyboardShortcut(.return, modifiers: .command)
                                    Button(role: .destructive) {
                                        vm.hide(courseId: course.id, session: session)
                                    } label: {
                                        Label("Hide Course", systemImage: "eye.slash")
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel({
                                    if let letter = vm.letter(for: course.id) {
                                        return "\(course.name), \(letter) grade"
                                    } else {
                                        return course.name
                                    }
                                }())
                                .accessibilityHint("Opens course detail")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .background(Color.systemGroupedBackground)
                }
            }
        }
        .task { await vm.load(session: session) }
    }

    private var sinceYouLastLooked: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Since you last looked")
                    .font(.subheadline.bold())
                Spacer()
                Button("Mark all seen") { vm.markChangesSeen(session: session) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            ForEach(vm.unseenChanges, id: \.id) { record in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon(for: record))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(record.title).font(.caption.bold())
                        if let detail = record.detail {
                            Text(detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(Color.systemGroupedBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func icon(for record: ChangeRecord) -> String {
        switch record.changeKind {
        case .newGrade: return "checkmark.circle"
        case .gradeChanged: return "arrow.up.arrow.down.circle"
        case .newFeedback: return "bubble.left"
        case .newAnnouncement: return "megaphone"
        case .newMessage: return "envelope"
        case .dueSoon: return "clock"
        case .none: return "bell"
        }
    }

    private func refresh(force: Bool = false) {
        Task { await vm.load(session: session, force: force) }
    }
}
