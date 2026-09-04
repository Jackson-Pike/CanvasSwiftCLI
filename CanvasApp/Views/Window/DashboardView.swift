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
    /// Width of the scrolling content column, captured once and reused for both the
    /// window-scaled hero numeral and the two-panel stack/side-by-side decision.
    @State private var contentWidth: CGFloat = 0
    @State private var showSettings = false
    @State private var dueSoonItems: [ToDoItem] = []

    /// Dynamic-Type anchors. Body/label text scales with the OS accessibility text-size
    /// setting; the hero numeral folds this multiplier into its window-aware size below.
    @ScaledMetric(relativeTo: .largeTitle) private var gpaScaleAnchor: CGFloat = 58
    @ScaledMetric(relativeTo: .callout) private var sentenceSize: CGFloat = 14.5
    @ScaledMetric(relativeTo: .caption) private var ctaSize: CGFloat = 12.5

    /// Items due within this rolling window count as "due soon" (three days, not a 24h cliff).
    private static let dueSoonWindow: TimeInterval = 72 * 3600
    /// Below this content width the two bottom panels stack instead of sitting side by side.
    private static let panelStackThreshold: CGFloat = 620

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
        let horizon = now.addingTimeInterval(Self.dueSoonWindow)
        let upcoming = (try? session.repository.toDoDueThisWeek(now: now)) ?? []
        dueSoonItems = upcoming.filter { item in
            guard let date = item.plannableDate else { return false }
            return date > now && date <= horizon
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
                    .tint(Color.accentHypothetical)
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
                    DueSoonStrip(items: dueSoonItems, courseColors: dotColors, onItemClick: { item in
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
            .background(contentWidthReader)
        }
    }

    /// Captures the content column's width for the hero numeral's window scaling and the
    /// bottom-panel layout switch — one read shared by both, rather than per-element geometry.
    private var contentWidthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { contentWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { _, newValue in contentWidth = newValue }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            // Single hero column: the GPA numeral owns the eye, with its outlook sentence
            // reading directly beneath it rather than competing alongside.
            VStack(alignment: .leading, spacing: 10) {
                Text("Term GPA")
                    .font(.sectionLabel)
                    .foregroundStyle(Color.inkTertiary)
                gpaNumeral
                sentence
                    .frame(maxWidth: 460, alignment: .leading)
            }

            Spacer(minLength: 16)

            scenariosButton
        }
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    /// The hero numeral. Its size is window-aware (clamped 46–64pt across content widths)
    /// with the Dynamic-Type multiplier folded in, and serif tracking follows the size.
    private var gpaNumeral: some View {
        Group {
            if let gpa = vm.termGPA {
                Text(String(format: "%.2f", gpa))
            } else {
                Text("—")
            }
        }
        .font(.display(gpaFontSize))
        .tracking(-0.03 * gpaFontSize)
        .foregroundStyle(Color.gpaCodeWhite)
    }

    private var gpaFontSize: CGFloat {
        let dynamicMultiplier = gpaScaleAnchor / 58   // OS accessibility text-size factor
        let minWidth: CGFloat = 620, maxWidth: CGFloat = 1100
        let minSize: CGFloat = 46, maxSize: CGFloat = 64
        let t = min(max((contentWidth - minWidth) / (maxWidth - minWidth), 0), 1)
        return (minSize + t * (maxSize - minSize)) * dynamicMultiplier
    }

    @ViewBuilder
    private var sentence: some View {
        if vm.termGPA == nil {
            outlookText("No graded work yet this term.")
        } else if Int(vm.pointsInPlay.rounded()) <= 0 {
            outlookText("Every assignment is graded — this term's GPA is final.")
        } else {
            gradeOutlook
        }
    }

    private func outlookText(_ string: String) -> some View {
        Text(string)
            .font(.system(size: sentenceSize))
            .lineSpacing(3)
            .foregroundStyle(Color.inkSecondary)
    }

    private var gradeOutlook: some View {
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
        .font(.system(size: sentenceSize))
        .lineSpacing(3)
    }

    /// Launches the what-if sandbox. Orchid is deliberate here — this is the one control that
    /// *is* the hypothetical action, so the accent reads as meaning rather than decoration.
    private var scenariosButton: some View {
        Button {
            router.sandboxOpen.toggle()
        } label: {
            Text(router.sandboxOpen ? "Hide scenarios" : "Explore scenarios")
                .font(.system(size: ctaSize, weight: .semibold))
                .foregroundStyle(Color.onAccent)
                .padding(.vertical, 9)
                .padding(.horizontal, 15)
                .fixedSize()
        }
        .buttonStyle(.plain)
        .background(Color.accentHypothetical, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityLabel(router.sandboxOpen ? "Hide grade scenarios" : "Explore grade scenarios")
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
        vm.recentFeedback.enumerated().compactMap { index, item -> FeedbackRow? in
            guard case .feedback(let authorName, let comment, _) = item.kind else { return nil }
            let resolvedCourseId = courseId(for: item)
            let tint = resolvedCourseId.flatMap { dotColors[$0] } ?? .accentHypothetical
            return FeedbackRow(
                // Two distinct comments can share one assignment id; fold in the row index so
                // `ForEach` identities stay unique (a collision drops/duplicates rows).
                id: item.assignment.id &* 100 &+ index,
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
                if contentWidth > 0 && contentWidth < Self.panelStackThreshold {
                    VStack(alignment: .leading, spacing: 24) {
                        AwaitingGradePanel(rows: awaitingRows, heldBackNote: nil)
                        RecentFeedbackPanel(rows: feedbackRows)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .top, spacing: 26) {
                        AwaitingGradePanel(rows: awaitingRows, heldBackNote: nil)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        RecentFeedbackPanel(rows: feedbackRows)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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

}
