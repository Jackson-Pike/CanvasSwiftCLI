import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

struct MainWindowView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        // The window is a restorable, Window-menu-reachable scene, so it must gate on setup
        // exactly like the popover — otherwise a fresh user lands in an empty split view
        // with no way to enter a token.
        if !session.hasSeenIntro {
            WelcomeView().frame(minWidth: 480, minHeight: 400)
        } else if !session.hasAcknowledgedKeychain {
            KeychainWarningView().frame(minWidth: 480, minHeight: 400)
        } else if !session.hasCredentials {
            SettingsView(isOnboarding: true, vm: session.coursesVM)
                .frame(minWidth: 480, minHeight: 400)
        } else {
            MainWindowBody(coursesVM: session.coursesVM)
        }
    }
}

private struct MainWindowBody: View {
    @ObservedObject var coursesVM: CoursesViewModel
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @State private var showSettings = false

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List(selection: Binding(get: { Optional(router.sidebar) },
                                    set: { router.sidebar = $0 ?? .dashboard })) {
                Section {
                    Label("Dashboard", systemImage: "square.grid.2x2").tag(SidebarItem.dashboard)
                    Label("Inbox", systemImage: "tray").tag(SidebarItem.inbox)
                    Label("Calendar", systemImage: "calendar").tag(SidebarItem.calendar)
                    Label("To-Do", systemImage: "checklist").tag(SidebarItem.todo)
                }
                Section("Courses") {
                    ForEach(coursesVM.courses, id: \.id) { course in
                        HStack {
                            Circle().fill(accentColor(for: course.courseCode)).frame(width: 8, height: 8)
                            Text(course.courseCode)
                            Spacer()
                            if let letter = coursesVM.letter(for: course.id) {
                                LetterBadge(letter: letter)
                            }
                        }
                        .tag(SidebarItem.course(course.id))
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            switch router.sidebar {
            case .dashboard: ComingSoonView(title: "Dashboard", phase: "Phase 1")
            case .inbox:     ComingSoonView(title: "Inbox", phase: "Phase 2")
            case .calendar:  ComingSoonView(title: "Calendar", phase: "Phase 3")
            case .todo:      ComingSoonView(title: "To-Do", phase: "Phase 3")
            case .course(let id): CourseWorkspaceView(courseId: id)
            }
        }
        .frame(minWidth: 900, minHeight: 600)   // spec §5.1
        .toolbar {
            ToolbarItem(placement: .status) {
                StalenessLabel(lastSyncedAt: coursesVM.lastSyncedAt)
            }
            ToolbarItem {
                Button {
                    Task { await coursesVM.load(session: session, force: true) }
                } label: {
                    if case .syncing = session.syncState { ProgressView().controlSize(.small) }
                    else { Image(systemName: "arrow.clockwise") }
                }
                .help("Refresh")
                .accessibilityLabel("Refresh")
                .disabled(coursesVM.isLoading)
            }
            ToolbarItem {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .help("Settings")
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isOnboarding: false, vm: coursesVM)
                .frame(minHeight: 420)   // SettingsView sets its own 340pt width
        }
        // Keyed on host: switching hosts from this window's own Settings sheet must re-run
        // the stale-selection check, or the sidebar keeps pointing at the old host's course.
        .task(id: session.host) {
            await coursesVM.load(session: session)
            // A persisted selection can outlive the course (hidden, dropped, or a different
            // host): fall back to the dashboard rather than rendering an orphan workspace.
            if case .course(let id) = router.sidebar,
               !coursesVM.courses.contains(where: { $0.id == id }) {
                router.sidebar = .dashboard
            }
        }
    }

    /// Phase 0 accent: stable hash of the course code (spec §5.1 fallback;
    /// /users/self/colors arrives in Phase 1).
    private func accentColor(for code: String) -> Color {
        let hues: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .red]
        return hues[abs(code.hashValue) % hues.count]
    }
}

struct ComingSoonView: View {
    let title: String
    let phase: String
    var body: some View {
        ContentUnavailableView(title, systemImage: "hammer",
                               description: Text("Coming in \(phase)."))
    }
}
