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
    /// Owned here alongside `coursesVM` (per-course credits/target prefs); `DashboardView`
    /// receives it rather than constructing its own so the same prefs back the sidebar's
    /// below-target coloring too.
    @State private var settings = CourseSettingsStore()

    private var inboxUnread: Int { (try? session.repository.unseenConversationCount()) ?? 0 }

    var body: some View {
        @Bindable var router = router
        NavigationSplitView {
            List {
                Section {
                    navRow(.dashboard, "Dashboard", "square.grid.2x2")
                    navRow(.inbox, "Inbox", "tray", badge: inboxUnread)
                    navRow(.calendar, "Calendar", "calendar")
                    navRow(.todo, "To-Do", "checklist")
                }
                Section("Courses") {
                    // §1.5: the ledger shows numbers, so the sidebar does too.
                    ForEach(coursesVM.courses, id: \.id) { course in
                        courseRow(id: course.id, code: course.courseCode,
                                  label: course.nickname ?? course.courseCode)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            // §1.5: staleness lives in the sidebar footer for every section — a quiet
            // bottom-left caption rather than a heavy centered toolbar pill.
            .safeAreaInset(edge: .bottom) {
                StalenessLabel(lastSyncedAt: coursesVM.lastSyncedAt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.canvasHairline).frame(height: 1)
                    }
            }
        } detail: {
            switch router.sidebar {
            case .dashboard: DashboardView(coursesVM: coursesVM, settings: settings)
            case .inbox:     InboxView()
            case .calendar:  CalendarView()
            case .todo:      ToDoView()
            case .course(let id): CourseWorkspaceView(courseId: id)
            }
        }
        .frame(minWidth: 900, minHeight: 600)   // spec §5.1
        .toolbar {
            ToolbarItem {
                Button {
                    router.quickOpenOpen = true
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Quick-Open (⌘K)")
                .accessibilityLabel("Quick-Open")
                .keyboardShortcut("k", modifiers: .command)
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
        .sheet(isPresented: $router.quickOpenOpen) {
            QuickOpenOverlay()
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

    /// Sidebar nav row with app-native selection (orchid wash + orchid icon), since the
    /// system `List` sidebar selection follows `controlAccentColor` and ignores `.tint`.
    @ViewBuilder
    private func navRow(_ item: SidebarItem, _ title: String, _ systemImage: String, badge: Int = 0) -> some View {
        let selected = router.sidebar == item
        Button {
            router.sidebar = item
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? Color.accentHypothetical : Color.inkSecondary)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: selected ? .semibold : .regular))
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: 4)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.mono(11))
                        .foregroundStyle(Color.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.accentHypothetical, in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentHypothetical.opacity(0.14) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func courseRow(id: Int, code: String, label: String) -> some View {
        let item = SidebarItem.course(id)
        let selected = router.sidebar == item
        Button {
            router.sidebar = item
        } label: {
            HStack(spacing: 8) {
                // Color stays keyed on `code` so the dot is stable regardless of nickname.
                Circle().fill(accentColor(for: code)).frame(width: 8, height: 8)
                Text(label)
                    .lineLimit(1).truncationMode(.tail)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(Color.inkPrimary)
                Spacer(minLength: 4)
                if let score = coursesVM.currentScore(for: id) {
                    Text(String(format: "%.1f", score))
                        .font(.mono(12))
                        .foregroundStyle(isBelowTarget(score, courseId: id) ? Color.lostMissing : Color.inkSecondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Color.accentHypothetical.opacity(0.14) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
        .listRowSeparator(.hidden)
    }

    /// Phase 0 accent: stable hash of the course code (spec §5.1 fallback;
    /// /users/self/colors arrives in Phase 1).
    private func accentColor(for code: String) -> Color {
        let hues = Color.courseAccentPalette
        return hues[abs(code.hashValue) % hues.count]
    }

    /// Compares a course's current percentage against its `CourseSettingsStore` target letter
    /// grade (e.g. "B-"), converted to a minimum percent via the standard 10-point scale.
    /// Courses with no target set are never flagged as below-target.
    private func isBelowTarget(_ score: Double, courseId: Int) -> Bool {
        guard let target = settings.targetGrade(for: courseId) else { return false }
        let bases: [String: Double] = ["A": 90.0, "B": 80.0, "C": 70.0, "D": 60.0]
        let base = target.first.flatMap { bases[String($0)] } ?? 0
        let modifier: Double = target.hasSuffix("-") ? -3.33 : (target.hasSuffix("+") ? 3.33 : 0)
        return score < base + modifier
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
