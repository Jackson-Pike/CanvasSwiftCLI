import SwiftUI
import CanvasCore
import CanvasData
import CanvasUI

/// The Dashboard detail pane: term GPA header, semester timeline, cross-course
/// ledger table, and the awaiting-grade / recent-feedback panels. Assembles
/// already-built CanvasUI pieces around `DashboardViewModel`, and is the one
/// place that maps `StreamItem` (CanvasData) into `AwaitingRow`/`FeedbackRow`
/// (CanvasUI) so CanvasUI itself stays free of CanvasData.
struct DashboardView: View {
    @Environment(AppSession.self) private var session
    @Environment(Router.self) private var router
    @ObservedObject var coursesVM: CoursesViewModel
    let settings: CourseSettingsStore

    @State private var vm = DashboardViewModel()
    @State private var termVM = TermScenarioViewModel()
    /// assignmentId -> courseId, rebuilt after every load. `StreamItem` does not carry a
    /// course id (it's built per-course and merged in `DashboardViewModel`), so this is
    /// reconstructed here by re-walking each visible course's cached assignments.
    @State private var assignmentCourseLookup: [Int: Int] = [:]
    @State private var panelsWidth: CGFloat = 0
    @State private var showSettings = false
    @State private var dueSoonItems: [ToDoItem] = []

    var body: some View {
        HStack(spacing: 0) {
            Group {
                if vm.error != nil {
                    errorState
                } else if vm.rows.isEmpty && !vm.isLoading {
                    emptyState
                } else {
                    dashboardContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if router.sandboxOpen {
                TermSandboxRail(vm: termVM)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: router.sandboxOpen)
        .background(Color.canvasBG)
        .sheet(isPresented: $showSettings) {
            SettingsView(isOnboarding: false, vm: coursesVM)
                .frame(minHeight: 420)
        }
        .task(id: session.host) {
            await reload()
        }
        .onChange(of: coursesVM.courses.count) {
            Task { await reload() }
        }
        .onChange(of: vm.summaries.count) {
            syncTermVM()
        }
        .onChange(of: vm.rows.count) {
            syncTermVM()
        }
    }

    /// Feeds the term sandbox VM the latest summaries + course-code lookup whenever
    /// `DashboardViewModel` finishes a read. `CourseGradeSummary` carries no display
    /// name, so the code map comes from `vm.rows` (built in the same pass).
    private func syncTermVM() {
        termVM.summaries = vm.summaries
        termVM.codes = Dictionary(uniqueKeysWithValues: vm.rows.map { ($0.id, $0.code) })
    }

    private func reload(force: Bool = false) async {
        await vm.load(session: session, coursesVM: coursesVM, settings: settings, force: force)
        rebuildAssignmentLookup()

        let now = Date()
        let upcoming = (try? session.repository.toDoDueThisWeek(now: now)) ?? []
        dueSoonItems = upcoming.filter { item in
            guard let date = item.plannableDate else { return false }
            return date > now && date <= now.addingTimeInterval(86400)
        }.map { item in
            ToDoItem(
                id: item.id,
                title: item.title,
                courseId: item.courseId,
                date: item.plannableDate,
                statusText: "Due soon",
                htmlUrl: item.htmlUrl
            )
        }
    }

    private func rebuildAssignmentLookup() {
        var lookup: [Int: Int] = [:]
        for row in vm.rows {
            let assignments = (try? session.repository.assignments(courseId: row.id)) ?? []
            for assignment in assignments {
                lookup[assignment.id] = row.id
            }
        }
        assignmentCourseLookup = lookup
    }

    // MARK: - States

    private var errorState: some View {
        ContentUnavailableView {
            Label("Couldn't Load Dashboard", systemImage: "exclamationmark.triangle")
        } description: {
            Text(vm.error ?? "")
        } actions: {
            Button("Retry") { Task { await reload(force: true) } }
                .buttonStyle(.bordered)
            if let error = vm.error, error.contains("Invalid token") || error.contains("unauthorized") {
                Button("Update Token…") { showSettings = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.byuhRed)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Active Courses", systemImage: "graduationcap")
        } description: {
            Text("Courses you're enrolled in this term will appear here.")
        } actions: {
            Button("Refresh") { Task { await reload(force: true) } }
                .buttonStyle(.bordered)
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if let start = vm.termStart, let end = vm.termEnd {
                    SemesterTimelineStrip(termStart: start, termEnd: end, ticks: timelineTicks)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 4)
                }
                if !dueSoonItems.isEmpty {
                    DueSoonStrip(items: dueSoonItems, onItemClick: { item in
                        if let urlString = item.htmlUrl, let url = URL(string: urlString) {
                            NSWorkspace.shared.open(url)
                        }
                    })
                    .padding(.horizontal, 30)
                    .padding(.bottom, 16)
                }
                ledgerSection
                bottomPanels
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TERM GPA")
                    .font(.sectionLabel)
                    .tracking(1.26)
                    .foregroundStyle(Color.inkTertiary)
                Group {
                    if let gpa = vm.termGPA {
                        Text(String(format: "%.2f", gpa))
                    } else {
                        Text("–.––")
                    }
                }
                .font(.display(58))
                .tracking(-1.74)
                .foregroundStyle(Color.gpaCodeWhite)
            }

            sentence
                .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 0)

            Button {
                router.sandboxOpen.toggle()
            } label: {
                Text("Play it out →")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 15)
                    .fixedSize()
            }
            .buttonStyle(.plain)
            .background(Color.accentHypothetical, in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var sentence: some View {
        let points = Int(vm.pointsInPlay.rounded())
        let ceiling = vm.ceilingGPA.map { String(format: "%.2f", $0) } ?? "—"
        let floor = vm.floorGPA.map { String(format: "%.2f", $0) } ?? "—"
        return (
            Text("\(points) points").fontWeight(.bold).foregroundStyle(Color.inkPrimary)
            + Text(" are still unawarded. Enough to reach ").foregroundStyle(Color.inkSecondary)
            + Text(ceiling).fontWeight(.bold).foregroundStyle(Color.accentHypothetical)
            + Text(" — or fall to ").foregroundStyle(Color.inkSecondary)
            + Text(floor).fontWeight(.bold).foregroundStyle(Color.inkPrimary)
            + Text(".").foregroundStyle(Color.inkSecondary)
        )
        .font(.system(size: 14.5))
        .lineSpacing(3)
    }

    /// Derives timeline ticks from the awaiting-grade and recent-feedback streams — the only
    /// due-date data `DashboardViewModel` currently exposes. Overdue awaiting-grade items are
    /// `.missing`, future ones `.upcoming`; feedback items (already graded) are `.graded`.
    /// Negative ids on the feedback side keep the two streams from colliding if the same
    /// assignment id ever appears in both.
    private var timelineTicks: [SemesterTimelineStrip.Tick] {
        let now = Date()
        var ticks: [SemesterTimelineStrip.Tick] = []
        for item in vm.awaitingGrade {
            guard let due = item.assignment.dueAt else { continue }
            let style: SemesterTimelineStrip.Tick.Style = due < now ? .missing : .upcoming
            ticks.append(.init(id: item.assignment.id, dueAt: due, style: style))
        }
        for item in vm.recentFeedback {
            guard let due = item.assignment.dueAt else { continue }
            ticks.append(.init(id: -item.assignment.id, dueAt: due, style: .graded))
        }
        return ticks
    }

    // MARK: - Ledger

    private var ledgerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            LedgerHeaderRow()
                .padding(.bottom, 8)

            if vm.isLoading && vm.rows.isEmpty {
                SkeletonList(rows: 4)
            } else {
                ForEach(vm.rows) { row in
                    LedgerRowView(
                        code: row.code,
                        name: row.name,
                        dotColor: row.dotColor,
                        nowPercent: row.nowPercent,
                        ledger: row.ledger,
                        ceilingPercent: row.ceilingPercent,
                        ceilingLetter: row.ceilingLetter,
                        floorPercent: row.floorPercent,
                        floorLetter: row.floorLetter,
                        missingLabel: row.missingLabel,
                        onTap: { router.reveal(.course(id: row.id, tab: .grades)) }
                    )
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 14)
    }

    // MARK: - Bottom panels

    private var dotColors: [Int: Color] {
        Dictionary(uniqueKeysWithValues: vm.rows.map { ($0.id, $0.dotColor) })
    }

    private func courseId(for item: StreamItem) -> Int? {
        assignmentCourseLookup[item.assignment.id]
    }

    private var awaitingRows: [AwaitingRow] {
        vm.awaitingGrade.map { item in
            let resolvedCourseId = courseId(for: item)
            let dot = resolvedCourseId.flatMap { dotColors[$0] } ?? .inkTertiary
            return AwaitingRow(
                id: item.assignment.id,
                dotColor: dot,
                title: item.assignment.name,
                subtitle: awaitingSubtitle(for: item),
                ageDays: ageDays(for: item),
                onTap: {
                    if let resolvedCourseId {
                        router.reveal(.assignment(courseId: resolvedCourseId, assignmentId: item.assignment.id))
                    } else {
                        // Course id could not be resolved for this stream item (e.g. the
                        // course was hidden/removed between load and lookup rebuild) —
                        // fall back to the dashboard section rather than a dead tap.
                        router.reveal(.section(.dashboard))
                    }
                }
            )
        }
    }

    private var feedbackRows: [FeedbackRow] {
        vm.recentFeedback.compactMap { item -> FeedbackRow? in
            guard case .feedback(let authorName, let comment, _) = item.kind else { return nil }
            let resolvedCourseId = courseId(for: item)
            let tint = resolvedCourseId.flatMap { dotColors[$0] } ?? .accentHypothetical
            return FeedbackRow(
                id: item.assignment.id,
                initials: initials(from: authorName),
                tint: tint,
                author: authorName,
                context: item.assignment.name,
                comment: comment,
                onTap: {
                    if let resolvedCourseId {
                        router.reveal(.assignment(courseId: resolvedCourseId, assignmentId: item.assignment.id))
                    } else {
                        router.reveal(.section(.dashboard))
                    }
                }
            )
        }
    }

    /// `submitted <date> · <pts> pts` when a due date is known, otherwise just the points —
    /// the model has no separate "submitted at" timestamp, only `dueAt`, so this doesn't
    /// invent one.
    private func awaitingSubtitle(for item: StreamItem) -> String {
        let pts = Int(item.assignment.pointsPossible ?? 0)
        guard let due = item.assignment.dueAt else { return "\(pts) pts" }
        return "due \(Self.shortDateFormatter.string(from: due)) · \(pts) pts"
    }

    private func ageDays(for item: StreamItem) -> Int {
        guard let due = item.assignment.dueAt, due < Date() else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: due, to: Date()).day ?? 0
        return max(0, days)
    }

    private func initials(from name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var bottomPanels: some View {
        let hasAwaiting = !awaitingRows.isEmpty
        let hasFeedback = !feedbackRows.isEmpty

        return Group {
            if vm.isLoading && vm.rows.isEmpty {
                HStack(alignment: .top, spacing: 26) {
                    SkeletonList(rows: 3)
                    SkeletonList(rows: 3)
                }
            } else if hasAwaiting && hasFeedback {
                HStack(alignment: .top, spacing: 26) {
                    AwaitingGradePanel(rows: awaitingRows, heldBackNote: nil)
                        .frame(width: leftPanelWidth, alignment: .topLeading)
                    RecentFeedbackPanel(rows: feedbackRows)
                        .frame(width: rightPanelWidth, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(widthReader)
            } else if hasAwaiting {
                AwaitingGradePanel(rows: awaitingRows, heldBackNote: nil)
            } else if hasFeedback {
                RecentFeedbackPanel(rows: feedbackRows)
            } else {
                EmptyView()
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 18)
        .padding(.bottom, 24)
    }

    /// Captures the row's own width so the two panels can be split `1fr 1.15fr` (per the
    /// handoff's grid spec) without a hard-coded window width.
    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { panelsWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, newValue in panelsWidth = newValue }
        }
    }

    private var leftPanelWidth: CGFloat { max(0, (panelsWidth - 26) * (1 / 2.15)) }
    private var rightPanelWidth: CGFloat { max(0, (panelsWidth - 26) * (1.15 / 2.15)) }
}
